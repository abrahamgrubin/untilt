import XCTest
import Foundation
@testable import UntiltLogic

final class CompassContextBuilderTests: XCTestCase {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: Date())!
    }

    func test_fullHistory_outputContainsDaysClean() {
        let output = CompassContextBuilder.build(
            daysClean: 23,
            recentUrgeEvents: [UrgeEventRecord(timestamp: daysAgo(1), completed: true)],
            recentJournalEntries: [CompassContextBuilder.JournalRecord(body: "Felt anxious", timestamp: daysAgo(1))],
            recentMeditationCompletions: [CompassContextBuilder.MeditationRecord(sessionTitle: "Box breathing", durationMinutes: 3)]
        )
        XCTAssertTrue(output.contains("23"), "Expected output to reference daysClean count")
    }

    func test_emptyHistory_returnsNonEmptyString() {
        let output = CompassContextBuilder.build(
            daysClean: 0,
            recentUrgeEvents: [],
            recentJournalEntries: [],
            recentMeditationCompletions: []
        )
        XCTAssertFalse(output.isEmpty)
    }

    func test_partialHistory_urgeEventsButNoJournal_doesNotCrash() {
        let output = CompassContextBuilder.build(
            daysClean: 5,
            recentUrgeEvents: [UrgeEventRecord(timestamp: daysAgo(1), completed: false)],
            recentJournalEntries: [],
            recentMeditationCompletions: []
        )
        XCTAssertFalse(output.isEmpty)
    }
}
