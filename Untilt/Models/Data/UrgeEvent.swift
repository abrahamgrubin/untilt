import Foundation
import SwiftData

@Model
final class UrgeEvent {
    var timestamp: Date
    /// true = breathing exercise completed (urge resisted)
    /// false = breathing exercise abandoned (Slip)
    var completed: Bool

    init(timestamp: Date = Date(), completed: Bool) {
        self.timestamp = timestamp
        self.completed = completed
    }

    /// A Slip is a gate activation that was abandoned
    var isSlip: Bool { !completed }
}
