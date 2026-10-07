import SwiftData
import SwiftUI

/// Account, privacy and Compass settings, opened from the gear on Today.
/// Holds the in-app account deletion App Store Guideline 5.1.1(v) requires.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var auth = AuthService.shared
    @AppStorage(CompassConsent.storageKey) private var compassEnabled = false

    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showConsent = false
    @State private var confirmCompassOff = false
    @State private var compassError: String?

    /// Turning Compass on goes through the full consent screen; turning it
    /// off asks whether to also delete its history (withdrawing consent).
    private var compassToggle: Binding<Bool> {
        Binding(
            get: { compassEnabled },
            set: { on in
                if on { showConsent = true } else { confirmCompassOff = true }
            }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if let email = auth.email {
                        LabeledContent("Signed in as", value: email)
                            .font(UntiltTheme.Font.bodySmall)
                    }
                    Button("Sign Out") { confirmSignOut = true }
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                }

                Section {
                    Toggle("Compass AI coach", isOn: compassToggle)
                        .tint(UntiltTheme.Color.lavender700)
                } header: {
                    Text("Compass")
                } footer: {
                    if let compassError {
                        Text(compassError).foregroundStyle(UntiltTheme.Color.error)
                    } else {
                        Text("When on, your Compass messages, notes from past chats and recent activity are sent to Anthropic's Claude through Untilt's server to write replies, check for signs of crisis and keep Compass's notes. Turning it off stops Compass chats and daily insights.")
                    }
                }

                Section("Privacy & Support") {
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    Link("Contact Support", destination: AppConfig.supportURL)
                }

                Section {
                    Text("Untilt and Compass support recovery but aren't a substitute for professional treatment. If you're in crisis, call 1-800-522-4700 or text 988.")
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        HStack {
                            Text("Delete Account")
                            Spacer()
                            if isDeleting { ProgressView() }
                        }
                    }
                    .disabled(isDeleting)
                } footer: {
                    if let deleteError {
                        Text(deleteError).foregroundStyle(UntiltTheme.Color.error)
                    } else {
                        Text("Permanently deletes your account, Compass conversations and notes from our servers, and all Untilt data on this iPhone.")
                    }
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                        .font(UntiltTheme.Font.caption)
                        .foregroundStyle(UntiltTheme.Color.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(UntiltTheme.Color.warmWhite)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(UntiltTheme.Color.lavender700)
                }
            }
            .confirmationDialog("Sign out of Untilt?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
            } message: {
                Text("Your history stays on this iPhone for when you sign back in. If a different account signs in, it's erased.")
            }
            .confirmationDialog("Turn off Compass?", isPresented: $confirmCompassOff, titleVisibility: .visible) {
                Button("Turn Off and Delete History", role: .destructive) { turnOffCompass(deleteHistory: true) }
                Button("Turn Off, Keep History") { turnOffCompass(deleteHistory: false) }
            } message: {
                Text("Nothing more is sent to Anthropic. You can also delete Compass's conversations and notes from Untilt's servers.")
            }
            .sheet(isPresented: $showConsent) {
                CompassConsentView(
                    onAgree: {
                        compassEnabled = true
                        showConsent = false
                    },
                    onDecline: { showConsent = false }
                )
            }
            .alert("Delete your account?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all your Untilt data, on our servers and on this iPhone. It can't be undone.\n\nIf you signed in with Apple, you can also remove Untilt under Settings › Apple Account › Sign in with Apple.")
            }
        }
    }

    private func deleteAccount() {
        deleteError = nil
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await BackendService.shared.deleteAccount()
                LocalDataStore.eraseForDeletedAccount(context: modelContext)
                auth.signOut()
            } catch AuthError.signedOut {
                // The session can't be refreshed: the usual cause is that an
                // earlier attempt deleted the login and its reply was lost.
                // Erase on-device data either way, as the dialog promised.
                LocalDataStore.eraseForDeletedAccount(context: modelContext)
            } catch BackendService.AccountDeletionError.partial {
                // Server data is already gone, so the phone's copy goes too.
                LocalDataStore.eraseForDeletedAccount(context: modelContext)
                deleteError = "Your data was deleted, but we couldn't finish removing your login. Please try again."
            } catch BackendService.AccountDeletionError.unavailable {
                deleteError = "Account deletion is temporarily unavailable. Please try again later or contact support."
            } catch {
                deleteError = "Couldn't delete your account. Check your connection and try again."
            }
        }
    }

    private func turnOffCompass(deleteHistory: Bool) {
        compassError = nil
        compassEnabled = false
        DailyInsightCache.clear()
        guard deleteHistory else { return }
        Task {
            do {
                try await BackendService.shared.deleteCompassData()
            } catch {
                compassError = "Compass is off, but its history couldn't be deleted. Turn it on and off again to retry."
            }
        }
    }
}

#Preview {
    SettingsView()
}
