import Foundation
import SwiftData

@Model
final class Party {
    var id: UUID
    var name: String
    var averageLevel: Int
    var tier: Int
    var resourcesSummary: String
    var inventorySummary: String
    var conditions: [String]?
    var members: [PartyMember]?

    init(
        name: String = "Adventuring Party",
        averageLevel: Int = 1,
        tier: Int = 1,
        resourcesSummary: String = "",
        inventorySummary: String = "",
        conditions: [String]? = nil,
        members: [PartyMember]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.averageLevel = averageLevel
        self.tier = tier
        self.resourcesSummary = resourcesSummary
        self.inventorySummary = inventorySummary
        self.conditions = conditions
        self.members = members
    }
}

@Model
final class PartyMember {
    var id: UUID
    var name: String
    var role: String
    var level: Int
    var notes: String
    var isNpc: Bool
    var npcId: UUID?

    init(
        name: String,
        role: String = "",
        level: Int = 1,
        notes: String = "",
        isNpc: Bool = false,
        npcId: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.level = level
        self.notes = notes
        self.isNpc = isNpc
        self.npcId = npcId
    }
}

@Model
final class LocationEntity {
    var id: UUID
    var name: String
    var type: String
    var createdAt: Date
    var tags: [String]?
    var dangerModifier: Int
    var themeTags: [String]?
    var origin: String
    var nodes: [LocationNode]?
    var edges: [LocationEdge]?

    init(
        name: String,
        type: String,
        tags: [String]? = nil,
        dangerModifier: Int = 0,
        themeTags: [String]? = nil,
        origin: String = "system",
        nodes: [LocationNode]? = nil,
        edges: [LocationEdge]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.createdAt = Date()
        self.tags = tags
        self.dangerModifier = dangerModifier
        self.themeTags = themeTags
        self.origin = origin
        self.nodes = nodes
        self.edges = edges
    }
}

@Model
final class LocationNode {
    var id: UUID
    var type: String
    var name: String?
    var summary: String
    var discovered: Bool
    var visitedCount: Int
    var notes: String?
    var contentSummary: String?
    var tags: [String]?
    var origin: String
    var traps: [TrapEntity]?
    var encounters: [EncounterEntity]?
    var clues: [ClueEntity]?
    var features: [LocationFeature]?
    var location: LocationEntity?

    init(
        type: String,
        summary: String,
        discovered: Bool = false,
        visitedCount: Int = 0,
        origin: String = "system",
        tags: [String]? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.summary = summary
        self.discovered = discovered
        self.visitedCount = visitedCount
        self.origin = origin
        self.tags = tags
        self.traps = nil
        self.encounters = nil
        self.clues = nil
        self.features = nil
    }
}

@Model
final class LocationFeature {
    var id: UUID
    var name: String
    var summary: String
    var category: String
    var tags: [String]?
    var origin: String
    var createdAt: Date
    var locationNodeId: UUID?
    var locationEdgeId: UUID?

    init(
        name: String,
        summary: String,
        category: String = "feature",
        tags: [String]? = nil,
        origin: String = "system",
        locationNodeId: UUID? = nil,
        locationEdgeId: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.category = category
        self.tags = tags
        self.origin = origin
        self.createdAt = Date()
        self.locationNodeId = locationNodeId
        self.locationEdgeId = locationEdgeId
    }
}

@Model
final class LocationEdge {
    var id: UUID
    var type: String
    var fromNodeId: UUID?
    var toNodeId: UUID?
    var isLocked: Bool
    var lockDC: Int?
    var isTrapped: Bool
    var requiresCheckSkill: String?
    var requiresCheckDC: Int?
    var oneWay: Bool
    var origin: String
    var trap: TrapEntity?
    var location: LocationEntity?

    init(
        type: String,
        fromNodeId: UUID? = nil,
        toNodeId: UUID? = nil,
        isLocked: Bool = false,
        lockDC: Int? = nil,
        isTrapped: Bool = false,
        requiresCheckSkill: String? = nil,
        requiresCheckDC: Int? = nil,
        oneWay: Bool = false,
        origin: String = "system"
    ) {
        self.id = UUID()
        self.type = type
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.isLocked = isLocked
        self.lockDC = lockDC
        self.isTrapped = isTrapped
        self.requiresCheckSkill = requiresCheckSkill
        self.requiresCheckDC = requiresCheckDC
        self.oneWay = oneWay
        self.origin = origin
    }
}

@Model
final class TrapEntity {
    var id: UUID
    var name: String
    var category: String
    var trigger: String
    var detectionSkill: String
    var detectionDC: Int
    var disarmSkill: String
    var disarmDC: Int
    var saveSkill: String?
    var saveDC: Int?
    var effectSummary: String
    var state: String
    var isResettable: Bool
    var origin: String
    var locationNodeId: UUID?
    var locationEdgeId: UUID?

    init(
        name: String,
        category: String,
        trigger: String,
        detectionSkill: String,
        detectionDC: Int,
        disarmSkill: String,
        disarmDC: Int,
        saveSkill: String? = nil,
        saveDC: Int? = nil,
        effectSummary: String,
        state: String = "hidden",
        isResettable: Bool = false,
        origin: String = "system",
        locationNodeId: UUID? = nil,
        locationEdgeId: UUID? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.trigger = trigger
        self.detectionSkill = detectionSkill
        self.detectionDC = detectionDC
        self.disarmSkill = disarmSkill
        self.disarmDC = disarmDC
        self.saveSkill = saveSkill
        self.saveDC = saveDC
        self.effectSummary = effectSummary
        self.state = state
        self.isResettable = isResettable
        self.origin = origin
        self.locationNodeId = locationNodeId
        self.locationEdgeId = locationEdgeId
    }
}

@Model
final class SkillCheckEntity {
    var id: UUID
    var prompt: String
    var skill: String
    var abilityOverride: String?
    var dc: Int
    var advantageState: String
    var stakes: String
    var reason: String
    var roll: Int?
    var modifier: Int?
    var total: Int?
    var outcome: String?
    var consequence: String?
    var origin: String
    var locationNodeId: UUID?
    var locationEdgeId: UUID?

    init(
        prompt: String,
        skill: String,
        dc: Int,
        advantageState: String,
        stakes: String,
        reason: String,
        abilityOverride: String? = nil,
        origin: String = "system",
        locationNodeId: UUID? = nil,
        locationEdgeId: UUID? = nil
    ) {
        self.id = UUID()
        self.prompt = prompt
        self.skill = skill
        self.dc = dc
        self.advantageState = advantageState
        self.stakes = stakes
        self.reason = reason
        self.abilityOverride = abilityOverride
        self.origin = origin
        self.locationNodeId = locationNodeId
        self.locationEdgeId = locationEdgeId
    }
}

@Model
final class EncounterEntity {
    var id: UUID
    var type: String
    var difficulty: String
    var participantsSummary: String
    var hooks: [String]?
    var resolved: Bool
    var origin: String
    var locationNodeId: UUID?

    init(
        type: String,
        difficulty: String,
        participantsSummary: String,
        hooks: [String]? = nil,
        resolved: Bool = false,
        origin: String = "system",
        locationNodeId: UUID? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.difficulty = difficulty
        self.participantsSummary = participantsSummary
        self.hooks = hooks
        self.resolved = resolved
        self.origin = origin
        self.locationNodeId = locationNodeId
    }
}

@Model
final class ClueEntity {
    var id: UUID
    var text: String
    var keywords: [String]?
    var relatesTo: String?
    var discoveredAt: Date
    var confidence: String
    var origin: String
    var locationNodeId: UUID?

    init(
        text: String,
        keywords: [String]? = nil,
        relatesTo: String? = nil,
        confidence: String = "uncertain",
        origin: String = "system",
        locationNodeId: UUID? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.keywords = keywords
        self.relatesTo = relatesTo
        self.discoveredAt = Date()
        self.confidence = confidence
        self.origin = origin
        self.locationNodeId = locationNodeId
    }
}

@Model
final class RumorEntity {
    var id: UUID
    var text: String
    var sourceNPC: String?
    var pointsTo: String?
    var resolved: Bool
    var origin: String

    init(
        text: String,
        sourceNPC: String? = nil,
        pointsTo: String? = nil,
        resolved: Bool = false,
        origin: String = "system"
    ) {
        self.id = UUID()
        self.text = text
        self.sourceNPC = sourceNPC
        self.pointsTo = pointsTo
        self.resolved = resolved
        self.origin = origin
    }
}

@Model
final class QuestEntity {
    var id: UUID
    var title: String
    var objectives: [String]?
    var giver: String?
    var locationTargets: [String]?
    var progress: String
    var reward: String
    var origin: String

    init(
        title: String,
        objectives: [String]? = nil,
        giver: String? = nil,
        locationTargets: [String]? = nil,
        progress: String = "open",
        reward: String = "",
        origin: String = "system"
    ) {
        self.id = UUID()
        self.title = title
        self.objectives = objectives
        self.giver = giver
        self.locationTargets = locationTargets
        self.progress = progress
        self.reward = reward
        self.origin = origin
    }
}

@Model
final class EventLogEntry {
    var id: UUID
    var timestamp: Date
    var sceneId: UUID?
    var summary: String
    var rollIds: [UUID]?
    var entityIds: [UUID]?
    var origin: String

    init(
        summary: String,
        sceneId: UUID? = nil,
        rollIds: [UUID]? = nil,
        entityIds: [UUID]? = nil,
        origin: String = "system"
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sceneId = sceneId
        self.summary = summary
        self.rollIds = rollIds
        self.entityIds = entityIds
        self.origin = origin
    }
}

@Model
final class TableRollRecord {
    var id: UUID
    var timestamp: Date
    var tableId: String
    var entryRange: String
    var diceSpec: String
    var rollTotal: Int
    var modifier: Int
    var seed: UInt64
    var sequence: Int
    var contextSummary: String
    var outcomeSummary: String

    init(
        tableId: String,
        entryRange: String,
        diceSpec: String,
        rollTotal: Int,
        modifier: Int,
        seed: UInt64,
        sequence: Int,
        contextSummary: String,
        outcomeSummary: String
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.tableId = tableId
        self.entryRange = entryRange
        self.diceSpec = diceSpec
        self.rollTotal = rollTotal
        self.modifier = modifier
        self.seed = seed
        self.sequence = sequence
        self.contextSummary = contextSummary
        self.outcomeSummary = outcomeSummary
    }
}
