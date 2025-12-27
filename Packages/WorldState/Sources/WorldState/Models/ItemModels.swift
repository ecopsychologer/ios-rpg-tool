import Foundation
import SwiftData

@Model
public final class ItemEntry {
    public var id: UUID
    public var name: String
    public var category: String
    public var subcategory: String?
    public var itemType: String?
    public var rarity: String?
    public var requiresAttunement: Bool
    public var attunementRequirement: String?
    public var cost: String?
    public var weight: String?
    public var properties: [String]
    public var detailLines: [String]
    public var source: String
    public var ownerId: UUID?
    public var ownerKind: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        name: String,
        category: String,
        subcategory: String? = nil,
        itemType: String? = nil,
        rarity: String? = nil,
        requiresAttunement: Bool = false,
        attunementRequirement: String? = nil,
        cost: String? = nil,
        weight: String? = nil,
        properties: [String] = [],
        detailLines: [String] = [],
        source: String = "srd",
        ownerId: UUID? = nil,
        ownerKind: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.itemType = itemType
        self.rarity = rarity
        self.requiresAttunement = requiresAttunement
        self.attunementRequirement = attunementRequirement
        self.cost = cost
        self.weight = weight
        self.properties = properties
        self.detailLines = detailLines
        self.source = source
        self.ownerId = ownerId
        self.ownerKind = ownerKind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
