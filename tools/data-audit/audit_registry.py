"""Audit BuildingRegistry.json for data problems.

Usage (from tools/data-audit, with the venv active):
    python audit_registry.py                    # print report to the terminal
    python audit_registry.py --output report.md # also save it to a file

This script only READS the registry. It never changes the JSON: every
finding is a suggestion for a human to check against a reliable source.
"""

import argparse
import json
import math
import re
import statistics
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import geonamescache

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = REPO_ROOT / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"
CITY_ENUM_PATH = REPO_ROOT / "Stamped! A City Passport" / "Models" / "Model.swift"

# A landmark further than this from the middle of its city gets flagged.
FAR_FROM_CITY_KM = 25.0
# A city whose landmarks sit this far from the real city centre is probably wrong.
CITY_CENTRE_MISMATCH_KM = 30.0
# The quiz builds 4 answer choices from one city's landmarks.
MIN_MAPPABLE_LANDMARKS = 4
# Tallest building on Earth (Burj Khalifa) is ~828 m with 163 floors.
MAX_HEIGHT_METERS = 830.0
MAX_STORIES = 163
# Normal buildings are roughly 2.5–6 m per storey; allow wide room for
# cathedrals, towers and halls before flagging.
MIN_METERS_PER_STORY = 1.5
MAX_METERS_PER_STORY = 40.0
PLACEHOLDER_TEXT = {"", "tbd", "n/a", "na", "?", "todo", "none", "-"}

# Some registry city names are not the name GeoNames uses, or are ambiguous
# (there is a Portland in Maine and Oregon). Map them to a GeoNames name plus
# an ISO country code so we pick the right reference city.
CITY_LOOKUP_OVERRIDES: dict[str, tuple[str, str]] = {
    "Minnesota": ("Minneapolis", "US"),
    "Washington D.C.": ("Washington", "US"),
    "Portland": ("Portland", "US"),
    "Victoria": ("Victoria", "CA"),
    "Central Jakarta": ("Jakarta", "ID"),
    "Bali": ("Denpasar", "ID"),
    "Zanzibar": ("Zanzibar", "TZ"),
    "Naples": ("Naples", "IT"),
    "Santiago": ("Santiago", "CL"),
    "Cartagena": ("Cartagena", "CO"),
    "Nice": ("Nice", "FR"),
    "Cork": ("Cork", "IE"),
    "Bath": ("Bath", "GB"),
    "Queenstown": ("Queenstown", "NZ"),
    "Guadalajara": ("Guadalajara", "MX"),
    "St. Petersburg": ("Saint Petersburg", "RU"),
    "St. Louis": ("St. Louis", "US"),
    "Sana'a": ("Sanaa", "YE"),
    "Xi'an": ("Xi'an", "CN"),
    "Hong Kong": ("Hong Kong", "HK"),
    "Kyoto": ("Kyoto", "JP"),
    "Ho Chi Minh City": ("Ho Chi Minh City", "VN"),
    "Quebec City": ("Québec", "CA"),
    "Reykjavik": ("Reykjavík", "IS"),
    "Bogotá": ("Bogotá", "CO"),
    "Medellín": ("Medellín", "CO"),
    "Brasília": ("Brasília", "BR"),
    "São Paulo": ("São Paulo", "BR"),
    "Mexico City": ("Mexico City", "MX"),
    "Melbourne": ("Melbourne", "AU"),
    "Florence": ("Florence", "IT"),
    "Venice": ("Venice", "IT"),
    "Athens": ("Athens", "GR"),
    "Lima": ("Lima", "PE"),
    "Manila": ("Manila", "PH"),
    "Seville": ("Sevilla", "ES"),
    "Zurich": ("Zürich", "CH"),
    "Prague": ("Prague", "CZ"),
    "Vienna": ("Vienna", "AT"),
    "Warsaw": ("Warsaw", "PL"),
    "Cupertino": ("Cupertino", "US"),
}

# Cities too small for GeoNames' "population over 15,000" list.
# Centre taken from the city's Wikipedia article.
MANUAL_CITY_CENTRES: dict[str, tuple[float, float]] = {
    "Queenstown": (-45.0312, 168.6626),
}


@dataclass
class Finding:
    check: str
    city: str
    landmark_id: str
    landmark_name: str
    detail: str


def distance_km(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
    """Great-circle distance between two points (haversine formula)."""
    earth_radius_km = 6371.0
    lat_a_rad, lat_b_rad = math.radians(lat_a), math.radians(lat_b)
    delta_lat = math.radians(lat_b - lat_a)
    delta_lon = math.radians(lon_b - lon_a)
    haversine = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat_a_rad) * math.cos(lat_b_rad) * math.sin(delta_lon / 2) ** 2
    )
    return 2 * earth_radius_km * math.asin(math.sqrt(haversine))


def has_usable_coordinates(landmark: dict) -> bool:
    """True when lat/lon exist, are not 0, and are inside the valid ranges."""
    latitude = landmark.get("latitude")
    longitude = landmark.get("longitude")
    if not isinstance(latitude, (int, float)) or not isinstance(longitude, (int, float)):
        return False
    if latitude == 0 or longitude == 0:
        return False
    return -90 <= latitude <= 90 and -180 <= longitude <= 180


def city_median_point(landmarks: list[dict]) -> tuple[float, float] | None:
    """Median lat and median lon of a city's landmarks.

    The median (not the average) is used so that one far-away landmark,
    like an airport, can't drag the city's centre towards itself.
    """
    mappable = [landmark for landmark in landmarks if has_usable_coordinates(landmark)]
    if not mappable:
        return None
    median_lat = statistics.median(landmark["latitude"] for landmark in mappable)
    median_lon = statistics.median(landmark["longitude"] for landmark in mappable)
    return median_lat, median_lon


def load_reference_city_centres(city_names: list[str]) -> dict[str, tuple[float, float]]:
    """Look up each city's real centre in the offline GeoNames database.

    When several cities share a name, the most populated one wins unless
    CITY_LOOKUP_OVERRIDES pins the country.
    """
    # Index every GeoNames city by its lowercase name and alternate names once,
    # so each lookup below is a quick dictionary read instead of a full scan.
    geonames = geonamescache.GeonamesCache()
    geonames_cities_by_name: dict[str, list[dict]] = {}
    for geonames_city in geonames.get_cities().values():
        all_names = {geonames_city["name"].lower()}
        all_names.update(alt.lower() for alt in geonames_city.get("alternatenames", []))
        for city_name_variant in all_names:
            geonames_cities_by_name.setdefault(city_name_variant, []).append(geonames_city)

    reference_centres: dict[str, tuple[float, float]] = {}
    for city_name in city_names:
        if city_name in MANUAL_CITY_CENTRES:
            reference_centres[city_name] = MANUAL_CITY_CENTRES[city_name]
            continue
        lookup_name, country_code = CITY_LOOKUP_OVERRIDES.get(city_name, (city_name, ""))
        candidates = [
            geonames_city
            for geonames_city in geonames_cities_by_name.get(lookup_name.lower(), [])
            if not country_code or geonames_city["countrycode"] == country_code
        ]
        if candidates:
            best_match = max(candidates, key=lambda geonames_city: geonames_city["population"])
            reference_centres[city_name] = (best_match["latitude"], best_match["longitude"])
    return reference_centres


def read_city_enum_names() -> set[str]:
    """Raw values of CityLocation.City in Model.swift (e.g. "New York")."""
    swift_source = CITY_ENUM_PATH.read_text(encoding="utf-8")
    enum_body = swift_source.split("public enum City:", 1)[1].split("var id:", 1)[0]
    # Matches the quoted part of things like `newYork = "New York"`.
    return set(re.findall(r'\w+\s*=\s*"([^"]+)"', enum_body))


def check_city_keys(registry: dict[str, list[dict]]) -> list[Finding]:
    """JSON city names that the app's City enum doesn't know are silently dropped."""
    known_city_names = read_city_enum_names()
    findings = []
    for city_name in registry:
        if city_name not in known_city_names:
            findings.append(Finding("unknown_city_key", city_name, "", "",
                                    "City name not in CityLocation.City, so the app ignores it"))
    for city_name in sorted(known_city_names - set(registry)):
        findings.append(Finding("city_without_landmarks", city_name, "", "",
                                "City exists in the app but has no landmarks in the JSON"))
    return findings


def check_coordinates(
    registry: dict[str, list[dict]],
    reference_centres: dict[str, tuple[float, float]],
) -> list[Finding]:
    findings = []
    for city_name, landmarks in registry.items():
        median_point = city_median_point(landmarks)
        reference_centre = reference_centres.get(city_name)

        if reference_centre is None:
            findings.append(Finding("no_reference_centre", city_name, "", "",
                                    "Couldn't find this city in GeoNames; add an override"))
        elif median_point is not None:
            # If the whole city is in the wrong place, every landmark would look
            # "close to the median", so compare the median to the real centre too.
            centre_gap_km = distance_km(*median_point, *reference_centre)
            if centre_gap_km > CITY_CENTRE_MISMATCH_KM:
                findings.append(Finding("city_centre_mismatch", city_name, "", "",
                                        f"Landmarks' median is {centre_gap_km:.0f} km from the real city centre"))

        # Measure from the real city centre when we know it. The median is only a
        # fallback, because if half a city's pins are wrong the median is wrong too.
        anchor_point = reference_centre or median_point
        anchor_label = "the city centre" if reference_centre else "the city's median point"

        for landmark in landmarks:
            landmark_id = landmark.get("id", "")
            landmark_name = landmark.get("name", "")
            if not has_usable_coordinates(landmark):
                findings.append(Finding("missing_coordinates", city_name, landmark_id, landmark_name,
                                        f"lat={landmark.get('latitude')}, lon={landmark.get('longitude')}"))
                continue
            if anchor_point is None:
                continue

            latitude, longitude = landmark["latitude"], landmark["longitude"]
            if looks_like_placeholder(latitude, longitude, reference_centre):
                findings.append(Finding("placeholder_coordinates", city_name, landmark_id, landmark_name,
                                        f"({latitude}, {longitude}) is a rounded number or the exact city "
                                        "centre, not the building's real location"))

            km_from_anchor = distance_km(latitude, longitude, *anchor_point)
            if km_from_anchor <= FAR_FROM_CITY_KM:
                continue

            # Would swapping lat and lon put it back in the city?
            swapped_is_valid = -90 <= longitude <= 90
            if swapped_is_valid and distance_km(longitude, latitude, *anchor_point) <= FAR_FROM_CITY_KM:
                findings.append(Finding("swapped_coordinates", city_name, landmark_id, landmark_name,
                                        f"({latitude}, {longitude}) looks like lat/lon are swapped"))
                continue

            # More than ~500 km away usually means wrong country or a sign error.
            check_name = "wrong_country_or_sign" if km_from_anchor > 500 else "far_from_city"
            findings.append(Finding(check_name, city_name, landmark_id, landmark_name,
                                    f"{km_from_anchor:.1f} km from {anchor_label}"))
    return findings


def looks_like_placeholder(
    latitude: float,
    longitude: float,
    reference_centre: tuple[float, float] | None,
) -> bool:
    """Real building coordinates have 4+ decimals and aren't the city centre itself."""
    if reference_centre and distance_km(latitude, longitude, *reference_centre) < 0.005:
        return True
    # e.g. 27.0, 30.0 — a country or region centroid.
    if latitude == round(latitude, 1) and longitude == round(longitude, 1):
        return True
    # e.g. 1.08333, 104.05 (1°05′N, 104°03′E). Whole arc-minutes is how a
    # whole city's location is usually written, not a single building's.
    return is_whole_arc_minute(latitude) and is_whole_arc_minute(longitude)


def is_whole_arc_minute(degrees: float) -> bool:
    """True when the value is (almost exactly) a whole number of minutes (1/60 of a degree)."""
    minutes = abs(degrees) * 60
    return abs(minutes - round(minutes)) < 0.006  # 0.006 minutes is about 0.0001 degrees


def check_stacked_pins(registry: dict[str, list[dict]]) -> list[Finding]:
    """Several different landmarks on exactly the same spot stack on the map."""
    findings = []
    for city_name, landmarks in registry.items():
        ids_by_point: dict[tuple[float, float], list[str]] = {}
        for landmark in landmarks:
            if has_usable_coordinates(landmark):
                point = (landmark["latitude"], landmark["longitude"])
                ids_by_point.setdefault(point, []).append(landmark.get("id", ""))
        for point, landmark_ids in ids_by_point.items():
            if len(landmark_ids) > 1:
                findings.append(Finding("stacked_pins", city_name, ", ".join(landmark_ids), "",
                                        f"{len(landmark_ids)} landmarks share {point}"))
    return findings


def normalised_name(name: str) -> str:
    """Lowercase, drop a leading 'the', and squash punctuation/whitespace."""
    lowered = name.lower().strip()
    lowered = re.sub(r"^the\s+", "", lowered)
    return re.sub(r"[^\w]+", " ", lowered).strip()


def check_duplicates(registry: dict[str, list[dict]]) -> list[Finding]:
    findings = []
    # Ids must be unique across the WHOLE registry: stamps and
    # BuildingRegistry.getBuilding(by:) look landmarks up by id alone.
    cities_by_id: dict[str, list[str]] = {}
    for city_name, landmarks in registry.items():
        for landmark in landmarks:
            cities_by_id.setdefault(landmark.get("id", ""), []).append(city_name)
    for landmark_id, city_names in cities_by_id.items():
        if len(city_names) > 1:
            findings.append(Finding("duplicate_id", ", ".join(city_names), landmark_id, "",
                                    f"id used {len(city_names)} times"))

    for city_name, landmarks in registry.items():
        ids_by_name: dict[str, list[str]] = {}
        for landmark in landmarks:
            ids_by_name.setdefault(normalised_name(landmark.get("name", "")), []).append(landmark.get("id", ""))
        for name_key, landmark_ids in ids_by_name.items():
            if len(landmark_ids) > 1:
                findings.append(Finding("duplicate_name", city_name, ", ".join(landmark_ids), name_key,
                                        "Same name appears more than once in this city"))
    return findings


def check_years(registry: dict[str, list[dict]]) -> list[Finding]:
    current_year = date.today().year
    findings = []
    for city_name, landmarks in registry.items():
        for landmark in landmarks:
            year_built = landmark.get("yearBuilt")
            problem = ""
            if not isinstance(year_built, int):
                problem = f"yearBuilt is {year_built!r}, not a whole number"
            elif year_built == 0:
                problem = "yearBuilt is 0 (probably unknown)"
            elif year_built > current_year + 5:
                # A few landmarks are under construction (e.g. Sagrada Família),
                # so allow a small window into the future.
                problem = f"yearBuilt {year_built} is in the future"
            elif year_built < -3000:
                problem = f"yearBuilt {year_built} is older than almost any standing building"
            if problem:
                findings.append(Finding("implausible_year", city_name, landmark.get("id", ""),
                                        landmark.get("name", ""), problem))
    return findings


def check_text_fields(registry: dict[str, list[dict]]) -> list[Finding]:
    findings = []
    for city_name, landmarks in registry.items():
        for landmark in landmarks:
            for field_name in ("name", "description", "architect", "buildingStyle", "address"):
                value = landmark.get(field_name)
                if not isinstance(value, str) or value.strip().lower() in PLACEHOLDER_TEXT:
                    findings.append(Finding("empty_text", city_name, landmark.get("id", ""),
                                            landmark.get("name", ""), f"{field_name} is {value!r}"))
                elif value != value.strip() or "  " in value:
                    findings.append(Finding("stray_whitespace", city_name, landmark.get("id", ""),
                                            landmark.get("name", ""), f"{field_name} has extra spaces"))
    return findings


def check_size(registry: dict[str, list[dict]]) -> list[Finding]:
    findings = []
    for city_name, landmarks in registry.items():
        for landmark in landmarks:
            stories = landmark.get("numberOfStories")
            height = landmark.get("height")
            problem = ""
            if not isinstance(stories, int) or not isinstance(height, (int, float)):
                problem = f"stories={stories!r}, height={height!r} are not numbers"
            elif stories < 0 or height < 0:
                problem = f"negative value (stories={stories}, height={height})"
            elif stories > MAX_STORIES or height > MAX_HEIGHT_METERS:
                problem = f"taller than the world's tallest building (stories={stories}, height={height})"
            elif stories > 0 and height == 0:
                # Usually a park, square or street rather than a building.
                findings.append(Finding("height_unknown", city_name, landmark.get("id", ""),
                                        landmark.get("name", ""), f"{stories} stories but height is 0"))
                continue
            elif stories >= 3 and height > 0:
                # Only judge metres-per-storey once there are a few floors;
                # a 1-storey cathedral nave can legitimately be 40 m tall.
                meters_per_story = height / stories
                if meters_per_story < MIN_METERS_PER_STORY:
                    problem = f"{height} m for {stories} stories is only {meters_per_story:.1f} m/storey (feet?)"
                elif meters_per_story > MAX_METERS_PER_STORY:
                    problem = f"{height} m for {stories} stories is {meters_per_story:.0f} m/storey"
            if problem:
                findings.append(Finding("suspicious_size", city_name, landmark.get("id", ""),
                                        landmark.get("name", ""), problem))
    return findings


def check_quiz_minimum(registry: dict[str, list[dict]]) -> list[Finding]:
    findings = []
    for city_name, landmarks in registry.items():
        mappable_count = sum(1 for landmark in landmarks if has_usable_coordinates(landmark))
        if mappable_count < MIN_MAPPABLE_LANDMARKS:
            findings.append(Finding("too_few_landmarks", city_name, "", "",
                                    f"only {mappable_count} mappable landmarks (quiz needs {MIN_MAPPABLE_LANDMARKS})"))
    return findings


def run_audit(registry: dict[str, list[dict]]) -> list[Finding]:
    reference_centres = load_reference_city_centres(list(registry))
    return (
        check_city_keys(registry)
        + check_coordinates(registry, reference_centres)
        + check_stacked_pins(registry)
        + check_duplicates(registry)
        + check_years(registry)
        + check_text_fields(registry)
        + check_size(registry)
        + check_quiz_minimum(registry)
    )


def format_report(registry: dict[str, list[dict]], findings: list[Finding]) -> str:
    landmark_count = sum(len(landmarks) for landmarks in registry.values())
    lines = [
        "# BuildingRegistry.json audit",
        "",
        f"{len(registry)} cities, {landmark_count} landmarks, {len(findings)} findings.",
        "",
    ]
    findings_by_check: dict[str, list[Finding]] = {}
    for finding in findings:
        findings_by_check.setdefault(finding.check, []).append(finding)

    lines.append("| Check | Count |")
    lines.append("|---|---|")
    for check_name, check_findings in findings_by_check.items():
        lines.append(f"| {check_name} | {len(check_findings)} |")

    for check_name, check_findings in findings_by_check.items():
        lines += ["", f"## {check_name} ({len(check_findings)})", ""]
        for finding in check_findings:
            label = f"`{finding.landmark_id}` {finding.landmark_name}".strip() if finding.landmark_id else ""
            lines.append(f"- **{finding.city}** {label} — {finding.detail}".replace("  ", " "))
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit BuildingRegistry.json")
    parser.add_argument("--registry", type=Path, default=REGISTRY_PATH)
    parser.add_argument("--output", type=Path, help="Also write the Markdown report here")
    arguments = parser.parse_args()

    registry = json.loads(arguments.registry.read_text(encoding="utf-8"))
    findings = run_audit(registry)
    report = format_report(registry, findings)
    print(report)
    if arguments.output:
        arguments.output.write_text(report, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
