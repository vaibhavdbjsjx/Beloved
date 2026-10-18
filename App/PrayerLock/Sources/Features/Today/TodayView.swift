import PLCalendar
import PLContent
import PLDesign
import PLFaith
import PLProtection
import SwiftUI

/// Today: the hour's light, a greeting, today's moment, and one quiet ledger of what
/// matters (your intention, how you're arriving, protection). Deliberately not a dashboard:
/// the only prominent action is the moment itself.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showingMood = false
    @State private var showingIntentions = false
    @State private var showingJourney = false
    @State private var showingCounter = false
    @State private var showingJournal = false
    @State private var showingRosary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.xl) {
                    header
                        .plStaggered(0)
                    if model.isReturningAfterBreak {
                        welcomeBack
                            .plStaggered(1)
                    }
                    DailyFocusCard()
                        .plStaggered(1)
                    if model.profile.faithID?.rawValue == "islam" {
                        SalahCard()
                            .plStaggered(1)
                    }
                    momentCard
                        .plStaggered(1)
                    if let verse = model.dailyVerse {
                        DailyVerseCard(verse: verse)
                            .plStaggered(2)
                    }
                    observances
                        .plStaggered(2)
                    ledger
                        .plStaggered(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PLSpacing.page)
                .padding(.top, PLSpacing.m)
                .padding(.bottom, PLSpacing.xxxl)
            }
            .plScrollEdgeFade()
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    Color.plCanvas
                    PLLightWash(light: PLLight.current(calendar: model.env.calendar))
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingMood) {
                MoodSheet()
            }
            .sheet(isPresented: $showingIntentions) {
                IntentionsSheet()
            }
            .fullScreenCover(isPresented: $showingRosary) {
                RosaryView()
            }
            .sheet(isPresented: $showingJournal) {
                PrayerJournalView()
            }
            .fullScreenCover(isPresented: $showingCounter) {
                PrayerCounterView(title: counter.title, target: counter.targets[0], targets: counter.targets)
            }
            .navigationDestination(isPresented: $showingJourney) {
                JourneyView()
            }
            .task {
                await model.refreshHabits()
                await model.refreshDailyVerse()
                await model.salah.refreshReminders()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: PLSpacing.m) {
            VStack(alignment: .leading, spacing: PLSpacing.s) {
                Text(dateLine)
                    .plEyebrow()
                    .accessibilityIdentifier("today.date")
                Text(Greeting.text(name: model.profile.displayName, date: .now, calendar: model.env.calendar))
                    .plHero()
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, PLSpacing.l)
    }

    /// The date — with the Hijri date for Muslims (Umm al-Qura calendar; local moon sighting
    /// can differ by a day).
    private var dateLine: String {
        let gregorian = Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard model.profile.faithID?.rawValue == "islam" else { return gregorian }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).day().month(.wide).year()
        style.calendar = Calendar(identifier: .islamicUmmAlQura)
        return "\(gregorian) · \(Date.now.formatted(style))"
    }

    private var welcomeBack: some View {
        HStack(alignment: .top, spacing: PLSpacing.m) {
            Rectangle()
                .fill(Color.plGilt)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                Text("Welcome back.")
                    .font(.plTitleSmall)
                    .foregroundStyle(Color.plInk)
                Text("There's nothing to catch up on — just this moment.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Today's moment

    private var momentCard: some View {
        let item = model.selectContent()?.item
        return VStack(alignment: .leading, spacing: PLSpacing.l) {
            HStack(alignment: .top, spacing: PLSpacing.m) {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    Text(eyebrow(for: item)).plEyebrow()
                    Text(item?.title.resolved(for: model.profile.languages) ?? String(localized: "A quiet pause"))
                        .font(.plTitle)
                        .foregroundStyle(Color.plInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(preview(for: item))
                        .font(.system(.callout, design: .serif))
                        .lineSpacing(4)
                        .foregroundStyle(Color.plInkSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("today.preview")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ThresholdWindow(width: 56, light: PLLight.current(calendar: model.env.calendar), presence: .still)
                    .padding(.top, PLSpacing.xxs)
            }
            VStack(spacing: PLSpacing.s) {
                Button("Begin a moment") { model.startMoment() }
                    .buttonStyle(.plPrimary)
                    .accessibilityIdentifier("today.beginMoment")
                Text(model.profile.contentLength.durationHint)
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
            }
        }
        .plPaper()
    }

    private func eyebrow(for item: ContentItem?) -> String {
        guard let segment = item?.segments.first(where: { $0.role != .explanation }) else {
            return String(localized: "Today's moment")
        }
        return String(localized: "Today's moment · \(ProvenanceLabel.title(for: segment.role))")
    }

    private func preview(for item: ContentItem?) -> String {
        let segment = item?.segments.first { $0.role != .explanation }
        let text = segment?.text?.resolved(for: model.profile.languages) ?? segment?.transliteration ?? segment?.original?.text
        return text ?? String(localized: "Sit with your breath for a few moments. No words are needed.")
    }

    // MARK: - Calendar

    @ViewBuilder
    private var observances: some View {
        let all = model.todaysObservances()
        let ordered = all.filter { $0.definition.kind != .weekly } + all.filter { $0.definition.kind == .weekly }
        let customs = model.todaysAssociations()
        if !ordered.isEmpty || !customs.isEmpty {
            VStack(alignment: .leading, spacing: PLSpacing.s) {
                SectionHeading(String(localized: "In the calendar"))
                ForEach(ordered) { observance in
                    VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: PLSpacing.xs) {
                            Text(observance.definition.name.resolved(for: model.profile.languages))
                                .font(.plTitleSmall)
                                .foregroundStyle(Color.plInk)
                            if observance.isEstimated {
                                Text("Expected")
                                    .plEyebrow(.plInkSecondary)
                            }
                        }
                        if let note = observance.definition.note?.resolved(for: model.profile.languages) {
                            Text(note)
                                .font(.plCallout)
                                .foregroundStyle(Color.plInkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                ForEach(customs) { custom in
                    Text(custom.explanation.resolved(for: model.profile.languages))
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Ledger

    private var ledger: some View {
        VStack(spacing: 0) {
            LedgerRow(
                label: String(localized: "Your intention"),
                systemImage: "sparkle",
                value: todaysIntention.map { "“\($0)”" } ?? String(localized: "Add a few words a pause can remind you of"),
                isPlaceholder: todaysIntention == nil,
                isQuote: todaysIntention != nil
            ) { showingIntentions = true }
            .accessibilityIdentifier("today.intention")
            PLHairline().padding(.leading, PLSpacing.xxxl)
            LedgerRow(
                label: String(localized: "How you're arriving"),
                systemImage: "wind",
                value: model.todayMood?.title ?? String(localized: "Optional — helps choose fitting words"),
                isPlaceholder: model.todayMood == nil
            ) { showingMood = true }
            .accessibilityIdentifier("today.mood")
            PLHairline().padding(.leading, PLSpacing.xxxl)
            if offersRosary {
                LedgerRow(
                    label: String(localized: "Rosary"),
                    systemImage: "circle.dotted",
                    value: String(localized: "Pray the rosary"),
                    detail: String(localized: "Today: \(RosaryMysteries.forDay(.now).name)")
                ) { showingRosary = true }
                .accessibilityIdentifier("today.rosary")
            } else {
                LedgerRow(
                    label: counter.label,
                    systemImage: "circle.dotted",
                    value: counter.title,
                    detail: counter.detail
                ) { showingCounter = true }
                .accessibilityIdentifier("today.counter")
            }
            PLHairline().padding(.leading, PLSpacing.xxxl)
            LedgerRow(
                label: JournalWording.forFaith(model.profile.faithID?.rawValue).title,
                systemImage: "book.closed",
                value: journalSummary,
                isPlaceholder: model.journal.requests.isEmpty
            ) { showingJournal = true }
            .accessibilityIdentifier("today.journal")
            PLHairline().padding(.leading, PLSpacing.xxxl)
            LedgerRow(
                label: String(localized: "Protection"),
                systemImage: "shield.lefthalf.filled",
                value: model.protectionStatus.title,
                detail: model.protectionStatus.summary,
                tone: model.protectionStatus.tone
            ) { model.selectedTab = .protection }
            .accessibilityIdentifier("today.protection")
            PLHairline().padding(.leading, PLSpacing.xxxl)
            LedgerRow(
                label: String(localized: "Your journey"),
                systemImage: "circle.grid.3x3",
                value: journeySummary,
                isPlaceholder: (model.habitSummary?.totalCompletedSessions ?? 0) == 0
            ) { showingJourney = true }
            .accessibilityIdentifier("today.journey")
        }
        .plPaper(padding: 0)
    }

    private var journeySummary: String {
        guard let summary = model.habitSummary, summary.totalCompletedSessions > 0 else {
            return String(localized: "Your pauses will gather here, gently")
        }
        return summary.daysPracticedLast7 == 1
            ? String(localized: "Paused on 1 of the last 7 days")
            : String(localized: "Paused on \(summary.daysPracticedLast7) of the last 7 days")
    }

    /// The guided rosary for Catholics (and Christians who haven't chosen a tradition).
    private var offersRosary: Bool {
        guard model.profile.faithID?.rawValue == "christianity" else { return false }
        let tradition = model.profile.traditionID?.rawValue
        return (tradition == nil || tradition == "christianity.catholic") && RosaryView.isAvailable(model)
    }

    /// Repeated prayer in each faith's own form: a 108-bead mala, a 33-bead tasbih, the rosary.
    private var counter: (label: String, title: String, detail: String, targets: [Int]) {
        switch model.profile.faithID?.rawValue {
        case "hinduism":
            (String(localized: "Japa"), String(localized: "Chant on a mala"), String(localized: "108 beads, with a soft tap on each"), [108, 54, 27, 11])
        case "islam":
            (String(localized: "Dhikr"), String(localized: "Tasbih counter"), String(localized: "SubhanAllah, Alhamdulillah, Allahu Akbar — 33 each"), [33, 99, 100, 11])
        case "christianity":
            (String(localized: "Prayer beads"), String(localized: "Pray the rosary or a chaplet"), String(localized: "A decade of ten, or the full fifty"), [10, 50, 33, 100])
        default:
            (String(localized: "Counting"), String(localized: "Count your breaths"), String(localized: "One tap for each slow breath"), [10, 21, 27, 108])
        }
    }

    private var journalSummary: String {
        let open = model.journal.open.count, answered = model.journal.answered.count
        if open == 0 && answered == 0 { return String(localized: "Keep the people and hopes you're praying for") }
        let praying = open == 1 ? String(localized: "1 you're praying for") : String(localized: "\(open) you're praying for")
        return answered == 0 ? praying : praying + " · " + String(localized: "\(answered) answered")
    }

    /// One intention per day, rotating through the user's list.
    private var todaysIntention: String? {
        let intentions = model.profile.intentions
        guard !intentions.isEmpty else { return nil }
        let day = model.env.calendar.ordinality(of: .day, in: .era, for: .now) ?? 0
        return intentions[day % intentions.count]
    }
}

/// A row in Today's ledger: a gilt glyph, a small-caps label, and its value.
private struct LedgerRow: View {
    let label: String
    let systemImage: String
    let value: String
    var detail: String?
    var isPlaceholder = false
    var isQuote = false
    var tone: PLStatusTone?
    let action: () -> Void

    /// Problems (protection paused, apps to confirm) read in caution ink — with words that
    /// say so — so they're noticed without alarm.
    private var valueColor: Color {
        if tone == .attention { return .plCaution }
        return isPlaceholder ? .plInkSecondary : .plInk
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: PLSpacing.m) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(Color.plGilt)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PLSpacing.xxs) {
                    Text(label).plEyebrow(.plInkSecondary)
                    Text(value)
                        .font(isQuote ? .plQuote : (isPlaceholder ? .plCallout : .plHeadline))
                        .foregroundStyle(valueColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(.plCaption)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.plInkSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, PLSpacing.l)
            .padding(.vertical, PLSpacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sheets

/// The optional check-in, offered from Today without crowding it.
struct MoodSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    VStack(alignment: .leading, spacing: PLSpacing.xs) {
                        Text("How are you arriving?")
                            .font(.plTitle)
                            .foregroundStyle(Color.plInk)
                        Text("Optional. Used only on this iPhone, to choose words that fit today.")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    MoodWords(selected: model.todayMood) { mood in
                        model.checkIn(model.todayMood == mood ? nil : mood)
                        dismiss()
                    }
                    if model.todayMood != nil {
                        Button("Clear today's answer") {
                            model.checkIn(nil)
                            dismiss()
                        }
                        .buttonStyle(.plQuiet(.plInkSecondary))
                    }
                }
                .padding(PLSpacing.page)
            }
            .background(Color.plCanvas)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.plCanvas)
    }
}

/// Edit intentions from Today.
struct IntentionsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.l) {
                    VStack(alignment: .leading, spacing: PLSpacing.xs) {
                        Text("Your intentions")
                            .font(.plTitle)
                            .foregroundStyle(Color.plInk)
                        Text("A few words to return to. Today shows one each day, and your moments offer them as a next step. They stay on this iPhone.")
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    IntentionsEditor(intentions: $draft)
                }
                .padding(PLSpacing.page)
            }
            .background(Color.plCanvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.updateIntentions(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("intentions.save")
                }
            }
            .onAppear { draft = model.profile.intentions }
        }
        .presentationBackground(Color.plCanvas)
    }
}

extension ContentLength {
    /// How long a moment of this length takes, in plain words.
    var durationHint: String {
        switch self {
        case .brief: String(localized: "Under a minute")
        case .standard: String(localized: "About a minute")
        case .extended: String(localized: "A few quiet minutes")
        }
    }
}

extension ProtectionStatus {
    var summary: String {
        switch self {
        case .unavailable: String(localized: "Screen Time isn't available on this device")
        case .needsAuthorization: String(localized: "Allow Screen Time access to begin")
        case .authorizationRevoked: String(localized: "Screen Time access is turned off")
        case .needsReselection: String(localized: "iOS needs you to confirm your apps again")
        case .needsSelection: String(localized: "Nothing is paused yet")
        case .off: String(localized: "Your chosen apps open freely")
        case .active: String(localized: "Chosen apps open after a moment")
        case let .unlocked(until): String(localized: "Apps open until \(until.formatted(date: .omitted, time: .shortened))")
        }
    }
}
