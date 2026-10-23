#!/usr/bin/env python3
"""
Stamped City Generator — Multi-Source Edition v2

Building data:  Overture Maps (Microsoft ML footprints + TomTom + OSM)
                OpenStreetMap (fallback + roads + water)
Land use:       Detroit Open Data Portal (Socrata REST API)
Terrain:        USGS 3DEP elevation service
Satellite:      ESRI World Imagery tiles (zoom 17, ~1.2 m/px)
Facades:        Procedural window textures (Pillow)
Landmark photos: Wikimedia Commons via Wikipedia REST API (cached)

Install deps (activate your venv first):
    pip install overturemaps py3dep rioxarray

Usage:
    python generate.py
"""

import io
import json
import math
import os
import pickle
import random
import shutil
import tempfile
import time
import numpy as np
import requests
import trimesh
from PIL import Image, ImageDraw
from shapely.geometry import Polygon, LineString, MultiPolygon, Point, box as shapely_box
from shapely.strtree import STRtree
from pxr import Usd, UsdGeom, UsdShade, UsdUtils, Sdf, Vt, Gf

# ── City config ───────────────────────────────────────────────────────────────
CITY = "detroit"
LAT_MIN, LON_MIN = 42.318, -83.092   # north of Detroit River (excludes Windsor)
LAT_MAX, LON_MAX = 42.385, -83.025   # covers Fisher Bldg, Packard Plant, Motown Museum

# ── Derived constants ──────────────────────────────────────────────────────────
CENTER_LAT = (LAT_MIN + LAT_MAX) / 2
CENTER_LON = (LON_MIN + LON_MAX) / 2
LAT_TO_M   = 111_000.0
LON_TO_M   = 111_000.0 * np.cos(np.radians(CENTER_LAT))

DEFAULT_HEIGHT  = 10.0
LEVELS_TO_M     = 3.5
MAX_HEIGHT      = 400.0     # >400 m is bad data
MIN_AREA_M2     = 20.0      # skip tiny/misplaced footprints (<20 m²)
DEDUP_THRESHOLD = 0.25      # skip OSM building if >25 % overlap with Overture

# Set True to skip the slow Overture S3 download and use OSM only.
# Once Overture finishes once and caches, set back to False.
SKIP_OVERTURE = False

PHOTOS_DIR = os.path.join(os.path.dirname(__file__), "output", "photos")
CACHE_DIR  = os.path.join(os.path.dirname(__file__), "output", "cache")
CACHE_TTL  = 7 * 24 * 3600   # re-download Overture data after 7 days


def _cache_path(name: str) -> str:
    return os.path.join(CACHE_DIR, f"{name}.pkl")


def _cache_load(name: str):
    """Return cached object or None if missing / expired."""
    path = _cache_path(name)
    if not os.path.exists(path):
        return None
    if time.time() - os.path.getmtime(path) > CACHE_TTL:
        print(f"  Cache expired for {name} — re-fetching")
        return None
    with open(path, "rb") as f:
        return pickle.load(f)


def _cache_save(name: str, obj) -> None:
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(_cache_path(name), "wb") as f:
        pickle.dump(obj, f)


def to_xy(lat: float, lon: float) -> tuple[float, float]:
    """Convert lat/lon to scene-space metres relative to city center."""
    return (lon - CENTER_LON) * LON_TO_M, (lat - CENTER_LAT) * LAT_TO_M


_x_min, _y_min = to_xy(LAT_MIN, LON_MIN)
_x_max, _y_max = to_xy(LAT_MAX, LON_MAX)
CLIP_BOX = shapely_box(_x_min, _y_min, _x_max, _y_max)


# ── Color / class tables ───────────────────────────────────────────────────────

CLASS_COLORS: dict[str, tuple[float, float, float]] = {
    "residential":    (0.72, 0.42, 0.30),
    "commercial":     (0.68, 0.74, 0.80),
    "industrial":     (0.52, 0.52, 0.50),
    "civic":          (0.88, 0.84, 0.72),
    "education":      (0.84, 0.76, 0.58),
    "entertainment":  (0.60, 0.38, 0.28),
    "hospitality":    (0.76, 0.64, 0.46),
    "medical":        (0.90, 0.90, 0.90),
    "religious":      (0.82, 0.76, 0.62),
    "transportation": (0.42, 0.42, 0.42),
    "military":       (0.52, 0.55, 0.46),
    "agricultural":   (0.68, 0.72, 0.50),
    "utility":        (0.58, 0.58, 0.56),
}

MATERIAL_COLORS: dict[str, tuple[float, float, float]] = {
    "brick":    (0.62, 0.32, 0.18),
    "concrete": (0.72, 0.72, 0.70),
    "glass":    (0.55, 0.70, 0.80),
    "metal":    (0.58, 0.62, 0.66),
    "stone":    (0.75, 0.70, 0.60),
    "wood":     (0.65, 0.48, 0.28),
}

OSM_TYPE_TO_CLASS: dict[str, str] = {
    "house": "residential", "residential": "residential", "apartments": "residential",
    "detached": "residential", "terrace": "residential", "semidetached_house": "residential",
    "retail": "commercial", "commercial": "commercial", "office": "commercial",
    "shop": "commercial", "supermarket": "commercial",
    "industrial": "industrial", "warehouse": "industrial", "factory": "industrial",
    "hangar": "industrial", "storage_tank": "industrial",
    "school": "education", "university": "education", "college": "education",
    "kindergarten": "education", "library": "education",
    "church": "religious", "cathedral": "religious", "mosque": "religious",
    "synagogue": "religious", "chapel": "religious",
    "hospital": "medical", "clinic": "medical",
    "stadium": "entertainment", "sports_centre": "entertainment", "arena": "entertainment",
    "hotel": "hospitality", "motel": "hospitality",
    "public": "civic", "government": "civic", "civic": "civic",
    "train_station": "transportation", "parking": "transportation",
}

PARCEL_CLASS_MAP: dict[str, str] = {
    "1": "agricultural",
    "2": "commercial",
    "3": "industrial",
    "4": "residential",
    "5": "utility",
    "7": "civic",
}

# Wall and window RGB colors used when generating per-tier facade textures.
FACADE_CONFIG: dict[str, dict] = {
    "residential":    {"wall": (140, 80,  55),  "window": (220, 215, 190)},
    "commercial":     {"wall": (80,  100, 130), "window": (200, 225, 250)},
    "industrial":     {"wall": (90,  90,  85),  "window": (130, 130, 120)},
    "civic":          {"wall": (170, 160, 130), "window": (235, 228, 205)},
    "education":      {"wall": (160, 140, 100), "window": (225, 215, 185)},
    "entertainment":  {"wall": (110, 60,  45),  "window": (210, 200, 170)},
    "hospitality":    {"wall": (140, 115, 75),  "window": (225, 218, 198)},
    "medical":        {"wall": (220, 220, 220), "window": (210, 225, 255)},
    "religious":      {"wall": (160, 148, 118), "window": (210, 205, 180)},
    "transportation": {"wall": (95,  95,  90),  "window": (150, 150, 145)},
    "military":       {"wall": (115, 120, 100), "window": (165, 168, 148)},
    "agricultural":   {"wall": (150, 158, 110), "window": (200, 205, 165)},
    "utility":        {"wall": (130, 130, 126), "window": (170, 170, 165)},
    "brick":          {"wall": (130, 70,  40),  "window": (215, 210, 190)},
    "concrete":       {"wall": (145, 145, 142), "window": (185, 195, 205)},
    "glass":          {"wall": (70,  105, 140), "window": (195, 225, 255)},
    "metal":          {"wall": (100, 108, 118), "window": (170, 180, 190)},
    "stone":          {"wall": (160, 150, 128), "window": (200, 195, 175)},
    "wood":           {"wall": (135, 98,  55),  "window": (200, 190, 165)},
    "short":          {"wall": (175, 165, 130), "window": (220, 215, 192)},
    "mid":            {"wall": (140, 140, 136), "window": (195, 205, 215)},
    "tall":           {"wall": (115, 130, 155), "window": (195, 220, 248)},
}


# ── Facade texture helpers ─────────────────────────────────────────────────────

def generate_facade_texture(tier: str, tmpdir: str, size: int = 1024) -> str:
    """Generate a detailed repeating facade JPEG for a building tier.

    Saved as JPEG (lossless-equivalent at q=92) so UsdUtils packages it reliably.
    Includes floor-separation bands, window frames, and tier-specific proportions.
    Returns the filename only (e.g. 'facade_commercial.jpg').
    """
    base_tier = tier[:-3] if tier.endswith(("_v0", "_v1", "_v2")) else tier
    variant_shift = {"_v0": 0, "_v1": -20, "_v2": 18}.get(tier[-3:], 0)
    cfg_base = FACADE_CONFIG.get(base_tier, {"wall": (150, 150, 145), "window": (200, 200, 195)})
    wall_rgb = tuple(max(0, min(255, c + variant_shift)) for c in cfg_base["wall"])
    win_rgb  = cfg_base["window"]

    img  = Image.new("RGB", (size, size), wall_rgb)
    draw = ImageDraw.Draw(img)

    # Tier-specific window grid and glass coverage
    if base_tier in ("glass", "commercial"):
        n_cols, n_rows, coverage, frame_px = 6, 10, 0.84, 2
    elif base_tier in ("brick", "residential", "religious"):
        n_cols, n_rows, coverage, frame_px = 3,  8, 0.44, 5
    elif base_tier in ("stone", "civic", "education"):
        n_cols, n_rows, coverage, frame_px = 3,  6, 0.50, 6
    elif base_tier in ("tall",):
        n_cols, n_rows, coverage, frame_px = 5,  9, 0.70, 3
    elif base_tier in ("concrete", "industrial"):
        n_cols, n_rows, coverage, frame_px = 4,  7, 0.50, 4
    else:
        n_cols, n_rows, coverage, frame_px = 4,  7, 0.56, 4

    margin = size // 12
    cell_w = (size - 2 * margin) // n_cols
    cell_h = (size - 2 * margin) // n_rows
    win_w  = int(cell_w * coverage)
    win_h  = int(cell_h * coverage * 0.75)
    pad_x  = (cell_w - win_w) // 2
    pad_y  = (cell_h - win_h) // 2

    # Floor slab bands — darker horizontal stripe at each floor line
    slab = tuple(max(0, c - 40) for c in wall_rgb)
    for row in range(n_rows + 1):
        y = margin + row * cell_h
        draw.rectangle([0, y - 2, size, y + 2], fill=slab)

    # Window frames + glass per cell
    frame_col = tuple(max(0, c - 18) for c in wall_rgb)
    for row in range(n_rows):
        for col in range(n_cols):
            x0 = margin + col * cell_w + pad_x
            y0 = margin + row * cell_h + pad_y
            # Outer frame
            draw.rectangle(
                [x0 - frame_px, y0 - frame_px,
                 x0 + win_w + frame_px, y0 + win_h + frame_px],
                fill=frame_col,
            )
            # Glass / window pane
            draw.rectangle([x0, y0, x0 + win_w, y0 + win_h], fill=win_rgb)

    safe     = tier.replace(":", "_").replace("#", "").replace("/", "_")
    filename = f"facade_{safe}.jpg"
    img.save(os.path.join(tmpdir, filename), "JPEG", quality=92)
    return filename


def compute_face_uvs(mesh: trimesh.Trimesh, tile_m: float = 4.0) -> np.ndarray:
    """Triplanar face-varying UV mapping for building walls.

    For each triangle, chooses a projection axis from the face normal so both
    E-W and N-S walls tile the facade texture correctly.  Returns an array of
    shape (3*num_faces, 2) for USD faceVarying interpolation.

    trimesh space: x=east, y=north, z=up.
      X-dominant face (E-W wall)  → project onto YZ plane: U=y,  V=z
      Y-dominant face (N-S wall)  → project onto XZ plane: U=x,  V=z
      Z-dominant face (roof/floor)→ project onto XY plane: U=x,  V=y
    """
    verts   = mesh.vertices   # (N, 3)
    faces   = mesh.faces      # (F, 3)
    normals = mesh.face_normals  # (F, 3)

    tri    = verts[faces]           # (F, 3, 3)
    abs_n  = np.abs(normals)        # (F, 3)
    dom    = np.argmax(abs_n, axis=1)[:, np.newaxis]  # (F, 1): 0=X, 1=Y, 2=Z

    u = np.where(dom == 0, tri[:, :, 1],   # X-dom → y
        np.where(dom == 1, tri[:, :, 0],   # Y-dom → x
                           tri[:, :, 0]))  # Z-dom → x

    v = np.where(dom == 2, tri[:, :, 1],   # Z-dom → y
                           tri[:, :, 2])   # X/Y-dom → z

    return np.column_stack([u.reshape(-1) / tile_m, v.reshape(-1) / tile_m])


def compute_box_uvs(vertices: np.ndarray, tile_m: float = 4.0) -> np.ndarray:
    """Legacy per-vertex box UVs — used only for landmark markers."""
    return np.column_stack([
        vertices[:, 0] / tile_m,
        vertices[:, 2] / tile_m,
    ])


# ── Wikimedia / landmark photos ────────────────────────────────────────────────

def fetch_wikimedia_photo(name: str, city: str = CITY.title()) -> str | None:
    """Fetch a Wikipedia thumbnail for a landmark name. Returns local path or None.

    Results are cached in output/photos/ so repeated runs are instant.
    Tries the exact name, then city-qualified variant, then Wikipedia search.
    """
    os.makedirs(PHOTOS_DIR, exist_ok=True)
    safe  = name.replace(" ", "_").replace("/", "-").replace("\\", "")
    local = os.path.join(PHOTOS_DIR, f"{safe}.jpg")

    if os.path.exists(local):
        return local

    headers = {"User-Agent": "StampedCityGenerator/1.0 (stamped-app; george@stamped.app)"}

    # Strip parenthetical qualifiers like "(DIA)" or "(Cadillac Place)" from lookup title
    import re as _re
    clean_name = _re.sub(r'\s*\([^)]*\)', '', name).strip()

    def _try_title(title: str) -> str | None:
        time.sleep(0.6)  # respect Wikipedia rate limit
        try:
            resp = requests.get(
                f"https://en.wikipedia.org/api/rest_v1/page/summary/{title}",
                headers=headers, timeout=10,
            )
            if resp.status_code != 200:
                return None
            thumb_url = resp.json().get("thumbnail", {}).get("source")
            if not thumb_url:
                return None
            # Upgrade to 800px thumbnail for better resolution on building faces
            thumb_url = thumb_url.replace("/320px-", "/800px-").replace("/200px-", "/800px-")
            img_resp = requests.get(thumb_url, headers=headers, timeout=15)
            img_resp.raise_for_status()
            with open(local, "wb") as fh:
                fh.write(img_resp.content)
            return local
        except Exception:
            return None

    def _search_fallback(query: str) -> str | None:
        """Use Wikipedia opensearch to find the best matching article title."""
        time.sleep(0.4)
        try:
            resp = requests.get(
                "https://en.wikipedia.org/w/api.php",
                params={"action": "opensearch", "search": query, "limit": 3, "format": "json"},
                headers=headers, timeout=10,
            )
            titles = resp.json()[1] if resp.status_code == 200 else []
            for t in titles:
                result = _try_title(t.replace(" ", "_"))
                if result:
                    return result
        except Exception:
            pass
        return None

    # 1. Exact name (parentheticals stripped)
    result = _try_title(clean_name.replace(" ", "_"))
    if result:
        print(f"    Photo: {name}")
        return result

    # 2. Name + city (e.g. "Fox_Theatre_(Detroit)")
    result = _try_title(f"{clean_name.replace(' ', '_')}_({city})")
    if result:
        print(f"    Photo: {name} (city-qualified)")
        return result

    # 3. Search fallback using cleaned name + city
    result = _search_fallback(f"{clean_name} {city}")
    if result:
        print(f"    Photo: {name} (search fallback)")
        return result

    return None


# ── Building tier helpers ─────────────────────────────────────────────────────

def building_height(tags: dict) -> float:
    if "height" in tags:
        try:
            h = float(tags["height"].replace(" m", "").replace("m", "").strip())
            return min(h, MAX_HEIGHT)
        except ValueError:
            pass
    if "building:levels" in tags:
        try:
            return min(float(tags["building:levels"]) * LEVELS_TO_M, MAX_HEIGHT)
        except ValueError:
            pass
    btype = tags.get("building", "yes").lower()
    _type_defaults = {
        "house": 5.5, "detached": 5.5, "semidetached_house": 6.5, "terrace": 6.0,
        "residential": 7.0, "apartments": 12.0,
        "retail": 5.0, "shop": 4.5, "commercial": 8.0, "office": 10.0,
        "industrial": 8.0, "warehouse": 9.0, "factory": 8.0, "hangar": 9.0,
        "church": 12.0, "cathedral": 18.0, "mosque": 10.0, "synagogue": 10.0,
        "school": 8.0, "university": 10.0, "college": 9.0, "kindergarten": 5.0,
        "hospital": 14.0, "clinic": 6.0,
        "hotel": 16.0, "motel": 6.0,
        "stadium": 25.0, "arena": 20.0,
        "parking": 9.0,
    }
    return _type_defaults.get(btype, DEFAULT_HEIGHT)


def building_tier(height: float, tags: dict, overture_class: str = "") -> str:
    colour = tags.get("building:colour", "")
    if colour.startswith("#") and len(colour) == 7:
        return f"hex_{colour[1:].lower()}"
    if overture_class in CLASS_COLORS:
        return overture_class
    material = tags.get("building:material", "").lower()
    if material in MATERIAL_COLORS:
        return material
    bldg_type = tags.get("building", "yes").lower()
    if bldg_type in OSM_TYPE_TO_CLASS:
        return OSM_TYPE_TO_CLASS[bldg_type]
    if height < 15:
        return "short"
    if height < 60:
        return "mid"
    return "tall"


# ── Overture Maps ─────────────────────────────────────────────────────────────

def fetch_overture_buildings() -> list[dict]:
    if SKIP_OVERTURE:
        print("Overture Maps skipped (SKIP_OVERTURE=True) — using OSM only")
        return []

    cache_key = f"overture_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Overture buildings loaded from cache ({len(cached)} buildings — delete output/cache/ to refresh)")
        return cached

    print("Fetching buildings from Overture Maps (this can take 10–20 min on first run)...")
    try:
        import overturemaps
        from shapely import wkb as shapely_wkb

        reader = overturemaps.record_batch_reader(
            "building",
            bbox=(LON_MIN, LAT_MIN, LON_MAX, LAT_MAX),
        )
        table = reader.read_all()
        rows  = table.to_pylist()
        print(f"  Overture: {len(rows)} raw records")

        buildings = []
        for row in rows:
            try:
                geom_wkb = row.get("geometry")
                if not geom_wkb:
                    continue
                geom = shapely_wkb.loads(bytes(geom_wkb))

                h = row.get("height") or 0
                if not h:
                    floors = row.get("num_floors") or 0
                    h = float(floors) * LEVELS_TO_M if floors else DEFAULT_HEIGHT
                height = min(float(h), MAX_HEIGHT)

                overture_class = row.get("class") or ""
                name = ""
                names_field = row.get("names")
                if isinstance(names_field, dict):
                    name = names_field.get("primary") or ""

                polys = list(geom.geoms) if geom.geom_type == "MultiPolygon" else [geom]
                for poly in polys:
                    if poly.geom_type != "Polygon":
                        continue
                    coords      = [to_xy(lat, lon) for lon, lat in poly.exterior.coords]
                    scene_poly  = Polygon(coords).buffer(0)
                    if not scene_poly.is_valid or scene_poly.area < MIN_AREA_M2:
                        continue
                    buildings.append({
                        "coords":       coords,
                        "height":       height,
                        "class":        overture_class,
                        "name":         name,
                        "tags":         {},
                        "shapely_poly": scene_poly,
                        "source":       "overture",
                    })
            except Exception:
                continue

        print(f"  Overture Maps: {len(buildings)} buildings")
        _cache_save(cache_key, buildings)
        return buildings

    except ImportError:
        print("  `overturemaps` not installed — run: pip install overturemaps")
        return []
    except Exception as e:
        print(f"  Overture Maps error: {e}")
        return []


# ── OpenStreetMap / Overpass ───────────────────────────────────────────────────

ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]


def overpass_query(query: str) -> dict:
    for url in ENDPOINTS:
        try:
            response = requests.post(url, data={"data": query}, timeout=120)
            if response.status_code == 200:
                return response.json()
            print(f"  {url} → {response.status_code}, trying next...")
        except requests.RequestException as e:
            print(f"  {url} failed: {e}, trying next...")
    raise RuntimeError("All Overpass API endpoints failed.")


def parse_ways(data: dict) -> tuple[list, dict]:
    """Parse OSM JSON into (way-list, nodes-dict). Includes relation multipolygons."""
    nodes: dict = {}
    ways:  dict = {}
    ways_list: list = []

    for el in data["elements"]:
        etype = el["type"]
        if etype == "node":
            nodes[el["id"]] = (el["lat"], el["lon"])
        elif etype == "way":
            ways[el["id"]] = el
            ways_list.append(el)

    # Assemble relation multipolygons (e.g. Renaissance Center)
    for el in data["elements"]:
        if el["type"] != "relation":
            continue
        outer_ids = [
            m["ref"] for m in el.get("members", [])
            if m.get("type") == "way" and m.get("role", "outer") in ("outer", "")
        ]
        lines = []
        for wid in outer_ids:
            way = ways.get(wid)
            if not way:
                continue
            coords = [
                (nodes[nid][1], nodes[nid][0])  # (lon, lat) for Shapely
                for nid in way.get("nodes", []) if nid in nodes
            ]
            if len(coords) >= 2:
                lines.append(coords)
        if not lines:
            continue
        try:
            from shapely.ops import polygonize, unary_union
            from shapely.geometry import LineString
            merged = unary_union([LineString(c) for c in lines])
            polys = list(polygonize(merged))
            if not polys:
                continue
            poly = max(polys, key=lambda p: p.area)
            ext = list(poly.exterior.coords)
            synth_base = -(el["id"] * 10000)
            for i, (lon, lat) in enumerate(ext):
                nodes[synth_base - i] = (lat, lon)
            ways_list.append({
                "type": "way",
                "id": el["id"],
                "nodes": [synth_base - i for i in range(len(ext))],
                "tags": el.get("tags", {}),
            })
        except Exception:
            continue

    return ways_list, nodes


def fetch_osm_buildings() -> tuple[list, dict]:
    # v2: includes relation["building"] for multipolygon complexes (e.g. RenCen)
    cache_key = f"osm_buildings_v2_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        ways, nodes = cached
        print(f"OSM buildings loaded from cache ({len(ways)} ways+relations)")
        return ways, nodes

    print("Fetching buildings from OpenStreetMap (ways + multipolygon relations)...")
    data = overpass_query(f"""
        [out:json][timeout:120];
        (
          way["building"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
          relation["building"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
        );
        (._;>;);
        out body;
    """)
    ways, nodes = parse_ways(data)
    print(f"  OSM: {len(ways)} buildings (ways + relations)")
    _cache_save(cache_key, (ways, nodes))
    return ways, nodes


def fetch_water() -> list:
    cache_key = f"osm_water_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Water loaded from cache ({len(cached)} elements)")
        return cached
    print("Fetching water from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:90];
            (
              way["natural"="water"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              way["waterway"="riverbank"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              way["landuse"="reservoir"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              relation["natural"="water"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              relation["waterway"="river"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            );
            out geom;
        """)
        elements = data.get("elements", [])
        print(f"  {len(elements)} water elements")
        _cache_save(cache_key, elements)
        return elements
    except RuntimeError as e:
        print(f"  Water fetch failed ({e}) — skipping water")
        return []


ROAD_WIDTHS = {
    "motorway": 16.0, "trunk": 14.0, "primary": 11.0,
    "secondary": 9.0, "tertiary": 7.0, "residential": 5.5,
    "unclassified": 5.0, "service": 4.0,
}


def fetch_roads() -> list:
    cache_key = f"osm_roads_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Roads loaded from cache ({len(cached)} segments)")
        return cached
    print("Fetching roads from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:90];
            way["highway"~"motorway|trunk|primary|secondary|tertiary|residential|unclassified"]
              ({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            out geom;
        """)
        elements = data.get("elements", [])
        # Enrich each element with a resolved width from width/lanes tags
        for el in elements:
            tags = el.get("tags", {})
            if "width" in tags:
                try:
                    el["_width"] = float(tags["width"])
                    continue
                except ValueError:
                    pass
            lanes = int(tags.get("lanes", 0) or 0)
            if lanes > 0:
                el["_width"] = lanes * 3.5
            else:
                el["_width"] = ROAD_WIDTHS.get(tags.get("highway", "residential"), 6.0)
        print(f"  {len(elements)} road segments")
        _cache_save(cache_key, elements)
        return elements
    except RuntimeError as e:
        print(f"  Roads fetch failed ({e}) — skipping roads")
        return []


def fetch_osm_trees() -> list[dict]:
    """Real street-tree positions from OSM natural=tree nodes (cached)."""
    cache_key = f"osm_trees_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Street trees loaded from cache ({len(cached)} nodes)")
        return cached
    print("Fetching street trees from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:60];
            node["natural"="tree"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            out body;
        """)
        trees = [
            {"lat": el["lat"], "lon": el["lon"],
             "height": float((el.get("tags") or {}).get("height", "0") or 0) or None}
            for el in data.get("elements", [])
            if el.get("type") == "node"
        ]
        print(f"  {len(trees)} street trees")
        _cache_save(cache_key, trees)
        return trees
    except RuntimeError as e:
        print(f"  Tree fetch failed ({e}) — will approximate placement")
        return []


def fetch_osm_lamps() -> list[dict]:
    """Real streetlight positions from OSM highway=street_lamp nodes (cached)."""
    cache_key = f"osm_lamps_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Street lamps loaded from cache ({len(cached)} nodes)")
        return cached
    print("Fetching street lamps from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:60];
            node["highway"="street_lamp"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            out body;
        """)
        lamps = [
            {"lat": el["lat"], "lon": el["lon"]}
            for el in data.get("elements", [])
            if el.get("type") == "node"
        ]
        print(f"  {len(lamps)} street lamps")
        _cache_save(cache_key, lamps)
        return lamps
    except RuntimeError as e:
        print(f"  Lamp fetch failed ({e}) — will approximate placement")
        return []


def fetch_osm_signs() -> tuple[list[dict], list[dict]]:
    """Stop signs and traffic signal positions from OSM (cached)."""
    cache_key = f"osm_signs_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        stops, signals = cached
        print(f"Signs loaded from cache ({len(stops)} stop signs, {len(signals)} traffic signals)")
        return stops, signals
    print("Fetching stop signs and traffic signals from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:60];
            (
              node["highway"="stop"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              node["highway"="traffic_signals"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            );
            out body;
        """)
        stops: list[dict]   = []
        signals: list[dict] = []
        for el in data.get("elements", []):
            if el.get("type") != "node":
                continue
            hw = el.get("tags", {}).get("highway", "")
            pt = {"lat": el["lat"], "lon": el["lon"]}
            if hw == "stop":
                stops.append(pt)
            elif hw == "traffic_signals":
                signals.append(pt)
        print(f"  {len(stops)} stop signs | {len(signals)} traffic signals")
        _cache_save(cache_key, (stops, signals))
        return stops, signals
    except RuntimeError as e:
        print(f"  Sign fetch failed ({e})")
        return [], []


def fetch_osm_parks_parking() -> tuple[list, list]:
    """Fetch park polygons and surface parking lots from OSM (cached)."""
    cache_key = f"osm_parks_parking_{CITY}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}"
    cached = _cache_load(cache_key)
    if cached is not None:
        parks, parking = cached
        print(f"Parks/parking loaded from cache ({len(parks)} parks, {len(parking)} lots)")
        return parks, parking
    print("Fetching parks and parking from OpenStreetMap...")
    try:
        data = overpass_query(f"""
            [out:json][timeout:90];
            (
              way["leisure"="park"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              way["landuse"~"grass|park|meadow|recreation_ground|village_green"]
                ({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              way["landuse"="parking"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              way["amenity"="parking"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
              relation["leisure"="park"]({LAT_MIN},{LON_MIN},{LAT_MAX},{LON_MAX});
            );
            out geom;
        """)
        parks: list = []
        parking: list = []
        for el in data.get("elements", []):
            tags = el.get("tags", {})
            is_park    = (tags.get("leisure") == "park" or
                          tags.get("landuse") in ("grass", "park", "meadow",
                                                   "recreation_ground", "village_green"))
            is_parking = (tags.get("landuse") == "parking" or
                          tags.get("amenity") == "parking")
            if el["type"] == "way":
                coords = [to_xy(pt["lat"], pt["lon"]) for pt in el.get("geometry", [])]
                if is_park:
                    parks.append(coords)
                elif is_parking:
                    parking.append(coords)
            elif el["type"] == "relation":
                for member in el.get("members", []):
                    if member.get("role") == "outer" and "geometry" in member:
                        coords = [to_xy(pt["lat"], pt["lon"]) for pt in member["geometry"]]
                        if is_park:
                            parks.append(coords)
        print(f"  {len(parks)} park polygons | {len(parking)} parking lots")
        _cache_save(cache_key, (parks, parking))
        return parks, parking
    except RuntimeError as e:
        print(f"  Parks/parking fetch failed ({e})")
        return [], []


# ── Detroit Open Data Portal ───────────────────────────────────────────────────

DETROIT_PARCEL_ENDPOINTS = [
    "https://data.detroitmi.gov/resource/fxkw-udwf.json",
    "https://data.detroitmi.gov/resource/xwkq-7y6f.json",
]


def fetch_detroit_parcels() -> list[dict]:
    print("Fetching parcel data from Detroit Open Data Portal...")
    params = {
        "$select": "propclass,lat,long",
        "$where": f"lat BETWEEN {LAT_MIN} AND {LAT_MAX} AND long BETWEEN {LON_MIN} AND {LON_MAX}",
        "$limit": "50000",
    }
    for url in DETROIT_PARCEL_ENDPOINTS:
        try:
            resp = requests.get(url, params=params, timeout=30)
            if resp.status_code != 200 or not resp.text.strip():
                continue
            data = resp.json()
            if not data:
                continue
            parcels = []
            for row in data:
                try:
                    lat = float(row.get("lat") or row.get("centroid_y") or 0)
                    lon = float(row.get("long") or row.get("centroid_x") or 0)
                    propclass  = str(row.get("propclass", "") or "")
                    land_type  = PARCEL_CLASS_MAP.get(propclass[:1], "")
                    if lat and lon and land_type:
                        x, y = to_xy(lat, lon)
                        parcels.append({"x": x, "y": y, "type": land_type})
                except (ValueError, TypeError):
                    continue
            if parcels:
                print(f"  Detroit parcels: {len(parcels)} records")
                return parcels
        except Exception as e:
            print(f"  {url} failed: {e}")
            continue
    print("  Detroit Open Data unavailable — using height tiers only")
    return []


def build_parcel_lookup(parcels: list[dict]):
    if not parcels:
        return lambda x, y: ""
    points = [Point(p["x"], p["y"]) for p in parcels]
    types  = [p["type"] for p in parcels]
    tree   = STRtree(points)

    def lookup(x: float, y: float) -> str:
        idx = tree.nearest(Point(x, y))
        if idx is None:
            return ""
        return types[idx] if Point(x, y).distance(points[idx]) < 150 else ""

    return lookup


# ── USGS 3DEP Terrain ──────────────────────────────────────────────────────────

def fetch_usgs_elevation() -> float:
    print("Fetching terrain elevation from USGS 3DEP...")
    try:
        resp = requests.get(
            "https://epqs.nationalmap.gov/v1/json",
            params={"x": CENTER_LON, "y": CENTER_LAT, "wkid": "4326",
                    "units": "Meters", "includeDate": "false"},
            timeout=15,
        )
        elev = float(resp.json().get("value") or 0)
        print(f"  Elevation: {elev:.1f} m ASL")
        return elev
    except Exception as e:
        print(f"  USGS unavailable ({e}), using 0 m")
        return 0.0


def fetch_elevation_grid(grid_n: int = 8) -> np.ndarray:
    """Fetch a grid_n×grid_n grid of elevations (m ASL) via USGS point queries."""
    cache_key = f"elev_grid_{CITY}_{grid_n}_{LAT_MIN:.4f}_{LAT_MAX:.4f}"
    cached = _cache_load(cache_key)
    if cached is not None:
        print(f"Elevation grid loaded from cache ({grid_n}×{grid_n})")
        return cached
    print(f"Fetching {grid_n}×{grid_n} elevation grid from USGS 3DEP...")
    lats = np.linspace(LAT_MIN, LAT_MAX, grid_n)
    lons = np.linspace(LON_MIN, LON_MAX, grid_n)
    grid = np.zeros((grid_n, grid_n))
    for i, lat in enumerate(lats):
        for j, lon in enumerate(lons):
            try:
                resp = requests.get(
                    "https://epqs.nationalmap.gov/v1/json",
                    params={"x": lon, "y": lat, "wkid": "4326",
                            "units": "Meters", "includeDate": "false"},
                    timeout=10,
                )
                val = resp.json().get("value")
                grid[i, j] = max(0.0, float(val) if val else 0.0)
                time.sleep(0.12)
            except Exception:
                pass
    _cache_save(cache_key, grid)
    print(f"  Elevation grid: min={grid.min():.1f} m  max={grid.max():.1f} m  "
          f"range={grid.max()-grid.min():.1f} m")
    return grid


def make_elevation_lookup(grid: np.ndarray):
    """Return (x_scene, y_scene) → elevation relative to city centre (m)."""
    grid_n = grid.shape[0]
    center_elev = float(grid[grid_n // 2, grid_n // 2])
    x_extent = _x_max - _x_min
    y_extent = _y_max - _y_min

    def lookup(x: float, y: float) -> float:
        col = (x - _x_min) / x_extent * (grid_n - 1)
        row = (y - _y_min) / y_extent * (grid_n - 1)
        col = max(0.0, min(grid_n - 1.001, col))
        row = max(0.0, min(grid_n - 1.001, row))
        c0, r0 = int(col), int(row)
        fc, fr = col - c0, row - r0
        elev = (grid[r0,     c0]     * (1 - fc) * (1 - fr) +
                grid[r0,     c0 + 1] * fc        * (1 - fr) +
                grid[r0 + 1, c0]     * (1 - fc)  * fr +
                grid[r0 + 1, c0 + 1] * fc         * fr)
        return elev - center_elev

    return lookup


# ── Merge building sources ─────────────────────────────────────────────────────

def merge_osm_into_overture(
    overture_buildings: list[dict],
    osm_ways: list,
    osm_nodes: dict,
    parcel_lookup,
) -> list[dict]:
    all_buildings = list(overture_buildings)

    if overture_buildings:
        ov_polys = [b["shapely_poly"] for b in overture_buildings]
        ov_tree  = STRtree(ov_polys)
    else:
        ov_tree = None

    osm_added = osm_skipped = 0

    for way in osm_ways:
        try:
            tags     = way.get("tags", {})
            node_ids = way.get("nodes", [])
            coords   = [to_xy(osm_nodes[nid][0], osm_nodes[nid][1])
                        for nid in node_ids if nid in osm_nodes]
            if len(coords) < 3:
                osm_skipped += 1
                continue

            poly = Polygon(coords).buffer(0)
            if not poly.is_valid or poly.area < MIN_AREA_M2:
                osm_skipped += 1
                continue

            # Skip if an Overture building already covers this footprint (25 % threshold)
            if ov_tree is not None:
                skip = False
                for idx in ov_tree.query(poly):
                    if ov_polys[idx].intersects(poly):
                        overlap = ov_polys[idx].intersection(poly).area
                        if overlap / poly.area > DEDUP_THRESHOLD:
                            skip = True
                            break
                if skip:
                    osm_skipped += 1
                    continue

            height = building_height(tags)
            if height > MAX_HEIGHT:
                osm_skipped += 1
                continue

            cx, cy = poly.centroid.x, poly.centroid.y
            all_buildings.append({
                "coords":       coords,
                "height":       height,
                "class":        parcel_lookup(cx, cy),
                "name":         tags.get("name", ""),
                "tags":         tags,
                "shapely_poly": poly,
                "source":       "osm",
            })
            osm_added += 1

        except Exception:
            osm_skipped += 1
            continue

    # Enrich Overture buildings that are missing a class
    for b in overture_buildings:
        if not b["class"]:
            cx, cy = b["shapely_poly"].centroid.x, b["shapely_poly"].centroid.y
            b["class"] = parcel_lookup(cx, cy)

    print(f"  Merged: {len(overture_buildings)} Overture + {osm_added} OSM "
          f"(skipped {osm_skipped})")
    return all_buildings


# ── 3D geometry builders ───────────────────────────────────────────────────────

def _is_stadium(tags: dict) -> bool:
    return (tags.get("building") in ("stadium", "arena") or
            tags.get("leisure") in ("stadium", "ice_rink") or
            tags.get("sport") is not None and tags.get("building") == "yes")


def _make_dome(poly: "Polygon", wall_h: float) -> trimesh.Trimesh:
    """Half-sphere dome sized to fit over the building footprint."""
    cx, cy = poly.centroid.x, poly.centroid.y
    radius = max(10.0, (poly.area ** 0.5) * 0.6)
    sphere = trimesh.creation.icosphere(subdivisions=3, radius=radius)
    # Keep only the top hemisphere (z >= 0 in sphere-local space)
    verts = sphere.vertices
    keep_mask = verts[:, 2] >= -0.05 * radius
    # Build index map and filter faces
    new_idx = np.full(len(verts), -1, dtype=int)
    new_idx[keep_mask] = np.arange(keep_mask.sum())
    faces_keep = []
    for f in sphere.faces:
        if all(keep_mask[f]):
            faces_keep.append(new_idx[f])
    if not faces_keep:
        return sphere
    dome = trimesh.Trimesh(
        vertices=verts[keep_mask],
        faces=np.array(faces_keep),
        process=False,
    )
    dome.apply_translation([cx, cy, wall_h])
    return dome


# ── Renaissance Center helpers ─────────────────────────────────────────────────

_RENZEN_X, _RENZEN_Y = to_xy(42.3293, -83.0398)   # GM Renaissance Center, Detroit


def _is_renzen(cx: float, cy: float) -> bool:
    # 250 m catches all buildings in the RenCen campus so none render as boxes
    return math.hypot(cx - _RENZEN_X, cy - _RENZEN_Y) < 250


def _make_renzen() -> list[trimesh.Trimesh]:
    """Cylindrical RenCen: central Marriott tower + 4 office cylinders + wide podium.

    Real offsets: the 4 office towers (200-500 series) are ~72 m from the central axis.
    Increasing from 52 m keeps a clear gap between the central cylinder (r=32) and each
    office cylinder (r=19): 72 - 32 - 19 = 21 m clearance, no z-fighting.
    """
    cx, cy = _RENZEN_X, _RENZEN_Y
    parts: list[trimesh.Trimesh] = []
    central = trimesh.creation.cylinder(radius=32, height=222, sections=48)
    central.apply_translation([cx, cy, 111])
    parts.append(central)
    for deg in (45, 135, 225, 315):
        rad = math.radians(deg)
        ox, oy = math.cos(rad) * 72, math.sin(rad) * 72
        flank = trimesh.creation.cylinder(radius=19, height=155, sections=32)
        flank.apply_translation([cx + ox, cy + oy, 77])
        parts.append(flank)
    podium = trimesh.creation.box([210, 140, 18])
    podium.apply_translation([cx, cy, 9])
    parts.append(podium)
    return parts


def build_city(buildings: list[dict], elevation_lookup=None) -> dict[str, list[trimesh.Trimesh]]:
    print("Building 3D geometry...")
    buckets: dict[str, list] = {}
    skipped = total = 0
    renzen_built = False

    for b in buildings:
        try:
            poly   = b["shapely_poly"]
            height = b["height"]
            if poly.area < MIN_AREA_M2 or height > MAX_HEIGHT:
                skipped += 1
                continue
            tags = b.get("tags", {})
            cx, cy = poly.centroid.x, poly.centroid.y
            elev = elevation_lookup(cx, cy) if elevation_lookup else 0.0

            # Renaissance Center: replace with accurate cylindrical geometry
            if _is_renzen(cx, cy):
                if not renzen_built:
                    for part in _make_renzen():
                        if elev:
                            part.apply_translation([0, 0, elev])
                        buckets.setdefault("renzen", []).append(part)
                    renzen_built = True
                    total += 1
                else:
                    skipped += 1
                continue

            # Stadiums: boost wall height and add a dome
            if _is_stadium(tags):
                wall_h = max(height, 45.0)
                mesh   = trimesh.creation.extrude_polygon(poly, wall_h)
                if elev:
                    mesh.apply_translation([0, 0, elev])
                buckets.setdefault("entertainment", []).append(mesh)
                dome = _make_dome(poly, wall_h + elev)
                buckets.setdefault("entertainment", []).append(dome)
                total += 1
                continue

            tier = building_tier(height, tags, b.get("class", ""))

            # Per-building color variant: deterministic from centroid so regeneration is stable
            if not tier.startswith("hex_"):
                variant = int(abs(cx * 7 + cy * 13)) % 3
                tier = f"{tier}_v{variant}"

            mesh = trimesh.creation.extrude_polygon(poly, height)

            # Parapet wall: thin raised rim around the rooftop edge
            try:
                p_poly = poly.buffer(-0.6)
                if p_poly.is_valid and not p_poly.is_empty and p_poly.area > 4.0:
                    parapet = trimesh.creation.extrude_polygon(p_poly, 1.2)
                    parapet.apply_translation([0, 0, height])
                    mesh = trimesh.util.concatenate([mesh, parapet])
            except Exception:
                pass

            if elev:
                mesh.apply_translation([0, 0, elev])

            buckets.setdefault(tier, []).append(mesh)
            total += 1
        except Exception:
            skipped += 1
            continue

    print(f"  Built {total} buildings ({skipped} skipped) in {len(buckets)} tiers")
    return buckets


def _polygon_from_geom(geom: list) -> list[tuple]:
    return [to_xy(pt["lat"], pt["lon"]) for pt in geom]


def _mesh_from_coords(coords: list, height: float = 1.0, clip: bool = False) -> list[trimesh.Trimesh]:
    if len(coords) < 3:
        return []
    polygon = Polygon(coords).buffer(0)
    if clip:
        polygon = polygon.intersection(CLIP_BOX)
    if polygon.is_empty or polygon.area < 2.0:
        return []
    polys  = list(polygon.geoms) if isinstance(polygon, MultiPolygon) else [polygon]
    meshes = []
    for poly in polys:
        try:
            meshes.append(trimesh.creation.extrude_polygon(poly, height))
        except Exception:
            continue
    return meshes


def build_water(elements: list) -> list[trimesh.Trimesh]:
    meshes = []
    for el in elements:
        try:
            if el["type"] == "way":
                meshes.extend(_mesh_from_coords(_polygon_from_geom(el.get("geometry", [])),
                                                height=1.0, clip=True))
            elif el["type"] == "relation":
                for member in el.get("members", []):
                    if member.get("role") == "outer" and "geometry" in member:
                        meshes.extend(_mesh_from_coords(_polygon_from_geom(member["geometry"]),
                                                        height=1.0, clip=True))
        except Exception:
            continue
    print(f"  Built {len(meshes)} water meshes")
    return meshes


_HIGHWAY_NO_SIDEWALK = {"motorway", "trunk", "motorway_link", "trunk_link"}


def build_roads(elements: list) -> tuple[list[trimesh.Trimesh], list[trimesh.Trimesh]]:
    road_meshes:     list[trimesh.Trimesh] = []
    sidewalk_meshes: list[trimesh.Trimesh] = []
    for el in elements:
        try:
            geom = el.get("geometry", [])
            if len(geom) < 2:
                continue
            highway = el.get("tags", {}).get("highway", "residential")
            width   = ROAD_WIDTHS.get(highway, 5.0)
            coords  = [to_xy(pt["lat"], pt["lon"]) for pt in geom]
            line     = LineString(coords)
            buffered = line.buffer(width / 2, cap_style=2, join_style=2)
            if not buffered.is_valid or buffered.area < 1.0:
                continue
            road_meshes.append(trimesh.creation.extrude_polygon(buffered, 0.15))

            # Sidewalks: 2 m band outside the road edge, raised 0.05 m above road surface
            if highway not in _HIGHWAY_NO_SIDEWALK:
                sw_outer = line.buffer(width / 2 + 2.0, cap_style=2, join_style=2)
                sidewalk = sw_outer.difference(buffered)
                if sidewalk.is_valid and not sidewalk.is_empty and sidewalk.area > 1.0:
                    sw_polys = (list(sidewalk.geoms)
                                if isinstance(sidewalk, MultiPolygon) else [sidewalk])
                    for sp in sw_polys:
                        try:
                            sidewalk_meshes.append(trimesh.creation.extrude_polygon(sp, 0.20))
                        except Exception:
                            continue
        except Exception:
            continue
    print(f"  Built {len(road_meshes)} road meshes | {len(sidewalk_meshes)} sidewalk meshes")
    return road_meshes, sidewalk_meshes


def build_parks_parking(
    park_coords: list, parking_coords: list
) -> tuple[list[trimesh.Trimesh], list[trimesh.Trimesh]]:
    park_meshes:    list[trimesh.Trimesh] = []
    parking_meshes: list[trimesh.Trimesh] = []
    for coords in park_coords:
        park_meshes.extend(_mesh_from_coords(coords, height=0.15, clip=True))
    for coords in parking_coords:
        parking_meshes.extend(_mesh_from_coords(coords, height=0.08, clip=True))
    print(f"  Built {len(park_meshes)} park meshes | {len(parking_meshes)} parking meshes")
    return park_meshes, parking_meshes


# ── Street furniture ───────────────────────────────────────────────────────────

_FURNITURE_RNG = random.Random(42)   # fixed seed → same city every run

_SKIP_HW_ALL  = {"motorway", "trunk", "motorway_link", "trunk_link",
                  "footway", "path", "cycleway", "steps", "pedestrian"}
_SKIP_HW_CARS = {"motorway", "trunk", "motorway_link", "trunk_link",
                  "primary", "secondary"}


def _perp(dx: float, dy: float) -> tuple[float, float]:
    """Unit perpendicular to a direction vector (left-hand side)."""
    ln = math.hypot(dx, dy)
    return (-dy / ln, dx / ln) if ln > 1e-9 else (0.0, 1.0)


def _make_tree(x: float, y: float, h_trunk: float, r_crown: float) -> tuple:
    trunk = trimesh.creation.cylinder(radius=0.22, height=h_trunk, sections=8)
    trunk.apply_translation([x, y, h_trunk / 2])
    crown = trimesh.creation.icosphere(subdivisions=2, radius=r_crown)
    crown.apply_translation([x, y, h_trunk + r_crown * 0.5])
    return trunk, crown


def _make_lamp(x: float, y: float, arm_dx: float, arm_dy: float) -> trimesh.Trimesh:
    pole = trimesh.creation.cylinder(radius=0.055, height=7.0, sections=6)
    pole.apply_translation([x, y, 3.5])
    arm  = trimesh.creation.box([1.6, 0.07, 0.07])
    arm.apply_translation([x + arm_dx * 0.8, y + arm_dy * 0.8, 7.0])
    head = trimesh.creation.box([0.45, 0.45, 0.18])
    head.apply_translation([x + arm_dx * 1.6, y + arm_dy * 1.6, 6.88])
    return trimesh.util.concatenate([pole, arm, head])


def _make_stop_sign(x: float, y: float) -> tuple[trimesh.Trimesh, trimesh.Trimesh]:
    pole = trimesh.creation.cylinder(radius=0.04, height=2.3, sections=6)
    pole.apply_translation([x, y, 1.15])
    face = trimesh.creation.cylinder(radius=0.30, height=0.05, sections=8)
    face.apply_translation([x, y, 2.50])
    return pole, face


def _make_traffic_light(x: float, y: float) -> tuple:
    pole = trimesh.creation.cylinder(radius=0.06, height=5.0, sections=6)
    pole.apply_translation([x, y, 2.5])
    housing = trimesh.creation.box([0.32, 0.10, 0.90])
    housing.apply_translation([x, y, 4.65])
    red = trimesh.creation.icosphere(subdivisions=1, radius=0.09)
    red.apply_translation([x, y, 4.95])
    yellow = trimesh.creation.icosphere(subdivisions=1, radius=0.09)
    yellow.apply_translation([x, y, 4.65])
    green = trimesh.creation.icosphere(subdivisions=1, radius=0.09)
    green.apply_translation([x, y, 4.35])
    return trimesh.util.concatenate([pole, housing]), red, yellow, green


def build_street_furniture(
    road_elements: list,
    osm_trees:     list[dict],
    osm_lamps:     list[dict],
    osm_stops:     list[dict],
    osm_signals:   list[dict],
) -> dict:
    """Build trees, streetlights, parked cars and pedestrians.

    Trees + lamps use real OSM node positions when available; falls back to
    procedural spacing along road geometry only when OSM returns nothing.
    Road widths come from the _width field set by fetch_roads() (OSM width/lanes
    tags → better than hard-coded defaults).
    Cars and people are always procedural (no free dataset for those).
    """
    tree_trunks:  list[trimesh.Trimesh] = []
    tree_crowns:  list[trimesh.Trimesh] = []
    lights:       list[trimesh.Trimesh] = []
    stop_poles:   list[trimesh.Trimesh] = []
    stop_faces:   list[trimesh.Trimesh] = []
    sig_bodies:   list[trimesh.Trimesh] = []
    sig_reds:     list[trimesh.Trimesh] = []
    sig_yellows:  list[trimesh.Trimesh] = []
    sig_greens:   list[trimesh.Trimesh] = []
    car_groups    = {k: [] for k in ("silver", "blue", "red", "black", "white")}
    person_groups = {k: [] for k in ("navy", "grey", "burgundy", "olive")}

    car_keys    = list(car_groups.keys())
    person_keys = list(person_groups.keys())
    rng = _FURNITURE_RNG
    total_cars = total_people = 0
    MAX_CARS = 700
    MAX_PEOPLE = 1400

    # ── Real OSM trees ─────────────────────────────────────────────────────────
    use_real_trees = len(osm_trees) > 0
    if use_real_trees:
        for t_node in osm_trees:
            x, y = to_xy(t_node["lat"], t_node["lon"])
            h_osm = t_node.get("height")
            h_trunk = float(h_osm) * 0.55 if h_osm else rng.uniform(3.5, 5.5)
            trunk, crown = _make_tree(x, y, h_trunk, rng.uniform(2.0, 3.2))
            tree_trunks.append(trunk)
            tree_crowns.append(crown)
        print(f"  Placed {len(osm_trees)} real OSM trees")

    # ── Real OSM streetlamps ───────────────────────────────────────────────────
    use_real_lamps = len(osm_lamps) > 0
    if use_real_lamps:
        for lamp in osm_lamps:
            x, y = to_xy(lamp["lat"], lamp["lon"])
            lights.append(_make_lamp(x, y, 0.0, 1.0))
        print(f"  Placed {len(osm_lamps)} real OSM street lamps")

    # ── Procedural pass for cars, people, and fallback trees/lamps ────────────
    for el in road_elements:
        geom = el.get("geometry", [])
        if len(geom) < 2:
            continue
        highway = el.get("tags", {}).get("highway", "residential")
        if highway in _SKIP_HW_ALL:
            continue

        half_road  = el.get("_width", ROAD_WIDTHS.get(highway, 6.0)) / 2.0
        tree_off   = half_road + 2.8
        light_off  = half_road + 0.7
        car_off    = half_road - 1.2
        person_off = half_road + 3.5

        pts = [to_xy(pt["lat"], pt["lon"]) for pt in geom]

        for i in range(len(pts) - 1):
            x0, y0 = pts[i]
            x1, y1 = pts[i + 1]
            seg = math.hypot(x1 - x0, y1 - y0)
            if seg < 8:
                continue

            dx, dy = (x1 - x0) / seg, (y1 - y0) / seg
            px, py = _perp(dx, dy)

            # Fallback trees (only when OSM had none)
            if not use_real_trees:
                t = rng.uniform(6, 14)
                while t < seg - 4:
                    cx = x0 + t * dx + tree_off * px
                    cy = y0 + t * dy + tree_off * py
                    trunk, crown = _make_tree(cx, cy, rng.uniform(3.5, 5.5), rng.uniform(2.0, 3.2))
                    tree_trunks.append(trunk)
                    tree_crowns.append(crown)
                    t += rng.uniform(14, 20)

            # Fallback lamps (only when OSM had none)
            if not use_real_lamps:
                t = rng.uniform(10, 20)
                while t < seg - 4:
                    for side in (1.0, -1.0):
                        lx = x0 + t * dx + side * light_off * px
                        ly = y0 + t * dy + side * light_off * py
                        lights.append(_make_lamp(lx, ly, -side * px, -side * py))
                    t += rng.uniform(28, 36)

            # Parked cars (always procedural)
            if highway not in _SKIP_HW_CARS and total_cars < MAX_CARS:
                t = rng.uniform(1, 4)
                while t < seg - 5 and total_cars < MAX_CARS:
                    if rng.random() < 0.60:
                        cx = x0 + t * dx + car_off * px
                        cy = y0 + t * dy + car_off * py
                        angle = math.atan2(dy, dx)
                        rot   = trimesh.transformations.rotation_matrix(angle, [0, 0, 1])
                        # Body — lower slab (engine bay + boot height)
                        body = trimesh.creation.box([4.5, 1.82, 0.80])
                        # Cabin — shorter, narrower, centred slightly rearward
                        cabin = trimesh.creation.box([2.20, 1.60, 0.60])
                        cabin.apply_translation([0.10, 0, 0.70])
                        # Wheels — 4 cylinders (trimesh Z-up, Z axis = axle)
                        for wx, wy in ((-1.30, 0.85), (-1.30, -0.85),
                                       ( 1.30, 0.85), ( 1.30, -0.85)):
                            w = trimesh.creation.cylinder(radius=0.30, height=0.20, sections=12)
                            # rotate wheel so its flat faces outward (along Y axis)
                            w.apply_transform(
                                trimesh.transformations.rotation_matrix(math.pi/2, [1, 0, 0])
                            )
                            w.apply_translation([wx, wy, 0.30])
                            body = trimesh.util.concatenate([body, w])
                        car = trimesh.util.concatenate([body, cabin])
                        car.apply_transform(rot)
                        car.apply_translation([cx, cy, 0.40])
                        car_groups[car_keys[total_cars % len(car_keys)]].append(car)
                        total_cars += 1
                    t += rng.uniform(5.0, 6.5)

            # Pedestrians (always procedural)
            if total_people < MAX_PEOPLE:
                t = rng.uniform(5, 15)
                while t < seg and total_people < MAX_PEOPLE:
                    if rng.random() < 0.30:
                        side = rng.choice([1.0, -1.0])
                        off  = person_off + rng.uniform(-0.6, 0.6)
                        for _ in range(rng.randint(1, 3)):
                            if total_people >= MAX_PEOPLE:
                                break
                            bx = x0 + t * dx + side * off * px + rng.uniform(-0.4, 0.4)
                            by = y0 + t * dy + side * off * py + rng.uniform(-0.4, 0.4)
                            h  = rng.uniform(1.62, 1.85)
                            body = trimesh.creation.cylinder(radius=0.18, height=h * 0.70, sections=6)
                            body.apply_translation([bx, by, h * 0.35])
                            head = trimesh.creation.icosphere(subdivisions=1, radius=h * 0.09)
                            head.apply_translation([bx, by, h * 0.88])
                            person_groups[person_keys[total_people % len(person_keys)]].append(
                                trimesh.util.concatenate([body, head])
                            )
                            total_people += 1
                    t += rng.uniform(8, 22)

    # ── Real OSM stop signs ────────────────────────────────────────────────────
    MAX_STOPS = 2000
    for node in osm_stops[:MAX_STOPS]:
        x, y = to_xy(node["lat"], node["lon"])
        pole, face = _make_stop_sign(x, y)
        stop_poles.append(pole)
        stop_faces.append(face)
    if stop_poles:
        print(f"  Placed {len(stop_poles)} stop signs")

    # ── Real OSM traffic signals ───────────────────────────────────────────────
    MAX_SIGNALS = 1000
    for node in osm_signals[:MAX_SIGNALS]:
        x, y = to_xy(node["lat"], node["lon"])
        body, r, yel, grn = _make_traffic_light(x, y)
        sig_bodies.append(body)
        sig_reds.append(r)
        sig_yellows.append(yel)
        sig_greens.append(grn)
    if sig_bodies:
        print(f"  Placed {len(sig_bodies)} traffic signals")

    print(f"  Street furniture: {len(tree_trunks)} trees | "
          f"{len(lights)} lights | "
          f"{sum(len(v) for v in car_groups.values())} cars | "
          f"{total_people} people | "
          f"{len(stop_poles)} stop signs | {len(sig_bodies)} signals")
    return {
        "tree_trunks":  tree_trunks,
        "tree_crowns":  tree_crowns,
        "lights":       lights,
        "stop_poles":   stop_poles,
        "stop_faces":   stop_faces,
        "sig_bodies":   sig_bodies,
        "sig_reds":     sig_reds,
        "sig_yellows":  sig_yellows,
        "sig_greens":   sig_greens,
        "cars":         {k: v for k, v in car_groups.items() if v},
        "people":       {k: v for k, v in person_groups.items() if v},
    }


REGISTRY_PATH = os.path.join(
    os.path.dirname(__file__),
    "../../Stamped! A City Passport/Resources/BuildingRegistry.json"
)


def load_landmarks() -> list[dict]:
    with open(REGISTRY_PATH) as f:
        data = json.load(f)
    landmarks = []
    for b in data.get(CITY.title(), []):
        lat, lon = b.get("latitude"), b.get("longitude")
        if lat and lon:
            landmarks.append({
                "name":   b.get("name", ""),
                "lat":    lat,
                "lon":    lon,
                "height": max(float(b.get("height", 20.0)), 15.0),
            })
    print(f"Loaded {len(landmarks)} landmarks")
    return landmarks


def build_landmarks(landmarks: list[dict]) -> list[dict]:
    """Return per-landmark dicts. Only creates a base mesh when a Wikimedia photo
    is available; otherwise the landmark is identified purely by lat/lon proximity
    at tap time (no extra geometry overlaid on the OSM building).
    """
    result = []
    found_photos = 0

    for lm in landmarks:
        try:
            x, y = to_xy(lm["lat"], lm["lon"])
            # Use the landmark's real height; minimum 10 m so it's always visible
            base_h = max(float(lm.get("height", 20)), 10.0)
            # Footprint radius: scale with height so tall buildings get a larger base
            r = max(12.0, min(60.0, base_h * 0.35))

            photo_path = fetch_wikimedia_photo(lm["name"])
            if photo_path:
                found_photos += 1
                # Rectangular footprint sized to the building's scale
                base = Polygon([
                    (x - r, y - r * 0.7), (x + r, y - r * 0.7),
                    (x + r, y + r * 0.7), (x - r, y + r * 0.7),
                ])
                result.append({
                    "name":      lm["name"],
                    "base_mesh": trimesh.creation.extrude_polygon(base, base_h),
                    "photo_path": photo_path,
                })
            else:
                result.append({
                    "name":      lm["name"],
                    "base_mesh": None,
                    "photo_path": None,
                })
        except Exception:
            continue

    print(f"  Built {len(result)} landmark markers ({found_photos} with photos)")
    return result


# ── USD / USDZ export ──────────────────────────────────────────────────────────

def _tier_color(tier: str) -> tuple[tuple[float, float, float], float, float]:
    if tier.endswith(("_v0", "_v1", "_v2")):
        base_color, roughness, metallic = _tier_color(tier[:-3])
        shifts = (0.0, -0.08, +0.08)
        shift = shifts[int(tier[-1])]
        return tuple(max(0.0, min(1.0, c + shift)) for c in base_color), roughness, metallic
    if tier == "short": return (0.90, 0.86, 0.74), 0.92, 0.00
    if tier == "mid":   return (0.70, 0.70, 0.68), 0.88, 0.00
    if tier == "tall":  return (0.62, 0.68, 0.76), 0.55, 0.00
    if tier in CLASS_COLORS:
        roughness = 0.40 if tier in ("commercial", "hospitality") else 0.80
        return CLASS_COLORS[tier], roughness, 0.00
    if tier in MATERIAL_COLORS:
        roughness = 0.40 if tier == "glass" else 0.80
        return MATERIAL_COLORS[tier], roughness, 0.00
    if tier.startswith("hex_"):
        h   = tier[4:]
        rgb = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
        return rgb, 0.80, 0.00
    return (0.80, 0.80, 0.78), 0.88, 0.00


def _write_mesh(stage, path: str, mesh: trimesh.Trimesh, mat,
                uvs: np.ndarray | None = None) -> None:
    prim = UsdGeom.Mesh.Define(stage, path)
    prim.GetPointsAttr().Set(Vt.Vec3fArray([
        Gf.Vec3f(float(v[0]), float(v[2]), float(-v[1])) for v in mesh.vertices
    ]))
    prim.GetFaceVertexCountsAttr().Set(Vt.IntArray([3] * len(mesh.faces)))
    prim.GetFaceVertexIndicesAttr().Set(Vt.IntArray([int(i) for f in mesh.faces for i in f]))
    prim.GetSubdivisionSchemeAttr().Set("none")

    if uvs is not None:
        # faceVarying has one UV per face-vertex (len = 3*faces); vertex has one per vertex
        interp = (UsdGeom.Tokens.faceVarying
                  if len(uvs) == 3 * len(mesh.faces)
                  else UsdGeom.Tokens.vertex)
        st_pv = UsdGeom.PrimvarsAPI(prim).CreatePrimvar(
            "st", Sdf.ValueTypeNames.TexCoord2fArray, interp
        )
        st_pv.Set(Vt.Vec2fArray([Gf.Vec2f(float(u), float(v)) for u, v in uvs]))

    UsdShade.MaterialBindingAPI(prim).Bind(mat)


def _make_solid_material(stage, path: str, color: tuple, roughness: float, metallic: float):
    mat    = UsdShade.Material.Define(stage, path)
    shader = UsdShade.Shader.Define(stage, f"{path}/shader")
    shader.CreateIdAttr("UsdPreviewSurface")
    shader.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).Set(Gf.Vec3f(*color))
    shader.CreateInput("roughness",    Sdf.ValueTypeNames.Float).Set(roughness)
    shader.CreateInput("metallic",     Sdf.ValueTypeNames.Float).Set(metallic)
    mat.CreateSurfaceOutput().ConnectToSource(shader.ConnectableAPI(), "surface")
    return mat


def _make_texture_material(stage, path: str, tex_filename: str,
                           roughness: float = 0.75, wrap: str = "repeat"):
    """Create a UsdPreviewSurface material driven by a UV texture file.

    tex_filename must be just the basename (e.g. "satellite.png") — the USD file
    and the textures both live in tmpdir so a plain relative name resolves correctly
    and UsdUtils.CreateNewUsdzPackage can find and bundle the file.
    """
    mat = UsdShade.Material.Define(stage, path)
    pbr = UsdShade.Shader.Define(stage, f"{path}/pbr")
    pbr.CreateIdAttr("UsdPreviewSurface")
    pbr.CreateInput("roughness", Sdf.ValueTypeNames.Float).Set(roughness)
    pbr.CreateInput("metallic",  Sdf.ValueTypeNames.Float).Set(0.0)

    tex = UsdShade.Shader.Define(stage, f"{path}/tex")
    tex.CreateIdAttr("UsdUVTexture")
    tex.CreateInput("file",  Sdf.ValueTypeNames.Asset).Set(tex_filename)
    tex.CreateInput("wrapS", Sdf.ValueTypeNames.Token).Set(wrap)
    tex.CreateInput("wrapT", Sdf.ValueTypeNames.Token).Set(wrap)

    st_reader = UsdShade.Shader.Define(stage, f"{path}/st")
    st_reader.CreateIdAttr("UsdPrimvarReader_float2")
    st_reader.CreateInput("varname", Sdf.ValueTypeNames.Token).Set("st")
    tex.CreateInput("st", Sdf.ValueTypeNames.Float2).ConnectToSource(
        st_reader.ConnectableAPI(), "result"
    )
    pbr.CreateInput("diffuseColor", Sdf.ValueTypeNames.Color3f).ConnectToSource(
        tex.ConnectableAPI(), "rgb"
    )
    mat.CreateSurfaceOutput().ConnectToSource(pbr.ConnectableAPI(), "surface")
    return mat


def fetch_satellite_image(tmpdir: str) -> str | None:
    ZOOM      = 17
    TILE_SIZE = 256
    ESRI      = "https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/tile"

    # Cache the cropped satellite PNG to avoid re-downloading ~900 tiles every run
    cache_png = os.path.join(CACHE_DIR, f"satellite_{CITY}_z{ZOOM}_{LAT_MIN}_{LAT_MAX}_{LON_MIN}_{LON_MAX}.png")
    img_path  = os.path.join(tmpdir, "satellite.png")
    if os.path.exists(cache_png):
        import shutil as _shutil
        _shutil.copy2(cache_png, img_path)
        from PIL import Image as _Image
        sz = _Image.open(img_path).size
        print(f"  Satellite: {sz[0]}×{sz[1]} px (cached)")
        return img_path

    def deg2tile(lat, lon):
        lat_r = math.radians(lat)
        n = 2 ** ZOOM
        return (
            int((lon + 180) / 360 * n),
            int((1 - math.log(math.tan(lat_r) + 1 / math.cos(lat_r)) / math.pi) / 2 * n),
        )

    def tile2lon(x): return x / (2 ** ZOOM) * 360 - 180
    def tile2lat(y): return math.degrees(math.atan(math.sinh(math.pi - 2 * math.pi * y / (2 ** ZOOM))))

    x_min, y_max = deg2tile(LAT_MIN, LON_MIN)
    x_max, y_min = deg2tile(LAT_MAX, LON_MAX)
    cols, rows   = x_max - x_min + 1, y_max - y_min + 1
    print(f"Fetching {cols * rows} satellite tiles ({cols}×{rows})...")

    stitched = Image.new("RGB", (cols * TILE_SIZE, rows * TILE_SIZE))
    for row, ty in enumerate(range(y_min, y_max + 1)):
        for col, tx in enumerate(range(x_min, x_max + 1)):
            try:
                resp = requests.get(f"{ESRI}/{ZOOM}/{ty}/{tx}", timeout=15)
                stitched.paste(Image.open(io.BytesIO(resp.content)), (col * TILE_SIZE, row * TILE_SIZE))
            except Exception:
                pass

    lon_l, lon_r = tile2lon(x_min), tile2lon(x_max + 1)
    lat_t, lat_b = tile2lat(y_min), tile2lat(y_max + 1)
    w, h = stitched.size
    # No flip: image has north at top, V=0 (image bottom) = south = correct for USD ground UVs
    cropped = stitched.crop((
        int((LON_MIN - lon_l) / (lon_r - lon_l) * w),
        int((lat_t - LAT_MAX) / (lat_t - lat_b) * h),
        int((LON_MAX - lon_l) / (lon_r - lon_l) * w),
        int((lat_t - LAT_MIN) / (lat_t - lat_b) * h),
    ))

    os.makedirs(CACHE_DIR, exist_ok=True)
    cropped.save(cache_png)
    cropped.save(img_path)
    print(f"  Satellite: {cropped.size[0]}×{cropped.size[1]} px")
    return img_path


_SAT_GRID = 4  # 4×4 = 16 tiles; each tile stays sharp when zoomed in


def _write_satellite_tiles(stage, city_path: str, tmpdir: str, sat_path: str) -> None:
    """Split the satellite into a _SAT_GRID×_SAT_GRID tiled ground plane.

    Each tile is a separate USD Mesh with its own JPEG texture so the renderer
    can use the full tile resolution when the camera is close to that patch.
    """
    img   = Image.open(sat_path)
    img_w, img_h = img.size

    half_w = (LON_MAX - LON_MIN) * LON_TO_M / 2
    half_h = (LAT_MAX - LAT_MIN) * LAT_TO_M / 2
    tile_w = 2 * half_w / _SAT_GRID
    tile_h = 2 * half_h / _SAT_GRID

    for row in range(_SAT_GRID):
        for col in range(_SAT_GRID):
            # USD scene coords (Y-up: +Z = south, -Z = north)
            x_west  = -half_w + col * tile_w
            x_east  = x_west + tile_w
            z_north = -half_h + row * tile_h   # more negative = further north
            z_south = z_north + tile_h

            # Pixel crop — image has north at top, row=0 of grid is northernmost
            px0 = int(col       * img_w / _SAT_GRID)
            px1 = int((col + 1) * img_w / _SAT_GRID)
            py0 = int(row       * img_h / _SAT_GRID)
            py1 = int((row + 1) * img_h / _SAT_GRID)
            tile_img = img.crop((px0, py0, px1, py1))

            tile_name = f"satellite_{row}_{col}.jpg"
            tile_img.save(os.path.join(tmpdir, tile_name), "JPEG", quality=90)

            mat = _make_texture_material(
                stage, f"{city_path}/materials/ground_{row}_{col}",
                f"0/{tile_name}", roughness=0.95, wrap="clamp"
            )
            gnd = UsdGeom.Mesh.Define(stage, f"{city_path}/ground_{row}_{col}")
            gnd.GetPointsAttr().Set(Vt.Vec3fArray([
                Gf.Vec3f(x_west, 0, z_south),   # SW → UV (0,0) image-bottom = south
                Gf.Vec3f(x_east, 0, z_south),   # SE → UV (1,0)
                Gf.Vec3f(x_east, 0, z_north),   # NE → UV (1,1) image-top = north
                Gf.Vec3f(x_west, 0, z_north),   # NW → UV (0,1)
            ]))
            gnd.GetFaceVertexCountsAttr().Set(Vt.IntArray([4]))
            gnd.GetFaceVertexIndicesAttr().Set(Vt.IntArray([0, 1, 2, 3]))
            gnd.GetSubdivisionSchemeAttr().Set("none")
            UsdGeom.PrimvarsAPI(gnd).CreatePrimvar(
                "st", Sdf.ValueTypeNames.TexCoord2fArray, UsdGeom.Tokens.varying
            ).Set(Vt.Vec2fArray([
                Gf.Vec2f(0, 0), Gf.Vec2f(1, 0), Gf.Vec2f(1, 1), Gf.Vec2f(0, 1),
            ]))
            UsdShade.MaterialBindingAPI(gnd).Bind(mat)

    print(f"  Satellite: {_SAT_GRID}×{_SAT_GRID} tiles ({img_w}×{img_h} px total)")


def export_usdz(
    buckets:          dict[str, list[trimesh.Trimesh]],
    water_meshes:     list[trimesh.Trimesh],
    road_meshes:      list[trimesh.Trimesh],
    sidewalk_meshes:  list[trimesh.Trimesh],
    park_meshes:      list[trimesh.Trimesh],
    parking_meshes:   list[trimesh.Trimesh],
    landmark_data:    list[dict],
    furniture:        dict,
) -> None:
    print(f"Combining meshes ({len(buckets)} building tiers)...")
    os.makedirs("output", exist_ok=True)
    usdz_path = os.path.abspath(f"output/{CITY}.usdz")

    print("Writing USD stage...")
    with tempfile.TemporaryDirectory() as _raw_tmpdir:
        tmpdir   = os.path.realpath(_raw_tmpdir)   # resolve /var → /private/var on macOS
        # UsdUtils.CreateNewUsdzPackage resolves assets as "0/<name>" relative to the
        # .usda layer.  Save ALL textures into tmpdir/0/ so they are found at that path.
        texdir   = os.path.join(tmpdir, "0")
        os.makedirs(texdir, exist_ok=True)

        usd_path = os.path.join(tmpdir, f"{CITY}.usda")
        stage    = Usd.Stage.CreateNew(usd_path)
        UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.y)
        xform = UsdGeom.Xform.Define(stage, f"/{CITY}")

        # ── Satellite ground (4×4 tiled for sharpness at any zoom level) ────────
        sat_path = fetch_satellite_image(tmpdir)
        if sat_path:
            _write_satellite_tiles(stage, f"/{CITY}", texdir, sat_path)

        # ground_base removed — the satellite tiles are single-sided flat quads that
        # cover the ground completely; a backing box is not needed and its axis
        # mapping through _write_mesh made it 6 m tall (not 3 cm), creating the
        # large brown wall visible in the mixed-immersive view.
        half_w = (LON_MAX - LON_MIN) * LON_TO_M / 2
        half_h = (LAT_MAX - LAT_MIN) * LAT_TO_M / 2

        # ── Buildings — procedural facade texture per tier ────────────────────
        for tier, tier_meshes in buckets.items():
            try:
                combined  = trimesh.util.concatenate(tier_meshes)
                safe_name = tier.replace(":", "_").replace("#", "").replace("/", "_")

                # Generate facade texture into texdir; reference with "0/" prefix
                tex_file = generate_facade_texture(tier, texdir)
                color, roughness, _ = _tier_color(tier)

                if tier == "renzen":
                    # GM Renaissance Center — dark bronze-tinted glass curtain wall
                    mat = _make_solid_material(
                        stage, f"/{CITY}/materials/bld_renzen",
                        (0.06, 0.05, 0.04), 0.12, 0.25
                    )
                    _write_mesh(stage, f"/{CITY}/buildings_renzen", combined, mat)
                elif tier.startswith("hex_"):
                    # Hex-colour buildings: use solid colour, no window texture
                    mat = _make_solid_material(
                        stage, f"/{CITY}/materials/bld_{safe_name}", color, roughness, 0.0
                    )
                    _write_mesh(stage, f"/{CITY}/buildings_{safe_name}", combined, mat)
                else:
                    mat = _make_texture_material(
                        stage, f"/{CITY}/materials/bld_{safe_name}",
                        f"0/{os.path.basename(tex_file)}", roughness=roughness
                    )
                    uvs = compute_face_uvs(combined)
                    _write_mesh(stage, f"/{CITY}/buildings_{safe_name}", combined, mat, uvs=uvs)
            except Exception as exc:
                print(f"  Warning: skipped tier '{tier}': {exc}")

        # ── Roads ─────────────────────────────────────────────────────────────
        if road_meshes:
            road_mat = _make_solid_material(
                stage, f"/{CITY}/materials/roads", (0.38, 0.38, 0.38), 0.9, 0.0
            )
            combined = trimesh.util.concatenate(road_meshes)
            _write_mesh(stage, f"/{CITY}/roads", combined, road_mat)

        # ── Water ─────────────────────────────────────────────────────────────
        if water_meshes:
            wat_mat = _make_solid_material(
                stage, f"/{CITY}/materials/water", (0.04, 0.24, 0.48), 0.05, 0.02
            )
            combined = trimesh.util.concatenate(water_meshes)
            _write_mesh(stage, f"/{CITY}/water", combined, wat_mat)

        # ── Sidewalks ─────────────────────────────────────────────────────────
        if sidewalk_meshes:
            sw_mat = _make_solid_material(
                stage, f"/{CITY}/materials/sidewalk", (0.78, 0.76, 0.72), 0.92, 0.0
            )
            _write_mesh(stage, f"/{CITY}/sidewalks",
                        trimesh.util.concatenate(sidewalk_meshes), sw_mat)

        # ── Parks ─────────────────────────────────────────────────────────────
        if park_meshes:
            park_mat = _make_solid_material(
                stage, f"/{CITY}/materials/park", (0.22, 0.52, 0.18), 0.95, 0.0
            )
            _write_mesh(stage, f"/{CITY}/parks",
                        trimesh.util.concatenate(park_meshes), park_mat)

        # ── Parking lots ──────────────────────────────────────────────────────
        if parking_meshes:
            parking_mat = _make_solid_material(
                stage, f"/{CITY}/materials/parking", (0.28, 0.28, 0.28), 0.92, 0.0
            )
            _write_mesh(stage, f"/{CITY}/parking_lots",
                        trimesh.util.concatenate(parking_meshes), parking_mat)

        # ── Landmarks — photo-textured base only when a photo is available ───
        for i, lm in enumerate(landmark_data):
            if not lm["photo_path"] or lm["base_mesh"] is None:
                continue
            safe_lm    = f"lm_{i}"
            photo_name = f"lm_{i}_photo.jpg"
            shutil.copy2(lm["photo_path"], os.path.join(texdir, photo_name))
            photo_mat = _make_texture_material(
                stage, f"/{CITY}/materials/{safe_lm}_photo",
                f"0/{photo_name}", roughness=0.6, wrap="clamp"
            )
            uvs = compute_box_uvs(lm["base_mesh"].vertices, tile_m=6.0)
            _write_mesh(stage, f"/{CITY}/{safe_lm}_base", lm["base_mesh"], photo_mat, uvs=uvs)

        # ── Street furniture ───────────────────────────────────────────────
        # Trees — brown trunk, green crown (separate materials)
        if furniture.get("tree_trunks"):
            trunk_mat = _make_solid_material(
                stage, f"/{CITY}/materials/tree_trunk", (0.35, 0.22, 0.10), 0.95, 0.0
            )
            _write_mesh(stage, f"/{CITY}/tree_trunks",
                        trimesh.util.concatenate(furniture["tree_trunks"]), trunk_mat)
        if furniture.get("tree_crowns"):
            crown_mat = _make_solid_material(
                stage, f"/{CITY}/materials/tree_crown", (0.20, 0.45, 0.18), 0.90, 0.0
            )
            _write_mesh(stage, f"/{CITY}/tree_crowns",
                        trimesh.util.concatenate(furniture["tree_crowns"]), crown_mat)

        # Streetlights — dark charcoal
        if furniture.get("lights"):
            light_mat = _make_solid_material(
                stage, f"/{CITY}/materials/streetlight", (0.18, 0.18, 0.20), 0.70, 0.10
            )
            _write_mesh(stage, f"/{CITY}/streetlights",
                        trimesh.util.concatenate(furniture["lights"]), light_mat)

        # Parked cars — one mesh per colour
        CAR_COLORS = {
            "silver":  (0.72, 0.72, 0.74),
            "blue":    (0.15, 0.28, 0.52),
            "red":     (0.62, 0.10, 0.10),
            "black":   (0.08, 0.08, 0.09),
            "white":   (0.90, 0.90, 0.90),
        }
        for cname, cmeshes in furniture.get("cars", {}).items():
            color = CAR_COLORS.get(cname, (0.6, 0.6, 0.6))
            mat   = _make_solid_material(
                stage, f"/{CITY}/materials/car_{cname}", color, 0.35, 0.20
            )
            _write_mesh(stage, f"/{CITY}/cars_{cname}",
                        trimesh.util.concatenate(cmeshes), mat)

        # Pedestrians — one mesh per clothing colour
        PERSON_COLORS = {
            "navy":     (0.12, 0.18, 0.38),
            "grey":     (0.55, 0.55, 0.58),
            "burgundy": (0.45, 0.10, 0.12),
            "olive":    (0.28, 0.32, 0.18),
        }
        for pname, pmeshes in furniture.get("people", {}).items():
            color = PERSON_COLORS.get(pname, (0.5, 0.5, 0.5))
            mat   = _make_solid_material(
                stage, f"/{CITY}/materials/person_{pname}", color, 0.85, 0.0
            )
            _write_mesh(stage, f"/{CITY}/people_{pname}",
                        trimesh.util.concatenate(pmeshes), mat)

        # Stop signs — grey pole, red octagon face
        if furniture.get("stop_poles"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/stop_pole", (0.45, 0.45, 0.45), 0.60, 0.30
            )
            _write_mesh(stage, f"/{CITY}/stop_poles",
                        trimesh.util.concatenate(furniture["stop_poles"]), mat)
        if furniture.get("stop_faces"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/stop_face", (0.80, 0.06, 0.06), 0.40, 0.05
            )
            _write_mesh(stage, f"/{CITY}/stop_faces",
                        trimesh.util.concatenate(furniture["stop_faces"]), mat)

        # Traffic signals — dark housing, coloured lenses
        if furniture.get("sig_bodies"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/sig_body", (0.14, 0.14, 0.16), 0.70, 0.20
            )
            _write_mesh(stage, f"/{CITY}/sig_bodies",
                        trimesh.util.concatenate(furniture["sig_bodies"]), mat)
        if furniture.get("sig_reds"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/sig_red", (0.92, 0.04, 0.04), 0.25, 0.0
            )
            _write_mesh(stage, f"/{CITY}/sig_reds",
                        trimesh.util.concatenate(furniture["sig_reds"]), mat)
        if furniture.get("sig_yellows"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/sig_yellow", (0.95, 0.76, 0.04), 0.25, 0.0
            )
            _write_mesh(stage, f"/{CITY}/sig_yellows",
                        trimesh.util.concatenate(furniture["sig_yellows"]), mat)
        if furniture.get("sig_greens"):
            mat = _make_solid_material(
                stage, f"/{CITY}/materials/sig_green", (0.04, 0.82, 0.22), 0.25, 0.0
            )
            _write_mesh(stage, f"/{CITY}/sig_greens",
                        trimesh.util.concatenate(furniture["sig_greens"]), mat)

        stage.SetDefaultPrim(xform.GetPrim())
        stage.Save()

        print("Packaging as USDZ...")
        success = UsdUtils.CreateNewUsdzPackage(Sdf.AssetPath(usd_path), usdz_path)

    if success and os.path.exists(usdz_path):
        size_mb = os.path.getsize(usdz_path) / (1024 * 1024)
        print(f"\n  {usdz_path}  ({size_mb:.1f} MB)")
        print("  AirDrop to iPhone → AR Quick Look.")
    else:
        print("  USDZ packaging failed.")


# ── Entry point ────────────────────────────────────────────────────────────────

def main() -> None:
    overture_buildings  = fetch_overture_buildings()
    osm_ways, osm_nodes = fetch_osm_buildings()
    water_elements      = fetch_water()
    road_elements       = fetch_roads()
    osm_trees              = fetch_osm_trees()
    osm_lamps              = fetch_osm_lamps()
    osm_stops, osm_signals = fetch_osm_signs()
    park_coords, parking_coords = fetch_osm_parks_parking()
    landmarks_raw          = load_landmarks()
    parcels             = fetch_detroit_parcels()
    elev_grid           = fetch_elevation_grid()

    parcel_lookup    = build_parcel_lookup(parcels)
    elevation_lookup = make_elevation_lookup(elev_grid)
    all_buildings = merge_osm_into_overture(
        overture_buildings, osm_ways, osm_nodes, parcel_lookup
    )

    if not all_buildings:
        print("No buildings found. Check bounding box or network.")
        return

    print("\nFetching Wikimedia photos for landmarks (cached after first run)...")
    landmark_data = build_landmarks(landmarks_raw)

    buckets      = build_city(all_buildings, elevation_lookup)
    water_meshes = build_water(water_elements)
    road_meshes, sidewalk_meshes = build_roads(road_elements)

    print("\nBuilding parks and parking lots...")
    park_meshes, parking_meshes = build_parks_parking(park_coords, parking_coords)

    print("\nBuilding street furniture (trees, lights, cars, people)...")
    furniture = build_street_furniture(road_elements, osm_trees, osm_lamps, osm_stops, osm_signals)

    total = sum(len(v) for v in buckets.values())
    print(f"\nSummary: {total} buildings | {len(water_meshes)} water | "
          f"{len(road_meshes)} roads | {len(sidewalk_meshes)} sidewalks | "
          f"{len(park_meshes)} parks | {len(parking_meshes)} parking | "
          f"{len(landmark_data)} landmarks")
    print(f"Tiers: {', '.join(sorted(buckets.keys()))}")

    export_usdz(buckets, water_meshes, road_meshes, sidewalk_meshes,
                park_meshes, parking_meshes, landmark_data, furniture)
    print(f"\nDone — {CITY.title()} USDZ generated.")


if __name__ == "__main__":
    main()
