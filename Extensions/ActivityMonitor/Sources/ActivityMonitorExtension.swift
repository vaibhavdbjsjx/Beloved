import DeviceActivity
import Foundation
import PLCore
import PLProtection

/// Re-applies shields when an unlock window ends. All decisions are made by the shared,
/// unit-tested `RelockService`:
/// - `intervalDidEnd` of a per-grant relock activity → re-shield; callbacks for any grant
///   other than the current one are ignored (`stopMonitoring` also fires `intervalDidEnd`).
/// - `eventDidReachThreshold` → short unlocks end after N minutes of *use*.
/// - `intervalDidStart` of the daily guard → safety-net re-shield each day.
///
/// Extensions run with tight memory limits: keep this file free of heavy work.
final class ActivityMonitorExtension: DeviceActivityMonitor {
    private let relock: RelockService<ScreenTimePlatform> = {
        let appGroup = AppConfiguration.fromBundle().appGroupIdentifier
        return RelockService(
            platform: ScreenTimePlatform(appGroupIdentifier: appGroup),
            state: .shared(appGroupIdentifier: appGroup)
        )
    }()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if activity == ScreenTimeIdentifiers.dailyGuardActivity {
            relock.handleDailyGuard(now: Date())
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        relock.handleRelockSignal(
            grantID: ScreenTimeIdentifiers.grantID(fromRelockActivity: activity),
            reason: .intervalEnded,
            now: Date()
        )
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard event == ScreenTimeIdentifiers.relockUsageEvent else { return }
        relock.handleRelockSignal(
            grantID: ScreenTimeIdentifiers.grantID(fromRelockActivity: activity),
            reason: .usageLimitReached,
            now: Date()
        )
    }
}
