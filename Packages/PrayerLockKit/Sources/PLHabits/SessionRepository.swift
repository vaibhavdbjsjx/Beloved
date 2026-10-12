import Foundation
import PLCore
import Synchronization

/// Persistence for prayer sessions.
public protocol SessionRepository: Sendable {
    func allSessions() async throws -> [PrayerSession]
    func append(_ session: PrayerSession) async throws
    /// Permanently removes all history (user-initiated "Delete my data").
    func deleteAll() async throws
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
}
