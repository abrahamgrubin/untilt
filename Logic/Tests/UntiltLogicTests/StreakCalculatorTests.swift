import XCTest
import Foundation
@testable import UntiltLogic

final class StreakCalculatorTests: XCTestCase {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int, from base: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -n, to: base)!
    }

    // MARK: - Slip days

    func test_completedUrgeEvents_produceNoSlipDays() {
        let today = Date()
        let events = [UrgeEventRecord(timestamp: daysAgo(3, from: today), completed: true)]
        let result = StreakCalculator.calculate(sobrietyStartDate: daysAgo(7, from: today), urgeEvents: events, today: today)
        XCTAssertTrue(result.slipDays.isEmpty)
    }

    func test_abandonedUrgeEvent_producesOneSlipDay() {
        let today = Date()
        let events = [UrgeEventRecord(timestamp: daysAgo(2, from: today), completed: false)]
        let result = StreakCalculator.calculate(sobrietyStartDate: daysAgo(7, from: today), urgeEvents: events, today: today)
        XCTAssertEqual(result.slipDays.count, 1)
    }

    func test_multipleAbandonedEventsOnSameDay_countAsOneSlipDay() {
        let today = Date()
        let slipDay = daysAgo(2, from: today)
        let events = [
            UrgeEventRecord(timestamp: slipDay, completed: false),
            UrgeEventRecord(timestamp: slipDay, completed: false),
        ]
        let result = StreakCalculator.calculate(sobrietyStartDate: daysAgo(7, from: today), urgeEvents: events, today: today)
        XCTAssertEqual(result.slipDays.count, 1)
    }

    // MARK: - Milestone progress

    func test_day6of7_progressToNextMilestoneIsCorrect() {
        let today = Date()
        let result = StreakCalculator.calculate(sobrietyStartDate: daysAgo(6, from: today), urgeEvents: [], today: today)
        XCTAssertEqual(result.nextMilestone, .day7)
        XCTAssertEqual(result.progressToNextMilestone, 6.0 / 7.0, accuracy: 0.001)
    }

    func test_exactlyAtMilestone_progressResetsToZeroTowardNext() {
        let today = Date()
        let result = StreakCalculator.calculate(sobrietyStartDate: daysAgo(7, from: today), urgeEvents: [], today: today)
        XCTAssertEqual(result.nextMilestone, .day30)
        XCTAssertEqual(result.progressToNextMilestone, 0.0, accuracy: 0.001)
    }

    // MARK: - Tracer bullet

    func test_sobrietyStartIsToday_daysCleanIsZero() {
        let today = Date()
        let result = StreakCalculator.calculate(sobrietyStartDate: today, urgeEvents: [], today: today)
        XCTAssertEqual(result.daysClean, 0)
    }

    func test_noUrgeEvents_daysCleanEqualsDaysSinceSobrietyStart() {
        let today = Date()
        let result = StreakCalculator.calculate(
            sobrietyStartDate: daysAgo(7, from: today),
            urgeEvents: [],
            today: today
        )
        XCTAssertEqual(result.daysClean, 7)
    }
}
