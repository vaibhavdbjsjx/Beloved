import Foundation
@testable import PLCompanion
import PLContent
import PLFaith
import PLScripture
import Testing

private let library = try! ScriptureLibrary()
private let registry = try! FaithRegistry.bundled()
private let catalog = try! ContentCatalog.bundled()

private func resolver(_ policy: ScripturePolicy = .development, content: ContentPolicy = .development) -> CompanionResolver {
    CompanionResolver(library: library, scripturePolicy: policy, catalog: catalog, contentPolicy: content, registry: registry)
}

@Suite("Markers")
struct MarkupTests {
    @Test func splitsProseAndMarkers() {
        let blocks = CompanionMarkup.blocks(from: "Rest in this: ⟦bible:PSA 46:10⟧ And pray ⟦prayer:christianity.prayer.anxious⟧.")
        #expect(blocks.count == 5)
        #expect(blocks[0] == .text("Rest in this: "))
        #expect(blocks[1] == .marker(CompanionMarker(raw: "bible:PSA 46:10")))
        #expect(CompanionMarker(raw: "bible:PSA 46:10").kind == .scripture(work: "bible", reference: "PSA 46:10"))
        #expect(CompanionMarker(raw: "gita:2:47").kind == .scripture(work: "bhagavad-gita", reference: "2:47"))
        #expect(CompanionMarker(raw: "Quran: 94:5-6").kind == .scripture(work: "quran", reference: "94:5-6"))
        #expect(CompanionMarker(raw: "mantra:hinduism.mantra.gayatri").kind == .prayer(id: "hinduism.mantra.gayatri"))
        #expect(CompanionMarker(raw: "hadith:bukhari 1").kind == .unknown)
    }

    @Test func holdsBackAHalfStreamedMarker() {
        let streaming = CompanionMarkup.blocks(from: "Here is a verse: ⟦bible:PS", isComplete: false)
        #expect(streaming == [.text("Here is a verse: ")])
        let done = CompanionMarkup.blocks(from: "Broken ⟦bible:PS", isComplete: true)
        #expect(done == [.text("Broken ⟦bible:PS")])
    }
}

@Suite("Resolving markers to verified text")
struct ResolverTests {
    @Test func bibleByCodeOrName() async throws {
        for raw in ["bible:PSA 46:10", "bible:Psalm 46:10", "bible:psalms 46:10"] {
            let block = await resolver().resolve(CompanionMarker(raw: raw))
            guard case let .passage(passage) = block else { Issue.record("\(raw) → \(block)"); continue }
            #expect(passage.translationText?.hasPrefix("“Be still, and know that I am God.") == true)
            #expect(passage.originalText == nil, "Hebrew numbers this verse differently")
        }
    }

    @Test func quranHasArabicAndEnglish() async throws {
        let block = await resolver().resolve(CompanionMarker(raw: "quran:94:5-6"))
        guard case let .passage(passage) = block else { Issue.record("\(block)"); return }
        #expect(passage.originalEdition?.id == "quran.ar")
        #expect(passage.translationText?.contains("ease") == true)
    }

    @Test func gitaIsSanskritWithTransliteration() async throws {
        let block = await resolver().resolve(CompanionMarker(raw: "gita:2.47"))
        guard case let .passage(passage) = block else { Issue.record("\(block)"); return }
        #expect(passage.originalText?.hasPrefix("कर्मण्येवाधिकारस्ते") == true)
        #expect(passage.transliterationText?.hasPrefix("karmaṇyevādhikāraste") == true)
        #expect(passage.translationText == nil, "Arnold doesn't number verses; the model explains in its own words")
    }

    @Test func prayersComeFromTheCatalog() async {
        let block = await resolver().resolve(CompanionMarker(raw: "prayer:hinduism.mantra.gayatri"))
        guard case let .prayer(item) = block else { Issue.record("\(block)"); return }
        #expect(item.id == "hinduism.mantra.gayatri")
    }

    @Test func anythingUnverifiableBecomesAPlainReference() async {
        #expect(await resolver().resolve(CompanionMarker(raw: "bible:Hezekiah 1:1")) == .reference("Hezekiah 1:1"))
        #expect(await resolver().resolve(CompanionMarker(raw: "quran:115:1")) == .reference("Quran 115:1"))
        #expect(await resolver().resolve(CompanionMarker(raw: "bible:PSA 119:1-176")) == .reference("PSA 119:1-176"), "too long to quote")
        #expect(await resolver().resolve(CompanionMarker(raw: "prayer:made.up")) == .reference("made.up"))
        #expect(await resolver().resolve(CompanionMarker(raw: "hadith:bukhari 1")) == .reference("hadith:bukhari 1"))
    }

    @Test func releaseBuildsQuoteOnlyApprovedTexts() async {
        let release = resolver(.release, content: .release)
        #expect(await release.resolve(CompanionMarker(raw: "bible:PSA 46:10")) == .reference("PSA 46:10"))
        #expect(await release.resolve(CompanionMarker(raw: "prayer:hinduism.mantra.gayatri")) == .reference("Gayatri Mantra"))
    }

    @Test func wholeAnswersResolveInOrder() async {
        let blocks = CompanionMarkup.blocks(from: "Breathe. ⟦quran:94:5⟧ You are not alone.")
        let resolved = await resolver().resolve(blocks)
        #expect(resolved.count == 3)
        if case .passage = resolved[1] {} else { Issue.record("expected a passage") }
    }
}

@Suite("Requests and streaming")
struct TransportTests {
    private var context: CompanionContext {
        var profile = SpiritualProfile()
        profile.faithID = "hinduism"
        return CompanionContext.make(profile: profile, registry: registry, catalog: catalog, policy: .development, scripture: ["bhagavad-gita"])
    }

    @Test func contextCarriesOnlyTheUsersTradition() {
        let ids = context.library.map(\.id)
        #expect(ids.contains("hinduism.mantra.gayatri"))
        #expect(!ids.contains { $0.hasPrefix("islam.") || $0.hasPrefix("christianity.") })
        #expect(context.faith == "hinduism")
    }

    @Test func requestsAreTrimmedAndStartWithTheUser() {
        var messages = [CompanionMessage(role: .assistant, text: "Welcome")]
        for index in 0..<40 {
            messages.append(CompanionMessage(role: index.isMultiple(of: 2) ? .user : .assistant, text: String(repeating: "a", count: 5_000)))
        }
        let request = CompanionRequest(conversation: messages, context: context)
        #expect(request.messages.count <= CompanionRequest.maximumTurns)
        #expect(request.messages.first?.role == .user)
        #expect(request.messages.allSatisfy { $0.text.count <= CompanionRequest.maximumCharactersPerTurn })
    }

    @Test func onlyTheUserAndTheCompanionReachTheModel() throws {
        let messages = [
            CompanionMessage(role: .user, text: "I want to hurt myself"),
            CompanionMessage(role: .assistant, origin: .support, text: "Please call…"),
            CompanionMessage(role: .user, text: "A prayer for peace"),
            CompanionMessage(role: .assistant, origin: .library, text: "⟦prayer:x⟧"),
            CompanionMessage(role: .user, text: "Tell me more"),
        ]
        let request = CompanionRequest(conversation: messages, context: context)
        #expect(request.messages.map(\.text) == ["Tell me more"], "consecutive user turns collapse to the latest")
        let old = Data(#"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","role":"user","text":"hi","date":0}"#.utf8)
        #expect(try JSONDecoder().decode(CompanionMessage.self, from: old).origin == .companion)
    }

    @Test func parsesTheEventStream() {
        var parser = CompanionStreamParser()
        #expect(parser.consume(line: #"data: {"type":"delta","text":"Peace "}"#) == [.delta("Peace ")])
        #expect(parser.consume(line: "") == [])
        #expect(parser.consume(line: ": keep-alive") == [])
        #expect(parser.consume(line: #"data: {"type":"error","code":"limit"}"#) == [.failure(.dailyLimitReached)])
        #expect(parser.consume(line: #"data: {"type":"done"}"#) == [.done])
    }

    @Test func unconfiguredTransportSaysSo() async {
        var thrown: Error?
        do {
            for try await _ in UnavailableCompanionTransport().reply(to: CompanionRequest(conversation: [], context: context)) {}
        } catch { thrown = error }
        #expect(thrown as? CompanionError == .notConfigured)
    }
}
