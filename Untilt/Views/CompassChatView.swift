import SwiftUI
import SwiftData

// MARK: - Compass Chat View (Reactive mode)
struct CompassChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var conversation = CompassConversation()

    @State private var inputText = ""
    @State private var showBoxBreathing = false

    /// Which of the three PRD modes this conversation is in. HomeView's
    /// "Ask Compass" entry point doesn't yet offer mode selection in the
    /// UI (that's a separate, larger frontend task — see the architecture
    /// doc's Section 9), so this defaults to urge surfing, the mode that
    /// entry point most closely matches.
    var mode: CompassMode = .urgeSurfing

    /// Pre-seeded opening when launched from a Slip notification
    var slipContext: String?

    private var messages: [CompassMessage] { conversation.messages }
    private var isLoading: Bool { conversation.isLoading }
    private var errorMessage: String? { conversation.errorMessage }

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
        .task { await conversation.start(mode: mode, slipContext: slipContext) }
        .onDisappear { conversation.end() }
        .fullScreenCover(isPresented: $showBoxBreathing) {
            BoxBreathingView(onComplete: { showBoxBreathing = false })
        }
    }

    // MARK: - Send message
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await conversation.send(text) }
    }
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
        if message.role == .crisis {
            crisisBubble
        } else {
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

    /// Crisis resources (PRD Section 8) — always paired with tappable
    /// tel: links, never just informational text, since the whole point
    /// of this path is getting the user to real help immediately.
    private var crisisBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
                Text(message.content)
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .lineSpacing(4)

                ForEach(message.crisisResources) { resource in
                    Link(destination: URL(string: resource.telHref)!) {
                        HStack(spacing: UntiltTheme.Spacing.s3) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 15, weight: .medium))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.name)
                                    .font(UntiltTheme.Font.bodySmall.weight(.semibold))
                                Text(resource.phone)
                                    .font(UntiltTheme.Font.caption)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, UntiltTheme.Spacing.s3)
                        .padding(.vertical, UntiltTheme.Spacing.s2 + 2)
                        .background(UntiltTheme.Color.error)
                        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.md))
                    }
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s4)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                    .stroke(UntiltTheme.Color.error, lineWidth: 1)
            )
            Spacer(minLength: 24)
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
