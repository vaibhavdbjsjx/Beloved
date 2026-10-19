import Foundation
import PLCore
import Synchronization

/// Persistence for prayer sessions.
public protocol SessionRepository: Sendable {
    func allSessions() async throws -> [PrayerSession]
    func append(_ session: PrayerSession) async throws
    /// Permanently removes all history (user-initiated "Delete my data").
    func deleteAll() async throws
    /// Adds sessions recorded on another device (iCloud sync); ones already here are kept.
    func merge(_ sessions: [PrayerSession]) async throws
}

extension Array where Element == PrayerSession {
    /// Union by id, oldest first.
    func merged(with other: [PrayerSession]) -> [PrayerSession] {
        let known = Set(map(\.id))
        return (self + other.filter { !known.contains($0.id) }).sorted { $0.startedAt < $1.startedAt }
    }
}

/// File-backed repository in the app's *private* container with `.complete` protection.
/// Extensions never read prayer history.
public actor FileSessionRepository: SessionRepository {
    private let store: CodableFileStore<[PrayerSession]>

    public init(fileURL: URL) {
        store = CodableFileStore(url: fileURL, protection: .complete)
    }

    public func allSessions() async throws -> [PrayerSession] {
        try store.load() ?? []
    }

    public func append(_ session: PrayerSession) async throws {
        try store.update(initial: []) { $0.append(session) }
    }

    public func deleteAll() async throws {
        try store.delete()
    }

    public func merge(_ sessions: [PrayerSession]) async throws {
        try store.update(initial: []) { $0 = $0.merged(with: sessions) }
    }
}

/// In-memory repository for tests and previews.
public final class InMemorySessionRepository: SessionRepository {
    private let sessions: Mutex<[PrayerSession]>

    public init(_ sessions: [PrayerSession] = []) {
        self.sessions = Mutex(sessions)
    }

    public func allSessions() async throws -> [PrayerSession] { sessions.withLock { $0 } }

    public func append(_ session: PrayerSession) async throws { sessions.withLock { $0.append(session) } }

    public func deleteAll() async throws { sessions.withLock { $0.removeAll() } }

    public func merge(_ other: [PrayerSession]) async throws { sessions.withLock { $0 = $0.merged(with: other) } }
}
