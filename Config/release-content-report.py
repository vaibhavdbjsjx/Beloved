#!/usr/bin/env python3
"""Counts the content a *release* build will actually show, per faith.

Mirrors PLContent.ContentPolicy.release: an item is shown only if its review status is
"approved" and every `sourceText` segment cites an edition whose licence is not
`pendingClearance`. Used by Config/validate-release.sh (archives fail if any faith the app
offers would show no content) and runnable by hand:

    python3 Config/release-content-report.py           # per-faith counts
    python3 Config/release-content-report.py --items   # why each item is blocked
    python3 Config/release-content-report.py --markdown > docs/26-content-approval-register.md
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.path.join(ROOT, "Packages", "PrayerLockKit", "Sources")
CONTENT = os.path.join(KIT, "PLContent", "Resources", "content-fixtures.json")
DEVOTIONS = os.path.join(KIT, "PLContent", "Resources", "devotions.json")
FAITHS = os.path.join(KIT, "PLFaith", "Resources", "faiths.json")
SCRIPTURE = os.path.join(KIT, "PLScripture", "Resources", "scripture-library.json")
DAILY = os.path.join(KIT, "PLScripture", "Resources", "daily-verses.json")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def load_items():
    """Every catalog item: editorial fixtures plus the imported devotional library."""
    items = load(CONTENT)
    if os.path.exists(DEVOTIONS):
        items += load(DEVOTIONS)
    return items


def cleared_editions(faiths):
    cleared = set()
    for faith in faiths:
        for source in faith.get("sources", []):
            for edition in source.get("editions", []):
                if "pendingClearance" not in edition.get("license", {}):
                    cleared.add(edition["id"])
    return cleared


def is_release_visible(item, cleared):
    if item.get("review", {}).get("status") != "approved":
        return False
    for segment in item.get("segments", []):
        if "draft" in (segment.get("author") or "").lower():
            return False  # never ship a visible "(draft)" label
        if segment.get("role") != "sourceText":
            continue
        edition = (segment.get("citation") or {}).get("edition")
        if edition not in cleared:
            return False
    return True


def editions_by_id(faiths):
    return {
        edition["id"]: edition
        for faith in faiths
        for source in faith.get("sources", [])
        for edition in source.get("editions", [])
    }


def blocking_reasons(item, cleared, editions):
    """Why ContentPolicy.release hides this item (empty = visible)."""
    reasons = []
    status = item.get("review", {}).get("status", "missing")
    if status != "approved":
        reasons.append(f"review status is '{status}' — needs faith-reviewer approval")
    for segment in item.get("segments", []):
        if status == "approved" and "draft" in (segment.get("author") or "").lower():
            # Stricter than ContentPolicy: an approved item must not show "(draft)" to users.
            reasons.append("approved, but the author label still says 'draft'")
        if segment.get("role") != "sourceText":
            continue
        citation = segment.get("citation") or {}
        edition = citation.get("edition")
        reference = citation.get("reference", "?")
        if not edition:
            reasons.append(f"scripture {reference} cites no edition")
        elif edition not in editions:
            reasons.append(f"scripture {reference} cites unknown edition '{edition}'")
        elif edition not in cleared:
            reasons.append(f"scripture {reference}: edition '{edition}' rights pending")
    return reasons


def advisories(item):
    """Not blocking under the policy, but a reviewer must check before approving."""
    notes = []
    for segment in item.get("segments", []):
        citation = segment.get("citation") or {}
        if segment.get("role") != "sourceText" and citation.get("reference") and not citation.get("edition"):
            notes.append(f"{segment.get('role')} references {citation['reference']} with no edition — verify against a scholarly edition")
        if segment.get("role") == "composedPrayer" and "draft" in (segment.get("author") or "").lower():
            notes.append("author label still says 'draft' — set the real author/editor")
    return notes


def item_report():
    faiths = load(FAITHS)
    items = load_items()
    cleared = cleared_editions(faiths)
    editions = editions_by_id(faiths)
    for item in items:
        reasons = blocking_reasons(item, cleared, editions)
        state = "VISIBLE" if not reasons else "BLOCKED"
        print(f"{state:8} {item['id']} ({item.get('faith') or 'faith-neutral'}, {item.get('kind')})")
        for reason in reasons:
            print(f"         - {reason}")
        for note in advisories(item):
            print(f"         * {note}")


def licence_label(edition):
    licence = edition.get("license", {})
    kind = next(iter(licence), "unknown")
    return {"publicDomain": "public domain", "pendingClearance": "PENDING clearance"}.get(kind, kind)


def markdown_register():
    """The approval register, generated from the catalog so it cannot drift from it."""
    faiths = load(FAITHS)
    items = load_items()
    cleared = cleared_editions(faiths)
    editions = editions_by_id(faiths)
    rows = []
    for number, item in enumerate(items, 1):
        sources, rights = [], []
        for segment in item.get("segments", []):
            citation = segment.get("citation") or {}
            if citation:
                edition = citation.get("edition")
                ref = citation.get("reference", "")
                sources.append(f"{ref} [{edition or 'no edition'}]")
                rights.append(licence_label(editions[edition]) if edition in editions else "no edition cited")
            elif segment.get("author"):
                sources.append(segment["author"])
                rights.append("original composition")
            elif segment.get("role") == "traditionalText":
                sources.append("traditional recitation, no citation")
                rights.append("unverified")
        reasons = blocking_reasons(item, cleared, editions) + [f"(advisory) {n}" for n in advisories(item)]
        rows.append("| {n} | `{id}` | {kind} | {faith} | {src} | {rights} | {review} | {release} | {missing} |".format(
            n=number, id=item["id"], kind=item.get("kind"),
            faith=item.get("faith") or "faith-neutral",
            src="; ".join(dict.fromkeys(sources)) or "—",
            rights="; ".join(dict.fromkeys(rights)) or "—",
            review=item.get("review", {}).get("status", "missing"),
            release="visible" if not blocking_reasons(item, cleared, editions) else "**BLOCKED**",
            missing="<br>".join(reasons) or "—"))
    print("""# Beloved — content approval register

Generated by `python3 Config/release-content-report.py --markdown` from
`content-fixtures.json` and `faiths.json`, using the same rules as the release gate. **Do not
edit by hand** — change the catalog (after a real review) and regenerate. Nothing here records a
review that has not happened.

| # | Item | Kind | Faith | Source / author | Rights | Review | Release | Missing before release |
|---|---|---|---|---|---|---|---|---|""")
    print("\n".join(rows))
    print(scripture_register(cleared, editions))
    print("""
## How an item becomes releasable (human steps)

1. A qualified reviewer for that tradition checks the exact text, transliteration, labels and
   explanation in a development build (draft items are badged there).
2. For scripture (`sourceText`): the named edition's licence is confirmed in writing and its
   `faiths.json` entry changed from `pendingClearance` to the real licence, with attribution text.
3. Composed prayers: the author/editor label is replaced with the real, consenting author.
4. In `content-fixtures.json`, set `review.status` to `approved` and record reviewer, date and
   notes in `review` (no approvals without a named reviewer).
5. Regenerate this register and run `python3 -m unittest Config/test_release_tools.py`; the
   `test_current_catalog_has_no_release_content` guard must then be updated deliberately to
   list the approved items.

## Reviewer record template (one per item)

| Field | Value |
|---|---|
| Item id | |
| Reviewer name and qualification / community | |
| Tradition(s) the reviewer is competent in | |
| Text verified against (edition, page/URL, date) | |
| Transliteration / translation checked | yes / no / n.a. |
| Labels correct (scripture / traditional / composed / explanation) | yes / no |
| Changes requested | |
| Decision | approve / reject / revise |
| Date and signature | |
""")
    return 0


def scripture_register(cleared, editions):
    """Reader editions and daily-verse lists (ScripturePolicy.release: licence cleared AND
    `review.status` approved in scripture-library.json / daily-verses.json)."""
    if not os.path.exists(SCRIPTURE):
        return ""
    library = load(SCRIPTURE)
    daily = load(DAILY)
    lines = ["", "## Scripture reader (Bible / Quran / Gita tabs)", "",
             "Generated from `scripture-library.json` and `daily-verses.json` (written by",
             "`scripts/import_scripture.py`, which always records `draft`). A release build shows an",
             "edition only when its licence is cleared in `faiths.json` **and** a reviewer approved the",
             "bundled text; each faith's daily-verse list needs its own approval.", "",
             "| Edition | Work | Role | Rights | Review | Release |", "|---|---|---|---|---|---|"]
    for edition in library["editions"]:
        status = edition.get("review", {}).get("status", "missing")
        visible = edition["id"] in cleared and status == "approved"
        rights = licence_label(editions[edition["id"]]) if edition["id"] in editions else "not in faiths.json"
        lines.append(f"| `{edition['id']}` | {edition['work']} | {edition['role']} | {rights} | {status} | "
                     + ("visible" if visible else "**BLOCKED**") + " |")
    lines += ["", "| Daily-verse list | Passages | Review | Release |", "|---|---|---|---|"]
    for faith, block in daily["faiths"].items():
        status = block.get("review", {}).get("status", "missing")
        lines.append(f"| {faith} ({block['work']}) | {len(block['entries'])} | {status} | "
                     + ("visible" if status == "approved" else "**BLOCKED**") + " |")
    return "\n".join(lines)


def report():
    faiths = load(FAITHS)
    items = load_items()
    cleared = cleared_editions(faiths)
    groups = {faith["id"]: [0, 0] for faith in faiths}
    groups["faith-neutral"] = [0, 0]
    for item in items:
        key = item.get("faith") or "faith-neutral"
        counts = groups.setdefault(key, [0, 0])
        counts[1] += 1
        if is_release_visible(item, cleared):
            counts[0] += 1
    return groups


def main():
    if "--markdown" in sys.argv[1:]:
        return markdown_register()
    if "--items" in sys.argv[1:]:
        item_report()
        return 0
    groups = report()
    empty = [name for name, (visible, _) in groups.items() if visible == 0]
    for name, (visible, total) in sorted(groups.items()):
        print(f"{name}: {visible} of {total} items visible in release builds")
    if empty:
        print("NO RELEASE CONTENT for: " + ", ".join(sorted(empty)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
