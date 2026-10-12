# Faith system, content engine & religious calendar

## Principles

1. **Religion-agnostic core.** Code knows about *faiths, traditions, focuses, sources,
   editions, practices, themes, occasions* — never about "Bible" or "deity" specifically.
   Each faith declares its own structure in `faiths.json`.
2. **Different shapes are first-class.** Islam has no deity/focus step (by design); Hinduism
   offers deity/devotional focus; Christianity uses denominations. The UI hides steps a faith
   doesn't use, and the validator rejects content that crosses faiths (e.g. a Shiva focus on an
   Islamic item) or uses a practice the faith doesn't declare (e.g. an Islamic "mantra").
3. **No invented doctrine, no invented quotations.** Every piece of text says what it is.
4. **Customs are customs.** "Monday is a Shiva day" is modelled as an opt-in devotional
   association with an explanation ("In many Hindu communities…"), never as a rule.

## Provenance model (the most important rule)

Every `ContentSegment` has a `role`:

| Role | Meaning | Required |
|---|---|---|
| `sourceText` | verbatim text from a cited edition | citation with **edition** + reference; edition rights must be cleared for release |
| `traditionalText` | customary recitation (mantra, dhikr, liturgical form) | optional citation |
| `paraphrase` | restatement of a source, not a quotation | citation |
| `composedPrayer` | written by a named human editor | author |
| `generatedPrayer` | written by AI | **never allowed in the curated catalog** |
| `explanation` | meaning / context / translation note | — |
| `devotionalInterpretation` | reflection on a source | — |

The UI prints this on every segment (`ProvenanceLabel`: "SCRIPTURE · Psalm 46:10 · World
English Bible", "TRADITIONAL", "PRAYER · <editor>", "AI-GENERATED PRAYER", "MEANING").
App Store Guideline 1.1.5 forbids "inaccurate or misleading quotations of religious texts" —
this model is how we stay on the right side of it.

## Release gate

`ContentPolicy.release` shows only `approved` items whose `sourceText` segments come from
rights-cleared editions. `ContentPolicy.development` shows drafts (badged "Unreviewed draft").
Unit tests assert that **today, zero catalog items are shippable** — the honest state.

When no approved content matches, the moment shows "Sit quietly for a moment" rather than
inventing text.

## Phase 1 catalog = development fixtures

`content-fixtures.json` (26 items: 8 Christian, 7 Islamic, 8 Hindu, 3 faith-neutral) exists to exercise the engine. Every item is `draft` with a
reviewer note. Specifically:
- **Bible**: three short passages cited to the World English Bible (public domain) — wording
  must be verified against the official WEB files before approval.
- **Quran**: Arabic text cited to a *pending* edition (`quran.ar`, `pendingClearance`) —
  blocked in release until a verified mushaf text and licence are chosen. English is given only
  as an *editorial meaning summary* (`explanation`), not as a translation.
- **Hindu**: mantras as `traditionalText` with Devanagari + IAST transliteration; Rigveda/Gita
  references where well established; reviewer notes flag sensitivities (e.g. some communities
  restrict the Gayatri to the initiated; never present Mahamrityunjaya as a medical remedy).
- **Editorial prayers** in each tradition and **faith-neutral** reflections for users who
  choose not to state a faith.

## Sourcing plan (blocker for launch)

| Faith | Need | Candidate approach |
|---|---|---|
| Christianity | Bible text | WEB (public domain) now; licensed modern translations (NIV/ESV/NRSV) need publisher agreements |
| Islam | Arabic Quran text; English meanings; duas from hadith | Verified digital mushaf (King Fahd Complex / Tanzil — check terms), licensed translation, hadith references reviewed by scholars |
| Hinduism | Sanskrit texts, translations, regional practices | Verified Sanskrit editions; licensed or commissioned translations; advisors across Shaiva/Vaishnava/Shakta/Smarta |

Each faith needs at least one qualified reviewer; reviews are recorded in `ReviewInfo`.

## Content engine (selection)

`ContentSelector` is pure and deterministic:
- **Hard filters**: policy, premium, faith (neutral content always eligible), tradition-specific
  items only for that tradition, focus-specific items only for users who chose that focus (or
  have an opt-in custom for today).
- **Scoring** (`SelectionWeights`, explainable): mood match, requested/mood themes, active
  occasion, time of day, chosen focus, devotional custom, tradition, preferred length,
  faith-neutral fallback penalty, recency penalty.
- **Rotation**: ties broken by a stable FNV-1a hash of `day + item id` — the same prayer all
  day, a different one tomorrow.
- **Explainability**: each result carries `reasons` (future "why this prayer?" UI).

Future content kinds (morning/evening, long/short, festivals, family/work/study…) are data:
`timesOfDay`, `length`, `occasions`, `themes` on items.

## Religious calendar engine

| Rule | Used for | Precision |
|---|---|---|
| `fixedGregorian` | Western Christmas | computed |
| `fixedJulian` | Christmas for Julian-calendar Orthodox churches (7 Jan) | computed |
| `easter(gregorian/julian, offset)` | Ash Wednesday, Lent, Palm Sunday, Good Friday, Easter, Pentecost; Orthodox equivalents | computed (unit-tested against sample years 2000–2027) |
| `weekdayBefore` | First Sunday of Advent | computed |
| `hijri(month, day)` via Foundation Umm al-Qura | Ramadan, last ten nights, Eid al-Fitr, Day of Arafah, Eid al-Adha, Islamic New Year, Ashura, Muharram | **estimated** — UI says "Expected"; actual dates depend on moon sighting/local authority |
| `weekly` | Jumu'ah (Friday), the Lord's Day (Sunday) | computed |
| `table` | Hindu festivals (Maha Shivaratri, Holi, Rama Navami, Janmashtami, Ganesh Chaturthi, Navaratri, Diwali) | **sourced** — tables are empty until a regional panchang source is chosen; region-aware |

Tradition handling: Western observances apply to users with no denomination; Orthodox ones
only to Orthodox users. Observance notes explain differences (e.g. Ashura's different meaning
for Sunni and Shia Muslims; Revised-Julian Orthodox churches keeping 25 December).

Not yet modelled (deliberately): Mawlid (observed differently or not at all across
communities), regional saints' days, Ekadashi/tithi-level observances, salah times (need
calculation methods and madhab settings — a later feature).

Next step for Hindu dates: evaluate Foundation's `.vikram` / regional Indian calendars (iOS 18+)
against published panchangs; until validated, use sourced tables.

## Adding a faith (checklist)

1. Add the faith, traditions, optional focuses, practices, sources/editions to `faiths.json`.
2. Add observances and (if any) devotional associations.
3. Add reviewed content; run `swift test` (validator must report no errors).
4. Add localized display strings if new practice kinds are introduced.
