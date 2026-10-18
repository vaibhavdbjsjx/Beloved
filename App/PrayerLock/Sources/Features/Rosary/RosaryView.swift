import PLContent
import PLDesign
import PLScripture
import SwiftUI

/// The mysteries of the rosary, as prayed since 2002: Joyful (Monday, Saturday), Sorrowful
/// (Tuesday, Friday), Glorious (Wednesday, Sunday), Luminous (Thursday). Each is paired with the
/// Gospel passage it meditates on, shown from the bundled World English Bible.
enum RosaryMysteries: String, CaseIterable, Identifiable {
    case joyful, luminous, sorrowful, glorious

    var id: String { rawValue }

    var name: String {
        switch self {
        case .joyful: String(localized: "The Joyful Mysteries")
        case .luminous: String(localized: "The Luminous Mysteries")
        case .sorrowful: String(localized: "The Sorrowful Mysteries")
        case .glorious: String(localized: "The Glorious Mysteries")
        }
    }

    /// (title, World English Bible reference)
    var mysteries: [(title: String, reference: String)] {
        switch self {
        case .joyful: [
            (String(localized: "The Annunciation"), "Luke 1:35-38"),
            (String(localized: "The Visitation"), "Luke 1:41-45"),
            (String(localized: "The Nativity"), "Luke 2:6-11"),
            (String(localized: "The Presentation in the Temple"), "Luke 2:28-32"),
            (String(localized: "The Finding in the Temple"), "Luke 2:46-49"),
        ]
        case .luminous: [
            (String(localized: "The Baptism of the Lord"), "Matthew 3:16-17"),
            (String(localized: "The Wedding at Cana"), "John 2:3-5"),
            (String(localized: "The Proclamation of the Kingdom"), "Mark 1:14-15"),
            (String(localized: "The Transfiguration"), "Matthew 17:1-5"),
            (String(localized: "The Institution of the Eucharist"), "Luke 22:19-20"),
        ]
        case .sorrowful: [
            (String(localized: "The Agony in the Garden"), "Luke 22:41-42"),
            (String(localized: "The Scourging at the Pillar"), "John 19:1"),
            (String(localized: "The Crowning with Thorns"), "Matthew 27:28-29"),
            (String(localized: "The Carrying of the Cross"), "John 19:16-17"),
            (String(localized: "The Crucifixion"), "Luke 23:44-46"),
        ]
        case .glorious: [
            (String(localized: "The Resurrection"), "Matthew 28:5-6"),
            (String(localized: "The Ascension"), "Acts 1:9-11"),
            (String(localized: "The Descent of the Holy Spirit"), "Acts 2:1-4"),
            (String(localized: "The Assumption of Mary"), "Luke 1:48-49"),
            (String(localized: "The Coronation of Mary"), "Revelation 12:1"),
        ]
        }
    }

    static func forDay(_ date: Date, calendar: Calendar = .current) -> RosaryMysteries {
        switch calendar.component(.weekday, from: date) {
        case 2, 7: .joyful        // Monday, Saturday
        case 3, 6: .sorrowful     // Tuesday, Friday
        case 5: .luminous         // Thursday
        default: .glorious        // Wednesday, Sunday
        }
    }
}

/// One step of the rosary: a prayer said `count` times, or the announcement of a mystery.
struct RosaryStep: Identifiable, Equatable {
    enum Kind: Equatable {
        case prayer(ContentItemID)
        case mystery(index: Int)
    }

    let id: Int
    let kind: Kind
    let count: Int
    let note: String?
    /// 0 for the opening prayers, 1…5 for the decades, 6 for the closing prayers.
    let decade: Int

    static let signOfCross: ContentItemID = "christianity.traditional.sign-of-the-cross"
    static let creed: ContentItemID = "christianity.traditional.apostles-creed"
    static let ourFather: ContentItemID = "christianity.traditional.our-father"
    static let hailMary: ContentItemID = "christianity.traditional.hail-mary"
    static let gloryBe: ContentItemID = "christianity.traditional.glory-be"
    static let hailHolyQueen: ContentItemID = "christianity.traditional.hail-holy-queen"
    static let closing: ContentItemID = "christianity.traditional.rosary-prayer"

    static var all: [ContentItemID] { [signOfCross, creed, ourFather, hailMary, gloryBe, hailHolyQueen, closing] }

    static func sequence() -> [RosaryStep] {
        var steps: [(Kind, Int, String?, Int)] = [
            (.prayer(signOfCross), 1, String(localized: "Holding the crucifix"), 0),
            (.prayer(creed), 1, nil, 0),
            (.prayer(ourFather), 1, nil, 0),
            (.prayer(hailMary), 3, String(localized: "For faith, hope and charity"), 0),
            (.prayer(gloryBe), 1, nil, 0),
        ]
        for decade in 1...5 {
            steps.append((.mystery(index: decade - 1), 1, nil, decade))
            steps.append((.prayer(ourFather), 1, nil, decade))
            steps.append((.prayer(hailMary), 10, nil, decade))
            steps.append((.prayer(gloryBe), 1, nil, decade))
        }
        steps.append((.prayer(hailHolyQueen), 1, nil, 6))
        steps.append((.prayer(closing), 1, nil, 6))
        steps.append((.prayer(signOfCross), 1, nil, 6))
        return steps.enumerated().map { RosaryStep(id: $0, kind: $1.0, count: $1.1, note: $1.2, decade: $1.3) }
    }
}

struct RosaryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mysteries = RosaryMysteries.forDay(.now)
    @State private var stepIndex = 0
    @State private var bead = 0
    private let steps = RosaryStep.sequence()

    /// Whether this build may show every prayer of the rosary.
    static func isAvailable(_ model: AppModel) -> Bool {
        let visible = Set(model.env.catalog.visibleItems(policy: model.env.contentPolicy, registry: model.env.registry).map(\.id))
        return RosaryStep.all.allSatisfy { model.env.catalog.item($0) != nil } && (model.env.configuration.isDevelopment || RosaryStep.all.allSatisfy(visible.contains))
    }

    var body: some View {
        let step = steps[stepIndex]
        ZStack {
            Color.plCanvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: PLSpacing.l) {
                header(step)
                ScrollView {
                    content(step)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
                footer(step)
            }
            .padding(PLSpacing.page)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: bead) { _, new in new != 0 }
        .sensoryFeedback(.success, trigger: stepIndex)
    }

    // MARK: - Parts

    private func header(_ step: RosaryStep) -> some View {
        VStack(alignment: .leading, spacing: PLSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Menu {
                    Picker("Mysteries", selection: $mysteries) {
                        ForEach(RosaryMysteries.allCases) { Text($0.name).tag($0) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(mysteries.name).plEyebrow()
                        Image(systemName: "chevron.down").font(.caption2).foregroundStyle(Color.plAccent)
                    }
                }
                .accessibilityIdentifier("rosary.mysteries")
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plQuiet(.plAccent))
                    .accessibilityIdentifier("rosary.done")
            }
            DecadeTrack(current: step.decade)
        }
    }

    @ViewBuilder
    private func content(_ step: RosaryStep) -> some View {
        let languages = model.profile.languages
        VStack(alignment: .leading, spacing: PLSpacing.m) {
            switch step.kind {
            case let .mystery(index):
                let mystery = mysteries.mysteries[index]
                Text(String(localized: "Mystery \(index + 1) of 5"))
                    .plEyebrow(.plInkSecondary)
                Text(mystery.title)
                    .font(.plDisplay)
                    .foregroundStyle(Color.plInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rosary.mystery")
                if let passage = passage(mystery.reference) {
                    Text(passage)
                        .plReading()
                    Text("\(mystery.reference) · World English Bible")
                        .font(.plCaption)
                        .foregroundStyle(Color.plInkSecondary)
                }
                Text("Picture the scene for a moment, then pray the decade with it in your heart.")
                    .font(.plCallout)
                    .foregroundStyle(Color.plInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case let .prayer(id):
                if let item = model.env.catalog.item(id) {
                    if let note = step.note { Text(note).plEyebrow(.plInkSecondary) }
                    Text(item.title.resolved(for: languages))
                        .font(.plTitle)
                        .foregroundStyle(Color.plInk)
                        .accessibilityIdentifier("rosary.prayer")
                    if let text = item.segments.first(where: { $0.role != .explanation })?.text?.resolved(for: languages) {
                        Text(text).plReading()
                    }
                }
            }
        }
    }

    private func footer(_ step: RosaryStep) -> some View {
        VStack(spacing: PLSpacing.m) {
            if step.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<step.count, id: \.self) { index in
                        Circle()
                            .fill(index < bead ? Color.plGilt : Color.plInkSecondary.opacity(0.2))
                            .frame(width: 14, height: 14)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text("\(bead) of \(step.count)"))
                .accessibilityIdentifier("rosary.beads")
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: PLSpacing.m) {
                Button { back() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plSecondary)
                    .frame(width: 64)
                    .disabled(stepIndex == 0 && bead == 0)
                    .accessibilityLabel("Back")
                Button { advance() } label: {
                    Text(primaryTitle(step))
                }
                .buttonStyle(.plPrimary)
                .accessibilityIdentifier("rosary.next")
            }
        }
    }

    private func primaryTitle(_ step: RosaryStep) -> String {
        if stepIndex == steps.count - 1 { return String(localized: "Amen") }
        if step.count > 1 { return String(localized: "Amen · \(bead + 1) of \(step.count)") }
        return String(localized: "Amen · Next")
    }

    // MARK: - Actions

    private func advance() {
        let step = steps[stepIndex]
        if bead + 1 < step.count {
            bead += 1
            return
        }
        guard stepIndex + 1 < steps.count else {
            dismiss()
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            stepIndex += 1
            bead = 0
        }
    }

    private func back() {
        if bead > 0 {
            bead -= 1
        } else if stepIndex > 0 {
            withAnimation(.easeInOut(duration: 0.25)) {
                stepIndex -= 1
                bead = 0
            }
        }
    }

    private func passage(_ reference: String) -> String? {
        guard let readable = model.readableWork, let edition = readable.translation,
              let parsed = ScriptureReferenceFormatter.parse(reference, in: readable.work),
              let units = try? model.env.scripture.passage(edition.id, parsed) else { return nil }
        return units.map(\.text).joined(separator: " ")
    }
}

/// Seven marks: the opening prayers, five decades, and the closing.
private struct DecadeTrack: View {
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0...6, id: \.self) { index in
                Capsule()
                    .fill(index < current ? Color.plGilt : (index == current ? Color.plAccent : Color.plInkSecondary.opacity(0.18)))
                    .frame(height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(current == 0 ? "Opening prayers" : (current == 6 ? "Closing prayers" : "Decade \(current) of 5")))
    }
}
