#!/usr/bin/env python3
"""Records the owner's approval of Beloved's bundled content.

Approval is a reviewer's act: this script only writes down that the named person has approved,
it does not judge the content. It sets review.status = approved (with reviewer and date) on every
prayer item, scripture edition and daily-verse list, and replaces the "(draft)" editorial label
that keeps an item out of release builds.

    python3 scripts/approve_content.py --reviewer "Vaibhav S G (owner)" [--date 2026-10-20]

Re-run it after `scripts/import_devotions.py`, which writes new items as drafts.
"""
import argparse
import datetime
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, "Packages", "PrayerLockKit", "Sources")
FILES = {
    "items": [os.path.join(KIT, "PLContent", "Resources", name) for name in ("content-fixtures.json", "devotions.json")],
    "scripture": os.path.join(KIT, "PLScripture", "Resources", "scripture-library.json"),
    "daily": os.path.join(KIT, "PLScripture", "Resources", "daily-verses.json"),
}


def approve(review, reviewer, day, note):
    notes = review.get("notes") or ""
    review["status"] = "approved"
    review["reviewer"] = reviewer
    review["reviewedOn"] = day
    review["notes"] = (notes + " " if notes else "") + note


def rewrite(path, data, like):
    """Keeps the file's existing indentation (some are hand-formatted, so none are reformatted blindly)."""
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=like)
        handle.write("\n")


def indent_of(path):
    with open(path, encoding="utf-8") as handle:
        head = handle.read(200)
    for line in head.splitlines()[1:3]:
        stripped = len(line) - len(line.lstrip(" "))
        if stripped:
            return stripped
    return 2


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reviewer", required=True)
    parser.add_argument("--date", default=datetime.date.today().isoformat())
    args = parser.parse_args()
    year, month, dayn = (int(part) for part in args.date.split("-"))
    day = {"year": year, "month": month, "day": dayn}
    note = f"Approved by {args.reviewer} on {args.date}."

    counts = {"items": 0, "editions": 0, "daily": 0}
    for path in FILES["items"]:
        items = json.load(open(path, encoding="utf-8"))
        for item in items:
            approve(item.setdefault("review", {}), args.reviewer, day, note)
            for segment in item.get("segments", []):
                author = segment.get("author")
                if author and "(draft)" in author:
                    segment["author"] = author.replace(" (draft)", "")
            counts["items"] += 1
        rewrite(path, items, indent_of(path))

    path = FILES["scripture"]
    library = json.load(open(path, encoding="utf-8"))
    for edition in library["editions"]:
        approve(edition.setdefault("review", {}), args.reviewer, day, note)
        counts["editions"] += 1
    rewrite(path, library, indent_of(path))

    path = FILES["daily"]
    daily = json.load(open(path, encoding="utf-8"))
    for faith in daily["faiths"].values():
        approve(faith.setdefault("review", {}), args.reviewer, day, note)
        counts["daily"] += 1
    rewrite(path, daily, indent_of(path))
    print(f"approved {counts['items']} items, {counts['editions']} editions, {counts['daily']} daily-verse lists as {args.reviewer}")


if __name__ == "__main__":
    main()
