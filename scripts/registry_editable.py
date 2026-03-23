# Editable registry for quick edits in VS Code.
# This file intentionally loads the canonical JSON if present so you can
# open/edit REGISTRY in VS Code without dealing with the very large JSON
# file directly. After editing, run the project's converter to write the
# canonical JSON back into the app resources if desired:
#   ./scripts/convert_registry.py import

import json
from pathlib import Path

# Path to the canonical JSON (relative to repo root).
DEFAULT_JSON_PATH = Path(__file__).resolve().parents[1] / "Stamped! A City Passport" / "Resources" / "BuildingRegistry.json"

# Try to load the full JSON if it exists. This makes the editable file
# a friendly view of the full registry inside VS Code.
try:
    if DEFAULT_JSON_PATH.exists():
        with open(DEFAULT_JSON_PATH, "r", encoding="utf-8") as f:
            REGISTRY = json.load(f)
    else:
        raise FileNotFoundError
except Exception:
    # Fallback minimal example (useful if you want to start editing without
    # a large JSON present). Replace or extend this dict as needed.
    REGISTRY = {
        "Bath": [
            {
                "id": "uk_roman_baths",
                "name": "The Roman Baths",
                "assetName": "romanBaths",
                "description": "Constructed around 70 AD...",
                "architect": "Ancient Romans",
                "yearBuilt": 70,
                "address": "Abbey Churchyard, Bath BA1 1LZ",
                "oldUse": "Public Bathing House",
                "newUse": "Museum / Historical Site",
                "buildingStyle": "Roman / Neoclassical",
                "numberOfStories": 2,
                "height": 12,
                "foodSpots": ["The Pump Room"],
                "currency": "GBP (£)"
            }
        ]
    }

# Helpful comment: edit REGISTRY here in VS Code. After editing, run the
# convert script to write the canonical JSON the app uses:
#   ./scripts/convert_registry.py import
