# Monetization architecture

Status: architecture implemented and unit-tested; **paywall disabled** (`isPaywallEnabled:
false`); **no prices anywhere** — pricing awaits market research.

## Components (`PLMonetization`)

| Component | Role |
|---|---|
| `monetization.json` | product IDs per plan (`prayerlock.premium.weekly / monthly / annual`), premium feature list, paywall switch |
| `PurchaseService` (protocol) | products, purchase, restore, current state, live updates |
| `StoreKitPurchaseService` | StoreKit 2: `Product.products`, `product.purchase()`, `AppStore.sync()`, `Product.SubscriptionInfo.status(for:)`, `Transaction.updates`/`currentEntitlements`; only *verified* transactions count; finishes transactions after recording |
| `UnavailablePurchaseService` | used while the paywall is off — reports truthfully that nothing is for sale |
| `SubscriptionState` | unknown · notSubscribed · subscribed (incl. trial) · inGracePeriod · inBillingRetry · expired · revoked |
| `SubscriptionStateMapper` | picks the best *verified* status in the group (own vs Family Sharing) |
| `EntitlementResolver` | the single answer to "premium right now?": subscribed → premium until expiry; grace period → premium until grace ends; billing retry / expired / revoked / unknown → free |
| `canUse(feature)` | feature gating driven by config, not by UI code |

All prices shown to users come from `Product.displayPrice` / offer `displayPrice` (localized by
the App Store). Introductory offers are shown only when `isEligibleForIntroOffer`.

## To launch subscriptions

1. Decide pricing and free/premium split (product decision; keep the core lock loop useful for free — a common criticism of the category is "no meaningful free tier").
2. Create the subscription group + 3 products in App Store Connect; set `PL_SUBSCRIPTION_GROUP_ID`.
3. Add a `.storekit` configuration file for local testing (prices there are test-only).
4. Build the paywall UI (Guideline 3.1.2 disclosures: price, period, what's included, auto-renewal terms, links to Terms/Privacy, Restore).
5. Flip `isPaywallEnabled` → true; add StoreKitTest-based tests.
6. Optional later: App Store Server Notifications V2 + server entitlement mirror (only if accounts or cross-platform entitlements are introduced).
