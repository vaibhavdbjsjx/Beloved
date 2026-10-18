import AuthenticationServices
import PhotosUI
import PLCore
import PLDesign
import PLMonetization
import StoreKit
import SwiftUI

/// Profile & Account Management screen adhering strictly to Beloved's design system.
@MainActor
public struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingAuthSheet = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditNameAlert = false
    @State private var nameDraft = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isManagingSubscription = false

    public init() {}

    public var body: some View {
        Form {
            headerSection
            membershipSection
            if model.currentUser != nil {
                accountManagementSection
            } else {
                signInPromptSection
            }
        }
        .labeledContentStyle(.pl)
        .scrollContentBackground(.hidden)
        .background(Color.plCanvas)
        .navigationTitle("Profile")
        .environment(\.defaultMinListRowHeight, 52)
        .sheet(isPresented: $showingAuthSheet) {
            AuthView()
                .environment(model)
        }
        .confirmationDialog(
            "Sign out of Beloved?",
            isPresented: $showingSignOutAlert,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                Task { await model.signOut() }
            }
        } message: {
            Text("Signing out removes your account session from this iPhone. Your on-device prayer history and Screen Time rules will be preserved.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task {
                    let success = await model.deleteAccount()
                    if success {
                        dismiss()
                    }
                }
            }
            Button("Manage Subscriptions") {
                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                    openURL(url)
                }
            }
        } message: {
            Text("This permanently deletes your account credentials and profile from Beloved.\n\nIMPORTANT: Deleting your Beloved account does NOT automatically cancel an active Apple App Store subscription. Subscriptions must be cancelled through your Apple ID settings.")
        }
        .alert("Edit Display Name", isPresented: $showingEditNameAlert) {
            TextField("Your Name", text: $nameDraft)
            Button("Save") {
                Task { await model.updateDisplayName(nameDraft) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.updateProfileAvatar(imageData: data)
                }
            }
        }
    }

    // MARK: - A. Profile Header

    private var headerSection: some View {
        let user = model.currentUser
        let localImage = user.flatMap { model.localAvatarImage(for: $0) }
        return Section {
            VStack(spacing: PLSpacing.m) {
                // Avatar with PhotosPicker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ProfileAvatarDisplay(
                        user: user,
                        localImage: localImage
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(user == nil)

                // Display Name & Email
                VStack(spacing: PLSpacing.xxs) {
                    HStack(spacing: PLSpacing.xs) {
                        Text(model.currentUser?.displayTitle ?? "Guest")
                            .font(.plHeadline.weight(.semibold))
                            .foregroundStyle(Color.plInk)

                        if model.accessLevel == .premium {
                            Text("PREMIUM")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.plAccentFill)
                                .foregroundStyle(Color.plOnAccentFill)
                                .clipShape(Capsule())
                        }
                    }

                    if let user = model.currentUser, let email = user.email {
                        HStack(spacing: 4) {
                            Text(email)
                                .font(.plCallout)
                                .foregroundStyle(Color.plInkSecondary)

                            if user.isPrivateEmail {
                                Image(systemName: "shield.checkmark.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Color.plAccent)
                                    .help("Apple Private Relay")
                            }
                        }
                    }

                    // Provider Tag
                    if let user = model.currentUser {
                        HStack(spacing: 4) {
                            Image(systemName: user.provider == .apple ? "apple.logo" : "globe")
                                .font(.caption2)
                            Text("Signed in with \(user.provider.displayName)")
                                .font(.plCaption)
                        }
                        .foregroundStyle(Color.plInkSecondary)
                        .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PLSpacing.m)
        }
        .listRowBackground(Color.plSurface)
    }

    // MARK: - B. Premium Membership (StoreKit 2)

    private var membershipSection: some View {
        Section {
            LabeledContent(
                "Membership Tier",
                value: model.accessLevel == .premium ? String(localized: "Beloved Premium") : String(localized: "Free")
            )

            if case let .subscribed(details) = model.subscriptionState {
                if let planName = planDisplayName(for: details.productID) {
                    LabeledContent("Active Plan", value: planName)
                }

                if let date = details.expiresAt {
                    let dateString = date.formatted(date: .abbreviated, time: .omitted)
                    if details.willAutoRenew {
                        LabeledContent("Renews on", value: dateString)
                    } else {
                        LabeledContent("Expires on", value: dateString)
                    }
                }
            }

            if model.accessLevel == .premium {
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                }
                .foregroundStyle(Color.plAccent)
            } else {
                NavigationLink("Upgrade to Premium") {
                    PaywallView()
                }
                .foregroundStyle(Color.plAccent)
            }

            Button("Restore Purchases") {
                Task { await model.restorePurchases() }
            }
            .foregroundStyle(Color.plInk)
        } header: {
            Text("Subscription")
                .foregroundStyle(Color.plInkSecondary)
        } footer: {
            Text("Subscriptions are verified securely through your Apple ID via StoreKit 2. Signing out of your Beloved account does not cancel your App Store subscription.")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    private func planDisplayName(for productID: String) -> String? {
        switch productID {
        case "beloved.premium.monthly":
            return String(localized: "Monthly Plan")
        case "beloved.premium.annual":
            return String(localized: "Annual Plan")
        default:
            return nil
        }
    }

    // MARK: - C. Account Management

    private var accountManagementSection: some View {
        Section {
            Button("Edit Display Name") {
                nameDraft = model.currentUser?.displayName ?? ""
                showingEditNameAlert = true
            }
            .foregroundStyle(Color.plInk)

            if let createdAt = model.currentUser?.createdAt {
                LabeledContent("Member Since", value: createdAt.formatted(date: .abbreviated, time: .omitted))
            }

            Button("Sign Out") {
                showingSignOutAlert = true
            }
            .foregroundStyle(Color.plInkSecondary)

            Button("Delete Account", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .foregroundStyle(Color.plDestructive)
        } header: {
            Text("Account Settings")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    private var signInPromptSection: some View {
        Section {
            Button {
                showingAuthSheet = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sign In to Beloved")
                            .font(.plHeadline.weight(.semibold))
                            .foregroundStyle(Color.plInk)
                        Text("Keep your account profile and access in sync across devices.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.plInkSecondary)
                }
            }
        }
        .listRowBackground(Color.plSurface)
    }
}

/// Standalone avatar display component decoupling photos and fallbacks.
public struct ProfileAvatarDisplay: View, Sendable {
    let user: AuthUser?
    let localImage: UIImage?

    public nonisolated init(user: AuthUser?, localImage: UIImage?) {
        self.user = user
        self.localImage = localImage
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let localImage {
                Image(uiImage: localImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
            } else if let user, let url = user.avatarURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                    } else {
                        fallback
                    }
                }
                .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
            } else {
                fallback
            }

            if user != nil {
                Circle()
                    .fill(Color.plSurfaceRaised)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.plAccent)
                    )
                    .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
            }
        }
    }

    private var fallback: some View {
        Circle()
            .fill(Color.plSurfaceRaised)
            .frame(width: 84, height: 84)
            .overlay(
                Text(user?.initials ?? "B")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.plAccent)
            )
            .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
    }
}

