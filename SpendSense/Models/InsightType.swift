//
// All data is stored locally on-device only. Nothing is shared externally.
//

import Foundation

enum InsightType: String, Codable, CaseIterable, Sendable {
    case weeklyHigh
    case unusualSpike
    case streakBreak
    case positiveReinforcement
    case quietWeek
}
