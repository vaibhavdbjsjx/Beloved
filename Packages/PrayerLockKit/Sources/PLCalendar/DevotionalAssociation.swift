import Foundation
import PLCore
import PLFaith

/// A cultural/devotional custom linking a weekday to a focus or theme
/// (e.g. "In many Hindu communities, Monday is associated with Shiva").
///
/// These are **customs that vary by region and tradition, not universal rules**.
/// They only influence content when the user opts in
/// (`SpiritualProfile.useDevotionalAssociations`), and are always shown with their
/// explanation so users understand why a suggestion appeared.
public struct DevotionalAssociation: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var faith: FaithID
    /// Empty = not specific to a tradition.
    public var traditions: [TraditionID]
    /// ISO weekday: 1 = Monday … 7 = Sunday.
    public var isoWeekday: Int
    public var focus: FocusID?
    public var themes: [ThemeID]
    public var explanation: LocalizedText

    public init(
        id: String,
        faith: FaithID,
        traditions: [TraditionID] = [],
        isoWeekday: Int,
        focus: FocusID?,
        themes: [ThemeID] = [],
        explanation: LocalizedText
    ) {
        self.id = id
        self.faith = faith
        self.traditions = traditions
        self.isoWeekday = isoWeekday
        self.focus = focus
        self.themes = themes
        self.explanation = explanation
    }
}

public struct DevotionalAssociations: Sendable {
    public let all: [DevotionalAssociation]

    public init(_ all: [DevotionalAssociation]) { self.all = all }

    public static func bundled() throws -> DevotionalAssociations {
        guard let url = Bundle.module.url(forResource: "devotional-associations", withExtension: "json") else {
            throw ReligiousCalendarError.resourceMissing("devotional-associations.json")
        }
        return DevotionalAssociations(
            try JSONDecoder.prayerLock().decode([DevotionalAssociation].self, from: Data(contentsOf: url))
        )
    }

    /// Associations for `date`, honoring the user's opt-in and faith/tradition.
    public func associations(on date: CivilDate, profile: SpiritualProfile) -> [DevotionalAssociation] {
        guard profile.useDevotionalAssociations, let faith = profile.faithID else { return [] }
        return all.filter { association in
            association.faith == faith
                && association.isoWeekday == date.isoWeekday
                && (association.traditions.isEmpty
                    || profile.traditionID.map(association.traditions.contains) == true)
        }
    }
}
