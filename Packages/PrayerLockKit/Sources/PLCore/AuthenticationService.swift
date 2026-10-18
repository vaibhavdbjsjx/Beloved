import CryptoKit
import Foundation

/// Defines operations for authentication and account management.
public protocol AuthenticationService: Sendable {
    func currentSession() async -> AuthSession?
    func signInWithApple(payload: AppleCredentialPayload) async throws -> AuthSession
    func signInWithGoogle(payload: GoogleCredentialPayload) async throws -> AuthSession
    func restorePreviousSignIn() async throws -> AuthSession?
    func signOut() async throws
    func deleteAccount(appleRevocationHandler: (@Sendable () async throws -> Void)?) async throws
    func updateDisplayName(_ name: String) async throws -> AuthUser
    func updateAvatarLocalFilename(_ filename: String?) async throws -> AuthUser
}

/// Core authentication coordinator handling session persistence and identity rules.
public actor StandardAuthenticationService: AuthenticationService {
    private let sessionStore: AccountSessionStore
    private var cachedSession: AuthSession?

    public init(sessionStore: AccountSessionStore) {
        self.sessionStore = sessionStore
        self.cachedSession = sessionStore.loadSession()
    }

    public func currentSession() async -> AuthSession? {
        cachedSession
    }

    public func restorePreviousSignIn() async throws -> AuthSession? {
        if let session = cachedSession {
            return session
        }
        if let loaded = sessionStore.loadSession() {
            cachedSession = loaded
            return loaded
        }
        return nil
    }

    public func signInWithApple(payload: AppleCredentialPayload) async throws -> AuthSession {
        // Validate ID token claims if present
        if let tokenString = payload.identityTokenString, !tokenString.isEmpty {
            let claims = Self.decodeJWTClaims(from: tokenString)
            if let iss = claims["iss"] as? String {
                guard iss == "https://appleid.apple.com" else {
                    throw AuthError.invalidCredentials
                }
            }
            if let exp = claims["exp"] as? TimeInterval {
                guard exp > Date().timeIntervalSince1970 else {
                    throw AuthError.expiredSession
                }
            }
            if let sub = claims["sub"] as? String {
                guard sub == payload.userIdentifier else {
                    throw AuthError.invalidCredentials
                }
            }
            if let rawNonce = payload.rawNonce, let expectedNonce = claims["nonce"] as? String {
                let hashed = Self.sha256(rawNonce)
                guard expectedNonce == hashed else {
                    throw AuthError.invalidCredentials
                }
            }
        }

        // Apple only returns the user's full name on the FIRST authorization.
        // If this is a subsequent sign-in and payload.formattedFullName is nil,
        // preserve the existing display name from prior session if matching user ID.
        var displayName = payload.formattedFullName
        var avatarFilename: String?
        var existingCreatedAt: Date = .now

        if let existing = cachedSession, existing.user.id == payload.userIdentifier {
            if displayName == nil || displayName?.isEmpty == true {
                displayName = existing.user.displayName
            }
            avatarFilename = existing.user.avatarLocalFilename
            existingCreatedAt = existing.user.createdAt
        }

        let isPrivate = payload.email?.lowercased().contains("privaterelay.appleid.com") ?? false

        let user = AuthUser(
            id: payload.userIdentifier,
            provider: .apple,
            email: payload.email,
            isPrivateEmail: isPrivate,
            displayName: displayName,
            avatarURL: nil,
            avatarLocalFilename: avatarFilename,
            createdAt: existingCreatedAt,
            lastSignInAt: .now
        )

        let session = AuthSession(
            user: user,
            idToken: payload.identityTokenString,
            authorizationCode: payload.authorizationCodeString,
            expiresAt: nil
        )

        try sessionStore.saveSession(session)
        cachedSession = session
        return session
    }

    public func signInWithGoogle(payload: GoogleCredentialPayload) async throws -> AuthSession {
        var existingCreatedAt: Date = .now
        var avatarFilename: String?

        if let existing = cachedSession, existing.user.id == payload.userID {
            existingCreatedAt = existing.user.createdAt
            avatarFilename = existing.user.avatarLocalFilename
        }

        let user = AuthUser(
            id: payload.userID,
            provider: .google,
            email: payload.email,
            isPrivateEmail: false,
            displayName: payload.displayName,
            avatarURL: payload.avatarURL,
            avatarLocalFilename: avatarFilename,
            createdAt: existingCreatedAt,
            lastSignInAt: .now
        )

        let session = AuthSession(
            user: user,
            idToken: payload.idToken,
            authorizationCode: nil,
            expiresAt: nil
        )

        try sessionStore.saveSession(session)
        cachedSession = session
        return session
    }

    public func signOut() async throws {
        cachedSession = nil
        try sessionStore.clearSession()
    }

    public func deleteAccount(appleRevocationHandler: (@Sendable () async throws -> Void)? = nil) async throws {
        // 1. If currently signed in with Apple and an appleRevocationHandler is provided, execute it.
        if let session = cachedSession {
            if session.user.provider == .apple, let appleRevocationHandler {
                do {
                    try await appleRevocationHandler()
                } catch {
                    throw AuthError.deletionFailed("Could not revoke Apple authorization: \(error.localizedDescription)")
                }
            } else if session.user.provider == .google, let idToken = session.idToken {
                // Revoke Google OAuth token using Google's official revocation endpoint
                do {
                    try await Self.revokeGoogleToken(token: idToken)
                } catch {
                    throw AuthError.deletionFailed("Remote token revocation failed: \(error.localizedDescription)")
                }
            }
        }

        // 2. Clear secure session storage completely
        cachedSession = nil
        try sessionStore.clearSession()
    }

    public func updateDisplayName(_ name: String) async throws -> AuthUser {
        guard var session = cachedSession else {
            throw AuthError.expiredSession
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        session.user.displayName = trimmed.isEmpty ? nil : trimmed
        try sessionStore.saveSession(session)
        cachedSession = session
        return session.user
    }

    public func updateAvatarLocalFilename(_ filename: String?) async throws -> AuthUser {
        guard var session = cachedSession else {
            throw AuthError.expiredSession
        }

        session.user.avatarLocalFilename = filename
        try sessionStore.saveSession(session)
        cachedSession = session
        return session.user
    }

    /// Revokes an OAuth token using Google's official revocation endpoint.
    /// Returns safely if the token was revoked (HTTP 200) or was already invalid/expired (HTTP 400).
    /// Throws on network failure or unexpected server response so callers do not assume remote revocation succeeded.
    public static func revokeGoogleToken(token: String) async throws {
        guard let url = URL(string: "https://oauth2.googleapis.com/revoke") else {
            throw AuthError.unknown("Invalid revocation endpoint.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.networkError("Invalid response from revocation endpoint.")
        }
        if (200...299).contains(http.statusCode) || http.statusCode == 400 {
            return
        }
        let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
        throw AuthError.revocationFailed("Revocation failed: \(detail)")
    }

    public static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    public static func decodeJWTClaims(from jwt: String) -> [String: Any] {
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

/// Fully controllable mock for unit tests and SwiftUI previews.
public actor MockAuthenticationService: AuthenticationService {
    public var stubbedSession: AuthSession?
    public var shouldThrowError: AuthError?
    public private(set) var didSignOut = false
    public private(set) var didDeleteAccount = false
    public private(set) var lastUpdatedDisplayName: String?
    public private(set) var lastUpdatedAvatarFilename: String?

    public init(session: AuthSession? = nil) {
        self.stubbedSession = session
    }

    public func currentSession() async -> AuthSession? {
        stubbedSession
    }

    public func signInWithApple(payload: AppleCredentialPayload) async throws -> AuthSession {
        if let error = shouldThrowError { throw error }
        let isPrivate = payload.email?.contains("privaterelay") ?? false
        let user = AuthUser(
            id: payload.userIdentifier,
            provider: .apple,
            email: payload.email,
            isPrivateEmail: isPrivate,
            displayName: payload.formattedFullName ?? stubbedSession?.user.displayName ?? "Apple User",
            avatarURL: nil,
            avatarLocalFilename: stubbedSession?.user.avatarLocalFilename,
            createdAt: stubbedSession?.user.createdAt ?? .now,
            lastSignInAt: .now
        )
        let session = AuthSession(user: user, idToken: "mock-apple-id-token", authorizationCode: "mock-apple-auth-code")
        stubbedSession = session
        return session
    }

    public func signInWithGoogle(payload: GoogleCredentialPayload) async throws -> AuthSession {
        if let error = shouldThrowError { throw error }
        let user = AuthUser(
            id: payload.userID,
            provider: .google,
            email: payload.email,
            isPrivateEmail: false,
            displayName: payload.displayName ?? "Google User",
            avatarURL: payload.avatarURL,
            avatarLocalFilename: stubbedSession?.user.avatarLocalFilename,
            createdAt: stubbedSession?.user.createdAt ?? .now,
            lastSignInAt: .now
        )
        let session = AuthSession(user: user, idToken: payload.idToken ?? "mock-google-id-token")
        stubbedSession = session
        return session
    }

    public func restorePreviousSignIn() async throws -> AuthSession? {
        if let error = shouldThrowError { throw error }
        return stubbedSession
    }

    public func signOut() async throws {
        if let error = shouldThrowError { throw error }
        didSignOut = true
        stubbedSession = nil
    }

    public func deleteAccount(appleRevocationHandler: (@Sendable () async throws -> Void)? = nil) async throws {
        if let error = shouldThrowError { throw error }
        try await appleRevocationHandler?()
        didDeleteAccount = true
        stubbedSession = nil
    }

    public func updateDisplayName(_ name: String) async throws -> AuthUser {
        if let error = shouldThrowError { throw error }
        guard var session = stubbedSession else { throw AuthError.expiredSession }
        session.user.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        lastUpdatedDisplayName = session.user.displayName
        stubbedSession = session
        return session.user
    }

    public func updateAvatarLocalFilename(_ filename: String?) async throws -> AuthUser {
        if let error = shouldThrowError { throw error }
        guard var session = stubbedSession else { throw AuthError.expiredSession }
        session.user.avatarLocalFilename = filename
        lastUpdatedAvatarFilename = filename
        stubbedSession = session
        return session.user
    }
}
