import PLContent
import PLDesign
import PLFaith
import SwiftUI

/// "Who will you pray to today?" — for faiths with many forms of the divine (Hinduism). Once
/// chosen, Today lists that deity's verified mantras and stotras, filterable by purpose (study,
/// prosperity, health, protection…), each opening in full with a japa counter.
struct DailyFocusCard: View {
    @Environment(AppModel.self) private var model
    @State private var choosing = false

    var body: some View {
        let choices = model.dailyFocusChoices
        if !choices.isEmpty {
            VStack(alignment: .leading, spacing: PLSpacing.m) {
                if let focusID = model.todaysFocus, !choosing,
                   let focus = choices.first(where: { $0.id == focusID }) {
                    chosen(focus)
                } else {
                    picker(choices)
                }
            }
            .plPaper()
        }
    }

    private func picker(_ choices: [SpiritualFocus]) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                Text("Today").plEyebrow()
                Text("Who will you pray to today?")
                    .font(.plTitle)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: PLSpacing.xs, alignment: .top), count: 4), spacing: PLSpacing.m) {
                ForEach(choices) { focus in
                    Button {
                        withAnimation(.snappy) {
                            model.chooseFocusForToday(focus.id)
                            choosing = false
                        }
                    } label: {
                        DeityMedallion(name: focus.name.resolved(for: model.profile.languages), focusID: focus.id.rawValue, isSelected: model.todaysFocus == focus.id)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("today.deity.\(focus.id.rawValue)")
                }
            }
        }
    }

    @ViewBuilder
    private func chosen(_ focus: SpiritualFocus) -> some View {
        let languages = model.profile.languages
        let items = model.itemsForTodaysFocus()
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text("Today").plEyebrow()
                Text(focus.name.resolved(for: languages))
                    .font(.plTitle)
                    .foregroundStyle(Color.plInk)
                    .accessibilityIdentifier("today.deity.name")
            }
            Spacer()
            Button("Change") { choosing = true }
                .buttonStyle(.plQuiet(.plAccent))
                .accessibilityIdentifier("today.deity.change")
        }
        if items.isEmpty {
            Text("Sit with \(focus.name.resolved(for: languages)) in silence for a few breaths — or ask the Companion.")
                .font(.plCallout)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            PurposeFilteredPrayers(items: items, limit: 4)
        }
    }

    /// Purposes that actually occur in this deity's items, most common first.
    static func purposes(of items: [ContentItem]) -> [ThemeID] {
        var counts: [ThemeID: Int] = [:]
        for item in items { for theme in item.themes { counts[theme, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.map(\.key)
    }
}

/// A deity as a gilt medallion with its name beneath — the "who will you pray to" choice.
struct DeityMedallion: View {
    let name: String
    var focusID: String = ""
    var isSelected = false

    /// The deity's name begins in its own script: ॐ for the formless Divine, Tamil for Murugan.
    static let glyphs: [String: String] = [
        "hinduism.ishvara": "ॐ", "hinduism.shiva": "शि", "hinduism.vishnu": "वि", "hinduism.venkateswara": "वें",
        "hinduism.krishna": "कृ", "hinduism.rama": "रा", "hinduism.ganesha": "ग", "hinduism.hanuman": "ह",
        "hinduism.devi": "दे", "hinduism.durga": "दु", "hinduism.lakshmi": "ल", "hinduism.saraswati": "स",
        "hinduism.kartikeya": "மு", "hinduism.surya": "सू", "hinduism.navagraha": "ग्र",
    ]

    /// "Venkateswara (Balaji)" → "Venkateswara"; "The Divine (no specific form)" → "The Divine".
    private var shortName: String {
        let main = name.components(separatedBy: " (").first ?? name
        // "Venkateswara (Balaji)" is too long for a medallion: use the familiar short name.
        if main.count > 10, let open = name.firstIndex(of: "("), let close = name.firstIndex(of: ")"), open < close {
            return String(name[name.index(after: open)..<close])
        }
        return main
    }

    var body: some View {
        VStack(spacing: PLSpacing.xs) {
            Text(Self.glyphs[focusID] ?? String(shortName.replacingOccurrences(of: "The ", with: "").prefix(1)))
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(isSelected ? Color.plOnAccentFill : Color.plAccent)
                .frame(width: 50, height: 50)
                .background(
                    Circle().fill(isSelected
                        ? AnyShapeStyle(LinearGradient(colors: [Color.plAccentFill, Color.plGilt], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.plAccentSoft))
                )
                .overlay(Circle().strokeBorder(Color.plGilt.opacity(isSelected ? 0 : 0.35), lineWidth: 1))
            Text(shortName)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.plInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
    }
}

/// A list of prayers or mantras with purpose chips (study, health, prosperity…); each opens in
/// full. `limit` shows only the first few with a "See all" link.
struct PurposeFilteredPrayers: View {
    @Environment(AppModel.self) private var model
    let items: [ContentItem]
    var limit: Int?
    @State private var purpose: ThemeID?
    @State private var opened: ContentItem?
    @State private var showingAll = false

    var body: some View {
        let purposes = DailyFocusCard.purposes(of: items)
        let filtered = items.filter { purpose == nil || $0.themes.contains(purpose!) }
        let shown = limit.map { Array(filtered.prefix($0)) } ?? filtered
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            if purposes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PLSpacing.xs) {
                        PLChip(String(localized: "All"), isSelected: purpose == nil) { purpose = nil }
                        ForEach(purposes, id: \.self) { theme in
                            PLChip(model.themeName(theme), isSelected: purpose == theme) { purpose = theme }
                                .accessibilityIdentifier("today.purpose.\(theme.rawValue)")
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { PLHairline() }
                    Button {
                        if model.isPremiumOnly(item) {
                            model.withPremium(String(localized: "The complete library")) { opened = item }
                        } else {
                            opened = item
                        }
                    } label: { MantraRow(item: item) }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("today.mantra.\(item.id.rawValue)")
                }
            }
            if let limit, filtered.count > limit {
                Button {
                    showingAll = true
                } label: {
                    Text(String(localized: "See all \(filtered.count)"))
                        .font(.plCallout.weight(.medium))
                        .foregroundStyle(Color.plAccent)
                }
                .accessibilityIdentifier("prayers.seeAll")
            }
        }
        .sheet(item: $opened) { item in
            MantraDetailView(item: item)
                .environment(model)
        }
        .sheet(isPresented: $showingAll) {
            NavigationStack {
                ScrollView {
                    PurposeFilteredPrayers(items: items)
                        .padding(PLSpacing.page)
                }
                .background(Color.plCanvas)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingAll = false } } }
            }
            .presentsPaywall()
            .environment(model)
            .presentationBackground(Color.plCanvas)
        }
    }
}

/// One mantra in a list: title, its opening words, and what it is traditionally for.
struct MantraRow: View {
    @Environment(AppModel.self) private var model
    let item: ContentItem

    var body: some View {
        HStack(alignment: .center, spacing: PLSpacing.m) {
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text(item.title.resolved(for: model.profile.languages))
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                if let opening = item.segments.first?.original?.text.split(separator: "\n").first {
                    Text(String(opening))
                        .font(.callout)
                        .foregroundStyle(Color.plInkSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: PLSpacing.xs) {
                    Text(item.themes.prefix(3).map { model.themeName($0) }.joined(separator: " · "))
                        .font(.plCaption)
                        .foregroundStyle(Color.plGilt)
                    if model.isPremiumOnly(item) && !model.hasPremiumAccess {
                        Label("Premium", systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.plAccent)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.plInkSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, PLSpacing.s)
        .contentShape(Rectangle())
    }
}

/// A mantra or stotra in full, with where it comes from and a japa counter.
struct MantraDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let item: ContentItem
    @State private var counting = false

    /// Repetition suits mantras and dhikr; a long stotra or a Christian prayer is read, not counted.
    private var counter: (label: String, target: Int, targets: [Int])? {
        switch item.faith?.rawValue {
        case "hinduism": (String(localized: "Chant with a mala (108)"), 108, [108, 54, 27, 11])
        case "islam": (String(localized: "Count with a tasbih"), 33, [33, 99, 100, 11])
        default: nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    Text(item.title.resolved(for: model.profile.languages))
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.env.configuration.isDevelopment { ReviewBadge(status: item.review.status) }
                    ForEach(Array(item.segments.enumerated()), id: \.offset) { _, segment in
                        ContentSegmentView(
                            segment: segment,
                            languages: model.profile.languages,
                            showOriginal: true,
                            showTransliteration: model.profile.showTransliteration,
                            editionTitle: model.editionTitle(for: segment)
                        )
                    }
                }
                .padding(PLSpacing.page)
            }
            .background(Color.plCanvas)
            .safeAreaInset(edge: .bottom) {
                if let counter {
                    Button {
                        counting = true
                    } label: {
                        Label(counter.label, systemImage: "circle.dotted")
                    }
                    .buttonStyle(.plPrimary)
                    .padding(PLSpacing.page)
                    .background(Color.plCanvas)
                    .accessibilityIdentifier("mantra.count")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("mantra.done") }
            }
            .fullScreenCover(isPresented: $counting) {
                PrayerCounterView(title: item.title.resolved(for: model.profile.languages), target: counter?.target ?? 108, targets: counter?.targets)
            }
        }
        .presentationBackground(Color.plCanvas)
    }
}
