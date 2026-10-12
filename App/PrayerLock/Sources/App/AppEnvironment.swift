import Foundation
import PLAssistant
import PLCalendar
import PLCompanion
import PLContent
import PLCore
import PLFaith
import PLHabits
import PLMonetization
import PLProtection
import PLScripture

/// Composition root: the only place that knows concrete implementations.
/// Every service is created once here and handed to the UI through `AppModel`.
@MainActor
final class AppEnvironment {
    let configuration: AppConfiguration
    let calendar: Calendar
    let registry: FaithRegistry
    let catalog: ContentCatalog
    let contentPolicy: ContentPolicy
    let selector: ContentSelector
    let scripture: ScriptureLibrary
    let scripturePolicy: ScripturePolicy
    let religiousCalendar: ReligiousCalendar
    let devotionalAssociations: DevotionalAssociations
    let profileStore: ProfileStore
    let sessions: any SessionRepository
    let protectionState: ProtectionStateStore
    let protection: ScreenTimeProtectionController
    let monetization: MonetizationConfiguration
    let purchases: any PurchaseService
    let notifications: NotificationService
    /// On-device answers from the verified library (free; also the companion's fallback).
    let assistant: AssistantPipeline
    /// The cloud companion, when a server is configured and subscriptions exist.
    let companionTransport: any CompanionTransport
    let companionResolver: CompanionResolver
    let companionStore: CodableFileStore<CompanionConversation>

    private init(
        configuration: AppConfiguration,
        locations: StorageLocations,
        protectionState: ProtectionStateStore
    ) throws {
        self.configuration = configuration
        calendar = .autoupdatingCurrent
        registry = try FaithRegistry.bundled()
        catalog = try ContentCatalog.bundled()
        contentPolicy = configuration.isDevelopment ? .development : .release
        selector = ContentSelector(catalog: catalog, registry: registry, policy: contentPolicy)
        scripture = try ScriptureLibrary()
        scripturePolicy = configuration.isDevelopment ? .development : .release
        religiousCalendar = try ReligiousCalendar.bundled()
        devotionalAssociations = try DevotionalAssociations.bundled()
        profileStore = ProfileStore(fileURL: locations.privateFile("profile.json"))
        sessions = FileSessionRepository(fileURL: locations.privateFile("sessions.json"))
        self.protectionState = protectionState
        protection = ScreenTimeProtectionController(
            platform: ScreenTimePlatform(appGroupIdentifier: configuration.appGroupIdentifier),
            state: protectionState
        )
        monetization = try MonetizationConfiguration.bundled()
        purchases = monetization.isPaywallEnabled
            ? StoreKitPurchaseService(configuration: monetization, subscriptionGroupID: configuration.subscriptionGroupID)
            : UnavailablePurchaseService()
        notifications = NotificationService()
        notifications.activate()
        assistant = AssistantPipeline(
            parser: IntentParser(registry: registry, taxonomy: catalog.taxonomy),
            contextResolver: FaithContextResolver(calendar: religiousCalendar, associations: devotionalAssociations),
            retriever: CatalogSourceRetriever(selector: selector)
        )
        if let endpoint = configuration.assistantEndpoint, monetization.isPaywallEnabled {
            let purchases = purchases
            companionTransport = CloudCompanionTransport(endpoint: endpoint) { await purchases.subscriptionProof() }
        } else {
            companionTransport = UnavailableCompanionTransport()
        }
        companionResolver = CompanionResolver(
            library: scripture, scripturePolicy: scripturePolicy,
            catalog: catalog, contentPolicy: contentPolicy, registry: registry
        )
        companionStore = CodableFileStore(url: locations.privateFile("companion.json"), protection: .complete)
    }

    /// Whether the cloud companion can be used in this build at all (server + subscriptions).
    var isCompanionCloudConfigured: Bool { !(companionTransport is UnavailableCompanionTransport) }

    static func live() throws -> AppEnvironment {
        let configuration = AppConfiguration.fromBundle()
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.uiTesting) {
            // Isolated, throwaway storage so UI tests never touch real user data.
            return try AppEnvironment(
                configuration: configuration,
                locations: .temporary(named: ProcessInfo.processInfo.environment[LaunchArgument.uiTestStoreKey]),
                protectionState: ProtectionStateStore(store: InMemoryKeyValueStore())
            )
        }
        return try AppEnvironment(
            configuration: configuration,
            locations: StorageLocations.standard(appGroupIdentifier: configuration.appGroupIdentifier),
            protectionState: .shared(appGroupIdentifier: configuration.appGroupIdentifier)
        )
    }
}

enum LaunchArgument {
    static let uiTesting = "-PLUITesting"
    /// UI tests only: environment key naming a temporary store that survives relaunches.
    static let uiTestStoreKey = "PL_UI_TEST_STORE"
}

/// Product name in one place. The home-screen name comes from
/// `INFOPLIST_KEY_CFBundleDisplayName`; keep the two in sync. The App Store name is set
/// in App Store Connect and must be unique there (see docs/19-app-store-readiness.md).
enum AppBrand {
    static let displayName = "Beloved"
}
