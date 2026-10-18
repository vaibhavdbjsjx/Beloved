import Foundation
import Security

/// Thread-safe contract for storing sensitive credentials.
public protocol SecureStorage: Sendable {
    func read(key: String) throws -> Data?
    func write(key: String, data: Data) throws
    func delete(key: String) throws
    func deleteAll() throws
}

/// Keychain-backed implementation using kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.
/// Credentials are kept purely on this device and are never included in iCloud Keychain backups.
public final class KeychainSecureStorage: SecureStorage, @unchecked Sendable {
    private let service: String
    private let lock = NSLock()

    public init(service: String = "com.beloved.auth") {
        self.service = service
    }

    public func read(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        return item as? Data
    }

    public func write(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let checkStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if checkStatus == errSecSuccess {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(updateStatus)
            }
        } else if checkStatus == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        } else {
            throw KeychainError.unhandledStatus(checkStatus)
        }
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unhandledStatus(status)
        }
    }

    public enum KeychainError: Error, LocalizedError, Sendable {
        case unhandledStatus(OSStatus)

        public var errorDescription: String? {
            switch self {
            case let .unhandledStatus(status):
                return "Keychain error status: \(status)"
            }
        }
    }
}

/// In-memory storage for unit tests, previews, and throwaway UI test instances.
public final class InMemorySecureStorage: SecureStorage, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func read(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func write(key: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    public func delete(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

/// Coordinates persistence of the user's active session in secure storage.
public struct AccountSessionStore: Sendable {
    private let storage: any SecureStorage
    private let sessionKey = "current_user_session"
    private let log = Log.logger(.storage)

    public init(storage: any SecureStorage) {
        self.storage = storage
    }

    public func loadSession() -> AuthSession? {
        do {
            guard let data = try storage.read(key: sessionKey) else {
                return nil
            }
            return try JSONDecoder().decode(AuthSession.self, from: data)
        } catch {
            log.error("Could not load auth session from secure storage: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    public func saveSession(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try storage.write(key: sessionKey, data: data)
    }

    public func clearSession() throws {
        try storage.delete(key: sessionKey)
    }
}
