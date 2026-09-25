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

/// Today's Compass insight card, as returned by `POST /insight`.
/// Codable (not just Decodable) so HomeView can cache it for the day.
struct DailyInsight: Codable, Equatable {
    enum Kind: String, Codable {
        /// Generated coaching insight.
        case insight
        /// Fixed, gentle check-in the backend serves after a recent crisis.
        case checkIn = "check_in"
    }

    let localDate: String
    let kind: Kind
    let title: String
    let body: String
    let bullets: [String]
    let question: String
    /// Present on check-in cards: the helplines, with `tel:` links, so they
    /// can be shown as tap-to-call rows (same list the chat's crisis
    /// response uses, from Server/src/ai/crisisResources.ts).
    let resources: [CrisisResource]?
}

/// On-device cache for today's insight card, so reopening the Today tab
/// doesn't hit the network.
///
/// Health-adjacent and per-user, so:
/// - Check-in cards (served after a recent crisis) are never cached on the
///   device. The server returns its stored card without a model call, so
///   skipping the cache costs one quick request, and nothing about a crisis
///   is left in `UserDefaults`.
/// - The cache is cleared on every sign-in and sign-out (AuthService), so
///   one person's card can never be shown to the next person who signs in
///   on the same phone.
enum DailyInsightCache {
    private static let key = "compass_daily_insight"

    /// Today's cached card, if there is one for `localDate`.
    static func load(for localDate: String) -> DailyInsight? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(DailyInsight.self, from: data),
              cached.localDate == localDate,
              cached.kind == .insight else {
            return nil
        }
        return cached
    }

    static func save(_ insight: DailyInsight) {
        guard insight.kind == .insight else {
            clear()
            return
        }
        if let data = try? JSONEncoder().encode(insight) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct CrisisResource: Codable, Identifiable, Equatable {
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

    // MARK: - Daily insight (Today tab)

    /// On-device activity numbers the backend needs to write today's
    /// Compass insight (Server/src/ai/insight.ts). Numbers and meditation
    /// catalogue titles only, never journal text.
    struct InsightSnapshot: Encodable {
        struct UrgeCounts: Encodable {
            let resisted: Int
            let slipped: Int
        }

        struct MeditationCounts: Encodable {
            let sessions: Int
            let minutes: Int
        }

        /// The user's local calendar date, `yyyy-MM-dd`.
        let localDate: String
        let daysClean: Int
        let urgesLast7Days: UrgeCounts
        let urgesPrior7Days: UrgeCounts
        /// nil when there has never been an Urge Event.
        let hoursSinceLastUrge: Double?
        let meditationLast7Days: MeditationCounts
        let recentMeditationTitles: [String]
        /// nil once every milestone is earned.
        let nextMilestoneDays: Int?
    }

    /// Returns today's insight card. The backend generates it on the first
    /// request of the user's day and returns the same card after that.
    func fetchDailyInsight(_ snapshot: InsightSnapshot) async throws -> DailyInsight {
        var request = try await authedRequest(path: "/insight", method: "POST")
        request.httpBody = try JSONEncoder().encode(snapshot)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkOK(response, data: data)
        return try JSONDecoder().decode(DailyInsight.self, from: data)
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
