import Foundation
import PLCore
import PLFaith

public enum ObservanceKind: String, Codable, Sendable {
    case feast
    case fast
    case season
    case festival
    case holyDay
    case weekly
    case commemoration
}

/// How trustworthy a computed date is. Shown to users where it matters.
public enum ObservancePrecision: String, Codable, Sendable {
    /// Deterministic from a published rule (e.g. Easter computus).
    case computed
    /// Astronomical/tabular estimate; actual observance depends on local authority or
    /// moon sighting (e.g. Islamic dates). UI must say "expected" / "may vary".
    case estimated
    /// Taken from a cited published table (e.g. a regional panchang).
    case sourcedTable
}

/// A dated table row (used where dates cannot be reliably computed on-device,
/// e.g. Hindu lunisolar festivals that vary by region and panchang).
public struct DatedEntry: Codable, Hashable, Sendable {
    public var range: CivilDateRange
    /// Region the date applies to (e.g. "IN-north", "IN-MH"), `nil` = general.
    public var region: String?
    public var source: String

    public init(range: CivilDateRange, region: String? = nil, source: String) {
        self.range = range
        self.region = region
        self.source = source
    }
}

public enum ObservanceSchedule: Codable, Hashable, Sendable {
    /// `end == nil` → single-day observance. Both rules must share a calendar system.
    case rule(start: DateRule, end: DateRule?)
    /// Every week on an ISO weekday (1 = Mon … 7 = Sun), e.g. Jumu'ah, the Lord's Day.
    case weekly(isoWeekday: Int)
    case table(entries: [DatedEntry])
}

public struct ObservanceDefinition: Codable, Identifiable, Hashable, Sendable {
    public var id: OccasionID
    public var faith: FaithID
    /// Empty = observed across the faith's traditions.
    public var traditions: [TraditionID]
    /// Include for users who did not specify a tradition (e.g. Western Easter yes, Orthodox Pascha no).
    public var includeWhenTraditionUnspecified: Bool
    public var name: LocalizedText
    public var kind: ObservanceKind
    public var schedule: ObservanceSchedule
    public var precision: ObservancePrecision
    /// User-facing context, e.g. how observance differs between traditions.
    public var note: LocalizedText?
    /// Where the rule or dates come from.
    public var source: String

    public init(
        id: OccasionID,
        faith: FaithID,
        traditions: [TraditionID] = [],
        includeWhenTraditionUnspecified: Bool = true,
        name: LocalizedText,
        kind: ObservanceKind,
        schedule: ObservanceSchedule,
        precision: ObservancePrecision,
        note: LocalizedText? = nil,
        source: String
    ) {
        self.id = id
        self.faith = faith
        self.traditions = traditions
        self.includeWhenTraditionUnspecified = includeWhenTraditionUnspecified
        self.name = name
        self.kind = kind
        self.schedule = schedule
        self.precision = precision
        self.note = note
        self.source = source
    }

    func applies(faith: FaithID?, tradition: TraditionID?) -> Bool {
        guard let faith, faith == self.faith else { return false }
        guard !traditions.isEmpty else { return true }
        guard let tradition else { return includeWhenTraditionUnspecified }
        return traditions.contains(tradition)
    }
}

/// One concrete occurrence of an observance.
public struct Observance: Hashable, Identifiable, Sendable {
    public var id: String { "\(definition.id)@\(range.start)" }
    public let definition: ObservanceDefinition
    public let range: CivilDateRange
    public let region: String?

    public var occasionID: OccasionID { definition.id }
    public var isEstimated: Bool { definition.precision == .estimated }
}
