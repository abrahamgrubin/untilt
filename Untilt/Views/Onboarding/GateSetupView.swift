import SwiftUI

// MARK: - Gambling apps the user can gate
struct GamblingApp: Identifiable, Hashable {
    let id: String          // bundle ID (informational)
    let name: String
    let icon: String        // SF Symbol approximation
}

extension GamblingApp {
    static let suggestions: [GamblingApp] = [
        GamblingApp(id: "com.draftkings.sportsbook",   name: "DraftKings",    icon: "crown.fill"),
        GamblingApp(id: "com.fanduel.sportsbook",      name: "FanDuel",       icon: "bolt.fill"),
        GamblingApp(id: "com.betmgm.sportsbook",       name: "BetMGM",        icon: "m.circle.fill"),
        GamblingApp(id: "com.caesars.sportsbook",      name: "Caesars",       icon: "c.circle.fill"),
        GamblingApp(id: "com.pointsbet.sportsbook",    name: "PointsBet",     icon: "p.circle.fill"),
        GamblingApp(id: "com.barstool.sportsbook",     name: "Barstool",      icon: "b.circle.fill"),
        GamblingApp(id: "com.williamhill.sportsbook",  name: "William Hill",  icon: "w.circle.fill"),
        GamblingApp(id: "com.bet365.sportsbook",       name: "bet365",        icon: "3.circle.fill"),
    ]
}

// MARK: - Gate Setup View (Onboarding step 3)
struct GateSetupView: View {
    @Binding var selectedApps: Set<GamblingApp>
    var onSkip: () -> Void
    var onContinue: () -> Void

    @State private var step: GateStep = .explain

    enum GateStep { case explain, select, confirm }

    var body: some View {
        ZStack {
            UntiltTheme.Color.warmWhite.ignoresSafeArea()
            switch step {
            case .explain:  explainStep
            case .select:   selectStep
            case .confirm:  confirmStep
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: Explain
    private var explainStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                step: 3, of: 3,
                title: "Set up the Mindful Gate",
                subtitle: "The gate intercepts gambling apps before you open them, giving you a moment to breathe and reconsider."
            )

            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s4) {
                ExplainRow(icon: "arrow.triangle.branch",
                           title: "How it works",
                           detail: "An iOS Shortcut routes you through a 2-minute breathing exercise whenever you try to open a gambling app.")
                ExplainRow(icon: "lock.shield",
                           title: "Your choice",
                           detail: "You decide which apps are gated. You can change this anytime in Settings.")
                ExplainRow(icon: "iphone.badge.play",
                           title: "Requires iOS Shortcuts",
                           detail: "We'll walk you through the setup step by step. It takes about 2 minutes.")
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.top, UntiltTheme.Spacing.s2)

            Spacer()

            VStack(spacing: UntiltTheme.Spacing.s3) {
                PrimaryButton(label: "Set up the gate") {
                    withAnimation { step = .select }
                }
                Button("Skip for now (not recommended)") {
                    onSkip()
                }
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.muted)
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s8)
        }
    }

    // MARK: Select apps
    private var selectStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                step: 3, of: 3,
                title: "Which apps do you want to gate?",
                subtitle: "Select at least one. You can add more later."
            )

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                          spacing: UntiltTheme.Spacing.s3) {
                    ForEach(GamblingApp.suggestions) { app in
                        AppSelectionCard(
                            app: app,
                            isSelected: selectedApps.contains(app)
                        ) {
                            if selectedApps.contains(app) {
                                selectedApps.remove(app)
                            } else {
                                selectedApps.insert(app)
                            }
                        }
                    }
                }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.top, UntiltTheme.Spacing.s2)
            }

            Spacer()

            PrimaryButton(label: "Continue") {
                withAnimation { step = .confirm }
            }
            .disabled(selectedApps.isEmpty)
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s8)
        }
    }

    // MARK: Confirm + Shortcut install instructions
    private var confirmStep: some View {
        VStack(spacing: 0) {
            OnboardingHeader(
                step: 3, of: 3,
                title: "Install the Shortcut",
                subtitle: "Follow these steps in the Shortcuts app to activate your gate."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s3) {
                    InstructionStep(number: 1, text: "Open the Shortcuts app on your iPhone.")
                    InstructionStep(number: 2, text: "Tap Automation at the bottom, then tap New Automation.")
                    InstructionStep(number: 3, text: "Choose 'App' → select the gambling apps you gated → tap Done.")
                    InstructionStep(number: 4, text: "Tap Add Action → search for 'Open App' → select Untilt.")
                    InstructionStep(number: 5, text: "Turn off 'Ask Before Running' and save.")

                    Text("Your gate is now active for: \(selectedApps.map(\.name).joined(separator: ", "))")
                        .font(UntiltTheme.Font.bodySmall)
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                        .padding(UntiltTheme.Spacing.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(UntiltTheme.Color.lavender50)
                        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.md))
                        .padding(.top, UntiltTheme.Spacing.s2)
                }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.top, UntiltTheme.Spacing.s2)
            }

            Spacer()

            PrimaryButton(label: "My gate is active — let's go!") {
                onContinue()
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s8)
        }
    }
}

// MARK: - Supporting views
private struct ExplainRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: UntiltTheme.Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(UntiltTheme.Color.lavender700)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(UntiltTheme.Color.slate)
                Text(detail).font(UntiltTheme.Font.bodySmall).foregroundStyle(UntiltTheme.Color.muted).lineSpacing(3)
            }
        }
    }
}

private struct AppSelectionCard: View {
    let app: GamblingApp
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: UntiltTheme.Spacing.s2) {
                ZStack {
                    RoundedRectangle(cornerRadius: UntiltTheme.Radius.md)
                        .fill(isSelected ? UntiltTheme.Color.lavender50 : UntiltTheme.Color.warmGray)
                        .frame(width: 48, height: 48)
                    Image(systemName: app.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.muted)
                }
                Text(app.name)
                    .font(UntiltTheme.Font.caption)
                    .foregroundStyle(isSelected ? UntiltTheme.Color.slate : UntiltTheme.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, UntiltTheme.Spacing.s3)
            .background(UntiltTheme.Color.white)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                    .stroke(isSelected ? UntiltTheme.Color.lavender700 : UntiltTheme.Color.border,
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: UntiltTheme.Spacing.s3) {
            ZStack {
                Circle()
                    .fill(UntiltTheme.Color.lavender700)
                    .frame(width: 26, height: 26)
                Text("\(number)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.slate)
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }
}
