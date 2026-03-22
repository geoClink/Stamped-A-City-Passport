# Building Registry Editing Workflow

This project stores the canonical building data used by the app in:

  Stamped! A City Passport/Resources/BuildingRegistry.json

To make editing easier in an editor like VS Code, this repository provides a small
workflow to convert between that JSON and an editable Python file.

Files
- `scripts/convert_registry.py` - CLI to export/import the JSON <-> editable Python file.
- `scripts/registry_editable.py` - The human-editable Python file (contains `REGISTRY` dict).

Why this workflow?
- JSON is the canonical runtime format used by the app and is included in the app bundle.
- Editing a massive JSON in-place is awkward. `registry_editable.py` gives you a nicer
  editing experience (syntax highlighting, quick find/replace, and optional Python-based
  transformations).

Basic usage

- Export the current JSON to the editable file:

  ```bash
  ./scripts/convert_registry.py export
  ```

- Edit `scripts/registry_editable.py` in your editor (take care to preserve the data
  shapes: top-level dict of city -> list of building dicts).

- Import your edits back to the app JSON (overwrites the bundle source file):

  ```bash
  ./scripts/convert_registry.py import
  ```

Validation and safety
- The script does basic validation to ensure the top-level object is a dict and each
  city's value is a list of dicts. It will refuse invalid formats.
- After importing, run the app or a unit test to ensure the `Building` model decodes
  correctly.

Recommended workflow
- Use `export` to get the latest data into `registry_editable.py` before making edits.
- Make small, incremental edits and run `import` frequently to avoid large merges.
- Commit `Resources/BuildingRegistry.json` as the canonical change so CI/tests can verify
  decoding in your build pipeline.

More advanced
- You can extend `scripts/convert_registry.py` to add extra validation rules (e.g.,
  checking required fields, value ranges, or deduplicating ids).
- Consider adding a unit test that decodes `Resources/BuildingRegistry.json` and checks
  for a few expected ids/counts to catch schema regressions in CI.
