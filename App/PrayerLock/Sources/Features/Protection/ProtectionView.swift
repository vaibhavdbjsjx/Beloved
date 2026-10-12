import FamilyControls
import ManagedSettings
import PLDesign
import PLProtection
import SwiftUI

/// Screen Time setup: a clear status at the top, then what is paused, whether protection is
/// on, and how long apps open after a moment — plus a plain statement of what iOS does and
/// doesn't allow.
struct ProtectionView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.xl) {
                    ProtectionStatusHero(status: model.protectionStatus)
                        .plStaggered(0)
                    ProtectionSetupPanel()
                        .plStaggered(1)
                    limits
                        .plStaggered(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PLSpacing.page)
                .padding(.top, PLSpacing.s)
                .padding(.bottom, PLSpacing.xxxl)
            }
            .background(Color.plCanvas)
            .navigationTitle("Protection")
        }
    }

    private var limits: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(String(localized: "What protection can and can't do"))
            VStack(alignment: .leading, spacing: 0) {
                limitRow("checkmark", "\(AppBrand.displayName) can place a pause in front of apps, categories and websites you choose.")
                PLHairline().padding(.leading, PLSpacing.xxxl)
                limitRow("info.circle", "It can't block phone calls, silence other apps' notifications or turn on Focus — iOS doesn't allow apps to do that.")
                PLHairline().padding(.leading, PLSpacing.xxxl)
                limitRow("person.crop.circle.badge.checkmark", "You stay in control: turn protection off here, or remove Screen Time access in the Settings app.")
            }
            .plPaper(padding: 0)
        }
    }

    private func limitRow(_ systemImage: String, _ text: LocalizedStringKey) -> some View {
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
}

/// The state of protection at a glance: a mark, a title and one plain sentence.
struct ProtectionStatusHero: View {
    let status: ProtectionStatus

    var body: some View {
        HStack(alignment: .center, spacing: PLSpacing.l) {
            ZStack {
                Circle()
                    .fill(status.tone == .active ? Color.plAccentSoft : Color.plSurface)
                Circle()
                    .strokeBorder(status.tone == .attention ? Color.plCaution : Color.plGilt, lineWidth: 1)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(status.tone == .attention ? Color.plCaution : Color.plAccent)
            }
            .frame(width: 60, height: 60)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text(status.title)
                    .font(.plTitle)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status.summary)
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("protection.status")
    }

    private var icon: String {
        switch status {
        case .active: "shield.lefthalf.filled"
        case .unlocked: "lock.open"
        case .off: "shield.slash"
        case .needsSelection: "square.grid.2x2"
        case .needsAuthorization: "hourglass"
        case .authorizationRevoked, .needsReselection, .unavailable: "exclamationmark"
        }
    }
}

/// Reused by onboarding and the Protection tab: authorization, app choice, the on/off
/// switch and the unlock duration. All Screen Time calls go through `AppModel`.
struct ProtectionSetupPanel: View {
    @Environment(AppModel.self) private var model
    @State private var selection = FamilyActivitySelection()
    @State private var showingPicker = false
    @State private var limitIssues: [SelectionLimits.Issue] = []

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xl) {
            switch model.protectionStatus {
            case .unavailable:
                notice(
                    title: "Not available here",
                    text: "Screen Time protection isn't available on this device. The rest of \(AppBrand.displayName) still works."
                )
            case .needsAuthorization:
                VStack(alignment: .leading, spacing: PLSpacing.m) {
                    Text("To place a pause in front of the apps you choose, \(AppBrand.displayName) needs Screen Time access. iOS asks you to confirm with Face ID, Touch ID or your passcode.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Allow Screen Time access") {
                        Task { await model.requestScreenTimeAuthorization() }
                    }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("protection.authorize")
                    privacyNote
                }
                .plPaper()
            case .authorizationRevoked:
                VStack(alignment: .leading, spacing: PLSpacing.m) {
                    Text("Screen Time access for \(AppBrand.displayName) is turned off, so your chosen apps aren't paused right now. Your choices are saved — allow access again to resume.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Allow Screen Time access again") {
                        Task { await model.requestScreenTimeAuthorization() }
                    }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("protection.reauthorize")
                }
                .plPaper()
            case .needsReselection:
                VStack(alignment: .leading, spacing: PLSpacing.m) {
                    Text("iOS needs you to confirm the apps you want to protect. Until you do, some of them may not be paused.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Choose apps again") { showingPicker = true }
                        .buttonStyle(.plPrimary)
                        .accessibilityIdentifier("protection.reselect")
                }
                .plPaper()
                selectionSection
                toggleSection
                durationSection
            default:
                selectionSection
                toggleSection
                durationSection
            }
        }
        .familyActivityPicker(
            headerText: String(localized: "Choose apps to pause before"),
            footerText: String(localized: "Up to 50 apps, 50 categories, and 50 websites."),
            isPresented: $showingPicker,
            selection: $selection
        )
        .onAppear { selection = model.env.protection.selection }
        .onChange(of: selection) { _, newValue in
            limitIssues = model.updateSelection(newValue)
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: PLSpacing.s) {
            Image(systemName: "eye.slash")
                .font(.footnote)
                .foregroundStyle(Color.plGilt)
                .accessibilityHidden(true)
            Text("Your choices stay private: iOS gives \(AppBrand.displayName) anonymous tokens — never the names of apps you use or how long you use them.")
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notice(title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            Text(title)
                .font(.plTitleSmall)
                .foregroundStyle(Color.plInk)
            Text(text)
                .font(.plCallout)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plPaper()
    }

    // MARK: - Sections

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(String(localized: "Pause before"))
            VStack(alignment: .leading, spacing: 0) {
                let apps = Array(selection.applicationTokens)
                if selection.isEmptySelection {
                    Text("No apps chosen yet. Choose the ones you tend to open without thinking.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(PLSpacing.l)
                } else {
                    ForEach(apps.prefix(8), id: \.self) { token in
                        Label(token)
                            .font(.plHeadline)
                            .foregroundStyle(Color.plInk)
                            .padding(.horizontal, PLSpacing.l)
                            .padding(.vertical, PLSpacing.s)
                        PLHairline().padding(.leading, PLSpacing.l)
                    }
                    if apps.count > 8 {
                        Text("and \(apps.count - 8) more")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .padding(.horizontal, PLSpacing.l)
                            .padding(.vertical, PLSpacing.s)
                    }
                    if !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty {
                        Text("\(selection.categoryTokens.count) categories · \(selection.webDomainTokens.count) websites")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .padding(.horizontal, PLSpacing.l)
                            .padding(.vertical, PLSpacing.s)
                    }
                }
                PLHairline()
                Button {
                    showingPicker = true
                } label: {
                    Label(selection.isEmptySelection ? "Choose apps" : "Change apps", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plQuiet)
                .padding(.horizontal, PLSpacing.l)
                .padding(.vertical, PLSpacing.xs)
                .accessibilityIdentifier("protection.chooseApps")
            }
            .plPaper(padding: 0)
            ForEach(limitIssues, id: \.self) { issue in
                Text(issue.message)
                    .font(.plCallout)
                    .foregroundStyle(Color.plCaution)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var toggleSection: some View {
        Toggle(isOn: Binding(
            get: { model.protectionSettings.isEnabled },
            set: { model.setProtectionEnabled($0) }
        )) {
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text("Protection")
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                Text(model.protectionStatus.summary)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.plAccent)
        .disabled(selection.isEmptySelection)
        .plPaper(padding: PLSpacing.l)
        .accessibilityIdentifier("protection.toggle")
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(String(localized: "After a moment, apps open for"))
            PLFlowLayout {
                ForEach(UnlockDuration.options, id: \.self) { duration in
                    PLChip(duration.title, isSelected: model.protectionSettings.unlockDuration == duration) {
                        model.setUnlockDuration(duration)
                    }
                }
            }
            Text(model.protectionSettings.unlockDuration.detail)
                .font(.plCaption)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension SelectionLimits.Issue {
    var message: String {
        switch self {
        case let .tooManyApplications(count):
            String(localized: "iOS allows up to 50 apps; you chose \(count). Please remove some.")
        case let .tooManyCategories(count):
            String(localized: "iOS allows up to 50 categories; you chose \(count). Please remove some.")
        case let .tooManyWebDomains(count):
            String(localized: "iOS allows up to 50 websites; you chose \(count). Please remove some.")
        }
    }
}
