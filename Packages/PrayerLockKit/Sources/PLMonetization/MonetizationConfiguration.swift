import Foundation
import PLCore

public enum SubscriptionPlan: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case annual
}

/// Features that may be gated behind Premium. *Which* features are premium is a
/// product decision expressed in `monetization.json`, not hard-coded in UI.
public enum PremiumFeature: String, Codable, CaseIterable, Sendable {
    case assistant
    case fullLibrary
    case extendedInsights
    case journal
    case multipleSchedules
    case additionalLanguages
}

/// Product identifiers and gating policy. Contains **no prices**: prices are set in
/// App Store Connect and displayed from StoreKit (`Product.displayPrice`) only.
public struct MonetizationConfiguration: Codable, Hashable, Sendable {
    public struct ProductDefinition: Codable, Hashable, Sendable {
        public var id: String
        public var plan: SubscriptionPlan

        public init(id: String, plan: SubscriptionPlan) {
            self.id = id
            self.plan = plan
        }
    }

    /// `false` until the products exist in App Store Connect. While disabled, the app
    /// must not show any purchase UI.
    public var isPaywallEnabled: Bool
    public var products: [ProductDefinition]
    public var premiumFeatures: [PremiumFeature]

    public init(isPaywallEnabled: Bool, products: [ProductDefinition], premiumFeatures: [PremiumFeature]) {
        self.isPaywallEnabled = isPaywallEnabled
        self.products = products
        self.premiumFeatures = premiumFeatures
    }

    public var productIDs: [String] { products.map(\.id) }

    public func plan(forProductID id: String) -> SubscriptionPlan? {
        products.first { $0.id == id }?.plan
    }

    public func isPremium(_ feature: PremiumFeature) -> Bool { premiumFeatures.contains(feature) }

    static var bundledResourceURL: URL? { Bundle.module.url(forResource: "monetization", withExtension: "json") }

    public static func bundled() throws -> MonetizationConfiguration {
        guard let url = bundledResourceURL else {
            throw PurchaseError.notConfigured
        }
        return try JSONDecoder.prayerLock().decode(MonetizationConfiguration.self, from: Data(contentsOf: url))
    }
}
