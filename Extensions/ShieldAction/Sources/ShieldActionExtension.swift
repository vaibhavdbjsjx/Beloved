import Foundation
@preconcurrency import ManagedSettings
import PLCore
import PLProtection
import UserNotifications
import os

/// Handles the shield's buttons.
///
/// "Begin": records a `ShieldRequest` in the App Group, then hands off to the app:
/// - iOS 26.5+: `.openParentalControlsApp` asks the system to open the app directly.
///   Whether this works under `.individual` (self-control) authorization is NOT yet
///   verified on device — so a local notification is always posted too, and the app
///   removes it once open. Set `PLUseOpenParentAppResponse` to NO in Info.plist to
///   disable the direct open if device testing shows a problem.
/// - Earlier iOS: `.defer` (the shield redraws with "open the app to begin") plus the
///   notification, which the user taps to reach the moment.
///
/// "Not now": `.close` closes the protected app.
final class ShieldActionExtension: ShieldActionDelegate {
    private let state = ProtectionStateStore.shared(appGroupIdentifier: AppConfiguration.fromBundle().appGroupIdentifier)
    private let log = Log.logger(.shieldAction)

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, subject: .application, tokenData: try? JSONEncoder().encode(application), completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, subject: .webDomain, tokenData: try? JSONEncoder().encode(webDomain), completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, subject: .category, tokenData: try? JSONEncoder().encode(category), completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        subject: ShieldRequest.Subject,
        tokenData: Data?,
        _ completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let handOff = ShieldHandOff.decide(
            primaryButton: action == .primaryButtonPressed,
            supportsDirectOpen: Self.supportsDirectOpen,
            directOpenEnabled: Bundle.main.object(forInfoDictionaryKey: "PLUseOpenParentAppResponse") as? Bool ?? false
        )
        guard handOff.startsMoment else {
            state.events.record(.shieldNotNowTapped, detail: subject.rawValue)
            completionHandler(.close)
            return
        }
        state.recordRequest(ShieldRequest(createdAt: Date(), subject: subject, tokenData: tokenData))

        let response = Self.response(for: handOff)
        state.events.record(.shieldBeginTapped, detail: "\(subject.rawValue) → \(handOff == .openApp ? "open app + notification" : "defer + notification")")
        let finish = UncheckedSendableBox { completionHandler(response) }
        postHandOffNotification {
            finish.value()
        }
    }

    private static var supportsDirectOpen: Bool {
        if #available(iOS 26.5, *) { return true }
        return false
    }

    private static func response(for handOff: ShieldHandOff) -> ShieldActionResponse {
        switch handOff {
        case .close: return .close
        case .deferWithNotification: return .defer
        case .openApp:
            if #available(iOS 26.5, *) { return .openParentalControlsApp }
            return .defer
        }
    }

    private func postHandOffNotification(then done: @escaping @Sendable () -> Void) {
        let copy = state.shieldCopy() ?? .englishFallback
        let content = UNMutableNotificationContent()
        content.title = copy.notificationTitle
        content.body = copy.notificationBody
        content.userInfo = [ShieldNotification.routeKey: ShieldNotification.route]
        let request = UNNotificationRequest(identifier: ShieldNotification.identifier, content: content, trigger: nil)
        let log = self.log
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                log.error("Hand-off notification failed: \(error.localizedDescription, privacy: .public)")
            }
            done()
        }
    }
}

/// Carries the non-Sendable completion handler across the notification callback.
/// Safe here: it is invoked exactly once, and ShieldActionDelegate allows any thread.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
