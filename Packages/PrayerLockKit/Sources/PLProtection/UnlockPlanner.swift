import Foundation

/// How a temporary unlock is enforced with DeviceActivity.
///
/// DeviceActivity cannot fire a callback after an arbitrary wall-clock delay; its
/// schedules must be at least 15 minutes long (verified in the iOS 27 SDK:
/// `MonitoringError.intervalTooShort` — "The minimum interval length for monitoring
/// device activity is fifteen minutes"). So:
/// - durations ≥ 15 min → a one-off schedule whose `intervalDidEnd` re-shields;
/// - durations < 15 min → a 15-minute schedule plus a *usage* threshold event, so
///   apps re-shield after N minutes of use or after 15 minutes, whichever is first.
/// The UI must describe short unlocks honestly ("5 minutes of use").
public struct UnlockPlan: Hashable, Sendable {
    public let monitoringStart: Date
    public let monitoringEnd: Date
    public let usageThreshold: TimeInterval?

    public var latestRelock: Date { monitoringEnd }
}

public enum UnlockPlanner {
    public static let minimumMonitoringInterval: TimeInterval = 15 * 60

    public static func plan(duration: UnlockDuration, now: Date, calendar: Calendar) -> UnlockPlan {
        switch duration {
        case let .minutes(minutes):
            let requested = TimeInterval(max(1, minutes) * 60)
            if requested < minimumMonitoringInterval {
                return UnlockPlan(
                    monitoringStart: now,
                    monitoringEnd: now.addingTimeInterval(minimumMonitoringInterval),
                    usageThreshold: requested
                )
            }
            return UnlockPlan(monitoringStart: now, monitoringEnd: now.addingTimeInterval(requested), usageThreshold: nil)

        case .restOfDay:
            let startOfToday = calendar.startOfDay(for: now)
            let midnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86_400)
            let end = max(midnight, now.addingTimeInterval(minimumMonitoringInterval))
            return UnlockPlan(monitoringStart: now, monitoringEnd: end, usageThreshold: nil)
        }
    }

    public static func grant(for plan: UnlockPlan, sessionID: UUID?) -> UnlockGrant {
        UnlockGrant(
            grantedAt: plan.monitoringStart,
            expiresAt: plan.monitoringEnd,
            usageLimit: plan.usageThreshold,
            sessionID: sessionID
        )
    }
}

/// Apple caps each shield list (verified in the iOS 27 SDK docs: "Your app can shield
/// up to 50 application tokens at once", same for categories and web domains).
public enum SelectionLimits {
    public static let maxApplications = 50
    public static let maxCategories = 50
    public static let maxWebDomains = 50

    public enum Issue: Hashable, Sendable {
        case tooManyApplications(Int)
        case tooManyCategories(Int)
        case tooManyWebDomains(Int)
    }

    public static func validate(applications: Int, categories: Int, webDomains: Int) -> [Issue] {
        var issues: [Issue] = []
        if applications > maxApplications { issues.append(.tooManyApplications(applications)) }
        if categories > maxCategories { issues.append(.tooManyCategories(categories)) }
        if webDomains > maxWebDomains { issues.append(.tooManyWebDomains(webDomains)) }
        return issues
    }
}
