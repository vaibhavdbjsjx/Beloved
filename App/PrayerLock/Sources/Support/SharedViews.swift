import PLContent
import PLDesign
import PLFaith
import PLProtection
import SwiftUI

// MARK: - Headings

/// A small-caps section label on scrolling screens.
struct SectionHeading: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .plEyebrow(.plInkSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The header of a top-level screen: a gilt eyebrow over a serif title, set like the
/// opening of a chapter. Replaces the system large title so every screen shares one voice.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xs) {
            Text(eyebrow).plEyebrow()
            Text(title)
                .font(.plDisplay)
                .foregroundStyle(Color.plInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let detail {
                Text(detail)
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, PLSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Mood

/// The optional check-in as words rather than a grid of buttons: serif words that flow
/// like a line of text. Selected words are filled lapis *and* set in a heavier weight.
struct MoodWords: View {
    let selected: Mood?
    let onSelect: (Mood) -> Void

    var body: some View {
        PLFlowLayout(spacing: PLSpacing.xs, lineSpacing: PLSpacing.xs) {
            ForEach(Mood.allCases, id: \.self) { mood in
                let isSelected = mood == selected
                Button {
                    onSelect(mood)
                } label: {
                    Text(mood.title)
                        .font(.system(.body, design: .serif, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.plOnAccentFill : Color.plInk)
                        .padding(.horizontal, PLSpacing.m)
                        .frame(minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: PLRadius.chip + 2, style: .continuous)
                                .fill(isSelected ? Color.plAccentFill : Color.plSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PLRadius.chip + 2, style: .continuous)
                                .strokeBorder(isSelected ? Color.clear : Color.plLine, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: PLRadius.chip + 2, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("mood.\(mood.rawValue)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Appearance

/// Light, dark, or follow the system. A device preference, not personal data, so it lives
/// in standard defaults (never in the App Group). Launch argument `-pl.appearance dark`
/// sets it for screenshots.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "pl.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "Automatic")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Intentions

/// Edits the user's personal intentions: a few words a pause can remind them of.
struct IntentionsEditor: View {
    @Binding var intentions: [String]
    @FocusState private var focused: Int?

    static let suggestions = [
        String(localized: "Be present with the people near me"),
        String(localized: "Rest my mind"),
        String(localized: "Finish what I started"),
        String(localized: "Pray before I scroll"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            ForEach(intentions.indices, id: \.self) { index in
                HStack(spacing: PLSpacing.s) {
                    Text("\(index + 1)")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(Color.plGilt)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    TextField("An intention", text: binding(for: index), axis: .vertical)
                        .font(.plQuote)
                        .foregroundStyle(Color.plInk)
                        .focused($focused, equals: index)
                        .submitLabel(.done)
                        .accessibilityLabel(Text("Intention \(index + 1)"))
                    Button {
                        intentions.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color.plInkSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("Remove intention \(index + 1)"))
                }
                .padding(.leading, PLSpacing.m)
                .plPaper(radius: PLRadius.control, padding: PLSpacing.xxs)
            }

            if intentions.count < SpiritualProfile.maximumIntentions {
                Button {
                    intentions.append("")
                    focused = intentions.count - 1
                } label: {
                    Label("Add an intention", systemImage: "plus")
                }
                .buttonStyle(.plQuiet)
                .accessibilityIdentifier("intentions.add")

                if intentions.isEmpty {
                    VStack(alignment: .leading, spacing: PLSpacing.xs) {
                        SectionHeading(String(localized: "Or begin with one of these"))
                        PLFlowLayout {
                            ForEach(Self.suggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    intentions = SpiritualProfile.normalizedIntentions(intentions + [suggestion])
                                }
                                .font(.plCallout)
                                .foregroundStyle(Color.plInk)
                                .padding(.horizontal, PLSpacing.s)
                                .frame(minHeight: 44)
                                .plPaper(radius: PLRadius.chip, padding: 0)
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { intentions.indices.contains(index) ? intentions[index] : "" },
            set: { value in
                guard intentions.indices.contains(index) else { return }
                // The field wraps onto several lines, so Return would insert a line break:
                // treat it as "done" instead. Intentions are one short line.
                if value.contains(where: \.isNewline) {
                    intentions[index] = String(value.filter { !$0.isNewline }.prefix(SpiritualProfile.maximumIntentionLength))
                    focused = nil
                    return
                }
                intentions[index] = String(value.prefix(SpiritualProfile.maximumIntentionLength))
            }
        )
    }
}

// MARK: - Protection presentation

extension ProtectionStatus {
    var tone: PLStatusTone {
        switch self {
        case .active, .unlocked: .active
        case .authorizationRevoked, .needsReselection, .unavailable: .attention
        case .needsAuthorization, .needsSelection, .off: .inactive
        }
    }

    /// Short title for the status (Today row, Protection header).
    var title: String {
        switch self {
        case .active: String(localized: "Protection is on")
        case .unlocked: String(localized: "Open for now")
        case .off: String(localized: "Protection is off")
        case .needsSelection: String(localized: "Choose apps to pause before")
        case .needsAuthorization: String(localized: "Not set up yet")
        case .authorizationRevoked: String(localized: "Protection is paused")
        case .needsReselection: String(localized: "Confirm your apps")
        case .unavailable: String(localized: "Not available on this device")
        }
    }
}

// MARK: - Rows

/// Label-and-value rows with the app's secondary ink for the value. iOS's default grey on
/// the vellum canvas is about 3.2:1, below WCAG AA; `plInkSecondary` passes (see
/// PaletteContrastTests). Stacks vertically when the row doesn't fit (large Dynamic Type).
struct PLLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                configuration.label
                Spacer(minLength: PLSpacing.s)
                configuration.content
                    .foregroundStyle(Color.plInkSecondary)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                configuration.label
                configuration.content
                    .foregroundStyle(Color.plInkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension LabeledContentStyle where Self == PLLabeledContentStyle {
    static var pl: PLLabeledContentStyle { PLLabeledContentStyle() }
}
