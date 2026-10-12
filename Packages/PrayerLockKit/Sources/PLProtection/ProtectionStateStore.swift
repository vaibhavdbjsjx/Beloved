import Foundation
import PLCore

/// Operational state shared between the app and its Screen Time extensions through
/// the App Group. Contains no personal or spiritual data by design.
public struct ProtectionStateStore: Sendable {
    enum Key {
        static let settings = "protection.settings"
        static let grant = "protection.grant"
        static let requests = "protection.shieldRequests"
        static let shieldCopy = "protection.shieldCopy"
        static let selection = "protection.selection"
        static let needsReselection = "protection.needsReselection"
    }

    /// Requests older than this are considered abandoned.
    public static let requestLifetime: TimeInterval = 10 * 60
    static let maxStoredRequests = 10

    private let store: any KeyValueStore

    public init(store: any KeyValueStore) { self.store = store }

    // MARK: Settings

    public func settings() -> ProtectionSettings {
        store.value(ProtectionSettings.self, forKey: Key.settings) ?? .default
    }

    public func save(_ settings: ProtectionSettings) {
        store.setValue(settings, forKey: Key.settings)
    }

    // MARK: Unlock grant

    public func grant() -> UnlockGrant? { store.value(UnlockGrant.self, forKey: Key.grant) }

    public func activeGrant(at date: Date) -> UnlockGrant? {
        grant().flatMap { $0.isActive(at: date) ? $0 : nil }
    }

    public func save(_ grant: UnlockGrant) { store.setValue(grant, forKey: Key.grant) }

    public func clearGrant() { store.removeValue(forKey: Key.grant) }

    // MARK: Shield requests

    public func recordRequest(_ request: ShieldRequest) {
        var requests = pendingRequests(at: request.createdAt)
        requests.append(request)
        store.setValue(Array(requests.suffix(Self.maxStoredRequests)), forKey: Key.requests)
    }

    public func pendingRequests(at date: Date) -> [ShieldRequest] {
        (store.value([ShieldRequest].self, forKey: Key.requests) ?? [])
            .filter { date.timeIntervalSince($0.createdAt) < Self.requestLifetime && $0.createdAt <= date.addingTimeInterval(60) }
    }

    /// Returns the newest pending request and clears the queue.
    public func takeLatestRequest(at date: Date) -> ShieldRequest? {
        let latest = pendingRequests(at: date).max { $0.createdAt < $1.createdAt }
        store.removeValue(forKey: Key.requests)
        return latest
    }

    // MARK: Shield copy

    public func shieldCopy() -> ShieldCopy? { store.value(ShieldCopy.self, forKey: Key.shieldCopy) }

    public func save(_ copy: ShieldCopy) { store.setValue(copy, forKey: Key.shieldCopy) }

    // MARK: Activity selection (opaque, platform-encoded)

    /// The JSON-encoded selection (`FamilyActivitySelection` on iOS), kept opaque so this
    /// type stays platform-neutral.
    public func selectionData() -> Data? { store.data(forKey: Key.selection) }

    public func saveSelectionData(_ data: Data?) { store.set(data, forKey: Key.selection) }

    public func selection<Selection: ProtectionSelection>(_ type: Selection.Type) -> Selection? {
        selectionData().flatMap { try? JSONDecoder().decode(Selection.self, from: $0) }
    }

    public func saveSelection<Selection: ProtectionSelection>(_ selection: Selection) {
        saveSelectionData(try? JSONEncoder().encode(selection))
    }

    /// Set when stored tokens could not be refreshed: the user must choose apps again.
    public var needsReselection: Bool { store.value(Bool.self, forKey: Key.needsReselection) ?? false }

    public func setNeedsReselection(_ value: Bool) {
        if value { store.setValue(true, forKey: Key.needsReselection) } else { store.removeValue(forKey: Key.needsReselection) }
    }

    // MARK: Diagnostics

    public var events: ProtectionEventLog { ProtectionEventLog(store: store) }

    /// Whether the user tapped "Begin" on a shield recently and the moment is waiting.
    public func hasPendingRequest(at date: Date) -> Bool { !pendingRequests(at: date).isEmpty }

    /// Store backed by the App Group's UserDefaults (falls back to standard defaults,
    /// with a logged error, when the App Group is not entitled — e.g. unsigned builds).
    public static func shared(appGroupIdentifier: String?) -> ProtectionStateStore {
        guard let identifier = appGroupIdentifier, let defaults = UserDefaults(suiteName: identifier) else {
            Log.logger(.protection).error("App Group unavailable; protection state is not shared with extensions")
            return ProtectionStateStore(store: UserDefaultsKeyValueStore(defaults: .standard))
        }
        return ProtectionStateStore(store: UserDefaultsKeyValueStore(defaults: defaults))
    }

    /// Removes all shared protection state (part of "Delete my data").
    public func reset() {
        for key in [Key.settings, Key.grant, Key.requests, Key.shieldCopy, Key.selection, Key.needsReselection] {
            store.removeValue(forKey: key)
        }
        events.clear()
    }
}
