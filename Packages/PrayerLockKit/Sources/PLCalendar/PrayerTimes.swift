import Foundation

/// The five daily prayers (with sunrise, which ends Fajr's time), calculated on the device from
/// the sun's position — no network, no location leaves the iPhone.
///
/// The astronomy follows the widely used method published by PrayTimes.org (Hamid Zarrabi-Zadeh),
/// itself based on the U.S. Naval Observatory's low-precision solar formulas: accurate to about a
/// minute, which is why mosques' timetables can differ from it by a few minutes. Communities
/// differ on the twilight angles for Fajr and Isha and on the shadow length for Asr, so both are
/// the user's choice.
public struct PrayerTimes: Equatable, Sendable {
    public enum Prayer: String, CaseIterable, Codable, Sendable, Identifiable {
        case fajr, sunrise, dhuhr, asr, maghrib, isha
        public var id: String { rawValue }
        /// Sunrise is shown for reference — it is not a prayer.
        public var isPrayer: Bool { self != .sunrise }
    }

    public let date: DateComponents
    public let times: [Prayer: Date]

    public func time(_ prayer: Prayer) -> Date? { times[prayer] }

    /// The next prayer after `instant`, if any remain on this day.
    public func next(after instant: Date) -> (prayer: Prayer, time: Date)? {
        Prayer.allCases
            .filter(\.isPrayer)
            .compactMap { prayer in times[prayer].map { (prayer, $0) } }
            .first { $0.1 > instant }
    }

    /// The prayer whose time it currently is (from its start until the next one begins).
    public func current(at instant: Date) -> Prayer? {
        let started = Prayer.allCases.compactMap { prayer in times[prayer].map { (prayer, $0) } }.filter { $0.1 <= instant }
        guard let last = started.last, last.0.isPrayer else { return nil }
        return last.0
    }
}

/// How twilight is measured for Fajr and Isha. These are the conventions published by the
/// organisations they're named after.
public enum PrayerCalculationMethod: String, CaseIterable, Codable, Sendable, Identifiable {
    case muslimWorldLeague
    case northAmerica
    case egypt
    case ummAlQura
    case karachi
    case singapore
    case jafari

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .muslimWorldLeague: "Muslim World League"
        case .northAmerica: "Islamic Society of North America"
        case .egypt: "Egyptian General Authority of Survey"
        case .ummAlQura: "Umm al-Qura University, Makkah"
        case .karachi: "University of Islamic Sciences, Karachi"
        case .singapore: "Majlis Ugama Islam Singapura"
        case .jafari: "Shia Ithna-Ashari (Leva Institute, Qum)"
        }
    }

    /// Sun's depression below the horizon at Fajr.
    var fajrAngle: Double {
        switch self {
        case .muslimWorldLeague, .karachi: 18
        case .northAmerica: 15
        case .egypt: 19.5
        case .ummAlQura: 18.5
        case .singapore: 20
        case .jafari: 16
        }
    }

    enum Isha: Equatable { case angle(Double), minutesAfterMaghrib(Double) }

    var isha: Isha {
        switch self {
        case .muslimWorldLeague: .angle(17)
        case .northAmerica: .angle(15)
        case .egypt: .angle(17.5)
        case .ummAlQura: .minutesAfterMaghrib(90)
        case .karachi: .angle(18)
        case .singapore: .angle(18)
        case .jafari: .angle(14)
        }
    }

    /// Jafari Maghrib waits for the redness to leave the eastern sky (sun 4° below the horizon).
    var maghribAngle: Double? { self == .jafari ? 4 : nil }

    /// A sensible starting point for the user's region; they can always change it.
    public static func suggested(forRegion region: String?) -> PrayerCalculationMethod {
        switch region?.uppercased() {
        case "US", "CA": .northAmerica
        case "PK", "IN", "BD", "AF", "NP", "LK": .karachi
        case "SA", "YE", "BH", "KW", "QA", "AE", "OM": .ummAlQura
        case "EG", "SY", "LB", "JO", "PS", "IQ", "LY", "SD", "SS": .egypt
        case "SG", "MY", "ID", "BN": .singapore
        case "IR": .jafari
        default: .muslimWorldLeague
        }
    }
}

/// The length of the shadow that begins Asr.
public enum AsrSchool: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Shafi'i, Maliki, Hanbali (and Ja'fari): shadow equals the object's length.
    case standard
    /// Hanafi: shadow twice the object's length.
    case hanafi

    public var id: String { rawValue }
    var shadowFactor: Double { self == .hanafi ? 2 : 1 }

    public var name: String {
        switch self {
        case .standard: "Shafi'i, Maliki, Hanbali"
        case .hanafi: "Hanafi"
        }
    }

    public static func suggested(forRegion region: String?) -> AsrSchool {
        switch region?.uppercased() {
        case "PK", "IN", "BD", "AF", "TR", "NP", "LK": .hanafi
        default: .standard
        }
    }
}

public struct PrayerTimeCalculator: Sendable {
    public var method: PrayerCalculationMethod
    public var asr: AsrSchool

    public init(method: PrayerCalculationMethod, asr: AsrSchool) {
        self.method = method
        self.asr = asr
    }

    /// Times for a civil day (in the calendar's time zone) at a place.
    public func times(latitude: Double, longitude: Double, on day: DateComponents, calendar: Calendar) -> PrayerTimes {
        guard let year = day.year, let month = day.month, let dayOfMonth = day.day else {
            return PrayerTimes(date: day, times: [:])
        }
        let jDate = Self.julian(year: year, month: month, day: dayOfMonth) - longitude / (15 * 24)
        let astro = Astronomy(jDate: jDate, latitude: latitude)

        // First estimates (hours), refined once from the sun's position at those moments.
        var fajr = astro.sunAngleTime(method.fajrAngle, at: 5, counterClockwise: true)
        let sunrise = astro.sunAngleTime(0.833, at: 6, counterClockwise: true)
        let dhuhr = astro.midDay(at: 12)
        let asrTime = astro.asrTime(factor: asr.shadowFactor, at: 13)
        let sunset = astro.sunAngleTime(0.833, at: 18)
        var maghrib = method.maghribAngle.map { astro.sunAngleTime($0, at: 18) } ?? sunset
        var isha: Double
        switch method.isha {
        case let .angle(angle): isha = astro.sunAngleTime(angle, at: 18)
        case let .minutesAfterMaghrib(minutes): isha = maghrib + minutes / 60
        }

        // High latitudes: when twilight never ends (or barely does), use the "angle-based"
        // portion of the night, as the major calculation authorities recommend.
        let night = Self.hourDifference(sunset, sunrise + 24)
        let fajrLimit = method.fajrAngle / 60 * night
        if fajr.isNaN || Self.hourDifference(fajr, sunrise) > fajrLimit { fajr = sunrise - fajrLimit }
        if case let .angle(angle) = method.isha {
            let ishaLimit = angle / 60 * night
            if isha.isNaN || Self.hourDifference(sunset, isha) > ishaLimit { isha = sunset + ishaLimit }
        }
        if let angle = method.maghribAngle {
            let limit = angle / 60 * night
            if maghrib.isNaN || Self.hourDifference(sunset, maghrib) > limit { maghrib = sunset + limit }
        }

        // Hours from midnight UTC of this date (the astronomy works in local solar time).
        var utc = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: .gmt, year: year, month: month, day: dayOfMonth)
        utc.hour = 0
        guard let midnightUTC = utc.date else { return PrayerTimes(date: day, times: [:]) }
        func date(_ hours: Double) -> Date? {
            guard hours.isFinite else { return nil }
            let utcHours = hours - longitude / 15
            // Round to the minute, as timetables do.
            let seconds = (utcHours * 3600 / 60).rounded() * 60
            return midnightUTC.addingTimeInterval(seconds)
        }
        var result: [PrayerTimes.Prayer: Date] = [:]
        result[.fajr] = date(fajr)
        result[.sunrise] = date(sunrise)
        result[.dhuhr] = date(dhuhr)
        result[.asr] = date(asrTime)
        result[.maghrib] = date(maghrib)
        result[.isha] = date(isha)
        return PrayerTimes(date: day, times: result)
    }

    static func julian(year: Int, month: Int, day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = (y / 100).rounded(.down)
        let b = 2 - a + (a / 4).rounded(.down)
        return (365.25 * (y + 4716)).rounded(.down) + (30.6001 * (m + 1)).rounded(.down) + Double(day) + b - 1524.5
    }

    static func hourDifference(_ from: Double, _ to: Double) -> Double {
        var diff = (to - from).truncatingRemainder(dividingBy: 24)
        if diff < 0 { diff += 24 }
        return diff
    }
}

/// The Kaaba's direction from any place on Earth (great-circle bearing, degrees from true north).
public enum Qibla {
    public static let kaabaLatitude = 21.4225
    public static let kaabaLongitude = 39.8262

    public static func bearing(latitude: Double, longitude: Double) -> Double {
        let phi = latitude * .pi / 180
        let phiK = kaabaLatitude * .pi / 180
        let deltaLambda = (kaabaLongitude - longitude) * .pi / 180
        let y = sin(deltaLambda)
        let x = cos(phi) * tan(phiK) - sin(phi) * cos(deltaLambda)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Great-circle distance to the Kaaba in kilometres.
    public static func distance(latitude: Double, longitude: Double) -> Double {
        let r = 6371.0
        let phi1 = latitude * .pi / 180, phi2 = kaabaLatitude * .pi / 180
        let dPhi = phi2 - phi1, dLambda = (kaabaLongitude - longitude) * .pi / 180
        let a = sin(dPhi / 2) * sin(dPhi / 2) + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Low-precision solar position (USNO), in local solar hours.
private struct Astronomy {
    let jDate: Double
    let latitude: Double

    private static func dsin(_ d: Double) -> Double { sin(d * .pi / 180) }
    private static func dcos(_ d: Double) -> Double { cos(d * .pi / 180) }
    private static func dtan(_ d: Double) -> Double { tan(d * .pi / 180) }
    private static func darcsin(_ x: Double) -> Double { asin(x) * 180 / .pi }
    private static func darccos(_ x: Double) -> Double { acos(x) * 180 / .pi }
    private static func darctan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    private static func darccot(_ x: Double) -> Double { atan(1 / x) * 180 / .pi }
    private static func fix(_ a: Double, _ b: Double) -> Double {
        let r = a - b * (a / b).rounded(.down)
        return r < 0 ? r + b : r
    }

    /// Declination of the sun and the equation of time, `hours` into the day.
    private func sunPosition(_ hours: Double) -> (declination: Double, equation: Double) {
        let d = jDate + hours / 24 - 2451545.0
        let g = Self.fix(357.529 + 0.98560028 * d, 360)
        let q = Self.fix(280.459 + 0.98564736 * d, 360)
        let l = Self.fix(q + 1.915 * Self.dsin(g) + 0.020 * Self.dsin(2 * g), 360)
        let e = 23.439 - 0.00000036 * d
        let ra = Self.fix(Self.darctan2(Self.dcos(e) * Self.dsin(l), Self.dcos(l)) / 15, 24)
        let eqt = q / 15 - ra
        let decl = Self.darcsin(Self.dsin(e) * Self.dsin(l))
        return (decl, eqt)
    }

    func midDay(at hours: Double) -> Double {
        Self.fix(12 - sunPosition(hours).equation, 24)
    }

    /// When the sun is `angle` degrees below the horizon — before noon if `counterClockwise`.
    func sunAngleTime(_ angle: Double, at hours: Double, counterClockwise: Bool = false) -> Double {
        let decl = sunPosition(hours).declination
        let noon = midDay(at: hours)
        let cosine = (-Self.dsin(angle) - Self.dsin(decl) * Self.dsin(latitude)) / (Self.dcos(decl) * Self.dcos(latitude))
        guard (-1...1).contains(cosine) else { return .nan }
        let t = Self.darccos(cosine) / 15
        return noon + (counterClockwise ? -t : t)
    }

    func asrTime(factor: Double, at hours: Double) -> Double {
        let decl = sunPosition(hours).declination
        let angle = -Self.darccot(factor + Self.dtan(abs(latitude - decl)))
        return sunAngleTime(angle, at: hours)
    }
}
