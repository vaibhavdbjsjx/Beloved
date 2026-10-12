#if os(iOS)
@preconcurrency import DeviceActivity
@preconcurrency import FamilyControls
import Foundation
@preconcurrency import ManagedSettings
import PLCore

/// The engine used by the app: `ProtectionEngine` over the real Screen Time frameworks.
public typealias ScreenTimeProtectionController = ProtectionEngine<ScreenTimePlatform>

/// Names shared by the app and its extensions. Computed (not stored) so Swift 6
/// concurrency checking doesn't flag non-Sendable framework types in statics.
public enum ScreenTimeIdentifiers {
    public static var storeName: ManagedSettingsStore.Name { .init(ScreenTimeNames.store) }
    public static var dailyGuardActivity: DeviceActivityName { .init(ScreenTimeNames.dailyGuardActivity) }
    public static var relockUsageEvent: DeviceActivityEvent.Name { .init(ScreenTimeNames.relockUsageEvent) }

    /// One activity per grant. `stopMonitoring` fires `intervalDidEnd` for a stopped
    /// activity (documented SDK behaviour); per-grant names let the monitor extension
    /// recognise and ignore those stale callbacks.
    public static func relockActivity(for grantID: UUID) -> DeviceActivityName {
        .init(ScreenTimeNames.relockActivity(for: grantID))
    }

    public static func grantID(fromRelockActivity activity: DeviceActivityName) -> UUID? {
        ScreenTimeNames.grantID(fromRelockActivity: activity.rawValue)
    }
}

extension FamilyActivitySelection: ProtectionSelection {
    public var applicationCount: Int { applicationTokens.count }
    public var categoryCount: Int { categoryTokens.count }
    public var webDomainCount: Int { webDomainTokens.count }
}

/// `ProtectionPlatform` backed by FamilyControls, ManagedSettings, and DeviceActivity.
///
/// Stateless: framework objects are created per call, so the same value is safe to use
/// from the app and from extension callbacks on any thread.
public struct ScreenTimePlatform: ProtectionPlatform {
    public typealias Selection = FamilyActivitySelection

    public let appGroupIdentifier: String?

    public init(appGroupIdentifier: String?) {
        self.appGroupIdentifier = appGroupIdentifier
    }

    private var store: ManagedSettingsStore { ManagedSettingsStore(named: ScreenTimeIdentifiers.storeName) }

    // MARK: Authorization

    public var authorization: ScreenTimeAuthorization {
        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved: return .approved
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        default:
            if #available(iOS 26.4, *), status == .approvedWithDataAccess { return .approved }
            return .notDetermined
        }
    }

    /// `.individual`: self-management of the user's own device (iOS 16+), confirmed with
    /// Face ID / Touch ID / passcode, revocable any time in Settings. Never `.child`.
    public func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    // MARK: Shields

    public func applyShields(_ selection: FamilyActivitySelection) {
        let store = self.store
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
    }

    public func clearShields() {
        store.clearAllSettings()
    }

    // MARK: Monitoring

    public func scheduleRelock(
        _ plan: UnlockPlan,
        grantID: UUID,
        selection: FamilyActivitySelection,
        calendar: Calendar
    ) throws {
        let center = DeviceActivityCenter()
        let name = ScreenTimeIdentifiers.relockActivity(for: grantID)
        let schedule = DeviceActivitySchedule(
            intervalStart: Self.components(plan.monitoringStart, calendar),
            intervalEnd: Self.components(plan.monitoringEnd, calendar),
            repeats: false
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if let threshold = plan.usageThreshold {
            let seconds = Int(threshold.rounded())
            events[ScreenTimeIdentifiers.relockUsageEvent] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: seconds / 60, second: seconds % 60),
                // Only count use *after* this unlock (iOS 17.4+ API; explicit, not defaulted).
                includesPastActivity: false
            )
        }
        try center.startMonitoring(name, during: schedule, events: events)
        // Retire previous relock activities only after the new one is in place.
        let stale = center.activities.filter {
            ScreenTimeIdentifiers.grantID(fromRelockActivity: $0) != nil && $0 != name
        }
        if !stale.isEmpty { center.stopMonitoring(stale) }
    }

    /// A repeating all-day schedule whose `intervalDidStart` re-applies shields every
    /// day — a safety net in case a relock callback is ever missed.
    public func ensureDailyGuard() throws {
        let center = DeviceActivityCenter()
        guard !center.activities.contains(ScreenTimeIdentifiers.dailyGuardActivity) else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        try center.startMonitoring(ScreenTimeIdentifiers.dailyGuardActivity, during: schedule)
    }

    public func stopAllMonitoring() {
        DeviceActivityCenter().stopMonitoring()
    }

    // MARK: Tokens

    /// iOS 26.5+ can refresh expired tokens (`ManagedSettingsStore.refresh`). Earlier
    /// versions have no API for this.
    public func refreshExpiredTokens(in selection: inout FamilyActivitySelection) throws -> TokenRefreshOutcome {
        guard #available(iOS 26.5, *) else { return .unsupported }
        var applications = Array(selection.applicationTokens)
        var categories = Array(selection.categoryTokens)
        var webDomains = Array(selection.webDomainTokens)
        if !applications.isEmpty { try ManagedSettingsStore.refresh(&applications) }
        if !categories.isEmpty { try ManagedSettingsStore.refresh(&categories) }
        if !webDomains.isEmpty { try ManagedSettingsStore.refresh(&webDomains) }

        var updated = selection
        updated.applicationTokens = Set(applications)
        updated.categoryTokens = Set(categories)
        updated.webDomainTokens = Set(webDomains)
        guard updated != selection else { return .unchanged }
        selection = updated
        return .refreshed
    }

    /// Observes iOS 26.5's token-expiry message. Keep the returned token alive.
    @available(iOS 26.5, *)
    public static func observeTokenExpiry(
        _ handler: @escaping @Sendable () async -> Void
    ) -> NotificationCenter.ObservationToken {
        NotificationCenter.default.addObserver(of: ManagedSettingsStore.self, for: .tokensDidExpire) { _ in
            await handler()
        }
    }

    // MARK: Diagnostics

    public func diagnostics() -> PlatformDiagnostics {
        let store = self.store
        return PlatformDiagnostics(
            monitoredActivities: DeviceActivityCenter().activities.map(\.rawValue).sorted(),
            shieldedApplications: store.shield.applications?.count ?? 0,
            shieldedWebDomains: store.shield.webDomains?.count ?? 0,
            categoryShieldActive: store.shield.applicationCategories != nil,
            appGroupAvailable: appGroupIdentifier.flatMap {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
            } != nil
        )
    }

    static func components(_ date: Date, _ calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }
}
#endif
