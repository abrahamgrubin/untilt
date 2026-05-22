import Foundation

public struct StreakCalculator {

    public struct Result {
        public let daysClean: Int
        public let currentStreak: Int
        public let slipDays: [Date]
        public let nextMilestone: MilestoneType
        public let progressToNextMilestone: Double
    }

    public static func calculate(
        sobrietyStartDate: Date,
        urgeEvents: [UrgeEventRecord],
        today: Date = Date()
    ) -> Result {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let startOfSobriety = calendar.startOfDay(for: sobrietyStartDate)
        let daysClean = calendar.dateComponents([.day], from: startOfSobriety, to: startOfToday).day ?? 0

        let slipDays = Set(
            urgeEvents
                .filter { !$0.completed }
                .map { calendar.startOfDay(for: $0.timestamp) }
        ).sorted()

        let currentStreak = computeCurrentStreak(daysClean: daysClean, slipDays: slipDays, today: startOfToday, calendar: calendar)
        let nextMilestone = computeNextMilestone(daysClean: daysClean)
        let progress = computeProgress(daysClean: daysClean, nextMilestone: nextMilestone)

        return Result(
            daysClean: daysClean,
            currentStreak: currentStreak,
            slipDays: slipDays,
            nextMilestone: nextMilestone,
            progressToNextMilestone: progress
        )
    }

    private static func computeCurrentStreak(daysClean: Int, slipDays: [Date], today: Date, calendar: Calendar) -> Int {
        guard !slipDays.isEmpty else { return daysClean }
        var streak = 0
        var cursor = today
        while true {
            if slipDays.contains(cursor) { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
            if streak > daysClean { break }
        }
        return streak
    }

    private static func computeNextMilestone(daysClean: Int) -> MilestoneType {
        MilestoneType.allCases.first { $0.rawValue > daysClean } ?? .year2
    }

    private static func computeProgress(daysClean: Int, nextMilestone: MilestoneType) -> Double {
        let previous = MilestoneType.allCases.last { $0.rawValue <= daysClean }
        let floor = previous?.rawValue ?? 0
        let ceiling = nextMilestone.rawValue
        guard ceiling > floor else { return 1.0 }
        return Double(daysClean - floor) / Double(ceiling - floor)
    }
}
