import Foundation
import PLFaith

/// Which content is allowed to reach users in a given build.
public struct ContentPolicy: Hashable, Sendable {
    /// Minimum editorial status for content to be shown.
    public var minimumReviewStatus: ReviewInfo.Status
    /// Whether verbatim text from editions with uncleared rights may be shown.
    public var allowsUnclearedEditions: Bool

    public init(minimumReviewStatus: ReviewInfo.Status, allowsUnclearedEditions: Bool) {
        self.minimumReviewStatus = minimumReviewStatus
        self.allowsUnclearedEditions = allowsUnclearedEditions
    }

    /// Release builds: only approved content from rights-cleared editions.
    public static let release = ContentPolicy(minimumReviewStatus: .approved, allowsUnclearedEditions: false)

    /// Development builds: drafts are visible (and badged as unreviewed in the UI).
    public static let development = ContentPolicy(minimumReviewStatus: .draft, allowsUnclearedEditions: true)

    public func permits(_ item: ContentItem, registry: FaithRegistry) -> Bool {
        guard item.review.status != .rejected, item.review.status >= minimumReviewStatus else { return false }
        guard !allowsUnclearedEditions else { return true }
        // Every verbatim segment must come from an edition whose rights are cleared.
        return item.segments.allSatisfy { segment in
            guard segment.role == .sourceText else { return true }
            guard let editionID = segment.citation?.edition, let edition = registry.edition(editionID) else {
                return false
            }
            return edition.license.permitsRedistribution
        }
    }
}
