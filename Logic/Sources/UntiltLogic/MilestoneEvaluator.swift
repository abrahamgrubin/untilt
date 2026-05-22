import Foundation

public struct MilestoneEvaluator {

    public static func newlyUnlocked(daysClean: Int, alreadyEarned: [MilestoneType]) -> [MilestoneType] {
        let earned = Set(alreadyEarned.map(\.rawValue))
        return MilestoneType.allCases.filter { $0.rawValue <= daysClean && !earned.contains($0.rawValue) }
    }
}
