import XCTest
import Foundation
@testable import UntiltLogic

final class SavingsCalculatorTests: XCTestCase {

    private let calendar = Calendar.current

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: Date())!
    }

    func test_oneWeekClean_savesTotalEqualToWeeklySpend() {
        let result = SavingsCalculator.calculate(weeklySpend: 100, sobrietyStartDate: daysAgo(7))
        XCTAssertEqual(result.totalSaved, 100, accuracy: 0.01)
    }

    func test_zeroSpend_savesTotalIsZero() {
        let result = SavingsCalculator.calculate(weeklySpend: 0, sobrietyStartDate: daysAgo(30))
        XCTAssertEqual(result.totalSaved, 0, accuracy: 0.01)
    }

    func test_sobrietyStartIsToday_savesTotalIsZero() {
        let today = Date()
        let result = SavingsCalculator.calculate(weeklySpend: 500, sobrietyStartDate: today, today: today)
        XCTAssertEqual(result.totalSaved, 0, accuracy: 0.01)
    }

    func test_noSavingsGoal_goalProgressIsNil() {
        let result = SavingsCalculator.calculate(weeklySpend: 100, sobrietyStartDate: daysAgo(7), savingsGoal: nil)
        XCTAssertNil(result.goalProgress)
    }

    func test_savingsGoalSet_goalProgressIsNonNil() {
        let result = SavingsCalculator.calculate(weeklySpend: 100, sobrietyStartDate: daysAgo(7), savingsGoal: 200)
        XCTAssertNotNil(result.goalProgress)
        XCTAssertEqual(result.goalProgress!, 0.5, accuracy: 0.01)
    }
}
