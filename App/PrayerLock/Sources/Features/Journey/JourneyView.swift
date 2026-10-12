import PLContent
import PLCore
import PLDesign
import PLHabits
import SwiftUI

/// A quiet record, framed gently: consistency over perfection. No streaks, no badges
/// designed to compel — a missed day is simply a day.
struct JourneyView: View {
    @Environment(AppModel.self) private var model

    /// Opened from Today ("Your journey"), inside Today's navigation stack.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                if let summary = model.habitSummary, summary.totalCompletedSessions > 0 {
                    overview(summary).plStaggered(0)
                    figures(summary).plStaggered(1)
                    if !summary.topThemes.isEmpty { themes(summary).plStaggered(2) }
                    recent.plStaggered(3)
                } else {
                    empty
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PLSpacing.page)
            .padding(.top, PLSpacing.s)
            .padding(.bottom, PLSpacing.xxxl)
        }
        .background(Color.plCanvas)
        .navigationTitle("Journey")
        .task { await model.refreshHabits() }
    }

    // MARK: - Week

    private func overview(_ summary: HabitSummary) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.l) {
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                Text("This week").plEyebrow()
                Text(summary.daysPracticedLast7 == 1
                     ? String(localized: "You paused on 1 of the last 7 days.")
                     : String(localized: "You paused on \(summary.daysPracticedLast7) of the last 7 days."))
                    .font(.plTitle)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every pause counts. A missed day is simply a day.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: PLSpacing.xs) {
                ForEach(summary.lastSevenDays, id: \.date) { day in
                    DayMark(
                        letter: weekdayLetter(day.date),
                        practiced: day.completedSessions > 0,
                        isToday: day.date == model.today,
                        accessibilityDay: day.date.startDate(in: model.env.calendar).formatted(.dateTime.weekday(.wide))
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .plPaper(padding: PLSpacing.m)
        }
    }

    // MARK: - Figures

    private func figures(_ summary: HabitSummary) -> some View {
        HStack(alignment: .top, spacing: 0) {
            figure(value: "\(summary.totalCompletedSessions)", label: String(localized: "Moments"))
            Rectangle().fill(Color.plLine).frame(width: 1).accessibilityHidden(true)
            figure(value: Duration.seconds(summary.totalTimeInPrayer)
                .formatted(.units(allowed: Self.timeUnits(for: summary.totalTimeInPrayer), width: .narrow)),
                   label: model.profile.faithID == nil ? String(localized: "In stillness") : String(localized: "In prayer"))
            Rectangle().fill(Color.plLine).frame(width: 1).accessibilityHidden(true)
            figure(value: "\(summary.shieldMomentsCompleted)", label: String(localized: "Before an app"))
        }
        .fixedSize(horizontal: false, vertical: true)
        .plPaper(padding: PLSpacing.m)
    }

    private func figure(value: String, label: String) -> some View {
        VStack(spacing: PLSpacing.xxs) {
            Text(value)
                .font(.plNumeral)
                .foregroundStyle(Color.plInk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .plEyebrow(.plInkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PLSpacing.s)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Themes and recent

    private func themes(_ summary: HabitSummary) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(String(localized: "What you've prayed about"))
            PLFlowLayout {
                ForEach(summary.topThemes, id: \.self) { theme in
                    Text(model.themeName(theme))
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(Color.plInk)
                        .padding(.horizontal, PLSpacing.s)
                        .padding(.vertical, PLSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PLRadius.chip, style: .continuous)
                                .fill(Color.plAccentSoft)
                        )
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            SectionHeading(String(localized: "Recent moments"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.recentSessions.prefix(10).enumerated()), id: \.element.id) { index, session in
                    if index > 0 { PLHairline().padding(.leading, PLSpacing.xxxl) }
                    if let item = revisitable(session) {
                        NavigationLink {
                            RevisitView(item: item, endedAt: session.endedAt)
                        } label: {
                            recentRow(session, title: item.title.resolved(for: model.profile.languages), showsChevron: true)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityHint(Text("Opens the passage again"))
                    } else {
                        recentRow(session, title: String(localized: "A quiet pause"), showsChevron: false)
                    }
                }
            }
            .plPaper(padding: 0)
        }
    }

    /// The passage behind a past moment, if it can still be shown under this build's content
    /// policy (a passage withdrawn from review is never resurfaced).
    private func revisitable(_ session: PrayerSession) -> ContentItem? {
        guard let id = session.contentItemID, let item = model.env.catalog.item(id),
              model.env.contentPolicy.permits(item, registry: model.env.registry) else { return nil }
        return item
    }

    private func recentRow(_ session: PrayerSession, title: String, showsChevron: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: PLSpacing.m) {
            Image(systemName: session.trigger == .shield ? "shield.lefthalf.filled" : "sun.horizon")
                .font(.callout)
                .foregroundStyle(Color.plGilt)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                Text(session.endedAt.formatted(.relative(presentation: .named)))
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.plInkSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, PLSpacing.l)
        .padding(.vertical, PLSpacing.m)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Empty

    private var empty: some View {
        VStack(spacing: PLSpacing.l) {
            ThresholdWindow(width: 120, light: PLLight.current(calendar: model.env.calendar), presence: .still)
                .padding(.top, PLSpacing.xl)
            VStack(spacing: PLSpacing.s) {
                Text("Your journey begins with a single pause")
                    .font(.plTitle)
                    .foregroundStyle(Color.plInk)
                Text("Completed moments will appear here — gently, without streaks. Everything stays on this iPhone.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Button("Begin a moment") { model.startMoment() }
                .buttonStyle(.plPrimary)
                .accessibilityIdentifier("journey.beginMoment")
        }
        .frame(maxWidth: .infinity)
    }

    /// Seconds for under a minute ("34s", not "0m"); hours and minutes after that.
    private static func timeUnits(for seconds: TimeInterval) -> Set<Duration.UnitsFormatStyle.Unit> {
        seconds < 60 ? [.seconds] : [.hours, .minutes]
    }

    private func weekdayLetter(_ date: CivilDate) -> String {
        date.startDate(in: model.env.calendar).formatted(.dateTime.weekday(.narrow))
    }
}

/// One day of the week: a bead — the shared counting form of rosary, tasbih and mala —
/// filled with gilt when the user paused that day, an empty ring when they didn't. Shape *and* fill change, so it never relies on colour.
private struct DayMark: View {
    let letter: String
    let practiced: Bool
    let isToday: Bool
    let accessibilityDay: String

    var body: some View {
        VStack(spacing: PLSpacing.xs) {
            ZStack {
                if practiced {
                    Circle().fill(Color.plGilt)
                } else {
                    Circle().strokeBorder(Color.plLine, lineWidth: 1.5)
                }
            }
            .frame(width: 24, height: 24)
            Text(letter)
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.plInk : Color.plInkSecondary)
            Circle()
                .fill(isToday ? Color.plAccent : Color.clear)
                .frame(width: 4, height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(accessibilityDay): \(practiced ? String(localized: "paused") : String(localized: "no moment"))\(isToday ? String(localized: ", today") : "")"))
    }
}

/// A past moment's passage, set exactly as it was in the moment — for returning to words
/// that helped. Read-only; nothing is recorded by opening it.
struct RevisitView: View {
    @Environment(AppModel.self) private var model
    let item: ContentItem
    let endedAt: Date

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.xl) {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    Text(endedAt.formatted(.dateTime.weekday(.wide).day().month(.wide))).plEyebrow()
                    Text(item.title.resolved(for: model.profile.languages))
                        .font(.plDisplay)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if model.env.configuration.isDevelopment {
                        ReviewBadge(status: item.review.status)
                    }
                }
                PLOrnament()
                ForEach(Array(item.segments.enumerated()), id: \.offset) { _, segment in
                    ContentSegmentView(
                        segment: segment,
                        languages: model.profile.languages,
                        showOriginal: model.profile.showOriginalScript,
                        showTransliteration: model.profile.showTransliteration,
                        editionTitle: model.editionTitle(for: segment)
                    )
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PLSpacing.page)
            .padding(.vertical, PLSpacing.l)
        }
        .background(Color.plCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("journey.revisit")
    }
}
