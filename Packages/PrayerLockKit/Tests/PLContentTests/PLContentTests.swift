import Foundation
@testable import PLContent
import PLFaith
import Testing

private let registry = try! FaithRegistry.bundled()
private let catalog = try! ContentCatalog.bundled()

private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private func draftItem(
    id: ContentItemID = "test.item",
    faith: FaithID? = "christianity",
    traditions: [TraditionID] = [],
    focuses: [FocusID] = [],
    kind: PracticeKind = .prayer,
    segments: [ContentSegment] = [ContentSegment(role: .composedPrayer, text: "Amen.", author: "Editor")],
    themes: [ThemeID] = [],
    moods: [Mood] = [],
    occasions: [OccasionID] = [],
    isPremium: Bool = false,
    status: ReviewInfo.Status = .approved
) -> ContentItem {
    ContentItem(
        id: id, faith: faith, traditions: traditions, focuses: focuses, kind: kind, title: "Test",
        segments: segments, themes: themes, moods: moods, occasions: occasions,
        isPremium: isPremium, review: ReviewInfo(status: status)
    )
}

@Suite struct CatalogValidationTests {
    @Test func bundledCatalogHasNoStructuralErrors() {
        let issues = CatalogValidator(registry: registry).validate(catalog)
        #expect(issues.errors.isEmpty, "\(issues.errors)")
    }

    @Test func bundledFixturesAreAllFlaggedAsUnapproved() {
        // Phase 1 ships development fixtures only — none may claim to be reviewed.
        #expect(catalog.items.allSatisfy { $0.review.status == .draft })
        #expect(!catalog.items.isEmpty)
    }

    @Test func everyMoodMapsToThemes() {
        for mood in Mood.allCases {
            #expect(!catalog.taxonomy.themes(for: mood).isEmpty, "\(mood)")
        }
    }

    @Test func catalogCoversEveryFaithAndFaithNeutralUsers() {
        let faiths = Set(catalog.items.map(\.faith))
        #expect(faiths == [nil, "christianity", "islam", "hinduism"])
    }

    @Test func rejectsAIGeneratedTextInCatalog() {
        let bad = draftItem(segments: [ContentSegment(role: .generatedPrayer, text: "A prayer.")])
        let issues = CatalogValidator(registry: registry).validate(ContentCatalog(items: [bad], taxonomy: catalog.taxonomy))
        #expect(issues.errors.contains { $0.message.contains("AI-generated") })
    }

    @Test func rejectsQuotationWithoutEditionOrReference() {
        let noEdition = draftItem(id: "a", kind: .scripture, segments: [
            ContentSegment(role: .sourceText, text: "Words.", citation: SourceCitation(source: "bible", reference: "Psalm 1:1")),
        ])
        let noCitation = draftItem(id: "b", kind: .scripture, segments: [ContentSegment(role: .sourceText, text: "Words.")])
        let wrongEdition = draftItem(id: "c", kind: .scripture, segments: [
            ContentSegment(role: .sourceText, text: "Words.", citation: SourceCitation(source: "bible", edition: "quran.ar", reference: "1:1")),
        ])
        let issues = CatalogValidator(registry: registry)
            .validate(ContentCatalog(items: [noEdition, noCitation, wrongEdition], taxonomy: catalog.taxonomy))
        #expect(Set(issues.errors.compactMap(\.itemID)) == ["a", "b", "c"])
    }

    @Test func rejectsCrossFaithTaxonomyAndAnonymousComposition() {
        let crossFaith = draftItem(id: "a", faith: "islam", focuses: ["hinduism.shiva"], kind: .dua)
        let wrongPractice = draftItem(id: "b", faith: "islam", kind: .mantra)
        let anonymous = draftItem(id: "c", segments: [ContentSegment(role: .composedPrayer, text: "Amen.")])
        let issues = CatalogValidator(registry: registry)
            .validate(ContentCatalog(items: [crossFaith, wrongPractice, anonymous], taxonomy: catalog.taxonomy))
        #expect(Set(issues.errors.compactMap(\.itemID)) == ["a", "b", "c"])
    }
}

@Suite struct ContentPolicyTests {
    @Test func releasePolicyBlocksDraftsAndUnclearedEditions() {
        #expect(!ContentPolicy.release.permits(draftItem(status: .draft), registry: registry))
        #expect(ContentPolicy.release.permits(draftItem(status: .approved), registry: registry))

        let rigveda = draftItem(faith: "hinduism", kind: .scripture, segments: [
            ContentSegment(role: .sourceText, original: OriginalText(text: "…", language: "sa"),
                           citation: SourceCitation(source: "rigveda", edition: "rigveda.sa", reference: "3.62.10")),
        ])
        #expect(!ContentPolicy.release.permits(rigveda, registry: registry), "rigveda.sa rights are pending clearance")
        #expect(ContentPolicy.development.permits(rigveda, registry: registry))
    }

    @Test func rejectedContentIsNeverShown() {
        #expect(!ContentPolicy.development.permits(draftItem(status: .rejected), registry: registry))
    }

    @Test func sourcesListOnlyEditionsQuotedByVisibleContent() {
        let bible = draftItem(id: "test.bible", kind: .scripture, segments: [
            ContentSegment(role: .sourceText, text: "Be still.",
                           citation: SourceCitation(source: "bible", edition: "bible.web", reference: "Psalm 46:10")),
        ])
        let rigveda = draftItem(id: "test.rigveda", faith: "hinduism", kind: .scripture, segments: [
            ContentSegment(role: .sourceText, original: OriginalText(text: "…", language: "sa"),
                           citation: SourceCitation(source: "rigveda", edition: "rigveda.sa", reference: "3.62.10")),
        ])
        let draft = draftItem(id: "test.draft", kind: .scripture, segments: bible.segments, status: .draft)
        let small = ContentCatalog(items: [bible, rigveda, draft], taxonomy: catalog.taxonomy)

        #expect(small.visibleItems(policy: .release, registry: registry).map(\.id) == ["test.bible"])
        #expect(small.citedEditions(policy: .release, registry: registry) == ["bible.web"])
        #expect(small.citedEditions(policy: .development, registry: registry) == ["bible.web", "rigveda.sa"])
    }
}

@Suite struct ContentSelectorTests {
    let selector = ContentSelector(catalog: catalog, registry: registry, policy: .development)
    let noon = date("2026-10-01T12:00:00Z")

    func context(_ profile: SpiritualProfile, mood: Mood? = nil, at time: Date? = nil, occasions: Set<OccasionID> = [],
                 devotional: Set<FocusID> = [], recent: [ContentItemID] = []) -> SelectionContext {
        SelectionContext(profile: profile, mood: mood, date: time ?? noon, calendar: utcCalendar,
                         activeOccasions: occasions, devotionalFocuses: devotional, recentlyShown: recent)
    }

    @Test func neverCrossesFaiths() {
        for faith in ["christianity", "islam", "hinduism"] as [FaithID] {
            let ranked = selector.rank(context(SpiritualProfile(faithID: faith)))
            #expect(!ranked.isEmpty)
            #expect(ranked.allSatisfy { $0.item.faith == faith || $0.item.faith == nil }, "\(faith)")
        }
    }

    @Test func usersWithoutAFaithGetOnlyFaithNeutralContent() {
        let ranked = selector.rank(context(SpiritualProfile()))
        #expect(!ranked.isEmpty)
        #expect(ranked.allSatisfy { $0.item.faith == nil })
    }

    @Test func faithSpecificContentOutranksNeutralFallback() throws {
        let best = try #require(selector.select(context(SpiritualProfile(faithID: "islam"))))
        #expect(best.item.faith == "islam")
    }

    @Test func moodShapesTheChoice() throws {
        let best = try #require(selector.select(context(SpiritualProfile(faithID: "christianity"), mood: .seekingForgiveness)))
        #expect(best.item.moods.contains(.seekingForgiveness) || best.item.themes.contains("forgiveness"))
        #expect(best.reasons.contains(.mood(.seekingForgiveness)))
    }

    @Test func respectsChosenFocusUnlessDevotionalAssociationApplies() {
        let shivaDevotee = SpiritualProfile(faithID: "hinduism", focusIDs: ["hinduism.shiva"])
        let ids = Set(selector.rank(context(shivaDevotee)).map(\.item.id))
        #expect(ids.contains("hinduism.mantra.panchakshara"))
        #expect(!ids.contains("hinduism.mantra.ganapati"))

        let withAssociation = Set(selector.rank(context(shivaDevotee, devotional: ["hinduism.ganesha"])).map(\.item.id))
        #expect(withAssociation.contains("hinduism.mantra.ganapati"))

        let noFocus = Set(selector.rank(context(SpiritualProfile(faithID: "hinduism"))).map(\.item.id))
        #expect(noFocus.contains("hinduism.mantra.ganapati") && noFocus.contains("hinduism.mantra.panchakshara"))
    }

    @Test func traditionSpecificContentOnlyForThatTradition() {
        let catholicOnly = draftItem(id: "catholic.only", traditions: ["christianity.catholic"])
        let custom = ContentSelector(catalog: ContentCatalog(items: [catholicOnly], taxonomy: catalog.taxonomy), registry: registry, policy: .development)
        #expect(custom.rank(context(SpiritualProfile(faithID: "christianity", traditionID: "christianity.catholic"))).count == 1)
        #expect(custom.rank(context(SpiritualProfile(faithID: "christianity", traditionID: "christianity.orthodox"))).isEmpty)
        #expect(custom.rank(context(SpiritualProfile(faithID: "christianity"))).isEmpty)
    }

    @Test func premiumContentRequiresEntitlement() {
        let premium = draftItem(id: "premium", isPremium: true)
        let custom = ContentSelector(catalog: ContentCatalog(items: [premium], taxonomy: catalog.taxonomy), registry: registry, policy: .development)
        var ctx = context(SpiritualProfile(faithID: "christianity"))
        #expect(custom.rank(ctx).isEmpty)
        ctx.hasPremium = true
        #expect(custom.rank(ctx).count == 1)
    }

    @Test func occasionBoostsSeasonalContent() throws {
        let best = try #require(selector.select(context(SpiritualProfile(faithID: "islam"), occasions: ["islam.ramadan"])))
        #expect(best.item.id == "islam.dua.ramadan")
    }

    @Test func deterministicWithinADayAndAvoidsRepeats() throws {
        let profile = SpiritualProfile(faithID: "hinduism")
        let first = try #require(selector.select(context(profile)))
        let again = try #require(selector.select(context(profile)))
        #expect(first.item.id == again.item.id)

        let next = try #require(selector.select(context(profile, recent: [first.item.id])))
        #expect(next.item.id != first.item.id)
    }

    @Test func timeOfDayBuckets() {
        #expect(TimeOfDay(date: date("2026-10-01T06:00:00Z"), calendar: utcCalendar) == .morning)
        #expect(TimeOfDay(date: date("2026-10-01T13:00:00Z"), calendar: utcCalendar) == .midday)
        #expect(TimeOfDay(date: date("2026-10-01T18:00:00Z"), calendar: utcCalendar) == .evening)
        #expect(TimeOfDay(date: date("2026-10-01T23:30:00Z"), calendar: utcCalendar) == .night)
    }
}
