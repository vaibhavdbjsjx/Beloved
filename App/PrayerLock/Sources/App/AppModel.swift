@preconcurrency import FamilyControls
import Foundation
import Observation
import PLBrand
import PLCalendar
import PLContent
import PLCore
import PLFaith
import PLHabits
import PLMonetization
import PLProtection
import PLScripture
import UIKit
import os

enum AppTab: Hashable {
    case today
    /// Prayer tools and libraries: mala/tasbih/rosary, prayer times, deities, needs, holy days.
    case pray
    /// The faith's own scripture — named "Bible", "Quran" or "Gita" in the tab bar.
    case scripture
    case companion
    case protection
    case settings
}

/// A screen in the scripture tab's navigation stack.
enum ScriptureRoute: Hashable {
    case book(String)
    case chapter(ScriptureLocation, highlight: PassageReference?)
    case about
}

/// A request to present the prayer moment.
struct MomentRequest: Identifiable, Equatable {
    let id = UUID()
    let trigger: PrayerSession.Trigger
    /// Present when the user came from a shield ("Begin" tapped on a protected app).
    let shieldRequest: ShieldRequest?
}

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// What happened when a moment was completed.
struct MomentOutcome: Equatable {
    /// `nil` when protection wasn't active (nothing needed unlocking).
    var unlockedUntil: Date?
    var usageLimit: TimeInterval?
    var unlockError: String?
}

/// Root UI state. Thin by design: business rules live in PrayerLockKit; this type
/// coordinates them and persists user choices.
@MainActor
@Observable
final class AppModel {
    let env: AppEnvironment

    private(set) var stored: StoredProfile
    private(set) var todayMood: Mood?
    var selectedTab: AppTab = .today
    var activeMoment: MomentRequest?
    var alert: AppAlert?
    private(set) var subscriptionState: SubscriptionState = .unknown
    private(set) var habitSummary: HabitSummary?
    private(set) var recentSessions: [PrayerSession] = []
    private(set) var protectionStatus: ProtectionStatus = .needsAuthorization
    private(set) var protectionSettings: ProtectionSettings = .default
    /// The faith's colour theme (lapis for Christians and by default, emerald for Muslims,
    /// saffron for Hindus). Changing it rebuilds the main interface in the new colours.
    private(set) var theme: PLTheme = .lapis
    /// Today's verse from the user's scripture, when this build may show one.
    private(set) var dailyVerse: DailyVerse?
    /// The scripture tab's navigation path (lets Today and notifications open a chapter).
    var scripturePath: [ScriptureRoute] = []
    /// Prayer times, Qibla and prayer reminders (shown to Muslims).
    let salah: SalahModel
    /// Prayer requests and answered prayers (on this iPhone only).
    let journal: PrayerJournal
    /// Bible / Quran / Gita reading plans.
    let plans: ReadingPlanStore
    /// Why the paywall is showing (set by a Premium feature the user tried), or `nil`.
    var paywallReason: String?
    /// A question to put to the companion when its tab opens (festival guides, "Ask about this").
    var pendingCompanionQuestion: String?

    // MARK: - Account State
    private(set) var currentUser: AuthUser?
    private(set) var isAuthenticating: Bool = false
    var authSheetPresented: Bool = false

    private let log = Log.logger(.app)
    /// Keeps the iOS 26.5+ token-expiry observation alive.
    @ObservationIgnored private var tokenExpiryObservation: Any?

    init(env: AppEnvironment) {
        self.env = env
        salah = SalahModel(notifications: env.notifications, defaults: env.preferences)
        journal = PrayerJournal(url: env.journalURL)
        plans = ReadingPlanStore(defaults: env.preferences)
        stored = env.profileStore.load()
        currentUser = env.sessionStore.loadSession()?.user
        applyTheme()
        if let checkIn = stored.checkIn, checkIn.date == CivilDate(.now, calendar: env.calendar) {
            todayMood = checkIn.mood
        }
        env.notifications.onOpenShieldMoment = { [weak self] in
            self?.presentShieldMoment(fromNotification: true)
        }
        env.notifications.onOpenDailyVerse = { [weak self] location in
            guard let self, self.isOnboarded, self.activeMoment == nil else { return }
            self.openScripture(location, highlight: self.dailyVerse?.location == location ? self.dailyVerse?.reference : nil)
        }
        refreshProtectionStatus()
        if #available(iOS 26.5, *) {
            tokenExpiryObservation = ScreenTimePlatform.observeTokenExpiry { [weak self] in
                await self?.handleTokenExpiry()
            }
        }
    }

    var profile: SpiritualProfile { stored.profile }
    var isOnboarded: Bool { stored.onboardingCompleted }
    var accessLevel: AccessLevel { EntitlementResolver.accessLevel(for: subscriptionState, now: .now) }

    /// Premium features are open with a subscription, when this build has no paywall, or under
    /// UI tests that ask for it (`-PLUnlockPremium`, development builds only).
    var hasPremiumAccess: Bool {
        accessLevel == .premium || !env.monetization.isPaywallEnabled
            || (env.configuration.isDevelopment && ProcessInfo.processInfo.arguments.contains("-PLUnlockPremium"))
    }

    /// Runs `action` when Premium is open; otherwise shows the paywall, saying why.
    func withPremium(_ reason: String, _ action: () -> Void) {
        if hasPremiumAccess { action() } else { paywallReason = reason }
    }

    /// Long stotras are Premium; mantras, short prayers and duas are always free.
    func isPremiumOnly(_ item: ContentItem) -> Bool { item.length == .extended }
    var today: CivilDate { CivilDate(.now, calendar: env.calendar) }
    var faith: Faith? { profile.faithID.flatMap(env.registry.faith) }

    // MARK: - Profile

    func completeOnboarding(with profile: SpiritualProfile) {
        stored.profile = profile
        stored.onboardingCompleted = true
        stored.onboardingProgress = nil
        persist()
        refreshShieldCopy()
        scriptureChanged()
    }

    /// Development builds under UI testing only: `-PLPreviewFaith <faith> [-PLPreviewTradition <id>]`.
    func applyPreviewProfileIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard env.configuration.isDevelopment, arguments.contains(LaunchArgument.uiTesting),
              let index = arguments.firstIndex(of: LaunchArgument.previewFaith), arguments.indices.contains(index + 1) else { return }
        let faith = FaithID(arguments[index + 1])
        let tradition = arguments.firstIndex(of: "-PLPreviewTradition").flatMap { arguments.indices.contains($0 + 1) ? TraditionID(arguments[$0 + 1]) : nil }
        completeOnboarding(with: SpiritualProfile(faithID: faith, traditionID: tradition, displayName: "Vaibhav"))
    }

    /// Saves unfinished onboarding answers (private container) without completing it.
    func saveOnboardingProgress(_ profile: SpiritualProfile, progress: OnboardingProgress) {
        guard !stored.onboardingCompleted else { return }
        stored.profile = profile
        stored.onboardingProgress = progress
        persist()
    }

    func updateIntentions(_ intentions: [String]) {
        updateProfile { $0.intentions = SpiritualProfile.normalizedIntentions(intentions) }
    }

    /// The most recent completed moment, if any (loaded by `refreshHabits`).
    var lastMomentDate: Date? { recentSessions.first?.endedAt }

    /// True when the user has paused before but not for a week or more — Today then
    /// welcomes them back without any catching up to do.
    var isReturningAfterBreak: Bool {
        ReturnGreeting.isReturningAfterBreak(lastMoment: lastMomentDate, now: .now)
    }

    func updateProfile(_ transform: (inout SpiritualProfile) -> Void) {
        let previousFaith = stored.profile.faithID
        transform(&stored.profile)
        persist()
        refreshShieldCopy()
        if stored.profile.faithID != previousFaith { scriptureChanged() }
    }

    /// Onboarding stays in the brand colours; the faith's theme starts in the main app.
    private func applyTheme() {
        let theme = stored.onboardingCompleted ? Self.theme(for: profile.faithID) : .lapis
        PLTheme.current = theme
        self.theme = theme
    }

    static func theme(for faith: FaithID?) -> PLTheme {
        switch faith?.rawValue {
        case "islam": .emerald
        case "hinduism": .saffron
        default: .lapis
        }
    }

    /// A different faith means a different scripture (or none) and colours: reset the reader
    /// and verse, and re-theme.
    private func scriptureChanged() {
        applyTheme()
        scripturePath = []
        if selectedTab == .scripture, readableWork == nil { selectedTab = .today }
        Task {
            await refreshDailyVerse()
            await rescheduleDailyVerses()
        }
    }

    // MARK: - Scripture

    /// The user's scripture as this build may show it, or `nil` (no faith chosen, a faith
    /// without a bundled scripture, or nothing approved yet in a release build).
    var readableWork: ReadableWork? {
        profile.faithID.flatMap {
            env.scripturePolicy.readableWork(for: $0, manifest: env.scripture.manifest, registry: env.registry)
        }
    }

    func readingLocation(for work: SourceWorkID) -> ScriptureLocation? { stored.reading.positions[work] }

    func saveReadingLocation(_ location: ScriptureLocation) {
        guard stored.reading.positions[location.work] != location else { return }
        stored.reading.positions[location.work] = location
        persist()
    }

    func preferredLayout(for work: SourceWorkID) -> ReadingLayout? { stored.reading.layouts[work] }

    func setPreferredLayout(_ layout: ReadingLayout, for work: SourceWorkID) {
        guard stored.reading.layouts[work] != layout else { return }
        stored.reading.layouts[work] = layout
        persist()
    }

    /// Opens a chapter in the scripture tab (from Today's verse or a notification).
    func openScripture(_ location: ScriptureLocation, highlight: PassageReference? = nil) {
        guard readableWork?.work.id == location.work else { return }
        selectedTab = .scripture
        scripturePath = [.chapter(location, highlight: highlight)]
    }

    func refreshDailyVerse() async {
        guard let faith = profile.faithID else {
            dailyVerse = nil
            return
        }
        do {
            dailyVerse = try await env.scripture.dailyVerse(for: faith, on: today, policy: env.scripturePolicy, registry: env.registry)
        } catch {
            log.error("Daily verse unavailable: \(String(describing: error), privacy: .public)")
            dailyVerse = nil
        }
    }

    var dailyVerseReminder: DailyVerseReminder { stored.dailyVerseReminder }

    /// Whether the user's scripture has a daily verse in this build (the setting is hidden otherwise).
    var offersDailyVerse: Bool {
        guard let faith = profile.faithID, let list = env.scripture.daily.faiths[faith] else { return false }
        return readableWork != nil && env.scripturePolicy.permits(list)
    }

    /// Turns the daily-verse notification on or off (asking iOS for permission when needed).
    func setDailyVerseReminder(_ reminder: DailyVerseReminder) async {
        var reminder = reminder
        if reminder.isEnabled, !stored.dailyVerseReminder.isEnabled {
            let status = await env.notifications.authorizationStatus()
            let allowed: Bool
            switch status {
            case .notDetermined: allowed = await env.notifications.requestAuthorization()
            case .denied: allowed = false
            default: allowed = true
            }
            if !allowed {
                reminder.isEnabled = false
                alert = AppAlert(
                    title: String(localized: "Notifications are off"),
                    message: String(localized: "To receive a daily verse, allow notifications for \(AppBrand.displayName) in the Settings app.")
                )
            }
        }
        stored.dailyVerseReminder = reminder
        persist()
        await rescheduleDailyVerses()
    }

    /// Schedules the next two weeks of daily verses (each with its own day's passage), or
    /// clears them when the reminder is off or no verse may be shown.
    func rescheduleDailyVerses() async {
        let reminder = stored.dailyVerseReminder
        guard reminder.isEnabled, offersDailyVerse, let faith = profile.faithID,
              let readable = readableWork else {
            await env.notifications.removeDailyVerses()
            return
        }
        let scheme = env.registry.source(readable.work.id)?.referenceScheme ?? .freeform
        var items: [NotificationService.DailyVerseNotification] = []
        for day in reminder.upcomingDays(from: .now, calendar: env.calendar) {
            guard let verse = try? await env.scripture.dailyVerse(for: faith, on: day, policy: env.scripturePolicy, registry: env.registry),
                  let body = verse.translationText ?? verse.originalText else { continue }
            items.append(.init(
                day: day.description,
                fireDate: reminder.fireComponents(for: day),
                title: String(localized: "Verse for today"),
                subtitle: ScriptureReferenceFormatter.format(verse.reference, in: readable.work, scheme: scheme, languages: profile.languages),
                body: body.replacingOccurrences(of: "\n", with: " "),
                location: verse.location
            ))
        }
        await env.notifications.scheduleDailyVerses(items)
    }

    func checkIn(_ mood: Mood?) {
        todayMood = mood
        stored.checkIn = mood.map { CheckIn(date: today, mood: $0) }
        persist()
    }

    private func persist() {
        var copy = stored
        if !copy.profile.rememberCheckIns { copy.checkIn = nil }
        env.profileStore.save(copy)
    }

    // MARK: - Content

    func todaysObservances() -> [Observance] {
        env.religiousCalendar.observances(on: today, faith: profile.faithID, tradition: profile.traditionID)
    }

    func todaysAssociations() -> [DevotionalAssociation] {
        env.devotionalAssociations.associations(on: today, profile: profile)
    }

    /// The deity chosen for today, if the user chose one today.
    var todaysFocus: FocusID? {
        guard let daily = stored.dailyFocus, daily.date == today else { return nil }
        return daily.focus
    }

    /// Deities offered for "Who will you pray to today?" — the faith's focuses, the user's own
    /// first.
    var dailyFocusChoices: [SpiritualFocus] {
        guard let faith, faith.usesSpiritualFocus else { return [] }
        let mine = Set(profile.focusIDs)
        return faith.focuses.filter { mine.contains($0.id) } + faith.focuses.filter { !mine.contains($0.id) }
    }

    func chooseFocusForToday(_ focus: FocusID?) {
        stored.dailyFocus = focus.map { DailyFocus(date: today, focus: $0) }
        persist()
    }

    /// The library's verified prayers for today's deity (mantras first).
    func itemsForTodaysFocus() -> [ContentItem] {
        guard let focus = todaysFocus else { return [] }
        return items(forFocus: focus)
    }

    /// The library's verified prayers for a deity (mantras first, long stotras last).
    func items(forFocus focus: FocusID) -> [ContentItem] {
        env.catalog.visibleItems(policy: env.contentPolicy, registry: env.registry)
            .filter { $0.focuses.contains(focus) }
            .sorted { ($0.kind == .mantra ? 0 : 1, $0.length == .extended ? 1 : 0) < ($1.kind == .mantra ? 0 : 1, $1.length == .extended ? 1 : 0) }
    }

    /// Every prayer this build may show for the user's faith (or faith-neutral ones).
    var faithItems: [ContentItem] {
        env.catalog.visibleItems(policy: env.contentPolicy, registry: env.registry)
            .filter { $0.faith == profile.faithID && $0.segments.contains { $0.role != .explanation } }
            .filter { item in item.traditions.isEmpty || profile.traditionID.map(item.traditions.contains) ?? false
                || (profile.traditionID == nil && item.traditions.contains("christianity.catholic")) }
    }

    func selectContent() -> ScoredContent? {
        env.selector.select(SelectionContext(
            profile: profile,
            mood: todayMood,
            date: .now,
            calendar: env.calendar,
            activeOccasions: Set(todaysObservances().map(\.occasionID)),
            devotionalFocuses: Set(todaysAssociations().compactMap(\.focus)).union([todaysFocus].compactMap { $0 }),
            recentlyShown: stored.recentlyShown,
            hasPremium: accessLevel == .premium
        ))
    }

    func markShown(_ id: ContentItemID) {
        stored.recentlyShown = Array(([id] + stored.recentlyShown.filter { $0 != id }).prefix(10))
        persist()
    }

    func editionTitle(for segment: ContentSegment) -> String? {
        segment.citation?.edition.flatMap(env.registry.edition)?.title.resolved(for: profile.languages)
    }

    func themeName(_ id: ThemeID) -> String {
        env.catalog.taxonomy.theme(id)?.name.resolved(for: profile.languages) ?? id.rawValue
    }

    // MARK: - Moments

    func startMoment() {
        guard activeMoment == nil else { return }
        activeMoment = MomentRequest(trigger: .manual, shieldRequest: nil)
    }

    /// Opens the moment for a shield hand-off (notification tap, or the app opened by
    /// `openParentalControlsApp` on iOS 26.5+).
    func presentShieldMoment(fromNotification: Bool) {
        guard isOnboarded, activeMoment == nil else { return }
        let request = env.protectionState.takeLatestRequest(at: .now)
        guard request != nil || fromNotification else { return }
        activeMoment = MomentRequest(trigger: .shield, shieldRequest: request)
    }

    /// Records a completed moment and, if protection is active, opens protected apps
    /// for the user's chosen duration.
    func completeMoment(_ request: MomentRequest, item: ContentItem?, startedAt: Date) async -> MomentOutcome {
        var outcome = MomentOutcome()
        let sessionID = UUID()

        refreshProtectionStatus()
        if protectionStatus == .active {
            do {
                let grant = try env.protection.grantUnlock(sessionID: sessionID, calendar: env.calendar)
                outcome.unlockedUntil = grant.expiresAt
                outcome.usageLimit = grant.usageLimit
            } catch ProtectionError.notAuthorized {
                outcome.unlockError = String(localized: "Your moment was saved. Screen Time access is off, so \(AppBrand.displayName) isn't controlling your apps right now.")
            } catch {
                log.error("Unlock failed: \(String(describing: error), privacy: .public)")
                outcome.unlockError = String(localized: "Your moment was saved, but your protected apps couldn't be opened. Please try again.")
            }
        }

        let session = PrayerSession(
            id: sessionID,
            startedAt: startedAt,
            endedAt: .now,
            trigger: request.trigger,
            outcome: .completed,
            contentItemID: item?.id,
            themes: item?.themes ?? [],
            mood: profile.rememberCheckIns ? todayMood : nil,
            grantedAccess: outcome.unlockedUntil != nil
        )
        do {
            try await env.sessions.append(session)
        } catch {
            log.error("Session not saved: \(String(describing: error), privacy: .public)")
        }
        if let item { markShown(item.id) }
        refreshProtectionStatus()
        await refreshHabits()
        return outcome
    }

    // MARK: - Protection

    func refreshProtectionStatus() {
        protectionStatus = env.protection.status()
        protectionSettings = env.protection.settings
    }

    func refreshShieldCopy() {
        env.protectionState.save(ShieldCopyFactory.make(for: profile))
    }

    func requestScreenTimeAuthorization() async {
        do {
            try await env.protection.requestAuthorization()
        } catch {
            alert = AppAlert(
                title: String(localized: "Screen Time access wasn't granted"),
                message: String(localized: "You can try again at any time. \(AppBrand.displayName) needs Screen Time access to place a pause in front of the apps you choose.")
            )
        }
        refreshProtectionStatus()
    }

    @discardableResult
    func updateSelection(_ selection: FamilyActivitySelection) -> [SelectionLimits.Issue] {
        let issues = env.protection.updateSelection(selection)
        refreshProtectionStatus()
        return issues
    }

    func setProtectionEnabled(_ enabled: Bool) {
        do {
            try env.protection.setEnabled(enabled)
        } catch {
            alert = AppAlert(
                title: String(localized: "Protection couldn't be turned on"),
                message: String(localized: "Allow Screen Time access and choose at least one app first.")
            )
        }
        refreshProtectionStatus()
    }

    func setUnlockDuration(_ duration: UnlockDuration) {
        env.protection.setUnlockDuration(duration)
        refreshProtectionStatus()
    }

    // MARK: - Lifecycle

    /// iOS 26.5+ reports expired Screen Time tokens; refresh them or ask for reselection.
    func handleTokenExpiry() {
        env.protection.refreshTokens()
        refreshProtectionStatus()
    }

    func handleBecameActive() async {
        env.protection.refreshTokens()
        env.protection.reconcile()
        refreshProtectionStatus()
        if isOnboarded { refreshShieldCopy() }
        env.notifications.clearShieldNotifications()
        if env.protectionState.hasPendingRequest(at: .now) {
            presentShieldMoment(fromNotification: false)
        }
        if let checkIn = stored.checkIn, checkIn.date != today {
            todayMood = nil
        }
        if let user = currentUser, user.provider == .apple {
            let state = await NativeAuthenticationService.checkAppleCredentialState(userID: user.id)
            if state == .revoked || state == .notFound {
                await signOut()
                alert = AppAlert(
                    title: String(localized: "Apple Sign-In"),
                    message: String(localized: "Your Apple authorization for Beloved was revoked in Settings. You have been signed out.")
                )
            }
        }
        await refreshHabits()
        await refreshDailyVerse()
        await rescheduleDailyVerses()
    }

    func refreshHabits() async {
        let sessions = (try? await env.sessions.allSessions()) ?? []
        habitSummary = HabitCalculator(calendar: env.calendar).summary(for: sessions, now: .now)
        recentSessions = Array(sessions.sorted { $0.endedAt > $1.endedAt }.prefix(20))
    }

    /// iOS reports Screen Time authorization asynchronously after launch, and the user
    /// can revoke it in Settings at any time — keep the UI in sync.
    func observeScreenTimeAuthorization() async {
        for await _ in AuthorizationCenter.shared.$authorizationStatus.values {
            refreshProtectionStatus()
        }
    }

    func observeSubscription() async {
        subscriptionState = await env.purchases.currentState()
        for await state in env.purchases.stateUpdates() {
            subscriptionState = state
        }
    }

    func restorePurchases() async {
        do {
            try await env.purchases.restorePurchases()
            subscriptionState = await env.purchases.currentState()
            if accessLevel != .premium {
                alert = AppAlert(
                    title: String(localized: "No Active Subscription"),
                    message: String(localized: "No active Beloved Premium subscription was found for this Apple ID.")
                )
            }
        } catch {
            alert = AppAlert(
                title: String(localized: "Couldn't restore purchases"),
                message: String(localized: "Check your connection and try again.")
            )
        }
    }

    func purchase(_ product: StoreProduct) async -> PurchaseOutcome? {
        do {
            let outcome = try await env.purchases.purchase(productID: product.id)
            switch outcome {
            case let .purchased(state):
                subscriptionState = state
            case .pending:
                alert = AppAlert(
                    title: String(localized: "Purchase pending"),
                    message: String(localized: "The App Store is still processing this purchase. Premium will unlock automatically when it is approved.")
                )
            case .cancelled:
                break
            }
            return outcome
        } catch {
            alert = AppAlert(
                title: String(localized: "Purchase couldn't be completed"),
                message: String(localized: "Check your connection and try again. You were not charged by Beloved.")
            )
            return nil
        }
    }

    // MARK: - Authentication & Account Management

    func refreshUserSession() async {
        if let session = try? await env.authentication.restorePreviousSignIn() {
            currentUser = session.user
        } else {
            currentUser = nil
        }
    }

    func signInWithApple(presentingWindow: UIWindow? = nil) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            if let native = env.authentication as? NativeAuthenticationService {
                let session = try await native.performAppleSignIn(presentingWindow: presentingWindow)
                currentUser = session.user
                authSheetPresented = false
            }
        } catch let error as AuthError {
            if error == .cancelled { return }
            alert = AppAlert(
                title: String(localized: "Apple Sign-In"),
                message: error.errorDescription ?? String(localized: "Sign in with Apple could not be completed.")
            )
        } catch {
            alert = AppAlert(
                title: String(localized: "Apple Sign-In"),
                message: error.localizedDescription
            )
        }
    }

    func signInWithGoogle(presentingWindow: UIWindow? = nil) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            if let native = env.authentication as? NativeAuthenticationService {
                let session = try await native.performGoogleSignIn(presentingWindow: presentingWindow)
                currentUser = session.user
                authSheetPresented = false
            }
        } catch let error as AuthError {
            if error == .cancelled { return }
            alert = AppAlert(
                title: String(localized: "Gmail Sign-In"),
                message: error.errorDescription ?? String(localized: "Sign in with Gmail could not be completed.")
            )
        } catch {
            alert = AppAlert(
                title: String(localized: "Gmail Sign-In"),
                message: error.localizedDescription
            )
        }
    }

    func signOut() async {
        do {
            try await env.authentication.signOut()
            currentUser = nil
        } catch {
            log.error("Sign out error: \(String(describing: error), privacy: .public)")
            currentUser = nil
        }
    }

    func deleteAccount() async -> Bool {
        do {
            if let user = currentUser, let filename = user.avatarLocalFilename {
                let url = avatarFileURL(for: filename)
                try? FileManager.default.removeItem(at: url)
            }

            try await env.authentication.deleteAccount(appleRevocationHandler: nil)
            currentUser = nil
            alert = AppAlert(
                title: String(localized: "Account Deleted"),
                message: String(localized: "Your account credentials and profile have been permanently deleted from this device. Please note that active App Store subscriptions must be managed separately in your Apple ID settings.")
            )
            return true
        } catch {
            alert = AppAlert(
                title: String(localized: "Deletion Failed"),
                message: error.localizedDescription
            )
            return false
        }
    }

    func updateDisplayName(_ name: String) async {
        do {
            let updated = try await env.authentication.updateDisplayName(name)
            currentUser = updated
        } catch {
            alert = AppAlert(
                title: String(localized: "Could not update name"),
                message: error.localizedDescription
            )
        }
    }

    func updateProfileAvatar(imageData: Data) async {
        guard let user = currentUser else { return }
        let filename = "avatar_\(user.id).jpg"
        let url = avatarFileURL(for: filename)
        do {
            let folder = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try imageData.write(to: url, options: .completeFileProtection)
            let updated = try await env.authentication.updateAvatarLocalFilename(filename)
            currentUser = updated
        } catch {
            alert = AppAlert(
                title: String(localized: "Could not save photo"),
                message: error.localizedDescription
            )
        }
    }

    func avatarFileURL(for filename: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("avatars").appendingPathComponent(filename)
    }

    func localAvatarImage(for user: AuthUser) -> UIImage? {
        guard let filename = user.avatarLocalFilename else { return nil }
        let url = avatarFileURL(for: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Data

    /// Permanently deletes everything the app stored on this device and removes
    /// all shields and schedules. Screen Time authorization itself is managed by iOS.
    func deleteAllData() async {
        do {
            try await env.sessions.deleteAll()
            try env.profileStore.delete()
            try env.companionStore.delete()
            if let user = currentUser, let filename = user.avatarLocalFilename {
                let url = avatarFileURL(for: filename)
                try? FileManager.default.removeItem(at: url)
            }
            try await env.authentication.deleteAccount(appleRevocationHandler: nil)
            currentUser = nil
        } catch {
            log.error("Data deletion incomplete: \(String(describing: error), privacy: .public)")
            alert = AppAlert(
                title: String(localized: "Some data couldn't be deleted"),
                message: String(localized: "Please try again.")
            )
        }
        env.protection.resetAll()
        await env.notifications.removeDailyVerses()
        // Everything added since: journal, reading plans, prayer times, festival greetings.
        journal.deleteAll()
        plans.reset()
        await salah.reset()
        env.preferences.removeObject(forKey: FestivalSettings.key)
        await env.notifications.removeFestivals()
        pendingCompanionQuestion = nil
        stored = StoredProfile()
        applyTheme()
        dailyVerse = nil
        scripturePath = []
        todayMood = nil
        habitSummary = nil
        recentSessions = []
        activeMoment = nil
        selectedTab = .today
        refreshProtectionStatus()
    }
}
