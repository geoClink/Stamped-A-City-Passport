"""Find a free 360° panorama on Wikimedia Commons for each landmark.

The Vision Pro app can put you "inside" a landmark by wrapping an
equirectangular (2:1) photo around a big sphere. This script looks for one
such photo per landmark in BuildingRegistry.json and writes the picks to
`Stamped! A City Passport/Resources/LandmarkPanoramas.json`.

How a landmark gets a panorama (most trustworthy source first):
1. Wikidata: an item at the landmark (same name, within 300 m) has a
   "photosphere image" (P4640) - a person already linked photo and place.
2. The landmark's own Commons category (from that Wikidata item) or its
   360°/panorama/interior subcategories hold a 360° photo.
3. City search: 360° photos taken anywhere in the city (three searches per
   city), matched to a landmark when taken within RADIUS_METRES and their
   file name or categories name the landmark.
4. Optional (--geosearch, slow): Commons geosearch around each landmark.

Every pick must also be:
- a 2:1 (equirectangular) image at least MIN_WIDTH pixels wide, tagged as a
  360° / spherical panorama (plenty of flat panoramas are almost 2:1 and
  would look warped wrapped around a sphere);
- licensed CC0, public domain, CC BY or CC BY-SA (never NC/ND);
- not listed in rejected.json, which records the manual review of the
  thumbnails (wrong building, photographer in the shot, ...).

Wikimedia rate-limits busy clients (HTTP 429), so requests go out one at a
time with a pause between them, and back off exponentially on errors. Every
response is cached in cache/ so reruns only fetch what is new.

Usage (no third-party packages needed, standard library only):
    python3 tools/landmark-panoramas/find_panoramas.py            # search + write JSON
    python3 tools/landmark-panoramas/find_panoramas.py --thumbs   # also download 500 px
                                                                  # thumbs (cache/thumbs) for review
    python3 tools/landmark-panoramas/find_panoramas.py --geosearch   # slower, finds a few more
"""

import argparse
import hashlib
import json
import math
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent.parent
REGISTRY_FILE = REPO_ROOT / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"
OUTPUT_FILE = REPO_ROOT / "Stamped! A City Passport" / "Resources" / "LandmarkPanoramas.json"
REJECTED_FILE = TOOL_DIR / "rejected.json"
CACHE_DIR = TOOL_DIR / "cache"
THUMBS_DIR = CACHE_DIR / "thumbs"

COMMONS_API = "https://commons.wikimedia.org/w/api.php"
WIKIDATA_SPARQL = "https://query.wikidata.org/sparql"
# Wikimedia asks scripts to say who they are and how to reach the owner
USER_AGENT = (
    "StampedPanoramaFinder/1.0 (https://georgeclinkscalesdev.com; "
    "finds 360-degree landmark panoramas for the Stamped! visionOS app)"
)

RADIUS_METRES = 200
MIN_WIDTH = 3000          # smaller panoramas look blurry when wrapped around you
ASPECT_TOLERANCE = 0.01   # 2:1 give or take 1% (wide-but-flat panoramas are ~2.06)
APP_IMAGE_WIDTH = 4096    # the size the app downloads (big but not huge)
PAUSE_SECONDS = 0.25      # pause between network requests
PHOTO_EXTENSIONS = (".jpg", ".jpeg", ".png", ".tif", ".tiff", ".webp")
MAX_RETRIES = 7

ALLOWED_LICENSES = {"CC0", "Public domain", "CC BY", "CC BY-SA"}

# Words that don't identify a landmark on their own ("the", "building", ...)
STOP_WORDS = {
    "the", "of", "and", "a", "an", "at", "in", "on", "de", "la", "le", "el",
    "del", "di", "du", "des", "der", "die", "das", "st", "saint",
    "building", "tower", "house", "hall", "center", "centre", "park",
    "museum", "church", "cathedral", "station", "bridge", "square", "street",
    "plaza", "palace", "temple", "library", "university", "college", "old",
    "new", "national", "city", "hotel", "theatre", "theater", "market",
    "garden", "gardens", "art", "arts", "memorial", "monument", "district",
}


@dataclass
class Landmark:
    city: str
    building_id: str
    name: str
    latitude: float | None
    longitude: float | None


@dataclass
class Candidate:
    title: str            # "File:Something.jpg"
    width: int
    height: int
    categories: list[str]
    distance_metres: float | None
    source: str           # "wikidata", "category", "city-search", "geosearch" or "pano360-search"
    latitude: float | None = None    # where the photo was taken (city search only)
    longitude: float | None = None


# MARK: - Network (one request at a time, cached, with backoff)


def cache_path_for(params: dict[str, str]) -> Path:
    key = json.dumps(params, sort_keys=True)
    digest = hashlib.sha256(key.encode()).hexdigest()[:24]
    return CACHE_DIR / "api" / f"{digest}.json"


def fetch_bytes(url: str) -> bytes:
    """GET a URL, retrying with exponential backoff on 429 / 5xx / network errors."""
    delay_seconds = 5.0
    for attempt in range(MAX_RETRIES):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read()
            time.sleep(PAUSE_SECONDS)
            return body
        except urllib.error.HTTPError as error:
            retryable = error.code == 429 or error.code >= 500
            if not retryable:
                raise
            # Respect Retry-After when the server sends one
            retry_after = error.headers.get("Retry-After")
            wait_seconds = float(retry_after) if retry_after and retry_after.isdigit() else delay_seconds
            print(f"  HTTP {error.code}, waiting {wait_seconds:.0f}s (attempt {attempt + 1})", file=sys.stderr)
            time.sleep(wait_seconds)
        except (urllib.error.URLError, TimeoutError) as error:
            print(f"  network error {error}, waiting {delay_seconds:.0f}s", file=sys.stderr)
            time.sleep(delay_seconds)
        delay_seconds *= 2
    raise RuntimeError(f"Gave up after {MAX_RETRIES} attempts: {url}")


def commons_query(params: dict[str, str]) -> dict[str, Any]:
    """Call the Commons API, using the on-disk cache when we've asked before."""
    full_params = {"action": "query", "format": "json", "formatversion": "2", **params}
    cache_file = cache_path_for(full_params)
    if cache_file.exists():
        return json.loads(cache_file.read_text())

    url = f"{COMMONS_API}?{urllib.parse.urlencode(full_params)}"
    delay_seconds = 4.0
    for attempt in range(MAX_RETRIES):
        payload = json.loads(fetch_bytes(url))
        error_code = payload.get("error", {}).get("code", "")
        # The search backend sometimes says it's too busy: treat that like a 429
        if error_code in {"cirrussearch-too-busy-error", "ratelimited", "maxlag"}:
            print(f"  API busy ({error_code}), waiting {delay_seconds:.0f}s", file=sys.stderr)
            time.sleep(delay_seconds)
            delay_seconds *= 2
            continue
        if error_code:
            raise RuntimeError(f"Commons API error {error_code} for {url}")
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps(payload))
        return payload
    raise RuntimeError(f"Commons API stayed busy: {url}")


# MARK: - Registry


def load_landmarks() -> list[Landmark]:
    registry: dict[str, list[dict[str, Any]]] = json.loads(REGISTRY_FILE.read_text())
    landmarks: list[Landmark] = []
    for city, buildings in registry.items():
        for building in buildings:
            landmarks.append(
                Landmark(
                    city=city,
                    building_id=building["id"],
                    name=building["name"],
                    latitude=building.get("latitude"),
                    longitude=building.get("longitude"),
                )
            )
    return landmarks


# MARK: - Matching a file to a landmark


def normalized(text: str) -> str:
    """Lowercase, strip accents and punctuation: 'Café_de Flore' -> 'cafe de flore'."""
    without_accents = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", " ", without_accents.lower()).strip()


def name_variants(landmark_name: str) -> list[str]:
    """The landmark name plus the part before any parenthesis or slash."""
    variants = {landmark_name}
    for separator in ("(", "/", " – ", " - ", ","):
        if separator in landmark_name:
            variants.add(landmark_name.split(separator)[0])
    # "Foo (Bar)" -> also try "Bar"
    for inside in re.findall(r"\(([^)]+)\)", landmark_name):
        variants.add(inside)
    return [normalized(variant) for variant in variants if normalized(variant)]


def significant_words(text: str) -> list[str]:
    return [word for word in normalized(text).split() if word not in STOP_WORDS and len(word) > 2]


def name_match_score(landmark_name: str, candidate: Candidate) -> float:
    """How strongly the file name + categories name this landmark (0 = not at all).

    A full-name match scores 2. Otherwise it's the share of the name's
    significant words that appear, and only counts when at least two such
    words (or one long, distinctive word for one-word names) are present.
    """
    haystack = " " + normalized(candidate.title + " " + " ".join(candidate.categories)) + " "
    for variant in name_variants(landmark_name):
        if len(variant) >= 6 and f" {variant} " in haystack:
            return 2.0
    words = significant_words(landmark_name)
    if not words:
        return 0.0
    found = [word for word in words if f" {word} " in haystack]
    if len(words) == 1:
        # One-word names ("The Circus") are too easy to match by accident, so the
        # whole name must be a category of its own ("Category:The Circus, Bath")
        whole_name = normalized(landmark_name).removeprefix("the ").strip()
        category_names = [normalized(category).removeprefix("the ") for category in candidate.categories]
        return 1.0 if any(name.startswith(whole_name) for name in category_names) else 0.0
    share = len(found) / len(words)
    return share if len(found) >= 2 and share >= 0.6 else 0.0


def is_equirectangular(candidate: Candidate) -> bool:
    """A still photo, 2:1, at least MIN_WIDTH wide (360° videos are 2:1 too)."""
    if not candidate.title.lower().endswith(PHOTO_EXTENSIONS):
        return False
    # Mapillary street-view frames: low quality, and aimed down the street, not at a landmark
    if candidate.title.startswith("File:Mapillary"):
        return False
    if candidate.height == 0 or candidate.width < MIN_WIDTH:
        return False
    return abs(candidate.width / candidate.height - 2.0) <= 2.0 * ASPECT_TOLERANCE


def looks_like_360(candidate: Candidate) -> bool:
    """Bonus signal: categorised or named as a spherical / 360° panorama."""
    text = normalized(candidate.title + " " + " ".join(candidate.categories))
    return any(marker in text for marker in ("360", "equirectangular", "spherical", "pano360", "photosphere"))


# MARK: - Searches


def candidates_from_pages(pages: list[dict[str, Any]], source: str) -> list[Candidate]:
    candidates: list[Candidate] = []
    for page in pages:
        info_list = page.get("imageinfo") or []
        if not info_list:
            continue
        info = info_list[0]
        coordinates = page.get("coordinates") or [{}]
        candidates.append(
            Candidate(
                title=page["title"],
                width=int(info.get("width", 0)),
                height=int(info.get("height", 0)),
                categories=[],
                distance_metres=coordinates[0].get("dist"),
                source=source,
            )
        )
    return candidates


def add_categories(candidates: list[Candidate]) -> None:
    """Fill in categories, only for the few files that are 2:1 (an ordinary,
    non-search API call, so it doesn't count against the busy search backend)."""
    for start in range(0, len(candidates), 20):
        batch = candidates[start : start + 20]
        payload = commons_query({
            "titles": "|".join(candidate.title for candidate in batch),
            "prop": "categories",
            "cllimit": "max",
        })
        categories_by_title = {
            page["title"]: [category["title"].removeprefix("Category:") for category in page.get("categories", [])]
            for page in payload.get("query", {}).get("pages", [])
        }
        for candidate in batch:
            candidate.categories = categories_by_title.get(candidate.title, [])


def nearby_files(landmark: Landmark, generator_params: dict[str, str], limit: int) -> tuple[list[Candidate], bool]:
    """Run a search-backed generator; return the 2:1, big-enough files it found,
    and whether it hit its limit (then there may be more nearby)."""
    payload = commons_query({
        **generator_params,
        "prop": "imageinfo|coordinates",
        "iiprop": "size",
        "colimit": "max",  # the default only returns coordinates for 10 files
        "codistancefrompoint": f"{landmark.latitude}|{landmark.longitude}",
    })
    pages = payload.get("query", {}).get("pages", [])
    source = "geosearch" if "ggscoord" in generator_params else "pano360-search"
    found = [candidate for candidate in candidates_from_pages(pages, source) if is_equirectangular(candidate)]
    return found, len(pages) >= limit


def geosearch_candidates(landmark: Landmark) -> list[Candidate]:
    """2:1 files photographed within RADIUS_METRES (Commons returns the nearest 100)."""
    if landmark.latitude is None or landmark.longitude is None:
        return []
    found, was_full = nearby_files(landmark, {
        "generator": "geosearch",
        "ggscoord": f"{landmark.latitude}|{landmark.longitude}",
        "ggsradius": str(RADIUS_METRES),
        "ggsnamespace": "6",
        "ggslimit": "100",
    }, limit=100)
    # In busy places the nearest 100 files may all be ordinary photos, so also
    # ask specifically for {{Pano360}} files nearby
    if was_full:
        template_files, _ = nearby_files(landmark, {
            "generator": "search",
            "gsrsearch": f"hastemplate:Pano360 nearcoord:{RADIUS_METRES}m,{landmark.latitude},{landmark.longitude}",
            "gsrnamespace": "6",
            "gsrlimit": "50",
        }, limit=50)
        found += template_files
    unique_by_title = {candidate.title: candidate for candidate in found}
    candidates = list(unique_by_title.values())
    add_categories(candidates)
    return candidates


# MARK: - The landmark's own Commons category (via Wikidata)

# Subcategories worth opening when looking for 360° photos of a landmark
PROMISING_SUBCATEGORY = re.compile(r"360|panoram|spheric|equirect|interior|inside|views from", re.IGNORECASE)
MAX_CATEGORIES_PER_LANDMARK = 8
# Big buildings: their Wikidata point can be a few hundred metres from ours
WIKIDATA_RADIUS_METRES = 300


def cached_json(url: str, cache_name: str) -> Any:
    """GET a JSON URL once; later runs read it from cache/."""
    digest = hashlib.sha256((cache_name + url).encode()).hexdigest()[:24]
    cache_file = CACHE_DIR / "other" / f"{digest}.json"
    if cache_file.exists():
        return json.loads(cache_file.read_text())
    payload = json.loads(fetch_bytes(url))
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps(payload))
    return payload


def wikidata_items_near(landmark: Landmark) -> list[dict[str, Any]]:
    """Wikidata items within WIKIDATA_RADIUS_METRES that have a Commons category (P373)."""
    query = (
        "SELECT ?item ?itemLabel ?category ?distance WHERE { SERVICE wikibase:around { "
        "?item wdt:P625 ?coordinates . "
        f'bd:serviceParam wikibase:center "Point({landmark.longitude} {landmark.latitude})"^^geo:wktLiteral . '
        f'bd:serviceParam wikibase:radius "{WIKIDATA_RADIUS_METRES / 1000}" . '
        "bd:serviceParam wikibase:distance ?distance . } "
        "?item wdt:P373 ?category . "
        'SERVICE wikibase:label { bd:serviceParam wikibase:language "en,mul". } }'
    )
    url = f"{WIKIDATA_SPARQL}?{urllib.parse.urlencode({'query': query, 'format': 'json'})}"
    bindings = cached_json(url, "wikidata-around")["results"]["bindings"]
    return [
        {
            "label": binding.get("itemLabel", {}).get("value", ""),
            "category": binding["category"]["value"],
            "distance_metres": float(binding["distance"]["value"]) * 1000,
        }
        for binding in bindings
    ]


def landmark_categories(landmark: Landmark) -> list[str]:
    """The Commons categories of the nearby Wikidata items that are this landmark.

    An item counts when its label (or its category's name) names the
    landmark; the best two matches are used.
    """
    if landmark.latitude is None or landmark.longitude is None:
        return []
    matches: list[tuple[float, float, str]] = []
    for item in wikidata_items_near(landmark):
        as_candidate = Candidate(
            title="",
            width=0,
            height=0,
            categories=[item["label"], item["category"]],
            distance_metres=item["distance_metres"],
            source="wikidata-category",
        )
        score = name_match_score(landmark.name, as_candidate)
        if score > 0:
            matches.append((score, -item["distance_metres"], item["category"]))
    matches.sort(reverse=True)
    categories: list[str] = []
    for _, _, category in matches:
        if category not in categories:
            categories.append(category)
    return categories[:2]


def category_tree_candidates(root_categories: list[str]) -> list[Candidate]:
    """2:1 files in the landmark's category and its panorama/interior subcategories."""
    to_visit = [(category, 0) for category in root_categories]
    visited: set[str] = set()
    found: dict[str, Candidate] = {}
    while to_visit and len(visited) < MAX_CATEGORIES_PER_LANDMARK:
        category, depth = to_visit.pop(0)
        if category in visited:
            continue
        visited.add(category)
        files_payload = commons_query({
            "generator": "categorymembers",
            "gcmtitle": f"Category:{category}",
            "gcmtype": "file",
            "gcmlimit": "500",
            "prop": "imageinfo",
            "iiprop": "size",
        })
        for candidate in candidates_from_pages(files_payload.get("query", {}).get("pages", []), "category"):
            if is_equirectangular(candidate):
                found.setdefault(candidate.title, candidate)
        if depth >= 2:
            continue
        subcategories_payload = commons_query({
            "list": "categorymembers",
            "cmtitle": f"Category:{category}",
            "cmtype": "subcat",
            "cmlimit": "500",
        })
        for member in subcategories_payload.get("query", {}).get("categorymembers", []):
            name = member["title"].removeprefix("Category:")
            if PROMISING_SUBCATEGORY.search(name):
                entry = (name, depth + 1)
                # 360° categories first: they're the most likely to hold what we want
                if re.search(r"360|spheric|equirect", name, re.IGNORECASE):
                    to_visit.insert(0, entry)
                else:
                    to_visit.append(entry)
    candidates = list(found.values())
    add_categories(candidates)
    return candidates


# MARK: - 360° photos around each city (a few searches per city, not per landmark)

# Three ways a 360° photo is usually marked on Commons. Mapillary street-view
# frames are left out: there are millions and they're never named after a landmark.
CITY_SEARCHES = [
    'incategory:"360°_panoramas"',
    "hastemplate:Pano360",
    "intitle:360",
]


def city_centre_and_radius(landmarks: list[Landmark]) -> tuple[float, float, float] | None:
    """Median landmark position and a radius (km) that covers the landmarks, 2-20 km."""
    located = [landmark for landmark in landmarks if landmark.latitude is not None and landmark.longitude is not None]
    if not located:
        return None
    latitudes = sorted(landmark.latitude for landmark in located)  # type: ignore[misc]
    longitudes = sorted(landmark.longitude for landmark in located)  # type: ignore[misc]
    centre_latitude = latitudes[len(latitudes) // 2]
    centre_longitude = longitudes[len(longitudes) // 2]
    farthest_metres = max(
        distance_metres(centre_latitude, centre_longitude, landmark.latitude, landmark.longitude)  # type: ignore[arg-type]
        for landmark in located
    )
    radius_km = min(20.0, max(2.0, farthest_metres / 1000 + 0.3))
    return centre_latitude, centre_longitude, radius_km


def city_search_pool(landmarks: list[Landmark]) -> list[Candidate]:
    """Every big 2:1 file marked as 360° that was photographed in the city."""
    centre = city_centre_and_radius(landmarks)
    if centre is None:
        return []
    centre_latitude, centre_longitude, radius_km = centre
    titles: set[str] = set()
    for marker in CITY_SEARCHES:
        payload = commons_query({
            "list": "search",
            "srsearch": f"{marker} nearcoord:{math.ceil(radius_km)}km,{centre_latitude:.5f},{centre_longitude:.5f} -intitle:Mapillary",
            "srnamespace": "6",
            "srlimit": "500",
            "srprop": "",
        })
        titles.update(result["title"] for result in payload.get("query", {}).get("search", []))

    # Sizes and camera positions, 50 files per (ordinary, non-search) request
    pool: list[Candidate] = []
    sorted_titles = sorted(titles)
    for start in range(0, len(sorted_titles), 50):
        payload = commons_query({
            "titles": "|".join(sorted_titles[start : start + 50]),
            "prop": "imageinfo|coordinates",
            "iiprop": "size",
            "colimit": "max",  # the default only returns coordinates for 10 files
        })
        for page in payload.get("query", {}).get("pages", []):
            info_list = page.get("imageinfo") or []
            coordinates = page.get("coordinates") or []
            if not info_list or not coordinates:
                continue
            candidate = Candidate(
                title=page["title"],
                width=int(info_list[0].get("width", 0)),
                height=int(info_list[0].get("height", 0)),
                categories=[],
                distance_metres=None,
                source="city-search",
                latitude=coordinates[0]["lat"],
                longitude=coordinates[0]["lon"],
            )
            if is_equirectangular(candidate):
                pool.append(candidate)
    add_categories(pool)
    # Every search above marks a 360° photo, but "intitle:360" can also catch
    # e.g. "Route 360": keep only files that really look like 360° panoramas
    return [candidate for candidate in pool if looks_like_360(candidate) or "Pano360" in " ".join(candidate.categories)]


def city_pool_candidates(landmark: Landmark, pool: list[Candidate]) -> list[Candidate]:
    """Files from the city pool taken within RADIUS_METRES that name the landmark."""
    if landmark.latitude is None or landmark.longitude is None:
        return []
    nearby: list[Candidate] = []
    for candidate in pool:
        distance = distance_metres(landmark.latitude, landmark.longitude, candidate.latitude, candidate.longitude)  # type: ignore[arg-type]
        if distance <= RADIUS_METRES and name_match_score(landmark.name, candidate) > 0:
            nearby.append(Candidate(**{**candidate.__dict__, "distance_metres": distance}))
    return nearby


# MARK: - Wikidata "photosphere image" (P4640)


def wikidata_photospheres() -> list[dict[str, Any]]:
    """Every Wikidata item with a photosphere image and coordinates (one request).

    Someone has already said "this 360° photo shows this place", so a match
    here is the most trustworthy kind.
    """
    cache_file = CACHE_DIR / "wikidata_photospheres.json"
    if not cache_file.exists():
        query = (
            "SELECT ?item ?itemLabel ?coord ?pano WHERE { ?item wdt:P4640 ?pano . ?item wdt:P625 ?coord . "
            'SERVICE wikibase:label { bd:serviceParam wikibase:language "en,mul,fr,de,es,it". } }'
        )
        url = f"{WIKIDATA_SPARQL}?{urllib.parse.urlencode({'query': query, 'format': 'json'})}"
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_bytes(fetch_bytes(url))
    bindings = json.loads(cache_file.read_text())["results"]["bindings"]

    photospheres: list[dict[str, Any]] = []
    for binding in bindings:
        point = binding["coord"]["value"]  # "Point(longitude latitude)"
        match = re.match(r"Point\(([-\d.eE]+) ([-\d.eE]+)\)", point)
        if not match:
            continue
        file_name = urllib.parse.unquote(binding["pano"]["value"].rsplit("/", 1)[-1]).replace("_", " ")
        photospheres.append({
            "label": binding.get("itemLabel", {}).get("value", ""),
            "longitude": float(match.group(1)),
            "latitude": float(match.group(2)),
            "title": f"File:{file_name}",
        })
    return photospheres


def distance_metres(latitude_a: float, longitude_a: float, latitude_b: float, longitude_b: float) -> float:
    """Flat-earth distance: plenty accurate over a few hundred metres."""
    degrees_to_radians = math.pi / 180
    east_west = (longitude_b - longitude_a) * degrees_to_radians * math.cos((latitude_a + latitude_b) / 2 * degrees_to_radians)
    north_south = (latitude_b - latitude_a) * degrees_to_radians
    return 6_371_000 * math.hypot(east_west, north_south)


def wikidata_candidates(landmark: Landmark, photospheres: list[dict[str, Any]]) -> list[Candidate]:
    """Photospheres of Wikidata items near the landmark whose label names it."""
    if landmark.latitude is None or landmark.longitude is None:
        return []
    candidates: list[Candidate] = []
    for photosphere in photospheres:
        distance = distance_metres(landmark.latitude, landmark.longitude, photosphere["latitude"], photosphere["longitude"])
        if distance > RADIUS_METRES:
            continue
        candidate = Candidate(
            title=photosphere["title"],
            width=0,
            height=0,
            # The item's label is matched against the landmark's name like a category
            categories=[photosphere["label"]],
            distance_metres=distance,
            source="wikidata",
        )
        if name_match_score(landmark.name, candidate) > 0:
            candidates.append(candidate)
    return candidates


def file_details(title: str) -> dict[str, Any]:
    """Licence, author and URLs (full size + an app-sized thumbnail) for one file."""
    payload = commons_query({
        "titles": title,
        "prop": "imageinfo",
        "iiprop": "url|size|extmetadata",
        "iiurlwidth": str(APP_IMAGE_WIDTH),
        "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Credit|UsageTerms|Copyrighted",
    })
    pages = payload.get("query", {}).get("pages", [])
    return pages[0] if pages else {}


# MARK: - Licences and credits


def strip_html(html_text: str) -> str:
    text = re.sub(r"<[^>]+>", "", html_text)
    text = text.replace("&amp;", "&").replace("&nbsp;", " ").replace("&#039;", "'").replace("&quot;", '"')
    return re.sub(r"\s+", " ", text).strip()


def simplified_license(short_name: str) -> str | None:
    """Map Commons' licence names to our allowed set, or None if not allowed.

    'CC BY-SA 4.0' -> 'CC BY-SA', 'CC0' -> 'CC0', 'Public domain' -> 'Public domain'.
    Anything with NC (non-commercial) or ND (no derivatives) is refused.
    """
    upper_name = short_name.upper()
    if "NC" in upper_name.replace("-", " ").split() or "-NC" in upper_name or "-ND" in upper_name:
        return None
    if upper_name.startswith("CC0") or upper_name == "CC ZERO":
        return "CC0"
    if upper_name.startswith("PUBLIC DOMAIN") or upper_name.startswith("PD"):
        return "Public domain"
    if upper_name.startswith("CC BY-SA") or upper_name.startswith("CC-BY-SA"):
        return "CC BY-SA"
    if upper_name.startswith("CC BY") or upper_name.startswith("CC-BY"):
        return "CC BY"
    return None


def without_query(url: str) -> str:
    """Drop Commons' ?utm_source=... tracking parameters."""
    return url.split("?")[0]


def panorama_record(landmark: Landmark, candidate: Candidate) -> dict[str, Any] | None:
    page = file_details(candidate.title)
    info_list = page.get("imageinfo") or []
    if not info_list:
        return None
    info = info_list[0]
    # Wikidata candidates arrive without a size: check they really are 2:1 here
    candidate.width = int(info.get("width", 0))
    candidate.height = int(info.get("height", 0))
    if not is_equirectangular(candidate):
        print(f"    not a big 2:1 image ({candidate.width}x{candidate.height}): {candidate.title}")
        return None
    metadata = info.get("extmetadata", {})
    license_name = metadata.get("LicenseShortName", {}).get("value", "")
    license_kind = simplified_license(license_name)
    if license_kind is None:
        print(f"    licence not allowed ({license_name!r}): {candidate.title}")
        return None
    author = strip_html(metadata.get("Artist", {}).get("value", "")) or "Unknown author"
    license_url = metadata.get("LicenseUrl", {}).get("value", "")
    if license_kind == "Public domain" and not license_url:
        license_url = "https://creativecommons.org/publicdomain/mark/1.0/"
    if license_kind == "CC0" and not license_url:
        license_url = "https://creativecommons.org/publicdomain/zero/1.0/"
    if license_url.startswith("http://"):
        license_url = "https://" + license_url.removeprefix("http://")
    return {
        "buildingID": landmark.building_id,
        "landmarkName": landmark.name,
        "city": landmark.city,
        "fileTitle": candidate.title,
        "foundVia": candidate.source,
        "filePageURL": info["descriptionurl"],
        "imageURL": without_query(info.get("thumburl") or info["url"]),
        "fullSizeURL": without_query(info["url"]),
        "width": info["width"],
        "height": info["height"],
        "author": author[:120],
        "license": license_kind,
        "licenseName": license_name,
        "licenseURL": license_url,
    }


# MARK: - Main


def best_candidate(
    landmark: Landmark,
    rejected_titles: set[str],
    photospheres: list[dict[str, Any]],
    city_pool: list[Candidate],
    use_geosearch: bool,
) -> Candidate | None:
    """The best 360° file of the landmark, trying the most trustworthy source first.

    1. A Wikidata "photosphere image" of an item that is this landmark.
    2. A 360°-tagged 2:1 file in the landmark's own Commons category tree.
    3. A 360° photo taken within RADIUS_METRES whose name or categories name
       the landmark (from the city-wide searches).
    4. (Optional, slow) a 360°-tagged 2:1 file photographed nearby whose
       name or categories name the landmark.
    """
    from_wikidata = [
        candidate for candidate in wikidata_candidates(landmark, photospheres) if candidate.title not in rejected_titles
    ]
    if from_wikidata:
        return min(from_wikidata, key=lambda candidate: candidate.distance_metres or 0)

    from_categories = [
        candidate for candidate in category_tree_candidates(landmark_categories(landmark))
        if candidate.title not in rejected_titles and looks_like_360(candidate)
    ]
    if from_categories:
        # Bigger is sharper
        return max(from_categories, key=lambda candidate: candidate.width)

    from_city = [
        candidate for candidate in city_pool_candidates(landmark, city_pool) if candidate.title not in rejected_titles
    ]
    if from_city:
        return max(from_city, key=lambda candidate: (name_match_score(landmark.name, candidate), -(candidate.distance_metres or 0)))

    if not use_geosearch:
        return None
    scored = [
        (name_match_score(landmark.name, candidate), candidate)
        for candidate in geosearch_candidates(landmark)
        if candidate.title not in rejected_titles and looks_like_360(candidate)
    ]
    scored = [(score, candidate) for score, candidate in scored if score > 0]
    if not scored:
        return None
    scored.sort(
        key=lambda pair: (pair[0], -(pair[1].distance_metres or RADIUS_METRES), pair[1].width),
        reverse=True,
    )
    return scored[0][1]


def download_thumb(record: dict[str, Any]) -> Path:
    """A 500 px preview, for checking the right building by eye."""
    THUMBS_DIR.mkdir(parents=True, exist_ok=True)
    thumb_file = THUMBS_DIR / f"{record['buildingID']}.jpg"
    if not thumb_file.exists():
        small_url = re.sub(r"/\d+px-", "/500px-", record["imageURL"]) if "/thumb/" in record["imageURL"] else record["imageURL"]
        thumb_file.write_bytes(fetch_bytes(small_url))
    return thumb_file


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--thumbs", action="store_true", help="download 500 px previews for review")
    parser.add_argument("--geosearch", action="store_true",
                        help="also try Commons geosearch (slow: the search backend is often 'too busy')")
    parser.add_argument("--limit", type=int, default=0, help="only process the first N landmarks (testing)")
    arguments = parser.parse_args()

    # rejected.json: {"File:Title.jpg": "reason", "building_id::File:Title.jpg": "reason", ...}
    # A plain title is rejected for every landmark; "building_id::" rejects it
    # for that landmark only (e.g. a good photo of the church next door).
    rejected: dict[str, str] = json.loads(REJECTED_FILE.read_text()) if REJECTED_FILE.exists() else {}
    photospheres = wikidata_photospheres()
    landmarks = load_landmarks()
    if arguments.limit:
        landmarks = landmarks[: arguments.limit]

    landmarks_by_city: dict[str, list[Landmark]] = {}
    for landmark in landmarks:
        landmarks_by_city.setdefault(landmark.city, []).append(landmark)
    city_pools: dict[str, list[Candidate]] = {}

    panoramas: dict[str, dict[str, Any]] = {}
    for index, landmark in enumerate(landmarks, start=1):
        if index % 50 == 0:
            print(f"[{index}/{len(landmarks)}] {len(panoramas)} panoramas so far", flush=True)
        if landmark.city not in city_pools:
            city_pools[landmark.city] = city_search_pool(landmarks_by_city[landmark.city])
        rejected_titles = {
            key.split("::", 1)[-1]
            for key in rejected
            if "::" not in key or key.startswith(f"{landmark.building_id}::")
        }
        candidate = best_candidate(landmark, rejected_titles, photospheres, city_pools[landmark.city], arguments.geosearch)
        if candidate is None:
            continue
        record = panorama_record(landmark, candidate)
        if record is None:
            continue
        print(f"  {landmark.city} / {landmark.name}: {candidate.title}", flush=True)
        if arguments.thumbs:
            download_thumb(record)
        panoramas[landmark.building_id] = record

    # The app only needs these fields; city/name/fileTitle help humans reading the file
    OUTPUT_FILE.write_text(json.dumps(dict(sorted(panoramas.items())), indent=2, ensure_ascii=False) + "\n")

    cities = sorted({record["city"] for record in panoramas.values()})
    print(f"\nPanoramas for {len(panoramas)} of {len(landmarks)} landmarks in {len(cities)} cities/campuses:")
    print(", ".join(cities))
    print(f"Wrote {OUTPUT_FILE.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
