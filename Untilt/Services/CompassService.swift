import Foundation

// MARK: - Compass Message
struct CompassMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    enum Role { case user, compass }
}

// MARK: - Compass Service
// Calls the Claude API with the Compass persona system prompt + user history context.
// NOTE: API key is bundled for beta only. Move to server proxy before public launch.

actor CompassService {

    static let shared = CompassService()

    private let apiKey: String = {
        // Read from Info.plist key CLAUDE_API_KEY (set via xcconfig)
        Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String ?? ""
    }()

    private let model = "claude-sonnet-4-5"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private let systemPrompt = """
    You are Compass, a warm and non-judgmental recovery coach inside the Untilt app. \
    Untilt helps people who are trying to quit gambling. You have access to the user's \
    behavioral history, which will be provided at the start of each conversation.

    Your role:
    - Talk users through urges using mindfulness techniques
    - When relevant, suggest 2–3 meditation session options by duration (e.g. "Would you prefer a 2, 5, or 10 minute session?")
    - Surface crisis resources (1-800-522-4700 National Problem Gambling Helpline, text 988) when the user signals acute distress
    - For daily insights: reference a specific recent data point, interpret it, end with one open coaching question

    Tone: calm, warm, conversational. Never clinical. Never preachy. Never use the word "relapse".
    If you don't know something, say so simply. Keep responses concise — 2–4 sentences unless the user asks for more.
    """

    // MARK: - Proactive daily insight
    /// Generates the daily insight card text. Cached per calendar day by the caller.
    func generateInsight(context: String) async throws -> String {
        let userPrompt = """
        \(context)

        Generate a single daily insight for this user. Follow this exact format:
        1. Reference one specific data point from their history above
        2. Interpret what it means for their recovery (1–2 sentences)
        3. End with one open coaching question

        Keep the total response under 100 words.
        """
        return try await send(messages: [["role": "user", "content": userPrompt]])
    }

    // MARK: - Reactive chat
    /// Sends a user message and returns Compass's reply.
    func chat(history: [CompassMessage], context: String, newMessage: String) async throws -> String {
        var apiMessages: [[String: String]] = []

        // Inject user context as first user message if history is fresh
        if history.isEmpty {
            apiMessages.append(["role": "user", "content": "My recovery context:\n\(context)"])
            apiMessages.append(["role": "assistant", "content": "Thanks — I have your context. How are you doing right now?"])
        }

        for msg in history {
            apiMessages.append(["role": msg.role == .user ? "user" : "assistant", "content": msg.content])
        }
        apiMessages.append(["role": "user", "content": newMessage])

        return try await send(messages: apiMessages)
    }

    // MARK: - Core API call
    private func send(messages: [[String: String]]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CompassError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = (json["content"] as? [[String: Any]])?.first,
            let text = content["text"] as? String
        else {
            throw CompassError.parseError
        }
        return text
    }
}

enum CompassError: Error {
    case apiError(Int)
    case parseError
}
