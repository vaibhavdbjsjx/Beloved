import Foundation

/// A source work (scripture, liturgy, hymn collection, devotional text).
public struct SourceWork: Codable, Identifiable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case scripture
        case liturgy
        case hymn
        case devotional
        case traditionalPrayer
    }

    /// How passages in this work are addressed — drives reference parsing/formatting.
    public enum ReferenceScheme: String, Codable, Sendable {
        /// Bible: book chapter:verse (e.g. "Psalm 46:10").
        case bookChapterVerse
        /// Quran: surah:ayah (e.g. "94:5–6").
        case surahAyah
        /// Rigveda: mandala.sukta.rik (e.g. "3.62.10").
        case mandalaSuktaRik
        /// Bhagavad Gita and similar: chapter.verse (e.g. "2.47").
        case chapterVerse
        /// Anything else; references are displayed as written.
        case freeform
    }

    public var id: SourceWorkID
    public var title: LocalizedText
    public var kind: Kind
    public var referenceScheme: ReferenceScheme
    public var editions: [Edition]

    public init(
        id: SourceWorkID,
        title: LocalizedText,
        kind: Kind,
        referenceScheme: ReferenceScheme,
        editions: [Edition]
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.referenceScheme = referenceScheme
        self.editions = editions
    }
}

/// A specific text edition or translation. Exact quotations must cite one.
public struct Edition: Codable, Identifiable, Hashable, Sendable {
    public var id: EditionID
    public var title: LocalizedText
    /// BCP-47 language of the edition's text (e.g. `en`, `ar`, `sa`).
    public var language: String
    /// ISO 15924 script code where useful (e.g. `Arab`, `Deva`, `Latn`).
    public var script: String?
    public var license: ContentLicense
    public var attribution: String

    public init(
        id: EditionID,
        title: LocalizedText,
        language: String,
        script: String? = nil,
        license: ContentLicense,
        attribution: String
    ) {
        self.id = id
        self.title = title
        self.language = language
        self.script = script
        self.license = license
        self.attribution = attribution
    }
}

/// Redistribution status of an edition. Release builds refuse to ship verbatim text
/// from an edition whose rights have not been cleared.
public enum ContentLicense: Codable, Hashable, Sendable {
    case publicDomain(note: String?)
    case creativeCommons(license: String, conditions: String?)
    case licensed(holder: String, agreementReference: String?)
    case pendingClearance(note: String)

    public var permitsRedistribution: Bool {
        if case .pendingClearance = self { return false }
        return true
    }
}
