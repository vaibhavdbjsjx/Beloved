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
    @State private var purpose: ThemeID?
    @State private var opened: ContentItem?

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
            .sheet(item: $opened) { item in
                MantraDetailView(item: item)
                    .environment(model)
            }
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
            PLFlowLayout {
                ForEach(choices) { focus in
                    PLChip(focus.name.resolved(for: model.profile.languages), isSelected: model.todaysFocus == focus.id) {
                        model.chooseFocusForToday(focus.id)
                        purpose = nil
                        choosing = false
                    }
                    .accessibilityIdentifier("today.deity.\(focus.id.rawValue)")
                }
            }
        }
    }

    @ViewBuilder
    private func chosen(_ focus: SpiritualFocus) -> some View {
        let languages = model.profile.languages
        let items = model.itemsForTodaysFocus()
        let purposes = Self.purposes(of: items)
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
                let shown = items.filter { purpose == nil || $0.themes.contains(purpose!) }
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { PLHairline() }
                    Button { opened = item } label: { MantraRow(item: item) }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("today.mantra.\(item.id.rawValue)")
                }
            }
        }
    }

    /// Purposes that actually occur in this deity's items, most common first.
    static func purposes(of items: [ContentItem]) -> [ThemeID] {
        var counts: [ThemeID: Int] = [:]
        for item in items { for theme in item.themes { counts[theme, default: 0] += 1 } }
        return counts.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.map(\.key)
    }
}

/// One mantra in a list: title, its opening words, and what it is traditionally for.
private struct MantraRow: View {
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
                Text(item.themes.prefix(3).map { model.themeName($0) }.joined(separator: " · "))
                    .font(.plCaption)
                    .foregroundStyle(Color.plGilt)
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
                Button {
                    counting = true
                } label: {
                    Label(String(localized: "Chant with a mala (108)"), systemImage: "circle.dotted")
                }
                .buttonStyle(.plPrimary)
                .padding(PLSpacing.page)
                .background(Color.plCanvas)
                .accessibilityIdentifier("mantra.count")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("mantra.done") }
            }
            .fullScreenCover(isPresented: $counting) {
                PrayerCounterView(title: item.title.resolved(for: model.profile.languages), target: 108)
            }
        }
        .presentationBackground(Color.plCanvas)
    }
}
