import Foundation
import PLCalendar
import PLContent
import PLCore
import PLFaith

/// Faith/tradition context assembled for a request.
public struct FaithContext: Hashable, Sendable {
    public var faith: FaithID?
    public var tradition: TraditionID?
    public var focus: FocusID?
    /// Observances active on the request date (for the resolved faith/tradition).
    public var occasions: [OccasionID]
    /// Explanations of devotional customs relevant to the request (always shown with the answer).
    public var devotionalNotes: [String]
    public var devotionalFocuses: [FocusID]
}

public struct FaithContextResolver: Sendable {
    let calendar: ReligiousCalendar
    let associations: DevotionalAssociations

    public init(calendar: ReligiousCalendar, associations: DevotionalAssociations) {
        self.calendar = calendar
        self.associations = associations
    }

    public func resolve(_ intent: AssistantIntent, request: AssistantRequest) -> FaithContext {
        // An explicit faith in the request wins (people may ask about another tradition);
        // the user's tradition only applies when it belongs to that faith.
        let faith = intent.faith ?? request.profile.faithID
        let tradition = faith == request.profile.faithID ? request.profile.traditionID : nil
        let today = CivilDate(request.date, calendar: request.calendar)

        let occasions = calendar.observances(on: today, faith: faith, tradition: tradition).map(\.occasionID)

        // Weekday customs: used when the user names a weekday ("for Monday"), or when
        // they opted into devotional associations for today.
        var notes: [String] = []
        var focuses: [FocusID] = []
        if let faith {
            var profile = request.profile
            profile.faithID = faith
            profile.traditionID = tradition
            let day: CivilDate
            if let weekday = intent.isoWeekday {
                profile.useDevotionalAssociations = true
                day = today.adding(days: (weekday - today.isoWeekday + 7) % 7)
            } else {
                day = today
            }
            for association in associations.associations(on: day, profile: profile)
            where intent.focus == nil || association.focus == intent.focus {
                notes.append(association.explanation.resolved(for: request.profile.languages))
                if let focus = association.focus { focuses.append(focus) }
            }
        }
        return FaithContext(
            faith: faith,
            tradition: tradition,
            focus: intent.focus,
            occasions: occasions,
            devotionalNotes: notes,
            devotionalFocuses: focuses
        )
    }
}

/// Output of the retrieval stage.
public struct RetrievalResult: Sendable {
    /// Verified source/traditional passages the generator may reference by ID.
    public var passages: [RetrievedPassage]
    /// The best whole library item for the request (used when no generator is available).
    public var bestItem: ContentItem?

    public init(passages: [RetrievedPassage], bestItem: ContentItem?) {
        self.passages = passages
        self.bestItem = bestItem
    }
}

/// Retrieval stage: finds verified passages in the curated library.
public protocol SourceRetriever: Sendable {
    func retrieve(_ intent: AssistantIntent, context: FaithContext, request: AssistantRequest, limit: Int) -> RetrievalResult
}

/// Retrieves from the bundled/approved catalog using the same selector as prayer
/// moments, so retrieval honours review status, rights clearance, and premium gating.
public struct CatalogSourceRetriever: SourceRetriever {
    let selector: ContentSelector

    public init(selector: ContentSelector) { self.selector = selector }

    public func retrieve(
        _ intent: AssistantIntent,
        context: FaithContext,
        request: AssistantRequest,
        limit: Int
    ) -> RetrievalResult {
        var profile = request.profile
        profile.faithID = context.faith
        profile.traditionID = context.tradition
        if let focus = context.focus { profile.focusIDs = [focus] }

        var selection = SelectionContext(
            profile: profile,
            mood: intent.mood ?? request.mood,
            themes: Set(intent.themes),
            date: request.date,
            calendar: request.calendar,
            activeOccasions: Set(context.occasions),
            devotionalFocuses: Set(context.devotionalFocuses),
            hasPremium: request.hasPremium,
            preferredKinds: intent.practice.map { [$0] } ?? []
        )

        // An explicit reference ("explain Psalm 46:10") is matched directly — still
        // subject to the same eligibility rules (review status, rights, premium).
        if let reference = intent.reference.map(Self.normalize) {
            let items = selector.catalog.items.filter { item in
                selector.isEligible(item, selection)
                    && item.segments.contains { Self.normalize($0.citation?.reference) == reference }
            }
            if let item = items.first {
                return RetrievalResult(passages: Array(items.flatMap(passages(in:)).prefix(limit)), bestItem: item)
            }
        }

        let ranked = selector.rank(selection)
        var result = ranked.flatMap { passages(in: $0.item) }
        if result.count < limit, !selection.preferredKinds.isEmpty {
            // e.g. a *prayer* request: ground it in scripture/traditional texts too.
            selection.preferredKinds = []
            for passage in selector.rank(selection).flatMap({ passages(in: $0.item) }) where !result.contains(passage) {
                result.append(passage)
            }
        }
        return RetrievalResult(passages: Array(result.prefix(limit)), bestItem: ranked.first?.item)
    }

    func passages(in item: ContentItem) -> [RetrievedPassage] {
        let explanations = item.segments.filter { $0.role == .explanation }
        return item.segments.enumerated().compactMap { index, segment in
            guard segment.role.claimsSourceFidelity else { return nil }
            return RetrievedPassage(
                id: "\(item.id.rawValue)#\(index)",
                itemID: item.id,
                title: item.title,
                segment: segment,
                explanations: explanations
            )
        }
    }

    static func normalize(_ reference: String?) -> String {
        (reference ?? "").lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "psalms", with: "psalm")
            .filter { !$0.isWhitespace }
    }
}
