import Foundation
import os

/// Log categories shared by the app and its extensions.
public enum LogCategory: String, Sendable, CaseIterable {
    case app
    case onboarding
    case content
    case calendar
    case habits
    case protection
    case monetization
    case assistant
    case storage
    case shieldConfiguration = "extension.shield-configuration"
    case shieldAction = "extension.shield-action"
    case activityMonitor = "extension.activity-monitor"
}

/// Central logger factory.
///
/// Privacy rule for the whole code base: spiritual content, moods, journal text,
/// names, and anything a user typed MUST be interpolated with `privacy: .private`
/// (the `os.Logger` default for dynamic strings) and SHOULD NOT be logged at all.
/// Log events and identifiers, not personal data.
public enum Log {
    public static func logger(_ category: LogCategory, bundle: Bundle = .main) -> Logger {
        Logger(subsystem: bundle.bundleIdentifier ?? "PrayerLock", category: category.rawValue)
    }
}
