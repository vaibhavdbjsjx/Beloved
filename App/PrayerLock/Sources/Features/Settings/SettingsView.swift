import PLContent
import PLDesign
import PLFaith
import PLMonetization
import PLScripture
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmingDeletion = false
    @State private var notificationStatus: UNAuthorizationStatus?
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system

    var body: some View {
        NavigationStack {
            Form {
                practice
                intentionsSection
                appearanceSection
                dailyVerseSection
                notifications
                privacy
                premium
                sources
                about
            }
            .labeledContentStyle(.pl)
            .scrollContentBackground(.hidden)
            .background(Color.plCanvas)
            .navigationTitle("Settings")
            .environment(\.defaultMinListRowHeight, 52)
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                // Returning from the Settings app after changing notification permission.
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
            .confirmationDialog(
                "Delete all your data?",
                isPresented: $confirmingDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    Task { await model.deleteAllData() }
                }
            } message: {
                Text("This permanently removes your profile, conversations, check-ins, and prayer history from this iPhone, and turns off protection. It can't be undone.")
            }
        }
    }

    private var practice: some View {
        Section {
            NavigationLink {
                FaithSettingsView()
            } label: {
                LabeledContent("Faith & tradition", value: faithSummary)
            }
            ContentPreferencesFields(
                profile: Binding(get: { model.profile }, set: { newValue in model.updateProfile { $0 = newValue } }),
                offersDevotionalCustoms: model.profile.faithID.map { faith in
                    model.env.devotionalAssociations.all.contains { $0.faith == faith }
                } ?? false
            )
        } header: {
            Text("Your practice")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    /// Marketing version plus build number, so support requests identify the exact build.
    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }

    private var faithSummary: String {
        guard let faith = model.faith else { return String(localized: "Not specified") }
        let name = faith.name.resolved(for: model.profile.languages)
        guard let tradition = model.profile.traditionID.flatMap(model.env.registry.tradition) else { return name }
        return "\(name) · \(tradition.name.resolved(for: model.profile.languages))"
    }

    // MARK: - Intentions and appearance

    private var intentionsSection: some View {
        Section {
            NavigationLink {
                IntentionsSettingsView()
            } label: {
                LabeledContent("Your intentions", value: intentionsSummary)
            }
            .accessibilityIdentifier("settings.intentions")
        } header: {
            Text("Intentions")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    private var intentionsSummary: String {
        let count = model.profile.intentions.count
        return count == 0 ? String(localized: "None yet") : String(localized: "\(count) of \(SpiritualProfile.maximumIntentions)")
    }

    private var appearanceSection: some View {
        Section {
            // Chips rather than a segmented control: segmented controls don't grow with
            // accessibility text sizes (seen at AX5), chips do.
            PLFlowLayout {
                ForEach(AppearancePreference.allCases) { option in
                    PLChip(option.title, isSelected: appearance == option) { appearance = option }
                        .accessibilityIdentifier("settings.appearance.\(option.rawValue)")
                }
            }
            .padding(.vertical, PLSpacing.xxs)
        } header: {
            Text("Appearance")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    // MARK: - Daily verse

    @ViewBuilder
    private var dailyVerseSection: some View {
        if model.offersDailyVerse, let work = model.readableWork?.work {
            let reminder = model.dailyVerseReminder
            Section {
                Toggle("Daily verse notification", isOn: Binding(
                    get: { reminder.isEnabled },
                    set: { value in
                        var updated = reminder
                        updated.isEnabled = value
                        Task {
                            await model.setDailyVerseReminder(updated)
                            await refreshNotificationStatus()
                        }
                    }
                ))
                .tint(.plAccent)
                .accessibilityIdentifier("settings.dailyVerse")
                if reminder.isEnabled {
                    DatePicker("Time", selection: Binding(
                        get: {
                            model.env.calendar.date(from: DateComponents(hour: reminder.hour, minute: reminder.minute)) ?? .now
                        },
                        set: { date in
                            let parts = model.env.calendar.dateComponents([.hour, .minute], from: date)
                            Task {
                                await model.setDailyVerseReminder(DailyVerseReminder(
                                    isEnabled: true, hour: parts.hour ?? reminder.hour, minute: parts.minute ?? reminder.minute))
                            }
                        }
                    ), displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("settings.dailyVerseTime")
                }
            } header: {
                Text("Verse for today")
                    .foregroundStyle(Color.plInkSecondary)
            } footer: {
                Text("A verse from \(work.title.resolved(for: model.profile.languages)) each day, the same one Today shows. Notifications can appear on your Lock Screen; previews follow your iPhone's notification settings.")
                    .foregroundStyle(Color.plInkSecondary)
            }
            .listRowBackground(Color.plSurface)
        }
    }

    // MARK: - Notifications

    private func refreshNotificationStatus() async {
        notificationStatus = await model.env.notifications.authorizationStatus()
    }

    @ViewBuilder
    private var notifications: some View {
        Section {
            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                LabeledContent("Notifications", value: String(localized: "On"))
            case .denied:
                LabeledContent("Notifications", value: String(localized: "Off"))
                Button("Turn on in the Settings app") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .accessibilityIdentifier("settings.notificationSettings")
            case .notDetermined:
                LabeledContent("Notifications", value: String(localized: "Not set"))
                Button("Allow notifications") {
                    Task {
                        await model.env.notifications.requestAuthorization()
                        await refreshNotificationStatus()
                    }
                }
                .accessibilityIdentifier("settings.allowNotifications")
            default:
                LabeledContent("Notifications", value: "–")
            }
        } header: {
            Text("Notifications")
                .foregroundStyle(Color.plInkSecondary)
        } footer: {
            Text("Used when you tap Begin on a paused app and iOS can't open \(AppBrand.displayName) directly — a notification takes you to your moment — and for the daily verse, if you turn it on. Pauses work either way.")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    private var privacy: some View {
        Section {
            Toggle("Remember daily check-ins", isOn: Binding(
                get: { model.profile.rememberCheckIns },
                set: { value in model.updateProfile { $0.rememberCheckIns = value } }
            ))
            NavigationLink("How your data is handled") { PrivacyDetailView() }
            NavigationLink("Privacy Policy") { LegalDocumentView(resource: .privacyPolicy) }
                .accessibilityIdentifier("settings.privacyPolicy")
            Button("Delete all my data", role: .destructive) { confirmingDeletion = true }
                .foregroundStyle(Color.plDestructive) // system red fails WCAG AA on white
                .accessibilityIdentifier("settings.deleteAll")
        } header: {
            Text("Privacy")
                .foregroundStyle(Color.plInkSecondary)
        } footer: {
            Text("When check-ins aren't remembered, your mood is used for today's moment and then discarded.")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }

    /// Shown only when in-app purchases exist for this build. While the paywall is
    /// disabled there is nothing to buy or restore, so no purchase UI appears at all.
    @ViewBuilder
    private var premium: some View {
        if model.env.monetization.isPaywallEnabled {
            Section {
                LabeledContent("Status", value: model.accessLevel == .premium ? String(localized: "Premium") : String(localized: "Free"))
                Button("Restore purchases") {
                    Task { await model.restorePurchases() }
                }
            } header: {
                Text("Premium")
                    .foregroundStyle(Color.plInkSecondary)
            }
            .listRowBackground(Color.plSurface)
        }
    }

    @ViewBuilder
    private var sources: some View {
        Section {
            NavigationLink("Sources & attributions") { SourcesView() }
            if model.env.configuration.isDevelopment {
                Text("Development build: unreviewed draft content is visible and marked. Release builds show only reviewed, rights-cleared content.")
                    .font(.plCaption)
                    .foregroundStyle(Color.plCaution)
            }
        } header: {
            Text("Content")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
        if model.env.configuration.isDevelopment {
            Section {
                NavigationLink("Protection diagnostics") { ProtectionDiagnosticsView() }
                    .accessibilityIdentifier("settings.diagnostics")
            } header: {
                Text("Development")
                    .foregroundStyle(Color.plInkSecondary)
            }
            .listRowBackground(Color.plSurface)
        }
    }

    private var about: some View {
        Section {
            LabeledContent("Version", value: versionDescription)
                .accessibilityIdentifier("settings.version")
            if let support = model.env.configuration.supportURL {
                Link("Help & support", destination: support)
                    .accessibilityIdentifier("settings.support")
            }
        } header: {
            Text("About")
                .foregroundStyle(Color.plInkSecondary)
        } footer: {
            Text("\(AppBrand.displayName) is an independent app and doesn't speak for any religious community. Every passage shows where it comes from.")
                .foregroundStyle(Color.plInkSecondary)
        }
        .listRowBackground(Color.plSurface)
    }
}

/// Edit faith, tradition, and focus after onboarding.
struct FaithSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft = SpiritualProfile()
    @State private var hasChosen = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                FaithChoiceList(registry: model.env.registry, profile: $draft, hasChosen: $hasChosen)
                if let faith = draft.faithID.flatMap(model.env.registry.faith) {
                    if !faith.traditions.isEmpty {
                        SectionHeading(faith.traditionLabel.resolved(for: draft.languages))
                        TraditionChoiceList(faith: faith, profile: $draft)
                    }
                    if faith.usesSpiritualFocus, let label = faith.focusLabel {
                        SectionHeading(label.resolved(for: draft.languages))
                        FocusChoiceList(faith: faith, profile: $draft)
                    }
                }
            }
            .padding(PLSpacing.l)
        }
        .background(Color.plCanvas)
        .navigationTitle("Faith & tradition")
        .toolbar {
            Button("Save") {
                model.updateProfile { $0 = draft }
                dismiss()
            }
        }
        .onAppear { draft = model.profile }
    }
}

struct PrivacyDetailView: View {
    var body: some View {
        Form {
            Section("Stored on this iPhone") {
                Text("Your faith and preferences, where you left off reading, your conversations with the companion, today's check-in (if remembered), and your prayer history. Protected by iOS Data Protection — unreadable while your iPhone is locked. Included in your own iCloud or computer backups.")
            }
            Section("Never collected") {
                Text("Which apps you use or for how long. Screen Time gives \(AppBrand.displayName) anonymous tokens only, and app usage data never leaves Apple's frameworks.")
            }
            Section("Not sent anywhere") {
                Text("\(AppBrand.displayName) makes no network requests with your data. There's no account, no analytics, no advertising, and no tracking.")
            }
            Section("Shared with the app's own extensions") {
                Text("To show the pause screen, the app's Screen Time extensions read your protection settings and the pause-screen text. They never read your prayer history.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.plCanvas)
        .navigationTitle("Your data")
        .safeAreaInset(edge: .bottom) {
            NavigationLink("Read the full Privacy Policy") { LegalDocumentView(resource: .privacyPolicy) }
                .buttonStyle(.plSecondary)
                .padding(PLSpacing.l)
        }
    }
}

/// Attribution for the editions behind the passages users can actually see. Development
/// builds list every edition with its rights status; release builds list only editions
/// quoted by visible content, so no pending or unused source is ever shown.
struct SourcesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let env = model.env
        // Editions quoted by visible content, plus those the reader may show in this build.
        let readable = env.registry.faiths.compactMap {
            env.scripturePolicy.readableWork(for: $0.id, manifest: env.scripture.manifest, registry: env.registry)
        }
        let readerEditions = readable.flatMap { ([$0.translation, $0.transliteration].compactMap { $0 } + $0.originals).map(\.id) }
        let cited = env.catalog.citedEditions(policy: env.contentPolicy, registry: env.registry).union(readerEditions)
        List {
            ForEach(env.registry.faiths) { faith in
                let editions = faith.sources.flatMap(\.editions).filter {
                    env.configuration.isDevelopment || cited.contains($0.id)
                }
                if !editions.isEmpty {
                    Section(faith.name.resolved(for: model.profile.languages)) {
                        ForEach(editions) { edition in
                            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                                Text(edition.title.resolved(for: model.profile.languages))
                                    .font(.headline)
                                Text(edition.license.title)
                                    .font(.plCaption)
                                    .foregroundStyle(edition.license.permitsRedistribution ? Color.plInkSecondary : Color.plCaution)
                                Text(edition.attribution)
                                    .font(.plCaption)
                                    .foregroundStyle(Color.plInkSecondary)
                            }
                        }
                    }
                }
            }
            Section {
                Text("Every passage is labelled as scripture, traditional text, an editorial prayer, an explanation, or a reflection, so you always know what you're reading. Quotations from scripture show the edition they come from.")
                    .font(.plCaption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.plCanvas)
        .navigationTitle("Sources")
    }
}

/// Edit intentions from Settings. Saves when leaving, so half-typed lines aren't trimmed
/// away while the user is still writing.
struct IntentionsSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: [String] = []
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                Text("A few words to return to. Today shows one each day, and your moments offer them as a next step. They stay on this iPhone and never appear on the pause screen.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                IntentionsEditor(intentions: $draft)
            }
            .padding(PLSpacing.page)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.plCanvas)
        .navigationTitle("Your intentions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            draft = model.profile.intentions
        }
        .onDisappear { model.updateIntentions(draft) }
        // Also save if the app leaves the foreground mid-edit (it may not come back).
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.updateIntentions(draft) }
        }
    }
}
