import Foundation

/// A calendar date with no time or time zone (proleptic Gregorian).
///
/// Religious observances, streak days, and "today's prayer" are all *day* concepts.
/// Modelling them as `Date` (an instant) invites off-by-one bugs around midnight,
/// DST changes, and travel; `CivilDate` keeps day arithmetic exact.
public struct CivilDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The civil date of `date` as observed in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar) {
        let components = Self.gregorianCalendar(timeZone: calendar.timeZone)
            .dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    // MARK: Julian Day Number (exact integer day arithmetic)

    /// Julian Day Number for this proleptic Gregorian date (Fliegel & Van Flandern).
    public var julianDayNumber: Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    public init(julianDayNumber jdn: Int) {
        let a = jdn + 32044
        let b = (4 * a + 3) / 146_097
        let c = a - 146_097 * b / 4
        let d = (4 * c + 3) / 1461
        let e = c - 1461 * d / 4
        let m = (5 * e + 2) / 153
        self.init(
            year: 100 * b + d - 4800 + m / 10,
            month: m + 3 - 12 * (m / 10),
            day: e - (153 * m + 2) / 5 + 1
        )
    }

    public func adding(days: Int) -> CivilDate { CivilDate(julianDayNumber: julianDayNumber + days) }

    public func days(until other: CivilDate) -> Int { other.julianDayNumber - julianDayNumber }

    /// ISO weekday: 1 = Monday … 7 = Sunday.
    public var isoWeekday: Int { (julianDayNumber % 7) + 1 }

    /// Foundation weekday: 1 = Sunday … 7 = Saturday.
    public var gregorianWeekday: Int { isoWeekday % 7 + 1 }

    public var isValid: Bool {
        CivilDate(julianDayNumber: julianDayNumber) == self
    }

    /// Start of this day in `calendar`'s time zone.
    public func startDate(in calendar: Calendar) -> Date {
        let gregorian = Self.gregorianCalendar(timeZone: calendar.timeZone)
        return gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func gregorianCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

/// An inclusive range of civil dates.
public struct CivilDateRange: Hashable, Codable, Sendable {
    public let start: CivilDate
    public let end: CivilDate

    public init(start: CivilDate, end: CivilDate) {
        precondition(start <= end, "CivilDateRange start must not be after end")
        self.start = start
        self.end = end
    }

    public init(single date: CivilDate) { self.init(start: date, end: date) }

    public func contains(_ date: CivilDate) -> Bool { start <= date && date <= end }

    public func overlaps(_ other: CivilDateRange) -> Bool { start <= other.end && other.start <= end }

    public var dayCount: Int { start.days(until: end) + 1 }

    public var days: [CivilDate] { (0..<dayCount).map { start.adding(days: $0) } }
}
