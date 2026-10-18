import Foundation
@testable import PLCalendar
import Testing

/// Reference timetables for 18 October 2026 from the AlAdhan API (same published method).
@Suite struct PrayerTimesTests {
    struct Case: Sendable, CustomStringConvertible {
        let place: String
        let latitude: Double, longitude: Double
        let zone: String
        let method: PrayerCalculationMethod
        let asr: AsrSchool
        let expected: [String] // fajr, sunrise, dhuhr, asr, maghrib, isha
        var description: String { place }
    }

    static let cases: [Case] = [
        Case(place: "London", latitude: 51.5074, longitude: -0.1278, zone: "Europe/London", method: .muslimWorldLeague, asr: .standard,
             expected: ["05:38", "07:29", "12:46", "15:30", "18:01", "19:46"]),
        Case(place: "New York", latitude: 40.7128, longitude: -74.0060, zone: "America/New_York", method: .northAmerica, asr: .standard,
             expected: ["05:55", "07:11", "12:41", "15:45", "18:11", "19:26"]),
        Case(place: "Bengaluru", latitude: 12.9716, longitude: 77.5946, zone: "Asia/Kolkata", method: .karachi, asr: .hanafi,
             expected: ["04:59", "06:10", "12:05", "16:22", "17:59", "19:10"]),
        Case(place: "Makkah", latitude: 21.4225, longitude: 39.8262, zone: "Asia/Riyadh", method: .ummAlQura, asr: .standard,
             expected: ["05:01", "06:17", "12:06", "15:27", "17:54", "19:24"]),
    ]

    @Test(arguments: cases)
    func matchesPublishedTimetables(_ c: Case) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: c.zone))
        let times = PrayerTimeCalculator(method: c.method, asr: c.asr)
            .times(latitude: c.latitude, longitude: c.longitude, on: DateComponents(year: 2026, month: 10, day: 18), calendar: calendar)
        let order: [PrayerTimes.Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        for (prayer, expected) in zip(order, c.expected) {
            let date = try #require(times.time(prayer), "\(prayer) missing")
            let parts = expected.split(separator: ":").compactMap { Int($0) }
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            let got = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            #expect(abs(got - (parts[0] * 60 + parts[1])) <= 2, "\(c.place) \(prayer): \(comps.hour!):\(comps.minute!) vs \(expected)")
        }
    }

    @Test func highLatitudeSummerStillHasFajrAndIsha() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))
        let times = PrayerTimeCalculator(method: .muslimWorldLeague, asr: .standard)
            .times(latitude: 59.91, longitude: 10.75, on: DateComponents(year: 2026, month: 6, day: 21), calendar: calendar)
        let fajr = try #require(times.time(.fajr)), sunrise = try #require(times.time(.sunrise))
        let maghrib = try #require(times.time(.maghrib)), isha = try #require(times.time(.isha))
        #expect(fajr < sunrise)
        #expect(maghrib < isha)
    }

    @Test func nextAndCurrentPrayer() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let times = PrayerTimeCalculator(method: .muslimWorldLeague, asr: .standard)
            .times(latitude: 51.5074, longitude: -0.1278, on: DateComponents(year: 2026, month: 10, day: 18), calendar: calendar)
        let afterDhuhr = try #require(times.time(.dhuhr)).addingTimeInterval(60)
        #expect(times.current(at: afterDhuhr) == .dhuhr)
        #expect(times.next(after: afterDhuhr)?.prayer == .asr)
        let afterSunrise = try #require(times.time(.sunrise)).addingTimeInterval(60)
        #expect(times.current(at: afterSunrise) == nil)
    }

    @Test(arguments: [
        ("London", 51.5074, -0.1278, 119.0),
        ("New York", 40.7128, -74.0060, 58.5),
        ("Bengaluru", 12.9716, 77.5946, 289.0),
        ("Jakarta", -6.2088, 106.8456, 295.1),
    ])
    func qiblaBearing(place: String, latitude: Double, longitude: Double, expected: Double) {
        #expect(abs(Qibla.bearing(latitude: latitude, longitude: longitude) - expected) < 1.0, "\(place)")
    }
}
