import SwiftUI
import SwiftData

// MARK: - Home View
struct HomeView: View {

    @Query private var profiles: [UserProfile]
    @Query(sort: \UrgeEvent.timestamp, order: .reverse) private var urgeEvents: [UrgeEvent]
    @Query(sort: \MeditationCompletion.timestamp, order: .reverse) private var completions: [MeditationCompletion]

    @State private var showCompass = false
    @State private var insightText: String? = nil
    @State private var insightLoading = false

    private var profile: UserProfile? { profiles.first }

    private let programLength = 30  // outer ring shows progress to next milestone

    private var dayNumber: Int {
        guard let profile else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: profile.sobrietyStartDate),
                                  to: cal.startOfDay(for: Date())).day ?? 0
    }

    private var moneySaved: String {
        guard let profile else { return "$0" }
        let weeks = Double(dayNumber) / 7.0
        let saved = weeks * profile.weeklySpend
        return String(format: "$%.0f", saved)
    }

    private var meditationMins: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completions.filter { $0.timestamp > weekAgo }.reduce(0) { $0 + $1.durationMinutes }
    }

    private var meditationProgress: Double {
        let goal = 60.0
        return min(Double(meditationMins) / goal, 1.0)
    }

    private var savingsProgress: Double {
        guard let profile, let goal = profile.savingsGoal, goal > 0 else { return 0 }
        let weeks = Double(dayNumber) / 7.0
        return min((weeks * profile.weeklySpend) / goal, 1.0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                headerView
                    .padding(.horizontal, UntiltTheme.Spacing.s5)
                    .padding(.top, UntiltTheme.Spacing.s3)
                    .padding(.bottom, UntiltTheme.Spacing.s4)
                    .background(UntiltTheme.Color.lavender100)

                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {

//                    heroRow
//                        .padding(.top, UntiltTheme.Spacing.s4)

                    crisisBanner
                        .padding(.top, UntiltTheme.Spacing.s4)
//                    liveInsightCard

                    supportButton

                    MeditationVideoShelfView()

                    quickAccessGrid

                }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
            }
        }
        .background(UntiltTheme.Color.warmWhite)
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showCompass) { CompassChatView() }
        .task { await loadInsightIfNeeded() }
    }

    // MARK: - Live Insight Card
    private var liveInsightCard: some View {
        Group {
            if insightLoading {
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl)
                    .fill(UntiltTheme.Color.white)
                    .frame(height: 140)
                    .overlay(ProgressView())
                    .overlay(RoundedRectangle(cornerRadius: UntiltTheme.Radius.xl)
                        .stroke(UntiltTheme.Color.border, lineWidth: 0.5))
            } else if let text = insightText {
                InsightCardView(
                    time: "Today's insight",
                    title: String(text.prefix(80)),
                    bodyText: text.count > 80 ? String(text.dropFirst(80)) : "",
                    bulletPoints: [],
                    closingQuestion: ""
                )
            } else {
                InsightCardView(
                    time: "Today's insight",
                    title: "Check in with yourself today",
                    bodyText: "How are you feeling right now? Tap Ask Compass to reflect.",
                    bulletPoints: [],
                    closingQuestion: "What's one small thing you're proud of today?"
                )
            }
        }
    }

    private func loadInsightIfNeeded() async {
        // Cache key: "compass_insight_YYYY-MM-DD"
        let dateKey = "compass_insight_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        if let cached = UserDefaults.standard.string(forKey: dateKey) {
            insightText = cached
            return
        }
        guard !insightLoading else { return }
        insightLoading = true
        do {
            let context = buildQuickContext()
            let text = try await CompassService.shared.generateInsight(context: context)
            insightText = text
            UserDefaults.standard.set(text, forKey: dateKey)
        } catch {
            // Fall through to fallback card
        }
        insightLoading = false
    }

    private func buildQuickContext() -> String {
        let resisted = urgeEvents.filter { $0.completed }.count
        let slipped  = urgeEvents.filter { !$0.completed }.count
        return """
        Days without a bet: \(dayNumber)
        Recent urge events: \(urgeEvents.count) (\(resisted) resisted, \(slipped) slipped)
        Meditation minutes this week: \(meditationMins)
        """
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button {
                // Navigate to settings
            } label: {
                ZStack {
                    Circle()
                        .fill(UntiltTheme.Color.lavender50)
                        .frame(width: UntiltTheme.Size.avatar,
                               height: UntiltTheme.Size.avatar)
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                }
            }

            Spacer()

            Text("Untilt")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.lavender700)

            Spacer()

            ZStack {
                Circle()
                    .fill(UntiltTheme.Color.lavender700)
                    .frame(width: UntiltTheme.Size.avatar,
                           height: UntiltTheme.Size.avatar)
                Text("J")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Hero Row
    private var heroRow: some View {
        HStack(alignment: .center, spacing: UntiltTheme.Spacing.s3 + 2) {
            RecoveryRingView(
                dayNumber: dayNumber,
                programLength: 30,
                meditationProgress: meditationProgress,
                savingsProgress: savingsProgress
            )

            VStack(spacing: UntiltTheme.Spacing.s2 + 1) {
                MetricPillView(
                    icon: "checkmark.seal",
                    label: "Days clean",
                    value: "\(dayNumber)",
                    pillColor: .lavender
                )
                MetricPillView(
                    icon: "dollarsign.circle",
                    label: "Saved",
                    value: moneySaved,
                    pillColor: .sage
                )
                MetricPillView(
                    icon: "brain.head.profile",
                    label: "Mins meditating this week",
                    value: "\(meditationMins) min",
                    pillColor: .purple
                )
            }
        }
    }

    // MARK: - Crisis Banner
    private var crisisBanner: some View {
        HStack(alignment: .top, spacing: UntiltTheme.Spacing.s3) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.warning)
                .padding(.top, 1)

            Group {
                Text("In crisis? Call ") +
                Text("1-800-GAMBLER")
                    .fontWeight(.semibold) +
                Text(" or text ") +
                Text("988")
                    .fontWeight(.semibold) +
                Text(" for immediate support.")
            }
            .font(UntiltTheme.Font.caption)
            .foregroundStyle(Color(hex: "633806"))
            .lineSpacing(3)
        }
        .padding(UntiltTheme.Spacing.s3 + 2)
        .background(UntiltTheme.Color.warningBg)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                .stroke(UntiltTheme.Color.warningBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Support Button
    private var supportButton: some View {
        Button { showCompass = true } label: {
            HStack(spacing: UntiltTheme.Spacing.s2) {
                Image(systemName: "message")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                Text("Ask Compass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, UntiltTheme.Spacing.s4)
            .padding(.vertical, UntiltTheme.Spacing.s3 + 2)
            .background(UntiltTheme.Color.lavender700)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg - 2))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Access Grid
    private var quickAccessGrid: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3 - 2) {
            Text("QUICK ACCESS")
                .font(UntiltTheme.Font.overline)
                .foregroundStyle(UntiltTheme.Color.muted)
                .kerning(0.8)
                .padding(.top, UntiltTheme.Spacing.s2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: UntiltTheme.Spacing.s3 - 2) {
                QuickAccessCard(icon: "leaf",
                                label: "Meditation",
                                sub: "4 sessions available",
                                iconBg: UntiltTheme.Color.lavender50,
                                iconFg: UntiltTheme.Color.lavender700)
                QuickAccessCard(icon: "chart.line.uptrend.xyaxis",
                                label: "Progress",
                                sub: "Day \(dayNumber) streak",
                                iconBg: UntiltTheme.Color.sage50,
                                iconFg: UntiltTheme.Color.sage700)
                QuickAccessCard(icon: "books.vertical",
                                label: "Resources",
                                sub: "Helplines & therapy",
                                iconBg: UntiltTheme.Color.lavender100,
                                iconFg: UntiltTheme.Color.lavender500)
                QuickAccessCard(icon: "square.and.pencil",
                                label: "Journal",
                                sub: "Write or talk to Compass",
                                iconBg: UntiltTheme.Color.sage50,
                                iconFg: UntiltTheme.Color.sage700)
            }
        }
    }

}

// MARK: - Quick Access Card
private struct QuickAccessCard: View {
    let icon: String
    let label: String
    let sub: String
    let iconBg: Color
    let iconFg: Color

    var body: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s2) {
            ZStack {
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.sm + 2)
                    .fill(iconBg)
                    .frame(width: UntiltTheme.Size.iconContainerMd,
                           height: UntiltTheme.Size.iconContainerMd)
                Image(systemName: icon)
                    .font(.system(size: UntiltTheme.Size.iconMd, weight: .medium))
                    .foregroundStyle(iconFg)
            }

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.slate)
            Text(sub)
                .font(UntiltTheme.Font.micro)
                .foregroundStyle(UntiltTheme.Color.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(UntiltTheme.Spacing.s3 + 2)
        .background(UntiltTheme.Color.white)
        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                .stroke(UntiltTheme.Color.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Tab Bar Items
enum TabItem: String, CaseIterable, Identifiable {
    case today      = "Today"
    case meditations = "Meditations"
    case journal    = "Journal"
    case progress   = "Progress"
    case resources  = "Resources"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today:       return "house"
        case .meditations: return "figure.mind.and.body"
        case .journal:     return "square.and.pencil"
        case .progress:    return "chart.line.uptrend.xyaxis"
        case .resources:   return "books.vertical"
        }
    }

    var activeIcon: String {
        switch self {
        case .today:       return "house.fill"
        case .meditations: return "figure.mind.and.body.circle.fill"
        case .journal:     return "square.and.pencil.circle.fill"
        case .progress:    return "chart.line.uptrend.xyaxis"
        case .resources:   return "books.vertical.fill"
        }
    }
}

struct TabBarItem: View {
    let tab: TabItem
    let isActive: Bool

    var body: some View {
        VStack(spacing: UntiltTheme.Spacing.s1 - 1) {
            Image(systemName: isActive ? tab.activeIcon : tab.icon)
                .font(.system(size: 22))
                .foregroundStyle(isActive
                    ? UntiltTheme.Color.lavender700
                    : UntiltTheme.Color.muted)
            Text(tab.rawValue)
                .font(UntiltTheme.Font.micro)
                .foregroundStyle(isActive
                    ? UntiltTheme.Color.lavender700
                    : UntiltTheme.Color.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
}
//
//  HomeView.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//

