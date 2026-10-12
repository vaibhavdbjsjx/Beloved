#!/usr/bin/env python3
"""Build Beloved's bundled scripture library from pinned, checksum-verified sources.

    python3 -I scripts/import_scripture.py            # verify sources, write resources
    python3 -I scripts/import_scripture.py --fetch    # download missing sources first
    python3 -I scripts/import_scripture.py --check    # verify only; fail if resources are stale

Sources (scripts/scripture/sources.json) live in Vendor/scripture-sources (git-ignored).
Output goes to Packages/PrayerLockKit/Sources/PLScripture/Resources.

Rules this script enforces:
  * Every source file must match its pinned SHA-256 — no silent upstream changes.
  * Verse text is copied verbatim. The only edits are the formatting normalisations that
    each edition's `modifications` field declares (Tanzil text: none at all — its licence
    forbids changes).
  * Book/chapter/verse counts are checked against known totals.
  * Every curated daily-verse reference must resolve, and every Arnold excerpt must be a
    verbatim span of the normalised Arnold text.
  * Content-catalog segments that cite a bundled edition must quote it exactly
    (`--sync-fixtures` rewrites them from the edition).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES_MANIFEST = ROOT / "scripts" / "scripture" / "sources.json"
DAILY_INPUT = ROOT / "scripts" / "scripture" / "daily-verses.json"
VENDOR = ROOT / "Vendor" / "scripture-sources"
OUT = ROOT / "Packages" / "PrayerLockKit" / "Sources" / "PLScripture" / "Resources"
FIXTURES = ROOT / "Packages" / "PrayerLockKit" / "Sources" / "PLContent" / "Resources" / "content-fixtures.json"

# ---------------------------------------------------------------------------------------
# Bible metadata (eBible VPL book codes, Protestant canon order)
# ---------------------------------------------------------------------------------------

BIBLE_BOOKS = [
    ("GEN", "Genesis"), ("EXO", "Exodus"), ("LEV", "Leviticus"), ("NUM", "Numbers"),
    ("DEU", "Deuteronomy"), ("JOS", "Joshua"), ("JDG", "Judges"), ("RUT", "Ruth"),
    ("1SA", "1 Samuel"), ("2SA", "2 Samuel"), ("1KI", "1 Kings"), ("2KI", "2 Kings"),
    ("1CH", "1 Chronicles"), ("2CH", "2 Chronicles"), ("EZR", "Ezra"), ("NEH", "Nehemiah"),
    ("EST", "Esther"), ("JOB", "Job"), ("PSA", "Psalms"), ("PRO", "Proverbs"),
    ("ECC", "Ecclesiastes"), ("SOL", "Song of Songs"), ("ISA", "Isaiah"), ("JER", "Jeremiah"),
    ("LAM", "Lamentations"), ("EZE", "Ezekiel"), ("DAN", "Daniel"), ("HOS", "Hosea"),
    ("JOE", "Joel"), ("AMO", "Amos"), ("OBA", "Obadiah"), ("JON", "Jonah"), ("MIC", "Micah"),
    ("NAH", "Nahum"), ("HAB", "Habakkuk"), ("ZEP", "Zephaniah"), ("HAG", "Haggai"),
    ("ZEC", "Zechariah"), ("MAL", "Malachi"),
    ("MAT", "Matthew"), ("MAR", "Mark"), ("LUK", "Luke"), ("JOH", "John"), ("ACT", "Acts"),
    ("ROM", "Romans"), ("1CO", "1 Corinthians"), ("2CO", "2 Corinthians"),
    ("GAL", "Galatians"), ("EPH", "Ephesians"), ("PHI", "Philippians"),
    ("COL", "Colossians"), ("1TH", "1 Thessalonians"), ("2TH", "2 Thessalonians"),
    ("1TI", "1 Timothy"), ("2TI", "2 Timothy"), ("TIT", "Titus"), ("PHM", "Philemon"),
    ("HEB", "Hebrews"), ("JAM", "James"), ("1PE", "1 Peter"), ("2PE", "2 Peter"),
    ("1JO", "1 John"), ("2JO", "2 John"), ("3JO", "3 John"), ("JUD", "Jude"),
    ("REV", "Revelation"),
]
OT_COUNT = 39
# Singular name used in references ("Psalm 46:10", not "Psalms 46:10").
REFERENCE_NAMES = {"PSA": "Psalm"}

# Known totals — a changed upstream file that slipped past the checksum would trip these.
EXPECTED = {
    "web": (66, 1189, 31103),
    "hebrew": (39, 929, 23213),
    "greek": (27, 260, 7959),
    "quran": (1, 114, 6236),
    "gita": (1, 18, 701),
}

TANZIL_NOTICE_MARK = "PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK"

# ---------------------------------------------------------------------------------------
# Devanagari → IAST
# ---------------------------------------------------------------------------------------

_INDEPENDENT_VOWELS = {
    "अ": "a", "आ": "ā", "इ": "i", "ई": "ī", "उ": "u", "ऊ": "ū", "ऋ": "ṛ", "ॠ": "ṝ",
    "ऌ": "ḷ", "ॡ": "ḹ", "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au",
}
_VOWEL_SIGNS = {
    "ा": "ā", "ि": "i", "ी": "ī", "ु": "u", "ू": "ū", "ृ": "ṛ", "ॄ": "ṝ", "ॢ": "ḷ",
    "ॣ": "ḹ", "े": "e", "ै": "ai", "ो": "o", "ौ": "au",
}
_CONSONANTS = {
    "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "ṅ",
    "च": "c", "छ": "ch", "ज": "j", "झ": "jh", "ञ": "ñ",
    "ट": "ṭ", "ठ": "ṭh", "ड": "ḍ", "ढ": "ḍh", "ण": "ṇ",
    "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
    "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m",
    "य": "y", "र": "r", "ल": "l", "ळ": "ḷ", "व": "v",
    "श": "ś", "ष": "ṣ", "स": "s", "ह": "h",
}
_OTHER = {
    "ं": "ṃ", "ः": "ḥ", "ँ": "m̐", "ऽ": "'", "।": " |", "॥": "||", "ॐ": "oṃ",
    "०": "0", "१": "1", "२": "2", "३": "3", "४": "4", "५": "5", "६": "6", "७": "7",
    "८": "8", "९": "9",
}
_VIRAMA = "्"
_NUKTA = "़"
_IGNORED = {"‌", "‍", _NUKTA}


def devanagari_to_iast(text: str) -> str:
    """Transliterate Sanskrit Devanagari to IAST (deterministic; no dictionary)."""
    out: list[str] = []
    chars = [c for c in text if c not in _IGNORED]
    i = 0
    while i < len(chars):
        c = chars[i]
        if c in _CONSONANTS:
            out.append(_CONSONANTS[c])
            nxt = chars[i + 1] if i + 1 < len(chars) else ""
            if nxt in _VOWEL_SIGNS:
                out.append(_VOWEL_SIGNS[nxt])
                i += 2
                continue
            if nxt == _VIRAMA:
                i += 2
                continue
            out.append("a")
        elif c in _INDEPENDENT_VOWELS:
            out.append(_INDEPENDENT_VOWELS[c])
        elif c in _OTHER:
            out.append(_OTHER[c])
        elif c in _VOWEL_SIGNS or c == _VIRAMA:
            raise ValueError(f"orphan vowel sign or virama in {text!r}")
        elif "ऀ" <= c <= "ॿ":
            raise ValueError(f"unmapped Devanagari character U+{ord(c):04X} in {text!r}")
        else:
            out.append(c)
        i += 1
    # "धीमहि ।" (a space before the danda) must not become "dhīmahi  |".
    return re.sub(r" {2,}", " ", "".join(out))


# ---------------------------------------------------------------------------------------
# Source loading
# ---------------------------------------------------------------------------------------


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def load_sources(fetch: bool) -> dict:
    manifest = json.loads(SOURCES_MANIFEST.read_text())
    for key, src in manifest["sources"].items():
        path = VENDOR / src["file"]
        if not path.exists():
            if not fetch:
                sys.exit(f"missing source {path} — run with --fetch")
            VENDOR.mkdir(parents=True, exist_ok=True)
            print(f"downloading {src['url']}")
            with urllib.request.urlopen(src["url"], timeout=300) as r:
                path.write_bytes(r.read())
        actual = sha256(path)
        if actual != src["sha256"]:
            sys.exit(f"checksum mismatch for {src['file']}: {actual} (pinned {src['sha256']}). "
                     "Review the upstream change, then update scripts/scripture/sources.json.")
    return manifest


def read_text(src: dict) -> str:
    path = VENDOR / src["file"]
    if "member" in src:
        with zipfile.ZipFile(path) as z:
            return z.read(src["member"]).decode("utf-8")
    return path.read_text(encoding="utf-8")


_VPL_LINE = re.compile(r"^(\S+) (\d+):(\d+) ?(.*)$")


def parse_vpl(text: str, book_ids: list[str]) -> list[dict]:
    """eBible verse-per-line → [{id, chapters: [[verse]]}] with contiguous numbering checks."""
    books: dict[str, list[list[str]]] = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        m = _VPL_LINE.match(line)
        if not m:
            raise ValueError(f"unparseable VPL line: {line[:80]!r}")
        book, chapter, verse, body = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4).strip()
        chapters = books.setdefault(book, [])
        while len(chapters) < chapter:
            chapters.append([])
        verses = chapters[chapter - 1]
        if verse <= len(verses):
            raise ValueError(f"{book} {chapter}:{verse} is out of sequence")
        # A verse some manuscripts omit (e.g. Mark 7:16 in the Patriarchal Text) is an
        # empty slot, so numbering stays aligned; readers skip empty slots.
        verses.extend([""] * (verse - len(verses) - 1))
        verses.append(body)
    if list(books) != book_ids:
        raise ValueError(f"unexpected book order: {list(books)}")
    for book, chapters in books.items():
        if any(not verses for verses in chapters):
            raise ValueError(f"{book} has an empty chapter")
    return [{"id": b, "chapters": books[b]} for b in book_ids]


def parse_tanzil(text: str) -> tuple[list[list[str]], str]:
    """Tanzil `sura|aya|text` → chapters, plus the copyright block (comment lines)."""
    surahs: list[list[str]] = []
    notice: list[str] = []
    for line in text.splitlines():
        if line.startswith("#"):
            notice.append(line)
            continue
        if not line.strip():
            continue
        sura, aya, body = line.split("|", 2)
        sura, aya = int(sura), int(aya)
        while len(surahs) < sura:
            surahs.append([])
        if aya != len(surahs[sura - 1]) + 1:
            raise ValueError(f"{sura}:{aya} is out of sequence")
        surahs[sura - 1].append(body)
    return surahs, "\n".join(notice).strip()


def parse_quran_metadata(text: str) -> list[dict]:
    m = re.search(r"QuranData\.Sura = \[(.*?)\n\];", text, re.S)
    rows = re.findall(r"\[(\d+), (\d+), (\d+), (\d+), '([^']*)', \"([^\"]*)\", '([^']*)', '(\w+)'\]", m.group(1))
    if len(rows) != 114:
        raise ValueError(f"expected 114 surah rows, found {len(rows)}")
    return [{"ayahs": int(r[1]), "arabic": r[4], "transliteration": r[5], "english": r[6],
             "revelation": r[7].lower()} for r in rows]


# Gita (gita/gita data) ------------------------------------------------------------------

# Only the narrators' formulae; "तमुवाच" (2.10) is verse text, not a speaker line.
_SPEAKER = re.compile(r"^\s*((?:धृतराष्ट्र|सञ्जय|संजय|अर्जुन)\s*उवाच|श्री\s*भगवानुवाच)\s*")
_LEGACY_I = re.compile("([\u0915-\u0939])\u094d\u093f((?:[\u0915-\u0939]\u094d)*[\u0915-\u0939])")
_VERSE_NUMBER = re.compile(r"\s*।{1,2}\s*\d+\s*\.\s*\d+\s*।{0,2}\s*$")


def normalise_gita_verse(raw: str) -> tuple[str | None, str]:
    """Formatting-only normalisation: speaker line split off, verse number removed,
    `।।` written as `॥`, missing line breaks after `।` restored, blank lines collapsed."""
    # Legacy encoding puts the pre-base vowel sign ि straight after a virama ("निश्िचत");
    # Unicode order is the whole consonant cluster first ("निश्चित"). Same letters, fixed order.
    text = _LEGACY_I.sub("\\1\u094d\\2\u093f", raw.strip())
    speaker = None
    m = _SPEAKER.match(text)
    if m:
        speaker = re.sub(r"\s+", " ", m.group(1)).strip()
        text = text[m.end():]
    text, count = _VERSE_NUMBER.subn("", text)
    if count != 1:
        raise ValueError(f"Gita verse without a closing number: {raw!r}")
    text = text.replace("।।", "॥")
    text = re.sub(r"।(?!\s*\n)\s*", "।\n", text)
    lines = [re.sub(r"[ \t]+", " ", line).strip() for line in text.split("\n")]
    text = "\n".join(line for line in lines if line) + " ॥"
    return speaker, text


# Arnold (Project Gutenberg #2388) -------------------------------------------------------

ARNOLD_SPEAKERS = {"Krishna", "Arjuna", "Sanjaya", "Dhritirashtra"}
_ROMAN = re.compile(r"^\s*CHAPTER ([IVXL]+)\s*$")


def normalise_arnold_line(line: str) -> str:
    line = re.sub(r"\[FN#\d+\]", "", line)
    line = line.replace("--", "—")
    line = re.sub(r"[ \t]+", " ", line)
    return line.strip()


def parse_arnold(text: str) -> tuple[list[list[str]], dict[str, str], list[str]]:
    lines = text.replace("\r", "").split("\n")
    start = next(i for i, l in enumerate(lines) if l.startswith("*** START OF"))
    end = next(i for i, l in enumerate(lines) if l.startswith("*** END OF"))
    lines = lines[start + 1:end]
    chapters: list[list[str]] = []
    speakers: dict[str, str] = {}
    titles: list[str] = []
    current: list[str] | None = None
    paragraph: list[str] = []
    pending_speaker: str | None = None
    closing = False
    title_open = False

    def flush():
        nonlocal paragraph, pending_speaker
        if current is None or not paragraph:
            paragraph = []
            return
        body = [normalise_arnold_line(l) for l in paragraph]
        body = [l for l in body if l]
        if body and body[0].rstrip(".:") in ARNOLD_SPEAKERS and len(body[0]) <= 15:
            pending_speaker = body[0].rstrip(".:")
            body = body[1:]
        if body:
            current.append("\n".join(body))
            if pending_speaker:
                speakers[f"{len(chapters)}:{len(current)}"] = pending_speaker
                pending_speaker = None
        paragraph = []

    for line in lines:
        if _ROMAN.match(line):
            flush()
            current = []
            chapters.append(current)
            closing = False
            continue
        if current is None:
            continue
        if line.strip().startswith("HERE END"):
            flush()
            closing = True
            continue
        if closing:
            stripped = line.strip()
            if line.startswith("[FN#"):
                break
            if title_open:
                titles[-1] += " " + stripped
                title_open = not stripped.endswith('"') and not stripped.endswith('",')
            elif stripped.startswith("Or") and len(titles) < len(chapters):
                titles.append(stripped[2:].strip())
                title_open = not stripped.endswith('"') and not stripped.endswith('",')
            continue
        if line.strip():
            paragraph.append(line)
        else:
            flush()
    flush()
    titles = [t.strip().strip('"').rstrip(',."').strip() for t in titles]
    return chapters, speakers, titles


# ---------------------------------------------------------------------------------------
# References
# ---------------------------------------------------------------------------------------

_REF = re.compile(r"^(\S+) (\d+):(\d+)(?:-(\d+))?$")


def parse_ref(ref: str) -> tuple[str, int, int, int]:
    m = _REF.match(ref)
    if not m:
        raise ValueError(f"bad reference {ref!r}")
    first = int(m.group(3))
    last = int(m.group(4) or first)
    if last < first:
        raise ValueError(f"reversed range {ref!r}")
    return m.group(1), int(m.group(2)), first, last


def lookup(edition: dict, book: str, chapter: int, first: int, last: int) -> list[str]:
    for b in edition["books"]:
        if b["id"] == book:
            verses = b["chapters"][chapter - 1]
            if last > len(verses):
                raise ValueError(f"{book} {chapter}:{last} does not exist in {edition['id']}")
            texts = verses[first - 1:last]
            if not all(t.strip() for t in texts):
                raise ValueError(f"{book} {chapter}:{first}-{last} has an empty verse in {edition['id']}")
            return texts
    raise ValueError(f"{book} not in {edition['id']}")


# ---------------------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------------------


def counts(books: list[dict]) -> tuple[int, int, int]:
    return (len(books), sum(len(b["chapters"]) for b in books),
            sum(len(v) for b in books for v in b["chapters"]))


def check_counts(name: str, books: list[dict]) -> None:
    got = counts(books)
    if got != EXPECTED[name]:
        raise ValueError(f"{name}: expected {EXPECTED[name]} books/chapters/verses, got {got}")


def build(manifest: dict) -> tuple[dict[str, dict], dict, dict]:
    src = manifest["sources"]
    retrieved = manifest["retrieved"]
    book_ids = [b for b, _ in BIBLE_BOOKS]

    web = parse_vpl(read_text(src["web"]), book_ids)
    hebrew = parse_vpl(read_text(src["hebrew"]), book_ids[:OT_COUNT])
    greek = parse_vpl(read_text(src["greek"]), book_ids[OT_COUNT:])
    for name, books in (("web", web), ("hebrew", hebrew), ("greek", greek)):
        check_counts(name, books)

    quran_ar, tanzil_notice = parse_tanzil(read_text(src["quranArabic"]))
    if TANZIL_NOTICE_MARK not in tanzil_notice:
        raise ValueError("Tanzil copyright block missing")
    quran_en, _ = parse_tanzil(read_text(src["quranPickthall"]))
    surahs = parse_quran_metadata(read_text(src["quranMetadata"]))
    for name, chapters in (("quran", quran_ar), ("quran", quran_en)):
        check_counts(name, [{"chapters": chapters}])
    if [len(c) for c in quran_ar] != [s["ayahs"] for s in surahs] or [len(c) for c in quran_en] != [s["ayahs"] for s in surahs]:
        raise ValueError("Quran ayah counts disagree with Tanzil metadata")

    gita_rows = sorted(json.loads(read_text(src["gitaSanskrit"])), key=lambda r: (r["chapter_number"], r["verse_number"]))
    gita_sa: list[list[str]] = [[] for _ in range(18)]
    gita_iast: list[list[str]] = [[] for _ in range(18)]
    gita_speakers_sa: dict[str, str] = {}
    gita_speakers_iast: dict[str, str] = {}
    for row in gita_rows:
        c, v = row["chapter_number"], row["verse_number"]
        if v != len(gita_sa[c - 1]) + 1:
            raise ValueError(f"Gita {c}.{v} out of sequence")
        speaker, verse = normalise_gita_verse(row["text"])
        gita_sa[c - 1].append(verse)
        gita_iast[c - 1].append(devanagari_to_iast(verse))
        if speaker:
            gita_speakers_sa[f"{c}:{v}"] = speaker
            gita_speakers_iast[f"{c}:{v}"] = devanagari_to_iast(speaker)
    check_counts("gita", [{"chapters": gita_sa}])
    gita_chapter_meta = sorted(json.loads(read_text(src["gitaChapters"])), key=lambda r: r["chapter_number"])
    if [r["verses_count"] for r in gita_chapter_meta] != [len(c) for c in gita_sa]:
        raise ValueError("Gita verse counts disagree with chapters.json")

    arnold, arnold_speakers, arnold_titles = parse_arnold(read_text(src["gitaArnold"]))
    if len(arnold) != 18 or len(arnold_titles) != 18 or any(not c for c in arnold):
        raise ValueError(f"Arnold: expected 18 chapters/titles, got {len(arnold)}/{len(arnold_titles)}")

    def source(key: str) -> dict:
        s = src[key]
        return {"url": s["url"], "sha256": s["sha256"], "retrieved": retrieved}

    def review(note: str) -> dict:
        return {"status": "draft", "notes": note}

    editions = {
        "bible.web": {"id": "bible.web", "books": web},
        "bible.hbo": {"id": "bible.hbo", "books": hebrew},
        "bible.grc": {"id": "bible.grc", "books": greek},
        "quran.ar": {"id": "quran.ar", "books": [{"id": "QUR", "chapters": quran_ar}]},
        "quran.en": {"id": "quran.en", "books": [{"id": "QUR", "chapters": quran_en}]},
        "bhagavad-gita.sa": {"id": "bhagavad-gita.sa", "books": [{"id": "BG", "chapters": gita_sa, "speakers": gita_speakers_sa}]},
        "bhagavad-gita.sa-Latn": {"id": "bhagavad-gita.sa-Latn", "books": [{"id": "BG", "chapters": gita_iast, "speakers": gita_speakers_iast}]},
        "bhagavad-gita.en": {"id": "bhagavad-gita.en", "books": [{"id": "BG", "chapters": arnold, "speakers": arnold_speakers}]},
    }

    bible_books = []
    for index, (book_id, name) in enumerate(BIBLE_BOOKS):
        entry = {"id": book_id, "title": {"en": name}, "group": "oldTestament" if index < OT_COUNT else "newTestament",
                 "chapterCount": len(web[index]["chapters"])}
        if book_id in REFERENCE_NAMES:
            entry["referenceTitle"] = {"en": REFERENCE_NAMES[book_id]}
        bible_books.append(entry)

    library = {
        "version": 1,
        "works": [
            {
                "id": "bible", "faith": "christianity",
                "title": {"en": "The Bible"}, "shortTitle": {"en": "Bible"},
                "translation": "bible.web", "originals": ["bible.hbo", "bible.grc"],
                "transliteration": None, "parallel": False,
                "books": bible_books,
            },
            {
                "id": "quran", "faith": "islam",
                "title": {"en": "The Quran"}, "shortTitle": {"en": "Quran"},
                "translation": "quran.en", "originals": ["quran.ar"],
                "transliteration": None, "parallel": True,
                "books": [{
                    "id": "QUR", "title": {"en": "The Quran"}, "chapterCount": 114,
                    "chapters": [{"title": {"en": s["english"]}, "originalTitle": s["arabic"],
                                  "transliteratedTitle": s["transliteration"], "detail": s["revelation"]}
                                 for s in surahs],
                }],
            },
            {
                "id": "bhagavad-gita", "faith": "hinduism",
                "title": {"en": "Bhagavad Gita"}, "shortTitle": {"en": "Gita"},
                "translation": "bhagavad-gita.en", "originals": ["bhagavad-gita.sa"],
                "transliteration": "bhagavad-gita.sa-Latn", "parallel": False,
                "books": [{
                    "id": "BG", "title": {"en": "Bhagavad Gita"}, "chapterCount": 18,
                    "chapters": [{"title": {"en": arnold_titles[i]}, "originalTitle": meta["name"],
                                  "transliteratedTitle": devanagari_to_iast(meta["name"])}
                                 for i, meta in enumerate(gita_chapter_meta)],
                }],
            },
        ],
        "editions": [
            {
                "id": "bible.web", "work": "bible", "role": "translation",
                "title": {"en": "World English Bible"}, "shortTitle": "WEB",
                "language": "en", "script": "Latn", "direction": "ltr", "versification": "english",
                "unit": "verse", "books": book_ids,
                "attribution": "World English Bible (WEB), 2020 stable text edition. Public domain. “World English Bible” is a trademark of eBible.org.",
                "attributionURL": "https://worldenglish.bible",
                "modifications": "None — verbatim verse text from eBible.org.",
                "source": source("web"),
                "review": review("Spot-check the text against eBible.org before approval."),
            },
            {
                "id": "bible.hbo", "work": "bible", "role": "original",
                "title": {"en": "Hebrew Old Testament (Masoretic Text)"}, "shortTitle": "Hebrew",
                "language": "hbo", "script": "Hebr", "direction": "rtl", "versification": "masoretic",
                "unit": "verse", "books": book_ids[:OT_COUNT],
                "attribution": "The Old Testament in ancient Hebrew, following the Masoretic Text (Westminster Leningrad Codex), via eBible.org. Public domain.",
                "attributionURL": "https://ebible.org/find/details.php?id=hbo",
                "modifications": "None — verbatim. Hebrew chapter and verse numbers follow the Masoretic Text and sometimes differ from English Bibles.",
                "source": source("hebrew"),
                "review": review("Confirm the Hebrew rendering (vowels and cantillation) displays correctly on device."),
            },
            {
                "id": "bible.grc", "work": "bible", "role": "original",
                "title": {"en": "Greek New Testament (Patriarchal Text, 1904)"}, "shortTitle": "Greek",
                "language": "grc", "script": "Grek", "direction": "ltr", "versification": "byzantine",
                "unit": "verse", "books": book_ids[OT_COUNT:],
                "attribution": "1904 Patriarchal Greek New Testament, via eBible.org. Public domain.",
                "attributionURL": "https://ebible.org/find/details.php?id=grcbyz",
                "modifications": "None — verbatim.",
                "source": source("greek"),
                "review": review("Spot-check against the eBible.org edition."),
            },
            {
                "id": "quran.ar", "work": "quran", "role": "original",
                "title": {"en": "Tanzil Quran Text (Uthmani)"}, "shortTitle": "Arabic",
                "language": "ar", "script": "Arab", "direction": "rtl", "versification": "tanzil",
                "unit": "verse", "books": ["QUR"],
                "attribution": "Tanzil Quran Text (Uthmani, Version 1.1). Copyright © 2007–2026 Tanzil Project. License: Creative Commons Attribution 3.0.",
                "attributionURL": "https://tanzil.net",
                "notice": tanzil_notice,
                "modifications": "None. The Tanzil licence permits verbatim copies only; Beloved never alters this text.",
                "source": source("quranArabic"),
                "review": review("Scholarly reviewer to confirm the text and its display (font, ligatures, pause marks) on device."),
            },
            {
                "id": "quran.en", "work": "quran", "role": "translation",
                "title": {"en": "The Meaning of the Glorious Koran — Pickthall"}, "shortTitle": "Pickthall",
                "language": "en", "script": "Latn", "direction": "ltr", "versification": "tanzil",
                "unit": "verse", "books": ["QUR"],
                "attribution": "English translation of the meanings by Mohammed Marmaduke Pickthall (1930). Public domain. Digital text from Tanzil.net.",
                "attributionURL": "https://tanzil.net/trans/",
                "modifications": "None — verbatim.",
                "source": source("quranPickthall"),
                "review": review("Tanzil offers its translations for non-commercial use; Beloved is free. Re-check before any paid offering."),
            },
            {
                "id": "bhagavad-gita.sa", "work": "bhagavad-gita", "role": "original",
                "title": {"en": "Bhagavad Gita — Sanskrit"}, "shortTitle": "Sanskrit",
                "language": "sa", "script": "Deva", "direction": "ltr", "versification": "gita-701",
                "unit": "verse", "books": ["BG"],
                "attribution": "Sanskrit text from the gita/gita open dataset (github.com/gita/gita), released under The Unlicense.",
                "attributionURL": "https://github.com/gita/gita",
                "modifications": "Formatting only: legacy vowel-sign order fixed to standard Unicode (26 places, e.g. ‘निश्िचत’ → ‘निश्चित’); verse numbers and the speaker line (e.g. “arjuna uvāca”) are shown separately, ‘।।’ is written ‘॥’, and line breaks after ‘।’ are restored. Numbering follows the 701-verse recension (chapter 13 has 35 verses).",
                "source": source("gitaSanskrit"),
                "review": review("Sanskrit reviewer to verify against a printed edition."),
            },
            {
                "id": "bhagavad-gita.sa-Latn", "work": "bhagavad-gita", "role": "transliteration",
                "title": {"en": "Bhagavad Gita — transliteration (IAST)"}, "shortTitle": "IAST",
                "language": "sa", "script": "Latn", "direction": "ltr", "versification": "gita-701",
                "unit": "verse", "books": ["BG"],
                "attribution": "Transliteration generated by Beloved from the Sanskrit text (IAST).",
                "attributionURL": None,
                "modifications": "Machine transliteration of the Sanskrit edition; words follow the Devanagari spacing (sandhi kept).",
                "source": source("gitaSanskrit"),
                "review": review("Sanskrit reviewer to spot-check the transliteration."),
            },
            {
                "id": "bhagavad-gita.en", "work": "bhagavad-gita", "role": "translation",
                "title": {"en": "The Song Celestial — Sir Edwin Arnold (1885)"}, "shortTitle": "Arnold",
                "language": "en", "script": "Latn", "direction": "ltr", "versification": "arnold-passages",
                "unit": "passage", "books": ["BG"],
                "attribution": "The Song Celestial, translated by Sir Edwin Arnold (1885). Public domain. Text from Project Gutenberg eBook #2388.",
                "attributionURL": "https://www.gutenberg.org/ebooks/2388",
                "modifications": "Project Gutenberg header, licence and footnotes removed; ‘--’ set as em dashes; line indentation removed. Arnold’s poem follows the chapters, not individual verses.",
                "source": source("gitaArnold"),
                "review": review("Reviewer to confirm the Gutenberg text and chapter titles."),
            },
        ],
    }

    for info in library["editions"]:
        info["chapterCounts"] = {b["id"]: len(b["chapters"]) for b in editions[info["id"]]["books"]}
        if [b for b in info["books"]] != list(info["chapterCounts"]):
            raise ValueError(f"{info['id']}: book list disagrees with its text")

    # Daily verses -------------------------------------------------------------------
    curated = json.loads(DAILY_INPUT.read_text())
    arnold_by_chapter = ["\n\n".join(c) for c in arnold]
    daily: dict = {"version": 1, "faiths": {}}
    work_editions = {w["id"]: w for w in library["works"]}
    for faith, block in curated.items():
        if faith.startswith("_"):
            continue
        work = work_editions[block["work"]]
        entries = []
        for item in block["references"]:
            ref = item if isinstance(item, str) else item["ref"]
            book, chapter, first, last = parse_ref(ref)
            lookup(editions[work["translation"]] if work["id"] != "bhagavad-gita" else editions["bhagavad-gita.sa"],
                   book, chapter, first, last)
            entry: dict = {"book": book, "chapter": chapter, "firstVerse": first, "lastVerse": last}
            if work["id"] == "quran":
                lookup(editions["quran.ar"], book, chapter, first, last)
            if isinstance(item, dict):
                body = arnold_by_chapter[chapter - 1]
                start = body.find(item["from"])
                if start < 0:
                    raise ValueError(f"Arnold phrase not found in chapter {chapter}: {item['from']!r}")
                end = body.find(item["to"], start)
                if end < 0:
                    raise ValueError(f"Arnold phrase not found after start in chapter {chapter}: {item['to']!r}")
                entry["translationExcerpt"] = body[start:end + len(item["to"])]
            entries.append(entry)
        if len({(e["book"], e["chapter"], e["firstVerse"]) for e in entries}) != len(entries):
            raise ValueError(f"duplicate daily verse for {faith}")
        daily["faiths"][faith] = {
            "work": block["work"], "entries": entries,
            "review": {"status": "draft",
                       "notes": "Selection of passages needs a faith reviewer."
                       + (" Each Arnold excerpt's pairing with its verse needs confirmation." if block["work"] == "bhagavad-gita" else "")},
        }
    return editions, library, daily


# ---------------------------------------------------------------------------------------
# Content-catalog fixtures that quote bundled editions
# ---------------------------------------------------------------------------------------

_CATALOG_REF = {
    "bible": re.compile(r"^(?P<book>.+?) (?P<c>\d+):(?P<a>\d+)(?:[–-](?P<b>\d+))?$"),
    "quran": re.compile(r"^(?P<c>\d+):(?P<a>\d+)(?:[–-](?P<b>\d+))?$"),
    "bhagavad-gita": re.compile(r"^(?P<c>\d+)\.(?P<a>\d+)(?:[–-](?P<b>\d+))?$"),
}


def catalog_lookup(editions: dict, citation: dict) -> str | None:
    edition = editions.get(citation.get("edition", ""))
    pattern = _CATALOG_REF.get(citation.get("source", ""))
    if not edition or not pattern:
        return None
    m = pattern.match(citation.get("reference", ""))
    if not m:
        raise ValueError(f"unparseable catalog reference {citation}")
    if citation["source"] == "bible":
        names = {name: bid for bid, name in BIBLE_BOOKS} | {v: k for k, v in REFERENCE_NAMES.items()}
        book = names[m.group("book")]
    else:
        book = edition["books"][0]["id"]
    first = int(m.group("a"))
    last = int(m.group("b") or first)
    return " ".join(lookup(edition, book, int(m.group("c")), first, last))


def sync_fixtures(editions: dict, write: bool) -> list[str]:
    items = json.loads(FIXTURES.read_text())
    problems: list[str] = []
    for item in items:
        for segment in item["segments"]:
            citation = segment.get("citation")
            if segment.get("role") != "sourceText" or not citation:
                continue
            expected = catalog_lookup(editions, citation)
            if expected is None:
                continue
            partial = "Phrase from the verse" in (citation.get("note") or "")
            holder = segment["original"] if "original" in segment else None
            current = holder["text"] if holder else (segment.get("text") or {})
            current = current if isinstance(current, str) else current.get("en", "")
            if (partial and current and current in expected) or (not partial and current == expected):
                continue
            problems.append(f"{item['id']} ({citation['reference']}) does not quote {citation['edition']} exactly")
            if write and not partial:
                if holder:
                    holder["text"] = expected
                    latin = catalog_lookup(editions, citation | {"edition": citation["edition"] + "-Latn"})
                    if latin:
                        segment["transliteration"] = latin
                else:
                    segment["text"] = expected if isinstance(segment.get("text"), str) else {"en": expected}
    if write:
        FIXTURES.write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n")
    return problems


# ---------------------------------------------------------------------------------------


def dump(obj) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fetch", action="store_true", help="download missing sources")
    parser.add_argument("--check", action="store_true", help="fail if bundled resources differ from a fresh build")
    parser.add_argument("--sync-fixtures", action="store_true", help="rewrite catalog quotations from the editions")
    args = parser.parse_args()

    manifest = load_sources(args.fetch)
    editions, library, daily = build(manifest)
    outputs = {f"{eid}.json": dump(ed) for eid, ed in editions.items()}
    outputs["scripture-library.json"] = json.dumps(library, ensure_ascii=False, indent=1) + "\n"
    outputs["daily-verses.json"] = json.dumps(daily, ensure_ascii=False, indent=1) + "\n"

    problems = sync_fixtures(editions, write=args.sync_fixtures and not args.check)
    if args.check:
        stale = [name for name, body in outputs.items()
                 if not (OUT / name).exists() or (OUT / name).read_text(encoding="utf-8") != body]
        for p in problems:
            print("fixture:", p)
        for name in stale:
            print("stale:", name)
        return 1 if stale or problems else 0

    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in outputs.items():
        (OUT / name).write_text(body, encoding="utf-8")
    total = sum(len(b.encode()) for b in outputs.values())
    print(f"wrote {len(outputs)} files ({total / 1_000_000:.1f} MB) to {OUT.relative_to(ROOT)}")
    for eid, ed in editions.items():
        b, c, v = counts(ed["books"])
        print(f"  {eid:24} {b:3} books {c:5} chapters {v:6} units")
    for faith, block in daily["faiths"].items():
        print(f"  daily {faith:13} {len(block['entries'])} passages")
    for p in problems:
        print(("synced: " if args.sync_fixtures else "fixture: ") + p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
