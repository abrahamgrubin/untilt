import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @State private var onboardingComplete = false

    private var hasProfile: Bool { !profiles.isEmpty }

    var body: some View {
        Group {
            if hasProfile || onboardingComplete {
                RootView()
            } else {
                OnboardingView {
                    onboardingComplete = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasProfile)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, UrgeEvent.self,
                               JournalEntry.self, MeditationCompletion.self,
                               MilestoneRecord.self], inMemory: true)
}

