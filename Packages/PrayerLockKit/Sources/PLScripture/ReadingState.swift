import Foundation
import PLCore
import PLFaith

/// Where the reader left off and how they like to read, per work. Personal (it reveals what
/// someone reads), so the app keeps it in the private, `.complete`-protected profile.
public struct ReadingState: Codable, Hashable, Sendable {
    public var positions: [SourceWorkID: ScriptureLocation]
    public var layouts: [SourceWorkID: ReadingLayout]

    public init(positions: [SourceWorkID: ScriptureLocation] = [:], layouts: [SourceWorkID: ReadingLayout] = [:]) {
        self.positions = positions
        self.layouts = layouts
    }

    // Tolerant decoding: an unreadable part resets only itself.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        positions = (try? container.decodeIfPresent([SourceWorkID: ScriptureLocation].self, forKey: .positions)) ?? [:]
        layouts = (try? container.decodeIfPresent([SourceWorkID: ReadingLayout].self, forKey: .layouts)) ?? [:]
    }
}

/// The optional daily-verse notification.
public struct DailyVerseReminder: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int

    /// Off by default; 7:30 when first turned on.
    public init(isEnabled: Bool = false, hour: Int = 7, minute: Int = 30) {
        self.isEnabled = isEnabled
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Local notifications can't change their text day to day, so the app schedules one per
    /// day ahead (each with that day's verse) and tops the list up whenever it opens.
    public static let daysScheduledAhead = 14

    /// The days to schedule, starting today if the time hasn't passed yet.
    public func upcomingDays(from now: Date, calendar: Calendar, count: Int = daysScheduledAhead) -> [CivilDate] {
        guard isEnabled, count > 0 else { return [] }
        let today = CivilDate(now, calendar: calendar)
        let todayFire = fireComponents(for: today)
        let firstOffset = calendar.date(from: todayFire).map { $0 > now ? 0 : 1 } ?? 1
        return (0..<count).map { today.adding(days: firstOffset + $0) }
    }

    /// Wall-clock components for a day's notification (follows the user's time zone).
    public func fireComponents(for day: CivilDate) -> DateComponents {
        DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
    }
}
