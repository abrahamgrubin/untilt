import SwiftUI
import SwiftData

// MARK: - Compass Chat View (Reactive mode)
struct CompassChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UrgeEvent.timestamp, order: .reverse) private var urgeEvents: [UrgeEvent]
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var journalEntries: [JournalEntry]
    @Query(sort: \MeditationCompletion.timestamp, order: .reverse) private var completions: [MeditationCompletion]
    @Query private var profiles: [UserProfile]

    @State private var messages: [CompassMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showBoxBreathing = false

    /// Pre-seeded opening when launched from a Slip notification
    var slipContext: String?

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.slate)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("Compass")
                        .font(UntiltTheme.Font.heading3)
                        .foregroundStyle(UntiltTheme.Color.slate)
                    Text("Your recovery coach")
                        .font(UntiltTheme.Font.micro)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }
                Spacer()
//                Color.clear.frame(width: 32)
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .overlay(alignment: .bottom) {
                Rectangle().fill(UntiltTheme.Color.border).frame(height: 0.8)
            }

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: UntiltTheme.Spacing.s3) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg, showBoxBreathing: $showBoxBreathing)
                                .id(msg.id)
                        }
                        if isLoading {
                            TypingIndicator()
                        }
                        if let error = errorMessage {
                            Text(error)
                                .font(UntiltTheme.Font.caption)
                                .foregroundStyle(UntiltTheme.Color.error)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal, UntiltTheme.Spacing.s4)
                    .padding(.vertical, UntiltTheme.Spacing.s4)
                }
                .background(UntiltTheme.Color.warmWhite)
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: isLoading) { _, loading in
                    if loading, let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            // Input bar
            HStack(spacing: UntiltTheme.Spacing.s3) {
                TextField("Message Compass…", text: $inputText, axis: .vertical)
                    .font(UntiltTheme.Font.body)
                    .lineLimit(4)
                    .padding(.horizontal, UntiltTheme.Spacing.s3)
                    .padding(.vertical, UntiltTheme.Spacing.s2 + 2)
                    .background(UntiltTheme.Color.warmGray)
                    .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? UntiltTheme.Color.muted
                            : UntiltTheme.Color.lavender700)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(.horizontal, UntiltTheme.Spacing.s4)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .overlay(alignment: .top) {
                Rectangle().fill(UntiltTheme.Color.border).frame(height: 0.5)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { startConversation() }
        .fullScreenCover(isPresented: $showBoxBreathing) {
            BoxBreathingView(onComplete: { showBoxBreathing = false })
        }
    }

    // MARK: - Start conversation
    private func startConversation() {
        let opening: String
        if let slip = slipContext {
            opening = slip
        } else {
            opening = "Hey — I'm here whenever you need me. How are you feeling right now?"
        }
        messages.append(CompassMessage(role: .compass, content: opening))
    }

    // MARK: - Send message
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(CompassMessage(role: .user, content: text))
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let context = buildContext()
                let reply = try await CompassService.shared.chat(
                    history: messages.dropLast(),
                    context: context,
                    newMessage: text
                )
                await MainActor.run {
                    messages.append(CompassMessage(role: .compass, content: reply))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Compass is unavailable right now. Try again in a moment."
                    isLoading = false
                }
            }
        }
    }

    private func buildContext() -> String {
        guard let profile = profiles.first else { return "New user, no history yet." }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: profile.sobrietyStartDate)
        let daysClean = calendar.dateComponents([.day], from: start, to: Date()).day ?? 0

        let recentUrge = urgeEvents.prefix(5).map {
            UntiltLogicUrgeRecord(timestamp: $0.timestamp, completed: $0.completed)
        }
        let recentJournal = journalEntries.prefix(3).map {
            UntiltLogicJournalRecord(body: $0.body, timestamp: $0.timestamp)
        }
        let recentMeds = completions.prefix(3).map {
            UntiltLogicMedRecord(sessionTitle: $0.sessionTitle, durationMinutes: $0.durationMinutes)
        }

        return contextString(daysClean: daysClean, urge: recentUrge, journal: recentJournal, meds: recentMeds)
    }
}

// MARK: - Simple wrappers to avoid importing UntiltLogic types directly here
private struct UntiltLogicUrgeRecord { let timestamp: Date; let completed: Bool }
private struct UntiltLogicJournalRecord { let body: String; let timestamp: Date }
private struct UntiltLogicMedRecord { let sessionTitle: String; let durationMinutes: Int }

private func contextString(daysClean: Int,
                            urge: [UntiltLogicUrgeRecord],
                            journal: [UntiltLogicJournalRecord],
                            meds: [UntiltLogicMedRecord]) -> String {
    var lines = ["## User Recovery Context", "Days clean: \(daysClean)"]
    let resisted = urge.filter { $0.completed }.count
    let slipped  = urge.filter { !$0.completed }.count
    lines.append("Recent urge events: \(urge.count) (\(resisted) resisted, \(slipped) slipped)")
    if journal.isEmpty { lines.append("Recent journal entries: none") }
    else { journal.forEach { lines.append("Journal: \($0.body.prefix(80))") } }
    if meds.isEmpty { lines.append("Recent meditations: none") }
    else { meds.forEach { lines.append("Meditation: \($0.sessionTitle) (\($0.durationMinutes) min)") } }
    return lines.joined(separator: "\n")
}

// MARK: - Message Bubble
private struct MessageBubble: View {
    let message: CompassMessage
    @Binding var showBoxBreathing: Bool

    var isUser: Bool { message.role == .user }

    /// Keywords that indicate Compass is suggesting box breathing / meditation
    private static let breathingKeywords = [
        "box breathing",
        "breathing exercise",
        "breathing session",
        "guided breathing",
        "deep breathing",
        "breathe together",
        "try breathing",
        "start breathing"
    ]

    /// Whether the message mentions a breathing exercise the user can launch
    private var hasBoxBreathingAction: Bool {
        guard !isUser else { return false }
        let lower = message.content.lowercased()
        return Self.breathingKeywords.contains { lower.contains($0) }
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s2) {
                Text(message.content)
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(isUser ? .white : UntiltTheme.Color.slate)
                    .lineSpacing(4)

                if hasBoxBreathingAction {
                    Button {
                        showBoxBreathing = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wind")
                                .font(.system(size: 14, weight: .medium))
                            Text("Start Box Breathing")
                                .font(UntiltTheme.Font.bodySmall.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, UntiltTheme.Spacing.s3)
                        .padding(.vertical, UntiltTheme.Spacing.s2)
                        .background(UntiltTheme.Color.lavender700)
                        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.md))
                    }
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s4)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(isUser ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(
                isUser ? nil :
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                    .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
            )
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing Indicator
private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(UntiltTheme.Color.muted)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                                   value: animating)
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s4)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5))
            Spacer(minLength: 48)
        }
        .onAppear { animating = true }
    }
}

#Preview {
    CompassChatView()
        .modelContainer(for: [UserProfile.self, UrgeEvent.self,
                               JournalEntry.self, MeditationCompletion.self], inMemory: true)
}
