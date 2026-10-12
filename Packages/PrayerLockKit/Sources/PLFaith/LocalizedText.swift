import Foundation

/// Text keyed by BCP-47 language code (`en`, `hi`, `ar`, `es`, …).
///
/// Content is data, not UI strings, so it is localized in the content files rather
/// than in the app's String Catalog. In JSON a bare string is accepted as English.
public struct LocalizedText: Hashable, Sendable, ExpressibleByStringLiteral {
    public var values: [String: String]

    public init(_ values: [String: String]) { self.values = values }
    public init(english: String) { values = ["en": english] }
    public init(stringLiteral value: String) { values = ["en": value] }

    public static let fallbackLanguage = "en"

    /// Best text for the user's preferred languages, falling back to English, then anything.
    public func resolved(for preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        for language in preferredLanguages {
            if let exact = values[language] { return exact }
            let base = Locale.Language(identifier: language).languageCode?.identifier
            if let base, let match = values[base] { return match }
        }
        return values[Self.fallbackLanguage] ?? values.sorted { $0.key < $1.key }.first?.value ?? ""
    }

    public var isEmpty: Bool { values.values.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
    public var languages: Set<String> { Set(values.keys) }
}

extension LocalizedText: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let single = try? container.decode(String.self) {
            values = [Self.fallbackLanguage: single]
        } else {
            values = try container.decode([String: String].self)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}
