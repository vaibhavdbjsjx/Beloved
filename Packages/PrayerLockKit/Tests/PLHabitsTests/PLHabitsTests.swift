import Foundation
import PLContent
import PLCore
@testable import PLHabits
import Testing

private func calendar(_ zone: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: zone)!
    return calendar
}

private func at(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

private func session(_ iso: String, outcome: PrayerSession.Outcome = .completed, trigger: PrayerSession.Trigger = .manual,
                     themes: [String] = [], seconds: TimeInterval = 60) -> PrayerSession {
    let end = at(iso)
    return PrayerSession(startedAt: end.addingTimeInterval(-seconds), endedAt: end, trigger: trigger, outcome: outcome,
                         themes: themes.map { .init($0) })
}

@Suite struct HabitCalculatorTests {
    let calculator = HabitCalculator(calendar: calendar())
    let now = at("2026-10-10T15:00:00Z")

    /// A moment left open for hours (phone idle, app in the background) counts at most
    /// `maximumCountedMoment`; ordinary moments count in full.
    @Test func idleMomentsDoNotInflateTimeInPrayer() {
        let summary = calculator.summary(for: [
            session("2026-10-10T08:00:00Z", seconds: 3 * 3600),
            session("2026-10-10T09:00:00Z", seconds: 45),
        ], now: now)
        #expect(summary.totalTimeInPrayer == HabitCalculator.maximumCountedMoment + 45)
    }

    @Test func streakIncludesToday() {
        let summary = calculator.summary(for: [
            session("2026-10-10T08:00:00Z"), session("2026-10-09T08:00:00Z"), session("2026-10-08T21:00:00Z"),
        ], now: now)
        #expect(summary.currentStreak == 3)
        #expect(summary.practicedToday)
    }

    @Test func streakStaysAliveUntilTodayEnds() {
        let summary = calculator.summary(for: [session("2026-10-09T08:00:00Z"), session("2026-10-08T08:00:00Z")], now: now)
        #expect(summary.currentStreak == 2)
        #expect(!summary.practicedToday)
    }

    @Test func gapResetsCurrentButNotLongest() {
        let summary = calculator.summary(for: [
            session("2026-10-10T08:00:00Z"),
            session("2026-10-05T08:00:00Z"), session("2026-10-04T08:00:00Z"), session("2026-10-03T08:00:00Z"),
        ], now: now)
        #expect(summary.currentStreak == 1)
        #expect(summary.longestStreak == 3)
    }

    @Test func abandonedMomentsDoNotCount() {
        let summary = calculator.summary(for: [session("2026-10-10T08:00:00Z", outcome: .abandoned)], now: now)
        #expect(summary.currentStreak == 0)
        #expect(summary.totalCompletedSessions == 0)
        #expect(summary.milestones.isEmpty)
    }

    @Test func forgivingConsistencyAndTotals() {
        let summary = calculator.summary(for: [
            session("2026-10-10T08:00:00Z", trigger: .shield, themes: ["peace"], seconds: 90),
            session("2026-10-10T09:00:00Z", themes: ["peace", "gratitude"], seconds: 30),
            session("2026-10-07T08:00:00Z", themes: ["gratitude", "peace"]),
            session("2026-09-20T08:00:00Z"),
        ], now: now)
        #expect(summary.daysPracticedLast7 == 2)
        #expect(summary.daysPracticedLast30 == 3)
        #expect(summary.totalCompletedSessions == 4)
        #expect(summary.totalTimeInPrayer == 90 + 30 + 60 + 60)
        #expect(summary.shieldMomentsCompleted == 1)
        #expect(summary.topThemes == ["peace", "gratitude"])
        #expect(summary.lastSevenDays.count == 7)
        #expect(summary.lastSevenDays.last?.completedSessions == 2)
        #expect(summary.milestones == [.firstMoment])
    }

    @Test func dayBoundariesFollowTheUsersTimeZone() {
        // 2026-10-10 03:30 UTC is 23:30 on 2026-10-09 in New York (EDT, UTC−4).
        let newYork = HabitCalculator(calendar: calendar("America/New_York"))
        let summary = newYork.summary(for: [session("2026-10-10T03:30:00Z")], now: at("2026-10-10T12:00:00Z"))
        #expect(!summary.practicedToday)
        #expect(summary.currentStreak == 1)
    }
}

@Suite struct SessionRepositoryTests {
    @Test func fileRepositoryPersistsAndDeletes() async throws {
        let repository = FileSessionRepository(fileURL: StorageLocations.temporary().privateFile("sessions.json"))
        #expect(try await repository.allSessions().isEmpty)
        let first = session("2026-10-10T08:00:00Z")
        try await repository.append(first)
        try await repository.append(session("2026-10-10T09:00:00Z"))
        let stored = try await repository.allSessions()
        #expect(stored.count == 2)
        #expect(stored.first == first)
        try await repository.deleteAll()
        #expect(try await repository.allSessions().isEmpty)
    }
}

@Suite struct ReturnGreetingTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func newUsersAreNotReturning() {
        #expect(!ReturnGreeting.isReturningAfterBreak(lastMoment: nil, now: now))
    }

    @Test func sixDaysIsNotABreak() {
        #expect(!ReturnGreeting.isReturningAfterBreak(lastMoment: now.addingTimeInterval(-6 * 86_400), now: now))
    }

    @Test func exactlySevenDaysIsNotYetABreak() {
        #expect(!ReturnGreeting.isReturningAfterBreak(lastMoment: now.addingTimeInterval(-ReturnGreeting.breakLength), now: now))
    }

    @Test func justOverSevenDaysIsABreak() {
        #expect(ReturnGreeting.isReturningAfterBreak(lastMoment: now.addingTimeInterval(-ReturnGreeting.breakLength - 1), now: now))
    }

    @Test func aMomentInTheFutureNeverTriggersTheNote() {
        // The device clock was moved back after a moment was recorded.
        #expect(!ReturnGreeting.isReturningAfterBreak(lastMoment: now.addingTimeInterval(3 * 86_400), now: now))
    }
}
