import Foundation

/// iOS Data Protection class applied to a persisted file.
///
/// Prayer history, moods, and journal entries are sensitive (religious belief is
/// "special category" data under GDPR), so private app data defaults to `.complete`:
/// the file is unreadable while the device is locked.
public enum DataProtection: Sendable {
    case complete
    case completeUnlessOpen
    case completeUntilFirstUserAuthentication
    case none

    var writingOption: Data.WritingOptions {
        switch self {
        case .complete: .completeFileProtection
        case .completeUnlessOpen: .completeFileProtectionUnlessOpen
        case .completeUntilFirstUserAuthentication: .completeFileProtectionUntilFirstUserAuthentication
        case .none: .noFileProtection
        }
    }
}

public enum StorageError: Error, Equatable, Sendable {
    case containerUnavailable(String)
    case coordinationFailed(String)
    case decodingFailed(String)
}

/// A single Codable value persisted as JSON with atomic, file-coordinated writes.
///
/// File coordination matters because the app and its extensions are separate
/// processes that may touch the same App Group files.
public struct CodableFileStore<Value: Codable & Sendable>: Sendable {
    public let url: URL
    public let protection: DataProtection

    public init(url: URL, protection: DataProtection = .complete) {
        self.url = url
        self.protection = protection
    }

    /// Returns `nil` when nothing has been saved yet.
    public func load() throws -> Value? {
        var result: Result<Value?, any Error> = .success(nil)
        try coordinate { coordinator, error in
            coordinator.coordinate(readingItemAt: url, options: [], error: error) { readURL in
                result = Result { try Self.read(readURL) }
            }
        }
        return try result.get()
    }

    public func save(_ value: Value) throws {
        var result: Result<Void, any Error> = .success(())
        try coordinate { coordinator, error in
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: error) { writeURL in
                result = Result { try write(value, to: writeURL) }
            }
        }
        try result.get()
    }

    /// Coordinated read-modify-write. Starts from `initial` when nothing is stored.
    @discardableResult
    public func update(
        initial: @autoclosure () -> Value,
        _ transform: (inout Value) throws -> Void
    ) throws -> Value {
        var result: Result<Value, any Error> = .failure(StorageError.coordinationFailed(url.lastPathComponent))
        try coordinate { coordinator, error in
            coordinator.coordinate(writingItemAt: url, options: .forMerging, error: error) { fileURL in
                result = Result {
                    var value = try Self.read(fileURL) ?? initial()
                    try transform(&value)
                    try write(value, to: fileURL)
                    return value
                }
            }
        }
        return try result.get()
    }

    public func delete() throws {
        var result: Result<Void, any Error> = .success(())
        try coordinate { coordinator, error in
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: error) { deleteURL in
                result = Result {
                    if FileManager.default.fileExists(atPath: deleteURL.path) {
                        try FileManager.default.removeItem(at: deleteURL)
                    }
                }
            }
        }
        try result.get()
    }

    // MARK: - Private

    private func coordinate(
        _ body: (NSFileCoordinator, NSErrorPointer) -> Void
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        body(coordinator, &coordinationError)
        if let coordinationError {
            throw StorageError.coordinationFailed(coordinationError.localizedDescription)
        }
    }

    private static func read(_ fileURL: URL) throws -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        do {
            return try JSONDecoder.prayerLock().decode(Value.self, from: data)
        } catch {
            throw StorageError.decodingFailed("\(fileURL.lastPathComponent): \(error)")
        }
    }

    private func write(_ value: Value, to fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.prayerLock().encode(value)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, protection.writingOption])
        #else
        // Data Protection classes are an iOS concept; macOS (unit tests) uses FileVault.
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }
}
