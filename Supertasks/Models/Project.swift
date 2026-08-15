import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var color: String?
    var createdAt: Date

    init(id: UUID = UUID(), name: String, color: String? = nil, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}
