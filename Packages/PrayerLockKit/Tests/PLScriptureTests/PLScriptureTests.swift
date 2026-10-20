import Foundation
import PLContent
import PLCore
import PLFaith
@testable import PLScripture
import Testing

private let library = try! ScriptureLibrary()
private let registry = try! FaithRegistry.bundled()
private var manifest: ScriptureManifest { library.manifest }

private func work(_ id: SourceWorkID) -> ScriptureWork { manifest.work(id)! }
private func readable(_ faith: FaithID, _ policy: ScripturePolicy = .development) -> ReadableWork? {
    policy.readableWork(for: faith, manifest: manifest, registry: registry)
}

/// The bundled manifest with every edition put back to draft: what a build looks like before
/// any reviewer has approved it.
private var unapprovedManifest: ScriptureManifest {
    var draft = manifest
    for index in draft.editions.indices { draft.editions[index].review.status = .draft }
    return draft
}

@Suite("Scripture manifest")
struct ManifestTests {
    @Test func everyFaithWithScriptureHasOneWork() {
        #expect(manifest.works.map(\.faith) == ["christianity", "islam", "hinduism"])
        #expect(manifest.work(for: "christianity")?.shortTitle.resolved(for: ["en"]) == "Bible")
        #expect(manifest.work(for: "islam")?.shortTitle.resolved(for: ["en"]) == "Quran")
        #expect(manifest.work(for: "hinduism")?.shortTitle.resolved(for: ["en"]) == "Gita")
    }

    @Test func everyEditionIsRegisteredWithALicence() {
        for edition in manifest.editions {
            let registered = registry.edition(edition.id)
            #expect(registered != nil, "\(edition.id) is missing from faiths.json")
            #expect(registered?.license.permitsRedistribution == true, "\(edition.id) has no cleared licence")
            #expect(registry.source(owning: edition.id) == edition.work)
            #expect(!edition.attribution.isEmpty)
            #expect(edition.source.sha256.count == 64)
        }
    }

    @Test func worksReferenceRealEditions() {
        for work in manifest.works {
            for id in [work.translation] + work.originals + [work.transliteration].compactMap({ $0 }) {
                #expect(manifest.edition(id)?.work == work.id)
            }
        }
    }

    @Test func everyApprovalNamesAReviewerAndDate() {
        // Approval is a reviewer's decision: when one is recorded, it says whose and when.
        for edition in manifest.editions where edition.review.status == .approved {
            #expect(edition.review.reviewer?.isEmpty == false && edition.review.reviewedOn != nil, "\(edition.id)")
        }
        for (faith, list) in library.daily.faiths where list.review.status == .approved {
            #expect(list.review.reviewer?.isEmpty == false && list.review.reviewedOn != nil, "\(faith)")
        }
    }

    @Test func tanzilNoticeTravelsWithTheText() throws {
        let quran = try #require(manifest.edition("quran.ar"))
        #expect(quran.notice?.contains("CHANGING IT IS NOT ALLOWED") == true)
        #expect(quran.attributionURL?.host() == "tanzil.net")
        #expect(quran.direction == .rtl)
    }
}

@Suite("Reading chapters")
struct ChapterTests {
    @Test func bibleVerseIsVerbatim() async throws {
        let psalm = try #require(try await library.chapter("bible.web", book: "PSA", chapter: 46))
        #expect(psalm.unit(10)?.text.hasPrefix("“Be still, and know that I am God.") == true)
        let genesis = try #require(try await library.chapter("bible.web", book: "GEN", chapter: 1))
        #expect(genesis.units.first?.text == "In the beginning, God created the heavens and the earth.")
        #expect(genesis.units.count == 31)
    }

    @Test func hebrewUsesItsOwnNumbering() async throws {
        let hebrew = try #require(manifest.edition("bible.hbo"))
        let english = try #require(manifest.edition("bible.web"))
        #expect(hebrew.chapterCount(book: "MAL") == 3)
        #expect(english.chapterCount(book: "MAL") == 4)
        #expect(try await library.chapter("bible.hbo", book: "MAL", chapter: 4) == nil)
        #expect(hebrew.versification != english.versification)
        #expect(!hebrew.covers(book: "MAT"))
    }

    @Test func omittedVersesAreSkippedNotRenumbered() async throws {
        let mark = try #require(try await library.chapter("bible.grc", book: "MAR", chapter: 7))
        #expect(mark.unit(16) == nil)
        #expect(mark.unit(17) != nil)
    }

    @Test func quranArabicAndTranslationAlign() async throws {
        let arabic = try #require(try await library.chapter("quran.ar", book: "QUR", chapter: 1))
        let english = try #require(try await library.chapter("quran.en", book: "QUR", chapter: 1))
        #expect(arabic.units.count == 7)
        #expect(english.units.count == 7)
        #expect(english.units[1].text == "Praise be to Allah, Lord of the Worlds,")
        let info = try #require(work("quran").books.first?.chapterInfo(94))
        #expect(info.transliteratedTitle == "Ash-Sharh")
    }

    @Test func gitaHasSpeakersAndTransliteration() async throws {
        let sanskrit = try #require(try await library.chapter("bhagavad-gita.sa", book: "BG", chapter: 1))
        let latin = try #require(try await library.chapter("bhagavad-gita.sa-Latn", book: "BG", chapter: 1))
        #expect(sanskrit.units.first?.speaker == "धृतराष्ट्र उवाच")
        #expect(latin.units.first?.speaker == "dhṛtarāṣṭra uvāca")
        #expect(sanskrit.units.count == latin.units.count)
        let verse = try await library.passage("bhagavad-gita.sa-Latn", PassageReference(book: "BG", chapter: 2, firstVerse: 47))
        #expect(verse.first?.text.hasPrefix("karmaṇyevādhikāraste mā phaleṣu kadācana") == true)
    }

    @Test func arnoldIsPassagesWithSpeakers() async throws {
        let edition = try #require(manifest.edition("bhagavad-gita.en"))
        #expect(edition.unit == .passage)
        let chapter = try #require(try await library.chapter("bhagavad-gita.en", book: "BG", chapter: 2))
        #expect(chapter.units.contains { $0.speaker == "Krishna" })
        #expect(chapter.units.allSatisfy { !$0.text.contains("[FN#") && !$0.text.contains("--") })
    }

    @Test func missingVersesThrow() async {
        await #expect(throws: ScriptureError.self) {
            try await library.passage("quran.en", PassageReference(book: "QUR", chapter: 1, firstVerse: 7, lastVerse: 8))
        }
        await #expect(throws: ScriptureError.self) {
            try await library.chapter("nope", book: "X", chapter: 1)
        }
    }
}

@Suite("What a build may show")
struct PolicyTests {
    @Test func releaseShowsNothingUntilReviewersApprove() {
        for faith: FaithID in ["christianity", "islam", "hinduism"] {
            #expect(ScripturePolicy.release.readableWork(for: faith, manifest: unapprovedManifest, registry: registry) == nil)
        }
    }

    @Test func releaseShowsTheApprovedBundle() {
        for faith: FaithID in ["christianity", "islam", "hinduism"] {
            #expect(readable(faith, .release) != nil, "\(faith)")
        }
    }

    @Test func developmentShowsEveryWork() throws {
        #expect(readable("christianity") != nil)
        #expect(readable("islam") != nil)
        #expect(readable("hinduism") != nil)
        #expect(readable("buddhism") == nil)
    }

    @Test func approvalAndLicenceAreBothRequired() throws {
        var edition = try #require(manifest.edition("bible.web"))
        edition.review.status = .draft
        #expect(!ScripturePolicy.release.permits(edition, registry: registry))
        edition.review.status = .approved
        #expect(ScripturePolicy.release.permits(edition, registry: registry))
        edition.review.status = .rejected
        #expect(!ScripturePolicy.development.permits(edition, registry: registry))
        // An approved text from an uncleared edition is still refused.
        var uncleared = try #require(manifest.edition("bible.web"))
        uncleared.id = "rigveda.sa"
        uncleared.review.status = .approved
        #expect(!ScripturePolicy.release.permits(uncleared, registry: registry))
    }

    @Test func layoutsFollowNumbering() throws {
        let bible = try #require(readable("christianity"))
        #expect(bible.layouts(for: "GEN") == [.translation, .original])
        #expect(bible.original(for: "GEN")?.id == "bible.hbo")
        #expect(bible.original(for: "JOH")?.id == "bible.grc")
        #expect(bible.chapterCount(book: "MAL", layout: .translation) == 4)
        #expect(bible.chapterCount(book: "MAL", layout: .original) == 3)

        let quran = try #require(readable("islam"))
        #expect(quran.layouts(for: "QUR") == [.translation, .original, .parallel])

        let gita = try #require(readable("hinduism"))
        #expect(gita.layouts(for: "BG") == [.translation, .original])
        #expect(gita.transliteration?.id == "bhagavad-gita.sa-Latn")
        #expect(gita.layout(preferred: .parallel, for: "BG") == .translation)
        #expect(gita.layout(preferred: .original, for: "BG") == .original)
    }

    @Test func partialApprovalShowsOnlyApprovedParts() throws {
        var approved = unapprovedManifest
        for index in approved.editions.indices where approved.editions[index].id == "quran.ar" {
            approved.editions[index].review.status = .approved
        }
        let quran = try #require(ScripturePolicy.release.readableWork(for: "islam", manifest: approved, registry: registry))
        #expect(quran.translation == nil)
        #expect(quran.layouts(for: "QUR") == [.original])
        #expect(quran.firstLocation == ScriptureLocation(work: "quran", book: "QUR", chapter: 1))
    }
}

@Suite("Daily verse")
struct DailyVerseTests {
    private let start = CivilDate(year: 2026, month: 10, day: 11)

    @Test func rotatesThroughEveryEntryBeforeRepeating() throws {
        for (faith, list) in library.daily.faiths {
            let days = (0..<list.entries.count).map { start.adding(days: $0) }
            let picks = days.compactMap { library.daily.entry(for: faith, on: $0) }
            #expect(Set(picks).count == list.entries.count, "\(faith) repeats early")
            #expect(library.daily.entry(for: faith, on: start) == library.daily.entry(for: faith, on: start))
        }
    }

    @Test func everyCuratedPassageResolves() async throws {
        for faith in library.daily.faiths.keys {
            let count = library.daily.faiths[faith]!.entries.count
            for offset in 0..<count {
                let verse = try await library.dailyVerse(for: faith, on: start.adding(days: offset), policy: .development, registry: registry)
                let resolved = try #require(verse)
                #expect(resolved.translationText?.isEmpty == false, "\(faith) +\(offset) has no translation")
            }
        }
    }

    @Test func eachFaithGetsTheRightLanguages() async throws {
        // Bible: English only (Hebrew/Greek number some verses differently).
        let bible = try #require(try await library.dailyVerse(for: "christianity", on: start, policy: .development, registry: registry))
        #expect(bible.originalText == nil)
        // Quran: Arabic and English, same numbering.
        let quran = try #require(try await library.dailyVerse(for: "islam", on: start, policy: .development, registry: registry))
        #expect(quran.originalEdition?.id == "quran.ar")
        #expect(quran.translationEdition?.id == "quran.en")
        // Gita: Sanskrit, IAST, and Arnold's lines.
        let gita = try #require(try await library.dailyVerse(for: "hinduism", on: start, policy: .development, registry: registry))
        #expect(gita.originalEdition?.id == "bhagavad-gita.sa")
        #expect(gita.transliterationText?.isEmpty == false)
        #expect(gita.translationEdition?.id == "bhagavad-gita.en")
    }

    @Test func releaseHasNoDailyVerseUntilApproved() async throws {
        var unapproved = try #require(library.daily.faiths["islam"])
        unapproved.review.status = .draft
        #expect(!ScripturePolicy.release.permits(unapproved))
        #expect(ScripturePolicy.release.permits(try #require(library.daily.faiths["islam"])))
        #expect(try await library.dailyVerse(for: "buddhism", on: start, policy: .development, registry: registry) == nil)
    }
}

@Suite("References")
struct ReferenceTests {
    @Test func formatting() {
        let bible = work("bible")
        #expect(ScriptureReferenceFormatter.format(PassageReference(book: "PSA", chapter: 46, firstVerse: 10), in: bible, scheme: .bookChapterVerse) == "Psalm 46:10")
        #expect(ScriptureReferenceFormatter.format(PassageReference(book: "1CO", chapter: 13, firstVerse: 4, lastVerse: 7), in: bible, scheme: .bookChapterVerse) == "1 Corinthians 13:4–7")
        #expect(ScriptureReferenceFormatter.format(PassageReference(book: "QUR", chapter: 94, firstVerse: 5, lastVerse: 6), in: work("quran"), scheme: .surahAyah) == "Quran 94:5–6")
        #expect(ScriptureReferenceFormatter.format(PassageReference(book: "BG", chapter: 2, firstVerse: 47), in: work("bhagavad-gita"), scheme: .chapterVerse) == "Bhagavad Gita 2.47")
        #expect(ScriptureReferenceFormatter.format(chapter: 23, book: "PSA", in: bible) == "Psalm 23")
    }

    @Test func parsing() {
        #expect(ScriptureReferenceFormatter.parse("Psalm 46:10", in: work("bible")) == PassageReference(book: "PSA", chapter: 46, firstVerse: 10))
        #expect(ScriptureReferenceFormatter.parse("Philippians 4:6–7", in: work("bible")) == PassageReference(book: "PHI", chapter: 4, firstVerse: 6, lastVerse: 7))
        #expect(ScriptureReferenceFormatter.parse("94:5–6", in: work("quran")) == PassageReference(book: "QUR", chapter: 94, firstVerse: 5, lastVerse: 6))
        #expect(ScriptureReferenceFormatter.parse("2.47", in: work("bhagavad-gita")) == PassageReference(book: "BG", chapter: 2, firstVerse: 47))
        #expect(ScriptureReferenceFormatter.parse("Hezekiah 1:1", in: work("bible")) == nil)
        #expect(ScriptureReferenceFormatter.parse("94:6–5", in: work("quran")) == nil)
    }

    /// The catalog may only quote a bundled edition exactly (or, when the citation says so,
    /// a phrase from within the verse).
    @Test func catalogQuotationsMatchTheEditions() async throws {
        let catalog = try ContentCatalog.bundled()
        var checked = 0
        for item in catalog.items {
            for segment in item.segments where segment.role == .sourceText {
                guard let citation = segment.citation, let editionID = citation.edition,
                      let edition = manifest.edition(editionID), let reference = citation.reference,
                      let parsed = ScriptureReferenceFormatter.parse(reference, in: work(edition.work)) else { continue }
                let expected = try await library.passage(editionID, parsed).map(\.text).joined(separator: " ")
                let quoted = segment.original?.text ?? segment.text?.resolved(for: ["en"]) ?? ""
                if citation.note?.contains("Phrase from the verse") == true {
                    #expect(expected.contains(quoted) && !quoted.isEmpty, "\(item.id)")
                } else {
                    #expect(quoted == expected, "\(item.id) does not quote \(editionID) exactly")
                }
                checked += 1
            }
        }
        #expect(checked >= 7)
    }
}

@Suite("Reading state and reminders")
struct ReadingStateTests {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test func readingStateRoundTripsAndToleratesDamage() throws {
        var state = ReadingState()
        state.positions["bible"] = ScriptureLocation(work: "bible", book: "PSA", chapter: 23)
        state.layouts["quran"] = .parallel
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(ReadingState.self, from: data) == state)
        let damaged = Data(#"{"positions": 7, "layouts": {"quran": "parallel"}}"#.utf8)
        let decoded = try JSONDecoder().decode(ReadingState.self, from: damaged)
        #expect(decoded.positions.isEmpty)
        #expect(decoded.layouts["quran"] == .parallel)
    }

    @Test func remindersStartTodayOnlyIfTheTimeIsStillAhead() {
        let reminder = DailyVerseReminder(isEnabled: true, hour: 7, minute: 30)
        let early = utc.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 6))!
        let late = utc.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 8))!
        #expect(reminder.upcomingDays(from: early, calendar: utc, count: 2) == [
            CivilDate(year: 2026, month: 10, day: 11), CivilDate(year: 2026, month: 10, day: 12),
        ])
        #expect(reminder.upcomingDays(from: late, calendar: utc).first == CivilDate(year: 2026, month: 10, day: 12))
        #expect(reminder.upcomingDays(from: late, calendar: utc).count == DailyVerseReminder.daysScheduledAhead)
        #expect(DailyVerseReminder().upcomingDays(from: early, calendar: utc).isEmpty)
    }

    @Test func reminderTimeIsClamped() {
        let reminder = DailyVerseReminder(isEnabled: true, hour: 31, minute: -4)
        #expect(reminder.hour == 23 && reminder.minute == 0)
        #expect(reminder.fireComponents(for: CivilDate(year: 2026, month: 1, day: 2)).hour == 23)
    }
}
