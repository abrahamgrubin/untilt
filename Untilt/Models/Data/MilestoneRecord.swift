import Foundation
import SwiftData

/// Persisted record of an earned Milestone. Type mirrors UntiltLogic.MilestoneType.
enum MilestoneTypeRaw: String, Codable {
    case day7   = "day_7"
    case day30  = "day_30"
    case day60  = "day_60"
    case day90  = "day_90"
    case month6 = "month_6"
    case year1  = "year_1"
    case year2  = "year_2"

    var displayName: String {
        switch self {
        case .day7:   return "7 Days"
        case .day30:  return "30 Days"
        case .day60:  return "60 Days"
        case .day90:  return "90 Days"
        case .month6: return "6 Months"
        case .year1:  return "1 Year"
        case .year2:  return "2 Years"
        }
    }
}

@Model
final class MilestoneRecord {
    var type: MilestoneTypeRaw
    var earnedDate: Date

    init(type: MilestoneTypeRaw, earnedDate: Date = Date()) {
        self.type = type
        self.earnedDate = earnedDate
    }
}
