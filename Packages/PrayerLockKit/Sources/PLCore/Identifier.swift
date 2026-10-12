import Foundation

/// A strongly-typed, string-backed identifier.
///
/// `Tag` is a phantom type that prevents mixing identifiers of different kinds
/// (e.g. passing a `TraditionID` where a `FaithID` is expected) while keeping the
/// JSON representation a plain string so content files stay human-editable.
public struct Identifier<Tag>: RawRepresentable, Hashable, Comparable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension Identifier: Codable {
    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Lets dictionaries keyed by identifiers encode as JSON objects instead of key/value arrays.
extension Identifier: CodingKeyRepresentable {
    public var codingKey: any CodingKey { AnyCodingKey(rawValue) }

    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}
