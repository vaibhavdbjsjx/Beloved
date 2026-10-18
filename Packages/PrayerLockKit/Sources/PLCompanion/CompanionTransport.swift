import Foundation

public enum CompanionError: Error, Equatable, Sendable {
    /// No companion server is configured for this build.
    case notConfigured
    /// The companion is part of Premium and there is no active subscription.
    case notSubscribed
    /// Today's fair-use allowance is used up (resets at midnight UTC).
    case dailyLimitReached
    /// Today's free messages are used up; Premium has a larger allowance.
    case freeLimitReached
    /// The server or the model provider couldn't answer right now.
    case unavailable
    case network
}

/// Streams the companion's reply as text deltas (markers included).
public protocol CompanionTransport: Sendable {
    func reply(to request: CompanionRequest) -> AsyncThrowingStream<String, Error>
}

/// Used when no server is configured: every request fails with `.notConfigured`, and the app
/// answers from the on-device library instead.
public struct UnavailableCompanionTransport: CompanionTransport {
    public init() {}
    public func reply(to request: CompanionRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: CompanionError.notConfigured) }
    }
}

/// Talks to Beloved's companion server (`server/companion`). The API key for the model lives
/// only on that server. Each request carries the App Store's signed proof of the user's
/// subscription, which the server verifies against Apple's certificate chain.
public struct CloudCompanionTransport: CompanionTransport {
    let endpoint: URL
    let installID: String
    let subscriptionProof: @Sendable () async -> String?
    let session: URLSession

    /// `installID`: a random identifier for this install (not tied to the person), used only to
    /// count the free daily allowance. `subscriptionProof` unlocks the Premium allowance.
    public init(endpoint: URL, installID: String, session: URLSession = .shared,
                subscriptionProof: @escaping @Sendable () async -> String?) {
        self.endpoint = endpoint
        self.installID = installID
        self.session = session
        self.subscriptionProof = subscriptionProof
    }

    public func reply(to request: CompanionRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let proof = await subscriptionProof()
                    var urlRequest = URLRequest(url: endpoint.appending(path: "v1/companion"))
                    urlRequest.httpMethod = "POST"
                    urlRequest.timeoutInterval = 60
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.setValue(installID, forHTTPHeaderField: "X-Beloved-Install")
                    if let proof { urlRequest.setValue(proof, forHTTPHeaderField: "X-Beloved-Subscription") }
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else { throw CompanionError.network }
                    switch http.statusCode {
                    case 200: break
                    case 401, 402, 403: throw CompanionError.notSubscribed
                    case 429:
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw body.contains("free_limit") ? CompanionError.freeLimitReached : CompanionError.dailyLimitReached
                    default: throw CompanionError.unavailable
                    }
                    var parser = CompanionStreamParser()
                    for try await line in bytes.lines {
                        for event in parser.consume(line: line) {
                            switch event {
                            case let .delta(text): continuation.yield(text)
                            case .done: continuation.finish(); return
                            case let .failure(error): throw error
                            }
                        }
                    }
                    continuation.finish()
                } catch let error as CompanionError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: CompanionError.network)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Parses the server's event stream: `data: {"type":"delta","text":"…"}` lines, then
/// `data: {"type":"done"}`; `{"type":"error","code":"limit"|"subscription"|"unavailable"}`.
public struct CompanionStreamParser: Sendable {
    public enum Event: Equatable, Sendable {
        case delta(String)
        case done
        case failure(CompanionError)
    }

    private struct Payload: Decodable {
        var type: String
        var text: String?
        var code: String?
    }

    public init() {}

    public mutating func consume(line: String) -> [Event] {
        guard line.hasPrefix("data:") else { return [] }
        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = json.data(using: .utf8), let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return [] }
        switch payload.type {
        case "delta": return payload.text.map { [.delta($0)] } ?? []
        case "done": return [.done]
        case "error":
            switch payload.code {
            case "limit": return [.failure(.dailyLimitReached)]
            case "subscription": return [.failure(.notSubscribed)]
            default: return [.failure(.unavailable)]
            }
        default: return []
        }
    }
}
