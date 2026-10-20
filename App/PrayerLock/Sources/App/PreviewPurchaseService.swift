import PLMonetization

/// Development-only: the two real plans as the App Store lists them, so the paywall can be
/// photographed for App Review without a sandbox account. Never used in release builds.
struct PreviewPurchaseService: PurchaseService {
    func products() async throws -> [StoreProduct] {
        let trial = StoreProduct.IntroductoryOffer(paymentMode: .freeTrial, periodDescription: "7 days", displayPrice: "$0.00")
        return [
            StoreProduct(id: "beloved.premium.monthly", plan: .monthly, displayName: "Beloved Premium Monthly",
                         displayPrice: "$5.99", periodDescription: "month", introductoryOffer: trial),
            StoreProduct(id: "beloved.premium.annual", plan: .annual, displayName: "Beloved Premium Annual",
                         displayPrice: "$34.99", periodDescription: "year", introductoryOffer: trial),
        ]
    }
    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func restorePurchases() async throws {}
    func currentState() async -> SubscriptionState { .notSubscribed }
    func stateUpdates() -> AsyncStream<SubscriptionState> { AsyncStream { $0.finish() } }
    func subscriptionProof() async -> String? { nil }
}
