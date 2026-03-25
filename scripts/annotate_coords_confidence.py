#!/usr/bin/env python3
"""
Annotate each building in BuildingRegistry.json with a confidence label based on static heuristics:
- 'high' : coordinates present, not flagged as outlier, not low-precision, not duplicate, not recently changed
- 'medium' : coordinates present but one minor flag (e.g., changed recently)
- 'review' : outlier, low precision, duplicate hotspot, or missing

Writes results to scripts/coords_confidence.json (does not modify the registry).
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
REG = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
VALID = ROOT / 'scripts' / 'validate_report.json'
OUT = ROOT / 'scripts' / 'coords_confidence.json'

CHANGED_IDS = {'auh_al_bahr_towers','bom_apple_bkc','sha_apple_campus','bali-potato-head','jakarta-istiqlal','ist_suleymaniye','br_ibirapuera_auditorium'}

# load registry
reg = json.loads(REG.read_text(encoding='utf-8'))
# flatten
buildings = []
for city, bl in reg.items():
    if not isinstance(bl, list):
        continue
    for b in bl:
        buildings.append({'city': city, 'id': b.get('id'), 'name': b.get('name'), 'lat': b.get('latitude'), 'lon': b.get('longitude')})

# load outliers from validate_report if available
outlier_ids = set()
if VALID.exists():
    vr = json.loads(VALID.read_text(encoding='utf-8'))
    for o in vr.get('outliers', []):
        outlier_ids.add(o.get('id'))

# helper functions
def hav(lat1,lon1,lat2,lon2):
    R=6371000.0
    phi1=math.radians(lat1); phi2=math.radians(lat2)
    dphi=math.radians(lat2-lat1); dl=math.radians(lon2-lon1)
    a=math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dl/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

# duplicates map
coord_map = {}
for b in buildings:
    lat = b['lat']; lon = b['lon']
    if lat is None or lon is None:
        continue
    key = (round(float(lat),6), round(float(lon),6))
    coord_map.setdefault(key, []).append(b['id'])

# low-precision detection
low_precision_ids = set()
for b in buildings:
    lat=b['lat']; lon=b['lon']; bid=b['id']
    if lat is None or lon is None:
        low_precision_ids.add(bid)
        continue
    # flag integer degrees (implausible) or < 4 decimal places
    def decimals(x):
        s=str(x)
        if '.' in s:
            return len(s.split('.')[-1].rstrip('0'))
        return 0
    if decimals(lat) < 3 or decimals(lon) < 3:
        low_precision_ids.add(bid)

# duplicate hotspots
dup_hotspot_ids = set()
for k, ids in coord_map.items():
    if len(ids) > 6:  # more than 6 buildings sharing same rounded coordinate
        dup_hotspot_ids.update(ids)

# now annotate
annotations = {}
counts = {'high':0,'medium':0,'review':0}
for b in buildings:
    bid=b['id']; lat=b['lat']; lon=b['lon']
    if lat is None or lon is None:
        label='review'
        reason='missing'
    elif bid in outlier_ids:
        label='review'; reason='outlier'
    elif bid in low_precision_ids:
        label='review'; reason='low_precision'
    elif bid in dup_hotspot_ids:
        label='review'; reason='duplicate_hotspot'
    elif bid in CHANGED_IDS:
        label='medium'; reason='recent_change'
    else:
        label='high'; reason='ok'
    annotations[bid] = {'city': b['city'], 'name': b['name'], 'latitude': lat, 'longitude': lon, 'confidence': label, 'reason': reason}
    counts[label]+=1

OUT.write_text(json.dumps({'generated':True, 'counts':counts, 'annotations':annotations}, ensure_ascii=False, indent=2), encoding='utf-8')
print('Wrote', OUT)
print('Counts:', counts)
