"""Build LandmarkAccessibility.json from OpenStreetMap wheelchair tags.

Usage (from tools/accessibility-data, with the venv active):
    python build_accessibility.py              # query Overpass, write the JSON
    python build_accessibility.py --offline    # reuse cached Overpass answers only

For every landmark in BuildingRegistry.json we look for the OpenStreetMap
feature that IS that landmark: same (or nearly the same) name, and within
about 150 m of the landmark's coordinates. We copy only what OSM says:

    wheelchair          yes / limited / no
    toilets:wheelchair  yes / no (only when tagged)

Landmarks with no confident match, or whose match has no wheelchair tag, are
left out. We never guess.

Overpass usage policy: one request at a time, a pause between requests,
backing off on 429 (too many requests) and 504 (server busy), and a
User-Agent that says who we are. Answers are cached in .cache/ so a re-run
does not ask the server again.
"""

import argparse
import json
import math
import re
import sys
import time
import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parents[2]
RESOURCES = REPO_ROOT / "Stamped! A City Passport" / "Resources"
REGISTRY_PATH = RESOURCES / "BuildingRegistry.json"
OUTPUT_PATH = RESOURCES / "LandmarkAccessibility.json"
CACHE_DIR = Path(__file__).resolve().parent / ".cache"

# Public Overpass servers. We use one at a time and move to the next only when
# the current one keeps failing (502/504 or no answer).
OVERPASS_MIRRORS = [
    # mail.ru's mirror kept answering on 2026-10-30 while the others were down
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
]
USER_AGENT = (
    "Stamped-A-City-Passport/2.9 (https://georgeclinkscalesdev.com; "
    "build-time landmark wheelchair-access data)"
)
SECONDS_BETWEEN_REQUESTS = 2.0
MAX_ATTEMPTS = 6
FIRST_BACKOFF_SECONDS = 10.0
MAX_BACKOFF_SECONDS = 60.0

# A feature counts as "the landmark" only if it is this close (metres) to the
# landmark's pin, or the pin sits inside the feature's outline.
MAX_DISTANCE_METERS = 150.0
# How similar two names must be (0–1) when they are not exactly equal.
MIN_NAME_SIMILARITY = 0.88
# The widest a query box may be, in degrees (0.15° is about 15 km), so one
# query never covers a huge area.
MAX_BOX_DEGREES = 0.15
# Half the size of the small box we search around each pin (0.003° is about
# 330 m north–south): roomy enough for big buildings whose outline starts a
# little away from the pin.
BOX_PADDING_DEGREES = 0.003

ALLOWED_WHEELCHAIR_VALUES = {"yes", "limited", "no"}
ALLOWED_TOILET_VALUES = {"yes", "no"}
# The feature must be a place people visit, not a bus stop, entrance or
# car park that happens to share the landmark's name.
FEATURE_KEYS = {"building", "tourism", "amenity", "historic", "leisure", "man_made", "shop", "office"}
REJECTED_KEYS = {"highway", "public_transport", "railway", "entrance", "barrier", "route"}
REJECTED_AMENITIES = {
    "parking", "parking_entrance", "bicycle_parking", "motorcycle_parking",
    "toilets", "bench", "shelter", "taxi", "atm", "drinking_water", "charging_station",
}
GENERIC_NAMES = {
    "abbey", "arena", "building", "cathedral", "center", "centre", "chapel", "church",
    "gallery", "hall", "library", "museum", "park", "stadium", "station", "theater",
    "theatre", "tower", "union", "university", "college", "school", "market", "bridge",
}
NAME_KEYS = ["name", "name:en", "int_name", "official_name", "alt_name", "old_name", "short_name"]


@dataclass
class Landmark:
    building_id: str
    name: str
    group_name: str
    latitude: float
    longitude: float


@dataclass
class Match:
    building_id: str
    element_type: str
    element_id: int
    wheelchair: str
    toilets_wheelchair: str | None
    name_score: float
    distance_meters: float


def load_landmarks() -> dict[str, list[Landmark]]:
    """Read the registry and return its landmarks grouped by city or campus."""
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    landmarks_by_group: dict[str, list[Landmark]] = {}
    for group_name, buildings in registry.items():
        landmarks_by_group[group_name] = [
            Landmark(
                building_id=building["id"],
                name=building["name"],
                group_name=group_name,
                latitude=float(building["latitude"]),
                longitude=float(building["longitude"]),
            )
            for building in buildings
            if building.get("latitude") and building.get("longitude")
        ]
    return landmarks_by_group


def split_into_query_boxes(landmarks: list[Landmark]) -> list[list[Landmark]]:
    """Group a city's landmarks into boxes at most MAX_BOX_DEGREES wide, one query each.

    Most cities fit in one box. Spread-out ones (Bali, Denver) get a few small
    boxes instead of one giant box full of data we don't need.
    """
    boxes: list[list[Landmark]] = []
    for landmark in sorted(landmarks, key=lambda item: (item.latitude, item.longitude)):
        for box in boxes:
            # Would the box still be small enough with this landmark in it?
            latitudes = [member.latitude for member in box] + [landmark.latitude]
            longitudes = [member.longitude for member in box] + [landmark.longitude]
            if (max(latitudes) - min(latitudes) <= MAX_BOX_DEGREES
                    and max(longitudes) - min(longitudes) <= MAX_BOX_DEGREES):
                box.append(landmark)
                break
        else:
            boxes.append([landmark])
    return boxes


def landmark_box(landmark: Landmark) -> tuple[float, float, float, float]:
    """South, west, north, east: a small box (a few hundred metres) around one pin."""
    return (
        round(landmark.latitude - BOX_PADDING_DEGREES, 5),
        round(landmark.longitude - BOX_PADDING_DEGREES, 5),
        round(landmark.latitude + BOX_PADDING_DEGREES, 5),
        round(landmark.longitude + BOX_PADDING_DEGREES, 5),
    )


def overpass_query(landmarks: list[Landmark]) -> str:
    """One query for a group of landmarks: a small box around each pin, joined.

    Only named features that carry a wheelchair tag, and only right around the
    landmarks rather than the whole city, so the server has little to do.
    """
    # Bus stops and bus/tram routes carry wheelchair tags too; leave them out.
    feature_filter = 'nwr["name"]["wheelchair"][!"highway"][!"public_transport"][!"route"]'
    parts = []
    for landmark in landmarks:
        south, west, north, east = landmark_box(landmark)
        parts.append(f"{feature_filter}({south},{west},{north},{east});")
    return "[out:json][timeout:120];(" + "".join(parts) + ");out tags center bb;"


# Which mirror we're on; it stays put while it works.
current_mirror_index = 0
# Query boxes Overpass never answered, so the summary can list them.
failed_boxes: list[str] = []


def fetch_overpass(query: str, cache_name: str, offline: bool) -> list[dict]:
    """Return Overpass elements for a query, using the cache when we can.

    Returns an empty list (and remembers the box) if every attempt fails, so
    one bad box doesn't stop the whole run. Re-running asks again for it.
    """
    global current_mirror_index
    cache_path = CACHE_DIR / f"{cache_name}.json"
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))["elements"]
    if offline:
        print(f"  (offline) no cache for {cache_name}, skipping")
        return []

    wait_seconds = FIRST_BACKOFF_SECONDS
    for attempt in range(1, MAX_ATTEMPTS + 1):
        time.sleep(SECONDS_BETWEEN_REQUESTS)  # one request at a time, with a pause
        mirror = OVERPASS_MIRRORS[current_mirror_index]
        problem = ""
        try:
            response = requests.post(
                mirror,
                data={"data": query},
                headers={"User-Agent": USER_AGENT},
                timeout=180,
            )
            # 429 = too many requests, 502/503/504 = server busy
            if response.status_code in (429, 502, 503, 504):
                problem = f"HTTP {response.status_code}"
            else:
                response.raise_for_status()
                payload = response.json()
                # Overpass can answer 200 with a "remark" when the query timed out.
                if "runtime error" in payload.get("remark", ""):
                    problem = f"Overpass remark: {payload['remark']}"
                else:
                    CACHE_DIR.mkdir(exist_ok=True)
                    cache_path.write_text(json.dumps(payload), encoding="utf-8")
                    return payload["elements"]
        except (requests.RequestException, ValueError) as error:
            problem = f"error {error}"

        print(f"  {problem} from {mirror} (attempt {attempt}); waiting {wait_seconds:.0f}s")
        time.sleep(wait_seconds)
        wait_seconds = min(wait_seconds * 2, MAX_BACKOFF_SECONDS)
        # After two failures in a row, try the next mirror. 429 means "slow
        # down", so for that one we only wait, never switch away.
        if attempt % 2 == 0 and not problem.startswith("HTTP 429"):
            current_mirror_index = (current_mirror_index + 1) % len(OVERPASS_MIRRORS)

    print(f"  giving up on {cache_name} for now")
    failed_boxes.append(cache_name)
    return []


def normalize_name(name: str) -> str:
    """Lowercase, remove accents and punctuation, drop a leading 'the'."""
    without_accents = "".join(
        character
        for character in unicodedata.normalize("NFKD", name)
        if not unicodedata.combining(character)
    )
    lowered = without_accents.casefold().replace("&", " and ")
    # Drop text in brackets, e.g. "Sagrada Família (Basilica)".
    lowered = re.sub(r"\(.*?\)", " ", lowered)
    words = re.sub(r"[^\w]+", " ", lowered).split()
    if words and words[0] == "the":
        words = words[1:]
    return " ".join(words)


def name_similarity(landmark_name: str, osm_name: str) -> float:
    """1.0 for the same name, otherwise a 0–1 similarity score."""
    left = normalize_name(landmark_name)
    right = normalize_name(osm_name)
    if not left or not right:
        return 0.0
    if left == right:
        return 1.0
    return SequenceMatcher(None, left, right).ratio()


def distance_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle (haversine) distance between two points."""
    earth_radius = 6_371_000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    half_chord = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    )
    return 2 * earth_radius * math.asin(math.sqrt(half_chord))


def element_distance(landmark: Landmark, element: dict) -> float:
    """0 when the pin is inside the feature's outline box, else metres to its centre."""
    bounds = element.get("bounds")
    if bounds and (
        bounds["minlat"] <= landmark.latitude <= bounds["maxlat"]
        and bounds["minlon"] <= landmark.longitude <= bounds["maxlon"]
    ):
        return 0.0
    center = element.get("center") or {"lat": element.get("lat"), "lon": element.get("lon")}
    if center["lat"] is None or center["lon"] is None:
        return math.inf
    return distance_meters(landmark.latitude, landmark.longitude, center["lat"], center["lon"])


def is_visitable_feature(tags: dict[str, str]) -> bool:
    """True for buildings and attractions; False for bus stops, entrances, car parks."""
    if any(key in tags for key in REJECTED_KEYS):
        return False
    if tags.get("amenity") in REJECTED_AMENITIES:
        return False
    return any(key in tags for key in FEATURE_KEYS)


def other_landmark_names(landmark: Landmark) -> list[str]:
    """Shorter forms of the landmark's name that OSM often uses instead.

    "Bath Guildhall" is just "Guildhall" in OSM, and "General Motors Building
    (Cadillac Place)" may be mapped as "Cadillac Place". These only count when
    they match an OSM name exactly.
    """
    alternatives: list[str] = []
    # The text in brackets on its own, when it's a real name of two or more words.
    # One word is usually an abbreviation or a neighbourhood: "(MIT)" would match
    # the whole university, "(Leidseplein)" the square outside.
    for bracketed in re.findall(r"\((.*?)\)", landmark.name):
        if len(normalize_name(bracketed).split()) >= 2:
            alternatives.append(bracketed)
    # The name without the city or campus name in it
    city_words = normalize_name(landmark.group_name).split()
    name_words = normalize_name(landmark.name).split()
    without_city = [word for word in name_words if word not in city_words]
    # Not when all that's left is a common word ("Michigan Stadium" → "Stadium"):
    # plenty of nearby things are called that.
    if without_city and len(without_city) < len(name_words) and " ".join(without_city) not in GENERIC_NAMES:
        alternatives.append(" ".join(without_city))
    return [alternative for alternative in alternatives if normalize_name(alternative)]


def best_name_score(landmark: Landmark, tags: dict[str, str]) -> float:
    """Highest similarity between the landmark name and any of the feature's names."""
    shorter_names = {normalize_name(alternative) for alternative in other_landmark_names(landmark)}
    scores = [0.0]
    for key in NAME_KEYS:
        # alt_name can hold several names separated by ";".
        for osm_name in tags.get(key, "").split(";"):
            if not osm_name.strip():
                continue
            scores.append(name_similarity(landmark.name, osm_name.strip()))
            # A shorter form only counts as an exact match, never "nearly the same"
            if normalize_name(osm_name) in shorter_names:
                scores.append(1.0)
    return max(scores)


def find_match(landmark: Landmark, elements: list[dict]) -> Match | None:
    """The one OSM feature that confidently is this landmark, or None."""
    candidates: list[Match] = []
    for element in elements:
        tags = element.get("tags", {})
        wheelchair_value = tags.get("wheelchair", "").strip().lower()
        if wheelchair_value not in ALLOWED_WHEELCHAIR_VALUES:
            continue
        if not is_visitable_feature(tags):
            continue
        name_score = best_name_score(landmark, tags)
        if name_score < MIN_NAME_SIMILARITY:
            continue
        distance = element_distance(landmark, element)
        if distance > MAX_DISTANCE_METERS:
            continue
        toilets_value = tags.get("toilets:wheelchair", "").strip().lower()
        candidates.append(
            Match(
                building_id=landmark.building_id,
                element_type=element["type"],
                element_id=element["id"],
                wheelchair=wheelchair_value,
                toilets_wheelchair=toilets_value if toilets_value in ALLOWED_TOILET_VALUES else None,
                name_score=name_score,
                distance_meters=distance,
            )
        )

    if not candidates:
        return None
    # Best name first, then closest.
    candidates.sort(key=lambda match: (-match.name_score, match.distance_meters))
    best = candidates[0]
    # If an equally good match disagrees about access, we can't tell which is
    # right, so we skip the landmark rather than guess.
    for other in candidates[1:]:
        if other.name_score == best.name_score and other.wheelchair != best.wheelchair:
            return None
    return best


def cache_name_for(group_name: str, box_index: int) -> str:
    """A safe file name for one city/campus query box."""
    safe_group = re.sub(r"[^\w]+", "_", normalize_name(group_name)).strip("_")
    return f"{safe_group}_{box_index}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--offline", action="store_true", help="use cached Overpass answers only")
    arguments = parser.parse_args()

    landmarks_by_group = load_landmarks()
    total_landmarks = sum(len(landmarks) for landmarks in landmarks_by_group.values())
    matches: dict[str, Match] = {}

    for group_index, (group_name, landmarks) in enumerate(landmarks_by_group.items(), start=1):
        boxes = split_into_query_boxes(landmarks)
        group_match_count = 0
        for box_index, box_landmarks in enumerate(boxes):
            elements = fetch_overpass(
                overpass_query(box_landmarks),
                cache_name_for(group_name, box_index),
                arguments.offline,
            )
            for landmark in box_landmarks:
                match = find_match(landmark, elements)
                if match:
                    matches[landmark.building_id] = match
                    group_match_count += 1
        print(f"[{group_index}/{len(landmarks_by_group)}] {group_name}: {group_match_count}/{len(landmarks)} landmarks")

    output: dict[str, dict[str, str]] = {}
    for building_id in sorted(matches):
        match = matches[building_id]
        entry = {
            "wheelchair": match.wheelchair,
            "osmType": match.element_type,
            "osmID": str(match.element_id),
        }
        if match.toilets_wheelchair:
            entry["toiletsWheelchair"] = match.toilets_wheelchair
        output[building_id] = entry

    OUTPUT_PATH.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Coverage stats.
    print()
    print(f"Landmarks with data: {len(output)} of {total_landmarks} ({len(output) / total_landmarks:.1%})")
    for value in ["yes", "limited", "no"]:
        count = sum(1 for entry in output.values() if entry["wheelchair"] == value)
        print(f"  wheelchair={value}: {count}")
    toilet_count = sum(1 for entry in output.values() if "toiletsWheelchair" in entry)
    print(f"  with toilets:wheelchair: {toilet_count}")
    if failed_boxes:
        print(f"Overpass never answered {len(failed_boxes)} boxes (re-run to retry): {', '.join(failed_boxes)}")
    print(f"Wrote {OUTPUT_PATH.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
