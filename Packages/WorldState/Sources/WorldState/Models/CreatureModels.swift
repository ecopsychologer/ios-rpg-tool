import Foundation
import SwiftData

@Model
public final class CreatureEntry {
    public var id: UUID
    public var name: String
    public var size: String?
    public var creatureType: String?
    public var alignment: String?
    public var armorClass: String?
    public var hitPoints: String?
    public var speed: String?
    public var savingThrows: String?
    public var skills: String?
    public var senses: String?
    public var languages: String?
    public var challenge: String?
    public var damageVulnerabilities: String?
    public var damageResistances: String?
    public var damageImmunities: String?
    public var conditionImmunities: String?
    public var traits: [String]
    public var actions: [String]
    public var reactions: [String]
    public var legendaryActions: [String]
    public var abilityScores: [CreatureAbilityScore]?
    public var source: String
    public var origin: String
    public var locationId: UUID?
    public var createdAt: Date
    public var updatedAt: Date

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
        traits: [String] = [],
        actions: [String] = [],
        reactions: [String] = [],
        legendaryActions: [String] = [],
        abilityScores: [CreatureAbilityScore]? = nil,
        source: String = "srd",
        origin: String = "system",
        locationId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
        self.traits = traits
        self.actions = actions
        self.reactions = reactions
        self.legendaryActions = legendaryActions
        self.abilityScores = abilityScores
        self.source = source
        self.origin = origin
        self.locationId = locationId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class CreatureAbilityScore {
    public var id: UUID
    public var ability: String
    public var score: String

    public init(ability: String, score: String) {
        self.id = UUID()
        self.ability = ability
        self.score = score
    }
}
