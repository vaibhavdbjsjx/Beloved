import Foundation
import PLCore
@testable import PLProtection
import Testing

private func at(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

@Suite struct UnlockPlannerTests {
    let now = at("2026-10-01T10:00:00Z")

    @Test func shortUnlocksUseUsageThresholdInsideMinimumWindow() {
        let plan = UnlockPlanner.plan(duration: .minutes(5), now: now, calendar: utc)
        #expect(plan.monitoringEnd.timeIntervalSince(plan.monitoringStart) == 15 * 60)
        #expect(plan.usageThreshold == TimeInterval(5 * 60))
    }

    @Test func longerUnlocksUseWallClockWindow() {
        let plan = UnlockPlanner.plan(duration: .minutes(30), now: now, calendar: utc)
        #expect(plan.monitoringEnd == now.addingTimeInterval(30 * 60))
        #expect(plan.usageThreshold == nil)
    }

    @Test func fifteenMinutesIsExactlyTheMinimum() {
        let plan = UnlockPlanner.plan(duration: .minutes(15), now: now, calendar: utc)
        #expect(plan.monitoringEnd.timeIntervalSince(now) == UnlockPlanner.minimumMonitoringInterval)
        #expect(plan.usageThreshold == nil)
    }

    @Test func restOfDayEndsAtMidnight() {
        let plan = UnlockPlanner.plan(duration: .restOfDay, now: now, calendar: utc)
        #expect(plan.monitoringEnd == at("2026-10-02T00:00:00Z"))
    }

    @Test func restOfDayNearMidnightStillMeetsMinimumInterval() {
        let late = at("2026-10-01T23:55:00Z")
        let plan = UnlockPlanner.plan(duration: .restOfDay, now: late, calendar: utc)
        #expect(plan.monitoringEnd == late.addingTimeInterval(15 * 60))
    }

    @Test func everyOfferedDurationProducesAValidSchedule() {
        for duration in UnlockDuration.options {
            let plan = UnlockPlanner.plan(duration: duration, now: now, calendar: utc)
            #expect(plan.monitoringEnd.timeIntervalSince(plan.monitoringStart) >= UnlockPlanner.minimumMonitoringInterval)
            #expect(plan.monitoringEnd.timeIntervalSince(plan.monitoringStart) <= 7 * 24 * 3600, "DeviceActivity maximum is one week")
        }
    }

    @Test func grantMirrorsPlan() {
        let plan = UnlockPlanner.plan(duration: .minutes(5), now: now, calendar: utc)
        let grant = UnlockPlanner.grant(for: plan, sessionID: nil)
        #expect(grant.expiresAt == plan.monitoringEnd)
        #expect(grant.usageLimit == TimeInterval(300))
        #expect(grant.isActive(at: now))
        #expect(!grant.isActive(at: plan.monitoringEnd))
    }
}

@Suite struct ProtectionStatusTests {
    let now = at("2026-10-01T10:00:00Z")
    let on = ProtectionSettings(isEnabled: true, unlockDuration: .minutes(15))

    @Test func derivationOrder() {
        #expect(ProtectionStatus.derive(isSupported: false, isAuthorized: true, hasSelection: true, settings: on, grant: nil, now: now) == .unavailable)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: false, hasSelection: false, settings: .default, grant: nil, now: now) == .needsAuthorization)
        // A saved selection means access was granted before: this is a revocation, not first setup.
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: false, hasSelection: true, settings: on, grant: nil, now: now) == .authorizationRevoked)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: true, needsReselection: true, settings: on, grant: nil, now: now) == .needsReselection)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: false, settings: on, grant: nil, now: now) == .needsSelection)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: true, settings: .default, grant: nil, now: now) == .off)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: true, settings: on, grant: nil, now: now) == .active)
    }

    @Test func activeGrantMeansUnlockedUntilExpiry() {
        let grant = UnlockGrant(grantedAt: now, expiresAt: now.addingTimeInterval(600), usageLimit: nil, sessionID: nil)
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: true, settings: on, grant: grant, now: now)
            == .unlocked(until: grant.expiresAt))
        #expect(ProtectionStatus.derive(isSupported: true, isAuthorized: true, hasSelection: true, settings: on, grant: grant,
                                        now: now.addingTimeInterval(601)) == .active)
    }
}

@Suite struct ProtectionStateStoreTests {
    let now = at("2026-10-01T10:00:00Z")

    @Test func defaultsAndPersistence() {
        let state = ProtectionStateStore(store: InMemoryKeyValueStore())
        #expect(state.settings() == .default)
        state.save(ProtectionSettings(isEnabled: true, unlockDuration: .restOfDay))
        #expect(state.settings().unlockDuration == .restOfDay)
    }

    @Test func expiredGrantsAreNotActive() {
        let state = ProtectionStateStore(store: InMemoryKeyValueStore())
        state.save(UnlockGrant(grantedAt: now, expiresAt: now.addingTimeInterval(60), usageLimit: nil, sessionID: nil))
        #expect(state.activeGrant(at: now) != nil)
        #expect(state.activeGrant(at: now.addingTimeInterval(61)) == nil)
        #expect(state.grant() != nil, "expired grants remain readable until cleared")
    }

    @Test func shieldRequestsExpireAndAreConsumedOnce() {
        let state = ProtectionStateStore(store: InMemoryKeyValueStore())
        state.recordRequest(ShieldRequest(createdAt: now.addingTimeInterval(-11 * 60), subject: .application, tokenData: nil))
        let fresh = ShieldRequest(createdAt: now, subject: .application, tokenData: Data([1, 2]))
        state.recordRequest(fresh)
        #expect(state.pendingRequests(at: now) == [fresh])
        #expect(state.takeLatestRequest(at: now) == fresh)
        #expect(state.takeLatestRequest(at: now) == nil)
    }

    @Test func requestQueueIsBounded() {
        let state = ProtectionStateStore(store: InMemoryKeyValueStore())
        for offset in 0..<20 {
            state.recordRequest(ShieldRequest(createdAt: now.addingTimeInterval(Double(offset)), subject: .category, tokenData: nil))
        }
        #expect(state.pendingRequests(at: now.addingTimeInterval(20)).count == ProtectionStateStore.maxStoredRequests)
    }

    @Test func resetRemovesEverything() {
        let state = ProtectionStateStore(store: InMemoryKeyValueStore())
        state.save(ProtectionSettings(isEnabled: true, unlockDuration: .minutes(5)))
        state.saveSelectionData(Data([9]))
        state.save(ShieldCopy.englishFallback)
        state.reset()
        #expect(state.settings() == .default)
        #expect(state.selectionData() == nil)
        #expect(state.shieldCopy() == nil)
    }

    @Test func shieldTitleUsesAppNameWhenKnown() {
        let copy = ShieldCopy.englishFallback
        #expect(copy.title(forApp: "Instagram") == "You chose to protect Instagram")
        #expect(copy.title(forApp: nil) == copy.title)
        #expect(copy.title(forApp: "") == copy.title)
    }

    @Test func selectionLimitsMatchApplesCaps() {
        #expect(SelectionLimits.validate(applications: 50, categories: 50, webDomains: 50).isEmpty)
        #expect(SelectionLimits.validate(applications: 51, categories: 0, webDomains: 60)
            == [.tooManyApplications(51), .tooManyWebDomains(60)])
    }
}

@Suite struct ScreenTimeNamesTests {
    @Test func relockActivityRoundTripsItsGrant() {
        let grant = UUID()
        #expect(ScreenTimeNames.grantID(fromRelockActivity: ScreenTimeNames.relockActivity(for: grant)) == grant)
    }

    @Test func otherActivitiesHaveNoGrantSoTheirCallbacksAreIgnored() {
        #expect(ScreenTimeNames.grantID(fromRelockActivity: ScreenTimeNames.dailyGuardActivity) == nil)
        #expect(ScreenTimeNames.grantID(fromRelockActivity: ScreenTimeNames.relockUsageEvent) == nil)
        #expect(ScreenTimeNames.grantID(fromRelockActivity: "prayerlock.relock.not-a-uuid") == nil)
        #expect(ScreenTimeNames.grantID(fromRelockActivity: "other.app.\(UUID().uuidString)") == nil)
        #expect(ScreenTimeNames.grantID(fromRelockActivity: "") == nil)
    }

    @Test func distinctGrantsGetDistinctActivities() {
        #expect(ScreenTimeNames.relockActivity(for: UUID()) != ScreenTimeNames.relockActivity(for: UUID()))
    }

    @Test func persistedNamesNeverChange() {
        // Live installs have activities registered under these names.
        #expect(ScreenTimeNames.store == "prayerlock.protection")
        #expect(ScreenTimeNames.dailyGuardActivity == "prayerlock.daily-guard")
        #expect(ScreenTimeNames.relockUsageEvent == "prayerlock.relock.usage")
        let grant = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        #expect(ScreenTimeNames.relockActivity(for: grant) == "prayerlock.relock.00000000-0000-0000-0000-000000000001")
    }
}

@Suite struct ShieldHandOffTests {
    @Test func notNowClosesAndStartsNothing() {
        for supports in [false, true] {
            for enabled in [false, true] {
                let handOff = ShieldHandOff.decide(primaryButton: false, supportsDirectOpen: supports, directOpenEnabled: enabled)
                #expect(handOff == .close)
                #expect(!handOff.startsMoment)
            }
        }
    }

    @Test func beginBeforeIOS265DefersWithNotification() {
        let handOff = ShieldHandOff.decide(primaryButton: true, supportsDirectOpen: false, directOpenEnabled: true)
        #expect(handOff == .deferWithNotification)
        #expect(handOff.startsMoment)
    }

    @Test func beginOpensTheAppOnlyWhenSupportedAndEnabled() {
        #expect(ShieldHandOff.decide(primaryButton: true, supportsDirectOpen: true, directOpenEnabled: true) == .openApp)
        #expect(ShieldHandOff.decide(primaryButton: true, supportsDirectOpen: true, directOpenEnabled: false) == .deferWithNotification)
    }
}
