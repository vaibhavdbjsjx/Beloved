import Foundation
import PLContent
import PLFaith

/// Validation stage: turns an untrusted model draft into provenance-labelled segments.
///
/// Guarantees, independent of model behaviour:
/// - Source/traditional text shown to users is always the *library's* verified copy,
///   inserted by passage ID — the model's own wording of scripture is discarded.
/// - Generated segments may not cite references outside the retrieved passages, and
///   may not contain long quotations (which could be fabricated scripture).
/// - Paraphrases without a valid source become "devotional interpretation".
public struct ResponseValidator: Sendable {
    /// Quoted spans at least this many words long are treated as attempted quotations.
    public var maxQuotedWords = 6

    public init() {}

    public struct Result: Hashable, Sendable {
        public var segments: [ContentSegment]
        public var removedCount: Int
    }

    public func validate(_ draft: GenerationDraft, passages: [RetrievedPassage]) -> Result {
        let byID = Dictionary(passages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let allowedReferences = Set(passages.compactMap { CatalogSourceRetriever.normalize($0.segment.citation?.reference) })
            .subtracting([""])

        var segments: [ContentSegment] = []
        var removed = 0

        for segment in draft.segments {
            switch segment.role {
            case .sourceText, .traditionalText:
                // Only accept quotations by reference; substitute the verified text.
                guard let id = segment.passageID, let passage = byID[id] else {
                    removed += 1
                    continue
                }
                segments.append(passage.segment)

            case .paraphrase:
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, isClean(text, allowedReferences: allowedReferences) else {
                    removed += 1
                    continue
                }
                if let id = segment.passageID, let citation = byID[id]?.segment.citation {
                    segments.append(ContentSegment(role: .paraphrase, text: LocalizedText(english: text), citation: citation))
                } else {
                    segments.append(ContentSegment(role: .devotionalInterpretation, text: LocalizedText(english: text)))
                }

            case .generatedPrayer, .explanation, .devotionalInterpretation, .composedPrayer:
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, isClean(text, allowedReferences: allowedReferences) else {
                    removed += 1
                    continue
                }
                // A model can never claim human authorship.
                let role: SegmentRole = segment.role == .composedPrayer ? .generatedPrayer : segment.role
                segments.append(ContentSegment(
                    role: role,
                    text: LocalizedText(english: text),
                    author: role == .generatedPrayer ? "AI-generated" : nil
                ))
            }
        }
        return Result(segments: segments, removedCount: removed)
    }

    /// No references outside the retrieved set, and no long quotations.
    func isClean(_ text: String, allowedReferences: Set<String>) -> Bool {
        for match in text.matches(of: Self.referencePattern) {
            let reference = CatalogSourceRetriever.normalize(String(match.output))
            if !allowedReferences.contains(where: { $0.hasSuffix(reference) || reference.hasSuffix($0) }) {
                return false
            }
        }
        for match in text.matches(of: Self.quotationPattern) {
            let words = match.output.split(whereSeparator: \.isWhitespace).count
            if words >= maxQuotedWords { return false }
        }
        return true
    }

    nonisolated(unsafe) static let referencePattern = /\d{1,3}:\d{1,3}(?:[–-]\d{1,3})?/
    nonisolated(unsafe) static let quotationPattern = /["“«][^"”»]+["”»]/
}
