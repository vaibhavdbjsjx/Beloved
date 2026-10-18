import AuthenticationServices
import PLCore
import PLDesign
import SwiftUI

/// Elegant, dedicated authentication sheet presenting exactly two options:
/// 1. Continue with Gmail
/// 2. Continue with Apple
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

                            Text("Sign in to preserve your profile and access Beloved seamlessly. Your prayer history and Screen Time rules always remain private on this iPhone.")
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

                        // Sign-In Actions (Exactly 2 options: Continue with Gmail & Continue with Apple)
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
                                // 1. Continue with Gmail
                                GoogleSignInButton {
                                    errorMessage = nil
                                    Task {
                                        await model.signInWithGoogle()
                                        if model.currentUser != nil {
                                            dismiss()
                                        }
                                    }
                                }
                                .padding(.horizontal, PLSpacing.l)

                                // 2. Continue with Apple
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

/// Polished button adhering to Google's official Sign-In branding guidelines, labelled "Continue with Gmail".
public struct GoogleSignInButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PLSpacing.s) {
                GoogleLogo()
                    .frame(width: 20, height: 20)

                Text("Continue with Gmail")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color(red: 0.12, green: 0.12, blue: 0.14))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(colorScheme == .dark ? Color(red: 0.18, green: 0.19, blue: 0.22) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                    .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

public typealias GmailSignInButton = GoogleSignInButton

/// Official multi-color Google "G" logo vector.
struct GoogleLogo: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Blue
            var bluePath = Path()
            bluePath.move(to: CGPoint(x: w * 0.98, y: h * 0.51))
            bluePath.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.81), control1: CGPoint(x: w * 0.98, y: h * 0.65), control2: CGPoint(x: w * 0.93, y: h * 0.75))
            bluePath.addLine(to: CGPoint(x: w * 0.52, y: h * 0.51))
            bluePath.addLine(to: CGPoint(x: w * 0.98, y: h * 0.51))
            context.fill(bluePath, with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))

            // Green
            var greenPath = Path()
            greenPath.move(to: CGPoint(x: w * 0.50, y: h * 0.98))
            greenPath.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.81), control1: CGPoint(x: w * 0.64, y: h * 0.98), control2: CGPoint(x: w * 0.76, y: h * 0.92))
            greenPath.addLine(to: CGPoint(x: w * 0.52, y: h * 0.51))
            greenPath.addLine(to: CGPoint(x: w * 0.21, y: h * 0.76))
            greenPath.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.98), control1: CGPoint(x: w * 0.28, y: h * 0.89), control2: CGPoint(x: w * 0.38, y: h * 0.98))
            context.fill(greenPath, with: .color(Color(red: 0.20, green: 0.66, blue: 0.33)))

            // Yellow
            var yellowPath = Path()
            yellowPath.move(to: CGPoint(x: w * 0.05, y: h * 0.50))
            yellowPath.addCurve(to: CGPoint(x: w * 0.21, y: h * 0.76), control1: CGPoint(x: w * 0.05, y: h * 0.60), control2: CGPoint(x: w * 0.11, y: h * 0.69))
            yellowPath.addLine(to: CGPoint(x: w * 0.52, y: h * 0.51))
            yellowPath.addLine(to: CGPoint(x: w * 0.20, y: h * 0.25))
            yellowPath.addCurve(to: CGPoint(x: w * 0.05, y: h * 0.50), control1: CGPoint(x: w * 0.11, y: h * 0.32), control2: CGPoint(x: w * 0.05, y: h * 0.40))
            context.fill(yellowPath, with: .color(Color(red: 0.98, green: 0.74, blue: 0.02)))

            // Red
            var redPath = Path()
            redPath.move(to: CGPoint(x: w * 0.50, y: h * 0.02))
            redPath.addCurve(to: CGPoint(x: w * 0.84, y: h * 0.18), control1: CGPoint(x: w * 0.64, y: h * 0.02), control2: CGPoint(x: w * 0.76, y: h * 0.08))
            redPath.addLine(to: CGPoint(x: w * 0.52, y: h * 0.51))
            redPath.addLine(to: CGPoint(x: w * 0.20, y: h * 0.25))
            redPath.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.02), control1: CGPoint(x: w * 0.28, y: h * 0.12), control2: CGPoint(x: w * 0.38, y: h * 0.02))
            context.fill(redPath, with: .color(Color(red: 0.92, green: 0.26, blue: 0.21)))
        }
    }
}
