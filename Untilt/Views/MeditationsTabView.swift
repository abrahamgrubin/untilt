import SwiftUI
import AVKit
import SwiftData

// MARK: - Meditations Tab
struct MeditationsTabView: View {
    @State private var selectedFilter: DurationFilter = .all
    @State private var selectedSession: MeditationSession?

    private var filteredSessions: [MeditationSession] {
        selectedFilter == .all
            ? MeditationSession.catalogue
            : MeditationSession.catalogue.filter { $0.filterBucket == selectedFilter }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s4) {
                // Header
                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1) {
                    Text("Meditations")
                        .font(UntiltTheme.Font.heading1)
                        .foregroundStyle(UntiltTheme.Color.slate)
                    Text("Choose a session to begin")
                        .font(UntiltTheme.Font.bodySmall)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.top, UntiltTheme.Spacing.s5)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UntiltTheme.Spacing.s2) {
                        ForEach(DurationFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                label: filter.rawValue,
                                isActive: selectedFilter == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, UntiltTheme.Spacing.s5)
                }

                // Session list
                LazyVStack(spacing: UntiltTheme.Spacing.s3) {
                    ForEach(filteredSessions) { session in
                        SessionRow(session: session) {
                            selectedSession = session
                        }
                        .padding(.horizontal, UntiltTheme.Spacing.s5)
                    }
                }
                .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
            }
        }
        .background(UntiltTheme.Color.warmWhite)
        .sheet(item: $selectedSession) { session in
            MeditationPlayerView(session: session)
        }
    }
}

// MARK: - Session Row
private struct SessionRow: View {
    let session: MeditationSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: UntiltTheme.Spacing.s3) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: UntiltTheme.Radius.md)
                        .fill(session.category.thumbnailColor)
                        .frame(width: 72, height: 72)
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 32, height: 32)
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(UntiltTheme.Color.lavender700)
                            .offset(x: 1)
                    }
                }

                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1 + 2) {
                    Text(session.category.rawValue)
                        .font(UntiltTheme.Font.micro)
                        .foregroundStyle(session.category.tagColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(session.category.tagBackground)
                        .clipShape(Capsule())

                    Text(session.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.slate)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: UntiltTheme.Spacing.s1) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(UntiltTheme.Color.muted)
                        Text("\(session.durationLabel) · \(session.level)")
                            .font(UntiltTheme.Font.micro)
                            .foregroundStyle(UntiltTheme.Color.muted)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.muted)
            }
            .padding(UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                    .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Chip (reused from MeditationVideoShelfView context)
private struct FilterChip: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(UntiltTheme.Font.overline)
                .foregroundStyle(isActive ? .white : UntiltTheme.Color.muted)
                .padding(.horizontal, UntiltTheme.Spacing.s3)
                .padding(.vertical, UntiltTheme.Spacing.s1 + 2)
                .background(isActive ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isActive ? Color.clear : UntiltTheme.Color.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meditation Player
struct MeditationPlayerView: View {
    let session: MeditationSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var hasError = false
    @State private var completed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(UntiltTheme.Spacing.s3)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text(session.title)
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    // Balance the close button
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, UntiltTheme.Spacing.s4)
                .padding(.top, UntiltTheme.Spacing.s4)

                Spacer()

                // Player content
                if let url = session.contentURL, let player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/9, contentMode: .fit)
                        .onAppear { player.play() }
                } else {
                    placeholderPlayer
                }

                Spacer()

                // Meta
                VStack(spacing: UntiltTheme.Spacing.s2) {
                    Text(session.category.rawValue)
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(session.title)
                        .font(UntiltTheme.Font.heading3)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("\(session.durationLabel) · \(session.level)")
                        .font(UntiltTheme.Font.bodySmall)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, UntiltTheme.Spacing.s6)
                .padding(.bottom, UntiltTheme.Spacing.s8)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    // MARK: - Placeholder (no contentURL yet)
    private var placeholderPlayer: some View {
        VStack(spacing: UntiltTheme.Spacing.s4) {
            ZStack {
                Circle()
                    .fill(session.category.thumbnailColor.opacity(0.3))
                    .frame(width: 120, height: 120)
                Image(systemName: "headphones")
                    .font(.system(size: 52))
                    .foregroundStyle(session.category.thumbnailColor)
            }

            Text("Audio coming soon")
                .font(UntiltTheme.Font.body)
                .foregroundStyle(.white.opacity(0.6))

            // Mark complete manually while content is not yet produced
            Button {
                recordCompletion()
                dismiss()
            } label: {
                Text("Mark as completed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, UntiltTheme.Spacing.s6)
                    .padding(.vertical, UntiltTheme.Spacing.s3)
                    .background(UntiltTheme.Color.lavender700)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - AVPlayer setup
    private func setupPlayer() {
        guard let url = session.contentURL else { return }
        let avPlayer = AVPlayer(url: url)
        player = avPlayer

        // Observe playback to end
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            recordCompletion()
        }
    }

    private func recordCompletion() {
        guard !completed else { return }
        completed = true
        let record = MeditationCompletion(
            sessionID: session.id,
            sessionTitle: session.title,
            durationMinutes: session.durationMinutes
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}

#Preview {
    MeditationsTabView()
        .modelContainer(for: [MeditationCompletion.self], inMemory: true)
}
