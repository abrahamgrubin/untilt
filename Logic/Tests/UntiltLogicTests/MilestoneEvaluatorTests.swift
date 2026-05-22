import XCTest
@testable import UntiltLogic

final class MilestoneEvaluatorTests: XCTestCase {

    func test_7DaysClean_noneEarned_returnsDay7() {
        let result = MilestoneEvaluator.newlyUnlocked(daysClean: 7, alreadyEarned: [])
        XCTAssertEqual(result, [.day7])
    }

    func test_7DaysClean_day7AlreadyEarned_returnsEmpty() {
        let result = MilestoneEvaluator.newlyUnlocked(daysClean: 7, alreadyEarned: [.day7])
        XCTAssertTrue(result.isEmpty)
    }

    func test_91DaysClean_noneEarned_returnsAllFourMilestones() {
        let result = MilestoneEvaluator.newlyUnlocked(daysClean: 91, alreadyEarned: [])
        XCTAssertEqual(Set(result), [.day7, .day30, .day60, .day90])
    }

    func test_0DaysClean_returnsEmpty() {
        let result = MilestoneEvaluator.newlyUnlocked(daysClean: 0, alreadyEarned: [])
        XCTAssertTrue(result.isEmpty)
    }
}
