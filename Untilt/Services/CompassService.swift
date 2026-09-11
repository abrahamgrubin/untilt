import Combine
import Foundation

// MARK: - Compass Message
struct CompassMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var crisisResources: [CrisisResource] = []

    enum Role { case user, compass, crisis }
}

// MARK: - Compass Conversation
// Owns one chat session's state against the real backend (see
// docs/adr/0003-backend-migration.md — this replaced direct
// client-to-Anthropic calls). One instance per CompassChatView presentation,
// not a shared singleton, since a session ID is now part of the state.
@MainActor
final class CompassConversation: ObservableObject {

    @Published private(set) var messages: [CompassMessage] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var sessionId: String?

    /// Starts a backend session and shows the opening message. Call once
    /// when the chat view appears.
    func start(mode: CompassMode, slipContext: String?) async {
        do {
            let session = try await BackendService.shared.startSession(mode: mode)
            sessionId = session.sessionId
            let opening = slipContext ?? "Hey — I'm here whenever you need me. How are you feeling right now?"
            messages.append(CompassMessage(role: .compass, content: opening))
        } catch {
            errorMessage = "Couldn't reach Compass right now. Check your connection and try again."
        }
    }

    /// Ends the backend session (enqueues async memory-profile
    /// summarization server-side). Call when the chat view is dismissed.
    func end() {
        guard let sessionId else { return }
        Task { await BackendService.shared.endSession(sessionId: sessionId) }
    }

    func send(_ text: String) async {
        guard let sessionId else {
            errorMessage = "Compass isn't ready yet — give it a moment and try again."
            return
        }
        messages.append(CompassMessage(role: .user, content: text))
        isLoading = true
        errorMessage = nil

        var replyIndex: Int?
        do {
            let stream = await BackendService.shared.sendMessage(sessionId: sessionId, text: text)
            for try await event in stream {
                switch event {
                case .token(let token):
                    if let idx = replyIndex {
                        messages[idx].content.append(token)
                    } else {
                        messages.append(CompassMessage(role: .compass, content: token))
                        replyIndex = messages.count - 1
                    }
                case .crisis(let message, let resources):
                    messages.append(CompassMessage(role: .crisis, content: message, crisisResources: resources))
                case .done:
                    isLoading = false
                case .failed(let reason):
                    errorMessage = "Compass is unavailable right now. Try again in a moment."
                    isLoading = false
                    _ = reason // surfaced via logging server-side; kept generic for the user
                }
            }
        } catch {
            errorMessage = "Compass is unavailable right now. Try again in a moment."
        }
        isLoading = false
    }
}
