import Foundation
import SwiftData

enum NPCImportance: String, CaseIterable, Identifiable {
    case minor
    case supporting
    case major

    var id: String { rawValue }
}

enum NPCAttitude: String, CaseIterable, Identifiable {
    case friendly
    case neutral
    case wary
    case hostile

    var id: String { rawValue }
}

@Model
final class NPCEntry {
    var id: UUID
    var name: String
    var aliases: [String]
    var species: String
    var roleTag: String
    var importance: String
    var portraitImageRef: String?
    var portraitAltText: String?
    var createdAt: Date
    var updatedAt: Date
    var origin: String

    var ac: Int?
    var hpCurrent: Int?
    var hpMax: Int?
    var hpTemp: Int?
    var proficiencyBonus: Int?
    var speed: Int?
    var senses: [String]
    var mechanicsNotes: String?
    var skillModifiers: [NPCSkillModifier]?
    var abilityScores: [NPCAbilityScore]?

    var levelOrCR: Int?
    var classOrArchetype: String?
    var equipment: [String]
    var features: [String]
    var attacks: [NPCAttack]?
    var spellsOrPowers: [String]
    var acBreakdown: String?
    var hpBreakdown: String?
    var skillBreakdown: String?

    var appearanceShort: String
    var notableFeatures: [String]
    var clothingGear: [String]
    var speechStyle: String?
    var mannerisms: [String]

    var personalityTraits: [String]
    var values: [String]
    var bonds: [String]
    var fears: [String]
    var quirks: [String]
    var flaws: [String]

    var goalsImmediate: [String]
    var goalsLongTerm: [String]
    var backstorySummary: String?
    var backstoryKeyEvents: [String]
    var secrets: [String]
    var questHooks: [NPCQuestHook]?
    var bondToParty: String?
    var bondToLocation: String?
    var bondStrength: String?

    var currentMood: String
    var moodIntensity: Int
    var stress: Int
    var attitudeToParty: String
    var conditions: [String]
    var lastSeenSceneId: UUID?
    var lastSeenAt: Date?
    var currentLocationId: UUID?
    var relationships: [NPCRelationship]?

    var generationSeed: String?
    var generationVersion: String?
    var generationCreatedBy: String?
    var generationRolls: [NPCGenerationRoll]?
    var derivedAppearanceShort: String?
    var derivedSummary: String?

    init(
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
final class NPCSkillModifier {
    var id: UUID
    var skill: String
    var modifier: Int

    init(skill: String, modifier: Int) {
        self.id = UUID()
        self.skill = skill
        self.modifier = modifier
    }
}

@Model
final class NPCAbilityScore {
    var id: UUID
    var ability: String
    var score: Int?

    init(ability: String, score: Int? = nil) {
        self.id = UUID()
        self.ability = ability
        self.score = score
    }
}

@Model
final class NPCAttack {
    var id: UUID
    var name: String
    var toHit: Int?
    var damage: String
    var damageType: String?
    var riderText: String?

    init(
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
final class NPCQuestHook {
    var id: UUID
    var hookText: String
    var stakes: String?
    var relatedThreads: [String]
    var status: String

    init(hookText: String, stakes: String? = nil, relatedThreads: [String] = [], status: String = "dormant") {
        self.id = UUID()
        self.hookText = hookText
        self.stakes = stakes
        self.relatedThreads = relatedThreads
        self.status = status
    }
}

@Model
final class NPCRelationship {
    var id: UUID
    var entityId: UUID
    var relationTag: String
    var affinityScore: Int
    var notes: String?

    init(entityId: UUID, relationTag: String, affinityScore: Int, notes: String? = nil) {
        self.id = UUID()
        self.entityId = entityId
        self.relationTag = relationTag
        self.affinityScore = affinityScore
        self.notes = notes
    }
}

@Model
final class NPCGenerationRoll {
    var id: UUID
    var tableId: String
    var rollValue: Int
    var pickedEntryId: String
    var resultText: String

    init(tableId: String, rollValue: Int, pickedEntryId: String, resultText: String) {
        self.id = UUID()
        self.tableId = tableId
        self.rollValue = rollValue
        self.pickedEntryId = pickedEntryId
        self.resultText = resultText
    }
}
