import Foundation

public struct SavingsCalculator {

    public struct Result {
        public let totalSaved: Double
        public let goalProgress: Double?
    }

    public static func calculate(
        weeklySpend: Double,
        sobrietyStartDate: Date,
        savingsGoal: Double? = nil,
        today: Date = Date()
    ) -> Result {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: sobrietyStartDate)
        let end = calendar.startOfDay(for: today)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        let weeksClean = Double(days) / 7.0
        let totalSaved = weeksClean * weeklySpend

        let goalProgress: Double? = savingsGoal.map { goal in
            guard goal > 0 else { return 0 }
            return min(totalSaved / goal, 1.0)
        }

        return Result(totalSaved: totalSaved, goalProgress: goalProgress)
    }
}
