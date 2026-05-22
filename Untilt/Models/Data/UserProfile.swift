import Foundation
import SwiftData

@Model
final class UserProfile {
    var appleUserID: String
    var sobrietyStartDate: Date
    var weeklySpend: Double
    var savingsGoal: Double?
    var gatedApps: [String]
    var gateConfigured: Bool
    var createdAt: Date

    init(
        appleUserID: String,
        sobrietyStartDate: Date,
        weeklySpend: Double,
        savingsGoal: Double? = nil,
        gatedApps: [String] = [],
        gateConfigured: Bool = false
    ) {
        self.appleUserID = appleUserID
        self.sobrietyStartDate = sobrietyStartDate
        self.weeklySpend = weeklySpend
        self.savingsGoal = savingsGoal
        self.gatedApps = gatedApps
        self.gateConfigured = gateConfigured
        self.createdAt = Date()
    }
}
