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
        concluded: Bool
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
