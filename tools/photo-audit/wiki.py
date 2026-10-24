"""Shared Wikipedia helpers for the landmark photo audit.

This file mirrors the photo lookup in
`Stamped! A City Passport/Managers/WikimediaService.swift`, so the audit sees
the same photo the app would show. The title overrides and logo patterns are
read straight out of the Swift file, so the two can't drift apart.

Every HTTP response is cached in cache/http_cache.json, so reruns are quick and
only new titles hit the network.
"""

import json
import math
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import quote

import requests

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent.parent
SWIFT_SERVICE = REPO_ROOT / "Stamped! A City Passport" / "Managers" / "WikimediaService.swift"
REGISTRY = REPO_ROOT / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"
CACHE_FILE = TOOL_DIR / "cache" / "http_cache.json"

# Wikimedia asks scripts to identify themselves and say how to reach the owner
USER_AGENT = "StampedPhotoAudit/1.0 (https://georgeclinkscalesdev.com; landmark photo audit for the Stamped! iOS app)"
REST_BASE = "https://en.wikipedia.org/api/rest_v1/page"
ACTION_API = "https://en.wikipedia.org/w/api.php"

# Seconds to wait between network requests (about 6 requests a second at most)
THROTTLE_SECONDS = 0.15

# Characters Swift's .urlPathAllowed leaves unencoded, so titles encode the same way
SWIFT_PATH_SAFE = "!$&'()*+,-./:;=@_~"


@dataclass
class Landmark:
    city: str
    id: str
    name: str
    latitude: float
    longitude: float


@dataclass
class PhotoResult:
    """What the app would show for one landmark."""

    title_tried: str | None  # The title that returned an article (None if none did)
    article_title: str | None  # Title after Wikipedia redirects
    page_type: str | None  # "standard", "disambiguation", ...
    photo_url: str | None
    article_lat: float | None
    article_lon: float | None


# MARK: - Reading the app's source


def load_landmarks() -> list[Landmark]:
    registry: dict[str, list[dict[str, Any]]] = json.loads(REGISTRY.read_text())
    landmarks: list[Landmark] = []
    for city, buildings in registry.items():
        for building in buildings:
            landmarks.append(
                Landmark(
                    city=city,
                    id=building["id"],
                    name=building["name"],
                    latitude=building["latitude"],
                    longitude=building["longitude"],
                )
            )
    return landmarks


def swift_title_overrides() -> dict[str, str]:
    """Parse the `titleOverrides` dictionary (building id -> title) out of WikimediaService.swift."""
    source = SWIFT_SERVICE.read_text()
    block = re.search(r"titleOverrides: \[String: String\] = \[(.*?)\n    \]", source, re.DOTALL)
    if block is None:
        return {}
    # Each entry looks like:   "nyc_vessel": "Vessel (structure)",
    pairs = re.findall(r'^\s*"((?:[^"\\]|\\.)*)":\s*"((?:[^"\\]|\\.)*)",', block.group(1), re.MULTILINE)
    return {key.replace('\\"', '"'): value.replace('\\"', '"') for key, value in pairs}


def swift_logo_patterns() -> list[str]:
    """Parse the substrings `isLogoOrDiagram` checks for, e.g. [".svg", "logo", "map"]."""
    source = SWIFT_SERVICE.read_text()
    body = re.search(r"func isLogoOrDiagram\(.*?\n    \}", source, re.DOTALL)
    if body is None:
        return []
    return re.findall(r'contains\("([^"]+)"\)', body.group(0))


# MARK: - Name helpers (same rules as the Swift service)


def simplify(name: str) -> str:
    """Strip a leading "The ", "A " or "An "."""
    for prefix in ("The ", "A ", "An "):
        if name.startswith(prefix):
            return name[len(prefix):]
    return name


def removing_parenthetical(name: str) -> str:
    """"Rockefeller Center (30 Rock)" -> "Rockefeller Center"."""
    if "(" not in name:
        return name
    return name[: name.index("(")].strip()


def candidate_titles(name: str, override: str | None) -> list[str]:
    """Titles the app tries, in order, without duplicates."""
    candidates = [override or name, simplify(name), simplify(removing_parenthetical(name))]
    unique: list[str] = []
    for title in candidates:
        if title not in unique:
            unique.append(title)
    return unique


def encoded_title(title: str) -> str:
    return quote(title.replace(" ", "_"), safe=SWIFT_PATH_SAFE)


def is_logo_or_diagram(url: str | None, patterns: list[str]) -> bool:
    if url is None:
        return False
    lowered = url.lower()
    return any(pattern in lowered for pattern in patterns)


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Great-circle distance (haversine formula)."""
    earth_radius_km = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    return 2 * earth_radius_km * math.asin(math.sqrt(a))


# MARK: - Cached HTTP client


class WikiClient:
    def __init__(self) -> None:
        self.session = requests.Session()
        self.session.headers["User-Agent"] = USER_AGENT
        self.cache: dict[str, Any] = {}
        if CACHE_FILE.exists():
            self.cache = json.loads(CACHE_FILE.read_text())
        self.unsaved_count = 0
        self.last_request_time = 0.0

    def save(self) -> None:
        CACHE_FILE.parent.mkdir(exist_ok=True)
        CACHE_FILE.write_text(json.dumps(self.cache))
        self.unsaved_count = 0

    def get_json(self, url: str, params: dict[str, str] | None = None) -> tuple[int, Any]:
        """GET a URL and return (status code, parsed JSON or None). Cached."""
        cache_key = url if params is None else f"{url}?{json.dumps(params, sort_keys=True)}"
        if cache_key in self.cache:
            cached = self.cache[cache_key]
            return cached["status"], cached["body"]

        for attempt in range(5):
            # Be polite: never send requests faster than the throttle allows
            wait = THROTTLE_SECONDS - (time.monotonic() - self.last_request_time)
            if wait > 0:
                time.sleep(wait)
            self.last_request_time = time.monotonic()

            response = self.session.get(url, params=params, timeout=30)
            # Rate limited or server trouble: back off and try again (not cached)
            if response.status_code == 429 or response.status_code >= 500:
                time.sleep(2 ** attempt)
                continue
            break

        body = response.json() if response.status_code == 200 else None
        self.cache[cache_key] = {"status": response.status_code, "body": body}
        self.unsaved_count += 1
        if self.unsaved_count >= 50:
            self.save()
        return response.status_code, body

    # REST endpoints the app uses. Only the fields we need are kept, so the cache stays small.

    def summary(self, title: str) -> dict[str, Any] | None:
        url = f"{REST_BASE}/summary/{encoded_title(title)}"
        cache_key = f"summary:{url}"
        if cache_key not in self.cache:
            status, body = self.get_json(url)
            trimmed = None
            if status == 200 and body is not None:
                trimmed = {
                    "title": body.get("title"),
                    "type": body.get("type"),
                    "original": (body.get("originalimage") or {}).get("source"),
                    "thumbnail": (body.get("thumbnail") or {}).get("source"),
                    "coordinates": body.get("coordinates"),
                }
            self.cache[cache_key] = trimmed
            self.cache.pop(url, None)  # Drop the full response, keep only the trimmed copy
        return self.cache[cache_key]

    def media_list_images(self, title: str) -> list[str]:
        """Largest srcset URL of each image in the article, in article order."""
        url = f"{REST_BASE}/media-list/{encoded_title(title)}"
        cache_key = f"media:{url}"
        if cache_key not in self.cache:
            status, body = self.get_json(url)
            images: list[str] = []
            if status == 200 and body is not None:
                for item in body.get("items", []):
                    srcset = item.get("srcset") or []
                    if item.get("type") == "image" and srcset:
                        src = srcset[-1]["src"]
                        images.append(f"https:{src}" if src.startswith("//") else src)
            self.cache[cache_key] = images
            self.cache.pop(url, None)
        return self.cache[cache_key]


# MARK: - The app's lookup, step for step


def app_photo(client: WikiClient, name: str, override: str | None, logo_patterns: list[str]) -> PhotoResult:
    for title in candidate_titles(name, override):
        summary = client.summary(title)
        if summary is None:
            continue  # Not a 200: the app moves on to the next candidate

        # The first article found wins, even if it has no photo
        photo = summary["original"] or summary["thumbnail"]
        if photo is None or is_logo_or_diagram(photo, logo_patterns):
            # The app calls media-list with the title it requested, not the redirect target
            for image in client.media_list_images(title):
                if not is_logo_or_diagram(image, logo_patterns):
                    photo = image
                    break

        coordinates = summary.get("coordinates") or {}
        return PhotoResult(
            title_tried=title,
            article_title=summary["title"],
            page_type=summary["type"],
            photo_url=photo,
            article_lat=coordinates.get("lat"),
            article_lon=coordinates.get("lon"),
        )
    return PhotoResult(None, None, None, None, None, None)
