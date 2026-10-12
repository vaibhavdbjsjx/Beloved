import Foundation

public enum PurchaseError: Error, Equatable, Sendable {
    /// Paywall disabled or products not configured for this build.
    case notConfigured
    case productNotFound(String)
    /// StoreKit could not verify the transaction's signature (JWS). Never grant access.
    case verificationFailed
    case storeUnavailable(String)
}

public enum PurchaseOutcome: Equatable, Sendable {
    case purchased(SubscriptionState)
    case cancelled
    /// Awaiting approval (Ask to Buy, SCA). The update arrives via `stateUpdates()`.
    case pending
}

/// A product as shown on the paywall. Every price string comes from StoreKit.
public struct StoreProduct: Identifiable, Hashable, Sendable {
    public struct IntroductoryOffer: Hashable, Sendable {
        public enum PaymentMode: Sendable { case freeTrial, payAsYouGo, payUpFront, other }
        public var paymentMode: PaymentMode
        public var periodDescription: String
        public var displayPrice: String
    }

    public var id: String
    public var plan: SubscriptionPlan
    public var displayName: String
    public var displayPrice: String
    public var periodDescription: String
    /// `nil` when there is no offer or the user is not eligible.
    public var introductoryOffer: IntroductoryOffer?
}

/// Abstraction over the App Store so UI and tests don't depend on StoreKit.
public protocol PurchaseService: Sendable {
    func products() async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    /// "Restore Purchases" (App Store Review requires an accessible restore action).
    func restorePurchases() async throws
    func currentState() async -> SubscriptionState
    /// Transaction updates (renewals, refunds, Ask-to-Buy approvals, other devices).
    func stateUpdates() -> AsyncStream<SubscriptionState>
    /// The App Store's signed proof (JWS) of an active, verified subscription to one of our
    /// products — sent to the companion server, which verifies it with Apple's certificates.
    /// `nil` when there is none.
    func subscriptionProof() async -> String?
}

/// Used while the paywall is disabled. Truthfully reports that nothing is for sale.
public struct UnavailablePurchaseService: PurchaseService {
    public init() {}
    public func products() async throws -> [StoreProduct] { throw PurchaseError.notConfigured }
    public func purchase(productID: String) async throws -> PurchaseOutcome { throw PurchaseError.notConfigured }
    public func restorePurchases() async throws { throw PurchaseError.notConfigured }
    public func currentState() async -> SubscriptionState { .notSubscribed }
    public func stateUpdates() -> AsyncStream<SubscriptionState> { AsyncStream { $0.finish() } }
    public func subscriptionProof() async -> String? { nil }
}
