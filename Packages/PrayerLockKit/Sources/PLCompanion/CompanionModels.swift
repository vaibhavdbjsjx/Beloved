import Foundation
import PLContent
import PLFaith

/// One turn in a conversation with the companion.
public struct CompanionMessage: Codable, Hashable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    /// Who wrote an answer — shown on it, so nobody mistakes one kind for another.
    public enum Origin: String, Codable, Sendable {
        /// The AI companion (its own words, plus verified texts in place of markers).
        case companion
        /// Chosen from Beloved's verified library on this iPhone; no AI involved.
        case library
        /// Support resources for someone who may be in danger.
        case support
    }

    public var id: UUID
    public var role: Role
    public var origin: Origin
    /// The user's words, or the answer *with its markers* (resolved when displayed, so a
    /// later, corrected library is always what's shown).
    public var text: String
    public var date: Date

    public init(id: UUID = UUID(), role: Role, origin: Origin = .companion, text: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.origin = origin
        self.text = text
        self.date = date
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        origin = (try? c.decodeIfPresent(Origin.self, forKey: .origin)) ?? .companion
        text = try c.decode(String.self, forKey: .text)
        date = try c.decode(Date.self, forKey: .date)
    }
}

/// A conversation kept on this iPhone only (private, `.complete`-protected).
public struct CompanionConversation: Codable, Hashable, Sendable {
    public var messages: [CompanionMessage]

    public init(messages: [CompanionMessage] = []) { self.messages = messages }

    /// Longest conversation kept; older turns fall away.
    public static let maximumStoredMessages = 200
}

/// What the companion server needs to answer within the user's own tradition — and nothing
/// more: no name, no intentions, no prayer history, no device identifiers.
public struct CompanionContext: Codable, Hashable, Sendable {
    /// A prayer, mantra or dua the app can insert verbatim with `⟦prayer:id⟧`.
    public struct LibraryEntry: Codable, Hashable, Sendable {
        public var id: String
        public var title: String
        public var kind: String
        public var themes: [String]
        public var focuses: [String]
    }

    public var faith: String?
    public var faithName: String?
    public var tradition: String?
    public var focuses: [String]
    /// BCP-47 language the user reads in.
    public var language: String
    /// Region, only for choosing crisis resources.
    public var region: String?
    /// Topics the user chose to share during onboarding ("pregnancy", "exams"), if any.
    public var helpWith: [String]
    /// Scripture the app can quote: `bible`, `quran`, `bhagavad-gita`.
    public var scripture: [String]
    public var library: [LibraryEntry]
    /// Today's date in words ("Monday, 19 October 2026"), so "today" means something.
    public var today: String?
    /// Holy days today and soon in their calendar ("Diwali (in 20 days, 8 November)").
    public var observances: [String] = []

    public init(
        faith: String?, faithName: String?, tradition: String?, focuses: [String], language: String,
        region: String?, helpWith: [String], scripture: [String], library: [LibraryEntry]
    ) {
        self.faith = faith
        self.faithName = faithName
        self.tradition = tradition
        self.focuses = focuses
        self.language = language
        self.region = region
        self.helpWith = helpWith
        self.scripture = scripture
        self.library = library
    }

    /// Builds the context from the profile and what this build may show.
    public static func make(
        profile: SpiritualProfile,
        registry: FaithRegistry,
        catalog: ContentCatalog,
        policy: ContentPolicy,
        scripture: [String],
        helpWith: [String] = [],
        region: String? = Locale.current.region?.identifier,
        today: String? = nil,
        observances: [String] = []
    ) -> CompanionContext {
        let language = profile.languages.first ?? "en"
        let faith = profile.faithID.flatMap(registry.faith)
        let items = catalog.visibleItems(policy: policy, registry: registry)
            .filter { $0.faith == nil || $0.faith == profile.faithID }
            .filter { item in item.segments.contains { $0.role == .sourceText || $0.role == .traditionalText || $0.role == .composedPrayer } }
        var context = CompanionContext(
            faith: profile.faithID?.rawValue,
            faithName: faith?.name.resolved(for: [language]),
            tradition: profile.traditionID.flatMap(registry.tradition)?.name.resolved(for: [language]),
            focuses: profile.focusIDs.compactMap { id in
                faith?.focuses.first { $0.id == id }?.name.resolved(for: [language])
            },
            language: language,
            region: region,
            helpWith: helpWith,
            scripture: scripture,
            library: items.map {
                LibraryEntry(
                    id: $0.id.rawValue,
                    title: $0.title.resolved(for: [language]),
                    kind: $0.kind.rawValue,
                    themes: $0.themes.map(\.rawValue),
                    focuses: $0.focuses.map(\.rawValue)
                )
            }
        )
        context.today = today
        context.observances = observances
        return context
    }
}

/// What the app sends to the companion server.
public struct CompanionRequest: Codable, Hashable, Sendable {
    public struct Turn: Codable, Hashable, Sendable {
        public var role: CompanionMessage.Role
        public var text: String
    }

    public var messages: [Turn]
    public var context: CompanionContext

    /// The recent conversation, trimmed so a long chat can't grow without bound.
    public static let maximumTurns = 24
    public static let maximumCharactersPerTurn = 4_000

    public init(conversation: [CompanionMessage], context: CompanionContext) {
        // Only the user's words and the companion's own answers go to the model; library and
        // support notes were never the model's, so they aren't presented as if they were.
        var turns: [Turn] = []
        for message in conversation where message.role == .user || message.origin == .companion {
            let turn = Turn(role: message.role, text: String(message.text.prefix(Self.maximumCharactersPerTurn)))
            if let last = turns.last, last.role == turn.role {
                turns[turns.count - 1] = turn // keep the latest of consecutive same-role turns
            } else {
                turns.append(turn)
            }
        }
        messages = Array(turns.suffix(Self.maximumTurns))
        // A conversation sent to the model must start with the user.
        while messages.first?.role == .assistant { messages.removeFirst() }
        self.context = context
    }
}
