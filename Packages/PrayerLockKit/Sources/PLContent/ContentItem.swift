import Foundation
import PLCore
import PLFaith

public enum ContentItemTag {}
public typealias ContentItemID = Identifier<ContentItemTag>

/// A unit of spiritual content shown in a prayer moment (a prayer, verse, mantra, dua…).
///
/// An item is made of `segments`, and **every segment carries its own provenance**.
/// A mantra card, for instance, is a `traditionalText` segment (Devanagari +
/// transliteration) followed by an `explanation` segment. The same segment model is
/// used for AI assistant answers, so verified scripture and generated text can never
/// be visually or structurally confused.
public struct ContentItem: Codable, Identifiable, Hashable, Sendable {
    public var id: ContentItemID
    /// `nil` = faith-neutral (breathing, intention, gratitude) — offered to everyone.
    public var faith: FaithID?
    /// Empty = suitable for every tradition of `faith`.
    public var traditions: [TraditionID]
    /// Empty = not specific to a deity/focus.
    public var focuses: [FocusID]
    public var kind: PracticeKind
    public var title: LocalizedText
    public var segments: [ContentSegment]
    public var themes: [ThemeID]
    public var moods: [Mood]
    /// Empty = any time of day.
    public var timesOfDay: [TimeOfDay]
    public var occasions: [OccasionID]
    public var length: ContentLength
    public var isPremium: Bool
    public var review: ReviewInfo

    public init(
        id: ContentItemID,
        faith: FaithID?,
        traditions: [TraditionID] = [],
        focuses: [FocusID] = [],
        kind: PracticeKind,
        title: LocalizedText,
        segments: [ContentSegment],
        themes: [ThemeID] = [],
        moods: [Mood] = [],
        timesOfDay: [TimeOfDay] = [],
        occasions: [OccasionID] = [],
        length: ContentLength = .brief,
        isPremium: Bool = false,
        review: ReviewInfo
    ) {
        self.id = id
        self.faith = faith
        self.traditions = traditions
        self.focuses = focuses
        self.kind = kind
        self.title = title
        self.segments = segments
        self.themes = themes
        self.moods = moods
        self.timesOfDay = timesOfDay
        self.occasions = occasions
        self.length = length
        self.isPremium = isPremium
        self.review = review
    }
}

/// What a piece of text *is*. This distinction is shown to users and enforced by validators.
public enum SegmentRole: String, Codable, CaseIterable, Sendable {
    /// Verbatim text from a cited, rights-cleared edition (scripture, canonical prayer).
    case sourceText
    /// A traditional recitation (mantra, dhikr, liturgical prayer) in its customary form,
    /// optionally citing where it originates.
    case traditionalText
    /// A restatement of a cited source in other words — never presented as a quotation.
    case paraphrase
    /// A prayer written by a named human author/editor.
    case composedPrayer
    /// A prayer written by the AI assistant. Never stored in the curated catalog.
    case generatedPrayer
    /// Meaning, context, or translation notes.
    case explanation
    /// A devotional reading or reflection on a source — interpretation, not doctrine.
    case devotionalInterpretation

    /// Roles whose text claims to reproduce an existing source.
    public var claimsSourceFidelity: Bool { self == .sourceText || self == .traditionalText }

    /// Roles that must cite a source.
    public var requiresCitation: Bool { self == .sourceText || self == .paraphrase }
}

public struct ContentSegment: Codable, Hashable, Sendable {
    public var role: SegmentRole
    /// Display text in the user's language (translation, composition, explanation).
    public var text: LocalizedText?
    /// Text in its original language/script (Arabic, Sanskrit, Greek, …).
    public var original: OriginalText?
    public var transliteration: String?
    public var citation: SourceCitation?
    /// Required for `composedPrayer`.
    public var author: String?

    public init(
        role: SegmentRole,
        text: LocalizedText? = nil,
        original: OriginalText? = nil,
        transliteration: String? = nil,
        citation: SourceCitation? = nil,
        author: String? = nil
    ) {
        self.role = role
        self.text = text
        self.original = original
        self.transliteration = transliteration
        self.citation = citation
        self.author = author
    }

    public var hasDisplayableText: Bool {
        !(text?.isEmpty ?? true) || !(original?.text.isEmpty ?? true)
    }
}

public struct OriginalText: Codable, Hashable, Sendable {
    public var text: String
    /// BCP-47 language, e.g. `ar`, `sa`, `he`, `grc`.
    public var language: String
    /// ISO 15924 script, e.g. `Arab`, `Deva`.
    public var script: String?

    public init(text: String, language: String, script: String? = nil) {
        self.text = text
        self.language = language
        self.script = script
    }
}

public struct SourceCitation: Codable, Hashable, Sendable {
    public var source: SourceWorkID
    /// Required for `sourceText` (which exact edition the words come from).
    public var edition: EditionID?
    /// Human-readable reference in the source's scheme, e.g. "Psalm 46:10", "94:5–6", "3.62.10".
    public var reference: String?
    public var note: String?

    public init(source: SourceWorkID, edition: EditionID? = nil, reference: String? = nil, note: String? = nil) {
        self.source = source
        self.edition = edition
        self.reference = reference
        self.note = note
    }
}

/// Editorial review state. Release builds only show `approved` content.
public struct ReviewInfo: Codable, Hashable, Sendable {
    public enum Status: String, Codable, Comparable, Sendable {
        case draft
        case inReview
        case approved
        case rejected

        private var rank: Int {
            switch self {
            case .rejected: 0
            case .draft: 1
            case .inReview: 2
            case .approved: 3
            }
        }

        public static func < (lhs: Status, rhs: Status) -> Bool { lhs.rank < rhs.rank }
    }

    public var status: Status
    public var reviewer: String?
    public var reviewedOn: CivilDate?
    public var notes: String?

    public init(status: Status, reviewer: String? = nil, reviewedOn: CivilDate? = nil, notes: String? = nil) {
        self.status = status
        self.reviewer = reviewer
        self.reviewedOn = reviewedOn
        self.notes = notes
    }
}
