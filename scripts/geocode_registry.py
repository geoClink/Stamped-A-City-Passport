#!/usr/bin/env python3
"""
Batch geocode BuildingRegistry JSON and inject latitude/longitude for each building.

Usage:
    python3 scripts/geocode_registry.py \
        --input "Stamped! A City Passport/Resources/BuildingRegistry.json" \
        --output "Stamped! A City Passport/Resources/BuildingRegistry.withcoords.json" \
        --email you@example.com

By default this uses OpenStreetMap Nominatim. You must provide a contact email (Nominatim policy).
Optional: set GOOGLE_API_KEY environment variable to use Google Geocoding as an alternative provider.

Behavior:
- Reads input JSON. Supports two common shapes:
  1) Legacy: { "City Name": [ {building}, ... ], ... }
  2) Wrapper: { "cities": { "City Name": [ ... ] }, "meta": {...} }
- For each building object it looks for existing `latitude` and `longitude` keys; if present, it's skipped unless --replace is provided.
- If coordinates missing, it geocodes the building.address and writes `latitude` and `longitude` (floating numbers) into each building.
- A local cache file `scripts/.geocode_cache.json` is used to avoid repeat lookups and respect rate-limits.
- A timestamped backup of the input file will be written before any edits (unless --unsafe used).

Notes:
- Nominatim usage policy requires a valid HTTP User-Agent and contact email. Provide `--email` or set GEOCODE_EMAIL env var.
- For large registries, be patient; the script rate-limits to 1 request/sec by default to be polite.

"""

from __future__ import annotations
import argparse
import json
import os
import sys
import time
import random
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Import requests lazily and handle missing dependency so dry-run can operate without it.
try:
    import requests
except Exception:
    requests = None  # type: ignore

CACHE_PATH = Path(__file__).parent / '.geocode_cache.json'
NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
GOOGLE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'


def timestamp() -> str:
    from datetime import datetime
    return datetime.now().strftime('%Y%m%d-%H%M%S')


def load_json(path: Path) -> Any:
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)


def dump_json(data: Any, path: Path) -> None:
    # atomic write: write to tmp then replace
    tmp = path.with_suffix(path.suffix + '.tmp')
    with tmp.open('w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    try:
        tmp.replace(path)
    except Exception:
        # fallback
        with path.open('w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)


def load_cache() -> Dict[str, Tuple[float, float]]:
    if CACHE_PATH.exists():
        try:
            return json.loads(CACHE_PATH.read_text(encoding='utf-8'))
        except Exception:
            return {}
    return {}


def save_cache(cache: Dict[str, Tuple[float, float]]) -> None:
    try:
        CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=2), encoding='utf-8')
    except Exception as e:
        print(f'Warning: failed to save cache: {e}', file=sys.stderr)


def nominatim_geocode(query: str, email: Optional[str], session) -> Optional[Tuple[float, float]]:
    if requests is None:
        raise RuntimeError('requests library is required for geocoding; install with: pip install requests')
    headers = {'User-Agent': f'StampedCityPassportGeocoder/1.0 (+{email or "no-email-provided"})'}
    params = {
        'q': query,
        'format': 'jsonv2',
        'limit': 1,
    }
    if email:
        params['email'] = email

    r = session.get(NOMINATIM_URL, params=params, headers=headers, timeout=15)
    r.raise_for_status()
    data = r.json()
    if isinstance(data, list) and len(data) > 0:
        first = data[0]
        lat = float(first.get('lat'))
        lon = float(first.get('lon'))
        return lat, lon
    return None


def google_geocode(query: str, api_key: str, session) -> Optional[Tuple[float, float]]:
    if requests is None:
        raise RuntimeError('requests library is required for geocoding; install with: pip install requests')
    params = {'address': query, 'key': api_key}
    r = session.get(GOOGLE_URL, params=params, timeout=15)
    r.raise_for_status()
    data = r.json()
    if data.get('status') == 'OK' and data.get('results'):
        loc = data['results'][0]['geometry']['location']
        return float(loc['lat']), float(loc['lng'])
    # Not OK => return None and let caller decide
    return None


def iter_buildings(data: Any) -> List[Tuple[List[str], Dict[str, Any]]]:
    """Return list of (path_keys, building_dict) where path_keys is list of keys to identify city."""
    out: List[Tuple[List[str], Dict[str, Any]]] = []
    if isinstance(data, dict):
        # wrapper form?
        if 'cities' in data and isinstance(data['cities'], dict):
            for cityName, buildings in data['cities'].items():
                if isinstance(buildings, list):
                    for b in buildings:
                        if isinstance(b, dict):
                            out.append(([cityName], b))
        else:
            # legacy: top-level mapping of city->list
            for cityName, buildings in data.items():
                if isinstance(buildings, list):
                    for b in buildings:
                        if isinstance(b, dict):
                            out.append(([cityName], b))
    return out


def write_back(data: Any, path: Path) -> None:
    # create a timestamped backup
    backup_path = path.with_name(f'{path.name}.{timestamp()}.bak')
    if not backup_path.exists():
        try:
            path.replace(backup_path)
            # write updated content to original path
            dump_json(data, path)
        except Exception:
            # fallback to simple dump
            dump_json(data, path)
    else:
        dump_json(data, path)


def perform_geocode_with_retries(provider: str, query: str, session, nominatim_email: Optional[str], opencage_key: Optional[str], google_key: Optional[str], max_retries: int = 3, base_backoff: float = 1.0) -> Optional[Tuple[float, float]]:
    attempt = 0
    while True:
        try:
            if provider == 'google':
                if not google_key:
                    raise RuntimeError('GOOGLE_API_KEY not set')
                res = google_geocode(query, google_key, session)
            else:
                res = nominatim_geocode(query, nominatim_email, session)

            # If we got a result (coords) return immediately. If None, treat as no-results (do not retry often)
            if res:
                return res
            # If no result, do not retry many times unless transient errors occurred. Treat as final.
            return None
        except requests.HTTPError as e:  # type: ignore
            # For 429 or 5xx, we should retry
            status = getattr(e.response, 'status_code', None)
            # If unauthorized (invalid API key), fail fast — no need to retry
            if status == 401:
                print(f'ERROR: provider {provider} returned 401 Unauthorized for query "{query}". Check your API key and permissions.', file=sys.stderr)
                sys.exit(3)
            attempt += 1
            if attempt > max_retries:
                print(f'ERROR: provider {provider} HTTP error for "{query}": {e}', file=sys.stderr)
                return None
            # If 429, honor Retry-After if present
            retry_after = None
            try:
                retry_after = int(e.response.headers.get('Retry-After')) if e.response and e.response.headers.get('Retry-After') else None
            except Exception:
                retry_after = None
            if retry_after:
                sleep_for = retry_after + random.uniform(0, 1)
            else:
                sleep_for = base_backoff * (2 ** (attempt - 1)) + random.uniform(0, 0.5)
            print(f'WARN: HTTP error from provider {provider} for "{query}": {e} - retrying in {sleep_for:.1f}s (attempt {attempt}/{max_retries})')
            time.sleep(sleep_for)
        except (requests.RequestException, RuntimeError) as e:  # type: ignore
            attempt += 1
            if attempt > max_retries:
                print(f'ERROR: provider {provider} network/error for "{query}": {e}', file=sys.stderr)
                return None
            sleep_for = base_backoff * (2 ** (attempt - 1)) + random.uniform(0, 0.5)
            print(f'WARN: network/error from provider {provider} for "{query}": {e} - retrying in {sleep_for:.1f}s (attempt {attempt}/{max_retries})')
            time.sleep(sleep_for)


def main():
    parser = argparse.ArgumentParser(description='Batch geocode building registry JSON and inject latitude/longitude')
    parser.add_argument('--input', '-i', required=True, help='Input registry JSON path')
    parser.add_argument('--output', '-o', help='Optional output path (if omitted, input is overwritten with backup)')
    parser.add_argument('--failures-output', help='Optional path to write JSON report of failed lookups (default: scripts/geocode_failures.json)')
    parser.add_argument('--email', '-e', help='Contact email for Nominatim (or set GEOCODE_EMAIL)')
    parser.add_argument('--delay', '-d', type=float, default=1.0, help='Seconds to wait between requests (politeness)')
    parser.add_argument('--dry-run', action='store_true', help="Don't write output, just report what would be changed")
    parser.add_argument('--provider', choices=['nominatim', 'google'], default='nominatim', help='Geocoding provider to use')
    parser.add_argument('--replace', action='store_true', help='Replace existing coordinates if present')
    parser.add_argument('--max-retries', type=int, default=3, help='Max retries for transient errors')
    parser.add_argument('--limit', type=int, default=0, help='Max number of buildings to geocode (0 = no limit)')
    parser.add_argument('--unsafe', action='store_true', help='Skip creating a timestamped backup when writing output')
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print('Input file not found:', input_path, file=sys.stderr)
        sys.exit(2)

    output_path = Path(args.output) if args.output else input_path

    email = args.email or os.environ.get('GEOCODE_EMAIL') or os.environ.get('NOMINATIM_EMAIL')
    google_key = os.environ.get('GOOGLE_API_KEY')

    # If requests is not available and we're not in dry-run, fail with instructions
    if requests is None and not args.dry_run:
        print('ERROR: the Python "requests" package is required for geocoding. Install with: pip install requests', file=sys.stderr)
        sys.exit(3)

    session = requests.Session() if requests is not None else None

    data = load_json(input_path)
    buildings = iter_buildings(data)
    print(f'Found {len(buildings)} building entries to examine')

    cache = load_cache()
    changed = 0
    looked_up = 0
    failures: List[Dict[str, str]] = []

    # If dry-run, only list buildings that would be geocoded and exit without network calls
    if args.dry_run:
        to_geocode = []
        for cityKeys, b in buildings:
            if 'latitude' in b and 'longitude' in b and b.get('latitude') is not None and b.get('longitude') is not None and not args.replace:
                continue
            address = b.get('address') or b.get('location') or ''
            if not address:
                continue
            to_geocode.append({'id': b.get('id'), 'city': cityKeys[0] if cityKeys else '', 'address': address})
            if args.limit and len(to_geocode) >= args.limit:
                break
        print('Dry-run: buildings that would be geocoded (count={}):'.format(len(to_geocode)))
        for item in to_geocode:
            print(f" - {item['city']} / {item['id']} -> {item['address']}")
        sys.exit(0)

    processed = 0
    for cityKeys, b in buildings:
        # building object
        if 'latitude' in b and 'longitude' in b and b.get('latitude') is not None and b.get('longitude') is not None and not args.replace:
            continue
        address = b.get('address') or b.get('location') or ''
        if not address:
            print(f"Skipping building id={b.get('id')} because no address present")
            continue

        key = address.strip()
        if key in cache:
            lat, lon = cache[key]
            b['latitude'] = lat
            b['longitude'] = lon
            continue

        # perform geocode with retries
        looked_up += 1
        coords = perform_geocode_with_retries(args.provider, key, session, email, None, google_key, max_retries=args.max_retries)

        if coords:
            lat, lon = coords
            b['latitude'] = lat
            b['longitude'] = lon
            cache[key] = (lat, lon)
            changed += 1
            print(f'Geocoded: "{key}" -> {lat:.6f},{lon:.6f}')
            processed += 1
            if args.limit and processed >= args.limit:
                print(f'INFO: reached processing limit of {args.limit}; stopping early')
                # break out of both loops by setting a flag
                break
        else:
            print(f'Failed to geocode: "{key}" (id={b.get("id")})')
            failures.append({'id': b.get('id', ''), 'address': key, 'city': cityKeys[0] if cityKeys else ''})

        save_cache(cache)
        time.sleep(args.delay)
        # if limit reached, break outer loop too
        if args.limit and processed >= args.limit:
            break

    print(f'Finished: looked up {looked_up}, changed {changed}.')

    # write failures report if any
    failures_output = Path(args.failures_output) if args.failures_output else Path(__file__).parent / 'geocode_failures.json'
    if failures:
        try:
            dump_json(failures, failures_output)
            print(f'Wrote failures report to: {failures_output}')
        except Exception as e:
            print(f'Warning: failed to write failures report: {e}', file=sys.stderr)
    else:
        # remove old failures file if exists
        try:
            if failures_output.exists():
                failures_output.unlink()
        except Exception:
            pass

    # Write output: if output path equals input, back up original first (timestamped)
    if output_path == input_path:
        backup_path = input_path.with_name(f'{input_path.name}.{timestamp()}.bak')
        if not backup_path.exists():
            input_path.replace(backup_path)
            print(f'Backup created: {backup_path}')
        else:
            print(f'Backup already exists: {backup_path}')

    dump_json(data, output_path)
    print(f'Wrote output to: {output_path}')


if __name__ == '__main__':
    main()
