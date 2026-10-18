import Foundation
import Observation
import PLDesign
import SwiftUI

/// The people and things someone is praying for, and the prayers they've seen answered.
/// Private: stored only on this iPhone.
struct PrayerRequest: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var person: String?
    var created: Date = .now
    var answered: Date?
    var answerNote: String?
    /// Times it was prayed for, to show faithfulness (never a streak to break).
    var prayedCount = 0
}

@MainActor
@Observable
final class PrayerJournal {
    private(set) var requests: [PrayerRequest] = []
    @ObservationIgnored private let url: URL

    init(directory: URL = URL.applicationSupportDirectory) {
        url = directory.appending(path: "prayer-journal.json")
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([PrayerRequest].self, from: data) {
            requests = saved
        }
    }

    var open: [PrayerRequest] { requests.filter { $0.answered == nil }.sorted { $0.created > $1.created } }
    var answered: [PrayerRequest] { requests.filter { $0.answered != nil }.sorted { ($0.answered ?? .distantPast) > ($1.answered ?? .distantPast) } }

    func add(_ text: String, person: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let who = person?.trimmingCharacters(in: .whitespacesAndNewlines)
        requests.append(PrayerRequest(text: trimmed, person: who?.isEmpty == false ? who : nil))
        save()
    }

    func prayed(_ id: PrayerRequest.ID) { change(id) { $0.prayedCount += 1 } }
    func markAnswered(_ id: PrayerRequest.ID, note: String?) {
        change(id) {
            $0.answered = .now
            let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
            $0.answerNote = trimmed?.isEmpty == false ? trimmed : nil
        }
    }
    func reopen(_ id: PrayerRequest.ID) { change(id) { $0.answered = nil; $0.answerNote = nil } }
    func delete(_ id: PrayerRequest.ID) {
        requests.removeAll { $0.id == id }
        save()
    }

    private func change(_ id: PrayerRequest.ID, _ edit: (inout PrayerRequest) -> Void) {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { return }
        edit(&requests[index])
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(requests)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            // Losing a save is better than crashing a prayer list; the next change retries.
        }
    }
}

/// Faith-appropriate words for the journal.
struct JournalWording {
    let title: String
    let empty: String
    let addPrompt: String
    let answeredTitle: String

    static func forFaith(_ faith: String?) -> JournalWording {
        switch faith {
        case "christianity":
            JournalWording(
                title: String(localized: "Prayer requests"),
                empty: String(localized: "Write down who and what you're bringing to God, and come back to them in your moments. Mark them answered when you see how God has replied."),
                addPrompt: String(localized: "What would you like to pray for?"),
                answeredTitle: String(localized: "Answered prayers"))
        case "islam":
            JournalWording(
                title: String(localized: "My du'a list"),
                empty: String(localized: "Keep the du'as you're making — for yourself, your family, the ummah — and remember them in sujood and at the blessed times."),
                addPrompt: String(localized: "What is your du'a?"),
                answeredTitle: String(localized: "Accepted du'as"))
        case "hinduism":
            JournalWording(
                title: String(localized: "My prayers"),
                empty: String(localized: "Write your sankalpa — the prayers you're offering, for yourself and for those you love — and return to them with your mantra."),
                addPrompt: String(localized: "What is your prayer?"),
                answeredTitle: String(localized: "Prayers fulfilled"))
        default:
            JournalWording(
                title: String(localized: "Intentions"),
                empty: String(localized: "Note the people and hopes you want to hold in mind, and return to them when you pause."),
                addPrompt: String(localized: "Who or what do you want to hold in mind?"),
                answeredTitle: String(localized: "Gratitude"))
        }
    }
}

struct PrayerJournalView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false
    @State private var answering: PrayerRequest?

    var body: some View {
        let journal = model.journal
        let words = JournalWording.forFaith(model.profile.faithID?.rawValue)
        NavigationStack {
            List {
                if journal.open.isEmpty && journal.answered.isEmpty {
                    Section {
                        Text(words.empty)
                            .font(.plCallout)
                            .foregroundStyle(Color.plInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !journal.open.isEmpty {
                    Section {
                        ForEach(journal.open) { request in
                            RequestRow(request: request)
                                .swipeActions(edge: .leading) {
                                    Button { journal.prayed(request.id) } label: { Label("Prayed", systemImage: "hands.sparkles") }
                                        .tint(Color.plGilt)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button { answering = request } label: { Label("Answered", systemImage: "checkmark.seal") }
                                        .tint(Color.plAccent)
                                    Button(role: .destructive) { journal.delete(request.id) } label: { Label("Delete", systemImage: "trash") }
                                }
                                .contextMenu {
                                    Button { journal.prayed(request.id) } label: { Label("I prayed for this", systemImage: "hands.sparkles") }
                                    Button { answering = request } label: { Label("Mark as answered", systemImage: "checkmark.seal") }
                                    Button(role: .destructive) { journal.delete(request.id) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    } footer: {
                        Text("Swipe right when you've prayed for one, left when it's answered.")
                    }
                }
                if !journal.answered.isEmpty {
                    Section(words.answeredTitle) {
                        ForEach(journal.answered) { request in
                            RequestRow(request: request)
                                .swipeActions {
                                    Button { journal.reopen(request.id) } label: { Label("Keep praying", systemImage: "arrow.uturn.backward") }
                                    Button(role: .destructive) { journal.delete(request.id) } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plCanvas)
            .navigationTitle(words.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("journal.done") }
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Label("Add", systemImage: "plus") }
                        .accessibilityIdentifier("journal.add")
                }
            }
            .sheet(isPresented: $adding) { AddRequestSheet(prompt: words.addPrompt) }
            .sheet(item: $answering) { request in AnsweredSheet(request: request) }
        }
        .presentationBackground(Color.plCanvas)
    }
}

private struct RequestRow: View {
    let request: PrayerRequest

    var body: some View {
        VStack(alignment: .leading, spacing: PLSpacing.xxs) {
            if let person = request.person {
                Text(person).plEyebrow()
            }
            Text(request.text)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.plInk)
            if let note = request.answerNote {
                Text(note)
                    .font(.plCallout)
                    .italic()
                    .foregroundStyle(Color.plInkSecondary)
            }
            Text(detail)
                .font(.plCaption)
                .foregroundStyle(request.answered == nil ? Color.plInkSecondary : Color.plGilt)
        }
        .padding(.vertical, PLSpacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        if let answered = request.answered {
            return String(localized: "Answered \(answered.formatted(date: .abbreviated, time: .omitted))")
        }
        let since = String(localized: "Since \(request.created.formatted(date: .abbreviated, time: .omitted))")
        return request.prayedCount == 0 ? since : since + " · " + String(localized: "prayed \(request.prayedCount)×")
    }
}

private struct AddRequestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let prompt: String
    @State private var text = ""
    @State private var person = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(prompt, text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .accessibilityIdentifier("journal.text")
                }
                Section {
                    TextField("For someone? (optional)", text: $person)
                        .textContentType(.name)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plCanvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.journal.add(text, person: person)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("journal.save")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.plCanvas)
    }
}

private struct AnsweredSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: PrayerRequest
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(request.text).font(.system(.body, design: .serif))
                }
                Section {
                    TextField("How was it answered? (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                } footer: {
                    Text("Sometimes the answer is yes, sometimes not yet, sometimes peace instead. Remembering helps.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.plCanvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.journal.markAnswered(request.id, note: note)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.plCanvas)
    }
}
