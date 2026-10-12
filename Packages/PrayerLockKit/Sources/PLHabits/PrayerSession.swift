import Foundation
import PLContent
import PLFaith

/// A completed (or abandoned) spiritual moment. Stored locally, never uploaded.
public struct PrayerSession: Codable, Identifiable, Hashable, Sendable {
    public enum Trigger: String, Codable, Sendable {
        /// The user opened a protected app and came here from the shield.
        case shield
        /// The user started a moment themselves.
        case manual
        /// From a reminder notification.
        case reminder
    }

    public enum Outcome: String, Codable, Sendable {
        case completed
        case abandoned
    }

    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var trigger: Trigger
    public var outcome: Outcome
    public var contentItemID: ContentItemID?
    public var themes: [ThemeID]
    /// Only recorded when the user allows it (`SpiritualProfile.rememberCheckIns`).
    public var mood: Mood?
    /// Whether this moment released protected apps.
    public var grantedAccess: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        trigger: Trigger,
        outcome: Outcome,
        contentItemID: ContentItemID? = nil,
        themes: [ThemeID] = [],
        mood: Mood? = nil,
        grantedAccess: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.trigger = trigger
        self.outcome = outcome
        self.contentItemID = contentItemID
        self.themes = themes
        self.mood = mood
        self.grantedAccess = grantedAccess
    }

    public var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
    public var isCompleted: Bool { outcome == .completed }
}
