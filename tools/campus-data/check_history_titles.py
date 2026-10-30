"""Spot-check the History card's Wikipedia article for every campus.

For each campus (name from the campus JSON, or its override in
Stamped! A City Passport/Models/CampusHistoryTitles.swift) this asks Wikipedia which
article the title leads to and Wikidata what that article is about, and flags any
title that is missing, a "may refer to" page, a redirect to something else, or not a
university (a city, a sports team...). It also prints the founding year (P571) the
card will show, or "none" when Wikidata's values disagree.

Run from the repository root:  python3 tools/campus-data/check_history_titles.py
Uses only the standard library; makes about 6 requests in all.
"""
import glob
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
USER_AGENT = "Stamped-A-City-Passport/2.3 (https://georgeclinkscalesdev.com; campus history title check)"
# Words in Wikipedia's short description that show the article is about a school
SCHOOL_WORDS = ("university", "college", "institute", "school")
# Words that show it is about something else
WRONG_WORDS = ("team", "athletic", "football", "basketball", "city in", "town in", "county")


def get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def load_campuses() -> list[dict]:
    campuses = []
    for path in sorted(glob.glob(str(ROOT / "tools/campus-data/campuses/*.json"))):
        data = json.loads(Path(path).read_text())
        campuses.extend(data if isinstance(data, list) else data.get("campuses", []))
    return campuses


def load_overrides() -> dict[str, str]:
    # Lines like:  .georgiaTech: "Georgia Tech",
    swift = (ROOT / "Stamped! A City Passport/Models/CampusHistoryTitles.swift").read_text()
    return dict(re.findall(r'^\s*\.(\w+): "([^"]+)",', swift, re.M))


def founded_year(statements: list[dict]) -> int | None:
    """Same rule as CampusHistoryService.foundedYear: a preferred value, else one agreed year."""
    def year(statement: dict) -> int | None:
        value = statement["mainsnak"].get("datavalue", {}).get("value", {})
        if value.get("precision", 0) < 9:
            return None
        return int(value["time"].lstrip("+").split("-")[0])

    usable = [s for s in statements if s.get("rank") != "deprecated"]
    preferred = [y for s in usable if s.get("rank") == "preferred" and (y := year(s))]
    if len(preferred) == 1:
        return preferred[0]
    years = {y for s in usable if (y := year(s))}
    return years.pop() if len(years) == 1 else None


def main() -> None:
    overrides = load_overrides()
    campuses = load_campuses()
    titles = [overrides.get(c["enumCase"], c["name"]) for c in campuses]

    # Which page each title lands on (after redirects), its Wikidata item and short description
    pages: dict[str, dict] = {}
    for start in range(0, len(titles), 50):
        batch = titles[start:start + 50]
        query = urllib.parse.urlencode({
            "action": "query", "format": "json", "redirects": 1,
            "prop": "pageprops|description", "ppprop": "wikibase_item|disambiguation",
            "titles": "|".join(batch),
        })
        result = get_json(f"https://en.wikipedia.org/w/api.php?{query}")["query"]
        normalized = {n["from"]: n["to"] for n in result.get("normalized", [])}
        redirects = {r["from"]: r["to"] for r in result.get("redirects", [])}
        by_title = {p["title"]: p for p in result["pages"].values()}
        for title in batch:
            landed = redirects.get(normalized.get(title, title), normalized.get(title, title))
            page = by_title.get(landed, {})
            pages[title] = {
                "landed": landed,
                "missing": "missing" in page,
                "disambiguation": "disambiguation" in page.get("pageprops", {}),
                "item": page.get("pageprops", {}).get("wikibase_item"),
                "description": (page.get("description") or "").lower(),
            }

    # Founding year for every item, 50 at a time
    items = [p["item"] for p in pages.values() if p["item"]]
    inception: dict[str, int | None] = {}
    for start in range(0, len(items), 50):
        query = urllib.parse.urlencode({
            "action": "wbgetentities", "format": "json", "props": "claims",
            "ids": "|".join(items[start:start + 50]),
        })
        for item, entity in get_json(f"https://www.wikidata.org/w/api.php?{query}")["entities"].items():
            inception[item] = founded_year(entity.get("claims", {}).get("P571", []))

    problems = 0
    for campus, title in zip(campuses, titles):
        page = pages[title]
        issues = []
        if page["missing"]:
            issues.append("no such article")
        if page["disambiguation"]:
            issues.append("'may refer to' page")
        if page["landed"] != title:
            issues.append(f"redirects to {page['landed']!r}")
        description = page["description"]
        if not any(word in description for word in SCHOOL_WORDS) or any(word in description for word in WRONG_WORDS):
            issues.append(f"not clearly a university: {description!r}")
        year = inception.get(page["item"])
        status = "CHECK: " + "; ".join(issues) if issues else "ok"
        problems += bool(issues)
        print(f"{campus['enumCase']:20} {title:48} founded {year or 'none':<5} {status}")
    print(f"\n{len(campuses)} campuses, {problems} to check")


if __name__ == "__main__":
    main()
