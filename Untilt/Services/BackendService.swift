import Foundation

// MARK: - Backend Service
// Talks to the real Untilt backend (Server/) instead of calling Anthropic
// directly from the client — see docs/adr/0003-backend-migration.md. Every
// request is authenticated with a Cognito access token from AuthService.

enum CompassMode: String {
    case urgeSurfing = "urge_surfing"
    case journaling
    case listening
}

/// One streamed chunk of a Compass reply, or the terminal state.
enum ChatEvent {
    case token(String)
    case crisis(message: String, resources: [CrisisResource])
    case done(turnCount: Int)
    case failed(String)
}

struct CrisisResource: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let phone: String
    let telHref: String
    let description: String
}

actor BackendService {

    static let shared = BackendService()

    // The real backend, behind HTTPS (Infra/alb.tf + api.pinenoodle.com —
    // see the architecture doc's Section 9 for the ACM/DNS setup).
    private let baseURL = URL(string: "https://api.pinenoodle.com")!

    // MARK: - Session lifecycle

    struct SessionInfo: Decodable {
        let sessionId: String
        let mode: String
    }

    func startSession(mode: CompassMode) async throws -> SessionInfo {
        var request = try await authedRequest(path: "/session", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode.rawValue])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkOK(response, data: data)
        return try JSONDecoder().decode(SessionInfo.self, from: data)
    }

    func endSession(sessionId: String) async {
        // Best-effort — the session-summarization job is enqueued
        // server-side regardless; nothing client-visible depends on this
        // succeeding, so failures are silently ignored rather than
        // surfaced to the user.
        guard var request = try? await authedRequest(path: "/session/\(sessionId)/end", method: "POST") else { return }
        request.httpBody = Data("{}".utf8)
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Messaging (SSE, with the crisis short-circuit as plain JSON)

    /// Sends a message and streams the reply. The backend responds either as
    /// `text/event-stream` (normal coaching turn, token-by-token) or as a
    /// single `application/json` body (crisis detected — see
    /// Server/src/routes/session.ts) — distinguished here by Content-Type,
    /// not by guessing at the body shape.
    func sendMessage(sessionId: String, text: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = try await authedRequest(path: "/session/\(sessionId)/message", method: "POST")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["message": text])

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw BackendError.badResponse
                    }
                    guard http.statusCode == 200 else {
                        throw BackendError.httpError(http.statusCode)
                    }

                    let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
                    if contentType.contains("application/json") {
                        try await Self.handleCrisisJSON(bytes: bytes, continuation: continuation)
                    } else {
                        try await Self.handleSSE(bytes: bytes, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(String(describing: error)))
                    continuation.finish()
                }
            }
        }
    }

    private static func handleCrisisJSON(bytes: URLSession.AsyncBytes, continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation) async throws {
        var raw = Data()
        for try await byte in bytes {
            raw.append(byte)
        }
        struct CrisisPayload: Decodable {
            let type: String
            let message: String
            let resources: [CrisisResource]
        }
        let payload = try JSONDecoder().decode(CrisisPayload.self, from: raw)
        continuation.yield(.crisis(message: payload.message, resources: payload.resources))
    }

    private static func handleSSE(bytes: URLSession.AsyncBytes, continuation: AsyncThrowingStream<ChatEvent, Error>.Continuation) async throws {
        var pendingEvent: String?
        for try await line in bytes.lines {
            if line.hasPrefix("event: ") {
                pendingEvent = String(line.dropFirst("event: ".count))
                continue
            }
            guard line.hasPrefix("data: ") else { continue }
            let jsonText = String(line.dropFirst("data: ".count))
            guard let jsonData = jsonText.data(using: .utf8) else { continue }

            switch pendingEvent {
            case "done":
                struct Done: Decodable { let turnCount: Int }
                if let done = try? JSONDecoder().decode(Done.self, from: jsonData) {
                    continuation.yield(.done(turnCount: done.turnCount))
                }
            case "error":
                struct ErrPayload: Decodable { let error: String }
                let message = (try? JSONDecoder().decode(ErrPayload.self, from: jsonData))?.error ?? "generation_failed"
                continuation.yield(.failed(message))
            default:
                struct TokenPayload: Decodable { let token: String }
                if let tok = try? JSONDecoder().decode(TokenPayload.self, from: jsonData) {
                    continuation.yield(.token(tok.token))
                }
            }
            pendingEvent = nil
        }
    }

    // MARK: - Shared request building

    private func authedRequest(path: String, method: String) async throws -> URLRequest {
        let token = try await AuthService.shared.validAccessToken()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static func checkOK(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw BackendError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

enum BackendError: Error {
    case badResponse
    case httpError(Int)
}
