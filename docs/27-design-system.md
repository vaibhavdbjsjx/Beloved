# Beloved — design system: "Threshold"

Date: 2026-10-10. Code: `Packages/PrayerLockKit/Sources/PLDesign` (tokens, type, motion,
components) and `PLBrand/Palette.swift` (colour values shared with the Screen Time
extensions). Visual QA: `sh scripts/screenshot-tour.sh OUT_DIR`.

## Vision

A pause is a **threshold** — the moment between reaching for something and choosing it.
Beloved is designed like a beautifully set devotional book: vellum paper, printer's ink, lapis
and gilt, generous margins, and a reading voice in serif. It should feel intimate and
trustworthy, never like a dashboard, a game or a motivational poster.

- **The arch is the signature.** Arches frame sacred space in every tradition Beloved serves —
  church windows, the mihrab, temple gateways (torana) — so the motif carries meaning without
  belonging to one faith. It appears as the breathing `ThresholdWindow`, the small
  `ThresholdMark`, Journey's day marks, the protection status mark and the app icon.
- **Light tells time.** A soft wash of the hour's light (dawn, day, dusk, night) sits behind
  headers; prayer traditions are anchored in the hours, and it makes each visit feel present.
- **Quiet luxury.** Depth comes from tone and hairlines, not shadows. Gilt is used sparingly
  (eyebrows, ornaments, marks). One prominent action per screen.
- **Emotionally kind.** No streaks, no guilt, no urgency. "A missed day is simply a day."
  Returning after a break: "There's nothing to catch up on — just this moment."

## Colour (light / dark)

Every text token meets WCAG AA (4.5:1) on every background in both appearances —
enforced by `PaletteContrastTests`. Dark is designed as a night vigil (warm ink, parchment
text, candle-gold accents), not an inversion.

| Token | Light | Dark | Use |
|---|---|---|---|
| canvas (vellum) | `#F4EFE6` | `#0F1014` | Every screen's page |
| surface (paper) | `#FBF8F2` | `#17181E` | Cards and rows, never stark white |
| surfaceRaised | `#ECE5D7` | `#21232B` | Pressed, inset, disabled |
| accentSoft | `#E4E8F3` | `#1E2742` | Selected backgrounds, theme chips |
| ink | `#1D1B18` | `#EDE6D8` | Text |
| inkSecondary | `#5C564C` | `#ADA698` | Supporting text (≥ 5.8:1) |
| accent (lapis) | `#243B7F` | `#A9BBEE` | Links, marks, lapis text |
| accentFill / onAccentFill | `#243B7F` / white | `#4462B8` / `#F1EBDD` | Primary buttons, selected chips — deep stone lapis at night |
| gilt | `#7A5A14` | `#D9B76E` | Eyebrows, ornaments, marks |
| sage | `#4A7660` | `#8DC2A4` | Active status mark (non-text, ≥ 3:1) |
| line | `#DCD3C2` | `#2C2E36` | Hairlines (decorative only) |
| caution / destructive | `#8A5A10` / `#A8231A` | `#E2B66B` / `#FF8A80` | Attention / delete |
| dawn · day · dusk · night light | warm rose · gold · amber · moonlit blue | deeper equivalents | Decorative washes only |

Status is never colour alone: `PLStatusMark` changes shape (filled arch, outlined arch with a
mark, empty arch) and is always next to words.

## Typography

System serif (New York) for display and reading; SF Pro for interface. All Dynamic Type.

| Style | Spec | Use |
|---|---|---|
| `plHero()` | serif regular 40pt, scales with `.largeTitle` | Welcome, Today greeting |
| `plDisplay` | serif regular `.largeTitle` | Screen and step titles |
| `plTitle` / `plTitleSmall` | serif medium `.title2` / `.title3` | Cards, rows |
| `plReading()` | serif `.title3`, line spacing 7 | Prayer and scripture |
| `plQuote` | serif italic `.title3` | Intentions, closing lines |
| `plEyebrow()` | caption semibold, expanded width, uppercase, gilt | Labels above titles (no tracking — see D45) |
| `plNumeral` | serif light `.largeTitle`, monospaced digits | Journey figures |
| `plVerseNumber` | serif semibold caption, monospaced digits, gilt | Verse numbers in the reader margin |
| `PLScriptStyle.forScript` | Arabic `.title` +16 leading · Hebrew `.title2` +12 · Devanagari `.title3` +10 · Greek serif `.title3` +8 | Original-language scripture (room for harakat, niqqud, cantillation, matras) |
| Navigation titles | serif (large: regular; inline: semibold) via `UINavigationBar.appearance()` | Protection, Journey, Settings |

## Space, shape, motion

- Spacing 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64; page margin 24.
- Radii: chip 10, control 16, panel 24 (continuous corners).
- Motion (`PLMotion`): `standard` spring (0.42 s, no bounce) for state; `gentle` (0.7 s) for
  compositional changes; `press` for touch; `breath` = 4 s in, 4 s out. Sections appear with a
  short stagger (`plStaggered`). **Reduce Motion** turns every movement into a 0.2 s fade and
  stops the breathing.
- Haptics: selection on choices, chips and mood words; success when a moment completes.

## Components (PLDesign)

`PLPrimaryButtonStyle` (lapis; disabled = paper + secondary ink, not faded lapis),
`PLSecondaryButtonStyle` (paper + hairline), `PLQuietButtonStyle` (text, 44pt), `plPaper()`,
`PLHairline`, `PLOrnament`, `PLChoiceCard` + `PLSelectionMark` (shape changes when
selected), `PLChip`, `PLFlowLayout`, `PLStatusMark`, `ArchShape`, `ThresholdWindow`
(breathing / still / open), `ThresholdMark`, `PLLightWash`, `ProvenanceLabel` (gilt eyebrow),
`ContentSegmentView` (reading typography).

## Screens

| Screen | Composition |
|---|---|
| Welcome | Breathing threshold, wordmark lockup, hero "A pause before the scroll.", three facts |
| Onboarding steps | Serif step titles, numbered progress (`2 / 7`), choice cards, "Make it yours" (name, intention, moment length, script), privacy ledger, protection panel, real notification preview, summary ledger |
| Today | Hour light; date eyebrow + hero greeting; "Today's moment" card (provenance, title, preview, small threshold, Begin, duration); calendar notes; one ledger: intention · how you're arriving · protection |
| Moment | Arrival (breathing threshold, "Breathe with the light"), mood words, reading page with ornament, breath-fill finish button, intention choices (personal first), open threshold + chosen intention on completion |
| Protection | Status hero (arch mark + title + sentence), panel (authorize / apps / switch / duration chips), can-and-can't ledger |
| Journey | "You paused on N of the last 7 days", seven arches lit in gilt, three serif figures, theme words, recent moments; designed empty state |
| Scripture (Bible / Quran / Gita tab) | Contents page: "Read" eyebrow, work title, editions line; "Continue reading" card (the screen's one primary button); testaments of books, or surahs/chapters with number, transliterated and English name, and the original-script title; "About these texts" |
| Chapter reader | Eyebrow + serif display title (+ original-script title); language chips (translation · original · Both only when numbering agrees); honest notes (Hebrew numbering, Arnold's poem); ornament; verses with gilt numbers hanging in the margin (Arabic-Indic for Arabic), speakers as eyebrows, original in `PLScriptStyle` per script, IAST in italic serif; attribution + tanzil.net link; previous/next chapter |
| Settings | Native form on vellum with paper rows; Intentions, Appearance, and Verse for today sections |
| Legal | Serif headings with hairlines, gilt diamond bullets, 620pt measure |
| App icon | Gilt double-ruled arch with a point of candlelight on deep lapis (`scripts/make_app_icon.py`) |

## Features added with the redesign

1. **Personal intentions** — up to three, on-device (`SpiritualProfile.intentions`, tolerant
   decoding so older profiles still load). One shows on Today each day; the moment offers them
   first as "what will you do next?"; the completion screen echoes the chosen one. Never shown
   on the Screen Time shield (extensions get no personal data).
2. **Appearance** — Automatic / Light / Dark chips (`pl.appearance`, standard defaults).
3. **Breath-fill finish** — the five-second minimum is a slow lapis fill, not a disabled button.
4. **Welcome back** — after 7+ days away, a kind note instead of any streak or "catch up".
5. **Quieter check-in** — moved from a 14-button grid on Today into a sheet and the moment.
6. **Revisit a moment** — Journey's recent moments reopen their passage (D46).
7. **Scripture reader** — the chosen faith's own scripture as a tab (D47–D50), original
   language and translation, continue reading, chapter grid, search.
8. **Verse for today** — a card on Today (original, transliteration, translation, source,
   Read / Share) and an opt-in daily notification (D51).

## Rules for new UI

Use tokens and components, never raw colours or one-off sizes; one primary action per screen;
every state has words, not only colour; check light, dark, AX5 text and Reduce Motion with
`scripts/screenshot-tour.sh` and the UI tests before calling a screen done.
