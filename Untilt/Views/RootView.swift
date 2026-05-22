import SwiftUI

/// Root view after onboarding. Manages the 5-tab navigation shell.
struct RootView: View {
    @State private var selectedTab: TabItem = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .ignoresSafeArea(edges: .bottom)

            tabBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today:
            HomeView()
        case .meditations:
            MeditationsTabView()
        case .journal:
            NavigationStack { JournalView() }
        case .progress:
            ProgressTabView()
        case .resources:
            ResourcesView()
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(TabItem.allCases) { tab in
                TabBarItem(tab: tab, isActive: selectedTab == tab)
                    .onTapGesture { selectedTab = tab }
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

// MARK: - Placeholder
struct PlaceholderView: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: UntiltTheme.Spacing.s4) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(UntiltTheme.Color.lavender500)
            Text(title)
                .font(UntiltTheme.Font.heading2)
                .foregroundStyle(UntiltTheme.Color.slate)
            Text("Coming soon")
                .font(UntiltTheme.Font.body)
                .foregroundStyle(UntiltTheme.Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntiltTheme.Color.warmWhite)
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    RootView()
}
