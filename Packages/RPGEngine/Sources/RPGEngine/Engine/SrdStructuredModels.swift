import Foundation

public struct SrdItemRecord: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let category: String
    public let subcategory: String?
    public let itemType: String?
    public let rarity: String?
    public let requiresAttunement: Bool
    public let attunementRequirement: String?
    public let cost: String?
    public let weight: String?
    public let properties: [String]
    public let description: [String]
    public let source: String

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
        description: [String] = [],
        source: String = "srd"
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
        self.description = description
        self.source = source
    }
}

public struct SrdCreatureRecord: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let size: String?
    public let creatureType: String?
    public let alignment: String?
    public let armorClass: String?
    public let hitPoints: String?
    public let speed: String?
    public let savingThrows: String?
    public let skills: String?
    public let senses: String?
    public let languages: String?
    public let challenge: String?
    public let damageVulnerabilities: String?
    public let damageResistances: String?
    public let damageImmunities: String?
    public let conditionImmunities: String?
    public let abilityScores: [String: String]
    public let traits: [String]
    public let actions: [String]
    public let reactions: [String]
    public let legendaryActions: [String]
    public let source: String

    public init(
        name: String,
        size: String? = nil,
        creatureType: String? = nil,
        alignment: String? = nil,
        armorClass: String? = nil,
        hitPoints: String? = nil,
        speed: String? = nil,
        savingThrows: String? = nil,
        skills: String? = nil,
        senses: String? = nil,
        languages: String? = nil,
        challenge: String? = nil,
        damageVulnerabilities: String? = nil,
        damageResistances: String? = nil,
        damageImmunities: String? = nil,
        conditionImmunities: String? = nil,
        abilityScores: [String: String] = [:],
        traits: [String] = [],
        actions: [String] = [],
        reactions: [String] = [],
        legendaryActions: [String] = [],
        source: String = "srd"
    ) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.creatureType = creatureType
        self.alignment = alignment
        self.armorClass = armorClass
        self.hitPoints = hitPoints
        self.speed = speed
        self.savingThrows = savingThrows
        self.skills = skills
        self.senses = senses
        self.languages = languages
        self.challenge = challenge
        self.damageVulnerabilities = damageVulnerabilities
        self.damageResistances = damageResistances
        self.damageImmunities = damageImmunities
        self.conditionImmunities = conditionImmunities
        self.abilityScores = abilityScores
        self.traits = traits
        self.actions = actions
        self.reactions = reactions
        self.legendaryActions = legendaryActions
        self.source = source
    }
}
