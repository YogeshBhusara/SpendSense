//
// All data is stored locally on-device only. Nothing is shared externally.
//

import Foundation
import SwiftData

@Model
final class SpendingInsight {
    @Attribute(.unique) var id: UUID
    var type: InsightType
    var title: String
    var body: String
    var createdAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        type: InsightType,
        title: String,
        body: String,
        createdAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
