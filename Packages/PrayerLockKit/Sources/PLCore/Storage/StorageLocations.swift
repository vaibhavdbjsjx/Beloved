import Foundation

/// Where the app keeps data on disk (directory names are internal and stable).
///
/// Two deliberately separate locations:
/// - **Private** (the app's own Application Support): profile, prayer history, journal.
///   Extensions cannot read it. Protected with `.complete` Data Protection.
/// - **Shared** (the App Group container): only the operational state the Screen Time
///   extensions need — protection settings, shield copy, pending shield requests.
///   Nothing sensitive goes here (principle of least sharing).
public struct StorageLocations: Sendable {
    public let privateDirectory: URL
    public let sharedDirectory: URL?
    public let appGroupIdentifier: String?

    public init(privateDirectory: URL, sharedDirectory: URL?, appGroupIdentifier: String?) {
        self.privateDirectory = privateDirectory
        self.sharedDirectory = sharedDirectory
        self.appGroupIdentifier = appGroupIdentifier
    }

    /// Resolves the standard locations for the current process.
    public static func standard(appGroupIdentifier: String?) throws -> StorageLocations {
        let fileManager = FileManager.default
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let privateDirectory = support.appending(path: "PrayerLock", directoryHint: .isDirectory)
        let shared = appGroupIdentifier.flatMap {
            fileManager.containerURL(forSecurityApplicationGroupIdentifier: $0)
        }
        return StorageLocations(
            privateDirectory: privateDirectory,
            sharedDirectory: shared?.appending(path: "Shared", directoryHint: .isDirectory),
            appGroupIdentifier: appGroupIdentifier
        )
    }

    /// Temporary, isolated locations for tests and previews.
    /// Throwaway storage. A `name` reuses the same folder across launches (UI tests that
    /// relaunch the app); without one, every launch starts empty.
    public static func temporary(named name: String? = nil) -> StorageLocations {
        let folder = name.map { "PrayerLock-UITest-\($0)" } ?? "PrayerLock-\(UUID().uuidString)"
        let root = FileManager.default.temporaryDirectory
            .appending(path: folder, directoryHint: .isDirectory)
        return StorageLocations(
            privateDirectory: root.appending(path: "Private", directoryHint: .isDirectory),
            sharedDirectory: root.appending(path: "Shared", directoryHint: .isDirectory),
            appGroupIdentifier: nil
        )
    }

    public func privateFile(_ name: String) -> URL {
        privateDirectory.appending(path: name, directoryHint: .notDirectory)
    }

    public func sharedFile(_ name: String) throws -> URL {
        guard let sharedDirectory else {
            throw StorageError.containerUnavailable(appGroupIdentifier ?? "<no app group configured>")
        }
        return sharedDirectory.appending(path: name, directoryHint: .notDirectory)
    }

    /// The App Group `UserDefaults`, or `nil` when the group is not configured/entitled.
    public func sharedDefaults() -> UserDefaults? {
        appGroupIdentifier.flatMap(UserDefaults.init(suiteName:))
    }
}
