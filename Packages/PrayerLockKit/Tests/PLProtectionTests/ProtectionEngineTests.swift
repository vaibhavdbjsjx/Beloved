import Foundation
import PLCore
@testable import PLProtection
import Testing

// MARK: - Test doubles

/// Stand-in for FamilyActivitySelection.
struct FakeSelection: ProtectionSelection {
    var apps: Set<String>
    var categories: Set<String>
    var sites: Set<String>

    init() { self.init(apps: []) }

    init(apps: Set<String>, categories: Set<String> = [], sites: Set<String> = []) {
        self.apps = apps
        self.categories = categories
        self.sites = sites
    }

    var applicationCount: Int { apps.count }
    var categoryCount: Int { categories.count }
    var webDomainCount: Int { sites.count }
}

struct FakeError: Error, Equatable {}

/// Records every OS-level call in order and models the current shield state.
/// Only used from @MainActor tests, so unsynchronised mutation is safe.
final class FakePlatform: ProtectionPlatform, @unchecked Sendable {
    typealias Selection = FakeSelection

    var authorization: ScreenTimeAuthorization = .approved
    var authorizationError: Error?
    var scheduleError: Error?
    var dailyGuardError: Error?
    var refreshBehavior: (inout FakeSelection) throws -> TokenRefreshOutcome = { _ in .unsupported }

    private(set) var calls: [String] = []
    /// What the system would currently be shielding (`nil` = nothing).
    private(set) var currentShield: FakeSelection?
    private(set) var scheduledGrants: [UUID] = []
    private(set) var lastPlan: UnlockPlan?
    private(set) var dailyGuardScheduled = false

    func requestAuthorization() async throws {
        calls.append("requestAuthorization")
        if let authorizationError { throw authorizationError }
        authorization = .approved
    }

    func applyShields(_ selection: FakeSelection) {
        calls.append("applyShields")
        currentShield = selection
    }

    func clearShields() {
        calls.append("clearShields")
        currentShield = nil
    }

    func scheduleRelock(_ plan: UnlockPlan, grantID: UUID, selection: FakeSelection, calendar: Calendar) throws {
        calls.append("scheduleRelock")
        if let scheduleError { throw scheduleError }
        scheduledGrants.append(grantID)
        lastPlan = plan
    }

    func ensureDailyGuard() throws {
        calls.append("ensureDailyGuard")
        if let dailyGuardError { throw dailyGuardError }
        dailyGuardScheduled = true
    }

    func stopAllMonitoring() {
        calls.append("stopAllMonitoring")
        scheduledGrants.removeAll()
        dailyGuardScheduled = false
    }

    func refreshExpiredTokens(in selection: inout FakeSelection) throws -> TokenRefreshOutcome {
        calls.append("refreshExpiredTokens")
        return try refreshBehavior(&selection)
    }

    func diagnostics() -> PlatformDiagnostics {
        PlatformDiagnostics(
            monitoredActivities: [], shieldedApplications: currentShield?.applicationCount ?? 0,
            shieldedWebDomains: 0, categoryShieldActive: false, appGroupAvailable: true
        )
    }

    func count(_ call: String) -> Int { calls.filter { $0 == call }.count }
}

private let t0 = ISO8601DateFormatter().date(from: "2026-10-01T10:00:00Z")!

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

@MainActor
private struct Harness {
    let platform = FakePlatform()
    let state = ProtectionStateStore(store: InMemoryKeyValueStore())
    let engine: ProtectionEngine<FakePlatform>

    init() { engine = ProtectionEngine(platform: platform, state: state) }

    /// Protection on with the given apps, shields up.
    static func protected(_ apps: Set<String>, duration: UnlockDuration = .minutes(15)) throws -> Harness {
        let harness = Harness()
        harness.engine.setUnlockDuration(duration)
        harness.engine.updateSelection(FakeSelection(apps: apps), now: t0)
        try harness.engine.setEnabled(true, now: t0)
        return harness
    }

    /// A fresh engine over the same persisted state — models the app being relaunched.
    func relaunched() -> ProtectionEngine<FakePlatform> { ProtectionEngine(platform: platform, state: state) }

    func relockSignal(_ grant: UnlockGrant, _ reason: RelockReason = .intervalEnded, at date: Date) {
        RelockService(platform: platform, state: state).handleRelockSignal(grantID: grant.id, reason: reason, now: date)
    }
}

// MARK: - Selection lifecycle

@MainActor
@Suite struct SelectionLifecycleTests {
    @Test func enablingProtectionAppliesShieldsAndDailyGuard() throws {
        let h = try Harness.protected(["a", "b"])
        #expect(h.platform.currentShield == FakeSelection(apps: ["a", "b"]))
        #expect(h.platform.dailyGuardScheduled)
        #expect(h.engine.status(now: t0) == .active)
    }

    /// Regression test for the Phase 1 stale-shield bug.
    @Test func removingAllAppsRemovesShieldsMonitoringAndProtection() throws {
        let h = try Harness.protected(["a", "b"])
        h.engine.updateSelection(FakeSelection(), now: t0)
        #expect(h.platform.currentShield == nil, "no stale shields may remain")
        #expect(h.platform.count("stopAllMonitoring") == 1)
        #expect(!h.platform.dailyGuardScheduled)
        #expect(!h.engine.settings.isEnabled)
        #expect(h.engine.status(now: t0) == .needsSelection)
    }

    /// Same regression, during an active unlock (shields already down, relock pending).
    @Test func removingAllAppsDuringUnlockCancelsThePendingRelock() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        h.engine.updateSelection(FakeSelection(), now: t0.addingTimeInterval(60))
        #expect(h.state.grant() == nil)
        #expect(h.platform.scheduledGrants.isEmpty)
        // A late callback from the cancelled relock must not re-shield anything.
        h.relockSignal(grant, at: t0.addingTimeInterval(900))
        #expect(h.platform.currentShield == nil)
    }

    @Test func removingOneAppReappliesTheRemainder() throws {
        let h = try Harness.protected(["a", "b"])
        h.engine.updateSelection(FakeSelection(apps: ["a"]), now: t0)
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
        #expect(h.engine.settings.isEnabled)
    }

    @Test func replacingTheSelectionAppliesTheReplacement() throws {
        let h = try Harness.protected(["a"])
        h.engine.updateSelection(FakeSelection(apps: ["x", "y"], categories: ["social"]), now: t0)
        #expect(h.platform.currentShield == FakeSelection(apps: ["x", "y"], categories: ["social"]))
    }

    @Test func changesDuringAnUnlockTakeEffectAtRelock() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        h.engine.updateSelection(FakeSelection(apps: ["a", "b", "c"]), now: t0.addingTimeInterval(60))
        #expect(h.platform.currentShield == nil, "the user's unlock is honoured")
        h.relockSignal(grant, at: grant.expiresAt)
        #expect(h.platform.currentShield == FakeSelection(apps: ["a", "b", "c"]))
    }

    @Test func enablingRequiresAuthorizationAndASelection() {
        let h = Harness()
        #expect(throws: ProtectionError.noSelection) { try h.engine.setEnabled(true, now: t0) }
        h.platform.authorization = .denied
        h.engine.updateSelection(FakeSelection(apps: ["a"]), now: t0)
        #expect(throws: ProtectionError.notAuthorized) { try h.engine.setEnabled(true, now: t0) }
    }

    @Test func turningProtectionOffRemovesShieldsAndMonitoring() throws {
        let h = try Harness.protected(["a"])
        _ = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        try h.engine.setEnabled(false, now: t0)
        #expect(h.platform.currentShield == nil)
        #expect(h.platform.scheduledGrants.isEmpty)
        #expect(h.state.grant() == nil)
        #expect(h.engine.status(now: t0) == .off)
    }

    @Test func selectionLimitsAreReported() {
        let h = Harness()
        let tooMany = FakeSelection(apps: Set((0..<51).map(String.init)))
        #expect(h.engine.updateSelection(tooMany, now: t0) == [.tooManyApplications(51)])
    }
}

// MARK: - Unlock & relock safety

@MainActor
@Suite struct UnlockAndRelockTests {
    @Test func relockIsScheduledBeforeShieldsAreRemoved() throws {
        let h = try Harness.protected(["a"])
        _ = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let schedule = try #require(h.platform.calls.lastIndex(of: "scheduleRelock"))
        let clear = try #require(h.platform.calls.lastIndex(of: "clearShields"))
        #expect(schedule < clear)
        #expect(h.engine.status(now: t0) == .unlocked(until: t0.addingTimeInterval(900)))
    }

    @Test func failedSchedulingKeepsShieldsUp() throws {
        let h = try Harness.protected(["a"])
        h.platform.scheduleError = FakeError()
        #expect(throws: ProtectionError.self) { try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc) }
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]), "never unlock without a relock")
        #expect(h.state.grant() == nil)
        #expect(h.engine.recentEvents.first?.kind == .relockSchedulingFailed)
    }

    @Test func failedSchedulingKeepsTheExistingUnlock() throws {
        let h = try Harness.protected(["a"])
        let first = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        h.platform.scheduleError = FakeError()
        #expect(throws: ProtectionError.self) {
            try h.engine.grantUnlock(sessionID: nil, now: t0.addingTimeInterval(60), calendar: utc)
        }
        #expect(h.state.grant()?.id == first.id)
    }

    @Test func staleRelockSignalNeverCancelsANewerUnlock() throws {
        let h = try Harness.protected(["a"])
        let first = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let second = try h.engine.grantUnlock(sessionID: nil, now: t0.addingTimeInterval(120), calendar: utc)

        // stopMonitoring on the first grant's activity fires its intervalDidEnd late.
        h.relockSignal(first, at: t0.addingTimeInterval(130))
        #expect(h.platform.currentShield == nil)
        #expect(h.state.grant()?.id == second.id)
        #expect(h.engine.recentEvents.first?.kind == .staleRelockIgnored)

        h.relockSignal(second, at: second.expiresAt)
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
        #expect(h.state.grant() == nil)
    }

    /// The monitor extension maps each callback's activity name through `ScreenTimeNames`;
    /// names that carry no grant (the daily guard's own interval ending, foreign or malformed
    /// names) must never end an active unlock.
    @Test func callbacksWithoutAGrantNeverCancelAnActiveUnlock() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let service = RelockService(platform: h.platform, state: h.state)
        for name in [ScreenTimeNames.dailyGuardActivity, "prayerlock.relock.not-a-uuid", "other.app.activity", ""] {
            service.handleRelockSignal(
                grantID: ScreenTimeNames.grantID(fromRelockActivity: name),
                reason: .intervalEnded,
                now: t0.addingTimeInterval(60)
            )
        }
        #expect(h.state.grant()?.id == grant.id)
        #expect(h.platform.currentShield == nil)
    }

    /// End-to-end through the real name mapping: the activity name scheduled for a grant
    /// is the one whose callback relocks it.
    @Test func relockActivityNameRoundTripsThroughTheMonitorPath() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let scheduledName = ScreenTimeNames.relockActivity(for: grant.id)
        RelockService(platform: h.platform, state: h.state).handleRelockSignal(
            grantID: ScreenTimeNames.grantID(fromRelockActivity: scheduledName),
            reason: .intervalEnded,
            now: grant.expiresAt
        )
        #expect(h.state.grant() == nil)
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
    }

    @Test func shortUnlockUsesUsageThresholdAndRelocksOnIt() throws {
        let h = try Harness.protected(["a"], duration: .minutes(5))
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let plan = try #require(h.platform.lastPlan)
        #expect(plan.usageThreshold == TimeInterval(300))
        #expect(plan.monitoringEnd.timeIntervalSince(plan.monitoringStart) == UnlockPlanner.minimumMonitoringInterval)

        // Threshold reached after 5 minutes of use, before the 15-minute window ends.
        h.relockSignal(grant, .usageLimitReached, at: t0.addingTimeInterval(400))
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
    }

    @Test func relockAfterProtectionWasTurnedOffDoesNothing() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        try h.engine.setEnabled(false, now: t0.addingTimeInterval(10))
        h.relockSignal(grant, at: grant.expiresAt)
        #expect(h.platform.currentShield == nil)
    }

    @Test func unlockRequiresProtectionOnAndAuthorization() throws {
        let h = try Harness.protected(["a"])
        h.platform.authorization = .notDetermined
        #expect(throws: ProtectionError.notAuthorized) { try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc) }
        h.platform.authorization = .approved
        try h.engine.setEnabled(false, now: t0)
        #expect(throws: ProtectionError.protectionOff) { try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc) }
    }

    /// If the app crashes or is killed mid-unlock, protection must still come back.
    @Test func relaunchAfterExpiredUnlockReappliesShields() throws {
        let h = try Harness.protected(["a"])
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)

        let relaunched = h.relaunched()
        relaunched.reconcile(now: t0.addingTimeInterval(60))
        #expect(h.platform.currentShield == nil, "an active unlock survives a relaunch")

        relaunched.reconcile(now: grant.expiresAt.addingTimeInterval(1))
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]), "missed relock is healed")
        #expect(h.state.grant() == nil)
    }

    @Test func dailyGuardRespectsActiveUnlockAndHealsExpiredOne() throws {
        let h = try Harness.protected(["a"], duration: .restOfDay)
        let grant = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        let service = RelockService(platform: h.platform, state: h.state)
        service.handleDailyGuard(now: t0.addingTimeInterval(3600))
        #expect(h.platform.currentShield == nil)
        service.handleDailyGuard(now: grant.expiresAt.addingTimeInterval(1))
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
    }

    @Test func reconcileRecreatesAMissingDailyGuard() throws {
        let h = try Harness.protected(["a"])
        let before = h.platform.count("ensureDailyGuard")
        h.engine.reconcile(now: t0)
        #expect(h.platform.count("ensureDailyGuard") == before + 1)
    }

    @Test func dailyGuardFailureDoesNotBlockProtection() throws {
        let h = Harness()
        h.platform.dailyGuardError = FakeError()
        h.engine.updateSelection(FakeSelection(apps: ["a"]), now: t0)
        try h.engine.setEnabled(true, now: t0)
        #expect(h.platform.currentShield == FakeSelection(apps: ["a"]))
        #expect(h.engine.recentEvents.contains { $0.kind == .dailyGuardFailed })
    }
}

// MARK: - Authorization & token lifecycle

@MainActor
@Suite struct AuthorizationAndTokenTests {
    @Test func deniedAtFirstSetupIsNotARecoveryCase() async {
        let h = Harness()
        h.platform.authorization = .denied
        #expect(h.engine.status(now: t0) == .needsAuthorization)
        h.platform.authorizationError = FakeError()
        await #expect(throws: FakeError.self) { try await h.engine.requestAuthorization() }
        #expect(h.engine.recentEvents.first?.kind == .authorizationFailed)
    }

    @Test func grantingAuthorizationThenReconciles() async throws {
        let h = Harness()
        h.platform.authorization = .notDetermined
        try await h.engine.requestAuthorization()
        #expect(h.engine.isAuthorized)
        #expect(h.engine.status(now: t0) == .needsSelection)
    }

    @Test func revokedAuthorizationShowsRecoveryAndKeepsChoices() throws {
        let h = try Harness.protected(["a"])
        let appliedBefore = h.platform.count("applyShields")

        h.platform.authorization = .notDetermined // turned off in Settings
        #expect(h.engine.status(now: t0) == .authorizationRevoked)
        h.engine.reconcile(now: t0)
        #expect(h.platform.count("applyShields") == appliedBefore, "no work while unauthorized")
        #expect(h.engine.selection == FakeSelection(apps: ["a"]), "choices are kept for recovery")
        #expect(h.engine.settings.isEnabled)

        h.platform.authorization = .approved // user allows access again
        h.engine.reconcile(now: t0)
        #expect(h.engine.status(now: t0) == .active)
        #expect(h.platform.count("applyShields") == appliedBefore + 1)
    }

    @Test func unsupportedTokenRefreshChangesNothing() throws {
        let h = try Harness.protected(["a"])
        #expect(h.engine.refreshTokens(now: t0) == .unsupported)
        #expect(h.engine.selection == FakeSelection(apps: ["a"]))
    }

    @Test func refreshedTokensAreSavedAndReapplied() throws {
        let h = try Harness.protected(["a"])
        h.platform.refreshBehavior = { selection in
            selection.apps = ["a-refreshed"]
            return .refreshed
        }
        #expect(h.engine.refreshTokens(now: t0) == .refreshed)
        #expect(h.engine.selection == FakeSelection(apps: ["a-refreshed"]))
        #expect(h.platform.currentShield == FakeSelection(apps: ["a-refreshed"]))
        #expect(h.engine.recentEvents.contains { $0.kind == .tokensRefreshed })
    }

    @Test func unrefreshableTokensAskTheUserToChooseAgain() throws {
        let h = try Harness.protected(["a"])
        h.platform.refreshBehavior = { _ in throw FakeError() }
        #expect(h.engine.refreshTokens(now: t0) == nil)
        #expect(h.engine.status(now: t0) == .needsReselection)
        #expect(h.engine.status(now: t0).needsRecovery)

        h.engine.updateSelection(FakeSelection(apps: ["a"]), now: t0)
        #expect(h.engine.status(now: t0) == .active)
    }

    @Test func refreshThatLosesEveryTokenDoesNotSilentlyDisableProtection() throws {
        let h = try Harness.protected(["a"])
        h.platform.refreshBehavior = { selection in
            selection = FakeSelection()
            return .refreshed
        }
        h.engine.refreshTokens(now: t0)
        #expect(h.engine.status(now: t0) == .needsReselection)
        #expect(h.engine.selection == FakeSelection(apps: ["a"]), "old choice kept until the user reselects")
        #expect(h.engine.settings.isEnabled)
    }

    @Test func resetRemovesEverything() throws {
        let h = try Harness.protected(["a"])
        _ = try h.engine.grantUnlock(sessionID: nil, now: t0, calendar: utc)
        h.engine.resetAll()
        #expect(h.platform.currentShield == nil)
        #expect(h.platform.scheduledGrants.isEmpty)
        #expect(h.engine.selection.isEmptySelection)
        #expect(h.state.grant() == nil)
        #expect(h.engine.recentEvents.isEmpty)
    }
}

@Suite struct ProtectionEventLogTests {
    @Test func boundedAndNewestFirst() {
        let log = ProtectionEventLog(store: InMemoryKeyValueStore())
        for index in 0..<(ProtectionEventLog.capacity + 20) {
            log.record(.shieldsApplied, detail: "\(index)", at: t0.addingTimeInterval(Double(index)))
        }
        let events = log.recent()
        #expect(events.count == ProtectionEventLog.capacity)
        #expect(events.first?.detail == "\(ProtectionEventLog.capacity + 19)")
    }
}
