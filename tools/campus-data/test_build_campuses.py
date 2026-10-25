"""Simple tests for build_campuses.py. Run with: python -m pytest"""

import json
from pathlib import Path

import build_campuses


def test_distance_between_two_known_points() -> None:
    # Sterling Memorial Library to Harkness Tower at Yale is roughly 250 m
    km = build_campuses.distance_km(41.3113, -72.9291, 41.3101, -72.9302)
    assert 0.1 < km < 0.3


def test_appending_campuses_leaves_cities_untouched(tmp_path: Path) -> None:
    # A tiny registry in the same format as the real one (2-space indent, no trailing newline)
    registry = tmp_path / "registry.json"
    cities = {"Bath": [{"id": "uk_roman_baths"}], "Zanzibar": [{"id": "znz-01"}]}
    original_text = json.dumps(cities, indent=2, ensure_ascii=False)
    registry.write_text(original_text)

    campuses = {"Yale University": [{"id": "campus_yale_sterling_library"}]}
    build_campuses.append_campus_entries(registry, campuses, set(campuses))
    result = json.loads(registry.read_text())

    # The cities keep their exact text, and the campus comes after them
    assert registry.read_text().startswith(original_text[:-2])
    assert list(result) == ["Bath", "Zanzibar", "Yale University"]


def test_appending_twice_replaces_the_old_campus_block(tmp_path: Path) -> None:
    # Re-running the script must not add a second copy of each campus
    registry = tmp_path / "registry.json"
    registry.write_text(json.dumps({"Bath": []}, indent=2))
    names = {"Yale University"}
    build_campuses.append_campus_entries(registry, {"Yale University": [{"id": "a"}]}, names)
    build_campuses.append_campus_entries(registry, {"Yale University": [{"id": "b"}]}, names)

    assert json.loads(registry.read_text()) == {"Bath": [], "Yale University": [{"id": "b"}]}


def test_strip_generated_removes_the_campus_block() -> None:
    source = (
        '        case dhaka = "Dhaka"\n'
        "        // BEGIN CAMPUSES (generated)\n"
        '        case yale = "Yale University"\n'
        "        // END CAMPUSES\n"
        "        var id: String\n"
    )
    assert build_campuses.strip_generated(source) == '        case dhaka = "Dhaka"\n        var id: String\n'


def test_two_blocks_in_one_file_both_survive(tmp_path: Path) -> None:
    # Model.swift has two campus blocks (enum cases and countries); writing one must keep the other
    swift_file = tmp_path / "Model.swift"
    swift_file.write_text('case dhaka = "Dhaka"\n// gap\ncase .dhaka: return .bangladesh\n')
    build_campuses.replace_generated_block(swift_file, 'case dhaka = "Dhaka"\n', "", ['case yale = "Yale"'])
    build_campuses.replace_generated_block(swift_file, "case .dhaka: return .bangladesh\n", "", ["case .yale: return .unitedStates"])
    build_campuses.replace_generated_block(swift_file, 'case dhaka = "Dhaka"\n', "", ['case mit = "MIT"'])

    text = swift_file.read_text()
    assert 'case mit = "MIT"' in text and 'case yale = "Yale"' not in text
    assert "case .yale: return .unitedStates" in text
    assert text.count("BEGIN CAMPUSES") == 2


def test_shared_article_buildings_use_their_own_coordinates() -> None:
    # Two buildings described by one district article: the article's single point must not be used
    def building(building_id: str, point: list[float]) -> dict:
        return {
            "id": building_id, "wiki": "Child of the Sun", "sharedArticle": True, "name": building_id,
            "description": "d", "architect": "a", "address": "x", "oldUse": "o", "newUse": "n",
            "buildingStyle": "s", "yearBuilt": 1941, "coordinates": point, "coordinatesSource": "osm",
        }
    campus = {
        "name": "Test College", "enumCase": "testCollege", "country": "unitedStates", "wiki": "Test College",
        "currency": "USD ($)", "_file": "test.json",
        "details": {field: "x" for field in build_campuses.DETAIL_FIELDS},
        "buildings": [building(f"campus_test_{n}", [28.03 + n / 1000, -81.95]) for n in range(4)],
    }
    cache = {"Child of the Sun": [28.0, -81.9]}
    errors, _ = build_campuses.check_campuses([campus], cache)

    assert errors == []
    assert campus["buildings"][1]["_lat"] == 28.031  # its own OSM point, not the article's


def test_conference_must_be_known_and_us_only() -> None:
    # A typo in "conference" or a conference on a non-US campus would put it in the wrong list group
    def campus(enum_case: str, country: str, conference: str) -> dict:
        return {
            "name": enum_case, "enumCase": enum_case, "country": country, "conference": conference,
            "wiki": "Test College", "currency": "USD ($)", "_file": "test.json",
            "details": {field: "x" for field in build_campuses.DETAIL_FIELDS},
            "buildings": [{
                "id": f"campus_{enum_case.lower()}_b{n}", "wiki": f"B{n}", "name": f"B{n}", "description": "d",
                "architect": "a", "address": "x", "oldUse": "o", "newUse": "n", "buildingStyle": "s",
                "yearBuilt": 1900, "coordinates": [28.03 + n / 1000, -81.95], "coordinatesSource": "osm",
                "sharedArticle": True,
            } for n in range(4)],
        }
    campuses = [
        campus("testBigTen", "unitedStates", "bigTen"),
        campus("testTypo", "unitedStates", "bigTenn"),
        campus("testAbroad", "canada", "acc"),
    ]
    errors, _ = build_campuses.check_campuses(campuses, {"Test College": [28.03, -81.95]})

    assert not any("testBigTen" in error for error in errors)
    assert any("testTypo" in error and "bigTenn" in error for error in errors)
    assert any("testAbroad" in error and "only US campuses" in error for error in errors)


def test_colors_and_traditions_are_checked() -> None:
    # Bad hex colors or a tradition far from campus would show up wrong in the app
    def campus(enum_case: str, colors: list, tradition_point: list[float]) -> dict:
        return {
            "name": enum_case, "enumCase": enum_case, "country": "unitedStates", "colors": colors,
            "wiki": "Test College", "currency": "USD ($)", "_file": "test.json",
            "details": {field: "x" for field in build_campuses.DETAIL_FIELDS},
            "buildings": [{
                "id": f"campus_{enum_case.lower()}_b{n}", "wiki": f"B{n}", "name": f"B{n}", "description": "d",
                "architect": "a", "address": "x", "oldUse": "o", "newUse": "n", "buildingStyle": "s",
                "yearBuilt": 1900, "coordinates": [28.03 + n / 1000, -81.95], "coordinatesSource": "osm",
                "sharedArticle": True,
            } for n in range(4)],
            "traditions": [{
                "id": f"trad_{enum_case.lower()}_bell", "name": "Ring the bell", "description": "d",
                "coordinates": tradition_point, "coordinatesSource": "osm", "source": "https://example.edu",
            }],
        }
    campuses = [
        campus("good", ["#18453B", "#FFFFFF"], [28.031, -81.95]),
        campus("badcolor", ["green"], [28.031, -81.95]),
        campus("faraway", ["#000000"], [29.0, -81.95]),
    ]
    errors, _ = build_campuses.check_campuses(campuses, {"Test College": [28.03, -81.95]})

    assert not any(error.startswith("good") for error in errors)
    assert any(error.startswith("badcolor") and "colors" in error for error in errors)
    assert any(error.startswith("faraway") and "km from the campus centre" in error for error in errors)
