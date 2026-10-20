import PLDesign
import PLFaith
import PLProtection
import SwiftUI
import UserNotifications

/// First launch. Collects only what improves the experience; every personal question is
/// optional, and nothing leaves the device. Answers are saved as the user moves between
/// steps, so closing the app mid-setup resumes where they left off.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    typealias Step = OnboardingStep

    @State private var step: Step = .welcome
    @State private var draft = SpiritualProfile()
    @State private var hasChosenFaith = false
    @State private var showingPrivacyPolicy = false
    @State private var hasRestored = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @FocusState private var nameFocused: Bool

    private var faith: Faith? { draft.faithID.flatMap(model.env.registry.faith) }
    private var light: Color { PLLight.current(calendar: model.env.calendar) }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
            }
            stepContent
                .id(step)
                .plAppearTransition()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Color.plCanvas
                PLLightWash(light: light, height: 480)
            }
            .ignoresSafeArea()
        }
        .animation(PLMotion.animation(PLMotion.gentle, reduceMotion: reduceMotion), value: step)
        .onAppear(perform: restoreProgress)
        .onChange(of: step) { _, newStep in
            saveProgress()
            if newStep == .summary {
                Task { notificationStatus = await model.env.notifications.authorizationStatus() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveProgress() }
        }
    }

    // MARK: - Progress

    private func restoreProgress() {
        guard !hasRestored else { return }
        hasRestored = true
        guard let progress = model.stored.onboardingProgress else { return }
        draft = model.profile
        hasChosenFaith = progress.hasChosenFaith
        step = OnboardingFlow(faith: draft.faithID.flatMap(model.env.registry.faith), includesProtection: model.screenTimeEnabled).resumeStep(for: progress)
    }

    private func saveProgress() {
        guard hasRestored else { return }
        model.saveOnboardingProgress(draft, progress: OnboardingProgress(step: step, hasChosenFaith: hasChosenFaith))
    }

    // MARK: - Navigation

    private var flow: OnboardingFlow { OnboardingFlow(faith: faith, includesProtection: model.screenTimeEnabled) }

    private func move(by offset: Int) {
        nameFocused = false
        if let next = flow.step(from: step, offset: offset) {
            step = next
        } else if offset > 0 {
            finish()
        }
    }

    private func finish() {
        draft.intentions = SpiritualProfile.normalizedIntentions(draft.intentions)
        model.completeOnboarding(with: draft)
    }

    /// Position among the steps that apply to this person (welcome excluded).
    private var progress: (index: Int, total: Int) {
        let steps = Step.allCases.filter { $0 != .welcome && flow.isApplicable($0) }
        let index = (steps.firstIndex(of: step) ?? 0) + 1
        return (index, steps.count)
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(spacing: PLSpacing.m) {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.plInk)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.plSurface))
                    .overlay(Circle().strokeBorder(Color.plLine, lineWidth: 1))
            }
            .accessibilityLabel(Text("Back"))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.plLine)
                    Capsule()
                        .fill(Color.plAccent)
                        .frame(width: proxy.size.width * CGFloat(progress.index) / CGFloat(max(progress.total, 1)))
                }
            }
            .frame(height: 3)
            .accessibilityElement()
            .accessibilityLabel(Text("Setup progress"))
            .accessibilityValue(Text("Step \(progress.index) of \(progress.total)"))
        }
        .padding(.horizontal, PLSpacing.m)
        .padding(.top, PLSpacing.xs)
    }

    private var footer: some View {
        VStack(spacing: PLSpacing.xxs) {
            switch step {
            case .welcome:
                Button("Begin") { move(by: 1) }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("onboarding.getStarted")
            case .faith:
                Button("Continue") { move(by: 1) }
                    .buttonStyle(.plPrimary)
                    .disabled(!hasChosenFaith)
                    .accessibilityIdentifier("onboarding.continue")
            case .protection:
                Button("Continue") { move(by: 1) }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("onboarding.continue")
                Button("Set up later") { move(by: 1) }
                    .buttonStyle(.plQuiet(.plInkSecondary))
            case .notifications:
                Button("Allow notifications") {
                    Task {
                        await model.env.notifications.requestAuthorization()
                        move(by: 1)
                    }
                }
                .buttonStyle(.plPrimary)
                Button("Not now") { move(by: 1) }
                    .buttonStyle(.plQuiet(.plInkSecondary))
                    .accessibilityIdentifier("onboarding.notificationsLater")
            case .summary:
                Button("Start using \(AppBrand.displayName)") { finish() }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("onboarding.finish")
            default:
                Button("Continue") { move(by: 1) }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("onboarding.continue")
            }
        }
        .padding(.horizontal, PLSpacing.page)
        .padding(.top, PLSpacing.s)
        .padding(.bottom, PLSpacing.m)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcome

        case .faith:
            stepScroll(title: "Which tradition guides your prayer?",
                       subtitle: "This shapes the prayers, scripture and observances you see. You can change it any time.") {
                FaithChoiceList(registry: model.env.registry, profile: $draft, hasChosen: $hasChosenFaith)
            }

        case .tradition:
            if let faith {
                stepScroll(title: LocalizedStringKey(faith.traditionLabel.resolved(for: draft.languages)),
                           subtitle: "Optional. Some content and observance dates differ between traditions.") {
                    TraditionChoiceList(faith: faith, profile: $draft)
                }
            }

        case .focus:
            if let faith, let label = faith.focusLabel {
                stepScroll(title: LocalizedStringKey(label.resolved(for: draft.languages)),
                           subtitle: "Optional. Choose any that are part of your practice.") {
                    FocusChoiceList(faith: faith, profile: $draft)
                }
            }

        case .personalize:
            stepScroll(title: "Make it yours",
                       subtitle: "Everything here is optional, stays on this iPhone, and can be changed in Settings.") {
                VStack(alignment: .leading, spacing: PLSpacing.xl) {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        SectionHeading(String(localized: "What should we call you?"))
                        TextField("First name (optional)", text: Binding(
                            get: { draft.displayName ?? "" },
                            set: { draft.displayName = $0.isEmpty ? nil : $0 }
                        ))
                        .font(.plTitleSmall)
                        .textContentType(.givenName)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .padding(.horizontal, PLSpacing.l)
                        .frame(minHeight: 56)
                        .plPaper(radius: PLRadius.control, padding: 0)
                        Text("Only used for greetings on this iPhone.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                    }
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        SectionHeading(String(localized: "An intention to return to"))
                        Text("A few words a pause can remind you of. Your moments will offer it as a next step.")
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        IntentionsEditor(intentions: $draft.intentions)
                    }
                    ContentPreferencesPanel(profile: $draft, offersDevotionalCustoms: offersDevotionalCustoms)
                }
            }

        case .privacy:
            stepScroll(title: "Private by design",
                       subtitle: "Prayer is personal. \(AppBrand.displayName) is built so it stays that way.") {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    VStack(alignment: .leading, spacing: 0) {
                        privacyRow("iphone", "Your practice, moods and prayer history are stored on this iPhone (and in your own device backups) — never on our servers.")
                        PLHairline().padding(.leading, PLSpacing.xxxl)
                        privacyRow("person.crop.circle.badge.xmark", "No account. No ads. Your spiritual data is never sold.")
                        PLHairline().padding(.leading, PLSpacing.xxxl)
                        if model.screenTimeEnabled {
                            privacyRow("eye.slash", "Screen Time gives \(AppBrand.displayName) anonymous tokens — never which apps you use or for how long.")
                            PLHairline().padding(.leading, PLSpacing.xxxl)
                        }
                        privacyRow("trash", "Delete everything at any time in Settings.")
                    }
                    .plPaper(padding: 0)
                    Button("Read the Privacy Policy") { showingPrivacyPolicy = true }
                        .buttonStyle(.plQuiet)
                        .accessibilityIdentifier("onboarding.privacyPolicy")
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                NavigationStack {
                    LegalDocumentView(resource: .privacyPolicy)
                        .toolbar {
                            Button("Done") { showingPrivacyPolicy = false }
                        }
                }
            }

        case .protection:
            stepScroll(title: "Choose where to pause",
                       subtitle: "When you open one of these apps, \(AppBrand.displayName) invites you to pause first. After your moment, they open for the time you choose.") {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    ProtectionSetupPanel()
                    Text("If you skip this or don't allow Screen Time access, nothing is paused — the rest of \(AppBrand.displayName) still works, and you can set this up any time in the Protection tab.")
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .notifications:
            stepScroll(title: "One notification, when you need it",
                       subtitle: "When you tap Begin on a paused app, iOS may not be able to open \(AppBrand.displayName) directly. This is the only notification \(AppBrand.displayName) sends — it takes you straight to your moment.") {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    NotificationPreview(copy: ShieldCopyFactory.make(for: draft))
                    Text("If you choose Not now, \(AppBrand.displayName) still pauses your apps. You can change this later in Settings.")
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .summary:
            stepScroll(title: "You're ready",
                       subtitle: "Here's your setup. You can change any of it later.") {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    VStack(alignment: .leading, spacing: 0) {
                        summaryRow("Practice", value: practiceSummary, systemImage: "book")
                        PLHairline().padding(.leading, PLSpacing.xxxl)
                        summaryRow("Moments", value: "\(draft.contentLength.title) · \(draft.contentLength.durationHint)", systemImage: "text.alignleft")
                        if let intention = SpiritualProfile.normalizedIntentions(draft.intentions).first {
                            PLHairline().padding(.leading, PLSpacing.xxxl)
                            summaryRow("Intention", value: "“\(intention)”", systemImage: "sparkle")
                        }
                        PLHairline().padding(.leading, PLSpacing.xxxl)
                        if model.screenTimeEnabled {
                            summaryRow("Protection", value: protectionSummary, systemImage: "shield.lefthalf.filled")
                            PLHairline().padding(.leading, PLSpacing.xxxl)
                        }
                        summaryRow("Notifications", value: notificationSummary, systemImage: "bell")
                    }
                    .plPaper(padding: 0)
                    Text(nextStepSummary)
                        .font(.plQuote)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Welcome

    private var welcome: some View {
        // Scrolls (and stays centred when it fits) so the largest Dynamic Type sizes never clip.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: PLSpacing.xl) {
                    ThresholdWindow(width: 176, light: light, presence: .breathing, showsDove: true)
                    VStack(spacing: PLSpacing.m) {
                        HStack(spacing: PLSpacing.xs) {
                            ThresholdMark(size: 12)
                            Text(AppBrand.displayName)
                                .plEyebrow()
                        }
                        Text(model.screenTimeEnabled ? "A pause before the scroll." : "A moment for what matters.")
                            .plHero()
                            .accessibilityAddTraits(.isHeader)
                        Text(model.screenTimeEnabled
                             ? "When you reach for a distracting app, \(AppBrand.displayName) offers a moment of prayer or stillness first — then you continue, on purpose."
                             : "Prayers, mantras, duas and scripture for your faith — with your festivals, prayer times and a companion who knows your tradition.")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.center)
                    Text("No account · No ads · Stays on your iPhone")
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, PLSpacing.page)
                .padding(.vertical, PLSpacing.xl)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Rows

    private func privacyRow(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PLSpacing.m) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(Color.plGilt)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(text)
                .font(.plCallout)
                .foregroundStyle(Color.plInk)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PLSpacing.l)
        .padding(.vertical, PLSpacing.m)
    }

    private func summaryRow(_ title: LocalizedStringKey, value: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PLSpacing.m) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(Color.plGilt)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text(title).plEyebrow(.plInkSecondary)
                Text(verbatim: value)
                    .font(.plCallout)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PLSpacing.l)
        .padding(.vertical, PLSpacing.m)
        .accessibilityElement(children: .combine)
    }

    private var practiceSummary: String {
        guard let faith else { return String(localized: "Faith-neutral moments") }
        var parts = [faith.name.resolved(for: draft.languages)]
        if let tradition = faith.traditions.first(where: { $0.id == draft.traditionID }) {
            parts.append(tradition.name.resolved(for: draft.languages))
        }
        let focuses = faith.focuses.filter { draft.focusIDs.contains($0.id) }
        if !focuses.isEmpty {
            parts.append(focuses.map { $0.name.resolved(for: draft.languages) }.joined(separator: ", "))
        }
        return parts.joined(separator: " · ")
    }

    private var hasProtection: Bool {
        model.protectionSettings.isEnabled && !model.env.protection.selection.isEmptySelection
    }

    private var protectionSummary: String {
        hasProtection
            ? String(localized: "On · apps open for \(model.protectionSettings.unlockDuration.title) after a moment")
            : String(localized: "Not set up yet")
    }

    private var notificationSummary: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "On")
        case .denied: String(localized: "Off — you can change this later in Settings")
        default: String(localized: "Not set")
        }
    }

    private var nextStepSummary: String {
        if !model.screenTimeEnabled {
            return String(localized: "Open Today for a moment whenever you like, and explore prayers, festivals and your companion in the Pray tab.")
        }
        return hasProtection
            ? String(localized: "Next time you open a chosen app, a pause appears first. Tap Begin for your moment, then continue with intention.")
            : String(localized: "Open Today for a moment whenever you like. Set up protection in the Protection tab when you're ready.")
    }

    private var offersDevotionalCustoms: Bool {
        guard let faithID = draft.faithID else { return false }
        return model.env.devotionalAssociations.all.contains { $0.faith == faithID }
    }

    private func stepScroll(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    Text(title)
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.l)
            .padding(.bottom, PLSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

/// What the hand-off notification looks like, using the exact copy the app sends.
private struct NotificationPreview: View {
    let copy: ShieldCopy

    var body: some View {
        HStack(alignment: .top, spacing: PLSpacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(red: 0.13, green: 0.20, blue: 0.43))
                ThresholdMark(size: 17)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(AppBrand.displayName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.plInkSecondary)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(Color.plInkSecondary)
                }
                Text(copy.notificationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.plInk)
                Text(copy.notificationBody)
                    .font(.subheadline)
                    .foregroundStyle(Color.plInk)
            }
        }
        .padding(PLSpacing.m)
        .plPaper(radius: 20, padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Example notification: \(copy.notificationTitle). \(copy.notificationBody)"))
    }
}
