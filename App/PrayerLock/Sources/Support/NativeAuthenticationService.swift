import AuthenticationServices
import CryptoKit
import Foundation
import PLCore
import UIKit

/// Concrete iOS implementation of AuthenticationService: Sign in with Apple, with the session kept
/// in the Keychain on this iPhone.
public final class NativeAuthenticationService: NSObject, AuthenticationService, @unchecked Sendable {
    private let underlying: StandardAuthenticationService
    private let configuration: AppConfiguration
    private let lock = NSLock()

    public init(sessionStore: AccountSessionStore, configuration: AppConfiguration) {
        self.underlying = StandardAuthenticationService(sessionStore: sessionStore)
        self.configuration = configuration
        super.init()
    }

    public func currentSession() async -> AuthSession? {
        await underlying.currentSession()
    }

    public func restorePreviousSignIn() async throws -> AuthSession? {
        guard let session = try await underlying.restorePreviousSignIn() else {
            return nil
        }

        // If Apple user, verify credential state with Apple
        if session.user.provider == .apple {
            let state = await Self.checkAppleCredentialState(userID: session.user.id)
            switch state {
            case .authorized:
                return session
            case .revoked, .notFound, .transferred:
                // Apple ID was revoked or not found
                try await underlying.signOut()
                return nil
            @unknown default:
                return session
            }
        }

        return session
    }

    public func signInWithApple(payload: AppleCredentialPayload) async throws -> AuthSession {
        try await underlying.signInWithApple(payload: payload)
    }

    public func signOut() async throws {
        try await underlying.signOut()
    }

    public func deleteAccount(appleRevocationHandler: (@Sendable () async throws -> Void)? = nil) async throws {
        try await underlying.deleteAccount(appleRevocationHandler: appleRevocationHandler)
    }

    public func updateDisplayName(_ name: String) async throws -> AuthUser {
        try await underlying.updateDisplayName(name)
    }

    public func updateAvatarLocalFilename(_ filename: String?) async throws -> AuthUser {
        try await underlying.updateAvatarLocalFilename(filename)
    }

    // MARK: - Apple Authentication Coordinator

    /// Performs native Sign in with Apple flow.
    @MainActor
    public func performAppleSignIn(presentingWindow: UIWindow?) async throws -> AuthSession {
        let nonce = Self.generateNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let coordinator = AppleSignInCoordinator(presentingWindow: presentingWindow)
        let credential = try await coordinator.perform(request: request)

        let payload = AppleCredentialPayload(
            userIdentifier: credential.user,
            identityToken: credential.identityToken,
            authorizationCode: credential.authorizationCode,
            email: credential.email,
            fullName: credential.fullName,
            realUserStatus: credential.realUserStatus.rawValue
        )

        return try await signInWithApple(payload: payload)
    }

    // MARK: - Utilities

    public static func checkAppleCredentialState(userID: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    public static func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback UUID-based nonce
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    public static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

}

// MARK: - Apple Coordinator

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private weak var presentingWindow: UIWindow?
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    init(presentingWindow: UIWindow?) {
        self.presentingWindow = presentingWindow
    }

    func perform(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentingWindow ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidCredentials)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AuthError.cancelled)
        } else {
            continuation?.resume(throwing: AuthError.networkError(error.localizedDescription))
        }
        continuation = nil
    }
}
