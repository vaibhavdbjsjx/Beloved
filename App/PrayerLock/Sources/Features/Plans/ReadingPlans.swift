import Foundation
import Observation
import PLDesign
import PLFaith
import PLScripture
import SwiftUI

/// A reading plan through the faith's own scripture: one portion a day, opened in the reader.
struct ReadingPlan: Identifiable, Hashable {
    struct Day: Hashable {
        var title: String
        var location: ScriptureLocation
        /// Where to begin within the chapter (a Quran juz starts mid-surah).
        var startVerse: Int?
    }

    let id: String
    let title: String
    let summary: String
    let symbol: String
    let days: [Day]

    /// Plans for a scripture work, in the order they're offered.
    static func plans(for work: SourceWorkID, books: [ScriptureBook]) -> [ReadingPlan] {
        func chapters(_ ids: [String]) -> [Day] {
            ids.flatMap { id -> [Day] in
                guard let book = books.first(where: { $0.id == id }) else { return [] }
                return (1...max(book.chapterCount, 1)).map { chapter in
                    Day(title: "\(book.title.resolved(for: ["en"])) \(chapter)", location: ScriptureLocation(work: work, book: id, chapter: chapter))
                }
            }
        }
        switch work.rawValue {
        case "bible":
            let nt = books.filter { $0.group == .newTestament }.map(\.id)
            return [
                ReadingPlan(id: "bible.gospels", title: String(localized: "The Gospels"), summary: String(localized: "Walk with Jesus through Matthew, Mark, Luke and John — a chapter a day for 89 days."), symbol: "figure.walk", days: chapters(["MAT", "MAR", "LUK", "JOH"])),
                ReadingPlan(id: "bible.psalms", title: String(localized: "Psalms"), summary: String(localized: "The prayer book of the Bible, one psalm a day for 150 days."), symbol: "music.quarternote.3", days: chapters(["PSA"])),
                ReadingPlan(id: "bible.proverbs", title: String(localized: "Proverbs in a month"), summary: String(localized: "A chapter of wisdom for each day of the month."), symbol: "lightbulb", days: chapters(["PRO"])),
                ReadingPlan(id: "bible.new-testament", title: String(localized: "The New Testament"), summary: String(localized: "All 260 chapters, one a day."), symbol: "books.vertical", days: chapters(nt)),
            ].filter { !$0.days.isEmpty }
        case "quran":
            let quran = books.first { $0.id == "QUR" }
            func surah(_ n: Int) -> String {
                quran?.chapterInfo(n).map { "\(n). \($0.title.resolved(for: ["en"]))" } ?? String(localized: "Surah \(n)")
            }
            // Juz boundaries from Tanzil's Quran metadata (quran-data.js).
            let juz: [(Int, Int)] = [(1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111), (7, 88), (8, 41),
                                     (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75), (21, 1), (23, 1), (25, 21), (27, 56),
                                     (29, 46), (33, 31), (36, 28), (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1)]
            let khatm = juz.enumerated().map { index, start in
                Day(title: String(localized: "Juz \(index + 1) · from \(surah(start.0)), verse \(start.1)"),
                    location: ScriptureLocation(work: work, book: "QUR", chapter: start.0), startVerse: start.1)
            }
            let amma = (78...114).map { n in
                Day(title: surah(n), location: ScriptureLocation(work: work, book: "QUR", chapter: n))
            }
            return [
                ReadingPlan(id: "quran.khatm-30", title: String(localized: "Khatm in 30 days"), summary: String(localized: "Complete the Qur'an in a month, one juz a day — the way many read it in Ramadan."), symbol: "moon.stars", days: khatm),
                ReadingPlan(id: "quran.juz-amma", title: String(localized: "Juz 'Amma"), summary: String(localized: "The short surahs often recited in salah, one a day for 37 days."), symbol: "text.book.closed", days: amma),
                ReadingPlan(id: "quran.surah-a-day", title: String(localized: "A surah a day"), summary: String(localized: "All 114 surahs in order."), symbol: "books.vertical", days: (1...114).map { Day(title: surah($0), location: ScriptureLocation(work: work, book: "QUR", chapter: $0)) }),
            ]
        case "bhagavad-gita":
            return [
                ReadingPlan(id: "gita.18", title: String(localized: "The Gita in 18 days"), summary: String(localized: "One chapter a day, as the Gita is often read in eighteen sittings."), symbol: "sun.max", days: chapters(["BG"]).enumerated().map { index, day in
                    var day = day
                    let name = books.first { $0.id == "BG" }?.chapterInfo(index + 1)?.title.resolved(for: ["en"])
                    day.title = name.map { String(localized: "Chapter \(index + 1) · \($0)") } ?? String(localized: "Chapter \(index + 1)")
                    return day
                }),
            ]
        default:
            return []
        }
    }
}

/// Which plan the user follows and which days are done. On this iPhone only.
@MainActor
@Observable
final class ReadingPlanStore {
    private(set) var progress: [String: Set<Int>] = [:]
    private(set) var activePlanID: String?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "pl.plans.progress"),
           let saved = try? JSONDecoder().decode([String: Set<Int>].self, from: data) {
            progress = saved
        }
        activePlanID = defaults.string(forKey: "pl.plans.active")
    }

    func reset() {
        progress = [:]
        activePlanID = nil
        defaults.removeObject(forKey: "pl.plans.progress")
        defaults.removeObject(forKey: "pl.plans.active")
    }

    func start(_ plan: ReadingPlan) {
        activePlanID = plan.id
        defaults.set(plan.id, forKey: "pl.plans.active")
    }

    func toggle(_ day: Int, in plan: ReadingPlan) {
        var done = progress[plan.id] ?? []
        if done.contains(day) { done.remove(day) } else { done.insert(day) }
        progress[plan.id] = done
        save()
    }

    func markDone(_ day: Int, in plan: ReadingPlan) {
        progress[plan.id, default: []].insert(day)
        save()
    }

    func completed(_ plan: ReadingPlan) -> Set<Int> { progress[plan.id] ?? [] }

    /// The first day not yet read.
    func nextDay(_ plan: ReadingPlan) -> Int? {
        let done = completed(plan)
        return plan.days.indices.first { !done.contains($0) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) { defaults.set(data, forKey: "pl.plans.progress") }
    }
}

extension AppModel {
    var readingPlans: [ReadingPlan] {
        guard let readable = readableWork else { return [] }
        return ReadingPlan.plans(for: readable.work.id, books: readable.work.books)
    }

    var activeReadingPlan: ReadingPlan? {
        readingPlans.first { $0.id == plans.activePlanID }
    }

    /// Opens a plan's day in the reader and counts it as read.
    func read(_ plan: ReadingPlan, day: Int) {
        let entry = plan.days[day]
        plans.start(plan)
        plans.markDone(day, in: plan)
        let highlight = entry.startVerse.flatMap { $0 > 1 ? PassageReference(book: entry.location.book, chapter: entry.location.chapter, firstVerse: $0) : nil }
        openScripture(entry.location, highlight: highlight)
    }
}

// MARK: - Views

struct ReadingPlansView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PLSpacing.m) {
                Text("Read a little every day. Each day opens in the reader; your progress stays on this iPhone.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(model.readingPlans.enumerated()), id: \.element.id) { index, plan in
                    if index == 0 || model.hasPremiumAccess {
                        NavigationLink {
                            ReadingPlanDetailView(plan: plan)
                        } label: {
                            PlanCard(plan: plan)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("plan.\(plan.id)")
                    } else {
                        Button {
                            model.paywallReason = String(localized: "Every reading plan")
                        } label: {
                            PlanCard(plan: plan, locked: true)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(PLSpacing.page)
        }
        .background(Color.plCanvas)
        .navigationTitle("Reading plans")
        .navigationBarTitleDisplayMode(.large)
    }
}

/// A plan's title, description and progress bar.
struct PlanCard: View {
    @Environment(AppModel.self) private var model
    let plan: ReadingPlan
    var locked = false

    var body: some View {
        let done = model.plans.completed(plan).count
        HStack(alignment: .top, spacing: PLSpacing.m) {
            PLIconBadge(plan.symbol, size: 44)
            VStack(alignment: .leading, spacing: PLSpacing.xs) {
                HStack {
                    Text(plan.title)
                        .font(.plTitleSmall)
                        .foregroundStyle(Color.plInk)
                    Spacer()
                    if locked {
                        Label("Premium", systemImage: "lock.fill").font(.plLabel).foregroundStyle(Color.plAccent)
                    } else if model.plans.activePlanID == plan.id {
                        Text("Reading").font(.plLabel).foregroundStyle(Color.plAccent)
                    }
                }
                Text(plan.summary)
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: Double(done), total: Double(max(plan.days.count, 1)))
                    .tint(Color.plGilt)
                Text(String(localized: "\(done) of \(plan.days.count) days"))
                    .font(.plCaption.monospacedDigit())
                    .foregroundStyle(Color.plInkSecondary)
            }
        }
        .plPaper()
    }
}

struct ReadingPlanDetailView: View {
    @Environment(AppModel.self) private var model
    let plan: ReadingPlan

    var body: some View {
        let done = model.plans.completed(plan)
        let next = model.plans.nextDay(plan)
        List {
            Section {
                VStack(alignment: .leading, spacing: PLSpacing.s) {
                    Text(plan.summary)
                        .font(.plCallout)
                        .foregroundStyle(Color.plInkSecondary)
                    if let next {
                        Button {
                            model.read(plan, day: next)
                        } label: {
                            Label(String(localized: "Read day \(next + 1): \(plan.days[next].title)"), systemImage: "book")
                        }
                        .buttonStyle(.plPrimary)
                        .accessibilityIdentifier("plan.readNext")
                    } else {
                        Label("Plan complete — well done.", systemImage: "checkmark.seal")
                            .foregroundStyle(Color.plAccent)
                    }
                }
                .padding(.vertical, PLSpacing.xs)
                .listRowBackground(Color.clear)
            }
            Section("Days") {
                ForEach(plan.days.indices, id: \.self) { index in
                    HStack {
                        Button {
                            model.plans.toggle(index, in: plan)
                        } label: {
                            Image(systemName: done.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(done.contains(index) ? Color.plAccent : Color.plInkSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(done.contains(index) ? "Mark unread" : "Mark read")
                        Button {
                            model.read(plan, day: index)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(localized: "Day \(index + 1)")).font(.plCaption).foregroundStyle(Color.plInkSecondary)
                                    Text(plan.days[index].title).font(.plBody).foregroundStyle(Color.plInk)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(Color.plInkSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.plSurface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.plCanvas)
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
