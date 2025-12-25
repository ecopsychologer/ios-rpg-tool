import Foundation
import SwiftData

@Model
final class WorldLoreEntry {
    var id: UUID
    var title: String
    var summary: String
    var tags: [String]
    var origin: String
    var createdAt: Date
    var updatedAt: Date
    var relatedLocationId: UUID?
    var relatedNpcId: UUID?
    var relatedSceneId: UUID?

    init(
        title: String,
        summary: String,
        tags: [String] = [],
        origin: String = "player",
        relatedLocationId: UUID? = nil,
        relatedNpcId: UUID? = nil,
        relatedSceneId: UUID? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.tags = tags
        self.origin = origin
        self.createdAt = Date()
        self.updatedAt = Date()
        self.relatedLocationId = relatedLocationId
        self.relatedNpcId = relatedNpcId
        self.relatedSceneId = relatedSceneId
    }
}
