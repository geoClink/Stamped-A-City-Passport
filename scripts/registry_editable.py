# Editable registry for quick edits in VS Code.
# This file is intended to be edited directly. After editing, run:
#   ./scripts/convert_registry.py import
# to write changes back to the app JSON (Resources/BuildingRegistry.json).

# Minimal example structure. Run `./scripts/convert_registry.py export` to
# replace this with the real data from Resources/BuildingRegistry.json.
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
