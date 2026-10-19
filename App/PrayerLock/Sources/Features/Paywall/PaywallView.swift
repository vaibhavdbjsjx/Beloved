import PLDesign
import PLMonetization
import SwiftUI

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var products: [StoreProduct] = []
    @State private var selectedID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                header
                featureList
                productsSection
                actions
                legal
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle("Beloved Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProducts() }
        .onChange(of: model.accessLevel) { _, access in
            if access == .premium { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            ThresholdWindow(width: 88, light: PLLight.current(calendar: model.env.calendar), presence: .still, showsDove: true)
                .frame(maxWidth: .infinity)
            ScreenHeader(
                eyebrow: String(localized: "Premium"),
                title: String(localized: "Go deeper in your faith, every day."),
                detail: String(localized: "Everything you need to pray stays free — the pause before apps, scripture, prayer times, the Qibla, your beads and the core prayers. Premium adds the deeper library and a companion who knows your tradition.")
            )
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            PaywallFeature(icon: "sparkles", title: "100 questions a day", detail: "Stories, history and meaning; step-by-step guides for every puja, prayer and festival — answered in your tradition (free: 10 a day).")
            PaywallFeature(icon: "books.vertical", title: "The complete library", detail: "Every stotra and long prayer — Aditya Hridayam, Kanakadhara, Subrahmanya Bhujangam and more — in the original script with transliteration and source.")
            PaywallFeature(icon: "circle.dotted", title: "Guided rosary", detail: "The day's mysteries with their Gospel passages, bead by bead.")
            PaywallFeature(icon: "book", title: "Every reading plan", detail: "The Gospels, Psalms, the New Testament, a Qur'an khatm in 30 days, the Gita in 18 days.")
            PaywallFeature(icon: "book.closed", title: "Unlimited prayer journal", detail: "Everyone you're praying for, and every prayer answered (free: 3 at a time).")
            PaywallFeature(icon: "lock.shield", title: "Private by design", detail: "Your prayers and journal stay on this iPhone. No ads, ever.")
        }
        .plPaper()
    }

    @ViewBuilder
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            SectionHeading(String(localized: "Choose a plan"))
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .accessibilityIdentifier("paywall.loading")
            } else if let loadError {
                Text(loadError)
                    .font(.plCallout)
                    .foregroundStyle(Color.plCaution)
                    .fixedSize(horizontal: false, vertical: true)
                    .plPaper()
                    .accessibilityIdentifier("paywall.error")
            } else {
                VStack(spacing: PLSpacing.s) {
                    ForEach(products) { product in
                        PaywallProductRow(product: product, isSelected: product.id == selectedProduct?.id) {
                            selectedID = product.id
                        }
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: PLSpacing.s) {
            Button {
                Task { await subscribe() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(.plOnAccentFill)
                } else {
                    Text(primaryButtonTitle)
                }
            }
            .buttonStyle(.plPrimary)
            .disabled(selectedProduct == nil || isLoading || isPurchasing)
            .accessibilityIdentifier("paywall.subscribe")

            Button("Restore purchases") {
                Task {
                    isPurchasing = true
                    await model.restorePurchases()
                    isPurchasing = false
                }
            }
            .buttonStyle(.plSecondary)
            .disabled(isPurchasing)
            .accessibilityIdentifier("paywall.restore")
        }
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            Text(disclosure)
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: PLSpacing.m) {
                NavigationLink("Privacy Policy") { LegalDocumentView(resource: .privacyPolicy) }
                Button("Terms of Use") {
                    openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
            }
            .font(.plCaption.weight(.semibold))
            .foregroundStyle(Color.plAccent)
        }
    }

    private var selectedProduct: StoreProduct? {
        products.first { $0.id == selectedID } ?? products.first
    }

    private var primaryButtonTitle: String {
        guard let product = selectedProduct else { return String(localized: "Subscribe") }
        if let offer = product.introductoryOffer, offer.paymentMode == .freeTrial {
            return String(localized: "Start \(offer.periodDescription) free")
        }
        return String(localized: "Subscribe")
    }

    private var disclosure: String {
        guard let product = selectedProduct else {
            return String(localized: "Prices are provided by the App Store.")
        }
        var parts = [String(localized: "\(product.displayName) renews every \(product.periodDescription) at \(product.displayPrice).")]
        if let offer = product.introductoryOffer {
            switch offer.paymentMode {
            case .freeTrial:
                parts.append(String(localized: "Eligible users get \(offer.periodDescription) free, then \(product.displayPrice) every \(product.periodDescription)."))
            default:
                parts.append(String(localized: "Introductory offer: \(offer.displayPrice) for \(offer.periodDescription)."))
            }
        }
        parts.append(String(localized: "Payment is charged by Apple. Manage or cancel in App Store subscription settings."))
        return parts.joined(separator: " ")
    }

    private func loadProducts() async {
        isLoading = true
        loadError = nil
        do {
            let loaded = try await model.env.purchases.products()
            products = loaded
            selectedID = loaded.first(where: { $0.plan == .annual })?.id ?? loaded.first?.id
            if loaded.isEmpty {
                loadError = String(localized: "The App Store did not return any subscription products for this build.")
            }
        } catch {
            loadError = String(localized: "Subscriptions are unavailable right now. Try again later.")
        }
        isLoading = false
    }

    private func subscribe() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        _ = await model.purchase(product)
        isPurchasing = false
    }
}

private struct PaywallFeature: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: PLSpacing.m) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.plGilt)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text(title)
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                Text(detail)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PaywallProductRow: View {
    let product: StoreProduct
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: PLSpacing.m) {
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    HStack(spacing: PLSpacing.xs) {
                        Text(product.displayName)
                            .font(.plTitleSmall)
                            .foregroundStyle(Color.plInk)
                        if product.plan == .annual {
                            Text("Best value")
                                .font(.plCaption.weight(.semibold))
                                .foregroundStyle(Color.plOnAccentFill)
                                .padding(.horizontal, PLSpacing.xs)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.plAccentFill))
                        }
                    }
                    Text(planDetail)
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: PLSpacing.s)
                Text(product.displayPrice)
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                PLSelectionMark(isSelected: isSelected)
            }
            .padding(PLSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous)
                    .fill(isSelected ? Color.plAccentSoft : Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous)
                    .strokeBorder(isSelected ? Color.plAccent : Color.plLine, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.product.\(product.plan.rawValue)")
    }

    private var planDetail: String {
        if let offer = product.introductoryOffer, offer.paymentMode == .freeTrial {
            return String(localized: "\(offer.periodDescription) free trial, then renews every \(product.periodDescription)")
        }
        return String(localized: "Renews every \(product.periodDescription)")
    }
}

/// Presents the paywall from inside a sheet (a sheet can't be shown from the root while
/// another is up). Apply to the root view of any sheet that has Premium features.
struct PremiumPaywallPresenter: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { model.paywallReason != nil }, set: { if !$0 { model.paywallReason = nil } })) {
            NavigationStack {
                PaywallView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Not now") { model.paywallReason = nil } }
                    }
            }
            .environment(model)
        }
    }
}

extension View {
    func presentsPaywall() -> some View { modifier(PremiumPaywallPresenter()) }
}
