import Foundation
import PLCore

/// The calendar system a rule is expressed in. A rule's "cycle year" is a year in this system.
public enum CalendarSystem: String, Codable, Sendable {
    case gregorian
    case julian
    /// Islamic (Hijri) calendar, computed with Foundation's Umm al-Qura implementation.
    case hijri
}

public enum Computus: String, Codable, Sendable {
    /// Western churches (Gregorian calendar).
    case gregorian
    /// Eastern Orthodox churches (Julian calendar), result converted to Gregorian.
    case julian
}

/// How to find a date within one cycle year. Rules are data (see `observances.json`).
public indirect enum DateRule: Codable, Hashable, Sendable {
    /// A fixed Gregorian date, e.g. Western Christmas (12-25).
    case fixedGregorian(month: Int, day: Int)
    /// A fixed Julian-calendar date, e.g. Christmas for Julian-calendar Orthodox churches.
    case fixedJulian(month: Int, day: Int)
    /// Easter (by the given computus) plus an offset, e.g. Good Friday = -2, Pentecost = +49.
    case easter(computus: Computus, offsetDays: Int)
    /// The n-th given ISO weekday (1 = Mon … 7 = Sun) strictly before a fixed Gregorian date,
    /// e.g. First Sunday of Advent = 4th Sunday before 12-25.
    case weekdayBefore(month: Int, day: Int, isoWeekday: Int, occurrence: Int)
    /// A Hijri month/day (Umm al-Qura). Always an *estimate* of actual observance.
    case hijri(month: Int, day: Int)
    /// Another rule shifted by whole days (e.g. last day of Ramadan = 1 Shawwal − 1).
    case offset(rule: DateRule, days: Int)

    public var calendarSystem: CalendarSystem {
        switch self {
        case .fixedGregorian, .weekdayBefore: .gregorian
        case .fixedJulian: .julian
        case let .easter(computus, _): computus == .gregorian ? .gregorian : .julian
        case .hijri: .hijri
        case let .offset(rule, _): rule.calendarSystem
        }
    }

    /// The Gregorian civil date this rule yields in the given cycle year, or `nil` if it
    /// does not occur (e.g. Feb 29 in a common year).
    public func evaluate(cycleYear year: Int) -> CivilDate? {
        switch self {
        case let .fixedGregorian(month, day):
            let date = CivilDate(year: year, month: month, day: day)
            return date.isValid ? date : nil

        case let .fixedJulian(month, day):
            return JulianCalendar.gregorianDate(julianYear: year, month: month, day: day)

        case let .easter(computus, offset):
            let easter: CivilDate? = switch computus {
            case .gregorian: EasterComputus.gregorianEaster(year: year)
            case .julian: EasterComputus.julianEasterInGregorian(year: year)
            }
            return easter?.adding(days: offset)

        case let .weekdayBefore(month, day, isoWeekday, occurrence):
            let anchor = CivilDate(year: year, month: month, day: day)
            guard anchor.isValid, (1...7).contains(isoWeekday), occurrence >= 1 else { return nil }
            var back = (anchor.isoWeekday - isoWeekday + 7) % 7
            if back == 0 { back = 7 }
            return anchor.adding(days: -back - 7 * (occurrence - 1))

        case let .hijri(month, day):
            return HijriCalendar.gregorianDate(hijriYear: year, month: month, day: day)

        case let .offset(rule, days):
            return rule.evaluate(cycleYear: year)?.adding(days: days)
        }
    }
}

// MARK: - Computus

public enum EasterComputus {
    /// Western Easter Sunday (Anonymous Gregorian algorithm / Meeus–Jones–Butcher).
    public static func gregorianEaster(year: Int) -> CivilDate {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return CivilDate(year: year, month: month, day: day)
    }

    /// Orthodox Easter (Pascha): Julian computus (Meeus), returned as a Gregorian date.
    public static func julianEasterInGregorian(year: Int) -> CivilDate? {
        let a = year % 4
        let b = year % 7
        let c = year % 19
        let d = (19 * c + 15) % 30
        let e = (2 * a + 4 * b - d + 34) % 7
        let month = (d + e + 114) / 31
        let day = (d + e + 114) % 31 + 1
        return JulianCalendar.gregorianDate(julianYear: year, month: month, day: day)
    }
}

public enum JulianCalendar {
    /// Converts a Julian-calendar date to the proleptic Gregorian civil date.
    public static func gregorianDate(julianYear year: Int, month: Int, day: Int) -> CivilDate? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        let jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
        return CivilDate(julianDayNumber: jdn)
    }
}

public enum HijriCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let utcGregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Gregorian civil date for a Hijri date, or `nil` if that day does not exist
    /// (e.g. the 30th of a 29-day month).
    public static func gregorianDate(hijriYear: Int, month: Int, day: Int) -> CivilDate? {
        let components = DateComponents(year: hijriYear, month: month, day: day)
        guard let date = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == hijriYear, roundTrip.month == month, roundTrip.day == day else { return nil }
        return CivilDate(date, calendar: utcGregorian)
    }

    public static func hijriYear(containing date: CivilDate) -> Int {
        calendar.component(.year, from: date.startDate(in: utcGregorian))
    }

    public static func hijriComponents(of date: CivilDate) -> (year: Int, month: Int, day: Int) {
        let c = calendar.dateComponents([.year, .month, .day], from: date.startDate(in: utcGregorian))
        return (c.year!, c.month!, c.day!)
    }
}
