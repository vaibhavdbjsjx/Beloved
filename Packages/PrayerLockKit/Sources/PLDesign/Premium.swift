import SwiftUI

// MARK: - Section header

/// A section's eyebrow and serif title, with an optional trailing action ("See all").
public struct PLSectionHeader: View {
    let eyebrow: String?
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(_ title: String, eyebrow: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.eyebrow = eyebrow
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow { Text(eyebrow).plEyebrow() }
                Text(title)
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: PLSpacing.s)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.plCallout.weight(.medium))
                    .foregroundStyle(Color.plAccent)
            }
        }
    }
}

// MARK: - Icon badge

/// A symbol on a soft accent disc — the app's one icon treatment.
public struct PLIconBadge: View {
    let systemName: String
    let size: CGFloat
    let tint: Color
    let fill: Color

    public init(_ systemName: String, size: CGFloat = 44, tint: Color = .plAccent, fill: Color = .plAccentSoft) {
        self.systemName = systemName
        self.size = size
        self.tint = tint
        self.fill = fill
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .accessibilityHidden(true)
    }
}

// MARK: - Tool tile

/// A square-ish tile for a tool (mala, Qibla, rosary…). Two per row.
public struct PLToolTile: View {
    let title: String
    let subtitle: String?
    let systemName: String
    let action: () -> Void

    public init(_ title: String, subtitle: String? = nil, systemName: String, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemName = systemName
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: PLSpacing.s) {
                PLIconBadge(systemName, size: 40)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.plHeadline)
                        .foregroundStyle(Color.plInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity, alignment: .topLeading)
            .padding(PLSpacing.m)
            .background(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous).fill(Color.plSurface))
            .overlay(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}

/// Two-column grid for tool tiles (one column at accessibility text sizes, so words never
/// break mid-letter in a narrow tile). Not lazy: tiles re-measure when the text size changes.
public struct PLTileGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        PLColumnsLayout(columns: typeSize >= .xxLarge ? 1 : 2, spacing: PLSpacing.s) {
            content
        }
    }
}

/// Equal-width columns; each row as tall as its tallest cell, every cell stretched to it.
public struct PLColumnsLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    public init(columns: Int, spacing: CGFloat) {
        self.columns = max(columns, 1)
        self.spacing = spacing
    }

    private func cellWidth(_ width: CGFloat) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func rowHeights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        stride(from: 0, to: subviews.count, by: columns).map { start in
            subviews[start..<min(start + columns, subviews.count)]
                .map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
                .max() ?? 0
        }
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let heights = rowHeights(subviews, width: cellWidth(width))
        return CGSize(width: width, height: heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0)))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = cellWidth(bounds.width)
        let heights = rowHeights(subviews, width: width)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for column in 0..<columns {
                let index = row * columns + column
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(column) * (width + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: width, height: height))
            }
            y += height + spacing
        }
    }
}

// MARK: - List row

/// A tappable row: icon, title, detail, chevron. Lives inside `plPaper(padding: 0)`.
public struct PLListRow: View {
    let title: String
    let detail: String?
    let systemName: String?
    let trailing: String?
    let action: () -> Void

    public init(_ title: String, detail: String? = nil, systemName: String? = nil, trailing: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.systemName = systemName
        self.trailing = trailing
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PLSpacing.m) {
                if let systemName { PLIconBadge(systemName, size: 36) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.plHeadline)
                        .foregroundStyle(Color.plInk)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing {
                    Text(trailing)
                        .font(.plCaption.monospacedDigit())
                        .foregroundStyle(Color.plInkSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.plInkSecondary.opacity(0.7))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PLSpacing.m)
            .padding(.vertical, PLSpacing.s + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Hero

/// A jewel-toned card in the faith's colour with a soft halo — for the one thing that
/// matters most right now (a festival, the next prayer). Text on it is light.
public struct PLHeroCard<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .foregroundStyle(Color.plOnAccentFill)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(PLSpacing.l)
            .background {
                GeometryReader { proxy in
                    ZStack {
                        LinearGradient(
                            colors: [Color.plAccentFill, Color.plAccentFill.mix(with: .black, by: 0.35)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        PLHalo()
                            .frame(width: proxy.size.height * 1.6, height: proxy.size.height * 1.6)
                            .position(x: proxy.size.width * 0.92, y: proxy.size.height * 0.1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: PLRadius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PLRadius.panel, style: .continuous).strokeBorder(Color.plGilt.opacity(0.35), lineWidth: 1))
    }
}

/// Concentric gilt rings fading outward — the halo behind the dove, used as ornament.
public struct PLHalo: View {
    public init() {}

    public var body: some View {
        ZStack {
            RadialGradient(colors: [Color.plGilt.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 140)
            ForEach(1..<5, id: \.self) { ring in
                Circle()
                    .strokeBorder(Color.plGilt.opacity(0.28 - Double(ring) * 0.05), lineWidth: 1)
                    .scaleEffect(CGFloat(ring) / 4)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Light text styles for use on `PLHeroCard`.
public extension View {
    func plHeroEyebrow() -> some View {
        modifier(PLEyebrowText(color: Color.plOnAccentFill.opacity(0.85)))
    }
}
