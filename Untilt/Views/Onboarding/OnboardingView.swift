import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Onboarding Step Machine
enum OnboardingStep {
    case welcome
    case sobrietyDate
    case weeklySpend
    case gateSetup
    case done
}

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step: OnboardingStep = .welcome
    @State private var sobrietyDate: Date = Date()
    @State private var weeklySpend: String = ""
    @State private var appleUserID: String = ""
    @State private var authError: String?
    @State private var selectedGatingApps: Set<GamblingApp> = []

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            UntiltTheme.Color.warmWhite.ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeStep(
                    onSignInWithApple: handleSignIn,
                    onDevBypass: {
                        // Simulator only — Sign in with Apple requires a passcode
                        // which simulators cannot set. This path is compiled out on
                        // real devices via #if targetEnvironment(simulator).
                        appleUserID = "dev-sim-\(UUID().uuidString.prefix(8))"
                        authError = nil
                        withAnimation { step = .sobrietyDate }
                    },
                    authError: authError
                )
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .sobrietyDate:
                SobrietyDateStep(date: $sobrietyDate) {
                    withAnimation { step = .weeklySpend }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .weeklySpend:
                WeeklySpendStep(spend: $weeklySpend) {
                    withAnimation { step = .gateSetup }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .gateSetup:
                GateSetupView(
                    selectedApps: $selectedGatingApps,
                    onSkip: { saveProfileAndFinish(gateConfigured: false) },
                    onContinue: { saveProfileAndFinish(gateConfigured: true) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .done:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Sign in with Apple
    private func handleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            appleUserID = credential.user
            authError = nil
            withAnimation { step = .sobrietyDate }
        case .failure(let error):
            authError = error.localizedDescription
        }
    }

    // MARK: - Persist and exit onboarding
    private func saveProfileAndFinish(gateConfigured: Bool = false) {
        let spend = Double(weeklySpend.filter { $0.isNumber || $0 == "." }) ?? 0
        let profile = UserProfile(
            appleUserID: appleUserID,
            sobrietyStartDate: sobrietyDate,
            weeklySpend: spend
        )
        profile.gatedApps = selectedGatingApps.map(\.id)
        profile.gateConfigured = gateConfigured
        modelContext.insert(profile)
        try? modelContext.save()
        withAnimation { onComplete() }
    }
}

// MARK: - Welcome Step
private struct WelcomeStep: View {
    let onSignInWithApple: (Result<ASAuthorization, Error>) -> Void
    let onDevBypass: () -> Void
    let authError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: UntiltTheme.Spacing.s4) {
                ZStack {
                    Circle()
                        .fill(UntiltTheme.Color.lavender100)
                        .frame(width: 96, height: 96)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                }

                VStack(spacing: UntiltTheme.Spacing.s2) {
                    Text("Welcome to Untilt")
                        .font(UntiltTheme.Font.heading1)
                        .foregroundStyle(UntiltTheme.Color.slate)

                    Text("A mindfulness companion for your recovery journey. One moment at a time.")
                        .font(UntiltTheme.Font.body)
                        .foregroundStyle(UntiltTheme.Color.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, UntiltTheme.Spacing.s6)
                }
            }

            Spacer()

            VStack(spacing: UntiltTheme.Spacing.s3) {
                // ── Real-device path ──────────────────────────────────────
                // Sign in with Apple requires a device passcode, which iOS
                // Simulator cannot set. On simulator we show a dev bypass
                // button instead so you can test the full onboarding flow.
                // The #if block is stripped from release builds entirely.
#if targetEnvironment(simulator)
                Button(action: onDevBypass) {
                    HStack(spacing: UntiltTheme.Spacing.s2) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 17, weight: .medium))
                        Text("Continue (Simulator)")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: UntiltTheme.Size.buttonHeight)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
                }
                .buttonStyle(.plain)

                Text("Dev bypass — Sign in with Apple is unavailable in Simulator")
                    .font(UntiltTheme.Font.micro)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .multilineTextAlignment(.center)
#else
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    onSignInWithApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: UntiltTheme.Size.buttonHeight)
                .cornerRadius(UntiltTheme.Radius.lg)

                if let error = authError {
                    Text(error)
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(UntiltTheme.Color.error)
                        .multilineTextAlignment(.center)
                }

                Text("By continuing, you agree to our Terms and Privacy Policy.")
                    .font(UntiltTheme.Font.micro)
                    .foregroundStyle(UntiltTheme.Color.muted)
                    .multilineTextAlignment(.center)
#endif
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s8)
        }
    }
}

// MARK: - Sobriety Date Step
private struct SobrietyDateStep: View {
    @Binding var date: Date
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 1, of: 3, title: "When did you last gamble?",
                             subtitle: "This sets your Days Clean counter. Be honest — only you can see this.")

            DatePicker(
                "Last gambling date",
                selection: $date,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .accentColor(UntiltTheme.Color.lavender700)

            Spacer()

            PrimaryButton(label: "Continue") { onContinue() }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.bottom, UntiltTheme.Spacing.s8)
        }
    }
}

// MARK: - Weekly Spend Step
private struct WeeklySpendStep: View {
    @Binding var spend: String
    let onContinue: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 2, of: 3,
                             title: "How much did you spend gambling per week?",
                             subtitle: "An estimate is fine. This lets Untilt calculate how much you're saving.")

            HStack(alignment: .firstTextBaseline, spacing: UntiltTheme.Spacing.s2) {
                Text("$")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.lavender700)
                TextField("0", text: $spend)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(UntiltTheme.Color.slate)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .frame(maxWidth: 200)
            }
            .padding(.top, UntiltTheme.Spacing.s8)
            .padding(.horizontal, UntiltTheme.Spacing.s5)

            Text("per week")
                .font(UntiltTheme.Font.body)
                .foregroundStyle(UntiltTheme.Color.muted)
                .padding(.top, UntiltTheme.Spacing.s2)

            Spacer()

            PrimaryButton(label: "Get started") { onContinue() }
                .padding(.horizontal, UntiltTheme.Spacing.s5)
                .padding(.bottom, UntiltTheme.Spacing.s8)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Shared components
struct OnboardingHeader: View {
    let step: Int
    let of: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: UntiltTheme.Spacing.s2) {
            Text("Step \(step) of \(of)")
                .font(UntiltTheme.Font.caption)
                .foregroundStyle(UntiltTheme.Color.lavender500)

            Text(title)
                .font(UntiltTheme.Font.heading2)
                .foregroundStyle(UntiltTheme.Color.slate)
                .lineSpacing(3)

            Text(subtitle)
                .font(UntiltTheme.Font.bodySmall)
                .foregroundStyle(UntiltTheme.Color.muted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, UntiltTheme.Spacing.s5)
        .padding(.top, UntiltTheme.Spacing.s6)
        .padding(.bottom, UntiltTheme.Spacing.s4)
    }
}

struct PrimaryButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: UntiltTheme.Size.buttonHeight)
                .background(UntiltTheme.Color.lavender700)
                .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
        }
        .buttonStyle(.plain)
    }
}
