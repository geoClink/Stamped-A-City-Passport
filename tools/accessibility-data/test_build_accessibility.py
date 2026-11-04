"""Tests for the OSM matching rules. No network: the OSM features are made up."""

from build_accessibility import Landmark, find_match, normalize_name

ROMAN_BATHS = Landmark("uk_roman_baths", "The Roman Baths", "Bath", 51.3811, -2.3597)


def osm_feature(name: str, wheelchair: str, latitude: float, longitude: float, **extra_tags: str) -> dict:
    """An Overpass node in the shape the API returns."""
    tags = {"name": name, "wheelchair": wheelchair, "tourism": "museum", **extra_tags}
    return {"type": "node", "id": 42, "lat": latitude, "lon": longitude, "tags": tags}


def test_normalize_drops_the_accents_and_punctuation() -> None:
    # "The" at the start, accents and punctuation don't stop a match
    assert normalize_name("The Café-Bar (Old)") == "cafe bar"


def test_same_name_nearby_matches() -> None:
    match = find_match(ROMAN_BATHS, [osm_feature("Roman Baths", "limited", 51.3812, -2.3597)])
    assert match is not None
    assert match.wheelchair == "limited"


def test_far_away_feature_does_not_match() -> None:
    # About 1 km away: a different place with the same name
    assert find_match(ROMAN_BATHS, [osm_feature("Roman Baths", "yes", 51.39, -2.3597)]) is None


def test_different_name_does_not_match() -> None:
    # A shop next door is not the landmark
    assert find_match(ROMAN_BATHS, [osm_feature("Roman Bath Shop", "yes", 51.3811, -2.3597)]) is None


def test_bus_stop_does_not_match() -> None:
    bus_stop = osm_feature("Roman Baths", "yes", 51.3811, -2.3597, highway="bus_stop")
    assert find_match(ROMAN_BATHS, [bus_stop]) is None


def test_unknown_wheelchair_value_is_skipped() -> None:
    assert find_match(ROMAN_BATHS, [osm_feature("Roman Baths", "designated", 51.3811, -2.3597)]) is None


def test_two_equal_matches_that_disagree_are_skipped() -> None:
    # We can't tell which is right, so we don't guess
    features = [
        osm_feature("Roman Baths", "yes", 51.3811, -2.3597),
        osm_feature("Roman Baths", "no", 51.3812, -2.3597),
    ]
    assert find_match(ROMAN_BATHS, features) is None


def test_one_word_in_brackets_does_not_match() -> None:
    # "(MIT)" is the university, not the building
    stata = Landmark("mit_stata", "Ray and Maria Stata Center (MIT)", "Boston", 42.3616, -71.0906)
    university = osm_feature("MIT", "limited", 42.3616, -71.0906, amenity="university")
    assert find_match(stata, [university]) is None


def test_city_name_left_out_still_matches() -> None:
    guildhall = Landmark("uk_bath_guildhall", "Bath Guildhall", "Bath", 51.3825, -2.3590)
    match = find_match(guildhall, [osm_feature("Guildhall", "yes", 51.3825, -2.3590)])
    assert match is not None
