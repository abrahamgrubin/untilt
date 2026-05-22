//
//  UntiltApp.swift
//  Untilt
//
//  Created by Abraham Rubin on 5/11/26.
//

import SwiftUI
import SwiftData

@main
struct UntiltApp: App {

    let container: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            UrgeEvent.self,
            JournalEntry.self,
            MeditationCompletion.self,
            MilestoneRecord.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var gateTriggered = false

    var body: some Scene {
        WindowGroup {
            if gateTriggered {
                MindfulGateView {
                    gateTriggered = false
                }
                .modelContainer(container)
            } else {
                ContentView()
                    .modelContainer(container)
                    .onOpenURL { url in
                        handleIncomingURL(url)
                    }
            }
        }
    }

    /// Handles untilt://gate?returnURL=<encoded-url> launched by the iOS Shortcut.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "untilt", url.host == "gate" else { return }
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let returnItem = components.queryItems?.first(where: { $0.name == "returnURL" }),
           let returnURLString = returnItem.value {
            UserDefaults.standard.set(returnURLString, forKey: "returnAppURL")
        }
        gateTriggered = true
    }
}
