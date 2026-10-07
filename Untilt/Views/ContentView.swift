import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var onboardingComplete = false
    @ObservedObject private var auth = AuthService.shared
    /// The account whose on-device data has been checked (see
    /// LocalDataStore). Nothing past sign-in renders until this matches the
    /// signed-in user, so another account's history never flashes on screen.
    @State private var claimedUserId: String?

    private var hasProfile: Bool { !profiles.isEmpty }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                // Auth gate first — see docs/adr/0003-backend-migration.md.
                // Everything past this point (onboarding, RootView, Compass)
                // now depends on a real backend user existing.
                SignInView()
            } else if auth.userId == nil || claimedUserId != auth.userId {
                // Fails closed: no identity, no history on screen.
                UntiltTheme.Color.warmWhite.ignoresSafeArea()
            } else if hasProfile || onboardingComplete {
                RootView()
            } else {
                OnboardingView {
                    onboardingComplete = true
                }
            }
        }
        .task(id: auth.userId) {
            // Any change of account (including sign-out, or deleting the
            // account then signing up again) re-derives onboarding from
            // whether a profile exists, rather than trusting this launch's flag.
            onboardingComplete = false
            guard let userId = auth.userId else {
                claimedUserId = nil
                if auth.isSignedIn { auth.signOut() }  // token without a readable identity
                return
            }
            LocalDataStore.claim(for: userId, context: modelContext)
            claimedUserId = userId
        }
        .animation(.easeInOut(duration: 0.4), value: hasProfile)
        .animation(.easeInOut(duration: 0.3), value: auth.isSignedIn)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, UrgeEvent.self,
                               JournalEntry.self, MeditationCompletion.self,
                               MilestoneRecord.self], inMemory: true)
}
