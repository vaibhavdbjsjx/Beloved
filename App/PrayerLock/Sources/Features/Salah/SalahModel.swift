import CoreLocation
import Foundation
import Observation
import PLCalendar
import os

/// Prayer times, Qibla and prayer reminders for Muslims. Everything is calculated on this
/// iPhone; the location is kept here (rounded to about a kilometre) and never sent anywhere.
@MainActor
@Observable
final class SalahModel: NSObject {
    struct Place: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        var name: String?
    }

    struct Settings: Codable, Equatable {
        var place: Place?
        var method: PrayerCalculationMethod
        var asr: AsrSchool
        var remindersOn: Bool = false

        static var suggested: Settings {
            let region = Locale.current.region?.identifier
            return Settings(place: nil, method: .suggested(forRegion: region), asr: .suggested(forRegion: region))
        }
    }

    enum LocationState: Equatable { case idle, locating, denied, failed }

    private(set) var settings: Settings
    private(set) var locationState: LocationState = .idle
    /// Live compass heading (degrees from true north), while the Qibla compass is open.
    private(set) var heading: Double?
    private(set) var headingAccuracy: Double?

    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private let log = Logger(subsystem: "com.vaibhavsg.beloved", category: "salah")
    private static let key = "pl.salah.settings"

    init(notifications: NotificationService, defaults: UserDefaults = .standard) {
        self.notifications = notifications
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            settings = saved
        } else {
            settings = .suggested
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: - Times

    func times(on date: Date = .now, calendar: Calendar = .current) -> PrayerTimes? {
        guard let place = settings.place else { return nil }
        return PrayerTimeCalculator(method: settings.method, asr: settings.asr).times(
            latitude: place.latitude, longitude: place.longitude,
            on: calendar.dateComponents([.year, .month, .day], from: date), calendar: calendar
        )
    }

    /// The next prayer from `now`, looking into tomorrow after Isha.
    func nextPrayer(after now: Date = .now, calendar: Calendar = .current) -> (prayer: PrayerTimes.Prayer, time: Date)? {
        if let next = times(on: now, calendar: calendar)?.next(after: now) { return next }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        return times(on: tomorrow, calendar: calendar)?.next(after: now)
    }

    var qiblaBearing: Double? {
        settings.place.map { Qibla.bearing(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var qiblaDistance: Double? {
        settings.place.map { Qibla.distance(latitude: $0.latitude, longitude: $0.longitude) }
    }

    // MARK: - Settings

    /// Forgets the place and choices ("Delete all data").
    func reset() async {
        defaults.removeObject(forKey: Self.key)
        settings = .suggested
        await notifications.removePrayerTimes()
    }

    func setMethod(_ method: PrayerCalculationMethod) { update { $0.method = method } }
    func setAsr(_ asr: AsrSchool) { update { $0.asr = asr } }

    func setReminders(_ on: Bool) async -> Bool {
        if on {
            let status = await notifications.authorizationStatus()
            let allowed = status == .notDetermined ? await notifications.requestAuthorization() : (status == .authorized || status == .provisional)
            guard allowed else { return false }
        }
        update { $0.remindersOn = on }
        return true
    }

    private func update(_ change: (inout Settings) -> Void) {
        change(&settings)
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.key) }
        Task { await refreshReminders() }
    }

    /// Schedules the next five days of prayer reminders (25 of iOS's 64 pending slots).
    func refreshReminders() async {
        guard settings.remindersOn, settings.place != nil else {
            await notifications.removePrayerTimes()
            return
        }
        let calendar = Calendar.current
        var reminders: [(id: String, date: Date, title: String, body: String)] = []
        for offset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now), let times = times(on: day, calendar: calendar) else { continue }
            let key = day.formatted(.iso8601.year().month().day())
            for prayer in PrayerTimes.Prayer.allCases where prayer.isPrayer {
                guard let time = times.time(prayer) else { continue }
                reminders.append((
                    id: "\(key).\(prayer.rawValue)",
                    date: time,
                    title: String(localized: "Time for \(prayer.displayName)"),
                    body: String(localized: "Take a moment to pray. Your apps can wait.")
                ))
            }
        }
        await notifications.schedulePrayerTimes(reminders)
    }

    // MARK: - Location

    /// Asks for "while using" location once, then remembers the place (rounded).
    func locate() async {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            locationState = .denied
            return
        default: break
        }
        locationState = .locating
        let location = await withCheckedContinuation { continuation in
            locationContinuation?.resume(returning: nil)
            locationContinuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
        guard let location else {
            locationState = manager.authorizationStatus == .denied ? .denied : .failed
            return
        }
        let rounded = Place(
            latitude: (location.coordinate.latitude * 100).rounded() / 100,
            longitude: (location.coordinate.longitude * 100).rounded() / 100
        )
        // Times are ready as soon as we have coordinates; the city name follows if it comes.
        locationState = .idle
        update { $0.place = rounded }
        if let name = await Self.placeName(for: location) {
            update { $0.place?.name = name }
        }
    }

    /// The town's name, or `nil` if the lookup is slow or offline (it is only a label).
    private static func placeName(for location: CLLocation) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
                return placemark?.locality ?? placemark?.administrativeArea ?? placemark?.country
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.headingFilter = 1
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        manager.stopUpdatingHeading()
        heading = nil
    }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }
}

extension SalahModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.locationContinuation != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted:
                self.locationContinuation?.resume(returning: nil)
                self.locationContinuation = nil
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.log.error("Location failed: \(error.localizedDescription, privacy: .public)")
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        Task { @MainActor in
            self.heading = value
            self.headingAccuracy = accuracy
        }
    }
}

extension PrayerTimes.Prayer {
    var displayName: String {
        switch self {
        case .fajr: String(localized: "Fajr")
        case .sunrise: String(localized: "Sunrise")
        case .dhuhr: String(localized: "Dhuhr")
        case .asr: String(localized: "Asr")
        case .maghrib: String(localized: "Maghrib")
        case .isha: String(localized: "Isha")
        }
    }

    var symbol: String {
        switch self {
        case .fajr: "sun.horizon"
        case .sunrise: "sunrise"
        case .dhuhr: "sun.max"
        case .asr: "sun.min"
        case .maghrib: "sunset"
        case .isha: "moon.stars"
        }
    }
}
