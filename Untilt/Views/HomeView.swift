import SwiftUI

// MARK: - Home View
// Main dashboard screen. Matches the Fitbit-inspired layout from the prototype:
//   1. Header (top nav)
//   2. Hero row (recovery ring + metric pills)
//   3. Crisis banner
//   4. Daily insight card
//   5. Talk to support CTA
//   6. Meditation video shelf
//   7. Quick access grid

struct HomeView: View {

    // In a real app these would come from a ViewModel / AppState
    let dayNumber: Int          = 23
    let programLength: Int      = 90
    let moneySaved: String      = "$1,840"
    let meditationMins: Int     = 47
    let meditationProgress: Double = 0.65   // weekly goal progress
    let savingsProgress: Double    = 0.46   // toward 90-day savings goal

    var body: some View {
        ZStack(alignment: .bottom) {
            UntiltTheme.Color.warmWhite
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    headerView
                        .padding(.horizontal, UntiltTheme.Spacing.s5)
                        .padding(.top, UntiltTheme.Spacing.s3)
                        .padding(.bottom, UntiltTheme.Spacing.s4)
                        .background(UntiltTheme.Color.lavender100)

                    VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {

                        heroRow
                            .padding(.top, UntiltTheme.Spacing.s4)

                        crisisBanner

                        InsightCardView(
                            time: "Today's insight · 9:00 AM",
                            title: "You resisted an urge during last night's game",
                            bodyText: "You opened DraftKings at 8:43 PM but completed your meditation session and returned to the home screen — a significant shift from three weeks ago.",
                            bulletPoints: [
                                "Your longest urge-free streak this week was 51 hours.",
                                "You have meditated every day this week — your most consistent week yet."
                            ],
                            closingQuestion: "Are you noticing a difference in how you feel on days when you meditate?"
                        )

                        supportButton

                        MeditationVideoShelfView()

                        quickAccessGrid

                    }
                    .padding(.horizontal, UntiltTheme.Spacing.s5)
                    .padding(.bottom, UntiltTheme.Size.navBarHeight + UntiltTheme.Spacing.s4)
                }
            }

            tabBar
        }
        .ignoresSafeArea(edges: .bottom)
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
                programLength: programLength,
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
        Button {
            // Navigate to chatbot
        } label: {
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

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack {
            ForEach(TabItem.allCases) { tab in
                TabBarItem(tab: tab, isActive: tab == .today)
            }
        }
        .padding(.horizontal, UntiltTheme.Spacing.s2)
        .frame(height: UntiltTheme.Size.navBarHeight)
        .background(UntiltTheme.Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(UntiltTheme.Color.border)
                .frame(height: 0.5)
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
    case today     = "Today"
    case support   = "Meditations"
    case progress  = "Progress"
    case resources = "Resources"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today:     return "house"
        case .support:   return "figure.mind.and.body"
        case .progress:  return "chart.line.uptrend.xyaxis"
        case .resources: return "books.vertical"
        }
    }

    var activeIcon: String {
        switch self {
        case .today:     return "house.fill"
        case .support:   return "figure.mind.and.body.circle.fill"
        case .progress:  return "chart.line.uptrend.xyaxis"
        case .resources: return "books.vertical.fill"
        }
    }
}

private struct TabBarItem: View {
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

