#!/usr/bin/env python3
"""
Validate coordinates in BuildingRegistry.json
- Confirm every building has latitude and longitude
- Check numeric ranges
- Flag exact 0,0
- Compute per-city centroid and flag outliers
- Output a JSON report to scripts/validate_report.json and print a summary
"""
from pathlib import Path
import json
import math

ROOT = Path(__file__).resolve().parents[1]
REG_PATH = ROOT / 'Stamped! A City Passport' / 'Resources' / 'BuildingRegistry.json'
OUT = Path(__file__).parent / 'validate_report.json'

# haversine
def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))


def is_valid_number(x):
    try:
        if x is None:
            return False
        v = float(x)
        if math.isfinite(v):
            return True
        return False
    except Exception:
        return False


def main():
    data = json.loads(REG_PATH.read_text(encoding='utf-8'))
    total = 0
    with_coords = 0
    invalid_coords = []
    zero_coords = []
    per_city = {}

    for city, buildings in data.items():
        if not isinstance(buildings, list):
            continue
        per_city.setdefault(city, [])
        for b in buildings:
            total += 1
            lat = b.get('latitude')
            lon = b.get('longitude')
            if is_valid_number(lat) and is_valid_number(lon):
                with_coords += 1
                latf = float(lat)
                lonf = float(lon)
                per_city[city].append({'id': b.get('id'), 'name': b.get('name'), 'lat': latf, 'lon': lonf})
                if abs(latf) < 1e-9 and abs(lonf) < 1e-9:
                    zero_coords.append({'id': b.get('id'), 'city': city, 'name': b.get('name')})
                if not (-90 <= latf <= 90 and -180 <= lonf <= 180):
                    invalid_coords.append({'id': b.get('id'), 'city': city, 'name': b.get('name'), 'lat': latf, 'lon': lonf})
            else:
                invalid_coords.append({'id': b.get('id'), 'city': city, 'name': b.get('name'), 'lat': lat, 'lon': lon})

    # per-city centroid and outliers
    outliers = []
    stats = {}
    for city, items in per_city.items():
        if not items:
            continue
        # compute mean lat/lon
        mean_lat = sum(i['lat'] for i in items) / len(items)
        mean_lon = sum(i['lon'] for i in items) / len(items)
        # compute distances
        dists = []
        for i in items:
            d = haversine(mean_lat, mean_lon, i['lat'], i['lon'])
            dists.append(d)
        # stats
        if len(dists) >= 2:
            mean_d = sum(dists) / len(dists)
            # std dev
            var = sum((x-mean_d)**2 for x in dists) / (len(dists)-1)
            sd = math.sqrt(var)
        else:
            mean_d = 0.0
            sd = 0.0
        # threshold: if many items, flag > max(50km, mean + 3*sd). If few items, use 50km
        if len(dists) >= 5:
            thresh = max(50.0, mean_d + 3*sd)
        else:
            thresh = 50.0
        # collect outliers
        for i, d in zip(items, dists):
            if d > thresh:
                outliers.append({'id': i['id'], 'city': city, 'name': i['name'], 'lat': i['lat'], 'lon': i['lon'], 'dist_km': d, 'city_centroid_lat': mean_lat, 'city_centroid_lon': mean_lon, 'threshold_km': thresh})
        stats[city] = {'count': len(items), 'centroid': {'lat': mean_lat, 'lon': mean_lon}, 'mean_dist_km': mean_d, 'sd_km': sd, 'threshold_km': thresh}

    report = {
        'total_buildings': total,
        'with_coordinates': with_coords,
        'missing_coordinates': total - with_coords,
        'invalid_coords': invalid_coords,
        'zero_coords': zero_coords,
        'outliers': outliers,
        'city_stats_sample': {k: stats[k] for k in list(stats)[:10]}
    }

    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Wrote validation report to', OUT)
    print('TOTAL_BUILDINGS:', total)
    print('WITH_COORDS:', with_coords)
    print('MISSING:', total-with_coords)
    print('INVALID_COORDS:', len(invalid_coords))
    print('ZERO_COORDS:', len(zero_coords))
    print('OUTLIERS:', len(outliers))

if __name__ == '__main__':
    main()
