//
// All data is stored locally on-device only. Nothing is shared externally.
//

import Foundation

enum EmotionalTag: String, Codable, CaseIterable, Sendable {
    case impulse
    case essential
    case treat
    case subscription

    var label: String {
        switch self {
        case .impulse: "Impulse buy"
        case .essential: "Essential"
        case .treat: "Treat yourself"
        case .subscription: "Subscription"
        }
    }

    /// Warm, non-alarm palette (amber / teal / violet / indigo).
    var color: String {
        switch self {
        case .impulse: "#FBBF24"
        case .essential: "#2DD4BF"
        case .treat: "#E879F9"
        case .subscription: "#818CF8"
        }
    }
}
