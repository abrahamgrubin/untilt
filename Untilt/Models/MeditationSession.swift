import SwiftUI

// MARK: - Meditation Session Model

enum SessionCategory: String, CaseIterable {
    case quickReset  = "Quick reset"
    case grounding   = "Grounding"
    case cbtBased    = "CBT-based"
    case focus       = "Focus"
    case deepWork    = "Deep work"
    case recovery    = "Recovery"

    var thumbnailColor: Color {
        switch self {
        case .quickReset:  return UntiltTheme.Color.lavender50
        case .grounding:   return UntiltTheme.Color.sage50
        case .cbtBased:    return UntiltTheme.Color.lavender100
        case .focus:       return UntiltTheme.Color.sage50
        case .deepWork:    return UntiltTheme.Color.lavender100
        case .recovery:    return UntiltTheme.Color.sage50
        }
    }

    var tagColor: Color {
        switch self {
        case .quickReset, .cbtBased, .deepWork: return UntiltTheme.Color.lavender700
        case .grounding, .focus, .recovery:     return UntiltTheme.Color.sage700
        }
    }

    var tagBackground: Color {
        switch self {
        case .quickReset, .cbtBased, .deepWork: return UntiltTheme.Color.lavender50
        case .grounding, .focus, .recovery:     return UntiltTheme.Color.sage50
        }
    }
}

enum DurationFilter: String, CaseIterable {
    case all      = "All"
    case quick    = "Under 5 min"
    case short    = "5–10 min"
    case medium   = "10–20 min"
    case long     = "20+ min"
}

struct MeditationSession: Identifiable {
    let id = UUID()
    let title: String
    let durationLabel: String   // e.g. "3:00"
    let durationMinutes: Int
    let category: SessionCategory
    let level: String

    var filterBucket: DurationFilter {
        switch durationMinutes {
        case ..<5:   return .quick
        case 5..<10: return .short
        case 10..<20: return .medium
        default:     return .long
        }
    }
}

// MARK: - Sample data
extension MeditationSession {
    static let catalogue: [MeditationSession] = [
        MeditationSession(title: "Box breathing for urge relief",            durationLabel: "3:00",  durationMinutes: 3,  category: .quickReset, level: "Beginner"),
        MeditationSession(title: "4-7-8 breath to calm anxiety",             durationLabel: "4:30",  durationMinutes: 4,  category: .quickReset, level: "Beginner"),
        MeditationSession(title: "Body scan for restlessness",               durationLabel: "7:00",  durationMinutes: 7,  category: .grounding,  level: "All levels"),
        MeditationSession(title: "Cognitive defusion from betting thoughts",  durationLabel: "9:00",  durationMinutes: 9,  category: .cbtBased,   level: "Intermediate"),
        MeditationSession(title: "Mindful awareness of cravings",            durationLabel: "12:00", durationMinutes: 12, category: .focus,      level: "Intermediate"),
        MeditationSession(title: "MBSR stress reduction session",            durationLabel: "18:00", durationMinutes: 18, category: .deepWork,   level: "All levels"),
        MeditationSession(title: "Loving-kindness for self-compassion",      durationLabel: "25:00", durationMinutes: 25, category: .deepWork,   level: "Advanced"),
        MeditationSession(title: "Full recovery meditation & reflection",    durationLabel: "30:00", durationMinutes: 30, category: .recovery,   level: "Advanced"),
    ]
}
