import Foundation
@testable import PLMonetization
import Testing

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let config = MonetizationConfiguration(
    isPaywallEnabled: true,
    products: [.init(id: "p.weekly", plan: .weekly), .init(id: "p.annual", plan: .annual)],
    premiumFeatures: [.assistant]
)

private func details(expires: TimeInterval?, grace: TimeInterval? = nil, trial: Bool = false) -> SubscriptionDetails {
    SubscriptionDetails(
        productID: "p.annual", plan: .annual,
        expiresAt: expires.map { now.addingTimeInterval($0) },
        willAutoRenew: true, isTrial: trial,
        gracePeriodExpiresAt: grace.map { now.addingTimeInterval($0) }
    )
}

@Suite struct EntitlementResolverTests {
    @Test func activeAndTrialSubscriptionsArePremium() {
        #expect(EntitlementResolver.accessLevel(for: .subscribed(details(expires: 3600)), now: now) == .premium)
        #expect(EntitlementResolver.accessLevel(for: .subscribed(details(expires: 3600, trial: true)), now: now) == .premium)
    }

    @Test func staleCachedSubscriptionExpires() {
        #expect(EntitlementResolver.accessLevel(for: .subscribed(details(expires: -1)), now: now) == .free)
    }

    @Test func gracePeriodKeepsAccessUntilGraceEnds() {
        #expect(EntitlementResolver.accessLevel(for: .inGracePeriod(details(expires: -3600, grace: 3600)), now: now) == .premium)
        #expect(EntitlementResolver.accessLevel(for: .inGracePeriod(details(expires: -7200, grace: -1)), now: now) == .free)
    }

    @Test func everythingElseIsFree() {
        for state: SubscriptionState in [.unknown, .notSubscribed, .revoked, .expired(details(expires: -1)), .inBillingRetry(details(expires: -1))] {
            #expect(EntitlementResolver.accessLevel(for: state, now: now) == .free, "\(state)")
        }
    }

    @Test func featureGating() {
        #expect(EntitlementResolver.canUse(.journal, configuration: config, state: .notSubscribed, now: now), "non-premium feature")
        #expect(!EntitlementResolver.canUse(.assistant, configuration: config, state: .notSubscribed, now: now))
        #expect(EntitlementResolver.canUse(.assistant, configuration: config, state: .subscribed(details(expires: 60)), now: now))
    }
}

@Suite struct SubscriptionStateMapperTests {
    func snapshot(_ renewal: StatusSnapshot.Renewal, _ product: String = "p.annual", expires: TimeInterval = 3600, verified: Bool = true) -> StatusSnapshot {
        StatusSnapshot(renewal: renewal, productID: product, expiresAt: now.addingTimeInterval(expires),
                       willAutoRenew: true, isTrial: false, gracePeriodExpiresAt: nil, isVerified: verified)
    }

    @Test func noStatusesMeansNotSubscribed() {
        #expect(SubscriptionStateMapper.state(from: [], configuration: config) == .notSubscribed)
    }

    @Test func unverifiedTransactionsNeverGrantAccess() {
        #expect(SubscriptionStateMapper.state(from: [snapshot(.subscribed, verified: false)], configuration: config) == .notSubscribed)
    }

    @Test func picksMostFavourableStatusAndMapsPlan() {
        let state = SubscriptionStateMapper.state(
            from: [snapshot(.expired, "p.weekly"), snapshot(.subscribed, "p.annual"), snapshot(.inBillingRetryPeriod, "p.weekly")],
            configuration: config
        )
        guard case let .subscribed(details) = state else {
            Issue.record("expected subscribed, got \(state)")
            return
        }
        #expect(details.plan == .annual)
    }

    @Test func mapsEveryRenewalState() {
        #expect(SubscriptionStateMapper.state(from: [snapshot(.revoked)], configuration: config) == .revoked)
        if case .inGracePeriod = SubscriptionStateMapper.state(from: [snapshot(.inGracePeriod)], configuration: config) {} else {
            Issue.record("expected grace period")
        }
    }
}

@Suite struct MonetizationConfigurationTests {
    @Test func bundledConfigurationHasNoPricesAndPaywallIsOff() throws {
        let bundled = try MonetizationConfiguration.bundled()
        #expect(!bundled.isPaywallEnabled, "No purchase UI until products exist in App Store Connect")
        #expect(Set(bundled.products.map(\.plan)) == [.monthly, .annual])
        #expect(Set(bundled.productIDs).count == bundled.productIDs.count)

        let url = try #require(MonetizationConfiguration.bundledResourceURL)
        let raw = try String(contentsOf: url, encoding: .utf8).lowercased()
        #expect(!raw.contains("price"), "Prices must come from StoreKit, never from config")
    }

    @Test func unavailableServiceIsHonest() async {
        let service = UnavailablePurchaseService()
        await #expect(throws: PurchaseError.notConfigured) { try await service.products() }
        #expect(await service.currentState() == .notSubscribed)
    }
}
