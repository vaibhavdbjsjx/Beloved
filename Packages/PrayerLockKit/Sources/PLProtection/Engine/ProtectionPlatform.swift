import Foundation

/// Screen Time authorization as the engine sees it (platform-neutral).
public enum ScreenTimeAuthorization: String, Codable, Sendable {
    case notDetermined
    case denied
    case approved
}

/// The user's choice of apps / categories / websites. On iOS this is
/// `FamilyActivitySelection` (opaque tokens); tests use a simple fake.
public protocol ProtectionSelection: Codable, Equatable {
    init()
    var applicationCount: Int { get }
    var categoryCount: Int { get }
    var webDomainCount: Int { get }
}

public extension ProtectionSelection {
    var isEmptySelection: Bool { applicationCount == 0 && categoryCount == 0 && webDomainCount == 0 }

    var limitIssues: [SelectionLimits.Issue] {
        SelectionLimits.validate(applications: applicationCount, categories: categoryCount, webDomains: webDomainCount)
    }

    /// Counts only — never token contents — for logs and diagnostics.
    var countsDescription: String { "\(applicationCount) apps, \(categoryCount) categories, \(webDomainCount) sites" }
}

public enum TokenRefreshOutcome: Equatable, Sendable {
    /// The OS has no token-refresh API (before iOS 26.5).
    case unsupported
    case unchanged
    case refreshed
}

/// Read-only facts about the OS-side protection state, for the diagnostics screen.
public struct PlatformDiagnostics: Equatable, Sendable {
    public var monitoredActivities: [String]
    public var shieldedApplications: Int
    public var shieldedWebDomains: Int
    public var categoryShieldActive: Bool
    public var appGroupAvailable: Bool

    public init(
        monitoredActivities: [String],
        shieldedApplications: Int,
        shieldedWebDomains: Int,
        categoryShieldActive: Bool,
        appGroupAvailable: Bool
    ) {
        self.monitoredActivities = monitoredActivities
        self.shieldedApplications = shieldedApplications
        self.shieldedWebDomains = shieldedWebDomains
        self.categoryShieldActive = categoryShieldActive
        self.appGroupAvailable = appGroupAvailable
    }
}

/// Every side effect the protection engine needs from the operating system.
///
/// The iOS implementation (`ScreenTimePlatform`) wraps FamilyControls, ManagedSettings,
/// and DeviceActivity. Keeping this boundary small is what lets the safety rules
/// (relock ordering, stale callbacks, empty selections, revocation, token expiry) be
/// unit-tested without a device.
public protocol ProtectionPlatform: Sendable {
    associatedtype Selection: ProtectionSelection

    var authorization: ScreenTimeAuthorization { get }
    func requestAuthorization() async throws

    func applyShields(_ selection: Selection)
    func clearShields()

    /// Schedules the relock for one unlock grant. Must throw rather than fail silently.
    func scheduleRelock(_ plan: UnlockPlan, grantID: UUID, selection: Selection, calendar: Calendar) throws
    func ensureDailyGuard() throws
    func stopAllMonitoring()

    /// Refreshes expired tokens in place. Throws when tokens can't be refreshed.
    func refreshExpiredTokens(in selection: inout Selection) throws -> TokenRefreshOutcome

    func diagnostics() -> PlatformDiagnostics
}
