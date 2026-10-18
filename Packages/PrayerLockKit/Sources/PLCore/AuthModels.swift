import Foundation

/// The supported authentication providers.
public enum AuthProvider: String, Codable, Sendable, CaseIterable {
    case apple = "apple"
    case google = "google"

    public var displayName: String {
        switch self {
        case .apple: "Apple"
        case .google: "Gmail"
        }
    }
}

/// An authenticated user identity in Beloved.
public struct AuthUser: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let provider: AuthProvider
    public var email: String?
    public var isPrivateEmail: Bool
    public var displayName: String?
    public var avatarURL: URL?
    /// Locally cached avatar filename stored in the private, complete-protected container.
    public var avatarLocalFilename: String?
    public let createdAt: Date
    public var lastSignInAt: Date

    public init(
        id: String,
        provider: AuthProvider,
        email: String? = nil,
        isPrivateEmail: Bool = false,
        displayName: String? = nil,
        avatarURL: URL? = nil,
        avatarLocalFilename: String? = nil,
        createdAt: Date = .now,
        lastSignInAt: Date = .now
    ) {
        self.id = id
        self.provider = provider
        self.email = email
        self.isPrivateEmail = isPrivateEmail
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.avatarLocalFilename = avatarLocalFilename
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
    }

    /// Best available display representation (displayName -> email -> "Beloved Member").
    public var displayTitle: String {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return "Beloved Member"
    }

    /// Initials for fallback avatars.
    public var initials: String {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let parts = name.split(separator: " ").filter { !$0.isEmpty }
            if parts.count >= 2 {
                let first = parts[0].prefix(1)
                let second = parts[1].prefix(1)
                return "\(first)\(second)".uppercased()
            } else if let single = parts.first {
                return String(single.prefix(2)).uppercased()
            }
        }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return String(email.prefix(2)).uppercased()
        }
        return "B"
    }
}

/// Active authentication session.
public struct AuthSession: Codable, Equatable, Sendable {
    public var user: AuthUser
    public let idToken: String?
    public let authorizationCode: String?
    public let expiresAt: Date?

    public init(
        user: AuthUser,
        idToken: String? = nil,
        authorizationCode: String? = nil,
        expiresAt: Date? = nil
    ) {
        self.user = user
        self.idToken = idToken
        self.authorizationCode = authorizationCode
        self.expiresAt = expiresAt
    }
}

/// Authentication and account errors.
public enum AuthError: Error, LocalizedError, Equatable, Sendable {
    case cancelled
    case networkError(String)
    case invalidCredentials
    case expiredSession
    case missingConfiguration(String)
    case revocationFailed(String)
    case reauthenticationRequired
    case deletionFailed(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign-in was cancelled."
        case let .networkError(detail):
            return "Connection error: \(detail)"
        case .invalidCredentials:
            return "Invalid account credentials. Please sign in again."
        case .expiredSession:
            return "Your session has expired. Please sign in again."
        case let .missingConfiguration(detail):
            return "Authentication is not configured: \(detail)"
        case let .revocationFailed(detail):
            return "Failed to revoke account access: \(detail)"
        case .reauthenticationRequired:
            return "For security, please re-authenticate to delete your account."
        case let .deletionFailed(detail):
            return "Account deletion could not be completed: \(detail)"
        case let .unknown(detail):
            return detail
        }
    }
}

/// Raw payload from Apple's ASAuthorizationAppleIDCredential.
public struct AppleCredentialPayload: Sendable {
    public let userIdentifier: String
    public let identityToken: Data?
    public let authorizationCode: Data?
    public let email: String?
    public let fullName: PersonNameComponents?
    public let rawNonce: String?
    public let realUserStatus: Int

    public init(
        userIdentifier: String,
        identityToken: Data? = nil,
        authorizationCode: Data? = nil,
        email: String? = nil,
        fullName: PersonNameComponents? = nil,
        rawNonce: String? = nil,
        realUserStatus: Int = 0
    ) {
        self.userIdentifier = userIdentifier
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.email = email
        self.fullName = fullName
        self.rawNonce = rawNonce
        self.realUserStatus = realUserStatus
    }

    public var formattedFullName: String? {
        guard let fullName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let formatted = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
        return formatted.isEmpty ? nil : formatted
    }

    public var identityTokenString: String? {
        guard let identityToken else { return nil }
        return String(data: identityToken, encoding: .utf8)
    }

    public var authorizationCodeString: String? {
        guard let authorizationCode else { return nil }
        return String(data: authorizationCode, encoding: .utf8)
    }
}

/// Raw payload from Google Sign-In.
public struct GoogleCredentialPayload: Sendable {
    public let userID: String
    public let idToken: String?
    public let email: String?
    public let displayName: String?
    public let avatarURL: URL?

    public init(
        userID: String,
        idToken: String? = nil,
        email: String? = nil,
        displayName: String? = nil,
        avatarURL: URL? = nil
    ) {
        self.userID = userID
        self.idToken = idToken
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}
