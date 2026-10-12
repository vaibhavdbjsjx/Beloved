import Foundation
import PLFaith

public struct CatalogIssue: Hashable, Sendable, CustomStringConvertible {
    public enum Severity: String, Sendable {
        /// Blocks a release build.
        case error
        /// Acceptable in development; must be resolved before content is approved.
        case warning
    }

    public var severity: Severity
    public var itemID: ContentItemID?
    public var message: String

    public init(_ severity: Severity, _ itemID: ContentItemID?, _ message: String) {
        self.severity = severity
        self.itemID = itemID
        self.message = message
    }

    public var description: String {
        "[\(severity.rawValue)] \(itemID?.rawValue ?? "catalog"): \(message)"
    }
}

/// Structural and provenance checks for the content catalog.
///
/// This is the automated half of content integrity; the other half is human review
/// (`ReviewInfo`). Run in unit tests and as a release gate.
public struct CatalogValidator: Sendable {
    public let registry: FaithRegistry

    public init(registry: FaithRegistry) { self.registry = registry }

    public func validate(_ catalog: ContentCatalog) -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        var seen = Set<ContentItemID>()
        let knownThemes = Set(catalog.taxonomy.themes.map(\.id))

        for mood in Mood.allCases where catalog.taxonomy.moodThemes[mood] == nil {
            issues.append(.init(.warning, nil, "mood '\(mood.rawValue)' has no theme mapping"))
        }
        for (mood, themes) in catalog.taxonomy.moodThemes {
            for theme in themes where !knownThemes.contains(theme) {
                issues.append(.init(.error, nil, "mood '\(mood.rawValue)' maps to unknown theme '\(theme)'"))
            }
        }

        for item in catalog.items {
            if !seen.insert(item.id).inserted {
                issues.append(.init(.error, item.id, "duplicate item id"))
            }
            issues += validateTaxonomy(item, knownThemes: knownThemes)
            if item.segments.isEmpty {
                issues.append(.init(.error, item.id, "item has no segments"))
            }
            for (index, segment) in item.segments.enumerated() {
                issues += validate(segment, index: index, in: item)
            }
            if item.title.isEmpty {
                issues.append(.init(.error, item.id, "missing title"))
            }
            if item.review.status != .approved {
                issues.append(.init(.warning, item.id, "not approved (status: \(item.review.status.rawValue))"))
            }
        }
        return issues
    }

    private func validateTaxonomy(_ item: ContentItem, knownThemes: Set<ThemeID>) -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        if let faithID = item.faith {
            guard let faith = registry.faith(faithID) else {
                return [.init(.error, item.id, "unknown faith '\(faithID)'")]
            }
            for tradition in item.traditions where registry.faith(owning: tradition) != faithID {
                issues.append(.init(.error, item.id, "tradition '\(tradition)' does not belong to \(faithID)"))
            }
            for focus in item.focuses where registry.faith(owning: focus) != faithID {
                issues.append(.init(.error, item.id, "focus '\(focus)' does not belong to \(faithID)"))
            }
            if !faith.practices.contains(item.kind) {
                issues.append(.init(.error, item.id, "practice '\(item.kind.rawValue)' is not declared for \(faithID)"))
            }
        } else if !item.traditions.isEmpty || !item.focuses.isEmpty {
            issues.append(.init(.error, item.id, "faith-neutral item cannot reference traditions or focuses"))
        }
        for theme in item.themes where !knownThemes.contains(theme) {
            issues.append(.init(.error, item.id, "unknown theme '\(theme)'"))
        }
        return issues
    }

    private func validate(_ segment: ContentSegment, index: Int, in item: ContentItem) -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        let label = "segment \(index) (\(segment.role.rawValue))"

        if !segment.hasDisplayableText {
            issues.append(.init(.error, item.id, "\(label) has no text"))
        }
        if segment.role == .generatedPrayer {
            issues.append(.init(.error, item.id, "\(label): AI-generated text is not allowed in the curated catalog"))
        }
        if segment.role == .composedPrayer, (segment.author ?? "").isEmpty {
            issues.append(.init(.error, item.id, "\(label): composed prayers must name an author/editor"))
        }
        if segment.role.requiresCitation, segment.citation == nil {
            issues.append(.init(.error, item.id, "\(label): citation required"))
        }
        if let citation = segment.citation {
            issues += validate(citation, label: label, role: segment.role, item: item)
        }
        if !segment.role.claimsSourceFidelity, segment.role != .explanation, segment.original != nil {
            issues.append(.init(.warning, item.id, "\(label): original-script text on a non-source segment"))
        }
        return issues
    }

    private func validate(
        _ citation: SourceCitation,
        label: String,
        role: SegmentRole,
        item: ContentItem
    ) -> [CatalogIssue] {
        guard registry.source(citation.source) != nil else {
            return [.init(.error, item.id, "\(label): unknown source '\(citation.source)'")]
        }
        var issues: [CatalogIssue] = []
        if role == .sourceText {
            guard let editionID = citation.edition else {
                return [.init(.error, item.id, "\(label): verbatim source text must cite an edition")]
            }
            guard let edition = registry.edition(editionID), registry.source(owning: editionID) == citation.source else {
                return [.init(.error, item.id, "\(label): edition '\(editionID)' is not an edition of '\(citation.source)'")]
            }
            if !edition.license.permitsRedistribution {
                issues.append(.init(.warning, item.id, "\(label): edition '\(editionID)' rights not cleared — blocked in release"))
            }
        }
        if (citation.reference ?? "").isEmpty, role == .sourceText || role == .paraphrase {
            issues.append(.init(.error, item.id, "\(label): citation needs a reference"))
        }
        return issues
    }
}

public extension Array where Element == CatalogIssue {
    var errors: [CatalogIssue] { filter { $0.severity == .error } }
    var warnings: [CatalogIssue] { filter { $0.severity == .warning } }
}
