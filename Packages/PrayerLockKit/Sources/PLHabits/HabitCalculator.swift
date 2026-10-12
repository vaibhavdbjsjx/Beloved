import Foundation
import PLCore
import PLFaith

/// Derived, display-ready habit insights.
///
/// Design principle: encourage consistency without manipulation. A missed day is
/// not framed as failure — the summary always includes a forgiving consistency
/// measure ("5 of the last 7 days") alongside the streak.
public struct HabitSummary: Hashable, Sendable {
    public struct Day: Hashable, Sendable {
        public let date: CivilDate
        public let completedSessions: Int
    }

    /// Consecutive days with at least one completed moment, ending today — or ending
    /// yesterday if today has no moment *yet* (the streak is still alive).
    public var currentStreak: Int
    public var longestStreak: Int
    public var practicedToday: Bool
    /// Oldest first, ending today.
    public var lastSevenDays: [Day]
    public var daysPracticedLast7: Int
    public var daysPracticedLast30: Int
    public var totalCompletedSessions: Int
    public var totalTimeInPrayer: TimeInterval
    /// Moments that came from a protected-app shield.
    public var shieldMomentsCompleted: Int
    /// Most common themes, most frequent first (ties alphabetical).
    public var topThemes: [ThemeID]
    public var milestones: [Milestone]
}

public enum Milestone: Hashable, Sendable {
    case firstMoment
    case moments(Int)
    case streak(Int)
}

public struct HabitCalculator: Sendable {
    /// The most one moment adds to "time in prayer". A moment left open while the phone sits
    /// idle (or the app is in the background) must not inflate the figure; the longest
    /// content is a few minutes, so 20 minutes is a generous, honest ceiling.
    public static let maximumCountedMoment: TimeInterval = 20 * 60

    public var calendar: Calendar
    public var momentMilestones: [Int] = [10, 50, 100, 365]
    public var streakMilestones: [Int] = [7, 30, 100]

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func summary(for sessions: [PrayerSession], now: Date) -> HabitSummary {
        let completed = sessions.filter(\.isCompleted)
        let today = CivilDate(now, calendar: calendar)

        var countsByDay: [CivilDate: Int] = [:]
        for session in completed {
            countsByDay[CivilDate(session.endedAt, calendar: calendar), default: 0] += 1
        }
        let practicedDays = Set(countsByDay.keys)

        let currentStreak = streak(endingAt: practicedDays.contains(today) ? today : today.adding(days: -1), in: practicedDays)
        let longest = longestStreak(in: practicedDays)

        let lastSeven = (0..<7).reversed().map { offset -> HabitSummary.Day in
            let day = today.adding(days: -offset)
            return HabitSummary.Day(date: day, completedSessions: countsByDay[day] ?? 0)
        }

        func daysPracticed(inLast window: Int) -> Int {
            (0..<window).filter { practicedDays.contains(today.adding(days: -$0)) }.count
        }

        var themeCounts: [ThemeID: Int] = [:]
        for session in completed {
            for theme in session.themes { themeCounts[theme, default: 0] += 1 }
        }
        let topThemes = themeCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(3)
            .map(\.key)

        var milestones: [Milestone] = []
        if !completed.isEmpty { milestones.append(.firstMoment) }
        milestones += momentMilestones.filter { completed.count >= $0 }.map(Milestone.moments)
        milestones += streakMilestones.filter { longest >= $0 }.map(Milestone.streak)

        return HabitSummary(
            currentStreak: currentStreak,
            longestStreak: longest,
            practicedToday: practicedDays.contains(today),
            lastSevenDays: lastSeven,
            daysPracticedLast7: daysPracticed(inLast: 7),
            daysPracticedLast30: daysPracticed(inLast: 30),
            totalCompletedSessions: completed.count,
            totalTimeInPrayer: completed.reduce(0) { $0 + min($1.duration, Self.maximumCountedMoment) },
            shieldMomentsCompleted: completed.filter { $0.trigger == .shield }.count,
            topThemes: topThemes,
            milestones: milestones
        )
    }

    private func streak(endingAt day: CivilDate, in practiced: Set<CivilDate>) -> Int {
        var count = 0
        var cursor = day
        while practiced.contains(cursor) {
            count += 1
            cursor = cursor.adding(days: -1)
        }
        return count
    }

    private func longestStreak(in practiced: Set<CivilDate>) -> Int {
        var longest = 0
        for day in practiced where !practiced.contains(day.adding(days: -1)) {
            // `day` starts a run.
            var length = 1
            while practiced.contains(day.adding(days: length)) { length += 1 }
            longest = max(longest, length)
        }
        return longest
    }
}
