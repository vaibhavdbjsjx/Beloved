import Foundation

/// A faith and its internal structure.
///
/// The model deliberately does NOT assume every faith shares Christianity's shape:
/// - `traditions` uses a faith-specific label ("Denomination", "School", "Sampradaya").
/// - `focuses` (deity / divine aspect) is optional — Islam has none by design (tawhid),
///   Hinduism has many, and the UI hides the step when a faith has no focuses.
/// - `practices` lists the practice kinds that are meaningful *in that faith*
///   (dua and dhikr for Islam, mantra and stotra for Hinduism, …).
public struct Faith: Codable, Identifiable, Hashable, Sendable {
    public var id: FaithID
    public var name: LocalizedText
    public var summary: LocalizedText
    /// What this faith calls a sub-tradition, e.g. "Denomination" or "Tradition / sampradaya".
    public var traditionLabel: LocalizedText
    public var traditions: [Tradition]
    /// What this faith calls a devotional focus, or `nil` when the concept does not apply.
    public var focusLabel: LocalizedText?
    public var focuses: [SpiritualFocus]
    public var practices: [PracticeKind]
    public var sources: [SourceWork]
    /// Editorial notes for reviewers (not shown to users).
    public var reviewNotes: String?

    public init(
        id: FaithID,
        name: LocalizedText,
        summary: LocalizedText,
        traditionLabel: LocalizedText,
        traditions: [Tradition],
        focusLabel: LocalizedText?,
        focuses: [SpiritualFocus],
        practices: [PracticeKind],
        sources: [SourceWork],
        reviewNotes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.traditionLabel = traditionLabel
        self.traditions = traditions
        self.focusLabel = focusLabel
        self.focuses = focuses
        self.practices = practices
        self.sources = sources
        self.reviewNotes = reviewNotes
    }

    public var usesSpiritualFocus: Bool { focusLabel != nil && !focuses.isEmpty }
}

/// A denomination, school, sect, or sampradaya within a faith.
public struct Tradition: Codable, Identifiable, Hashable, Sendable {
    public var id: TraditionID
    public var name: LocalizedText
    public var summary: LocalizedText?

    public init(id: TraditionID, name: LocalizedText, summary: LocalizedText? = nil) {
        self.id = id
        self.name = name
        self.summary = summary
    }
}

/// A deity, divine aspect, or devotional focus (only for faiths that use the concept).
public struct SpiritualFocus: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case deity
        case divineAspect
        case general
    }

    public var id: FocusID
    public var name: LocalizedText
    public var kind: Kind
    public var alsoKnownAs: [String]

    public init(id: FocusID, name: LocalizedText, kind: Kind, alsoKnownAs: [String] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.alsoKnownAs = alsoKnownAs
    }
}

/// A kind of spiritual practice. Faiths declare which kinds are meaningful to them.
public enum PracticeKind: String, Codable, CaseIterable, Sendable {
    case prayer
    case scripture
    case mantra
    case stotra
    case dua
    case dhikr
    case reflection
    case gratitude
    case intention
    case silence
}
