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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
