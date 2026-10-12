import Foundation
import PLCore
import PLFaith

public enum ContentCatalogError: Error, Equatable, Sendable {
    case resourceMissing(String)
}

/// The curated content library plus its taxonomy.
///
/// The bundled items carry their own review status; release builds show only items that
/// `ContentPolicy.release` permits (approved and rights-cleared).
public struct ContentCatalog: Sendable {
    public let items: [ContentItem]
    public let taxonomy: ContentTaxonomy
    private let itemsByID: [ContentItemID: ContentItem]

    public init(items: [ContentItem], taxonomy: ContentTaxonomy) {
        self.items = items
        self.taxonomy = taxonomy
        // Duplicate IDs are reported by CatalogValidator; keep the first occurrence here.
        self.itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public func item(_ id: ContentItemID) -> ContentItem? { itemsByID[id] }

    /// Items the given policy allows users to see.
    public func visibleItems(policy: ContentPolicy, registry: FaithRegistry) -> [ContentItem] {
        items.filter { policy.permits($0, registry: registry) }
    }

    /// Editions quoted by the content users can actually see — what the Sources screen
    /// must attribute. Editions that no visible item quotes are not listed.
    public func citedEditions(policy: ContentPolicy, registry: FaithRegistry) -> Set<EditionID> {
        Set(visibleItems(policy: policy, registry: registry)
            .flatMap(\.segments)
            .compactMap { $0.citation?.edition })
    }

    public static func bundled() throws -> ContentCatalog {
        let decoder = JSONDecoder.prayerLock()
        func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
                throw ContentCatalogError.resourceMissing("\(name).json")
            }
            return try decoder.decode(T.self, from: Data(contentsOf: url))
        }
        // Editorial items plus the devotional library imported verbatim from pinned sources
        // (scripts/import_devotions.py).
        return ContentCatalog(
            items: try load("content-fixtures", as: [ContentItem].self) + load("devotions", as: [ContentItem].self),
            taxonomy: try load("taxonomy", as: ContentTaxonomy.self)
        )
    }
}
