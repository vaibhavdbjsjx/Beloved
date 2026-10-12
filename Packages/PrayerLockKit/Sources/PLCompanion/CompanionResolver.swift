import Foundation
import PLContent
import PLFaith
import PLScripture

/// A companion answer ready to display: the model's words, and verified texts in place of
/// its markers.
public enum ResolvedCompanionBlock: Hashable, Sendable {
    case text(String)
    case passage(ResolvedPassage)
    case prayer(ContentItem)
    /// A marker the app couldn't fill (unknown reference, or text this build may not show):
    /// shown as a plain reference, never as words the model wrote.
    case reference(String)
}

/// Fills markers from the bundled, verified library — the only source of holy text the
/// companion ever shows.
public struct CompanionResolver: Sendable {
    let library: ScriptureLibrary
    let scripturePolicy: ScripturePolicy
    let catalog: ContentCatalog
    let contentPolicy: ContentPolicy
    let registry: FaithRegistry

    public init(
        library: ScriptureLibrary,
        scripturePolicy: ScripturePolicy,
        catalog: ContentCatalog,
        contentPolicy: ContentPolicy,
        registry: FaithRegistry
    ) {
        self.library = library
        self.scripturePolicy = scripturePolicy
        self.catalog = catalog
        self.contentPolicy = contentPolicy
        self.registry = registry
    }

    public func resolve(_ blocks: [CompanionBlock]) async -> [ResolvedCompanionBlock] {
        var resolved: [ResolvedCompanionBlock] = []
        for block in blocks {
            switch block {
            case let .text(text):
                resolved.append(.text(text))
            case let .marker(marker):
                resolved.append(await resolve(marker))
            }
        }
        return resolved
    }

    public func resolve(_ marker: CompanionMarker) async -> ResolvedCompanionBlock {
        switch marker.kind {
        case let .scripture(work, reference):
            let workID = SourceWorkID(work)
            guard let scriptureWork = library.manifest.work(workID),
                  let parsed = ScriptureReferenceFormatter.parse(reference, in: scriptureWork),
                  let passage = try? await library.resolve(parsed, in: workID, policy: scripturePolicy, registry: registry)
            else { return .reference(displayReference(marker)) }
            return .passage(passage)
        case let .prayer(id):
            guard let item = catalog.item(ContentItemID(id)), contentPolicy.permits(item, registry: registry) else {
                return .reference(displayReference(marker))
            }
            return .prayer(item)
        case .unknown:
            return .reference(displayReference(marker))
        }
    }

    /// "Psalm 23:1-3" rather than "bible:PSA 23:1-3" when shown as a plain reference.
    private func displayReference(_ marker: CompanionMarker) -> String {
        switch marker.kind {
        case let .scripture(work, reference):
            let title = library.manifest.work(SourceWorkID(work))?.shortTitle.resolved(for: ["en"]) ?? work
            if work == "bible" { return reference }
            return "\(title) \(reference)"
        case let .prayer(id):
            return catalog.item(ContentItemID(id))?.title.resolved(for: ["en"]) ?? id
        case .unknown:
            return marker.raw
        }
    }
}
