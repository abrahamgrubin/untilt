import AuthenticationServices
import SwiftUI

/// Sign-in gate shown before onboarding/the main app. Email/password,
/// Sign in with Apple and Google, all through Supabase Auth — see
/// AuthService and docs/adr/0004-leave-aws.md.
struct SignInView: View {
    @ObservedObject private var auth = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        ScrollView {
            VStack(spacing: UntiltTheme.Spacing.s5) {
                Image(systemName: "compass.drawing")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(UntiltTheme.Color.lavender700)
                    .padding(.top, UntiltTheme.Spacing.s10)

                VStack(spacing: UntiltTheme.Spacing.s2) {
                    Text("Welcome to Untilt")
                        .font(UntiltTheme.Font.heading2)
                        .foregroundStyle(UntiltTheme.Color.slate)
                    Text(isCreatingAccount ? "Create an account to get started" : "Sign in to get started")
                        .font(UntiltTheme.Font.body)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }

                emailForm

                divider

                providerButtons

                if let errorMessage {
                    message(errorMessage, color: UntiltTheme.Color.error)
                }
                if let infoMessage {
                    message(infoMessage, color: UntiltTheme.Color.sage700)
                }
            }
            .padding(.horizontal, UntiltTheme.Spacing.s5)
            .padding(.bottom, UntiltTheme.Spacing.s5)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UntiltTheme.Color.warmWhite)
    }

    // MARK: - Email / password

    private var emailForm: some View {
        VStack(spacing: UntiltTheme.Spacing.s3) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .inputStyle()

            SecureField("Password", text: $password)
                .textContentType(isCreatingAccount ? .newPassword : .password)
                .inputStyle()

            Button {
                submitEmail()
            } label: {
                HStack {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(isCreatingAccount ? "Create Account" : "Sign In")
                            .font(UntiltTheme.Font.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: UntiltTheme.Size.buttonHeight)
                .background(UntiltTheme.Color.lavender700.opacity(canSubmit ? 1 : 0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
            }
            .disabled(!canSubmit)

            Button {
                isCreatingAccount.toggle()
                errorMessage = nil
                infoMessage = nil
            } label: {
                Text(isCreatingAccount ? "Already have an account? Sign in" : "New here? Create an account")
                    .font(UntiltTheme.Font.bodySmall)
                    .foregroundStyle(UntiltTheme.Color.lavender700)
            }
        }
    }

    private var divider: some View {
        HStack(spacing: UntiltTheme.Spacing.s3) {
            Rectangle().fill(UntiltTheme.Color.border).frame(height: 1)
            Text("or")
                .font(UntiltTheme.Font.caption)
                .foregroundStyle(UntiltTheme.Color.muted)
            Rectangle().fill(UntiltTheme.Color.border).frame(height: 1)
        }
    }

    // MARK: - Apple / Google

    private var providerButtons: some View {
        VStack(spacing: UntiltTheme.Spacing.s3) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email]
                request.nonce = auth.prepareAppleSignIn()
            } onCompletion: { result in
                handleApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: UntiltTheme.Size.buttonHeight)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))

            if AppConfig.googleSignInEnabled {
                Button {
                    run { try await auth.signInWithGoogle() }
                } label: {
                    Text("Continue with Google")
                        .font(UntiltTheme.Font.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: UntiltTheme.Size.buttonHeight)
                        .foregroundStyle(UntiltTheme.Color.slate)
                        .background(UntiltTheme.Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: UntiltTheme.Radius.lg)
                                .stroke(UntiltTheme.Color.border, lineWidth: 1)
                        )
                }
                .disabled(isWorking)
            }
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(UntiltTheme.Font.caption)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func submitEmail() {
        let email = email.trimmingCharacters(in: .whitespaces)
        if isCreatingAccount {
            run {
                if try await auth.signUp(email: email, password: password) == .confirmationRequired {
                    infoMessage = "Check your email to confirm your account, then sign in."
                    isCreatingAccount = false
                }
            }
        } else {
            run { try await auth.signIn(email: email, password: password) }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            run { try await auth.signInWithApple(credential) }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Sign in with Apple didn't go through. Please try again."
            }
        }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            do {
                try await action()
            } catch AuthError.cancelled {
                // User dismissed the sheet — not an error worth surfacing.
            } catch AuthError.server(_, let message?) {
                errorMessage = message
            } catch {
                errorMessage = "Sign-in didn't go through. Please try again."
            }
            isWorking = false
        }
    }
}

private extension View {
    func inputStyle() -> some View {
        font(UntiltTheme.Font.body)
            .padding(.horizontal, UntiltTheme.Spacing.s3)
            .frame(height: UntiltTheme.Size.inputHeight)
            .background(UntiltTheme.Color.warmGray)
            .clipShape(RoundedRectangle(cornerRadius: UntiltTheme.Radius.md))
    }
}

#Preview {
    SignInView()
}
