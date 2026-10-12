import Foundation
@testable import PLAssistant
import PLCalendar
import PLContent
import PLFaith
import Testing

private let registry = try! FaithRegistry.bundled()
private let catalog = try! ContentCatalog.bundled()
private let selector = ContentSelector(catalog: catalog, registry: registry, policy: .development)
private let parser = IntentParser(registry: registry, taxonomy: catalog.taxonomy)
private let resolver = FaithContextResolver(calendar: try! ReligiousCalendar.bundled(), associations: try! DevotionalAssociations.bundled())

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

/// 2026-10-01 is a Thursday.
private let thursday = ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!

private func request(_ text: String, profile: SpiritualProfile = SpiritualProfile()) -> AssistantRequest {
    AssistantRequest(text: text, profile: profile, date: thursday, calendar: utc)
}

private func pipeline(generator: any GenerationProvider = UnconfiguredGenerationProvider()) -> AssistantPipeline {
    AssistantPipeline(parser: parser, contextResolver: resolver, retriever: CatalogSourceRetriever(selector: selector),
                      generator: generator, region: "US")
}

/// Test double standing in for a future server-side model.
private struct ScriptedGenerator: GenerationProvider {
    let draft: @Sendable (GenerationPrompt) -> GenerationDraft
    func generate(_ prompt: GenerationPrompt) async throws -> GenerationDraft { draft(prompt) }
}

@Suite struct SafetyRouterTests {
    let router = LocalSafetyRouter()

    @Test(arguments: ["I want to end my life", "I feel suicidal tonight", "I keep wanting to hurt myself"])
    func crisisLanguageRoutesToSupport(text: String) {
        #expect(router.classify(text) == .crisis(.selfHarm))
    }

    @Test func abuseRoutesToSupport() {
        #expect(router.classify("My partner hits me and I am unsafe at home") == .crisis(.abuse))
    }

    @Test(arguments: [
        "Give me a short prayer for anxiety",
        "They mock my faith at work, give me strength",
        "A prayer for my mother's healing before surgery",
        "Help me forgive an insult",
    ])
    func sincereRequestsProceed(text: String) {
        #expect(router.classify(text) == .proceed)
    }

    @Test func medicalAdviceGetsDisclaimer() {
        #expect(router.classify("Should I stop taking my medication and just pray?") == .proceedWithMedicalDisclaimer)
    }
}

@Suite struct IntentParserTests {
    @Test func quranBasedDuaForPatience() {
        let intent = parser.parse("Give me a Quran-based dua for patience.")
        #expect(intent.faith == "islam")
        #expect(intent.practice == .dua)
        #expect(intent.themes.contains("patience"))
    }

    @Test func shivaMantraForMonday() {
        let intent = parser.parse("Give me a Shiva mantra for Monday")
        #expect(intent.faith == "hinduism")
        #expect(intent.focus == "hinduism.shiva")
        #expect(intent.practice == .mantra)
        #expect(intent.isoWeekday == 1)
    }

    @Test func christianPrayerForToday() {
        let intent = parser.parse("Give me a Christian prayer for today.")
        #expect(intent.faith == "christianity")
        #expect(intent.practice == .prayer)
    }

    @Test func anxietyMapsToMoodAndThemes() {
        let intent = parser.parse("Give me a short prayer for anxiety.")
        #expect(intent.mood == .anxious)
        #expect(intent.themes.contains("peace"))
        #expect(intent.faith == nil)
    }

    @Test func explainVerse() {
        let intent = parser.parse("Explain Psalm 46:10")
        #expect(intent.wantsExplanation)
        #expect(intent.reference == "Psalm 46:10")
        #expect(intent.faith == "christianity")
    }
}

@Suite struct ResponseValidatorTests {
    let passages = CatalogSourceRetriever(selector: selector).passages(in: catalog.item("christianity.psalm-46-10")!)
    let validator = ResponseValidator()

    @Test func modelWrittenScriptureIsDiscarded() {
        let draft = GenerationDraft(segments: [GenerationDraft.Segment(role: .sourceText, text: "Be still and know that I am the Lord.")])
        let result = validator.validate(draft, passages: passages)
        #expect(result.segments.isEmpty)
        #expect(result.removedCount == 1)
    }

    @Test func quotationsByPassageIDUseVerifiedLibraryText() throws {
        let id = try #require(passages.first?.id)
        let draft = GenerationDraft(segments: [GenerationDraft.Segment(role: .sourceText, text: "garbled model copy", passageID: id)])
        let result = validator.validate(draft, passages: passages)
        #expect(result.segments == [passages[0].segment])
    }

    @Test func generatedTextCannotCiteUnretrievedReferences() {
        let draft = GenerationDraft(segments: [
            GenerationDraft.Segment(role: .generatedPrayer, text: "As John 3:16 says, You love us. Amen."),
            GenerationDraft.Segment(role: .explanation, text: "Psalm 46:10 invites stillness."),
        ])
        let result = validator.validate(draft, passages: passages)
        #expect(result.removedCount == 1)
        #expect(result.segments.map(\.role) == [.explanation])
    }

    @Test func longQuotationsInGeneratedTextAreRemoved() {
        let draft = GenerationDraft(segments: [
            GenerationDraft.Segment(role: .generatedPrayer, text: "Remember: “the Lord will always carry every burden you have” Amen."),
        ])
        #expect(validator.validate(draft, passages: passages).removedCount == 1)
    }

    @Test func modelCannotClaimHumanAuthorshipOrUncitedParaphrase() {
        let draft = GenerationDraft(segments: [
            GenerationDraft.Segment(role: .composedPrayer, text: "God, give me peace. Amen."),
            GenerationDraft.Segment(role: .paraphrase, text: "Be calm and trust."),
        ])
        let result = validator.validate(draft, passages: passages)
        #expect(result.segments.map(\.role) == [.generatedPrayer, .devotionalInterpretation])
        #expect(result.segments.first?.author == "AI-generated")
    }
}

@Suite struct AssistantPipelineTests {
    @Test func crisisNeverReachesGeneration() async {
        let response = await pipeline(generator: ScriptedGenerator { _ in
            Issue.record("generator must not be called")
            return GenerationDraft(segments: [])
        }).respond(to: request("I want to end my life"))
        #expect(response.kind == .crisisSupport)
        guard case let .crisisSupport(resources) = response.notices.first else {
            Issue.record("missing crisis resources")
            return
        }
        #expect(resources.contains { $0.contact.contains("988") })
        #expect(resources.contains { $0.region == nil })
    }

    @Test func withoutBackendAnswersFromVerifiedLibraryAndSaysSo() async throws {
        let response = await pipeline().respond(to: request("Give me a Shiva mantra for Monday"))
        #expect(response.kind == .libraryOnly)
        #expect(response.notices.contains(.generationUnavailable))
        let first = try #require(response.segments.first)
        // Verbatim, sourced text (now the verified Mahamrityunjaya, Rigveda 7.59.12).
        #expect(first.role.claimsSourceFidelity)
        #expect(response.notices.contains { if case .devotionalContext = $0 { true } else { false } },
                "the Monday–Shiva custom must be explained, not asserted")
    }

    @Test func respectsRequestedFaith() async throws {
        // A Christian user explicitly asking for a Quran-based dua gets Islamic content.
        let response = await pipeline().respond(to: request("Give me a Quran-based dua for patience",
                                                            profile: SpiritualProfile(faithID: "christianity")))
        #expect(response.intent?.faith == "islam")
        let islamicItems = catalog.items.filter { $0.faith == "islam" && $0.kind == .dua }
        #expect(islamicItems.contains { $0.segments == response.segments })
    }

    @Test func composedResponsesAreValidated() async {
        let response = await pipeline(generator: ScriptedGenerator { prompt in
            GenerationDraft(segments: [
                .init(role: .sourceText, text: "ignored", passageID: prompt.passages.first?.id),
                .init(role: .generatedPrayer, text: "Lord, quiet my heart. Amen."),
                .init(role: .sourceText, text: "Invented verse with no id."),
            ])
        }).respond(to: request("Give me a short Christian prayer for anxiety", profile: SpiritualProfile(faithID: "christianity")))
        #expect(response.kind == .composed)
        #expect(response.segments.map(\.role) == [.sourceText, .generatedPrayer])
        #expect(response.notices.contains(.removedUnverifiedContent(1)))
    }

    @Test func promptIsMinimised() async throws {
        let profile = SpiritualProfile(faithID: "christianity", displayName: "Sensitive Name")
        final class Capture: @unchecked Sendable { var prompt: GenerationPrompt? }
        let capture = Capture()
        let generator = ScriptedGenerator { prompt in
            capture.prompt = prompt
            return GenerationDraft(segments: [])
        }
        _ = await pipeline(generator: generator).respond(to: request("A prayer for peace", profile: profile))
        let json = String(decoding: try JSONEncoder().encode(try #require(capture.prompt)), as: UTF8.self)
        #expect(!json.contains("Sensitive Name"))
    }
}
