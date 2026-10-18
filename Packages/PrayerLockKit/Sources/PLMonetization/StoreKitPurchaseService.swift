import Foundation
import PLCore
import StoreKit

/// StoreKit 2 implementation of `PurchaseService`.
///
/// - Only *verified* transactions (JWS signature checked by StoreKit) grant access.
/// - Transactions are finished only after the entitlement has been recorded.
/// - Not used while `monetization.json` has `isPaywallEnabled: false` (the current
///   release sells nothing); `UnavailablePurchaseService` is used instead.
public final class StoreKitPurchaseService: PurchaseService {
    private let configuration: MonetizationConfiguration
    private let subscriptionGroupID: String?

    public init(configuration: MonetizationConfiguration, subscriptionGroupID: String?) {
        self.configuration = configuration
        self.subscriptionGroupID = subscriptionGroupID
    }

    public func products() async throws -> [StoreProduct] {
        guard configuration.isPaywallEnabled else { throw PurchaseError.notConfigured }
        let storeProducts: [Product]
        do {
            storeProducts = try await Product.products(for: configuration.productIDs)
        } catch {
            throw PurchaseError.storeUnavailable(error.localizedDescription)
        }

        var result: [StoreProduct] = []
        for product in storeProducts {
            guard let plan = configuration.plan(forProductID: product.id), let subscription = product.subscription else {
                continue
            }
            var intro: StoreProduct.IntroductoryOffer?
            if let offer = subscription.introductoryOffer, await subscription.isEligibleForIntroOffer {
                intro = StoreProduct.IntroductoryOffer(
                    paymentMode: Self.paymentMode(offer.paymentMode),
                    periodDescription: Self.describe(offer.period),
                    displayPrice: offer.displayPrice
                )
            }
            result.append(StoreProduct(
                id: product.id,
                plan: plan,
                displayName: product.displayName,
                displayPrice: product.displayPrice,
                periodDescription: Self.describe(subscription.subscriptionPeriod),
                introductoryOffer: intro
            ))
        }
        let order = SubscriptionPlan.allCases
        func rank(_ plan: SubscriptionPlan) -> Int { order.firstIndex(of: plan) ?? order.count }
        return result.sorted { rank($0.plan) < rank($1.plan) }
    }

    public func purchase(productID: String) async throws -> PurchaseOutcome {
        guard configuration.isPaywallEnabled else { throw PurchaseError.notConfigured }
        guard let product = try await Product.products(for: [productID]).first else {
            throw PurchaseError.productNotFound(productID)
        }
        switch try await product.purchase() {
        case let .success(verification):
            guard case let .verified(transaction) = verification else { throw PurchaseError.verificationFailed }
            await transaction.finish()
            let state = await currentState()
            if case .subscribed = state {
                return .purchased(state)
            }
            let details = SubscriptionDetails(
                productID: transaction.productID,
                plan: configuration.plan(forProductID: transaction.productID),
                expiresAt: transaction.expirationDate,
                willAutoRenew: true,
                isTrial: transaction.offer?.paymentMode == .freeTrial,
                gracePeriodExpiresAt: nil
            )
            return .purchased(.subscribed(details))
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    public func restorePurchases() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseError.storeUnavailable(error.localizedDescription)
        }
    }

    public func currentState() async -> SubscriptionState {
        if let subscriptionGroupID {
            do {
                let statuses = try await Product.SubscriptionInfo.status(for: subscriptionGroupID)
                if !statuses.isEmpty {
                    return SubscriptionStateMapper.state(from: statuses.map(Self.snapshot), configuration: configuration)
                }
            } catch {
                Log.logger(.monetization).error("Subscription status unavailable: \(error.localizedDescription, privacy: .public)")
            }
        }
        return await stateFromCurrentEntitlements()
    }

    public func stateUpdates() -> AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            let task = Task {
                for await update in Transaction.updates {
                    if case let .verified(transaction) = update {
                        await transaction.finish()
                    }
                    continuation.yield(await self.currentState())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func subscriptionProof() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  configuration.plan(forProductID: transaction.productID) != nil,
                  transaction.revocationDate == nil,
                  (transaction.expirationDate ?? .distantPast) > Date()
            else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    // MARK: - Mapping

    private func stateFromCurrentEntitlements() async -> SubscriptionState {
        var snapshots: [StatusSnapshot] = []
        let now = Date()
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  configuration.plan(forProductID: transaction.productID) != nil
            else { continue }
            let renewal: StatusSnapshot.Renewal
            if transaction.revocationDate != nil {
                renewal = .revoked
            } else if let expiresAt = transaction.expirationDate, expiresAt <= now {
                renewal = .expired
            } else {
                renewal = .subscribed
            }
            snapshots.append(StatusSnapshot(
                renewal: renewal,
                productID: transaction.productID,
                expiresAt: transaction.expirationDate,
                willAutoRenew: false, // Unknown without renewal info; UI must not claim auto-renewal.
                isTrial: transaction.offer?.paymentMode == .freeTrial,
                gracePeriodExpiresAt: nil,
                isVerified: true
            ))
        }
        return SubscriptionStateMapper.state(from: snapshots, configuration: configuration)
    }

    static func snapshot(_ status: Product.SubscriptionInfo.Status) -> StatusSnapshot {
        let renewal: StatusSnapshot.Renewal = switch status.state {
        case .subscribed: .subscribed
        case .inGracePeriod: .inGracePeriod
        case .inBillingRetryPeriod: .inBillingRetryPeriod
        case .expired: .expired
        case .revoked: .revoked
        default: .unrecognized
        }
        guard case let .verified(transaction) = status.transaction else {
            return StatusSnapshot(
                renewal: renewal, productID: "", expiresAt: nil, willAutoRenew: false,
                isTrial: false, gracePeriodExpiresAt: nil, isVerified: false
            )
        }
        var renewalInfo: Product.SubscriptionInfo.RenewalInfo?
        if case let .verified(info) = status.renewalInfo { renewalInfo = info }
        return StatusSnapshot(
            renewal: renewal,
            productID: transaction.productID,
            expiresAt: transaction.expirationDate,
            willAutoRenew: renewalInfo?.willAutoRenew ?? false,
            isTrial: transaction.offer?.paymentMode == .freeTrial,
            gracePeriodExpiresAt: renewalInfo?.gracePeriodExpirationDate,
            isVerified: true
        )
    }

    static func paymentMode(_ mode: Product.SubscriptionOffer.PaymentMode) -> StoreProduct.IntroductoryOffer.PaymentMode {
        switch mode {
        case .freeTrial: .freeTrial
        case .payAsYouGo: .payAsYouGo
        case .payUpFront: .payUpFront
        default: .other
        }
    }

    static func describe(_ period: Product.SubscriptionPeriod) -> String {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.weekOfMonth = period.value
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: components.day = period.value
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        return formatter.string(from: components) ?? ""
    }
}
