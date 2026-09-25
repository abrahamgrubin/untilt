import Combine
import Foundation

// MARK: - Compass Message
struct CompassMessage: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var crisisResources: [CrisisResource] = []

    enum Role { case user, compass, crisis, findTherapist, followUpConsent }
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

    /// Appends a local-only prompt asking the user for their zip code, so
    /// the "Find a Therapist" hand-off (architecture doc Section 9) can
    /// build a location-filtered Psychology Today link. Deliberately a
    /// purely client-side flow — no backend/model call. This is a simple
    /// structured input, not something that needs (or should route
    /// through) crisis-detection or the mode-specific conversation
    /// orchestration, matching this app's general preference for a
    /// deterministic path over an LLM one wherever one will do.
    func presentFindTherapistPrompt() {
        messages.append(CompassMessage(
            role: .compass,
            content: "I can help you find a gambling-specialized therapist nearby. What's your zip code?"
        ))
        messages.append(CompassMessage(role: .findTherapist, content: ""))
    }

    /// Appends a follow-up question once the Psychology Today search sheet
    /// closes (architecture doc Section 9). Deliberately a normal
    /// compass-role message, not a special yes/no bubble: the user's
    /// reply flows through the regular `send()` pipeline like any other
    /// turn, so it reaches the model and gets picked up by the existing
    /// session-end memory-profile summarization (Section 4) for free --
    /// no new backend/storage work needed, and no yes/no button forces a
    /// binary answer onto something that's often more complicated than
    /// that.
    func appendTherapistFollowUp() {
        messages.append(CompassMessage(
            role: .compass,
            content: "How did that feel? Did you reach out to anyone, or is there something making that feel hard right now?"
        ))
    }

    /// Appends a structured yes/no prompt asking whether Compass should
    /// check back in about a week if the user hasn't heard from a
    /// therapist yet. Deterministic capture, not routed through the
    /// model, since the answer drives an actual scheduling decision --
    /// same reasoning as the zip-code bubble above and the
    /// crisis-detection design: a structured input beats an LLM one
    /// wherever the answer needs to be acted on programmatically.
    func appendFollowUpConsentPrompt() {
        messages.append(CompassMessage(
            role: .followUpConsent,
            content: "Would you like me to check back in about a week if you haven't heard back from a therapist?"
        ))
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
