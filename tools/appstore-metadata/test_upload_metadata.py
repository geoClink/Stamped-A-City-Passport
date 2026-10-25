"""
Tests for upload_metadata.py. None of these contact Apple.

Run with:  ./venv/bin/pytest
"""

from __future__ import annotations

import upload_metadata


def make_locale_text(**overrides: str) -> dict:
    """A valid set of texts for one language; pass a field to override it."""
    texts = {
        "locale": "en-US",
        "subtitle": "Campus visits & architecture",
        "promotional_text": "Promo",
        "description": "Description",
        "keywords": "college,campus",
        "whats_new": "New stuff",
    }
    texts.update(overrides)
    return texts


def test_real_files_for_2_5_pass_the_checks() -> None:
    # Checks the real JSON files in the repo: all 10 languages load and fit Apple's limits
    locale_texts = upload_metadata.load_locale_files("2.5")
    assert len(locale_texts) == 10
    assert "en-US" in locale_texts
    assert upload_metadata.find_problems(locale_texts) == []


def test_text_over_the_limit_is_reported() -> None:
    # Promotional text is limited to 170 characters, so 171 must be flagged
    too_long = make_locale_text(promotional_text="x" * 171)
    problems = upload_metadata.find_problems({"en-US": too_long})
    assert problems == ["en-US: promotional_text is 171 characters (limit 170)"]


def test_missing_field_is_reported() -> None:
    # An empty What's New would wipe the box in App Store Connect, so it's an error
    missing = make_locale_text(whats_new="")
    problems = upload_metadata.find_problems({"en-US": missing})
    assert problems == ["en-US: whats_new is missing"]


def test_only_changed_text_is_sent() -> None:
    # If App Store Connect already has the same text, there's nothing to send for it
    current = {"whatsNew": "Same", "promotionalText": "Old promo", "keywords": None}
    wanted = {"whatsNew": "Same", "promotionalText": "New promo", "keywords": "campus"}
    assert upload_metadata.changed_attributes(current, wanted) == {
        "promotionalText": "New promo",
        "keywords": "campus",
    }


def test_new_language_copies_english_name_and_privacy_url() -> None:
    # A new language under App Information reuses the English app name and privacy URL,
    # but gets its own translated subtitle
    english = {"name": "Stamped! A City Passport", "privacyPolicyUrl": "https://example.com/privacy", "subtitle": "English"}
    attributes = upload_metadata.new_app_info_attributes(english, "Campus und Architektur")
    assert attributes == {
        "name": "Stamped! A City Passport",
        "privacyPolicyUrl": "https://example.com/privacy",
        "subtitle": "Campus und Architektur",
    }


def test_marketing_url_is_added_only_when_given() -> None:
    texts = make_locale_text()
    without_url = upload_metadata.wanted_version_attributes(texts, None)
    with_url = upload_metadata.wanted_version_attributes(texts, "https://example.com")
    assert "marketingUrl" not in without_url
    assert with_url["marketingUrl"] == "https://example.com"
