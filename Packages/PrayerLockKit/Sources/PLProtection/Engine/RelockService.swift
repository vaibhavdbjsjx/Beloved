import Foundation

/// Why a relock signal arrived.
public enum RelockReason: String, Sendable {
    /// The unlock window's DeviceActivity interval ended.
    case intervalEnded
    /// The usage threshold of a short unlock was reached.
    case usageLimitReached
}

/// Re-shield rules shared by the app and the DeviceActivity monitor extension.
///
/// Not actor-isolated: the monitor extension calls it synchronously from system callbacks.
public struct RelockService<Platform: ProtectionPlatform> {
    private let platform: Platform
    private let state: ProtectionStateStore

    public init(platform: Platform, state: ProtectionStateStore) {
        self.platform = platform
        self.state = state
    }

    /// Re-applies shields when protection is on, something is selected, and no unlock
    /// grant is active. Idempotent — safe to call on every app activation.
    @discardableResult
    public func reapplyIfNeeded(now: Date) -> Bool {
        let settings = state.settings()
        guard settings.isEnabled,
              let selection = state.selection(Platform.Selection.self),
              !selection.isEmptySelection
        else { return false }
        if state.activeGrant(at: now) != nil { return false }
        if state.grant() != nil { state.clearGrant() }
        platform.applyShields(selection)
        state.events.record(.shieldsApplied, detail: selection.countsDescription, at: now)
        return true
    }

    /// Handles the end of an unlock window. Signals for any grant other than the current
    /// one are stale (e.g. `stopMonitoring` fires `intervalDidEnd` for replaced grants)
    /// and must never cancel a newer unlock.
    public func handleRelockSignal(grantID: UUID?, reason: RelockReason, now: Date) {
        guard let grantID else { return }
        guard state.grant()?.id == grantID else {
            state.events.record(.staleRelockIgnored, detail: reason.rawValue, at: now)
            return
        }
        state.clearGrant()
        state.events.record(.relockFired, detail: reason.rawValue, at: now)
        reapplyIfNeeded(now: now)
    }

    /// The daily safety net: re-shield unless an unlock is genuinely active.
    public func handleDailyGuard(now: Date) {
        state.events.record(.dailyGuardFired, at: now)
        reapplyIfNeeded(now: now)
    }
}
