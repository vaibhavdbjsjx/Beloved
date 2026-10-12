import Foundation
import PLCore
import PLFaith

public enum ReligiousCalendarError: Error, Equatable, Sendable {
    case resourceMissing(String)
    case mixedCalendarSystems(OccasionID)
    case invalidWeekday(OccasionID)
}

/// Resolves which religious observances fall on given days for a user's faith/tradition.
public struct ReligiousCalendar: Sendable {
    public let definitions: [ObservanceDefinition]

    public init(definitions: [ObservanceDefinition]) throws {
        for definition in definitions {
            switch definition.schedule {
            case let .rule(start, end):
                if let end, end.calendarSystem != start.calendarSystem {
                    throw ReligiousCalendarError.mixedCalendarSystems(definition.id)
                }
            case let .weekly(isoWeekday):
                guard (1...7).contains(isoWeekday) else {
                    throw ReligiousCalendarError.invalidWeekday(definition.id)
                }
            case .table:
                break
            }
        }
        self.definitions = definitions
    }

    public static func bundled() throws -> ReligiousCalendar {
        guard let url = Bundle.module.url(forResource: "observances", withExtension: "json") else {
            throw ReligiousCalendarError.resourceMissing("observances.json")
        }
        let definitions = try JSONDecoder.prayerLock().decode([ObservanceDefinition].self, from: Data(contentsOf: url))
        return try ReligiousCalendar(definitions: definitions)
    }

    /// Observances overlapping `range` for the given faith/tradition, sorted by start date.
    /// Weekly observances are expanded into individual days.
    public func observances(
        in range: CivilDateRange,
        faith: FaithID?,
        tradition: TraditionID?,
        region: String? = nil
    ) -> [Observance] {
        definitions
            .filter { $0.applies(faith: faith, tradition: tradition) }
            .flatMap { occurrences(of: $0, in: range, region: region) }
            .sorted { ($0.range.start, $0.definition.id) < ($1.range.start, $1.definition.id) }
    }

    public func observances(on date: CivilDate, faith: FaithID?, tradition: TraditionID?) -> [Observance] {
        observances(in: CivilDateRange(single: date), faith: faith, tradition: tradition)
    }

    // MARK: - Occurrence expansion

    func occurrences(of definition: ObservanceDefinition, in range: CivilDateRange, region: String?) -> [Observance] {
        switch definition.schedule {
        case let .weekly(isoWeekday):
            return range.days
                .filter { $0.isoWeekday == isoWeekday }
                .map { Observance(definition: definition, range: CivilDateRange(single: $0), region: nil) }

        case let .table(entries):
            return entries
                .filter { $0.range.overlaps(range) && (region == nil || $0.region == nil || $0.region == region) }
                .map { Observance(definition: definition, range: $0.range, region: $0.region) }

        case let .rule(start, end):
            return cycleYears(for: start.calendarSystem, covering: range).compactMap { year in
                guard let first = start.evaluate(cycleYear: year) else { return nil }
                let last = end.flatMap { $0.evaluate(cycleYear: year) } ?? first
                guard first <= last else { return nil }
                let occurrence = CivilDateRange(start: first, end: last)
                guard occurrence.overlaps(range) else { return nil }
                return Observance(definition: definition, range: occurrence, region: nil)
            }
        }
    }

    /// Cycle years (in the rule's own calendar system) whose occurrences could overlap `range`.
    /// Padded by one year on each side for seasons that straddle a year boundary.
    func cycleYears(for system: CalendarSystem, covering range: CivilDateRange) -> ClosedRange<Int> {
        switch system {
        case .gregorian, .julian:
            return (range.start.year - 1)...(range.end.year + 1)
        case .hijri:
            return (HijriCalendar.hijriYear(containing: range.start) - 1)...(HijriCalendar.hijriYear(containing: range.end) + 1)
        }
    }
}
