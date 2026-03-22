//
// All data is stored locally on-device only. Nothing is shared externally.
//

import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var merchant: String
    var rawMessageText: String
    var date: Date
    var category: Category
    var isConfirmed: Bool
    var emotionalTag: EmotionalTag?
    var note: String?

    init(
        id: UUID = UUID(),
        amount: Double,
        merchant: String,
        rawMessageText: String,
        date: Date,
        category: Category,
        isConfirmed: Bool = false,
        emotionalTag: EmotionalTag? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.rawMessageText = rawMessageText
        self.date = date
        self.category = category
        self.isConfirmed = isConfirmed
        self.emotionalTag = emotionalTag
        self.note = note
    }
}
