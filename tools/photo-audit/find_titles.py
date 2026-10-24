"""Suggest the right Wikipedia article for every landmark the audit flagged.

Usage (from tools/photo-audit, after running audit.py):
    .venv/bin/python find_titles.py --report reports/audit-before.json

For each flagged landmark it:
  1. searches Wikipedia for the landmark name (plain, then with the city), then
     adds nearby geotagged articles that share a word with the name,
  2. keeps only articles whose coordinates are within 2 km of the landmark,
     so "Union Station" in Portland can't pick Los Angeles's station,
  3. keeps only titles that share the landmark's distinctive words (name_matches),
  4. runs the app's own photo lookup on that title and keeps it only if the
     result is a real photo.

Writes reports/suggestions.json (matches) and reports/unresolved.json (the rest).
"""

import argparse
import json
import re
import unicodedata
from pathlib import Path
from typing import Any

from audit import MAX_DISTANCE_KM, REPORTS_DIR, categorize
from wiki import (
    ACTION_API,
    Landmark,
    WikiClient,
    app_photo,
    distance_km,
    load_landmarks,
    removing_parenthetical,
    simplify,
    swift_logo_patterns,
)

# How many search results to look at per query
SEARCH_LIMIT = "10"


def search_titles(client: WikiClient, query: str) -> list[str]:
    _, body = client.get_json(
        ACTION_API,
        {"action": "query", "list": "search", "srsearch": query, "srlimit": SEARCH_LIMIT, "format": "json"},
    )
    if body is None:
        return []
    return [hit["title"] for hit in body.get("query", {}).get("search", [])]


def nearby_titles(client: WikiClient, landmark: Landmark) -> list[str]:
    """Articles geotagged within 2 km, closest first. Used to rank search hits."""
    _, body = client.get_json(
        ACTION_API,
        {
            "action": "query",
            "list": "geosearch",
            "gscoord": f"{landmark.latitude}|{landmark.longitude}",
            "gsradius": str(int(MAX_DISTANCE_KM * 1000)),
            "gslimit": "100",
            "format": "json",
        },
    )
    if body is None:
        return []
    return [hit["title"] for hit in body.get("query", {}).get("geosearch", [])]


def shares_a_word(title: str, name: str) -> bool:
    """True if the title and name share a word longer than 3 letters ("Tower", "Basilica"...)."""
    title_words = {word.lower().strip(",.'()") for word in title.split() if len(word) > 3}
    name_words = {word.lower().strip(",.'()") for word in name.split() if len(word) > 3}
    return bool(title_words & name_words)


# Small words that don't help tell two places apart
STOPWORDS = {"the", "of", "and", "at", "in", "on", "de", "del", "la", "le", "da", "do", "dos", "das", "di", "el", "y", "e", "st", "saint"}

# Building-type words: matching only these isn't enough ("Dolmabahçe Palace" is not "Istanbul Justice Palace")
GENERIC_WORDS = {
    "palace", "tower", "house", "building", "museum", "church", "cathedral", "basilica", "center", "centre",
    "hall", "station", "temple", "shrine", "park", "street", "bridge", "theatre", "theater", "hotel", "mosque",
    "library", "square", "market", "plaza", "mall", "garden", "gardens", "castle", "fort", "fortress", "city",
    "old", "new", "national", "public", "central", "great", "grand", "main", "custom", "customs", "union",
    "state", "art", "arts", "contemporary", "modern", "history", "memorial", "office", "campus", "terminal",
}

# Apple Stores have no Wikipedia articles of their own; a photo of the mall around them is George's call
APPLE_RETAIL_MARKERS = ("Apple ", "Apple Premium", "iStore", "iSpace", "iPlace")


def words(text: str) -> set[str]:
    """Lowercase words without accents, punctuation or a plural/possessive "s"."""
    folded = unicodedata.normalize("NFKD", text.replace("’", "'")).encode("ascii", "ignore").decode().lower()
    result: set[str] = set()
    # Hyphens and dots split words too: "James-Simon-Galerie", "U.S."
    for word in re.split(r"[^a-z0-9']+", folded):
        word = word.strip("'").removesuffix("'s")
        if len(word) > 3 and word.endswith("s"):
            word = word[:-1]  # "Towers" -> "tower", "Customs" -> "custom"
        # Single letters ("U", "S" from "U.S.") say nothing about the place
        if len(word) > 1 and word not in STOPWORDS:
            result.add(word)
    return result


def name_matches(name: str, title: str, city: str) -> bool:
    """Does the article title plausibly name the same landmark?"""
    title_words = words(title)
    city_words = words(city)

    def matches(part: str) -> bool:
        name_words = words(part) - city_words  # "Sydney Opera House" must match on "opera house"
        if not name_words:
            return False
        shared = name_words & title_words
        if len(shared) < len(name_words) / 2:
            return False
        distinctive = name_words - GENERIC_WORDS
        if distinctive:
            return bool(shared & distinctive)
        # Only generic words ("Union Station"): the title must name the city to be sure
        return bool(city_words & title_words)

    # Try the full name, the name without its parenthetical, and the parenthetical alone
    parts = [name, removing_parenthetical(name)]
    if "(" in name:
        parts.append(name[name.index("(") + 1:].rstrip(")"))
    return any(matches(part) for part in parts)


def article_coordinates(client: WikiClient, titles: list[str]) -> dict[str, tuple[float, float]]:
    """Primary coordinates for up to 50 titles, keyed by the title we asked for."""
    if not titles:
        return {}
    _, body = client.get_json(
        ACTION_API,
        {"action": "query", "prop": "coordinates", "titles": "|".join(titles), "redirects": "1", "format": "json"},
    )
    if body is None:
        return {}
    query: dict[str, Any] = body.get("query", {})

    # Map redirect targets back to the title we searched for
    asked_for: dict[str, str] = {title: title for title in titles}
    for redirect in query.get("redirects", []):
        asked_for[redirect["to"]] = redirect["from"]

    coordinates: dict[str, tuple[float, float]] = {}
    for page in query.get("pages", {}).values():
        points = page.get("coordinates")
        if points:
            original_title = asked_for.get(page["title"], page["title"])
            coordinates[original_title] = (points[0]["lat"], points[0]["lon"])
    return coordinates


def find_title(client: WikiClient, landmark: Landmark, logo_patterns: list[str]) -> dict[str, Any] | None:
    if any(marker in landmark.name for marker in APPLE_RETAIL_MARKERS):
        return None
    base_name = simplify(removing_parenthetical(landmark.name))
    queries = [landmark.name, f"{base_name} {landmark.city}"]

    candidates: list[str] = []
    for query in queries:
        for title in search_titles(client, query):
            if title not in candidates:
                candidates.append(title)

    # Fallback: geotagged articles close to the landmark whose name looks related
    for title in nearby_titles(client, landmark):
        if title not in candidates and shares_a_word(title, base_name):
            candidates.append(title)

    # The API accepts at most 50 titles per request
    coordinates: dict[str, tuple[float, float]] = {}
    for start in range(0, len(candidates), 50):
        coordinates |= article_coordinates(client, candidates[start:start + 50])
    for title in candidates:
        if title not in coordinates:
            continue  # No coordinates means we can't prove it's the right place
        lat, lon = coordinates[title]
        distance = distance_km(landmark.latitude, landmark.longitude, lat, lon)
        if distance > MAX_DISTANCE_KM or not name_matches(landmark.name, title, landmark.city):
            continue

        # Check the app would really show a good photo with this title
        result = app_photo(client, landmark.name, title, logo_patterns)
        category, _ = categorize(landmark, result)
        if category == "ok":
            return {"title": title, "distance_km": round(distance, 2), "photo_url": result.photo_url}
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--report", type=Path, default=REPORTS_DIR / "audit.json")
    args = parser.parse_args()

    rows: list[dict[str, Any]] = json.loads(args.report.read_text())
    flagged_ids = {row["id"]: row["category"] for row in rows if row["category"] != "ok"}
    landmarks = [landmark for landmark in load_landmarks() if landmark.id in flagged_ids]
    print(f"Looking for better titles for {len(landmarks)} flagged landmarks")

    client = WikiClient()
    logo_patterns = swift_logo_patterns()
    suggestions: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    for index, landmark in enumerate(landmarks, start=1):
        found = find_title(client, landmark, logo_patterns)
        entry = {"city": landmark.city, "id": landmark.id, "name": landmark.name, "was": flagged_ids[landmark.id]}
        if found is None:
            unresolved.append(entry)
        else:
            suggestions.append(entry | found)
        if index % 25 == 0:
            print(f"  {index}/{len(landmarks)}")
            client.save()
    client.save()

    (REPORTS_DIR / "suggestions.json").write_text(json.dumps(suggestions, indent=2, ensure_ascii=False))
    (REPORTS_DIR / "unresolved.json").write_text(json.dumps(unresolved, indent=2, ensure_ascii=False))
    print(f"{len(suggestions)} suggestions, {len(unresolved)} unresolved")


if __name__ == "__main__":
    main()
