import PLContent
import PLDesign
import PLFaith
import SwiftUI

/// "Who will you pray to today?" — for faiths with many forms of the divine (Hinduism). Once
/// chosen, Today shows that deity's verified mantra, and the moment and the companion follow it.
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
            .animation(.default, value: model.todaysFocus)
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
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "Today with \(focus.name.resolved(for: languages))")).plEyebrow()
            Spacer()
            Button("Change") { choosing = true }
                .buttonStyle(.plQuiet(.plAccent))
                .accessibilityIdentifier("today.deity.change")
        }
        if let item = model.itemsForTodaysFocus().first {
            Text(item.title.resolved(for: languages))
                .font(.plTitle)
                .foregroundStyle(Color.plInk)
            ForEach(Array(item.segments.filter { $0.role != .explanation }.enumerated()), id: \.offset) { _, segment in
                ContentSegmentView(
                    segment: segment,
                    languages: languages,
                    showOriginal: true,
                    showTransliteration: model.profile.showTransliteration,
                    editionTitle: model.editionTitle(for: segment)
                )
            }
            if let note = item.segments.first(where: { $0.role == .explanation })?.text?.resolved(for: languages) {
                Text(note)
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text("Sit with \(focus.name.resolved(for: languages)) in silence for a few breaths — or ask the Companion for a prayer.")
                .font(.plCallout)
                .foregroundStyle(Color.plInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Button {
            model.startMoment()
        } label: {
            Label(String(localized: "Pray now"), systemImage: "sparkles")
        }
        .buttonStyle(.plSecondary)
        .accessibilityIdentifier("today.deity.pray")
    }
}
