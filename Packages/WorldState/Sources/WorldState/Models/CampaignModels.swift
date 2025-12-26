import Foundation
import SwiftData

@Model
public final class Campaign {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var isActive: Bool
    public var chaosFactor: Int
    public var sceneNumber: Int
    public var scenes: [SceneEntry]
    public var characters: [CharacterEntry]
    public var threads: [ThreadEntry]
    public var npcs: [NPCEntry] = []
    public var worldLore: [WorldLoreEntry] = []
    public var playerCharacters: [PlayerCharacter] = []
    public var rulesetName: String?
    public var contentPackVersion: String?
    public var oracleConfig: String?
    public var worldVibe: String = ""
    public var party: Party?
    public var activeSceneId: UUID?
    public var activeLocationId: UUID?
    public var activeNodeId: UUID?
    public var lastNodeId: UUID?
    public var locations: [LocationEntity]?
    public var eventLog: [EventLogEntry]?
    public var tableRolls: [TableRollRecord]?
    public var rngSeed: UInt64?
    public var rngSequence: Int?

    public init(title: String = "Solo Campaign") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.isActive = true
        self.chaosFactor = 5
        self.sceneNumber = 1
        self.scenes = []
        self.characters = []
        self.threads = []
        self.npcs = []
        self.worldLore = []
        self.playerCharacters = []
        self.rulesetName = nil
        self.contentPackVersion = nil
        self.oracleConfig = nil
        self.worldVibe = ""
        self.party = nil
        self.activeSceneId = nil
        self.activeLocationId = nil
        self.activeNodeId = nil
        self.lastNodeId = nil
        self.locations = nil
        self.eventLog = nil
        self.tableRolls = nil
        self.rngSeed = nil
        self.rngSequence = nil
    }
}

@Model
public final class SceneEntry {
    public var id: UUID
    public var sceneNumber: Int
    public var createdAt: Date
    public var intent: String
    public var roll: Int
    public var chaosFactor: Int
    public var sceneType: String
    public var alterationMethod: String?
    public var alterationDetail: String?
    public var randomEventFocus: String?
    public var meaningWord1: String?
    public var meaningWord2: String?
    public var summary: String
    public var charactersAdded: [String]
    public var charactersFeatured: [String]
    public var charactersRemoved: [String]
    public var threadsAdded: [String]
    public var threadsFeatured: [String]
    public var threadsRemoved: [String]
    public var pcsInControl: Bool
    public var concluded: Bool
    public var interactions: [SceneInteraction]?
    public var skillChecks: [SkillCheckRecord]?
    public var fateQuestions: [FateQuestionRecord]?
    public var places: [String] = []
    public var curiosities: [String] = []
    public var rollHighlights: [String] = []
    public var locationId: UUID?
    public var generatedEntityIds: [UUID]?
    public var canonizations: [CanonizationRecord]?

    public init(
        sceneNumber: Int,
        intent: String,
        roll: Int,
        chaosFactor: Int,
        sceneType: String,
        alterationMethod: String? = nil,
        alterationDetail: String? = nil,
        randomEventFocus: String? = nil,
        meaningWord1: String? = nil,
        meaningWord2: String? = nil,
        summary: String,
        charactersAdded: [String],
        charactersFeatured: [String],
        charactersRemoved: [String],
        threadsAdded: [String],
        threadsFeatured: [String],
        threadsRemoved: [String],
        pcsInControl: Bool,
        concluded: Bool,
        interactions: [SceneInteraction]? = nil,
        skillChecks: [SkillCheckRecord]? = nil,
        fateQuestions: [FateQuestionRecord]? = nil,
        places: [String] = [],
        curiosities: [String] = [],
        rollHighlights: [String] = [],
        locationId: UUID? = nil,
        generatedEntityIds: [UUID]? = nil,
        canonizations: [CanonizationRecord]? = nil
    ) {
        self.id = UUID()
        self.sceneNumber = sceneNumber
        self.createdAt = Date()
        self.intent = intent
        self.roll = roll
        self.chaosFactor = chaosFactor
        self.sceneType = sceneType
        self.alterationMethod = alterationMethod
        self.alterationDetail = alterationDetail
        self.randomEventFocus = randomEventFocus
        self.meaningWord1 = meaningWord1
        self.meaningWord2 = meaningWord2
        self.summary = summary
        self.charactersAdded = charactersAdded
        self.charactersFeatured = charactersFeatured
        self.charactersRemoved = charactersRemoved
        self.threadsAdded = threadsAdded
        self.threadsFeatured = threadsFeatured
        self.threadsRemoved = threadsRemoved
        self.pcsInControl = pcsInControl
        self.concluded = concluded
        self.interactions = interactions
        self.skillChecks = skillChecks
        self.fateQuestions = fateQuestions
        self.places = places
        self.curiosities = curiosities
        self.rollHighlights = rollHighlights
        self.locationId = locationId
        self.generatedEntityIds = generatedEntityIds
        self.canonizations = canonizations
    }
}

@Model
public final class CanonizationRecord {
    public var id: UUID
    public var createdAt: Date
    public var assumption: String
    public var likelihood: String
    public var chaosFactor: Int
    public var roll: Int
    public var target: Int
    public var outcome: String

    public init(
        assumption: String,
        likelihood: String,
        chaosFactor: Int,
        roll: Int,
        target: Int,
        outcome: String
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.assumption = assumption
        self.likelihood = likelihood
        self.chaosFactor = chaosFactor
        self.roll = roll
        self.target = target
        self.outcome = outcome
    }
}

@Model
public final class SceneInteraction {
    public var id: UUID
    public var timestamp: Date
    public var playerText: String
    public var gmText: String
    public var turnSignal: String?

    public init(playerText: String, gmText: String, turnSignal: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.playerText = playerText
        self.gmText = gmText
        self.turnSignal = turnSignal
    }
}

@Model
public final class SkillCheckRecord {
    public var id: UUID
    public var createdAt: Date
    public var playerAction: String
    public var checkType: String
    public var skill: String
    public var abilityOverride: String?
    public var dc: Int?
    public var opponentSkill: String?
    public var opponentDC: Int?
    public var advantageState: String
    public var stakes: String
    public var partialSuccessDC: Int?
    public var partialSuccessOutcome: String?
    public var reason: String
    public var rollResult: Int?
    public var modifier: Int?
    public var total: Int?
    public var outcome: String?
    public var consequence: String?

    public init(
        playerAction: String,
        checkType: String,
        skill: String,
        abilityOverride: String? = nil,
        dc: Int? = nil,
        opponentSkill: String? = nil,
        opponentDC: Int? = nil,
        advantageState: String,
        stakes: String,
        partialSuccessDC: Int? = nil,
        partialSuccessOutcome: String? = nil,
        reason: String
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.playerAction = playerAction
        self.checkType = checkType
        self.skill = skill
        self.abilityOverride = abilityOverride
        self.dc = dc
        self.opponentSkill = opponentSkill
        self.opponentDC = opponentDC
        self.advantageState = advantageState
        self.stakes = stakes
        self.partialSuccessDC = partialSuccessDC
        self.partialSuccessOutcome = partialSuccessOutcome
        self.reason = reason
    }
}

@Model
public final class FateQuestionRecord {
    public var id: UUID
    public var createdAt: Date
    public var question: String
    public var likelihood: String
    public var chaosFactor: Int
    public var roll: Int
    public var target: Int
    public var outcome: String

    public init(
        question: String,
        likelihood: String,
        chaosFactor: Int,
        roll: Int,
        target: Int,
        outcome: String
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.question = question
        self.likelihood = likelihood
        self.chaosFactor = chaosFactor
        self.roll = roll
        self.target = target
        self.outcome = outcome
    }
}

@Model
public final class CharacterEntry {
    public var id: UUID
    public var name: String
    public var key: String
    public var weight: Int

    public init(name: String, weight: Int = 1) {
        self.id = UUID()
        self.name = name
        self.key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.weight = weight
    }
}

@Model
public final class ThreadEntry {
    public var id: UUID
    public var name: String
    public var key: String
    public var weight: Int

    public init(name: String, weight: Int = 1) {
        self.id = UUID()
        self.name = name
        self.key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.weight = weight
    }
}
