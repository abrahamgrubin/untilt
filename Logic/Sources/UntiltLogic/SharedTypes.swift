import Foundation

public struct UrgeEventRecord {
    public let timestamp: Date
    public let completed: Bool

    public init(timestamp: Date, completed: Bool) {
        self.timestamp = timestamp
        self.completed = completed
    }
}

public enum MilestoneType: Int, CaseIterable, Comparable {
    case day7   = 7
    case day30  = 30
    case day60  = 60
    case day90  = 90
    case month6 = 180
    case year1  = 365
    case year2  = 730

    public static func < (lhs: MilestoneType, rhs: MilestoneType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
