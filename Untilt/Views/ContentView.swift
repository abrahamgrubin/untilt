import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var onboardingComplete = false
    @ObservedObject private var auth = AuthService.shared

    private var hasProfile: Bool { !profiles.isEmpty }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                // Auth gate first — see docs/adr/0003-backend-migration.md.
                // Everything past this point (onboarding, RootView, Compass)
                // now depends on a real backend user existing.
                SignInView()
            } else if hasProfile || onboardingComplete {
                RootView()
            } else {
                OnboardingView {
                    onboardingComplete = true
                }
            }
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

