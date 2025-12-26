import Foundation
import SwiftData

public enum NPCImportance: String, CaseIterable, Identifiable {
    case minor
    case supporting
    case major

    public var id: String { rawValue }
}

public enum NPCAttitude: String, CaseIterable, Identifiable {
    case friendly
    case neutral
    case wary
    case hostile

    public var id: String { rawValue }
}

@Model
public final class NPCEntry {
    public var id: UUID
    public var name: String
    public var aliases: [String]
    public var species: String
    public var roleTag: String
    public var importance: String
    public var portraitImageRef: String?
    public var portraitAltText: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var origin: String

    public var ac: Int?
    public var hpCurrent: Int?
    public var hpMax: Int?
    public var hpTemp: Int?
    public var proficiencyBonus: Int?
    public var speed: Int?
    public var senses: [String]
    public var mechanicsNotes: String?
    public var skillModifiers: [NPCSkillModifier]?
    public var abilityScores: [NPCAbilityScore]?

    public var levelOrCR: Int?
    public var classOrArchetype: String?
    public var equipment: [String]
    public var features: [String]
    public var attacks: [NPCAttack]?
    public var spellsOrPowers: [String]
    public var acBreakdown: String?
    public var hpBreakdown: String?
    public var skillBreakdown: String?

    public var appearanceShort: String
    public var notableFeatures: [String]
    public var clothingGear: [String]
    public var speechStyle: String?
    public var mannerisms: [String]

    public var personalityTraits: [String]
    public var values: [String]
    public var bonds: [String]
    public var fears: [String]
    public var quirks: [String]
    public var flaws: [String]

    public var goalsImmediate: [String]
    public var goalsLongTerm: [String]
    public var backstorySummary: String?
    public var backstoryKeyEvents: [String]
    public var secrets: [String]
    public var questHooks: [NPCQuestHook]?
    public var bondToParty: String?
    public var bondToLocation: String?
    public var bondStrength: String?

    public var currentMood: String
    public var moodIntensity: Int
    public var stress: Int
    public var attitudeToParty: String
    public var conditions: [String]
    public var lastSeenSceneId: UUID?
    public var lastSeenAt: Date?
    public var currentLocationId: UUID?
    public var relationships: [NPCRelationship]?

    public var generationSeed: String?
    public var generationVersion: String?
    public var generationCreatedBy: String?
    public var generationRolls: [NPCGenerationRoll]?
    public var derivedAppearanceShort: String?
    public var derivedSummary: String?

    public init(
        name: String,
        species: String,
        roleTag: String,
        importance: String = NPCImportance.minor.rawValue,
        origin: String = "system"
    ) {
        self.id = UUID()
        self.name = name
        self.aliases = []
        self.species = species
        self.roleTag = roleTag
        self.importance = importance
        self.portraitImageRef = nil
        self.portraitAltText = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.origin = origin

        self.ac = nil
        self.hpCurrent = nil
        self.hpMax = nil
        self.hpTemp = nil
        self.proficiencyBonus = nil
        self.speed = nil
        self.senses = []
        self.mechanicsNotes = nil
        self.skillModifiers = nil
        self.abilityScores = nil

        self.levelOrCR = nil
        self.classOrArchetype = nil
        self.equipment = []
        self.features = []
        self.attacks = nil
        self.spellsOrPowers = []
        self.acBreakdown = nil
        self.hpBreakdown = nil
        self.skillBreakdown = nil

        self.appearanceShort = ""
        self.notableFeatures = []
        self.clothingGear = []
        self.speechStyle = nil
        self.mannerisms = []

        self.personalityTraits = []
        self.values = []
        self.bonds = []
        self.fears = []
        self.quirks = []
        self.flaws = []

        self.goalsImmediate = []
        self.goalsLongTerm = []
        self.backstorySummary = nil
        self.backstoryKeyEvents = []
        self.secrets = []
        self.questHooks = nil
        self.bondToParty = nil
        self.bondToLocation = nil
        self.bondStrength = nil

        self.currentMood = ""
        self.moodIntensity = 0
        self.stress = 0
        self.attitudeToParty = NPCAttitude.neutral.rawValue
        self.conditions = []
        self.lastSeenSceneId = nil
        self.lastSeenAt = nil
        self.currentLocationId = nil
        self.relationships = nil

        self.generationSeed = nil
        self.generationVersion = nil
        self.generationCreatedBy = nil
        self.generationRolls = nil
        self.derivedAppearanceShort = nil
        self.derivedSummary = nil
    }
}

@Model
public final class NPCSkillModifier {
    public var id: UUID
    public var skill: String
    public var modifier: Int

    public init(skill: String, modifier: Int) {
        self.id = UUID()
        self.skill = skill
        self.modifier = modifier
    }
}

@Model
public final class NPCAbilityScore {
    public var id: UUID
    public var ability: String
    public var score: Int?

    public init(ability: String, score: Int? = nil) {
        self.id = UUID()
        self.ability = ability
        self.score = score
    }
}

@Model
public final class NPCAttack {
    public var id: UUID
    public var name: String
    public var toHit: Int?
    public var damage: String
    public var damageType: String?
    public var riderText: String?

    public init(
        name: String,
        damage: String,
        toHit: Int? = nil,
        damageType: String? = nil,
        riderText: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.toHit = toHit
        self.damage = damage
        self.damageType = damageType
        self.riderText = riderText
    }
}

@Model
public final class NPCQuestHook {
    public var id: UUID
    public var hookText: String
    public var stakes: String?
    public var relatedThreads: [String]
    public var status: String

    public init(hookText: String, stakes: String? = nil, relatedThreads: [String] = [], status: String = "dormant") {
        self.id = UUID()
        self.hookText = hookText
        self.stakes = stakes
        self.relatedThreads = relatedThreads
        self.status = status
    }
}

@Model
public final class NPCRelationship {
    public var id: UUID
    public var entityId: UUID
    public var relationTag: String
    public var affinityScore: Int
    public var notes: String?

    public init(entityId: UUID, relationTag: String, affinityScore: Int, notes: String? = nil) {
        self.id = UUID()
        self.entityId = entityId
        self.relationTag = relationTag
        self.affinityScore = affinityScore
        self.notes = notes
    }
}

@Model
public final class NPCGenerationRoll {
    public var id: UUID
    public var tableId: String
    public var rollValue: Int
    public var pickedEntryId: String
    public var resultText: String

    public init(tableId: String, rollValue: Int, pickedEntryId: String, resultText: String) {
        self.id = UUID()
        self.tableId = tableId
        self.rollValue = rollValue
        self.pickedEntryId = pickedEntryId
        self.resultText = resultText
    }
}
