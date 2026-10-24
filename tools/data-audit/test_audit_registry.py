"""Small pytest checks for the audit helpers. Run with: pytest"""

from audit_registry import (
    check_duplicates,
    distance_km,
    has_usable_coordinates,
    looks_like_placeholder,
    normalised_name,
)


def test_distance_between_two_known_points() -> None:
    # London to Paris is about 344 km in a straight line.
    assert 340 < distance_km(51.5074, -0.1278, 48.8566, 2.3522) < 348


def test_zero_or_missing_coordinates_are_not_usable() -> None:
    # 0 means "nobody filled this in", and None means the key is missing.
    assert not has_usable_coordinates({"latitude": 0, "longitude": 12.5})
    assert not has_usable_coordinates({"latitude": None, "longitude": None})
    assert has_usable_coordinates({"latitude": 51.5, "longitude": -0.12})


def test_rounded_numbers_look_like_placeholders() -> None:
    # 27.0, 30.0 is the middle of Egypt, not a building in Cairo.
    assert looks_like_placeholder(27.0, 30.0, None)
    # 1°05′N 104°03′E is Batam the city, not one building in it.
    assert looks_like_placeholder(1.08333, 104.05, None)
    assert not looks_like_placeholder(30.045833, 31.224444, None)


def test_duplicate_ids_are_found_across_cities() -> None:
    # Stamps are keyed by id, so the same id in two cities must be flagged.
    registry = {"Paris": [{"id": "abc", "name": "A"}], "Rome": [{"id": "abc", "name": "B"}]}
    findings = check_duplicates(registry)
    assert [finding.check for finding in findings] == ["duplicate_id"]


def test_names_differing_only_by_the_or_punctuation_match() -> None:
    assert normalised_name("The Roman Baths") == normalised_name("Roman Baths!")
