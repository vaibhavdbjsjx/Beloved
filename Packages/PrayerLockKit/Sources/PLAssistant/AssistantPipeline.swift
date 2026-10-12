import Foundation
import PLContent
import PLCore
import PLFaith

/// USER REQUEST → SAFETY ROUTER → FAITH CONTEXT → SOURCE RETRIEVAL → GENERATION → VALIDATION → USER
///
/// Each stage is a separate, replaceable component. Safety routing and retrieval run
/// on-device; only generation (when configured) talks to a server, and only with the
/// minimised `GenerationPrompt`.
public struct AssistantPipeline: Sendable {
    let router: any SafetyRouter
    let parser: IntentParser
    let contextResolver: FaithContextResolver
    let retriever: any SourceRetriever
    let generator: any GenerationProvider
    let validator: ResponseValidator
    let region: String?

    public init(
        router: any SafetyRouter = LocalSafetyRouter(),
        parser: IntentParser,
        contextResolver: FaithContextResolver,
        retriever: any SourceRetriever,
        generator: any GenerationProvider = UnconfiguredGenerationProvider(),
        validator: ResponseValidator = ResponseValidator(),
        region: String? = Locale.current.region?.identifier
    ) {
        self.router = router
        self.parser = parser
        self.contextResolver = contextResolver
        self.retriever = retriever
        self.generator = generator
        self.validator = validator
        self.region = region
    }

    public func respond(to request: AssistantRequest) async -> AssistantResponse {
        // 1. Safety first — before parsing, retrieval, or any network call.
        var notices: [AssistantNotice] = []
        switch router.classify(request.text) {
        case .crisis:
            return AssistantResponse(
                kind: .crisisSupport,
                segments: [],
                notices: [.crisisSupport(CrisisResources.resources(for: region))],
                intent: nil
            )
        case .decline:
            return AssistantResponse(kind: .declined, segments: [], notices: [.declined], intent: nil)
        case .proceedWithMedicalDisclaimer:
            notices.append(.notMedicalAdvice)
        case .proceed:
            break
        }

        // 2. Intent + faith context.
        let intent = parser.parse(request.text)
        let context = contextResolver.resolve(intent, request: request)
        notices += context.devotionalNotes.map(AssistantNotice.devotionalContext)

        // 3. Retrieval of verified passages.
        let retrieval = retriever.retrieve(intent, context: context, request: request, limit: 3)
        let passages = retrieval.passages

        // 4. Generation (optional) + 5. validation.
        do {
            let prompt = PromptBuilder.prompt(request: request, intent: intent, context: context, passages: passages)
            let draft = try await generator.generate(prompt)
            let result = validator.validate(draft, passages: passages)
            if result.removedCount > 0 { notices.append(.removedUnverifiedContent(result.removedCount)) }
            if !result.segments.isEmpty {
                return AssistantResponse(kind: .composed, segments: result.segments, notices: notices, intent: intent)
            }
        } catch {
            if case GenerationError.notConfigured = error {
                notices.append(.generationUnavailable)
            } else {
                Log.logger(.assistant).error("Generation failed: \(String(describing: error), privacy: .public)")
                notices.append(.generationUnavailable)
            }
        }

        // Fallback: the best curated library item, unchanged (it carries its own provenance).
        guard let item = retrieval.bestItem else {
            notices.append(.noMatchingContent)
            return AssistantResponse(kind: .libraryOnly, segments: [], notices: notices, intent: intent)
        }
        return AssistantResponse(kind: .libraryOnly, segments: item.segments, notices: notices, intent: intent, itemID: item.id)
    }
}
