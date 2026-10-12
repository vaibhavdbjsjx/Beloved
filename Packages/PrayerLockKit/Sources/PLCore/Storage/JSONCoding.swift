import Foundation

public extension JSONEncoder {
    /// Encoder used for everything the app persists. Stable key order keeps
    /// exported files diff-able; ISO-8601 dates keep data exports human-readable.
    static func prayerLock() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static func prayerLock() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
