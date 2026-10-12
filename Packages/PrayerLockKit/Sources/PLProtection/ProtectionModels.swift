import Foundation

/// How long protected apps stay open after a completed prayer moment.
public enum UnlockDuration: Codable, Hashable, Sendable {
    case minutes(Int)
    case restOfDay

    public static let options: [UnlockDuration] = [.minutes(5), .minutes(15), .minutes(30), .minutes(60), .restOfDay]
}

/// User-chosen protection behaviour. Lives in the App Group (extensions read it).
public struct ProtectionSettings: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var unlockDuration: UnlockDuration

    public init(isEnabled: Bool, unlockDuration: UnlockDuration) {
        self.isEnabled = isEnabled
        self.unlockDuration = unlockDuration
    }

    public static let `default` = ProtectionSettings(isEnabled: false, unlockDuration: .minutes(15))
}

/// Temporary access granted after a completed prayer moment.
public struct UnlockGrant: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var grantedAt: Date
    /// Latest moment access ends (wall clock). Access may end earlier via `usageLimit`.
    public var expiresAt: Date
    /// Re-shield after this much *use* of protected apps, if set.
    public var usageLimit: TimeInterval?
    public var sessionID: UUID?

    public init(id: UUID = UUID(), grantedAt: Date, expiresAt: Date, usageLimit: TimeInterval?, sessionID: UUID?) {
        self.id = id
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.usageLimit = usageLimit
        self.sessionID = sessionID
    }

    public func isActive(at date: Date) -> Bool { date < expiresAt }
}

/// Written by the Shield Action extension when the user taps "Begin" on a shield,
/// read by the app to open the prayer moment for that app.
public struct ShieldRequest: Codable, Hashable, Sendable, Identifiable {
    public enum Subject: String, Codable, Sendable {
        case application
        case category
        case webDomain
    }

    public var id: UUID
    public var createdAt: Date
    public var subject: Subject
    /// The JSON-encoded opaque Screen Time token (ApplicationToken, etc.). The app can
    /// render it with `Label(token)` but can never learn which app it is.
    public var tokenData: Data?

    public init(id: UUID = UUID(), createdAt: Date, subject: Subject, tokenData: Data?) {
        self.id = id
        self.createdAt = createdAt
        self.subject = subject
        self.tokenData = tokenData
    }
}

/// Text the Screen Time extensions display. Prepared by the app (which has the full
/// localization and content stack) so the extensions stay tiny.
/// Must never contain personal data — the shield is visible to anyone holding the phone.
public struct ShieldCopy: Codable, Hashable, Sendable {
    public static let appNameToken = "{app}"

    public var title: String
    /// Title when the shielded app's name is known; contains `{app}`.
    public var titleForApp: String
    public var subtitle: String
    public var primaryButton: String
    public var secondaryButton: String
    /// Subtitle after "Begin" was tapped, while the moment is waiting in the app.
    public var awaitingSubtitle: String
    public var notificationTitle: String
    public var notificationBody: String

    public init(
        title: String,
        titleForApp: String,
        subtitle: String,
        primaryButton: String,
        secondaryButton: String,
        awaitingSubtitle: String,
        notificationTitle: String,
        notificationBody: String
    ) {
        self.title = title
        self.titleForApp = titleForApp
        self.subtitle = subtitle
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.awaitingSubtitle = awaitingSubtitle
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
    }

    public func title(forApp name: String?) -> String {
        guard let name, !name.isEmpty else { return title }
        return titleForApp.replacingOccurrences(of: Self.appNameToken, with: name)
    }

    /// Used by extensions before the app has written localized copy. The tone is
    /// deliberate: the user chose this pause; nothing here shames them for opening an app.
    public static let englishFallback = ShieldCopy(
        title: "You chose to protect this app",
        titleForApp: "You chose to protect {app}",
        subtitle: "Take a moment before opening it.",
        primaryButton: "Begin",
        secondaryButton: "Not now",
        awaitingSubtitle: "Open Beloved to begin your moment.",
        notificationTitle: "Your moment is ready",
        notificationBody: "Tap to begin your moment."
    )
}

public enum ProtectionStatus: Hashable, Sendable {
    /// Screen Time APIs are not available in this environment.
    case unavailable
    /// Never set up: Screen Time access hasn't been granted yet.
    case needsAuthorization
    /// Was set up, but Screen Time access is no longer granted (turned off in Settings,
    /// or not yet reported by iOS right after launch). Choices are kept for recovery.
    case authorizationRevoked
    /// Stored app tokens could not be refreshed; the user must choose apps again.
    case needsReselection
    case needsSelection
    case off
    case active
    case unlocked(until: Date)

    public static func derive(
        isSupported: Bool,
        isAuthorized: Bool,
        hasSelection: Bool,
        needsReselection: Bool = false,
        settings: ProtectionSettings,
        grant: UnlockGrant?,
        now: Date
    ) -> ProtectionStatus {
        guard isSupported else { return .unavailable }
        guard isAuthorized else {
            // A saved selection can only exist if access was granted before.
            return hasSelection || settings.isEnabled ? .authorizationRevoked : .needsAuthorization
        }
        if needsReselection { return .needsReselection }
        guard hasSelection else { return .needsSelection }
        guard settings.isEnabled else { return .off }
        if let grant, grant.isActive(at: now) { return .unlocked(until: grant.expiresAt) }
        return .active
    }

    /// Whether the UI should show a recovery prompt.
    public var needsRecovery: Bool { self == .authorizationRevoked || self == .needsReselection }
}
