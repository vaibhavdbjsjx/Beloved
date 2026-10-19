import Foundation

/// Build-time configuration read from the host bundle's Info.plist.
///
/// Values originate in `Config/*.xcconfig` and are injected into Info.plist via
/// build-setting substitution. Secrets never live here: anything in Info.plist
/// ships inside the binary and is readable by anyone who downloads the app.
public struct AppConfiguration: Sendable, Equatable {
    public enum Environment: String, Sendable {
        case development
        case production
    }

    public enum InfoKey {
        public static let environment = "PLEnvironment"
        public static let appGroupIdentifier = "PLAppGroupIdentifier"
        public static let assistantEndpoint = "PLAssistantEndpoint"
        public static let subscriptionGroupID = "PLSubscriptionGroupID"
        public static let supportURL = "PLSupportURL"
        public static let privacyPolicyURL = "PLPrivacyPolicyURL"
    }

    public var environment: Environment
    /// The App Group shared by the app and its Screen Time extensions.
    public var appGroupIdentifier: String?
    /// Public base URL of the (future) assistant proxy. Not a secret — the proxy
    /// holds model-provider keys server-side. `nil` disables the assistant.
    public var assistantEndpoint: URL?
    /// App Store Connect subscription group identifier.
    public var subscriptionGroupID: String?
    /// Public support page (the App Store "Support URL"). `nil` hides the in-app link,
    /// so the app never shows a link to a page that doesn't exist yet.
    public var supportURL: URL?
    /// Hosted copy of the privacy policy. The full policy is also bundled in the app,
    /// so it is readable offline whether or not this is set.
    public var privacyPolicyURL: URL?

    public init(
        environment: Environment,
        appGroupIdentifier: String?,
        assistantEndpoint: URL?,
        subscriptionGroupID: String?,
        supportURL: URL? = nil,
        privacyPolicyURL: URL? = nil
    ) {
        self.environment = environment
        self.appGroupIdentifier = appGroupIdentifier
        self.assistantEndpoint = assistantEndpoint
        self.subscriptionGroupID = subscriptionGroupID
        self.supportURL = supportURL
        self.privacyPolicyURL = privacyPolicyURL
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        from(infoDictionary: bundle.infoDictionary ?? [:])
    }

    public static func from(infoDictionary: [String: Any]) -> AppConfiguration {
        func string(_ key: String) -> String? {
            guard let value = infoDictionary[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            // Unresolved build settings ("$(FOO)") or empty values mean "not configured".
            return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
        }
        return AppConfiguration(
            // Fail closed: a missing or unknown value must never expose draft content or
            // diagnostics, so it means production. Debug builds set "development" explicitly.
            environment: string(InfoKey.environment).flatMap(Environment.init(rawValue:)) ?? .production,
            appGroupIdentifier: string(InfoKey.appGroupIdentifier),
            assistantEndpoint: string(InfoKey.assistantEndpoint).flatMap(URL.init(string:)),
            subscriptionGroupID: string(InfoKey.subscriptionGroupID),
            supportURL: string(InfoKey.supportURL).flatMap(secureWebURL),
            privacyPolicyURL: string(InfoKey.privacyPolicyURL).flatMap(secureWebURL)
        )
    }

    /// Only absolute `https` URLs with a host are accepted for user-facing links.
    static func secureWebURL(_ string: String) -> URL? {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https",
              let host = url.host(), !host.isEmpty else { return nil }
        return url
    }

    public var isDevelopment: Bool { environment == .development }
}
