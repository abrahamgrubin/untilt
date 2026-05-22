import SwiftUI

// MARK: - Meditation Video Shelf View
// Horizontally scrolling carousel of meditation sessions with duration filter chips.

struct MeditationVideoShelfView: View {
    @State private var selectedFilter: DurationFilter = .all

    private var filteredSessions: [MeditationSession] {
        if selectedFilter == .all {
            return MeditationSession.catalogue
        }
        return MeditationSession.catalogue.filter { $0.filterBucket == selectedFilter }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Section header
            HStack {
                Text("SUGGESTED MEDITATIONS")
                    .font(UntiltTheme.Font.overline)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .kerning(0.8)
                Spacer()
                Button("See all") {}
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(UntiltTheme.Color.lavender500)
            }
            .padding(.bottom, UntiltTheme.Spacing.s3 - 2)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UntiltTheme.Spacing.s1 + 3) {
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
            }
            .padding(.bottom, UntiltTheme.Spacing.s3)

            // Video card carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UntiltTheme.Spacing.s3 - 2) {
                    ForEach(filteredSessions) { session in
                        VideoCard(session: session)
                    }
                }
                .padding(.bottom, UntiltTheme.Spacing.s2)
            }
        }
    }
}

// MARK: - Filter Chip
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
                .background(
                    isActive
                        ? UntiltTheme.Color.lavender700
                        : UntiltTheme.Color.white
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isActive
                                ? Color.clear
                                : UntiltTheme.Color.border,
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Video Card
private struct VideoCard: View {
    let session: MeditationSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail
            ZStack(alignment: .bottomTrailing) {
                Rectangle()
                    .fill(session.category.thumbnailColor)
                    .frame(width: UntiltTheme.Size.videoCardWidth,
                           height: UntiltTheme.Size.videoThumbHeight)

                // Decorative ring motif
                Circle()
                    .stroke(session.category.tagColor.opacity(0.18), lineWidth: 18)
                    .frame(width: 72, height: 72)

                // Play button
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.92))
                        .frame(width: 32, height: 32)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                        .offset(x: 1.5)
                }

                // Duration badge
                Text(session.durationLabel)
                    .font(UntiltTheme.Font.micro)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.52))
                    .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.sm - 2))
                    .padding(7)
            }
            .frame(width: UntiltTheme.Size.videoCardWidth,
                   height: UntiltTheme.Size.videoThumbHeight)
            .clipped()

            // Info zone
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1 + 2) {
                // Category tag
                Text(session.category.rawValue)
                    .font(UntiltTheme.Font.micro)
                    .foregroundStyle(session.category.tagColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(session.category.tagBackground)
                    .clipShape(Capsule())

                // Title
                Text(session.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .lineLimit(2)
                    .lineSpacing(2)

                // Meta row
                HStack(spacing: UntiltTheme.Spacing.s1) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(UntiltTheme.Color.muted)
                    Text("\(session.durationLabel) · \(session.level)")
                        .font(UntiltTheme.Font.micro)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s3 - 2)
            .padding(.top, UntiltTheme.Spacing.s3 - 2)
            .padding(.bottom, UntiltTheme.Spacing.s3)
        }
        .frame(width: UntiltTheme.Size.videoCardWidth)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
        )
    }
}

#Preview {
    MeditationVideoShelfView()
        .padding()
}
