import Foundation
import PLFaith
import PLProtection
import PLScripture
import UserNotifications

/// Local notifications only — the app has no push server.
///
/// Used for the shield → app hand-off: when "Begin" is tapped on a shield, the Shield
/// Action extension posts a local notification the user can tap to open the moment
/// (the only official route before iOS 26.5's `openParentalControlsApp`, and a
/// fallback after it).
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var onOpenShieldMoment: (() -> Void)?
    /// A daily-verse notification was tapped: open the reader at its chapter.
    var onOpenDailyVerse: ((ScriptureLocation) -> Void)?
    private let center = UNUserNotificationCenter.current()

    func activate() {
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Removes the hand-off notification once the app is open (it has done its job).
    func clearShieldNotifications() {
        center.removeDeliveredNotifications(withIdentifiers: [ShieldNotification.identifier])
    }

    // MARK: - Daily verse

    /// One notification for the daily verse. Its text is that day's verse, so each day is
    /// scheduled separately.
    struct DailyVerseNotification: Sendable {
        var day: CivilDateKey
        var fireDate: DateComponents
        var title: String
        var subtitle: String
        var body: String
        var location: ScriptureLocation
    }

    /// `yyyy-mm-dd`, used in identifiers.
    typealias CivilDateKey = String

    nonisolated static let dailyVersePrefix = "beloved.daily-verse."
    nonisolated private static let dailyVerseRoute = "dailyVerse"

    /// Replaces every scheduled daily-verse notification with `notifications`.
    func scheduleDailyVerses(_ notifications: [DailyVerseNotification]) async {
        await removeDailyVerses()
        for item in notifications {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.subtitle = item.subtitle
            content.body = item.body
            content.sound = nil
            content.threadIdentifier = "daily-verse"
            content.userInfo = [
                ShieldNotification.routeKey: Self.dailyVerseRoute,
                "work": item.location.work.rawValue,
                "book": item.location.book,
                "chapter": item.location.chapter,
            ]
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.fireDate, repeats: false)
            let request = UNNotificationRequest(identifier: Self.dailyVersePrefix + item.day, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func removeDailyVerses() async {
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.dailyVersePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
    }

    // MARK: - Delegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let route = info[ShieldNotification.routeKey] as? String
        if route == Self.dailyVerseRoute,
           let work = info["work"] as? String, let book = info["book"] as? String, let chapter = info["chapter"] as? Int {
            let location = ScriptureLocation(work: SourceWorkID(work), book: book, chapter: chapter)
            await MainActor.run { self.onOpenDailyVerse?(location) }
            return
        }
        guard route == ShieldNotification.route else { return }
        await MainActor.run { self.onOpenShieldMoment?() }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // In the foreground the moment opens directly; don't also show a banner.
        let route = notification.request.content.userInfo[ShieldNotification.routeKey] as? String
        return route == ShieldNotification.route ? [] : [.banner, .list, .sound]
    }
}
