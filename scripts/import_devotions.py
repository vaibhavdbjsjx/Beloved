#!/usr/bin/env python3
"""Build Beloved's devotional library (prayers, mantras, duas) from pinned, verified sources.

    python3 -I scripts/import_devotions.py              # verify sources, write devotions.json
    python3 -I scripts/import_devotions.py --fetch      # download missing pinned revisions first
    python3 -I scripts/import_devotions.py --check      # fail if devotions.json is stale

Sources (scripts/devotions/sources.json):
  * The Book of Common Prayer (1979, The Episcopal Church — public domain), "Prayers and
    Thanksgivings", from English Wikisource page transcriptions pinned by revision.
  * Rigveda 3.62 and 7.59 and the Santāna Gopāla stotram, from Sanskrit Wikisource pinned by
    revision.
  * Qur'anic duas cut word-for-word from the bundled Tanzil text (PLScripture resources).

Rules enforced here: every page's SHA-256 matches its pin; text is verbatim (only wiki markup is
removed); a dua phrase is a whole-word suffix of its verse in the Tanzil text, and its English is a
verbatim substring of Pickthall; every item is written as `draft` — approval is a reviewer's act.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import importlib.util
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "scripts" / "devotions" / "spec.json"
SOURCES = ROOT / "scripts" / "devotions" / "sources.json"
VENDOR = ROOT / "Vendor" / "devotion-sources"
SCRIPTURE = ROOT / "Packages" / "PrayerLockKit" / "Sources" / "PLScripture" / "Resources"
OUT = ROOT / "Packages" / "PrayerLockKit" / "Sources" / "PLContent" / "Resources" / "devotions.json"
USER_AGENT = "BelovedApp-devotions-importer/1.0 (verified sourcing; low volume)"

_spec = importlib.util.spec_from_file_location("import_scripture", ROOT / "scripts" / "import_scripture.py")
_scripture = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_scripture)
devanagari_to_iast = _scripture.devanagari_to_iast

DRAFT = {"status": "draft", "notes": "Imported verbatim from a pinned source (scripts/import_devotions.py). Needs a faith reviewer: text, title, tags and any explanation."}

# ---------------------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------------------


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def api(site: str, params: dict) -> dict:
    url = f"https://{site}/w/api.php?" + urllib.parse.urlencode({**params, "format": "json", "formatversion": "2"})
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            import time
            time.sleep(10 * (attempt + 1))  # Wikimedia rate limit: back off politely


def fetch_revisions(site: str, revids: list[int]) -> dict[int, dict]:
    out: dict[int, dict] = {}
    for start in range(0, len(revids), 40):
        chunk = revids[start:start + 40]
        data = api(site, {"action": "query", "prop": "revisions", "revids": "|".join(map(str, chunk)),
                          "rvprop": "ids|content", "rvslots": "main"})
        for page in data["query"]["pages"]:
            for rev in page["revisions"]:
                out[rev["revid"]] = {"title": page["title"], "revid": rev["revid"], "content": rev["slots"]["main"]["content"]}
    return out


def pin(manifest: dict) -> None:
    """Resolve the current revision of every listed title and record revid + checksum."""
    for key, source in manifest["sources"].items():
        if source.get("pages"):
            continue  # already pinned; re-pin deliberately by deleting "pages"
        titles = source["titles"]
        pins = []
        for start in range(0, len(titles), 40):
            data = api(source["site"], {"action": "query", "prop": "revisions", "titles": "|".join(titles[start:start + 40]),
                                        "rvprop": "ids|content", "rvslots": "main"})
            by_title = {p["title"]: p for p in data["query"]["pages"]}
            for title in titles[start:start + 40]:
                page = by_title.get(title.replace("_", " "))
                if not page or "revisions" not in page:
                    sys.exit(f"{key}: page not found: {title}")
                rev = page["revisions"][0]
                pins.append({"title": page["title"], "revid": rev["revid"], "sha256": sha256(rev["slots"]["main"]["content"])})
        source["pages"] = pins
    SOURCES.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"pinned {sum(len(s['pages']) for s in manifest['sources'].values())} pages")


def load_sources(fetch: bool) -> dict[str, list[str]]:
    """Returns key → page contents in pinned order (verified by checksum)."""
    manifest = json.loads(SOURCES.read_text())
    out: dict[str, list[str]] = {}
    VENDOR.mkdir(parents=True, exist_ok=True)
    for key, source in manifest["sources"].items():
        cache = VENDOR / f"{key}.json"
        pages = json.loads(cache.read_text()) if cache.exists() else None
        if pages is None:
            if not fetch:
                sys.exit(f"missing {cache} — run with --fetch")
            revs = fetch_revisions(source["site"], [p["revid"] for p in source["pages"]])
            pages = [revs[p["revid"]] for p in source["pages"]]
            cache.write_text(json.dumps(pages, ensure_ascii=False))
        texts = []
        for expected, page in zip(source["pages"], pages):
            if page["revid"] != expected["revid"] or sha256(page["content"]) != expected["sha256"]:
                sys.exit(f"{key}: {expected['title']} does not match its pinned revision/checksum")
            texts.append(page["content"])
        out[key] = texts
    for key, files in manifest.get("files", {}).items():
        for lang in ("hi", "en"):
            spec = files[lang]
            path = VENDOR / spec["file"]
            if not path.exists():
                if not fetch:
                    sys.exit(f"missing {path} — run with --fetch")
                request = urllib.request.Request(spec["url"], headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(request, timeout=120) as response:
                    path.write_bytes(response.read())
            if hashlib.sha256(path.read_bytes()).hexdigest() != spec["sha256"]:
                sys.exit(f"{path.name} does not match its pinned checksum")
            out[f"{key}:{lang}"] = [path.read_text(encoding="utf-8", errors="strict")]
    return out


def page_lines(page_html: str) -> list[str]:
    body = re.sub(r"<script.*?</script>|<style.*?</style>", "", page_html, flags=re.S)
    text = html.unescape(re.sub(r"<[^>]+>", "\n", body))
    lines = [l.strip() for l in text.split("\n") if l.strip()]
    # Rejoin a word the page split across elements (a line that starts with a vowel sign).
    joined: list[str] = []
    for line in lines:
        if joined and unicodedata.category(line[0]) == "Mc" or (joined and unicodedata.category(line[0]) == "Mn"):
            joined[-1] += line
        else:
            joined.append(line)
    return joined


def chalisa(hi_html: str, en_html: str) -> tuple[str, str]:
    """Devanagari text (opening doha, chaupais, closing doha) and the page's romanisation."""
    hi = page_lines(hi_html)
    start = next(i for i, l in enumerate(hi) if l.startswith("श्रीगुरु"))
    end = next(i for i in range(start, len(hi)) if l_start(hi[i], "पवन तनय"))
    body = [l for l in hi[start:end + 2] if l not in ("चौपाई", "दोहा")]
    verses = re.split(r"(?<=।।)\s*", " ".join(body))
    original = "\n".join(v.strip() for v in verses if v.strip())
    en = page_lines(en_html)
    s2 = next(i for i, l in enumerate(en) if l.startswith("Shri Guru Charan"))
    e2 = next(i for i in range(s2, len(en)) if en[i].startswith("Pavan Tanay"))
    roman = "\n".join(l for l in en[s2:e2 + 1] if l not in ("Chaupai", "Doha"))
    if original.count("।।") < 40:
        raise ValueError("Hanuman Chalisa looks incomplete")
    return original, roman


def l_start(line: str, prefix: str) -> bool:
    return line.startswith(prefix)


# ---------------------------------------------------------------------------------------
# Wiki markup → text (markup only; words untouched)
# ---------------------------------------------------------------------------------------

_TEMPLATE = re.compile(r"\{\{([^{}]*)\}\}")


def _template(match: re.Match) -> str:
    parts = match.group(1).split("|")
    name = parts[0].strip().lower()
    if name in ("hws",):
        return parts[2] if len(parts) > 2 else (parts[1] if len(parts) > 1 else "")
    if name in ("hwe",):
        return ""
    if name in ("font-size", "font-size-x", "smaller", "larger", "sc", "small-caps", "x-larger", "center"):
        return parts[-1]
    if name in ("em", "gap", "nbsp"):
        return " "
    return ""  # layout templates (dhr, anchor, right, …)


def strip_markup(text: str) -> str:
    text = re.sub(r"<noinclude>.*?</noinclude>", "", text, flags=re.S)
    text = re.sub(r"<section[^>]*/>", "", text)
    for _ in range(4):
        text = _TEMPLATE.sub(_template, text)
    text = re.sub(r"<br\s*/?>", "\n", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("'''", "").replace("''", "")
    text = html.unescape(text).replace("‑", "-")
    return text


def tidy(text: str) -> str:
    lines = [re.sub(r"[ \t ]+", " ", line).strip() for line in text.split("\n")]
    paragraphs, current = [], []
    for line in lines:
        if line:
            current.append(line)
        elif current:
            paragraphs.append(" ".join(current))
            current = []
    if current:
        paragraphs.append(" ".join(current))
    return "\n\n".join(paragraphs).strip()


# ---------------------------------------------------------------------------------------
# Book of Common Prayer 1979 — numbered prayers
# ---------------------------------------------------------------------------------------

_BCP_HEAD = re.compile(r"''\s*(\d+)\.\s+(.+?)''\s*\n")
# A paragraph that is entirely italic (optionally inside a font template) is a rubric.
_RUBRIC = re.compile(r"(\{\{[^{}|]*\|[^{}|]*\|)?\s*''[^']+''\s*(\}\})?\s*", re.S)


def parse_bcp(pages: list[str]) -> tuple[dict[int, tuple[str, str]], dict[int, tuple[str, str]]]:
    """Returns (prayers, thanksgivings): number → (title, text)."""
    joined = []
    for raw in pages:
        raw = re.sub(r"<noinclude>.*?</noinclude>", "", raw, flags=re.S)
        raw = re.sub(r"<section[^>]*/>", "", raw)
        joined.append(raw)
    full = " ".join(joined)
    # The Thanksgivings section starts on its own page; find its heading position.
    marker = re.search(r"\{\{font-size[^}]*\|\s*Thanksgivings\s*\}\}", full)
    sections = (full[:marker.start()], full[marker.start():]) if marker else (full, "")

    def items(section: str) -> dict[int, tuple[str, str]]:
        result: dict[int, tuple[str, str]] = {}
        heads = list(_BCP_HEAD.finditer(section))
        for i, head in enumerate(heads):
            end = heads[i + 1].start() if i + 1 < len(heads) else len(section)
            body = section[head.end():end]
            # Drop section headings ('''Prayers for …''') that sit between prayers, and rubrics:
            # instructions printed wholly in italics, which are not words of the prayer.
            body = re.sub(r"'''[^']+'''", "", body)
            body = "\n\n".join(p for p in re.split(r"\n\s*\n", body) if not _RUBRIC.fullmatch(p.strip()))
            title = tidy(strip_markup(head.group(2)))
            text = tidy(strip_markup(body))
            number = int(head.group(1))
            if number not in result:
                result[number] = (title, text)
        return result

    return items(sections[0]), items(sections[1])


# ---------------------------------------------------------------------------------------
# Sanskrit Wikisource
# ---------------------------------------------------------------------------------------


def poem(text: str) -> str:
    """All <poem> blocks, in order (pages split a hymn around images)."""
    blocks = re.findall(r"<poem>(.*?)</poem>", text, re.S)
    body = "\n".join(blocks) if blocks else text
    body = re.sub(r"<[^>]+>", "", body)
    return html.unescape(body)


_DEVA_DIGITS = str.maketrans("०१२३४५६७८९", "0123456789")


def rigveda_verse(page_text: str, number: int) -> str:
    """The verse ending in ॥number॥, as its two half-lines."""
    body = poem(page_text)
    # Verses end with ॥N॥ (Devanagari digits).
    parts = re.split(r"॥\s*([०-९]+)\s*॥", body)
    verses = {}
    for i in range(1, len(parts), 2):
        verses[int(parts[i].translate(_DEVA_DIGITS))] = parts[i - 1]
    if number not in verses:
        raise ValueError(f"verse {number} not found")
    lines = [l.strip() for l in verses[number].strip().split("\n") if l.strip()]
    return "\n".join(lines) + " ॥"


def shloka_with(page_text: str, phrase: str, verses: int = 1, numbered: bool = False, dots: bool = False) -> str:
    """The verse(s) containing `phrase`, verbatim: from the start of the line where the phrase
    appears through the `verses`-th double danda (॥ or ।।) that follows."""
    body = poem(page_text) if "<poem>" in page_text else re.sub(r"<[^>]+>", "", page_text)
    body = html.unescape(re.sub(r"\{\{[^{}]*\}\}", "", body))
    # Markup only: bold quotes and <br>; some pages type dandas as | and ||.
    body = body.replace("'''", "").replace("<br>", "")
    body = body.replace("।।", "॥").replace("||", "॥").replace("|", "।")
    if dots:  # pages converted from ITRANS write ॥ as ".." and । as "."
        body = re.sub(r"\s*\.\.\s*([०-९0-9]+)", r" ॥ \1॥", body)
        body = re.sub(r"\s*\.\.", " ॥", body)
        body = re.sub(r"\s+\.(?=\s*$)", " ।", body, flags=re.M)
    at = body.find(phrase)
    if at < 0:
        raise ValueError(f"phrase not found: {phrase!r}")
    start = body.rfind("\n", 0, at) + 1
    end = at  # a verse ends at the first ॥ after the phrase itself
    numbered_end = re.compile(r"॥\s*[०-९0-9][०-९0-9.\-]*\s*॥?")
    for _ in range(verses):
        if numbered:
            # pages that mark every half-verse with ॥: a verse ends only at its number
            found = numbered_end.search(body, end)
            end = found.start() if found else -1
        else:
            end = body.find("॥", end)
        if end < 0:
            raise ValueError(f"no verse end after {phrase!r}")
        # include the verse number that follows the danda (॥ १ ॥)
        closing = re.match(r"॥(\s*[०-९0-9.\-]+\s*॥)?", body[end:])
        end += closing.end() if closing else 1
    lines = [re.sub(r"[ \t\u00a0]+", " ", l).strip() for l in body[start:end].split("\n")]
    text = "\n".join(l for l in lines if l)
    text = re.sub(r"\s*॥\s*[०-९0-9.\-]+\s*॥\s*$", " ॥", text)  # verse number → plain end mark
    return text


def santana_gopala(page_text: str, part: str) -> str:
    body = poem(page_text)
    lines = [re.sub(r"[ \t]+", " ", l).strip() for l in body.split("\n")]
    lines = [l for l in lines if l]
    if part == "mula":
        start = next(i for i, l in enumerate(lines) if "मूल मन्त्र" in l) + 1
        end = next(i for i in range(start, len(lines)) if lines[i].endswith("॥"))
        return "\n".join(lines[start:end + 1])
    if part == "stotra":
        start = next(i for i, l in enumerate(lines) if l.startswith("सन्तानगोपालस्तोत्रं")) + 1
        end = max(i for i, l in enumerate(lines) if re.search(r"॥\s*[०-९0-9]+\s*॥", l))
        return "\n".join(lines[start:end + 1])
    raise ValueError(part)


# ---------------------------------------------------------------------------------------
# Qur'anic duas from the bundled Tanzil text
# ---------------------------------------------------------------------------------------


def bare(word: str) -> str:
    """Letters only: decomposed (so آ and ا + ٓ compare equal), marks removed."""
    return "".join(c for c in unicodedata.normalize("NFD", word) if unicodedata.category(c) != "Mn")


def quran_text(edition: dict, surah: int, first: int, last: int) -> list[str]:
    return edition["books"][0]["chapters"][surah - 1][first - 1:last]


def phrase_from(verse: str, marker: str) -> str:
    """The verse from the first word that matches `marker` (ignoring diacritics) to the end."""
    words = verse.split(" ")
    target = bare(marker)
    for index, word in enumerate(words):
        if bare(word) == target:
            return " ".join(words[index:])
    raise ValueError(f"word {marker!r} not found in verse")


# ---------------------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------------------


def item(id: str, faith: str, kind: str, title: str, segments: list, spec: dict, length: str = "standard") -> dict:
    return {
        "id": id, "faith": faith, "traditions": spec.get("traditions", []), "focuses": spec.get("focuses", []), "kind": kind,
        "title": title, "segments": segments, "themes": spec.get("themes", []), "moods": spec.get("moods", []),
        "timesOfDay": spec.get("times", []), "occasions": [], "length": spec.get("length", length),
        "isPremium": False, "review": DRAFT,
    }


def explanation(text: str) -> dict:
    return {"role": "explanation", "text": text, "author": "Beloved editorial (draft)"}


def build(sources: dict[str, list[str]]) -> list[dict]:
    spec = json.loads(SPEC.read_text())
    items: list[dict] = []

    # Christianity — BCP 1979
    c = spec["christianity"]
    prayers, thanks = parse_bcp(sources["bcp1979"])
    if len(prayers) != 70 or len(thanks) != 11:
        raise ValueError(f"BCP: expected 70 prayers and 11 thanksgivings, got {len(prayers)} and {len(thanks)}")
    for group, table, prefix, label in (("prayers", prayers, "prayer", "Prayers"), ("thanksgivings", thanks, "thanksgiving", "Thanksgivings")):
        for entry in c[group]:
            title, text = table[entry["n"]]
            if len(text) < 40 or "{{" in text or "''" in text:
                raise ValueError(f"BCP {group} {entry['n']} looks malformed: {text[:80]!r}")
            slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
            items.append(item(
                f"christianity.bcp.{prefix}-{entry['n']}-{slug}"[:80], "christianity",
                "gratitude" if group == "thanksgivings" else "prayer", title,
                [{"role": "sourceText", "text": text,
                  "citation": {"source": c["source"], "edition": c["edition"],
                               "reference": f"Prayers and Thanksgivings, {'Thanksgiving' if group == 'thanksgivings' else 'Prayer'} {entry['n']}"}}],
                entry, length="brief" if len(text) < 420 else "standard"))

    # Christianity — traditional prayers (public-domain printed sources on English Wikisource)
    for entry in c.get("traditional", []):
        v = entry["passage"]
        text = tidy(strip_markup("\n".join(sources[v["page"]])))
        start = text.find(v["start"])
        end = text.find(v["end"], start)
        if start < 0 or end < 0:
            raise ValueError(f"{entry['id']}: passage not found")
        passage = text[start:end + len(v["end"])]
        for wrong, right in v.get("fixes", []):
            if wrong not in passage:
                raise ValueError(f"{entry['id']}: fix {wrong!r} no longer matches")
            passage = passage.replace(wrong, right)
        items.append(item(entry["id"], "christianity", entry["kind"], entry["title"],
                          [{"role": "sourceText", "text": passage,
                            "citation": {"source": v["source"], "edition": v["edition"], "reference": v["reference"]}},
                           explanation(entry["explanation"])], entry, length="brief" if len(passage) < 420 else "standard"))

    # Hinduism — Sanskrit Wikisource
    for entry in spec["hinduism"]:
        if "chalisa" in entry:
            original, roman = chalisa(sources["hanuman-chalisa:hi"][0], sources["hanuman-chalisa:en"][0])
            c = entry["chalisa"]
            segment = {"role": "sourceText", "original": {"text": original, "language": "hi", "script": "Deva"},
                       "transliteration": roman,
                       "citation": {"source": c["source"], "edition": c["edition"], "reference": c["reference"]}}
            items.append(item(entry["id"], "hinduism", entry["kind"], entry["title"],
                              [segment, explanation(entry["explanation"])], entry))
            continue
        if "shloka" in entry:
            v = entry["shloka"]
            original = shloka_with(sources[v["page"]][0], v["phrase"], v.get("verses", 1), v.get("numbered", False), v.get("dots", False))
            # Editorial corrections of obvious typos on the source page, listed in the spec
            # for review; each must still match (so a changed source is noticed).
            for wrong, right in v.get("fixes", []):
                if wrong not in original:
                    raise ValueError(f"{entry['id']}: fix {wrong!r} no longer matches")
                original = original.replace(wrong, right)
            cite = {"source": v["source"], "edition": v["edition"], "reference": v["reference"]}
            segment = {"role": "sourceText", "original": {"text": original, "language": "sa", "script": "Deva"},
                       "transliteration": devanagari_to_iast(original), "citation": cite}
            items.append(item(entry["id"], "hinduism", entry["kind"], entry["title"],
                              [segment, explanation(entry["explanation"])], entry))
            continue
        if "verse" in entry:
            v = entry["verse"]
            original = rigveda_verse(sources[v["page"]][0], v["verse"])
            cite = {"source": v["source"], "edition": v["edition"], "reference": v["reference"]}
        else:
            v = entry["stotra"]
            original = santana_gopala(sources[v["page"]][0], v["part"])
            cite = {"source": v["source"], "edition": v["edition"], "reference": v["reference"]}
        segment = {"role": "sourceText", "original": {"text": original, "language": "sa", "script": "Deva"},
                   "transliteration": devanagari_to_iast(original), "citation": cite}
        items.append(item(entry["id"], "hinduism", entry["kind"], entry["title"],
                          [segment, explanation(entry["explanation"])], entry))

    # Islam — Tanzil
    arabic = json.loads((SCRIPTURE / "quran.ar.json").read_text())
    english = json.loads((SCRIPTURE / "quran.en.json").read_text())
    for entry in spec["islam"]:
        surah, verses = entry["ref"].split(":")
        surah = int(surah)
        first, _, last = verses.partition("-")
        first, last = int(first), int(last or first)
        ar = quran_text(arabic, surah, first, last)
        en = quran_text(english, surah, first, last)
        if "from" in entry:
            ar = [phrase_from(ar[0], entry["from"])] + ar[1:]
            start = en[0].find(entry["translationFrom"])
            if start < 0:
                raise ValueError(f"{entry['id']}: {entry['translationFrom']!r} not in Pickthall {entry['ref']}")
            en = [en[0][start:]] + en[1:]
        reference = f"{surah}:{first}" + (f"–{last}" if last != first else "")
        note = {"note": "Phrase from the verse."} if "from" in entry else {}
        items.append(item(entry["id"], "islam", "dua" if entry["id"].startswith("islam.dua") else "scripture", entry["title"], [
            {"role": "sourceText", "original": {"text": " ".join(ar), "language": "ar", "script": "Arab"},
             "citation": {"source": "quran", "edition": "quran.ar", "reference": reference, **note}},
            {"role": "sourceText", "text": " ".join(en),
             "citation": {"source": "quran", "edition": "quran.en", "reference": reference, **note}},
            explanation(entry["explanation"]),
        ], entry, length="brief" if len(" ".join(en)) < 300 else "standard"))

    ids = [i["id"] for i in items]
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate ids")
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--pin", action="store_true", help="record current revisions of sources.json titles")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.pin:
        pin(json.loads(SOURCES.read_text()))
        return 0
    items = build(load_sources(args.fetch))
    body = json.dumps(items, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != body:
            print("stale: devotions.json")
            return 1
        return 0
    OUT.write_text(body, encoding="utf-8")
    counts = {}
    for i in items:
        counts[i["faith"]] = counts.get(i["faith"], 0) + 1
    print(f"wrote {len(items)} items {counts} to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
