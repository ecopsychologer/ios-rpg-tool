import Foundation
import SwiftData

@Model
public final class Party {
    public var id: UUID
    public var name: String
    public var averageLevel: Int
    public var tier: Int
    public var resourcesSummary: String
    public var inventorySummary: String
    public var conditions: [String]?
    public var members: [PartyMember]?

    public init(
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
public final class PartyMember {
    public var id: UUID
    public var name: String
    public var role: String
    public var level: Int
    public var notes: String
    public var isNpc: Bool
    public var npcId: UUID?

    public init(
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
public final class LocationEntity {
    public var id: UUID
    public var name: String
    public var type: String
    public var createdAt: Date
    public var tags: [String]?
    public var dangerModifier: Int
    public var themeTags: [String]?
    public var origin: String
    public var nodes: [LocationNode]?
    public var edges: [LocationEdge]?

    public init(
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
public final class LocationNode {
    public var id: UUID
    public var type: String
    public var name: String?
    public var summary: String
    public var discovered: Bool
    public var visitedCount: Int
    public var notes: String?
    public var contentSummary: String?
    public var tags: [String]?
    public var origin: String
    public var traps: [TrapEntity]?
    public var encounters: [EncounterEntity]?
    public var clues: [ClueEntity]?
    public var features: [LocationFeature]?
    public var location: LocationEntity?

    public init(
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
public final class LocationFeature {
    public var id: UUID
    public var name: String
    public var summary: String
    public var category: String
    public var tags: [String]?
    public var origin: String
    public var createdAt: Date
    public var locationNodeId: UUID?
    public var locationEdgeId: UUID?

    public init(
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
public final class LocationEdge {
    public var id: UUID
    public var type: String
    public var label: String?
    public var fromNodeId: UUID?
    public var toNodeId: UUID?
    public var isLocked: Bool
    public var lockDC: Int?
    public var isTrapped: Bool
    public var requiresCheckSkill: String?
    public var requiresCheckDC: Int?
    public var oneWay: Bool
    public var origin: String
    public var trap: TrapEntity?
    public var location: LocationEntity?

    public init(
        type: String,
        label: String? = nil,
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
        self.label = label
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
public final class TrapEntity {
    public var id: UUID
    public var name: String
    public var category: String
    public var trigger: String
    public var detectionSkill: String
    public var detectionDC: Int
    public var disarmSkill: String
    public var disarmDC: Int
    public var saveSkill: String?
    public var saveDC: Int?
    public var effectSummary: String
    public var state: String
    public var isResettable: Bool
    public var origin: String
    public var locationNodeId: UUID?
    public var locationEdgeId: UUID?

    public init(
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
public final class SkillCheckEntity {
    public var id: UUID
    public var prompt: String
    public var skill: String
    public var abilityOverride: String?
    public var dc: Int
    public var advantageState: String
    public var stakes: String
    public var reason: String
    public var roll: Int?
    public var modifier: Int?
    public var total: Int?
    public var outcome: String?
    public var consequence: String?
    public var origin: String
    public var locationNodeId: UUID?
    public var locationEdgeId: UUID?

    public init(
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
public final class EncounterEntity {
    public var id: UUID
    public var type: String
    public var difficulty: String
    public var participantsSummary: String
    public var hooks: [String]?
    public var resolved: Bool
    public var origin: String
    public var locationNodeId: UUID?

    public init(
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
public final class ClueEntity {
    public var id: UUID
    public var text: String
    public var keywords: [String]?
    public var relatesTo: String?
    public var discoveredAt: Date
    public var confidence: String
    public var origin: String
    public var locationNodeId: UUID?

    public init(
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
public final class RumorEntity {
    public var id: UUID
    public var text: String
    public var sourceNPC: String?
    public var pointsTo: String?
    public var resolved: Bool
    public var origin: String

    public init(
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
public final class QuestEntity {
    public var id: UUID
    public var title: String
    public var objectives: [String]?
    public var giver: String?
    public var locationTargets: [String]?
    public var progress: String
    public var reward: String
    public var origin: String

    public init(
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
public final class EventLogEntry {
    public var id: UUID
    public var timestamp: Date
    public var sceneId: UUID?
    public var summary: String
    public var rollIds: [UUID]?
    public var entityIds: [UUID]?
    public var origin: String

    public init(
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
public final class TableRollRecord {
    public var id: UUID
    public var timestamp: Date
    public var tableId: String
    public var entryRange: String
    public var diceSpec: String
    public var rollTotal: Int
    public var modifier: Int
    public var seed: UInt64
    public var sequence: Int
    public var contextSummary: String
    public var outcomeSummary: String

    public init(
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
