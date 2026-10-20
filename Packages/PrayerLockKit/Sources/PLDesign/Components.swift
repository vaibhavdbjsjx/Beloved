import PLContent
import PLFaith
import SwiftUI

// MARK: - Buttons

/// The one primary action on a screen: lapis, full width, 54pt tall. Disabled is a clear
/// resting state (paper with secondary ink) rather than a washed-out lapis.
public struct PLPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration)
    }

    private struct PrimaryBody: View {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.plHeadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, PLSpacing.m)
                .padding(.vertical, PLSpacing.xxs)
                .foregroundStyle(isEnabled ? Color.plOnAccentFill : Color.plInkSecondary)
                .background(
                    RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                        .fill(isEnabled ? Color.plAccentFill : Color.plSurfaceRaised)
                )
                .contentShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .brightness(configuration.isPressed ? -0.04 : 0)
                .animation(PLMotion.press, value: configuration.isPressed)
        }
    }
}

/// A secondary action: paper with a hairline, ink text.
public struct PLSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        SecondaryBody(configuration: configuration)
    }

    private struct SecondaryBody: View {
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.plHeadline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, PLSpacing.m)
                .padding(.vertical, PLSpacing.xxs)
                .foregroundStyle(isEnabled ? Color.plInk : Color.plInkSecondary)
                .background(
                    RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                        .fill(configuration.isPressed ? Color.plSurfaceRaised : Color.plSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous)
                        .strokeBorder(Color.plLine, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
                .animation(PLMotion.press, value: configuration.isPressed)
        }
    }
}

/// A quiet text action ("Not now", "Skip", "Change"). At least 44pt tall.
public struct PLQuietButtonStyle: ButtonStyle {
    let color: Color

    public init(color: Color = .plAccent) { self.color = color }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plHeadline.weight(.medium))
            .foregroundStyle(color)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(PLMotion.press, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PLPrimaryButtonStyle {
    static var plPrimary: PLPrimaryButtonStyle { PLPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == PLSecondaryButtonStyle {
    static var plSecondary: PLSecondaryButtonStyle { PLSecondaryButtonStyle() }
}

public extension ButtonStyle where Self == PLQuietButtonStyle {
    static var plQuiet: PLQuietButtonStyle { PLQuietButtonStyle() }
    static func plQuiet(_ color: Color) -> PLQuietButtonStyle { PLQuietButtonStyle(color: color) }
}

// MARK: - Surfaces

/// Paper: a surface a shade lighter than the page, edged with a hairline. No shadows —
/// depth comes from tone, the way printed matter has it.
public struct PLPaper: ViewModifier {
    let radius: CGFloat
    let padding: CGFloat?
    let fill: Color

    public init(radius: CGFloat = PLRadius.panel, padding: CGFloat? = PLSpacing.l, fill: Color = .plSurface) {
        self.radius = radius
        self.padding = padding
        self.fill = fill
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
    }
}

public extension View {
    func plPaper(radius: CGFloat = PLRadius.panel, padding: CGFloat? = PLSpacing.l, fill: Color = .plSurface) -> some View {
        modifier(PLPaper(radius: radius, padding: padding, fill: fill))
    }
}

/// A hairline rule.
public struct PLHairline: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(Color.plLine)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// A small ornament between passages: hairline · gilt diamond · hairline.
public struct PLOrnament: View {
    public init() {}

    public var body: some View {
        HStack(spacing: PLSpacing.s) {
            Rectangle().fill(Color.plLine).frame(width: 28, height: 1)
            Rectangle()
                .fill(Color.plGilt)
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
            Rectangle().fill(Color.plLine).frame(width: 28, height: 1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Selection

/// A selectable card for single or multiple choice (faith, tradition, focus). Serif title,
/// optional detail, and a mark that changes shape as well as colour when selected.
public struct PLChoiceCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    public init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: PLSpacing.m) {
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    Text(title)
                        .font(.plTitleSmall)
                        .foregroundStyle(Color.plInk)
                    if let subtitle {
                        Text(subtitle)
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PLSelectionMark(isSelected: isSelected)
            }
            .padding(.horizontal, PLSpacing.l)
            .padding(.vertical, PLSpacing.m + 2)
            .background(
                RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous)
                    .fill(isSelected ? Color.plAccentSoft : Color.plSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous)
                    .strokeBorder(isSelected ? Color.plAccent : Color.plLine, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: PLRadius.control + 4, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .animation(PLMotion.animation(PLMotion.standard, reduceMotion: reduceMotion), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Selected: a filled lapis disc with a check. Unselected: an empty hairline ring.
public struct PLSelectionMark: View {
    let isSelected: Bool

    public init(isSelected: Bool) { self.isSelected = isSelected }

    public var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.clear : Color.plLine, lineWidth: 1.5)
            if isSelected {
                Circle().fill(Color.plAccentFill)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.plOnAccentFill)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityHidden(true)
    }
}

/// Gentle press feedback for custom tappable surfaces.
public struct PressableStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration)
    }

    private struct PressableBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
                .opacity(configuration.isPressed ? 0.92 : 1)
                .animation(PLMotion.press, value: configuration.isPressed)
        }
    }
}

/// A compact option (durations, filters). Selected options are filled lapis *and* bold,
/// so the state never relies on colour alone.
public struct PLChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? .plCallout.weight(.semibold) : .plCallout)
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
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Layout

/// Lays children out in lines, wrapping like text (moods, chips, themes).
public struct PLFlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    public init(spacing: CGFloat = PLSpacing.xs, lineSpacing: CGFloat = PLSpacing.xs) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * lineSpacing
        let usedWidth = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? usedWidth, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Status

/// How the protection is doing, as a mark *and* words (never colour alone).
public enum PLStatusTone: Sendable {
    case active
    case attention
    case inactive
}

public struct PLStatusMark: View {
    let tone: PLStatusTone

    public init(_ tone: PLStatusTone) { self.tone = tone }

    public var body: some View {
        ZStack {
            switch tone {
            case .active:
                Circle().fill(Color.plSage)
            case .attention:
                Circle().strokeBorder(Color.plCaution, lineWidth: 1.5)
                Circle().fill(Color.plCaution).frame(width: 4, height: 4)
            case .inactive:
                Circle().strokeBorder(Color.plInkSecondary.opacity(0.7), lineWidth: 1.5)
            }
        }
        .frame(width: 13, height: 13)
        .accessibilityHidden(true)
    }
}

// MARK: - Content

/// States what a piece of text *is* (scripture, traditional, editorial prayer,
/// AI-generated, explanation…). Shown on every content segment — this is how users
/// can always tell verified sources from generated or editorial text.
public struct ProvenanceLabel: View {
    let segment: ContentSegment
    let editionTitle: String?

    public init(segment: ContentSegment, editionTitle: String? = nil) {
        self.segment = segment
        self.editionTitle = editionTitle
    }

    public var body: some View {
        Text(text)
            .plEyebrow(segment.role == .generatedPrayer ? .plCaution : .plGilt)
            .accessibilityLabel(text)
    }

    var text: String {
        var parts = [Self.title(for: segment.role)]
        if let reference = segment.citation?.reference { parts.append(reference) }
        if let editionTitle { parts.append(editionTitle) }
        if segment.role == .composedPrayer, let author = segment.author { parts.append(author) }
        return parts.joined(separator: " · ")
    }

    public static func title(for role: SegmentRole) -> String {
        switch role {
        case .sourceText: String(localized: "Scripture", bundle: .module)
        case .traditionalText: String(localized: "Traditional", bundle: .module)
        case .paraphrase: String(localized: "Paraphrase", bundle: .module)
        case .composedPrayer: String(localized: "Prayer", bundle: .module)
        case .generatedPrayer: String(localized: "AI-generated prayer", bundle: .module)
        case .explanation: String(localized: "Meaning", bundle: .module)
        case .devotionalInterpretation: String(localized: "Reflection", bundle: .module)
        }
    }
}

/// Marks content that has not passed editorial review. Only visible in development
/// builds (release policy never shows unreviewed content).
public struct ReviewBadge: View {
    let status: ReviewInfo.Status

    public init(status: ReviewInfo.Status) { self.status = status }

    public var body: some View {
        // Hidden when photographing App Store screenshots (development builds only show it).
        if status != .approved && !ProcessInfo.processInfo.arguments.contains("-PLStoreScreenshots") {
            Label(String(localized: "Unreviewed draft", bundle: .module), systemImage: "exclamationmark.triangle")
                .font(.plLabel)
                .foregroundStyle(Color.plCaution)
                .padding(.horizontal, PLSpacing.xs)
                .padding(.vertical, PLSpacing.xxs)
                .background(Color.plSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.plCaution.opacity(0.5), lineWidth: 1))
        }
    }
}

/// Renders one content segment: provenance, original script, transliteration, text —
/// typeset for reading, with the explanation set apart in the interface voice.
public struct ContentSegmentView: View {
    let segment: ContentSegment
    let languages: [String]
    let showOriginal: Bool
    let showTransliteration: Bool
    let editionTitle: String?

    public init(
        segment: ContentSegment,
        languages: [String],
        showOriginal: Bool = true,
        showTransliteration: Bool = true,
        editionTitle: String? = nil
    ) {
        self.segment = segment
        self.languages = languages
        self.showOriginal = showOriginal
        self.showTransliteration = showTransliteration
        self.editionTitle = editionTitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            ProvenanceLabel(segment: segment, editionTitle: editionTitle)
            if showOriginal, let original = segment.original {
                Text(original.text)
                    .font(.plOriginalScript)
                    .lineSpacing(10)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    // The direction must wrap the frame too, so "leading" is the right edge for RTL.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, Self.isRightToLeft(original.language) ? .rightToLeft : .leftToRight)
            }
            if showTransliteration, let transliteration = segment.transliteration {
                Text(transliteration)
                    .font(.plTransliteration)
                    .lineSpacing(4)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let text = segment.text?.resolved(for: languages), !text.isEmpty {
                if segment.role == .explanation {
                    Text(text)
                        .font(.plCallout)
                        .lineSpacing(4)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(text).plReading()
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func isRightToLeft(_ language: String) -> Bool {
        ["ar", "he", "hbo", "fa", "ur"].contains(Locale.Language(identifier: language).languageCode?.identifier ?? language)
    }
}
