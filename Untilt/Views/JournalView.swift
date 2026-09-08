import SwiftUI
import SwiftData

// MARK: - Journal Tab
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntry.timestamp, order: .reverse) private var entries: [JournalEntry]
    @State private var showModeSelector = false
    @State private var activeMode: JournalEntryMode?
    @State private var linkedUrgeEvent: UrgeEvent?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Journal")
                    .font(UntiltTheme.Font.heading1)
                    .foregroundStyle(UntiltTheme.Color.slate)
                Spacer()
                Button {
                    showModeSelector = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.top, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s4)

            if entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .background(UntiltTheme.Color.warmWhite)
        .confirmationDialog("New journal entry", isPresented: $showModeSelector, titleVisibility: .visible) {
            Button("Free Form") { activeMode = .freeWrite }
            Button("AI Prompted") { activeMode = .checkIn }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $activeMode) { mode in
            if mode == .freeWrite {
                FreeWriteView { body in
                    save(body: body, mode: .freeWrite, urgeEvent: nil)
                }
            } else {
                CompassJournalView { body in
                    save(body: body, mode: .checkIn, urgeEvent: nil)
                }
            }
        }
    }

    // MARK: - Entry List
    private var entryList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: UntiltTheme.Spacing.s3) {
                ForEach(entries) { entry in
                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                        EntryRow(entry: entry)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, UntiltTheme.Spacing.s5)
                }
            }
            .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
            .padding(.top, UntiltTheme.Spacing.s2)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: UntiltTheme.Spacing.s4) {
            Spacer()
            Image(systemName: "square.and.pencil.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(UntiltTheme.Color.lavender500)
            Text("Your journal is empty")
                .font(UntiltTheme.Font.heading3)
                .foregroundStyle(UntiltTheme.Color.slate)
            Text("Tap the pen icon to write freely\nor let Compass guide you.")
                .font(UntiltTheme.Font.body)
                .foregroundStyle(UntiltTheme.Color.muted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Save
    func save(body: String, mode: JournalEntryMode, urgeEvent: UrgeEvent?) {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let entry = JournalEntry(body: body, mode: mode, urgeEvent: urgeEvent)
        modelContext.insert(entry)
        try? modelContext.save()
        activeMode = nil
    }
}

// MARK: - Entry Row
private struct EntryRow: View {
    let entry: JournalEntry

    private var modeIcon: String {
        switch entry.mode {
        case .urgeLinked: return "bolt.fill"
        case .checkIn:    return "sparkles"
        case .freeWrite:  return "square.and.pencil"
        }
    }

    private var modeColor: Color {
        switch entry.mode {
        case .urgeLinked: return UntiltTheme.Color.warning
        case .checkIn:    return UntiltTheme.Color.lavender500
        case .freeWrite:  return UntiltTheme.Color.sage500
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: UntiltTheme.Spacing.s3) {
            Image(systemName: modeIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(modeColor)
                .frame(width: 32, height: 32)
                .background(modeColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1) {
                Text(entry.timestamp, style: .date)
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(UntiltTheme.Color.muted)
                Text(entry.body)
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .lineLimit(2)
                    .lineSpacing(3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(UntiltTheme.Color.muted)
        }
        .padding(UntiltTheme.Spacing.s3 + 2)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
            .stroke(UntiltTheme.Color.border, lineWidth: 0.5))
    }
}

// MARK: - Entry Detail (read-only)
private struct EntryDetailView: View {
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s4) {
                Text(entry.timestamp, style: .date)
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(UntiltTheme.Color.muted)
                Text(entry.body)
                    .font(UntiltTheme.Font.body)
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .lineSpacing(6)
            }
            .padding(UntiltTheme.Spacing.s5)
        }
        .background(UntiltTheme.Color.warmWhite)
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Free-Write View
private struct FreeWriteView: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .font(UntiltTheme.Font.body)
                .foregroundStyle(UntiltTheme.Color.slate)
                .padding(UntiltTheme.Spacing.s4)
                .background(UntiltTheme.Color.warmWhite)
                .focused($focused)
                .onAppear { focused = true }
                .navigationTitle("Free-form")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave(text); dismiss() }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}

// MARK: - Compass Journal View (prompted)
private struct CompassJournalView: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [CompassMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var transcript = ""

    private let prompts = [
        "What's been on your mind today?",
        "How are you feeling in your body right now?",
        "What's one thing you're grateful for today?"
    ]
    @State private var promptIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: UntiltTheme.Spacing.s3) {
                            ForEach(messages) { msg in
                                MessageRow(message: msg).id(msg.id)
                            }
                            if isLoading { ProgressView().padding() }
                        }
                        .padding(UntiltTheme.Spacing.s4)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last { proxy.scrollTo(last.id) }
                    }
                }

                HStack(spacing: UntiltTheme.Spacing.s3) {
                    TextField("Write your answer…", text: $inputText, axis: .vertical)
                        .font(UntiltTheme.Font.body)
                        .lineLimit(4)
                        .padding(.horizontal, UntiltTheme.Spacing.s3)
                        .padding(.vertical, UntiltTheme.Spacing.s2)
                        .background(UntiltTheme.Color.warmGray)
                        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl))

                    Button { sendAnswer() } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(inputText.isEmpty
                                ? UntiltTheme.Color.muted
                                : UntiltTheme.Color.lavender700)
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding(UntiltTheme.Spacing.s4)
                .background(UntiltTheme.Color.white)
                .overlay(alignment: .top) {
                    Rectangle().fill(UntiltTheme.Color.border).frame(height: 0.5)
                }
            }
            .background(UntiltTheme.Color.warmWhite)
            .navigationTitle("Compass Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(transcript); dismiss() }
                        .disabled(transcript.isEmpty)
                }
            }
            .onAppear { askNext() }
        }
    }

    private func askNext() {
        guard promptIndex < prompts.count else { return }
        let q = prompts[promptIndex]
        messages.append(CompassMessage(role: .compass, content: q))
        transcript += "Compass: \(q)\n"
        promptIndex += 1
    }

    private func sendAnswer() {
        let answer = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        inputText = ""
        messages.append(CompassMessage(role: .user, content: answer))
        transcript += "You: \(answer)\n"

        if promptIndex < prompts.count {
            isLoading = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isLoading = false
                askNext()
            }
        } else {
            messages.append(CompassMessage(role: .compass,
                content: "Thank you for sharing. Your entry has been saved. Tap Save when you're ready."))
        }
    }
}

private struct MessageRow: View {
    let message: CompassMessage
    var isUser: Bool { message.role == .user }
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.content)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(isUser ? .white : UntiltTheme.Color.slate)
                .lineSpacing(4)
                .padding(.horizontal, UntiltTheme.Spacing.s3 + 2)
                .padding(.vertical, UntiltTheme.Spacing.s2 + 2)
                .background(isUser ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.white)
                .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
                .overlay(isUser ? nil :
                    RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                        .stroke(UntiltTheme.Color.border, lineWidth: 0.5))
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - JournalEntryMode: Identifiable for sheet(item:)
extension JournalEntryMode: Identifiable {
    public var id: String { rawValue }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .modelContainer(for: [JournalEntry.self, UrgeEvent.self], inMemory: true)
}
