import json, sys, pathlib
p = pathlib.Path("Stamped! A City Passport/Resources/BuildingRegistry.json")
try:
    with p.open('r', encoding='utf-8') as f:
        j = json.load(f)
    print("Bundle JSON path:", p)
    print("Bundle JSON city count:", len(j.keys()))
    print("Sample cities:", list(j.keys())[:10])
except Exception as e:
    print("Error reading bundle JSON:", e)
    sys.exit(1)
