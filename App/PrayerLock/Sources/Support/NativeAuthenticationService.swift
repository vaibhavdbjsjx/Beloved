import AuthenticationServices
import CryptoKit
import Foundation
import PLCore
import UIKit

/// Concrete iOS implementation of AuthenticationService integrating Apple AuthenticationServices
/// and Google Sign-In with local Keychain session storage.
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

    public func signInWithGoogle(payload: GoogleCredentialPayload) async throws -> AuthSession {
        try await underlying.signInWithGoogle(payload: payload)
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

    // MARK: - Google Authentication Coordinator

    /// Performs Google Sign-In using OAuth 2.0 PKCE / OIDC via ASWebAuthenticationSession.
    @MainActor
    public func performGoogleSignIn(presentingWindow: UIWindow?) async throws -> AuthSession {
        guard let clientID = configuration.googleClientID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clientID.isEmpty else {
            throw AuthError.missingConfiguration(
                "Google Client ID is not configured. Please add PL_GOOGLE_CLIENT_ID to your build configuration or Secrets.xcconfig."
            )
        }

        let scheme = Self.reversedClientID(from: clientID)
        let redirectURI = "\(scheme):/oauth2redirect"
        let codeVerifier = Self.generateCodeVerifier()
        let codeChallenge = Self.sha256Base64URL(codeVerifier)
        let state = Self.generateNonce(length: 32)
        let rawNonce = Self.generateNonce(length: 32)
        let nonce = Self.sha256(rawNonce)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "nonce", value: nonce)
        ]

        guard let authURL = components.url else {
            throw AuthError.unknown("Could not construct Google authorization URL.")
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { callbackURL, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: AuthError.cancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: AuthError.networkError(error.localizedDescription))
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: AuthError.invalidCredentials)
                    return
                }
                continuation.resume(returning: callbackURL)
            }

            let presentationContextProvider = WebAuthPresentationContextProvider(window: presentingWindow)
            session.presentationContextProvider = presentationContextProvider
            objc_setAssociatedObject(session, "presentationProvider", presentationContextProvider, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            if !session.start() {
                continuation.resume(throwing: AuthError.unknown("Could not start authentication session."))
            }
        }

        // Parse query or fragment for code and state
        let parsed = Self.parseOAuthCallback(callbackURL)
        if let error = parsed["error"] {
            throw AuthError.unknown("Authentication failed: \(error)")
        }
        guard let returnedState = parsed["state"], returnedState == state else {
            throw AuthError.invalidCredentials
        }
        guard let code = parsed["code"] else {
            throw AuthError.invalidCredentials
        }

        // Exchange authorization code for tokens via PKCE
        let (idToken, _) = try await Self.exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier,
            clientID: clientID,
            redirectURI: redirectURI
        )

        // Validate OIDC JWT claims securely
        let claims = Self.decodeJWTClaims(from: idToken)
        guard let iss = claims["iss"] as? String,
              iss == "https://accounts.google.com" || iss == "accounts.google.com" else {
            throw AuthError.invalidCredentials
        }
        guard let aud = claims["aud"] as? String, aud == clientID else {
            throw AuthError.invalidCredentials
        }
        guard let exp = claims["exp"] as? TimeInterval, exp > Date().timeIntervalSince1970 else {
            throw AuthError.expiredSession
        }
        guard let tokenNonce = claims["nonce"] as? String, tokenNonce == nonce else {
            throw AuthError.invalidCredentials
        }
        guard let userID = claims["sub"] as? String, !userID.isEmpty else {
            throw AuthError.invalidCredentials
        }

        let email = claims["email"] as? String
        let name = claims["name"] as? String
        let pictureString = claims["picture"] as? String
        let avatarURL = pictureString.flatMap(URL.init(string:))

        let payload = GoogleCredentialPayload(
            userID: userID,
            idToken: idToken,
            email: email,
            displayName: name,
            avatarURL: avatarURL
        )

        return try await signInWithGoogle(payload: payload)
    }

    private static func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        clientID: String,
        redirectURI: String
    ) async throws -> (idToken: String, refreshToken: String?) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            throw AuthError.unknown("Invalid token endpoint URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.invalidCredentials
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String else {
            throw AuthError.invalidCredentials
        }

        let refreshToken = json["refresh_token"] as? String
        return (idToken, refreshToken)
    }

    public static func generateCodeVerifier(length: Int = 64) -> String {
        generateNonce(length: length)
    }

    public static func sha256Base64URL(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return Data(hashedData).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
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

    private static func reversedClientID(from clientID: String) -> String {
        let parts = clientID.split(separator: ".")
        return parts.reversed().joined(separator: ".")
    }

    private static func parseOAuthCallback(_ url: URL) -> [String: String] {
        var params: [String: String] = [:]
        // Check query items
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                params[item.name] = item.value
            }
        }
        // Check fragment items (hash parameters e.g. #id_token=...&access_token=...)
        if let fragment = url.fragment {
            let pairs = fragment.split(separator: "&")
            for pair in pairs {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let key = String(kv[0])
                    let val = String(kv[1]).removingPercentEncoding ?? String(kv[1])
                    params[key] = val
                }
            }
        }
        return params
    }

    private static func decodeJWTClaims(from jwt: String) -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}

// MARK: - Presentation Context & Apple Coordinator

private final class WebAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private weak var window: UIWindow?

    init(window: UIWindow?) {
        self.window = window
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

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
