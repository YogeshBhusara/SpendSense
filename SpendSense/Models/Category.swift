//
// All data is stored locally on-device only. Nothing is shared externally.
//

import Foundation

enum Category: String, Codable, CaseIterable, Sendable {
    case food
    case transport
    case shopping
    case entertainment
    case bills
    case health
    case travel
    case subscriptions
    case other

    var displayName: String {
        switch self {
        case .food: "Food"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .entertainment: "Entertainment"
        case .bills: "Bills"
        case .health: "Health"
        case .travel: "Travel"
        case .subscriptions: "Subscriptions"
        case .other: "Other"
        }
    }

    var emoji: String {
        switch self {
        case .food: "🍽️"
        case .transport: "🚗"
        case .shopping: "🛍️"
        case .entertainment: "🎬"
        case .bills: "📄"
        case .health: "❤️‍🩹"
        case .travel: "✈️"
        case .subscriptions: "📱"
        case .other: "📦"
        }
    }

    /// Hex color string (e.g. "#RRGGBB") for UI theming.
    /// Chart / chip tints — design system hues only (no red for spending categories).
    var color: String {
        switch self {
        case .food: "#FB7185"
        case .transport: "#2DD4BF"
        case .shopping: "#FBBF24"
        case .entertainment: "#C084FC"
        case .bills: "#94A3B8"
        case .health: "#5EEAD4"
        case .travel: "#38BDF8"
        case .subscriptions: "#818CF8"
        case .other: "#A8A29E"
        }
    }

    /// Suggested monthly budget cap for this category, if applicable.
    var monthlyBudgetHint: Double? {
        switch self {
        case .food: 450
        case .transport: 200
        case .shopping: 250
        case .entertainment: 120
        case .bills: nil
        case .health: 150
        case .travel: 500
        case .subscriptions: 80
        case .other: nil
        }
    }
}
