import SwiftUI

/// Sign-in gate shown before onboarding/the main app. Launches Cognito's
/// Hosted UI, which itself presents the Apple/Google/email choice — see
/// AuthService and docs/adr/0003-backend-migration.md for why auth moved
/// off-device.
struct SignInView: View {
    @ObservedObject private var auth = AuthService.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: UntiltTheme.Spacing.s5) {
            Spacer()

            Image(systemName: "compass.drawing")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(UntiltTheme.Color.lavender700)

            VStack(spacing: UntiltTheme.Spacing.s2) {
                Text("Welcome to Untilt")
                    .font(UntiltTheme.Font.heading2)
                    .foregroundStyle(UntiltTheme.Color.slate)
                Text("Sign in to get started")
                    .font(UntiltTheme.Font.body)
                    .foregroundStyle(UntiltTheme.Color.muted)
            }

            Spacer()

            VStack(spacing: UntiltTheme.Spacing.s3) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(UntiltTheme.Color.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, UntiltTheme.Spacing.s4)
                }

                Button {
                    signIn()
                } label: {
                    HStack {
                        if isSigningIn {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In")
                                .font(UntiltTheme.Font.body.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, UntiltTheme.Spacing.s3)
                    .background(UntiltTheme.Color.lavender700)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
                }
                .disabled(isSigningIn)
                .padding(.horizontal, UntiltTheme.Spacing.s5)

                Text("Apple, Google, or email — you'll choose on the next screen.")
                    .font(UntiltTheme.Font.micro)
                    .foregroundStyle(UntiltTheme.Color.muted)
            }
            .padding(.bottom, UntiltTheme.Spacing.s5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntiltTheme.Color.warmWhite)
    }

    private func signIn() {
        errorMessage = nil
        isSigningIn = true
        Task {
            do {
                try await auth.signIn()
            } catch AuthError.cancelled {
                // User dismissed the sheet — not an error worth surfacing.
            } catch {
                errorMessage = "Sign-in didn't go through. Please try again."
            }
            isSigningIn = false
        }
    }
}

#Preview {
    SignInView()
}
