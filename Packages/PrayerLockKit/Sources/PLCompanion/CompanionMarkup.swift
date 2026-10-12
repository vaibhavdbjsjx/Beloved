import Foundation

/// The companion's answer, split into what the model wrote and what the app must fill in.
///
/// The model never writes scripture, mantras or traditional prayers itself. Where it wants one,
/// it writes a marker and the app inserts the verified text from the on-device library:
///
///     ⟦bible:PSA 23:1-3⟧      ⟦bible:Psalm 23:1-3⟧      ⟦quran:94:5-6⟧      ⟦gita:2:47⟧
///     ⟦prayer:hinduism.mantra.gayatri⟧
///
/// Anything between `⟦` and `⟧` that doesn't resolve is shown as a plain reference — never as text.
public enum CompanionBlock: Hashable, Sendable {
    case text(String)
    case marker(CompanionMarker)
}

public struct CompanionMarker: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A scripture passage: work (`bible`, `quran`, `bhagavad-gita`) and its reference text.
        case scripture(work: String, reference: String)
        /// A library item (prayer, mantra, dua…) by id.
        case prayer(id: String)
        /// Unknown kind — kept so it can be shown honestly as a reference.
        case unknown
    }

    public var raw: String
    public var kind: Kind

    public init(raw: String) {
        self.raw = raw
        kind = Self.parse(raw)
    }

    static let workAliases: [String: String] = [
        "bible": "bible", "quran": "quran", "qur'an": "quran", "koran": "quran",
        "gita": "bhagavad-gita", "bhagavad-gita": "bhagavad-gita", "bhagavadgita": "bhagavad-gita",
    ]

    private static func parse(_ raw: String) -> Kind {
        let body = raw.trimmingCharacters(in: .whitespaces)
        guard let colon = body.firstIndex(of: ":") else { return .unknown }
        let prefix = body[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
        let rest = body[body.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return .unknown }
        if prefix == "prayer" || prefix == "mantra" || prefix == "dua" { return .prayer(id: rest) }
        if let work = workAliases[prefix] { return .scripture(work: work, reference: rest) }
        return .unknown
    }
}

public enum CompanionMarkup {
    public static let open: Character = "⟦"
    public static let close: Character = "⟧"

    /// Splits text into prose and markers. While a reply is still streaming (`isComplete ==
    /// false`), an unfinished marker at the end is held back rather than shown half-typed.
    public static func blocks(from text: String, isComplete: Bool = true) -> [CompanionBlock] {
        var blocks: [CompanionBlock] = []
        var prose = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == open {
                guard let end = text[index...].firstIndex(of: close) else {
                    // Unterminated: hold it back while streaming; show it literally once complete.
                    if isComplete { prose += text[index...] }
                    break
                }
                if !prose.isEmpty {
                    blocks.append(.text(prose))
                    prose = ""
                }
                let inner = String(text[text.index(after: index)..<end])
                blocks.append(.marker(CompanionMarker(raw: inner)))
                index = text.index(after: end)
                continue
            }
            prose.append(character)
            index = text.index(after: index)
        }
        if !prose.isEmpty { blocks.append(.text(prose)) }
        return blocks.compactMap { block in
            if case let .text(value) = block, value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
            return block
        }
    }
}
