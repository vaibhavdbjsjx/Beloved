import Foundation
import Synchronization

/// Small key-value storage for operational state (settings, flags, shield copy).
///
/// Do not put sensitive personal data here: the App Group instance is readable by
/// every extension and is not protected with `.complete` Data Protection.
public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public extension KeyValueStore {
    func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder.prayerLock().decode(T.self, from: data)
    }

    func setValue<T: Encodable>(_ value: T?, forKey key: String) {
        guard let value else {
            set(nil, forKey: key)
            return
        }
        set(try? JSONEncoder.prayerLock().encode(value), forKey: key)
    }

    func removeValue(forKey key: String) { set(nil, forKey: key) }
}

/// `UserDefaults`-backed store (use `UserDefaults(suiteName:)` for the App Group).
public final class UserDefaultsKeyValueStore: KeyValueStore, @unchecked Sendable {
    // UserDefaults is documented as thread-safe.
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) { self.defaults = defaults }

    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }

    public func set(_ data: Data?, forKey key: String) {
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}

/// In-memory store for tests and SwiftUI previews.
public final class InMemoryKeyValueStore: KeyValueStore {
    private let storage = Mutex<[String: Data]>([:])

    public init() {}

    public func data(forKey key: String) -> Data? { storage.withLock { $0[key] } }

    public func set(_ data: Data?, forKey key: String) {
        storage.withLock { $0[key] = data }
    }
}
