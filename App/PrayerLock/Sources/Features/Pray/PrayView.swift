import PLCalendar
import PLContent
import PLDesign
import PLFaith
import SwiftUI

/// Everything for prayer in one place, in clear sections: the faith's own tools, who to pray
/// to (Hindu), prayers for every need, practical guides, and the holy days ahead.
struct PrayView: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: Sheet?
    @State private var cover: Sheet?

    enum Sheet: String, Identifiable {
        case counter, rosary, qibla, journal, salahTimes
        var id: String { rawValue }
    }

    private var faith: String? { model.profile.faithID?.rawValue }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PLSpacing.xl) {
                    header
                    tools
                    if faith == "hinduism" { deities }
                    if faith == "christianity" { corePrayers }
                    if faith == "islam" { duas }
                    needs
                    guides
                    holyDays
                }
                .padding(.horizontal, PLSpacing.page)
                .padding(.top, PLSpacing.m)
                .padding(.bottom, PLSpacing.xxxl)
            }
            .background(Color.plCanvas)
            .navigationTitle("Pray")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: PrayRoute.self) { route in
                switch route {
                case let .deity(focus): DeityView(focus: focus)
                case let .theme(theme): ThemePrayersView(theme: theme)
                case .holyDays: HolyDaysView()
                case .plans: ReadingPlansView()
                case .zakat: ZakatCalculatorView()
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .salahTimes: SalahTimesView().environment(model)
                default: PrayerJournalView().environment(model)
                }
            }
            .fullScreenCover(item: $cover) { cover in
                switch cover {
                case .rosary: RosaryView().environment(model)
                case .qibla: QiblaView().environment(model)
                default: PrayerCounterView(title: counter.title, target: counter.targets[0], targets: counter.targets).environment(model)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text(subtitle)
            .font(.system(.title3, design: .serif))
            .foregroundStyle(Color.plInkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtitle: String {
        switch faith {
        case "hinduism": String(localized: "Mantras for every deity and every need, your mala, and the festivals ahead.")
        case "islam": String(localized: "Your salah, the Qibla, duas from the Qur'an, dhikr and the blessed days ahead.")
        case "christianity": String(localized: "The prayers of the Church, the rosary, Scripture plans and the feasts ahead.")
        default: String(localized: "Words, quiet practices and moments to return to.")
        }
    }

    // MARK: - Tools

    private var tools: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            PLSectionHeader(String(localized: "Your practice"))
            PLTileGrid {
                switch faith {
                case "islam":
                    PLToolTile(String(localized: "Prayer times"), subtitle: nextPrayerLine, systemName: "clock") { sheet = .salahTimes }
                        .accessibilityIdentifier("pray.salah")
                    PLToolTile(String(localized: "Qibla"), subtitle: String(localized: "Face the Kaaba"), systemName: "location.north.line") { cover = .qibla }
                        .accessibilityIdentifier("pray.qibla")
                    PLToolTile(String(localized: "Tasbih"), subtitle: String(localized: "33 · 99 · 100"), systemName: "circle.dotted") { cover = .counter }
                        .accessibilityIdentifier("pray.counter")
                    PLToolTile(String(localized: "My du'a list"), subtitle: journalLine, systemName: "book.closed") { sheet = .journal }
                    NavigationLink(value: PrayRoute.plans) { tileLabel(String(localized: "Read the Qur'an"), String(localized: "Khatm in 30 days"), "book") }
                        .buttonStyle(PressableStyle())
                    NavigationLink(value: PrayRoute.zakat) { tileLabel(String(localized: "Zakat"), String(localized: "Calculate what's due"), "percent") }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("pray.zakat")
                case "christianity":
                    if offersRosary {
                        PLToolTile(String(localized: "Rosary"), subtitle: RosaryMysteries.forDay(.now).name, systemName: "circle.dotted") { model.withPremium(String(localized: "Guided rosary")) { cover = .rosary } }
                            .accessibilityIdentifier("pray.rosary")
                    } else {
                        PLToolTile(String(localized: "Prayer beads"), subtitle: String(localized: "Count your prayers"), systemName: "circle.dotted") { cover = .counter }
                    }
                    PLToolTile(String(localized: "Prayer requests"), subtitle: journalLine, systemName: "book.closed") { sheet = .journal }
                    NavigationLink(value: PrayRoute.plans) { tileLabel(String(localized: "Bible plans"), String(localized: "Gospels · Psalms · Proverbs"), "book") }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("pray.plans")
                    NavigationLink(value: PrayRoute.holyDays) { tileLabel(String(localized: "Feasts & seasons"), nextHolyDayLine, "calendar") }
                        .buttonStyle(PressableStyle())
                case "hinduism":
                    PLToolTile(String(localized: "Japa mala"), subtitle: String(localized: "108 beads"), systemName: "circle.dotted") { cover = .counter }
                        .accessibilityIdentifier("pray.counter")
                    PLToolTile(String(localized: "My prayers"), subtitle: journalLine, systemName: "book.closed") { sheet = .journal }
                    NavigationLink(value: PrayRoute.plans) { tileLabel(String(localized: "Read the Gita"), String(localized: "18 days, a chapter a day"), "book") }
                        .buttonStyle(PressableStyle())
                    NavigationLink(value: PrayRoute.holyDays) { tileLabel(String(localized: "Festivals"), nextHolyDayLine, "calendar") }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("pray.festivals")
                default:
                    PLToolTile(String(localized: "Count breaths"), subtitle: String(localized: "A quiet counter"), systemName: "circle.dotted") { cover = .counter }
                    PLToolTile(String(localized: "Intentions"), subtitle: journalLine, systemName: "book.closed") { sheet = .journal }
                }
            }
        }
    }

    private func tileLabel(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            PLIconBadge(symbol, size: 40)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.plHeadline).foregroundStyle(Color.plInk).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(.plCaption).foregroundStyle(Color.plInkSecondary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity, alignment: .topLeading)
        .padding(PLSpacing.m)
        .background(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous).fill(Color.plSurface))
        .overlay(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: PLRadius.panel - 4, style: .continuous))
    }

    private var offersRosary: Bool {
        let tradition = model.profile.traditionID?.rawValue
        return (tradition == nil || tradition == "christianity.catholic") && RosaryView.isAvailable(model)
    }

    private var counter: (title: String, targets: [Int]) {
        switch faith {
        case "hinduism": (String(localized: "Japa"), [108, 54, 27, 11])
        case "islam": (String(localized: "Dhikr"), [33, 99, 100, 11])
        case "christianity": (String(localized: "Prayer beads"), [10, 50, 33, 100])
        default: (String(localized: "Breaths"), [10, 21, 27, 108])
        }
    }

    private var journalLine: String {
        let open = model.journal.open.count
        return open == 0 ? String(localized: "Keep who you pray for") : String(localized: "\(open) you're praying for")
    }

    private var nextPrayerLine: String {
        guard let next = model.salah.nextPrayer() else { return String(localized: "Set your location") }
        return "\(next.prayer.displayName) · \(next.time.formatted(date: .omitted, time: .shortened))"
    }

    private var nextHolyDayLine: String {
        guard let next = model.upcomingObservances(days: 120).first(where: { $0.range.start >= model.today }) else { return String(localized: "The year ahead") }
        return "\(next.definition.name.resolved(for: model.profile.languages)) · \(next.range.start.formatted)"
    }

    // MARK: - Hindu: deities

    private var deities: some View {
        let focuses = model.dailyFocusChoices
        return VStack(alignment: .leading, spacing: PLSpacing.s) {
            PLSectionHeader(String(localized: "Pray to"), eyebrow: String(localized: "Mantras by deity"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: PLSpacing.s), GridItem(.flexible(), spacing: PLSpacing.s)], spacing: PLSpacing.s) {
                ForEach(focuses) { focus in
                    let count = model.items(forFocus: focus.id).count
                    NavigationLink(value: PrayRoute.deity(focus.id)) {
                        DeityTile(name: focus.name.resolved(for: model.profile.languages).components(separatedBy: " (").first ?? "", count: count, symbol: focus.id.rawValue)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("pray.deity.\(focus.id.rawValue)")
                }
            }
        }
    }

    // MARK: - Christian / Muslim libraries

    private var corePrayers: some View {
        let items = model.faithItems.filter { $0.id.rawValue.hasPrefix("christianity.traditional") }
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    PLSectionHeader(String(localized: "Prayers of the Church"), eyebrow: String(localized: "Every Christian knows"))
                    PurposeFilteredPrayers(items: items, limit: 5)
                        .plPaper(padding: PLSpacing.m)
                }
            }
        }
    }

    private var duas: some View {
        let items = model.faithItems.filter { $0.id.rawValue.hasPrefix("islam.") }
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    PLSectionHeader(String(localized: "Duas from the Qur'an"), eyebrow: String(localized: "With Arabic and meaning"))
                    PurposeFilteredPrayers(items: items, limit: 5)
                        .plPaper(padding: PLSpacing.m)
                }
            }
        }
    }

    // MARK: - Needs

    private var needs: some View {
        let themes = needThemes
        return Group {
            if !themes.isEmpty {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    PLSectionHeader(String(localized: "Prayers for every need"))
                    PLFlowLayout(spacing: PLSpacing.xs, lineSpacing: PLSpacing.xs) {
                        ForEach(themes, id: \.self) { theme in
                            NavigationLink(value: PrayRoute.theme(theme)) {
                                Text(model.themeName(theme))
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(Color.plInk)
                                    .padding(.horizontal, PLSpacing.m)
                                    .padding(.vertical, PLSpacing.s)
                                    .background(Capsule().fill(Color.plSurface))
                                    .overlay(Capsule().strokeBorder(Color.plLine, lineWidth: 1))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityIdentifier("pray.need.\(theme.rawValue)")
                        }
                    }
                }
            }
        }
    }

    /// Themes with at least two prayers in this faith, most-used first.
    private var needThemes: [ThemeID] {
        var counts: [ThemeID: Int] = [:]
        for item in model.faithItems { for theme in item.themes { counts[theme, default: 0] += 1 } }
        return counts.filter { $0.value >= 2 }.sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }.map(\.key)
    }

    // MARK: - Guides

    private var guides: some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            PLSectionHeader(String(localized: "How to…"), eyebrow: String(localized: "Step-by-step, from the companion"))
            VStack(spacing: 0) {
                ForEach(Array(guideQuestions.enumerated()), id: \.offset) { index, guide in
                    if index > 0 { PLHairline().padding(.leading, 64) }
                    PLListRow(guide.title, systemName: guide.symbol) { model.ask(guide.question) }
                }
            }
            .plPaper(padding: 0)
        }
    }

    private var guideQuestions: [(title: String, symbol: String, question: String)] {
        switch faith {
        case "hinduism": [
            (String(localized: "Do a simple daily puja at home"), "flame", "How do I do a simple daily puja at home, step by step, as a beginner?"),
            (String(localized: "Perform aarti"), "sparkles", "How do I perform aarti correctly at home?"),
            (String(localized: "Keep a vrat (fast)"), "moon", "How do I keep a vrat properly — what to eat, what to avoid, and how to break it? Include Ekadashi and Monday fasts."),
            (String(localized: "Chant a mantra with a mala"), "circle.dotted", "How do I chant a mantra with a japa mala — how to hold it, the meru bead, and counting 108?"),
            (String(localized: "Set up a home mandir"), "house", "How should I set up a small mandir at home — direction, placement and daily care?"),
            (String(localized: "Satyanarayan katha"), "book", "How is Satyanarayan puja and katha done at home?"),
        ]
        case "islam": [
            (String(localized: "Make wudu"), "drop", "How do I make wudu step by step, and what breaks it?"),
            (String(localized: "Pray the five daily prayers"), "person", "How do I pray salah step by step, with the number of rakats for each of the five prayers?"),
            (String(localized: "Pray Jumu'ah"), "building.columns", "How is Jumu'ah (Friday prayer) prayed, and what are its sunnahs?"),
            (String(localized: "Pray Witr and Tahajjud"), "moon.stars", "How do I pray Witr and Tahajjud?"),
            (String(localized: "Make up a missed prayer"), "clock.arrow.circlepath", "How do I make up a missed prayer (qada)?"),
            (String(localized: "Pray Janazah"), "heart", "How is the Janazah (funeral) prayer performed?"),
        ]
        case "christianity": [
            (String(localized: "Pray with Scripture (Lectio Divina)"), "book", "How do I pray with Scripture using Lectio Divina, step by step?"),
            (String(localized: "Start a daily prayer time"), "sunrise", "How can I build a simple daily prayer habit — morning and evening?"),
            (String(localized: "Pray the rosary"), "circle.dotted", "How do I pray the rosary, step by step, and which mysteries go with which day?"),
            (String(localized: "Make a good confession"), "hand.raised", "How do I prepare for and make a good confession?"),
            (String(localized: "Fast for Lent"), "drop", "How do Christians fast in Lent, and what are the rules in my tradition?"),
            (String(localized: "Pray for someone who is sick"), "cross.case", "How can I pray for someone who is sick?"),
        ]
        default: [
            (String(localized: "A two-minute stillness practice"), "wind", "Teach me a simple two-minute stillness practice."),
            (String(localized: "A gratitude practice"), "heart", "How can I build a daily gratitude practice?"),
        ]
        }
    }

    // MARK: - Holy days

    private var holyDays: some View {
        let upcoming = Array(model.upcomingObservances(days: 120).filter { $0.range.start >= model.today }.prefix(4))
        return VStack(alignment: .leading, spacing: PLSpacing.s) {
            PLSectionHeader(faith == "christianity" ? String(localized: "Feasts ahead") : (faith == "islam" ? String(localized: "Blessed days ahead") : String(localized: "Festivals ahead")))
            if upcoming.isEmpty {
                Text("Nothing in the next few months.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcoming.enumerated()), id: \.element.id) { index, observance in
                        if index > 0 { PLHairline().padding(.leading, 64) }
                        NavigationLink {
                            FestivalDetailView(observance: observance)
                        } label: {
                            HStack(spacing: PLSpacing.m) {
                                PLIconBadge(FestivalGreeting.forOccasion(observance.occasionID.rawValue, name: "")?.symbol ?? "calendar", size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(observance.definition.name.resolved(for: model.profile.languages))
                                        .font(.plHeadline).foregroundStyle(Color.plInk)
                                    Text(observance.range.start.formatted + (observance.isEstimated ? " · " + String(localized: "expected") : ""))
                                        .font(.plCaption).foregroundStyle(Color.plInkSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.plInkSecondary.opacity(0.7))
                            }
                            .padding(.horizontal, PLSpacing.m)
                            .padding(.vertical, PLSpacing.s + 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .plPaper(padding: 0)
            }
            NavigationLink(value: PrayRoute.holyDays) {
                Label(String(localized: "See the full calendar"), systemImage: "calendar")
                    .font(.plCallout.weight(.medium))
                    .foregroundStyle(Color.plAccent)
            }
            .accessibilityIdentifier("pray.calendar")
        }
    }
}

enum PrayRoute: Hashable {
    case deity(FocusID)
    case theme(ThemeID)
    case holyDays
    case plans
    case zakat
}

/// A deity in the gallery: a gilt monogram, the name and how many mantras.
private struct DeityTile: View {
    let name: String
    let count: Int
    let symbol: String

    var body: some View {
        HStack(spacing: PLSpacing.s) {
            Text(DeityMedallion.glyphs[symbol] ?? String(name.prefix(1)))
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Color.plOnAccentFill)
                .frame(width: 44, height: 44)
                .background(Circle().fill(LinearGradient(colors: [Color.plAccentFill, Color.plGilt], startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.plHeadline)
                    .foregroundStyle(Color.plInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(count == 1 ? String(localized: "1 prayer") : String(localized: "\(count) prayers"))
                    .font(.plCaption)
                    .foregroundStyle(Color.plInkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(PLSpacing.s)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous).fill(Color.plSurface))
        .overlay(RoundedRectangle(cornerRadius: PLRadius.control, style: .continuous).strokeBorder(Color.plLine, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    static func symbol(for id: String) -> String { "sparkles" }
}

/// One deity's mantras and stotras, filterable by purpose, plus their days and a question.
struct DeityView: View {
    @Environment(AppModel.self) private var model
    let focus: FocusID

    var body: some View {
        let choice = model.dailyFocusChoices.first { $0.id == focus }
        let name = choice?.name.resolved(for: model.profile.languages) ?? focus.rawValue
        let items = model.items(forFocus: focus)
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                PLHeroCard {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        Text(String(localized: "Pray to")).plHeroEyebrow()
                        Text(name).font(.system(.largeTitle, design: .serif))
                        if let names = choice?.alsoKnownAs, !names.isEmpty {
                            Text(names.joined(separator: " · "))
                                .font(.system(.callout, design: .serif)).opacity(0.85)
                        }
                        Button {
                            model.chooseFocusForToday(focus)
                            model.selectedTab = .today
                        } label: {
                            Label(model.todaysFocus == focus ? String(localized: "Your focus today") : String(localized: "Pray to \(name) today"), systemImage: "sun.max")
                                .font(.plHeadline)
                                .foregroundStyle(Color.plAccent)
                                .padding(.horizontal, PLSpacing.m)
                                .padding(.vertical, PLSpacing.s)
                                .background(Capsule().fill(Color.plOnAccentFill))
                        }
                        .buttonStyle(PressableStyle())
                        .padding(.top, PLSpacing.xs)
                    }
                }
                if items.isEmpty {
                    Text("Beloved's verified library doesn't have a mantra for \(name) yet. Ask the companion about \(name)'s mantras and stories.")
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                } else {
                    VStack(alignment: .leading, spacing: PLSpacing.s) {
                        PLSectionHeader(String(localized: "Mantras and stotras"))
                        PurposeFilteredPrayers(items: items)
                            .plPaper(padding: PLSpacing.m)
                    }
                }
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    PLSectionHeader(String(localized: "Ask about \(name)"))
                    VStack(spacing: 0) {
                        let questions = [
                            "Tell me the main stories of \(name).",
                            "How do I do a simple puja to \(name) at home?",
                            "Which day and which festivals are special for \(name), and why?",
                        ]
                        ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                            if index > 0 { PLHairline().padding(.leading, 64) }
                            PLListRow(question, systemName: index == 0 ? "book" : (index == 1 ? "flame" : "calendar")) { model.ask(question) }
                        }
                    }
                    .plPaper(padding: 0)
                }
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Every prayer in the faith for one need.
struct ThemePrayersView: View {
    @Environment(AppModel.self) private var model
    let theme: ThemeID

    var body: some View {
        let items = model.faithItems.filter { $0.themes.contains(theme) }
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.m) {
                PurposeFilteredPrayers(items: items)
                    .plPaper(padding: PLSpacing.m)
                Button {
                    model.ask("I'd like a prayer for \(model.themeName(theme).lowercased()). What do you suggest, and how should I pray it?")
                } label: {
                    Label("Ask the companion", systemImage: "sparkles")
                }
                .buttonStyle(.plSecondary)
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle(model.themeName(theme))
        .navigationBarTitleDisplayMode(.large)
    }
}
