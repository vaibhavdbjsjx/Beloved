import Foundation

/// Raw names of Screen Time stores, activities and events — platform-independent so the
/// parsing that protects against stale callbacks is unit-tested on any Mac.
///
/// Never rename these: existing installs have live activities registered under them.
public enum ScreenTimeNames {
    public static let store = "prayerlock.protection"
    public static let dailyGuardActivity = "prayerlock.daily-guard"
    public static let relockUsageEvent = "prayerlock.relock.usage"
    static let relockPrefix = "prayerlock.relock."

    /// One activity per grant, so a callback can be matched to the grant that scheduled it.
    public static func relockActivity(for grantID: UUID) -> String {
        relockPrefix + grantID.uuidString
    }

    /// The grant a relock activity belongs to; `nil` for any other activity (the daily
    /// guard, foreign or malformed names), which the relock logic then ignores.
    public static func grantID(fromRelockActivity name: String) -> UUID? {
        guard name.hasPrefix(relockPrefix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(relockPrefix.count)))
    }
}

/// What the shield's buttons do — decided here so it is unit-tested; the Shield Action
/// extension only translates the result into `ShieldActionResponse`.
public enum ShieldHandOff: Equatable, Sendable {
    /// "Not now": close the protected app. Nothing is recorded or posted.
    case close
    /// "Begin" on iOS 26.5+: ask iOS to open the app directly (notification as fallback).
    case openApp
    /// "Begin" otherwise: the shield redraws and a notification leads to the moment.
    case deferWithNotification

    public static func decide(primaryButton: Bool, supportsDirectOpen: Bool, directOpenEnabled: Bool) -> ShieldHandOff {
        guard primaryButton else { return .close }
        return supportsDirectOpen && directOpenEnabled ? .openApp : .deferWithNotification
    }

    /// Whether a `ShieldRequest` is recorded and the hand-off notification posted.
    public var startsMoment: Bool { self != .close }
}
