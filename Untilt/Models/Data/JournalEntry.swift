import Foundation
import SwiftData

enum JournalEntryMode: String, Codable {
    case urgeLinked   = "urge_linked"
    case checkIn      = "check_in"
    case freeWrite    = "free_write"
}

@Model
final class JournalEntry {
    var body: String
    var mode: JournalEntryMode
    var timestamp: Date
    /// Present when mode == .urgeLinked
    var urgeEvent: UrgeEvent?

    init(body: String, mode: JournalEntryMode, timestamp: Date = Date(), urgeEvent: UrgeEvent? = nil) {
        self.body = body
        self.mode = mode
        self.timestamp = timestamp
        self.urgeEvent = urgeEvent
    }
}
