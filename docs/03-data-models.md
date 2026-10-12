# Data models & storage

## Where data lives

| Data | Location | Protection | Readers |
|---|---|---|---|
| `StoredProfile` (faith, tradition, focuses, preferences, optional name, today's check-in*, recently shown) | app container `Application Support/PrayerLock/profile.json` | `.complete` (unreadable while locked) | app |
| `[PrayerSession]` history | `…/sessions.json` | `.complete` | app |
| `ProtectionSettings`, `UnlockGrant`, `[ShieldRequest]`, `ShieldCopy`, encoded `FamilyActivitySelection` | App Group `UserDefaults` | default (after first unlock) | app + 3 extensions |
| Bundled faith / content / calendar / monetization data | package resource bundles (read-only) | — | app (+ extensions as linked) |

\* Today's mood is persisted only when "Remember daily check-ins" is on.

Nothing is sent to a server. Device backups (iCloud/computer) include the app container —
stated plainly to users.

## Core types

### Faith system (`PLFaith`)
```
Faith ─ id, name, summary
      ├─ traditionLabel + [Tradition]              ("Denomination", "Tradition (sampradaya)")
      ├─ focusLabel? + [SpiritualFocus]            (nil/empty for Islam & Christianity)
      ├─ practices: [PracticeKind]                 (prayer, scripture, mantra, stotra, dua, dhikr, …)
      └─ sources: [SourceWork] ─ referenceScheme   (bookChapterVerse, surahAyah, mandalaSuktaRik, …)
                               └─ [Edition] ─ language, script, license, attribution
ContentLicense = publicDomain | creativeCommons | licensed | pendingClearance
SpiritualProfile = faith?, tradition?, focuses, contentLength, languages, showOriginalScript,
                   showTransliteration, useDevotionalAssociations (opt-in), rememberCheckIns, displayName?
```
IDs are typed (`Identifier<Tag>`) and encode as plain strings: `christianity.catholic`,
`hinduism.shiva`, `bible.web`.

### Content (`PLContent`)
```
ContentItem ─ id, faith? (nil = faith-neutral), traditions[], focuses[], kind: PracticeKind,
              title, segments[], themes[], moods[], timesOfDay[], occasions[], length,
              isPremium, review: ReviewInfo(status: draft|inReview|approved|rejected, reviewer, date, notes)
ContentSegment ─ role: SegmentRole, text?, original?(text, language, script), transliteration?,
                 citation?(source, edition?, reference?, note?), author?
SegmentRole = sourceText | traditionalText | paraphrase | composedPrayer | generatedPrayer
              | explanation | devotionalInterpretation
```
Mood (check-in): grateful, anxious, stressed, sad, angry, lonely, hopeful, happy,
seekingGuidance, seekingForgiveness, needStrength, needPeace, celebrating, justWantToPray.

### Calendar (`PLCalendar`)
```
ObservanceDefinition ─ id (OccasionID), faith, traditions[], includeWhenTraditionUnspecified,
                       name, kind, schedule, precision (computed|estimated|sourcedTable), note?, source
ObservanceSchedule = rule(start: DateRule, end: DateRule?) | weekly(isoWeekday) | table([DatedEntry])
DateRule = fixedGregorian | fixedJulian | easter(computus, offset) | weekdayBefore | hijri | offset(rule, days)
DevotionalAssociation ─ faith, traditions[], isoWeekday, focus?, themes[], explanation
```

### Habits (`PLHabits`)
```
PrayerSession ─ id, startedAt, endedAt, trigger (shield|manual|reminder), outcome,
                contentItemID?, themes[], mood? (only if remembered), grantedAccess
HabitSummary ─ currentStreak, longestStreak, practicedToday, lastSevenDays, daysPracticedLast7/30,
               totalCompletedSessions, totalTimeInPrayer, shieldMomentsCompleted, topThemes, milestones
```

### Protection (`PLProtection`)
```
ProtectionSettings ─ isEnabled, unlockDuration (.minutes(n) | .restOfDay)
UnlockGrant ─ id, grantedAt, expiresAt, usageLimit?, sessionID?
ShieldRequest ─ id, createdAt, subject (application|category|webDomain), tokenData (opaque)
ShieldCopy ─ title, titleForApp ("{app} can wait a moment"), subtitle, buttons, awaitingSubtitle,
             notificationTitle/Body  (prepared by the app, localized; no personal data)
ProtectionStatus = unavailable | needsAuthorization | needsSelection | off | active | unlocked(until)
```

### Monetization (`PLMonetization`)
```
MonetizationConfiguration ─ isPaywallEnabled, products[(id, plan)], premiumFeatures[]   (no prices)
SubscriptionState = unknown | notSubscribed | subscribed(d) | inGracePeriod(d) | inBillingRetry(d)
                    | expired(d) | revoked
SubscriptionDetails ─ productID, plan?, expiresAt?, willAutoRenew, isTrial, gracePeriodExpiresAt?
```

## Evolution rules

- Stored JSON is decoded tolerantly (`decodeIfPresent` + defaults) so new fields never wipe data.
- Shared App Group values are versionless but small; breaking changes must use new keys.
- When history grows beyond JSON comfort (likely years of daily use), migrate sessions to
  SQLite/SwiftData behind the same `SessionRepository` protocol.
