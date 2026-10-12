import Foundation

public struct SubscriptionDetails: Codable, Hashable, Sendable {
    public var productID: String
    public var plan: SubscriptionPlan?
    public var expiresAt: Date?
    public var willAutoRenew: Bool
    /// The current period is an introductory free trial.
    public var isTrial: Bool
    public var gracePeriodExpiresAt: Date?

    public init(
        productID: String,
        plan: SubscriptionPlan?,
        expiresAt: Date?,
        willAutoRenew: Bool,
        isTrial: Bool,
        gracePeriodExpiresAt: Date? = nil
    ) {
        self.productID = productID
        self.plan = plan
        self.expiresAt = expiresAt
        self.willAutoRenew = willAutoRenew
        self.isTrial = isTrial
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
    }
}

/// The user's subscription situation, independent of StoreKit types (so it can be
/// cached, tested, and rendered).
public enum SubscriptionState: Codable, Hashable, Sendable {
    /// Not determined yet (e.g. first launch while the App Store is unreachable).
    case unknown
    case notSubscribed
    /// Active (including free trials).
    case subscribed(SubscriptionDetails)
    /// Billing failed; Apple's grace period keeps access while payment is retried.
    case inGracePeriod(SubscriptionDetails)
    /// Billing failed and grace period (if any) ended; Apple is still retrying.
    case inBillingRetry(SubscriptionDetails)
    case expired(SubscriptionDetails)
    /// Refunded or revoked by Apple / Family Sharing.
    case revoked

    public var details: SubscriptionDetails? {
        switch self {
        case let .subscribed(d), let .inGracePeriod(d), let .inBillingRetry(d), let .expired(d): d
        case .unknown, .notSubscribed, .revoked: nil
        }
    }
}

public enum AccessLevel: String, Codable, Sendable {
    case free
    case premium
}

/// Maps subscription state to access. Pure and unit-tested; the single source of
/// truth for "is this user premium right now?".
public enum EntitlementResolver {
    public static func accessLevel(for state: SubscriptionState, now: Date) -> AccessLevel {
        switch state {
        case let .subscribed(details):
            // The expiry check protects against a stale cached state granting access forever.
            return isBefore(now, details.expiresAt) ? .premium : .free
        case let .inGracePeriod(details):
            return isBefore(now, details.gracePeriodExpiresAt ?? details.expiresAt) ? .premium : .free
        case .inBillingRetry, .expired, .revoked, .notSubscribed, .unknown:
            return .free
        }
    }

    public static func canUse(
        _ feature: PremiumFeature,
        configuration: MonetizationConfiguration,
        state: SubscriptionState,
        now: Date
    ) -> Bool {
        !configuration.isPremium(feature) || accessLevel(for: state, now: now) == .premium
    }

    private static func isBefore(_ now: Date, _ deadline: Date?) -> Bool {
        guard let deadline else { return true }
        return now < deadline
    }
}

/// A StoreKit-independent snapshot of one `Product.SubscriptionInfo.Status`.
public struct StatusSnapshot: Hashable, Sendable {
    public enum Renewal: Sendable {
        case subscribed
        case inGracePeriod
        case inBillingRetryPeriod
        case expired
        case revoked
        case unrecognized
    }

    public var renewal: Renewal
    public var productID: String
    public var expiresAt: Date?
    public var willAutoRenew: Bool
    public var isTrial: Bool
    public var gracePeriodExpiresAt: Date?
    public var isVerified: Bool

    public init(
        renewal: Renewal,
        productID: String,
        expiresAt: Date?,
        willAutoRenew: Bool,
        isTrial: Bool,
        gracePeriodExpiresAt: Date?,
        isVerified: Bool
    ) {
        self.renewal = renewal
        self.productID = productID
        self.expiresAt = expiresAt
        self.willAutoRenew = willAutoRenew
        self.isTrial = isTrial
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
        self.isVerified = isVerified
    }
}

public enum SubscriptionStateMapper {
    /// Picks the most favourable *verified* status in the subscription group
    /// (a user can have more than one, e.g. their own plus Family Sharing).
    public static func state(
        from snapshots: [StatusSnapshot],
        configuration: MonetizationConfiguration
    ) -> SubscriptionState {
        let verified = snapshots.filter(\.isVerified)

        func rank(_ renewal: StatusSnapshot.Renewal) -> Int {
            switch renewal {
            case .subscribed: 5
            case .inGracePeriod: 4
            case .inBillingRetryPeriod: 3
            case .expired: 2
            case .revoked: 1
            case .unrecognized: 0
            }
        }
        guard let best = verified.max(by: { lhs, rhs in
            rank(lhs.renewal) != rank(rhs.renewal)
                ? rank(lhs.renewal) < rank(rhs.renewal)
                : (lhs.expiresAt ?? .distantPast) < (rhs.expiresAt ?? .distantPast)
        }) else { return .notSubscribed }

        let details = SubscriptionDetails(
            productID: best.productID,
            plan: configuration.plan(forProductID: best.productID),
            expiresAt: best.expiresAt,
            willAutoRenew: best.willAutoRenew,
            isTrial: best.isTrial,
            gracePeriodExpiresAt: best.gracePeriodExpiresAt
        )
        switch best.renewal {
        case .subscribed: return .subscribed(details)
        case .inGracePeriod: return .inGracePeriod(details)
        case .inBillingRetryPeriod: return .inBillingRetry(details)
        case .expired: return .expired(details)
        case .revoked: return .revoked
        case .unrecognized: return .unknown
        }
    }
}
