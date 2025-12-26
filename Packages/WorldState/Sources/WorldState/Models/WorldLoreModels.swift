import Foundation
import SwiftData

@Model
public final class WorldLoreEntry {
    public var id: UUID
    public var title: String
    public var summary: String
    public var tags: [String]
    public var origin: String
    public var createdAt: Date
    public var updatedAt: Date
    public var relatedLocationId: UUID?
    public var relatedNpcId: UUID?
    public var relatedSceneId: UUID?

    public init(
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
