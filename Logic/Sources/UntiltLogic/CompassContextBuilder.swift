import Foundation

public struct CompassContextBuilder {

    public struct JournalRecord {
        public let body: String
        public let timestamp: Date
        public init(body: String, timestamp: Date) {
            self.body = body
            self.timestamp = timestamp
        }
    }

    public struct MeditationRecord {
        public let sessionTitle: String
        public let durationMinutes: Int
        public init(sessionTitle: String, durationMinutes: Int) {
            self.sessionTitle = sessionTitle
            self.durationMinutes = durationMinutes
        }
    }

    public static func build(
        daysClean: Int,
        recentUrgeEvents: [UrgeEventRecord],
        recentJournalEntries: [JournalRecord],
        recentMeditationCompletions: [MeditationRecord]
    ) -> String {
        var lines: [String] = []

        lines.append("## User Recovery Context")
        lines.append("Days clean: \(daysClean)")

        let completed = recentUrgeEvents.filter(\.completed).count
        let slipped = recentUrgeEvents.filter { !$0.completed }.count
        lines.append("Recent urge events: \(recentUrgeEvents.count) total (\(completed) resisted, \(slipped) slipped)")

        if recentJournalEntries.isEmpty {
            lines.append("Recent journal entries: none")
        } else {
            lines.append("Recent journal entries:")
            recentJournalEntries.prefix(3).forEach { lines.append("  - \($0.body)") }
        }

        if recentMeditationCompletions.isEmpty {
            lines.append("Recent meditations: none")
        } else {
            lines.append("Recent meditations:")
            recentMeditationCompletions.prefix(3).forEach {
                lines.append("  - \($0.sessionTitle) (\($0.durationMinutes) min)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
