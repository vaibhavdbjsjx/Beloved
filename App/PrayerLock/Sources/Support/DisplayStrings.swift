import Foundation
import PLContent
import PLFaith
import PLProtection

// UI strings for domain values live in the app (and its String Catalog), not in the
// domain package — the package stays identifier-only.

extension Mood {
    var title: String {
        switch self {
        case .grateful: String(localized: "Grateful")
        case .anxious: String(localized: "Anxious")
        case .stressed: String(localized: "Stressed")
        case .sad: String(localized: "Sad")
        case .angry: String(localized: "Angry")
        case .lonely: String(localized: "Lonely")
        case .hopeful: String(localized: "Hopeful")
        case .happy: String(localized: "Happy")
        case .seekingGuidance: String(localized: "Seeking guidance")
        case .seekingForgiveness: String(localized: "Seeking forgiveness")
        case .needStrength: String(localized: "Need strength")
        case .needPeace: String(localized: "Need peace")
        case .celebrating: String(localized: "Celebrating")
        case .justWantToPray: String(localized: "Just want to pray")
        }
    }
}

extension ContentLength {
    var title: String {
        switch self {
        case .brief: String(localized: "Brief")
        case .standard: String(localized: "Standard")
        case .extended: String(localized: "Extended")
        }
    }
}

extension UnlockDuration {
    var title: String {
        switch self {
        case let .minutes(minutes):
            String(localized: "\(minutes) minutes")
        case .restOfDay:
            String(localized: "Rest of the day")
        }
    }

    /// Honest description of how the unlock is enforced (see UnlockPlanner).
    var detail: String {
        switch self {
        case let .minutes(minutes) where TimeInterval(minutes * 60) < UnlockPlanner.minimumMonitoringInterval:
            String(localized: "\(minutes) minutes of use. Apps also close again after 15 minutes at most — iOS can't schedule anything shorter.")
        case .minutes:
            String(localized: "Apps close again when the time is up.")
        case .restOfDay:
            String(localized: "Apps stay open until midnight.")
        }
    }
}

extension ContentLicense {
    var title: String {
        switch self {
        case .publicDomain: String(localized: "Public domain")
        case let .creativeCommons(license, _): license
        case let .licensed(holder, _): String(localized: "Licensed from \(holder)")
        case .pendingClearance: String(localized: "Rights pending — not shown in release builds")
        }
    }
}

enum Greeting {
    static func text(name: String?, date: Date, calendar: Calendar) -> String {
        let base = switch TimeOfDay(date: date, calendar: calendar) {
        case .morning: String(localized: "Good morning")
        case .midday: String(localized: "Good afternoon")
        case .evening: String(localized: "Good evening")
        case .night: String(localized: "Peaceful night")
        }
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return base }
        return "\(base), \(name)"
    }
}

/// Builds the localized copy the Screen Time extensions display.
enum ShieldCopyFactory {
    static func make(for profile: SpiritualProfile) -> ShieldCopy {
        let prays = profile.faithID != nil
        return ShieldCopy(
            title: String(localized: "You chose to protect this app"),
            titleForApp: String(localized: "You chose to protect \(ShieldCopy.appNameToken)"),
            subtitle: prays
                ? String(localized: "Take a moment to pray before opening it.")
                : String(localized: "Take a moment before opening it."),
            primaryButton: String(localized: "Begin"),
            secondaryButton: String(localized: "Not now"),
            awaitingSubtitle: String(localized: "Open \(AppBrand.displayName) to begin your moment."),
            notificationTitle: String(localized: "Your moment is ready"),
            notificationBody: String(localized: "Tap to begin your moment.")
        )
    }
}
