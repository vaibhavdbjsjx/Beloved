import Foundation
import os
import PLCore

public enum ProtectionError: Error, Equatable, Sendable {
    case notAuthorized
    case noSelection
    case protectionOff
    case schedulingFailed(String)
}

/// App-side orchestration of Screen Time protection, independent of the OS frameworks.
///
/// Safety rules enforced here (all unit-tested with a fake platform):
/// 1. **Relock before release** — an unlock schedules its relock *before* shields are
///    removed; if scheduling fails, shields stay up and no grant is recorded.
/// 2. **Stale signals never win** — relock callbacks for anything but the current grant
///    are ignored (see `RelockService`).
/// 3. **Empty selection removes everything** — clearing every app removes shields and
///    monitoring and turns protection off; nothing stale stays behind.
/// 4. **Self-healing** — `reconcile()` (run on every app activation) re-applies shields
///    after an expired grant and re-creates the daily guard.
/// 5. **No destructive reaction to lost authorization** — choices are kept so protection
///    resumes when access is granted again (iOS can report "not determined" briefly at
///    launch, so revocation must never wipe state).
/// 6. **Expired tokens** — refreshed when the OS supports it; otherwise the user is
///    asked to choose apps again (never a silent failure).
@MainActor
public final class ProtectionEngine<Platform: ProtectionPlatform> {
    public typealias Selection = Platform.Selection

    private let platform: Platform
    private let state: ProtectionStateStore
    private let log = Log.logger(.protection)

    public init(platform: Platform, state: ProtectionStateStore) {
        self.platform = platform
        self.state = state
    }

    // MARK: Authorization

    public var authorization: ScreenTimeAuthorization { platform.authorization }
    public var isAuthorized: Bool { platform.authorization == .approved }

    public func requestAuthorization() async throws {
        state.events.record(.authorizationRequested)
        do {
            try await platform.requestAuthorization()
        } catch {
            state.events.record(.authorizationFailed, detail: String(describing: error))
            throw error
        }
        reconcile()
    }

    // MARK: Selection & settings

    public var selection: Selection { state.selection(Selection.self) ?? Selection() }
    public var settings: ProtectionSettings { state.settings() }

    /// Saves the selection (add, remove, or replace) and applies it immediately.
    /// An empty selection removes all shields and monitoring and turns protection off.
    /// Returns Apple's per-list limit violations (max 50 each) for the UI to explain.
    @discardableResult
    public func updateSelection(_ selection: Selection, now: Date = Date()) -> [SelectionLimits.Issue] {
        state.saveSelection(selection)
        state.setNeedsReselection(false)
        state.events.record(.selectionUpdated, detail: selection.countsDescription, at: now)

        if selection.isEmptySelection {
            state.clearGrant()
            platform.stopAllMonitoring()
            platform.clearShields()
            var settings = state.settings()
            settings.isEnabled = false
            state.save(settings)
            state.events.record(.shieldsCleared, detail: "selection empty", at: now)
        } else {
            reconcile(now: now)
        }
        return selection.limitIssues
    }

    public func setUnlockDuration(_ duration: UnlockDuration) {
        var settings = state.settings()
        settings.unlockDuration = duration
        state.save(settings)
    }

    public func setEnabled(_ enabled: Bool, now: Date = Date()) throws {
        if enabled {
            guard isAuthorized else { throw ProtectionError.notAuthorized }
            guard !selection.isEmptySelection else { throw ProtectionError.noSelection }
        }
        var settings = state.settings()
        settings.isEnabled = enabled
        state.save(settings)

        if enabled {
            state.events.record(.protectionEnabled, at: now)
            reconcile(now: now)
        } else {
            state.clearGrant()
            platform.stopAllMonitoring()
            platform.clearShields()
            state.events.record(.protectionDisabled, at: now)
        }
    }

    // MARK: Unlock

    /// Grants temporary access after a completed prayer moment (rule 1).
    @discardableResult
    public func grantUnlock(sessionID: UUID?, now: Date = Date(), calendar: Calendar = .current) throws -> UnlockGrant {
        let settings = state.settings()
        guard settings.isEnabled else { throw ProtectionError.protectionOff }
        guard isAuthorized else { throw ProtectionError.notAuthorized }
        let selection = self.selection
        guard !selection.isEmptySelection else { throw ProtectionError.noSelection }

        let plan = UnlockPlanner.plan(duration: settings.unlockDuration, now: now, calendar: calendar)
        let grant = UnlockPlanner.grant(for: plan, sessionID: sessionID)
        // Persist first so stale callbacks from replaced activities are recognised.
        let previousGrant = state.grant()
        state.save(grant)
        do {
            try platform.scheduleRelock(plan, grantID: grant.id, selection: selection, calendar: calendar)
        } catch {
            if let previousGrant { state.save(previousGrant) } else { state.clearGrant() }
            state.events.record(.relockSchedulingFailed, detail: String(describing: error), at: now)
            log.error("Relock scheduling failed: \(String(describing: error), privacy: .public)")
            throw ProtectionError.schedulingFailed(String(describing: error))
        }
        platform.clearShields()
        state.events.record(.unlockGranted, detail: Self.describe(plan), at: now)
        return grant
    }

    // MARK: Lifecycle

    /// Safety net, called on every app activation (rule 4).
    public func reconcile(now: Date = Date()) {
        guard state.settings().isEnabled, isAuthorized else { return }
        do {
            try platform.ensureDailyGuard()
        } catch {
            state.events.record(.dailyGuardFailed, detail: String(describing: error), at: now)
        }
        RelockService(platform: platform, state: state).reapplyIfNeeded(now: now)
    }

    /// Refreshes expired Screen Time tokens (rule 6). Call when iOS reports expiry and on
    /// app activation.
    @discardableResult
    public func refreshTokens(now: Date = Date()) -> TokenRefreshOutcome? {
        var refreshed = selection
        guard !refreshed.isEmptySelection else { return nil }
        let before = refreshed
        do {
            let outcome = try platform.refreshExpiredTokens(in: &refreshed)
            guard outcome == .refreshed else { return outcome }
            if refreshed.isEmptySelection {
                // Every token became unusable: ask the user rather than silently disabling.
                state.setNeedsReselection(true)
                state.events.record(.tokenRefreshFailed, detail: "no usable tokens", at: now)
                return outcome
            }
            state.saveSelection(refreshed)
            state.events.record(.tokensRefreshed, detail: "\(before.countsDescription) → \(refreshed.countsDescription)", at: now)
            reconcile(now: now)
            return outcome
        } catch {
            state.setNeedsReselection(true)
            state.events.record(.tokenRefreshFailed, detail: String(describing: error), at: now)
            log.error("Token refresh failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    public func status(now: Date = Date()) -> ProtectionStatus {
        ProtectionStatus.derive(
            isSupported: true,
            isAuthorized: isAuthorized,
            hasSelection: !selection.isEmptySelection,
            needsReselection: state.needsReselection,
            settings: state.settings(),
            grant: state.grant(),
            now: now
        )
    }

    public func diagnostics() -> PlatformDiagnostics { platform.diagnostics() }

    public var recentEvents: [ProtectionEvent] { state.events.recent() }

    /// Removes shields, monitoring, and all shared protection state ("Delete my data").
    public func resetAll() {
        platform.stopAllMonitoring()
        platform.clearShields()
        state.reset()
    }

    static func describe(_ plan: UnlockPlan) -> String {
        let window = Int(plan.monitoringEnd.timeIntervalSince(plan.monitoringStart) / 60)
        if let threshold = plan.usageThreshold {
            return "\(Int(threshold / 60)) min of use within \(window) min"
        }
        return "\(window) min"
    }
}
