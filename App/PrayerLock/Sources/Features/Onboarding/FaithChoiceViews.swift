import PLDesign
import PLFaith
import SwiftUI

/// Faith choice — including a first-class "rather not say" option.
struct FaithChoiceList: View {
    let registry: FaithRegistry
    @Binding var profile: SpiritualProfile
    /// `false` until the user makes an explicit choice (so nothing is pre-selected).
    @Binding var hasChosen: Bool

    var body: some View {
        VStack(spacing: PLSpacing.s) {
            ForEach(registry.faiths) { faith in
                PLChoiceCard(
                    title: faith.name.resolved(for: profile.languages),
                    subtitle: faith.summary.resolved(for: profile.languages),
                    isSelected: hasChosen && profile.faithID == faith.id
                ) { select(faith.id) }
                .accessibilityIdentifier("faith.\(faith.id.rawValue)")
            }
            PLChoiceCard(
                title: String(localized: "I'd rather not say"),
                subtitle: String(localized: "Faith-neutral pauses for breath and intention."),
                isSelected: hasChosen && profile.faithID == nil
            ) { select(nil) }
            .accessibilityIdentifier("faith.none")
        }
    }

    private func select(_ id: FaithID?) {
        if profile.faithID != id {
            profile.faithID = id
            profile.traditionID = nil
            profile.focusIDs = []
            profile.useDevotionalAssociations = false
        }
        hasChosen = true
    }
}

struct TraditionChoiceList: View {
    let faith: Faith
    @Binding var profile: SpiritualProfile

    var body: some View {
        VStack(spacing: PLSpacing.s) {
            ForEach(faith.traditions) { tradition in
                PLChoiceCard(
                    title: tradition.name.resolved(for: profile.languages),
                    subtitle: tradition.summary?.resolved(for: profile.languages),
                    isSelected: profile.traditionID == tradition.id
                ) { profile.traditionID = tradition.id }
                .accessibilityIdentifier("tradition.\(tradition.id.rawValue)")
            }
            PLChoiceCard(
                title: String(localized: "Prefer not to specify"),
                isSelected: profile.traditionID == nil
            ) { profile.traditionID = nil }
        }
    }
}

struct FocusChoiceList: View {
    let faith: Faith
    @Binding var profile: SpiritualProfile

    var body: some View {
        VStack(spacing: PLSpacing.s) {
            ForEach(faith.focuses) { focus in
                let selected = profile.focusIDs.contains(focus.id)
                PLChoiceCard(
                    title: focus.name.resolved(for: profile.languages),
                    subtitle: focus.alsoKnownAs.isEmpty ? nil : focus.alsoKnownAs.joined(separator: " · "),
                    isSelected: selected
                ) {
                    if selected {
                        profile.focusIDs.removeAll { $0 == focus.id }
                    } else {
                        profile.focusIDs.append(focus.id)
                    }
                }
            }
        }
    }
}

/// Content preferences shared by onboarding and Settings (inside a Form).
struct ContentPreferencesFields: View {
    @Binding var profile: SpiritualProfile
    let offersDevotionalCustoms: Bool

    var body: some View {
        Picker("Length of a moment", selection: $profile.contentLength) {
            ForEach(ContentLength.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        Toggle("Show original script", isOn: $profile.showOriginalScript)
            .accessibilityIdentifier("settings.showOriginalScript")
        Toggle("Show transliteration", isOn: $profile.showTransliteration)
            .accessibilityIdentifier("settings.showTransliteration")
        if offersDevotionalCustoms {
            Toggle("Use weekday customs", isOn: $profile.useDevotionalAssociations)
        }
    }
}

/// The same preferences, laid out on paper for onboarding (outside a Form).
struct ContentPreferencesPanel: View {
    @Binding var profile: SpiritualProfile
    let offersDevotionalCustoms: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.l) {
            VStack(alignment: .leading, spacing: PLSpacing.s) {
                SectionHeading(String(localized: "Length of a moment"))
                PLFlowLayout {
                    ForEach(ContentLength.allCases, id: \.self) { length in
                        PLChip(length.title, isSelected: profile.contentLength == length) {
                            profile.contentLength = length
                        }
                    }
                }
                Text(profile.contentLength.durationHint)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
            }
            VStack(spacing: 0) {
                toggleRow("Show original script", detail: "Arabic, Sanskrit and other scripts, where a passage has them.",
                          isOn: $profile.showOriginalScript)
                PLHairline().padding(.leading, PLSpacing.l)
                toggleRow("Show transliteration", detail: "How the original words sound, in Latin letters.",
                          isOn: $profile.showTransliteration)
                if offersDevotionalCustoms {
                    PLHairline().padding(.leading, PLSpacing.l)
                    toggleRow("Use weekday customs",
                              detail: "Weekday customs (for example, Monday and Shiva in many Hindu communities) vary by region and family. Turn this on only if they're part of your practice.",
                              isOn: $profile.useDevotionalAssociations)
                }
            }
            .plPaper(padding: 0)
        }
    }

    private func toggleRow(_ title: LocalizedStringKey, detail: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text(title)
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                Text(detail)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.plAccent)
        .padding(.horizontal, PLSpacing.l)
        .padding(.vertical, PLSpacing.m)
    }
}
