import Foundation
import os

/// Keeps a person's Beloved data in their own iCloud (the iCloud key-value store), so it comes
/// back after reinstalling or on a new iPhone. No account and no Beloved server: Apple syncs it
/// with the Apple ID on the device, and only that person can read it.
///
/// Each kind of data is one blob with a timestamp; the newest write wins. The prayer-time
/// location and companion conversations are never synced.
@MainActor
final class CloudSync {
    enum Key: String, CaseIterable {
        case profile, journal, plans, prayerSettings, festivals, sessions
    }

    /// Set by the app to apply data that arrived from iCloud (another device, or a reinstall).
    var onRemoteChange: ((Set<Key>) -> Void)?

    private let store = NSUbiquitousKeyValueStore.default
    private let defaults: UserDefaults
    private let isActive: Bool
    private let log = Logger(subsystem: "com.vaibhavsg.beloved", category: "sync")
    private static let enabledKey = "pl.icloudSync"
    /// The key-value store holds 1 MB in all; keep every blob well under it.
    private static let maximumBlobBytes = 600_000

    /// `isActive` is false under UI tests, so tests never touch a real iCloud account.
    init(defaults: UserDefaults, isActive: Bool) {
        self.defaults = defaults
        self.isActive = isActive
    }

    /// On by default; the person can turn it off in You.
    var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    func start() {
        guard isActive else { return }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] note in
            let changed = (note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? []
            let keys = Set(changed.compactMap { Key(rawValue: $0.replacingOccurrences(of: ".t", with: "")) })
            MainActor.assumeIsolated { self?.remoteChanged(keys) }
        }
        store.synchronize()
        remoteChanged(Set(Key.allCases))
    }

    /// Uploads one kind of data after a local change.
    func push(_ key: Key, _ data: Data) {
        guard isActive, isEnabled else { return }
        guard data.count <= Self.maximumBlobBytes else {
            log.error("Not syncing \(key.rawValue, privacy: .public): \(data.count) bytes is too large")
            return
        }
        let stamp = Date.now.timeIntervalSince1970
        store.set(data, forKey: key.rawValue)
        store.set(stamp, forKey: key.rawValue + ".t")
        defaults.set(stamp, forKey: localStampKey(key))
    }

    func push<T: Encodable>(_ key: Key, encoding value: T) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        push(key, data)
    }

    /// Whether iCloud already holds this kind of data.
    func hasRemote(_ key: Key) -> Bool {
        isActive && store.object(forKey: key.rawValue) != nil
    }

    /// iCloud's copy, if it is newer than what this iPhone has. Marks it as seen.
    func newerRemote(_ key: Key) -> Data? {
        guard isActive, isEnabled, let data = store.data(forKey: key.rawValue) else { return nil }
        let remote = store.double(forKey: key.rawValue + ".t")
        guard remote > defaults.double(forKey: localStampKey(key)) else { return nil }
        defaults.set(remote, forKey: localStampKey(key))
        return data
    }

    /// "Delete all data" also removes the iCloud copy, on every device.
    func deleteAll() {
        for key in Key.allCases {
            defaults.removeObject(forKey: localStampKey(key))
            guard isActive else { continue }
            store.removeObject(forKey: key.rawValue)
            store.removeObject(forKey: key.rawValue + ".t")
        }
        if isActive { store.synchronize() }
    }

    private func remoteChanged(_ keys: Set<Key>) {
        guard isEnabled, !keys.isEmpty else { return }
        onRemoteChange?(keys)
    }

    private func localStampKey(_ key: Key) -> String { "pl.sync.\(key.rawValue).t" }
}
