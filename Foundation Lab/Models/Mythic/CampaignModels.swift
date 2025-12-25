import Foundation
import SwiftData

@Model
final class Campaign {
    var id: UUID
    var title: String
    var createdAt: Date
    var isActive: Bool
    var chaosFactor: Int
    var sceneNumber: Int
    var scenes: [SceneEntry]
    var characters: [CharacterEntry]
    var threads: [ThreadEntry]

    init(title: String = "Solo Campaign") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.isActive = true
        self.chaosFactor = 5
        self.sceneNumber = 1
        self.scenes = []
        self.characters = []
        self.threads = []
    }
}

@Model
final class SceneEntry {
    var id: UUID
    var sceneNumber: Int
    var createdAt: Date
    var intent: String
    var roll: Int
    var chaosFactor: Int
    var sceneType: String
    var alterationMethod: String?
    var alterationDetail: String?
    var randomEventFocus: String?
    var meaningWord1: String?
    var meaningWord2: String?
    var summary: String
    var charactersAdded: [String]
    var charactersFeatured: [String]
    var charactersRemoved: [String]
    var threadsAdded: [String]
    var threadsFeatured: [String]
    var threadsRemoved: [String]
    var pcsInControl: Bool
    var concluded: Bool
    var interactions: [SceneInteraction]
    var skillChecks: [SkillCheckRecord]
    var fateQuestions: [FateQuestionRecord]
    var places: [String]
    var curiosities: [String]
    var rollHighlights: [String]

    init(
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
        interactions: [SceneInteraction] = [],
        skillChecks: [SkillCheckRecord] = [],
        fateQuestions: [FateQuestionRecord] = [],
        places: [String] = [],
        curiosities: [String] = [],
        rollHighlights: [String] = []
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
    }
}

@Model
final class SceneInteraction {
    var id: UUID
    var timestamp: Date
    var playerText: String
    var gmText: String
    var turnSignal: String?

    init(playerText: String, gmText: String, turnSignal: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.playerText = playerText
        self.gmText = gmText
        self.turnSignal = turnSignal
    }
}

@Model
final class SkillCheckRecord {
    var id: UUID
    var createdAt: Date
    var playerAction: String
    var checkType: String
    var skill: String
    var abilityOverride: String?
    var dc: Int?
    var opponentSkill: String?
    var opponentDC: Int?
    var advantageState: String
    var stakes: String
    var partialSuccessDC: Int?
    var partialSuccessOutcome: String?
    var reason: String
    var rollResult: Int?
    var modifier: Int?
    var total: Int?
    var outcome: String?
    var consequence: String?

    init(
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
final class FateQuestionRecord {
    var id: UUID
    var createdAt: Date
    var question: String
    var likelihood: String
    var chaosFactor: Int
    var roll: Int
    var target: Int
    var outcome: String

    init(
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
final class CharacterEntry {
    var id: UUID
    var name: String
    var key: String
    var weight: Int

    init(name: String, weight: Int = 1) {
        self.id = UUID()
        self.name = name
        self.key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.weight = weight
    }
}

@Model
final class ThreadEntry {
    var id: UUID
    var name: String
    var key: String
    var weight: Int

    init(name: String, weight: Int = 1) {
        self.id = UUID()
        self.name = name
        self.key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.weight = weight
    }
}
