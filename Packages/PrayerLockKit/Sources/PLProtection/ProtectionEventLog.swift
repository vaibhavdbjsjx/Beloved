import Foundation
import PLCore

/// One protection lifecycle event, recorded for on-device troubleshooting.
///
/// Contains no app names, tokens, prayer content, or moods — only what happened, when,
/// and counts/durations. Stays on the device; cleared by "Delete all my data".
public struct ProtectionEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case authorizationRequested
        case authorizationFailed
        case selectionUpdated
        case protectionEnabled
        case protectionDisabled
        case shieldsApplied
        case shieldsCleared
        case dailyGuardFailed
        case dailyGuardFired
        case unlockGranted
        case relockSchedulingFailed
        case relockFired
        case staleRelockIgnored
        case shieldBeginTapped
        case shieldNotNowTapped
        case tokensRefreshed
        case tokenRefreshFailed
    }

    public var date: Date
    public var kind: Kind
    public var detail: String?

    public init(date: Date, kind: Kind, detail: String? = nil) {
        self.date = date
        self.kind = kind
        self.detail = detail
    }
}

/// Bounded event log in the App Group, written by the app, the Shield Action extension,
/// and the Activity Monitor extension. (The Shield Configuration extension is sandboxed
/// read-only and never writes.)
///
/// Cross-process writes are last-writer-wins, so an entry can occasionally be lost when
/// two processes write at the same instant. Acceptable for diagnostics; never used for logic.
public struct ProtectionEventLog: Sendable {
    static let key = "protection.events"
    public static let capacity = 100

    private let store: any KeyValueStore

    public init(store: any KeyValueStore) { self.store = store }

    public func record(_ kind: ProtectionEvent.Kind, detail: String? = nil, at date: Date = Date()) {
        var events = store.value([ProtectionEvent].self, forKey: Self.key) ?? []
        events.append(ProtectionEvent(date: date, kind: kind, detail: detail))
        store.setValue(Array(events.suffix(Self.capacity)), forKey: Self.key)
    }

    /// Newest first.
    public func recent() -> [ProtectionEvent] {
        (store.value([ProtectionEvent].self, forKey: Self.key) ?? []).reversed()
    }

    public func clear() { store.removeValue(forKey: Self.key) }
}
