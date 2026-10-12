import Foundation
import PLCore
import PLFaith

/// Everything the selector may consider. All of it stays on-device.
public struct SelectionContext: Sendable {
    public var profile: SpiritualProfile
    public var mood: Mood?
    /// Themes explicitly requested (e.g. by the assistant: "a prayer for patience").
    public var themes: Set<ThemeID>
    public var date: Date
    public var calendar: Calendar
    /// Observances active today for the user's faith/tradition (from PLCalendar).
    public var activeOccasions: Set<OccasionID>
    /// Focuses suggested by opt-in weekday devotional associations (from PLCalendar).
    public var devotionalFocuses: Set<FocusID>
    /// Recently shown items, most recent first.
    public var recentlyShown: [ContentItemID]
    public var hasPremium: Bool
    /// Restrict to these practice kinds when possible (falls back to all if none match).
    public var preferredKinds: Set<PracticeKind>

    public init(
        profile: SpiritualProfile,
        mood: Mood? = nil,
        themes: Set<ThemeID> = [],
        date: Date,
        calendar: Calendar = .current,
        activeOccasions: Set<OccasionID> = [],
        devotionalFocuses: Set<FocusID> = [],
        recentlyShown: [ContentItemID] = [],
        hasPremium: Bool = false,
        preferredKinds: Set<PracticeKind> = []
    ) {
        self.profile = profile
        self.mood = mood
        self.themes = themes
        self.date = date
        self.calendar = calendar
        self.activeOccasions = activeOccasions
        self.devotionalFocuses = devotionalFocuses
        self.recentlyShown = recentlyShown
        self.hasPremium = hasPremium
        self.preferredKinds = preferredKinds
    }
}

/// Tunable scoring weights. Kept explicit so ranking is explainable and testable.
public struct SelectionWeights: Sendable {
    public var moodMatch = 5.0
    public var themeMatchPerTheme = 3.0
    public var maxThemeMatches = 2
    public var occasionMatch = 6.0
    public var timeOfDayMatch = 2.0
    public var focusMatch = 3.0
    public var devotionalFocusMatch = 2.0
    public var traditionSpecific = 1.0
    public var lengthMatch = 2.0
    public var lengthTooLongPenalty = -3.0
    public var faithNeutralPenalty = -4.0
    public var recentPenalty = -8.0
    public var recentWindow = 5

    public init() {}
}

/// A ranked item plus the reasons it scored as it did ("why am I seeing this?").
public struct ScoredContent: Sendable {
    public enum Reason: Hashable, Sendable {
        case mood(Mood)
        case theme(ThemeID)
        case occasion(OccasionID)
        case timeOfDay(TimeOfDay)
        case focus(FocusID)
        case devotionalAssociation(FocusID)
        case tradition(TraditionID)
        case length
        case recentlyShown
        case faithNeutralFallback
    }

    public var item: ContentItem
    public var score: Double
    public var reasons: [Reason]
}

/// Chooses spiritual content for a moment. Pure and deterministic: the same inputs
/// on the same day yield the same choice, and it rotates from day to day.
public struct ContentSelector: Sendable {
    public let catalog: ContentCatalog
    public let registry: FaithRegistry
    public let policy: ContentPolicy
    public var weights: SelectionWeights

    public init(
        catalog: ContentCatalog,
        registry: FaithRegistry,
        policy: ContentPolicy,
        weights: SelectionWeights = SelectionWeights()
    ) {
        self.catalog = catalog
        self.registry = registry
        self.policy = policy
        self.weights = weights
    }

    public func select(_ context: SelectionContext) -> ScoredContent? {
        rank(context).first
    }

    public func rank(_ context: SelectionContext) -> [ScoredContent] {
        var pool = catalog.items.filter { isEligible($0, context) }
        if !context.preferredKinds.isEmpty {
            let preferred = pool.filter { context.preferredKinds.contains($0.kind) }
            if !preferred.isEmpty { pool = preferred }
        }
        let dayKey = CivilDate(context.date, calendar: context.calendar).description
        return pool
            .map { score($0, context) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                // Deterministic daily rotation among equally good candidates.
                return StableHash.fnv1a("\(dayKey)|\(lhs.item.id)") < StableHash.fnv1a("\(dayKey)|\(rhs.item.id)")
            }
    }

    // MARK: - Hard filters

    /// Whether `item` may be shown in `context` (policy, premium, faith/tradition/focus).
    public func isEligible(_ item: ContentItem, _ context: SelectionContext) -> Bool {
        guard policy.permits(item, registry: registry) else { return false }
        if item.isPremium, !context.hasPremium { return false }

        let profile = context.profile
        guard let faith = profile.faithID else {
            // No faith chosen: only faith-neutral content.
            return item.faith == nil
        }
        guard item.faith == nil || item.faith == faith else { return false }

        // Tradition-specific content only for users in that tradition.
        if !item.traditions.isEmpty {
            guard let tradition = profile.traditionID, item.traditions.contains(tradition) else { return false }
        }

        // Focus-specific content: if the user chose focuses, respect them (plus any
        // opt-in devotional association for today). If they chose none, allow all.
        if !item.focuses.isEmpty, !profile.focusIDs.isEmpty {
            let allowed = Set(profile.focusIDs).union(context.devotionalFocuses)
            guard !allowed.isDisjoint(with: item.focuses) else { return false }
        }
        return true
    }

    // MARK: - Scoring

    func score(_ item: ContentItem, _ context: SelectionContext) -> ScoredContent {
        var score = 0.0
        var reasons: [ScoredContent.Reason] = []

        var wantedThemes = context.themes
        if let mood = context.mood {
            if item.moods.contains(mood) {
                score += weights.moodMatch
                reasons.append(.mood(mood))
            }
            wantedThemes.formUnion(catalog.taxonomy.themes(for: mood))
        }
        for theme in item.themes.filter(wantedThemes.contains).prefix(weights.maxThemeMatches) {
            score += weights.themeMatchPerTheme
            reasons.append(.theme(theme))
        }

        for occasion in item.occasions where context.activeOccasions.contains(occasion) {
            score += weights.occasionMatch
            reasons.append(.occasion(occasion))
        }

        let timeOfDay = TimeOfDay(date: context.date, calendar: context.calendar)
        if item.timesOfDay.contains(timeOfDay) {
            score += weights.timeOfDayMatch
            reasons.append(.timeOfDay(timeOfDay))
        }

        for focus in item.focuses {
            if context.profile.focusIDs.contains(focus) {
                score += weights.focusMatch
                reasons.append(.focus(focus))
            } else if context.devotionalFocuses.contains(focus) {
                score += weights.devotionalFocusMatch
                reasons.append(.devotionalAssociation(focus))
            }
        }

        if let tradition = context.profile.traditionID, item.traditions.contains(tradition) {
            score += weights.traditionSpecific
            reasons.append(.tradition(tradition))
        }

        if item.length == context.profile.contentLength {
            score += weights.lengthMatch
            reasons.append(.length)
        } else if item.length.rank > context.profile.contentLength.rank {
            score += weights.lengthTooLongPenalty
        }

        if context.profile.faithID != nil, item.faith == nil {
            score += weights.faithNeutralPenalty
            reasons.append(.faithNeutralFallback)
        }

        if let index = context.recentlyShown.prefix(weights.recentWindow).firstIndex(of: item.id) {
            // Most recent gets the full penalty, older ones progressively less.
            let decay = 1.0 - Double(index) / Double(weights.recentWindow)
            score += weights.recentPenalty * decay
            reasons.append(.recentlyShown)
        }

        return ScoredContent(item: item, score: score, reasons: reasons)
    }
}

extension ContentLength {
    var rank: Int {
        switch self {
        case .brief: 0
        case .standard: 1
        case .extended: 2
        }
    }
}
