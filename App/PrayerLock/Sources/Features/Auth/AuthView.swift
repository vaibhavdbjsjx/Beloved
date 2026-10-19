import AuthenticationServices
import PLCore
import PLDesign
import SwiftUI

/// The account sheet: Sign in with Apple, the one sign-in option.
public struct AuthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var errorMessage: String?
    @State private var currentAppleNonce: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.plCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: PLSpacing.xl) {
                        // Header
                        VStack(spacing: PLSpacing.m) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 56, weight: .light))
                                .foregroundStyle(Color.plAccent)
                                .padding(.top, PLSpacing.xl)

                            Text("Your Beloved Account")
                                .font(.plDisplay)
                                .foregroundStyle(Color.plInk)
                                .multilineTextAlignment(.center)

                            Text("Optional. Sign in with Apple to show your name and photo. Your faith, journal and journey are kept in your own iCloud whether or not you sign in.")
                                .font(.plCallout)
                                .foregroundStyle(Color.plInkSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, PLSpacing.m)
                        }

                        // Error Banner
                        if let errorMessage {
                            HStack(alignment: .top, spacing: PLSpacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Color.plDestructive)
                                Text(errorMessage)
                                    .font(.plCaption)
                                    .foregroundStyle(Color.plInk)
                                Spacer()
                                Button {
                                    self.errorMessage = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundStyle(Color.plInkSecondary)
                                }
                            }
                            .padding(PLSpacing.s)
                            .background(Color.plSurfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: PLRadius.chip, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PLRadius.chip, style: .continuous)
                                    .strokeBorder(Color.plDestructive.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, PLSpacing.l)
                        }

                        // Sign in with Apple — the one account option (an App Store app; every user has an Apple ID)
                        VStack(spacing: PLSpacing.m) {
                            if model.isAuthenticating {
                                HStack(spacing: PLSpacing.s) {
                                    ProgressView()
                                        .tint(Color.plAccent)
                                    Text("Signing in…")
                                        .font(.plHeadline)
                                        .foregroundStyle(Color.plInkSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.plSurface)
                                .clipShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                                .padding(.horizontal, PLSpacing.l)
                            } else {
                                // Sign in with Apple
                                SignInWithAppleButton(.continue) { request in
                                    let rawNonce = NativeAuthenticationService.generateNonce()
                                    currentAppleNonce = rawNonce
                                    request.requestedScopes = [.fullName, .email]
                                    request.nonce = NativeAuthenticationService.sha256(rawNonce)
                                } onCompletion: { result in
                                    switch result {
                                    case let .success(authorization):
                                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                            let payload = AppleCredentialPayload(
                                                userIdentifier: credential.user,
                                                identityToken: credential.identityToken,
                                                authorizationCode: credential.authorizationCode,
                                                email: credential.email,
                                                fullName: credential.fullName,
                                                rawNonce: currentAppleNonce,
                                                realUserStatus: credential.realUserStatus.rawValue
                                            )
                                            Task {
                                                do {
                                                    let session = try await model.env.authentication.signInWithApple(payload: payload)
                                                    await MainActor.run {
                                                        _ = session
                                                        dismiss()
                                                    }
                                                    await model.refreshUserSession()
                                                } catch {
                                                    errorMessage = error.localizedDescription
                                                }
                                            }
                                        }
                                    case let .failure(error):
                                        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                                            return
                                        }
                                        errorMessage = error.localizedDescription
                                    }
                                }
                                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                                .frame(height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                                .padding(.horizontal, PLSpacing.l)
                            }
                        }

                        // Legal & Privacy Disclosures
                        VStack(spacing: PLSpacing.xs) {
                            Text("By continuing, you agree to Beloved's")
                                .font(.plCaption)
                                .foregroundStyle(Color.plInkSecondary)

                            HStack(spacing: PLSpacing.xs) {
                                Link("Terms of Use", destination: URL(string: "https://beloveded.netlify.app/terms.html")!)
                                    .font(.plCaption.weight(.medium))
                                    .foregroundStyle(Color.plAccent)

                                Text("·")
                                    .font(.plCaption)
                                    .foregroundStyle(Color.plInkSecondary)

                                NavigationLink("Privacy Policy") {
                                    LegalDocumentView(resource: .privacyPolicy)
                                }
                                .font(.plCaption.weight(.medium))
                                .foregroundStyle(Color.plAccent)
                            }
                        }
                        .padding(.top, PLSpacing.s)

                        // Skip / Not Now Button
                        Button("Not now") {
                            dismiss()
                        }
                        .buttonStyle(PLQuietButtonStyle(color: .plInkSecondary))
                        .padding(.top, PLSpacing.xs)
                    }
                    .padding(.bottom, PLSpacing.xxl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.plInkSecondary)
                }
            }
        }
    }
}


