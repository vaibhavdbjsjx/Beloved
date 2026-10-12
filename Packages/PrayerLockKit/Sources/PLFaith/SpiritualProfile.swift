import Foundation

/// Preferred length of spiritual content.
public enum ContentLength: String, Codable, CaseIterable, Sendable {
    /// Under ~30 seconds — the default for a lock interruption.
    case brief
    /// Around a minute.
    case standard
    /// Several minutes.
    case extended
}

/// What the user chose to share about their spiritual practice.
///
/// Everything is optional: the app must work for someone who declines to state a
/// faith ("just want a pause"). Stored locally only; never sent to a server except
/// the minimum needed for an explicit assistant request (see AI architecture doc).
public struct SpiritualProfile: Codable, Hashable, Sendable {
    public var faithID: FaithID?
    public var traditionID: TraditionID?
    public var focusIDs: [FocusID]
    public var contentLength: ContentLength
    /// Preferred content languages in priority order (BCP-47).
    public var languages: [String]
    public var showOriginalScript: Bool
    public var showTransliteration: Bool
    /// Opt-in: let weekday devotional associations (e.g. Monday–Shiva in many Hindu
    /// communities) influence suggestions. Off by default — these are customs, not rules.
    public var useDevotionalAssociations: Bool
    /// Remember daily check-in moods in history (off → moods are used once, then discarded).
    public var rememberCheckIns: Bool
    /// Optional first name, used only for greetings on-device.
    public var displayName: String?
    /// A few words the user wants a pause to remind them of ("Call my mother"). Private,
    /// on-device, shown in the app only — never in the Screen Time extensions.
    public var intentions: [String]

    /// At most this many intentions; each is trimmed and capped (see `normalizedIntentions`).
    public static let maximumIntentions = 3
    public static let maximumIntentionLength = 80

    public init(
        faithID: FaithID? = nil,
        traditionID: TraditionID? = nil,
        focusIDs: [FocusID] = [],
        contentLength: ContentLength = .brief,
        languages: [String] = ["en"],
        showOriginalScript: Bool = true,
        showTransliteration: Bool = true,
        useDevotionalAssociations: Bool = false,
        rememberCheckIns: Bool = true,
        displayName: String? = nil,
        intentions: [String] = []
    ) {
        self.faithID = faithID
        self.traditionID = traditionID
        self.focusIDs = focusIDs
        self.contentLength = contentLength
        self.languages = languages
        self.showOriginalScript = showOriginalScript
        self.showTransliteration = showTransliteration
        self.useDevotionalAssociations = useDevotionalAssociations
        self.rememberCheckIns = rememberCheckIns
        self.displayName = displayName
        self.intentions = Self.normalizedIntentions(intentions)
    }

    /// Trims, drops empties and duplicates, caps length and count.
    public static func normalizedIntentions(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in raw {
            let trimmed = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumIntentionLength))
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
            if result.count == maximumIntentions { break }
        }
        return result
    }

    // Tolerant decoding: a field added in a later version (or missing from an older file)
    // falls back to its default instead of failing — so an update never wipes a profile.
    private enum CodingKeys: String, CodingKey {
        case faithID, traditionID, focusIDs, contentLength, languages, showOriginalScript
        case showTransliteration, useDevotionalAssociations, rememberCheckIns, displayName, intentions
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SpiritualProfile()
        faithID = try c.decodeIfPresent(FaithID.self, forKey: .faithID)
        traditionID = try c.decodeIfPresent(TraditionID.self, forKey: .traditionID)
        focusIDs = (try? c.decodeIfPresent([FocusID].self, forKey: .focusIDs)) ?? defaults.focusIDs
        contentLength = (try? c.decodeIfPresent(ContentLength.self, forKey: .contentLength)) ?? defaults.contentLength
        languages = (try? c.decodeIfPresent([String].self, forKey: .languages)) ?? defaults.languages
        showOriginalScript = (try? c.decodeIfPresent(Bool.self, forKey: .showOriginalScript)) ?? defaults.showOriginalScript
        showTransliteration = (try? c.decodeIfPresent(Bool.self, forKey: .showTransliteration)) ?? defaults.showTransliteration
        useDevotionalAssociations = (try? c.decodeIfPresent(Bool.self, forKey: .useDevotionalAssociations))
            ?? defaults.useDevotionalAssociations
        rememberCheckIns = (try? c.decodeIfPresent(Bool.self, forKey: .rememberCheckIns)) ?? defaults.rememberCheckIns
        displayName = try? c.decodeIfPresent(String.self, forKey: .displayName)
        intentions = Self.normalizedIntentions((try? c.decodeIfPresent([String].self, forKey: .intentions)) ?? [])
    }
}
