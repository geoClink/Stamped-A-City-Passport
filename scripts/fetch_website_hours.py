#!/usr/bin/env python3
"""
For entries in scripts/restaurant_hours_osm.json lacking hours, re-query Overpass at larger radius to capture website tags,
then fetch websites and attempt to parse opening hours from JSON-LD or common HTML patterns.
Writes merged output to scripts/restaurant_hours_full.json.
"""
from pathlib import Path
import json, time, re
import requests
from datetime import datetime
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[1]
OSM_REPORT = ROOT / 'scripts' / 'restaurant_hours_osm.json'
OUT = ROOT / 'scripts' / 'restaurant_hours_full.json'
OVERPASS = 'https://overpass-api.de/api/interpreter'

HEADERS = {'User-Agent': 'StampedCityPassportHoursCollector/1.0 (+https://example.invalid)'}

# reuse helper from previous script-ish
TIME_RANGE_RE = re.compile(r"(\d{1,2}:\d{2})-(\d{1,2}:\d{2})")
WEEKDAY_ORDER = ['Mo','Tu','We','Th','Fr','Sa','Su']
WEEKDAY_MAP = {'Mo':'monday','Tu':'tuesday','We':'wednesday','Th':'thursday','Fr':'friday','Sa':'saturday','Su':'sunday'}

MEAL_WINDOWS = {
    'breakfast': ("05:00","10:30"),
    'lunch': ("10:30","14:30"),
    'dinner': ("17:00","22:30")
}


def parse_opening_hours_tag(tag: str):
    # reuse simple parser from previous script
    if not tag or not isinstance(tag, str):
        return {}
    out = {d: [] for d in WEEKDAY_MAP.values()}
    parts = [p.strip() for p in tag.split(';') if p.strip()]
    for part in parts:
        m = re.match(r'^([A-Za-z0-9,\- ]+)\s+(.*)$', part)
        if m:
            dayspec = m.group(1).strip(); timespec = m.group(2).strip()
        else:
            dayspec = 'Mo-Su'; timespec = part
        ranges = TIME_RANGE_RE.findall(timespec)
        if not ranges:
            continue
        days = []
        for token in re.split(r',\s*', dayspec):
            token = token.strip()
            if '-' in token:
                dm = token.split('-')
                if dm[0] in WEEKDAY_ORDER and dm[1] in WEEKDAY_ORDER:
                    start_idx = WEEKDAY_ORDER.index(dm[0]); end_idx = WEEKDAY_ORDER.index(dm[1])
                    if start_idx <= end_idx:
                        rng = WEEKDAY_ORDER[start_idx:end_idx+1]
                    else:
                        rng = WEEKDAY_ORDER[start_idx:] + WEEKDAY_ORDER[:end_idx+1]
                    days.extend(rng)
            elif token in WEEKDAY_ORDER:
                days.append(token)
        if not days:
            days = WEEKDAY_ORDER[:]
        for dr in days:
            wd = WEEKDAY_MAP.get(dr)
            if not wd: continue
            for tr in ranges:
                out[wd].append([tr[0], tr[1]])
    return out


def infer_meals(hours_dict, cuisine_list):
    meals = {}
    for meal, win in MEAL_WINDOWS.items():
        count = 0
        for wd, ranges in hours_dict.items():
            for r in ranges:
                if r[0] <= win[1] and r[1] >= win[0]:
                    count += 1; break
        available = (count >= 4)
        cuisine_hint = False
        if cuisine_list:
            text = ','.join(cuisine_list).lower() if isinstance(cuisine_list,list) else str(cuisine_list).lower()
            if meal == 'breakfast' and any(x in text for x in ('bakery','breakfast','brunch','coffee','tea')):
                cuisine_hint = True
            if meal == 'dinner' and any(x in text for x in ('dinner','steak','grill','seafood')):
                cuisine_hint = True
            if meal == 'lunch' and any(x in text for x in ('lunch','sandwich','burger','salad','pizza')):
                cuisine_hint = True
        if available and cuisine_hint:
            conf='high'
        elif available:
            conf='medium'
        elif cuisine_hint:
            conf='medium'
        else:
            conf='low'
        meals[meal] = {'available': available, 'confidence': conf, 'days_open_count': count}
    return meals


def query_overpass_for_tags(lat, lon, radius=200):
    q = ("[out:json][timeout:25];(node(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         "way(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         "relation(around:%d,%f,%f)[amenity~'restaurant|cafe|fast_food|bar|pub|biergarten|ice_cream|food_court|food'];"
         ");out center tags;") % (radius, lat, lon, radius, lat, lon, radius, lat, lon)
    try:
        r = requests.post(OVERPASS, data=q.encode('utf-8'), headers=HEADERS, timeout=60)
        if r.status_code==200:
            return r.json().get('elements', [])
    except Exception as e:
        print('Overpass query error:', e)
    return []


def extract_jsonld_hours(html_text):
    # find JSON-LD script blocks
    matches = re.findall(r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', html_text, flags=re.I|re.S)
    for m in matches:
        try:
            j = json.loads(m)
        except Exception:
            continue
        # j may be a list or dict
        arr = j if isinstance(j, list) else [j]
        for item in arr:
            # look for openingHours or openingHoursSpecification
            if isinstance(item, dict):
                if 'openingHours' in item:
                    oh = item['openingHours']
                    # normalize to dict
                    return normalize_opening_hours_from_list(oh)
                if 'openingHoursSpecification' in item:
                    specs = item['openingHoursSpecification']
                    return normalize_opening_hours_from_spec(specs)
    return None


def normalize_opening_hours_from_list(oh_list):
    # oh_list like ["Mo-Su 08:00-22:00"]
    if not oh_list: return {}
    if isinstance(oh_list, str): oh_list = [oh_list]
    # join and delegate to parse_opening_hours_tag by creating a faux tag
    tag = '; '.join(oh_list)
    return parse_opening_hours_tag(tag)


def normalize_opening_hours_from_spec(specs):
    # specs is a list of dicts with dayOfWeek, opens, closes
    out = {d: [] for d in ('monday','tuesday','wednesday','thursday','friday','saturday','sunday')}
    if isinstance(specs, dict): specs = [specs]
    for s in specs:
        days = s.get('dayOfWeek')
        if isinstance(days, str): days = [days]
        opens = s.get('opens')
        closes = s.get('closes')
        if not (days and opens and closes): continue
        for d in days:
            # day may be full name or URL; take last part
            dn = d.split('/')[-1] if '/' in d else d
            dn = dn[:2].title()
            wd = WEEKDAY_MAP.get(dn)
            if wd:
                out[wd].append([opens, closes])
    return out


def fetch_website(url):
    try:
        r = requests.get(url, headers=HEADERS, timeout=15)
        if r.status_code==200:
            return r.text
    except Exception as e:
        print('Fetch website error for', url, e)
    return None


def attempt_website_parsing(website_url):
    html = fetch_website(website_url)
    if not html:
        return None
    # try JSON-LD
    jld = extract_jsonld_hours(html)
    if jld:
        return jld
    # fallback: search for patterns like 'Mon-Fri 08:00-17:00' in the HTML
    m = re.findall(r'(Mo[nday]{0,5}|Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)[^<\n]{0,40}\d{1,2}:\d{2}.*?\d{1,2}:\d{2}', html, flags=re.I|re.S)
    # crude: try to find sequences like 'Mon-Fri 08:00-17:00'
    tag_matches = re.findall(r'((?:Mo|Tu|We|Th|Fr|Sa|Su|Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)[^<;\n]{0,40}\d{1,2}:\d{2}\s?-\s?\d{1,2}:\d{2})', html, flags=re.I)
    if tag_matches:
        # join and parse
        tag = '; '.join(tag_matches[:5])
        return parse_opening_hours_tag(tag)
    return None


def process():
    data = json.loads(OSM_REPORT.read_text(encoding='utf-8'))
    out = []
    updated_count = 0
    for rec in data:
        if rec.get('hours'):
            out.append(rec); continue
        lat = rec.get('latitude'); lon = rec.get('longitude')
        print('Requery OSM for', rec.get('id'))
        elements = query_overpass_for_tags(lat, lon, radius=200)
        best = None; best_score=0
        for el in elements:
            tags = el.get('tags', {})
            name = tags.get('name')
            # score by name similarity and distance if center present
            # distance not recomputed here; rely on Overpass closeness
            name_score = 1.0 if (name and rec.get('name') and rec['name'].lower() == name.lower()) else 0.0
            score = name_score
            if score > best_score:
                best_score = score; best=el
        if best:
            tags = best.get('tags', {})
            oh = tags.get('opening_hours')
            website = tags.get('website') or tags.get('contact:website')
            cuisine = tags.get('cuisine')
            cuisine_list = [x.strip() for x in cuisine.split(';')] if cuisine else None
            if oh:
                hours = parse_opening_hours_tag(oh)
                meals = infer_meals(hours, cuisine_list)
                rec.update({'hours': hours if hours else None, 'cuisine': cuisine_list, 'meals': meals, 'sources': ['osm'], 'confidence': 'high' if oh else 'medium'})
                updated_count += 1
                out.append(rec)
                time.sleep(1.0)
                continue
            # if no opening_hours but website present, try website
            if website:
                print(' Fetching website', website)
                jhours = attempt_website_parsing(website)
                if jhours:
                    meals = infer_meals(jhours, cuisine_list)
                    rec.update({'hours': jhours, 'cuisine': cuisine_list, 'meals': meals, 'sources': ['website'], 'confidence': 'high'})
                    updated_count += 1
                    out.append(rec)
                    time.sleep(1.0)
                    continue
        # If no best with tags or no website found, try a looser website check using existing name
        # Attempt to search for website via simple heuristics: try possible domain patterns? Skipping heavy web search to avoid TOS issues.
        rec['confidence'] = 'none'
        out.append(rec)
        time.sleep(1.0)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote', OUT)
    print('Updated entries:', updated_count)

if __name__ == '__main__':
    process()
