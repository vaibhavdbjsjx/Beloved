import Foundation

/// A bundled legal document (privacy policy, notices) split into display blocks.
///
/// The source is a deliberately small Markdown subset — `#`/`##`/`###` headings,
/// `- ` bullets and paragraphs — so the same file can be shown in the app and published
/// on the web without a Markdown engine. Inline emphasis is kept as written and
/// rendered by the UI (`AttributedString(markdown:)`).
public struct LegalDocument: Equatable, Sendable {
    public enum Block: Equatable, Sendable {
        case title(String)
        case heading(String)
        case subheading(String)
        case paragraph(String)
        case bullet(String)
    }

    public var blocks: [Block]

    public init(blocks: [Block]) {
        self.blocks = blocks
    }

    public var title: String? {
        for case let .title(text) in blocks { return text }
        return nil
    }

    public static func parse(markdown: String) -> LegalDocument {
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
            } else if let text = line.dropPrefix("### ") {
                flushParagraph()
                blocks.append(.subheading(text))
            } else if let text = line.dropPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(text))
            } else if let text = line.dropPrefix("# ") {
                flushParagraph()
                blocks.append(.title(text))
            } else if let text = line.dropPrefix("- ") ?? line.dropPrefix("* ") {
                flushParagraph()
                blocks.append(.bullet(text))
            } else {
                paragraph.append(line)
            }
        }
        flushParagraph()
        return LegalDocument(blocks: blocks)
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        let rest = dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }
}
