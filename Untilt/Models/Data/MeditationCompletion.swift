import Foundation
import SwiftData

@Model
final class MeditationCompletion {
    /// Matches MeditationSession.id in the catalogue
    var sessionID: String
    var sessionTitle: String
    var durationMinutes: Int
    var timestamp: Date

    init(sessionID: String, sessionTitle: String, durationMinutes: Int, timestamp: Date = Date()) {
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.durationMinutes = durationMinutes
        self.timestamp = timestamp
    }
}
