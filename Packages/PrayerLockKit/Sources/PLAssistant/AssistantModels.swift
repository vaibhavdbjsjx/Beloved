import Foundation
import PLContent
import PLFaith

/// A user's request to the assistant ("Give me a short prayer for anxiety").
public struct AssistantRequest: Sendable {
    public var text: String
    public var profile: SpiritualProfile
    public var mood: Mood?
    public var date: Date
    public var calendar: Calendar
    public var hasPremium: Bool

    public init(
        text: String,
        profile: SpiritualProfile,
        mood: Mood? = nil,
        date: Date = Date(),
        calendar: Calendar = .current,
        hasPremium: Bool = false
    ) {
        self.text = text
        self.profile = profile
        self.mood = mood
        self.date = date
        self.calendar = calendar
        self.hasPremium = hasPremium
    }
}

/// What the user appears to be asking for.
public struct AssistantIntent: Hashable, Sendable {
    public var practice: PracticeKind?
    public var wantsExplanation: Bool
    public var faith: FaithID?
    public var focus: FocusID?
    public var mood: Mood?
    public var themes: [ThemeID]
    /// ISO weekday mentioned in the request ("for Monday").
    public var isoWeekday: Int?
    /// A passage reference mentioned in the request ("John 3:16", "2:255").
    public var reference: String?

    public init(
        practice: PracticeKind? = nil,
        wantsExplanation: Bool = false,
        faith: FaithID? = nil,
        focus: FocusID? = nil,
        mood: Mood? = nil,
        themes: [ThemeID] = [],
        isoWeekday: Int? = nil,
        reference: String? = nil
    ) {
        self.practice = practice
        self.wantsExplanation = wantsExplanation
        self.faith = faith
        self.focus = focus
        self.mood = mood
        self.themes = themes
        self.isoWeekday = isoWeekday
        self.reference = reference
    }
}

/// A verified passage from the curated library, offered to the generator by ID.
public struct RetrievedPassage: Hashable, Sendable, Identifiable {
    /// Stable ID the generator must use to reference this passage: "<itemID>#<segmentIndex>".
    public let id: String
    public let itemID: ContentItemID
    public let title: LocalizedText
    public let segment: ContentSegment
    /// Library explanation segments that accompany the passage, if any.
    public let explanations: [ContentSegment]
}

/// Structured model output. The generator must label every segment's role and may
/// only quote sources by passing `passageID` — never by typing scripture itself.
public struct GenerationDraft: Codable, Hashable, Sendable {
    public struct Segment: Codable, Hashable, Sendable {
        public var role: SegmentRole
        public var text: String
        public var passageID: String?

        public init(role: SegmentRole, text: String, passageID: String? = nil) {
            self.role = role
            self.text = text
            self.passageID = passageID
        }
    }

    public var segments: [Segment]

    public init(segments: [Segment]) { self.segments = segments }
}

public struct CrisisResource: Hashable, Sendable {
    public var name: String
    public var contact: String
    /// ISO 3166 region code, `nil` = universal.
    public var region: String?
}

public enum AssistantNotice: Hashable, Sendable {
    /// The request suggests the user may be at risk. Show support resources prominently.
    case crisisSupport([CrisisResource])
    /// The request asked for medical/psychological advice the app must not give.
    case notMedicalAdvice
    /// A request the assistant declines (e.g. mocking a faith).
    case declined
    /// No language model is configured; the answer comes only from the verified library.
    case generationUnavailable
    /// The validator removed content it could not verify (count of segments).
    case removedUnverifiedContent(Int)
    /// A weekday/devotional custom informed the answer; show its explanation.
    case devotionalContext(String)
    case noMatchingContent
}

public struct AssistantResponse: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case crisisSupport
        case declined
        /// Library content only (no generation).
        case libraryOnly
        /// Validated mix of library passages and generated text.
        case composed
    }

    public var kind: Kind
    public var segments: [ContentSegment]
    public var notices: [AssistantNotice]
    public var intent: AssistantIntent?
    /// The library item a library-only answer came from.
    public var itemID: ContentItemID?

    public init(kind: Kind, segments: [ContentSegment], notices: [AssistantNotice], intent: AssistantIntent?, itemID: ContentItemID? = nil) {
        self.kind = kind
        self.segments = segments
        self.notices = notices
        self.intent = intent
        self.itemID = itemID
    }
}
