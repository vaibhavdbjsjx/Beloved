import Foundation
import PLContent
import PLFaith

public enum GenerationError: Error, Equatable, Sendable {
    /// No generation backend is configured for this build.
    case notConfigured
    case unavailable(String)
    case malformedOutput
}

/// The *minimum* information that may leave the device for generation.
/// No name, no history, no journal, no device identifiers.
public struct GenerationPrompt: Codable, Hashable, Sendable {
    public struct Passage: Codable, Hashable, Sendable {
        public var id: String
        public var role: SegmentRole
        public var reference: String?
        public var text: String
    }

    public var requestText: String
    public var faith: FaithID?
    public var tradition: TraditionID?
    public var focus: FocusID?
    public var mood: Mood?
    public var language: String
    public var devotionalNotes: [String]
    public var passages: [Passage]
    public var rules: String
}

/// Generation stage. Implementations call a server-side proxy; API keys never ship in the app.
public protocol GenerationProvider: Sendable {
    func generate(_ prompt: GenerationPrompt) async throws -> GenerationDraft
}

/// Phase 1 default: there is no backend yet, and the pipeline falls back to
/// library-only answers. This is reported to the user, never hidden.
public struct UnconfiguredGenerationProvider: GenerationProvider {
    public init() {}
    public func generate(_ prompt: GenerationPrompt) async throws -> GenerationDraft {
        throw GenerationError.notConfigured
    }
}

public enum PromptBuilder {
    /// Non-negotiable rules sent with every generation request. The validator enforces
    /// them independently — the model is never trusted to follow them.
    public static let rules = """
    You help people pray and reflect within their own faith tradition.
    1. Never write scripture, Quran, hadith, mantra, or any attributed religious text yourself. To include one, \
    reference a provided passage by its id in `passageID`; the app inserts the verified text.
    2. Do not cite chapter/verse/surah/ayah references other than those of the provided passages.
    3. Label every segment's role: generatedPrayer (a prayer you wrote), explanation, devotionalInterpretation, \
    or sourceText/traditionalText (only with passageID).
    4. Stay within the requested faith and tradition. Do not compare faiths or declare doctrine; when traditions \
    differ, say so plainly.
    5. Weekday or devotional customs are customs, not universal rules — describe them that way.
    6. You are not a doctor or therapist. Never diagnose or advise on medication or treatment.
    7. Keep prayers short, warm, and respectful. Output JSON matching the GenerationDraft schema.
    """

    public static func prompt(
        request: AssistantRequest,
        intent: AssistantIntent,
        context: FaithContext,
        passages: [RetrievedPassage]
    ) -> GenerationPrompt {
        GenerationPrompt(
            requestText: request.text,
            faith: context.faith,
            tradition: context.tradition,
            focus: context.focus,
            // The mood is only shared when the user typed it or chose it for this request.
            mood: intent.mood ?? request.mood,
            language: request.profile.languages.first ?? "en",
            devotionalNotes: context.devotionalNotes,
            passages: passages.map {
                GenerationPrompt.Passage(
                    id: $0.id,
                    role: $0.segment.role,
                    reference: $0.segment.citation?.reference,
                    text: $0.segment.text?.resolved(for: request.profile.languages)
                        ?? $0.segment.original?.text ?? ""
                )
            },
            rules: rules
        )
    }
}
