import Foundation
import Observation
import PLAssistant
import PLCompanion
import PLContent
import PLCore
import PLFaith
import PLScripture
import os

/// The companion conversation: safety first, then the cloud companion for subscribers, or an
/// answer from Beloved's verified library. Holy text is only ever the library's own words.
@MainActor
@Observable
final class CompanionModel {
    private(set) var conversation = CompanionConversation()
    /// The reply as it streams in (markers included), or `nil` when not answering.
    private(set) var streamingText: String?
    private(set) var isResponding = false
    /// A short, honest note about the last reply (limit reached, offline…).
    private(set) var notice: String?

    @ObservationIgnored private var app: AppModel?
    @ObservationIgnored private var task: Task<Void, Never>?
    private let log = Log.logger(.assistant)
    private let safety = LocalSafetyRouter()

    func attach(_ app: AppModel) {
        guard self.app == nil else { return }
        self.app = app
        conversation = (try? app.env.companionStore.load()) ?? CompanionConversation()
    }

    /// Premium + a configured server: the full companion. Otherwise the verified library.
    var usesCloud: Bool {
        guard let app else { return false }
        return app.env.isCompanionCloudConfigured && app.accessLevel == .premium
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding, let app else { return }
        notice = nil
        append(CompanionMessage(role: .user, text: text))

        switch safety.classify(text) {
        case .crisis:
            append(CompanionMessage(role: .assistant, origin: .support, text: String(localized: "I'm really glad you told me. You deserve support right now, from someone who can be with you. Please reach out to one of these — and if you're in immediate danger, call your local emergency number.")))
            return
        case .decline:
            append(CompanionMessage(role: .assistant, origin: .library, text: String(localized: "Beloved doesn't compare or rank faiths. Each tradition is honoured here on its own terms. Is there something in your own practice I can help with?")))
            return
        case .proceedWithMedicalDisclaimer, .proceed:
            break
        }

        isResponding = true
        task = Task { [weak self] in
            guard let self else { return }
            if self.usesCloud {
                await self.replyFromCompanion(app: app)
            } else {
                await self.replyFromLibrary(text, app: app)
            }
            self.isResponding = false
            self.streamingText = nil
        }
    }

    func stop() {
        task?.cancel()
    }

    func startOver() {
        task?.cancel()
        conversation = CompanionConversation()
        streamingText = nil
        notice = nil
        persist()
    }

    // MARK: - Replies

    private func replyFromCompanion(app: AppModel) async {
        let request = CompanionRequest(conversation: conversation.messages, context: context(app))
        var reply = ""
        streamingText = ""
        do {
            for try await delta in app.env.companionTransport.reply(to: request) {
                reply += delta
                streamingText = reply
            }
            if !reply.isEmpty { append(CompanionMessage(role: .assistant, origin: .companion, text: reply)) }
        } catch is CancellationError {
            if !reply.isEmpty { append(CompanionMessage(role: .assistant, origin: .companion, text: reply)) }
        } catch let error as CompanionError {
            if !reply.isEmpty { append(CompanionMessage(role: .assistant, origin: .companion, text: reply)) }
            notice = message(for: error)
            if reply.isEmpty, let last = conversation.messages.last(where: { $0.role == .user }) {
                await replyFromLibrary(last.text, app: app)
            }
        } catch {
            notice = message(for: .network)
        }
    }

    /// An answer chosen from the verified library on this iPhone — no AI involved.
    private func replyFromLibrary(_ text: String, app: AppModel) async {
        let response = await app.env.assistant.respond(to: AssistantRequest(
            text: text, profile: app.profile, mood: app.todayMood, date: .now,
            calendar: app.env.calendar, hasPremium: app.accessLevel == .premium
        ))
        var parts: [String] = []
        if let reference = response.intent?.reference, let marker = scriptureMarker(reference, app: app) {
            parts.append(String(localized: "Here is the passage you asked about:"))
            parts.append(marker)
        }
        if let itemID = response.itemID {
            parts.append(parts.isEmpty
                ? String(localized: "From Beloved's library, chosen for what you asked:")
                : String(localized: "And something to pray with:"))
            parts.append("⟦prayer:\(itemID.rawValue)⟧")
        }
        if response.notices.contains(.notMedicalAdvice) {
            parts.append(String(localized: "Prayer goes alongside care, never instead of it — please keep your doctor close."))
        }
        if parts.isEmpty {
            parts.append(String(localized: "I couldn't find something for that in Beloved's library yet. Try asking for a prayer, a verse, or words for how you feel — for example “a prayer for peace”."))
        }
        append(CompanionMessage(role: .assistant, origin: .library, text: parts.joined(separator: "\n")))
    }

    private func scriptureMarker(_ reference: String, app: AppModel) -> String? {
        guard let work = app.readableWork?.work,
              ScriptureReferenceFormatter.parse(reference, in: work) != nil else { return nil }
        let prefix = ["bhagavad-gita": "gita"][work.id.rawValue] ?? work.id.rawValue
        return "⟦\(prefix):\(reference)⟧"
    }

    private func context(_ app: AppModel) -> CompanionContext {
        CompanionContext.make(
            profile: app.profile,
            registry: app.env.registry,
            catalog: app.env.catalog,
            policy: app.env.contentPolicy,
            scripture: app.readableWork.map { [$0.work.id.rawValue] } ?? []
        )
    }

    private func message(for error: CompanionError) -> String {
        switch error {
        case .dailyLimitReached: String(localized: "You've reached today's companion allowance. It renews tomorrow — the library is always here.")
        case .notSubscribed: String(localized: "The companion is part of Premium. Here's something from the library instead.")
        case .notConfigured: String(localized: "The companion isn't available in this build. Here's something from the library.")
        case .unavailable, .network: String(localized: "The companion couldn't answer just now. Here's something from the library instead.")
        }
    }

    // MARK: - Storage

    private func append(_ message: CompanionMessage) {
        conversation.messages.append(message)
        if conversation.messages.count > CompanionConversation.maximumStoredMessages {
            conversation.messages.removeFirst(conversation.messages.count - CompanionConversation.maximumStoredMessages)
        }
        persist()
    }

    private func persist() {
        guard let app else { return }
        do {
            try app.env.companionStore.save(conversation)
        } catch {
            log.error("Companion conversation not saved: \(String(describing: error), privacy: .public)")
        }
    }
}
