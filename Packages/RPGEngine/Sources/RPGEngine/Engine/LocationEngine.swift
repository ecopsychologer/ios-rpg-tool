import Foundation
import TableEngine
import WorldState

public struct SoloLocationEngine {
    private var tableEngine: TableEngine?
    private let packStore = ContentPackStore()

    public init() {}

    public mutating func generateDungeonStart(campaign: Campaign) -> LocationEntity? {
        do {
            try ensureTableEngine()
        } catch {
            return nil
        }
        guard let tableEngine else { return nil }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let location = LocationEntity(
            name: "Dungeon Entrance",
            type: "dungeon",
            tags: ["dungeon"],
            dangerModifier: 0,
            themeTags: ["ancient"],
            origin: "system"
        )

        let context = RollContext(
            campaignId: campaign.id,
            sceneId: nil,
            locationId: location.id,
            nodeId: nil,
            tags: ["dungeon", "entry"],
            dangerModifier: location.dangerModifier,
            depth: 0
        )

        var engine = tableEngine
        let execution = engine.execute(tableId: "dungeon_start", context: context, seed: seed, sequence: sequence)
        self.tableEngine = engine

        let node = resolveStartNode(from: execution)
        node.discovered = true
        node.visitedCount = 1
        node.location = location

        if node.type == "room" {
            applyRoomShape(to: node, campaign: campaign, context: context, seed: seed)
        }

        location.nodes = [node]
        if !execution.spawnedEdges.isEmpty {
            let edges = execution.spawnedEdges.map { spawn in
                LocationEdge(
                    type: spawn.edgeType,
                    label: spawn.summary,
                    fromNodeId: node.id,
                    toNodeId: nil,
                    isLocked: spawn.tags.contains("locked"),
                    lockDC: spawn.tags.contains("locked") ? 15 : nil,
                    isTrapped: spawn.tags.contains("trapped"),
                    requiresCheckSkill: nil,
                    requiresCheckDC: nil,
                    oneWay: spawn.tags.contains("oneWay"),
                    origin: "system"
                )
            }
            location.edges = edges
        } else {
            location.edges = []
        }

        campaign.activeLocationId = location.id
        campaign.activeNodeId = node.id

        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        if node.type == "room" {
            addRoomContents(to: node, campaign: campaign, context: context, seed: seed)
        }

        if campaign.locations == nil {
            campaign.locations = [location]
        } else {
            campaign.locations?.append(location)
        }

        let logEntry = EventLogEntry(
            summary: "Generated location: \(location.name) (\(location.type))",
            sceneId: campaign.activeSceneId,
            rollIds: campaign.tableRolls?.suffix(execution.rollResults.count).map { $0.id },
            entityIds: [location.id, node.id]
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }

        return location
    }

    public mutating func advanceToNextNode(campaign: Campaign, reason: String) -> LocationNode? {
        do {
            try ensureTableEngine()
        } catch {
            return nil
        }
        guard var tableEngine else { return nil }
        guard let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }) else { return nil }
        guard let currentNode = location.nodes?.first(where: { $0.id == campaign.activeNodeId }) else { return nil }

        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let previousNodeId = currentNode.id

        if let existing = resolveBacktrackNode(
            campaign: campaign,
            location: location,
            currentNode: currentNode,
            reason: normalizedReason
        ) {
            existing.discovered = true
            existing.visitedCount += 1
            campaign.activeNodeId = existing.id
            campaign.lastNodeId = previousNodeId
            appendMoveLog(
                campaign: campaign,
                location: location,
                node: existing,
                summary: "Returned to node: \(existing.summary) via \(reason)"
            )
            return existing
        }

        let openEdge = location.edges?.first(where: { $0.fromNodeId == currentNode.id && $0.toNodeId == nil })
        if let openEdge {
            return advanceAlongEdge(campaign: campaign, edge: openEdge, reason: reason)
        }
        if let existing = resolveConnectedNode(location: location, currentNode: currentNode) {
            existing.discovered = true
            existing.visitedCount += 1
            campaign.activeNodeId = existing.id
            campaign.lastNodeId = previousNodeId
            appendMoveLog(
                campaign: campaign,
                location: location,
                node: existing,
                summary: "Moved to existing node: \(existing.summary) via \(reason)"
            )
            return existing
        }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let context = RollContext(
            campaignId: campaign.id,
            sceneId: campaign.activeSceneId,
            locationId: location.id,
            nodeId: currentNode.id,
            tags: ["dungeon", "advance"],
            dangerModifier: location.dangerModifier,
            depth: 0
        )

        let execution = tableEngine.execute(tableId: "dungeon_next_node", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        let newNode = resolveStartNode(from: execution)
        newNode.discovered = true
        newNode.visitedCount = 1
        newNode.location = location

        if newNode.type == "room" {
            applyRoomShape(to: newNode, campaign: campaign, context: context, seed: seed)
            addRoomContents(to: newNode, campaign: campaign, context: context, seed: seed)
        } else if newNode.type == "passage" {
            addPassageFeatures(to: newNode, campaign: campaign, context: context, seed: seed)
        }

        if location.nodes == nil {
            location.nodes = [currentNode, newNode]
        } else {
            location.nodes?.append(newNode)
        }

        if let edgeIndex = location.edges?.firstIndex(where: { $0.fromNodeId == currentNode.id && $0.toNodeId == nil }) {
            location.edges?[edgeIndex].toNodeId = newNode.id
        } else {
            let edgeContext = RollContext(
                campaignId: campaign.id,
                sceneId: campaign.activeSceneId,
                locationId: location.id,
                nodeId: currentNode.id,
                tags: ["dungeon", "edge"],
                dangerModifier: location.dangerModifier,
                depth: 0
            )
            let templateEdge = generateEdgeTemplate(campaign: campaign, context: edgeContext)
            let edge = templateEdge ?? LocationEdge(
                type: "passage",
                label: "Passage",
                fromNodeId: currentNode.id,
                toNodeId: newNode.id,
                isLocked: false,
                lockDC: nil,
                isTrapped: false,
                requiresCheckSkill: nil,
                requiresCheckDC: nil,
                oneWay: false,
                origin: "system"
            )
            edge.fromNodeId = currentNode.id
            edge.toNodeId = newNode.id
            if location.edges == nil {
                location.edges = [edge]
            } else {
                location.edges?.append(edge)
            }
        }

        campaign.activeNodeId = newNode.id
        campaign.lastNodeId = previousNodeId

        let logEntry = EventLogEntry(
            summary: "Advanced to new node: \(newNode.summary) via \(reason)",
            sceneId: campaign.activeSceneId,
            rollIds: campaign.tableRolls?.suffix(execution.rollResults.count).map { $0.id },
            entityIds: [location.id, newNode.id]
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }

        return newNode
    }

    public mutating func advanceAlongEdge(campaign: Campaign, edge: LocationEdge, reason: String) -> LocationNode? {
        do {
            try ensureTableEngine()
        } catch {
            return nil
        }
        guard var tableEngine else { return nil }
        guard let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }) else { return nil }
        guard let currentNode = location.nodes?.first(where: { $0.id == campaign.activeNodeId }) else { return nil }
        guard edge.fromNodeId == currentNode.id else { return nil }

        let previousNodeId = currentNode.id
        let normalizedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        applyEdgeTemplateIfNeeded(
            edge,
            campaign: campaign,
            context: RollContext(
                campaignId: campaign.id,
                sceneId: campaign.activeSceneId,
                locationId: location.id,
                nodeId: currentNode.id,
                tags: ["dungeon", "edge"],
                dangerModifier: location.dangerModifier,
                depth: 0
            )
        )

        if let existingId = edge.toNodeId,
           let existingNode = location.nodes?.first(where: { $0.id == existingId }) {
            existingNode.discovered = true
            existingNode.visitedCount += 1
            campaign.activeNodeId = existingNode.id
            campaign.lastNodeId = previousNodeId
            appendMoveLog(
                campaign: campaign,
                location: location,
                node: existingNode,
                summary: "Moved to existing node: \(existingNode.summary) via \(reason)"
            )
            return existingNode
        }

        if let backtrack = resolveBacktrackNode(
            campaign: campaign,
            location: location,
            currentNode: currentNode,
            reason: normalizedReason
        ) {
            backtrack.discovered = true
            backtrack.visitedCount += 1
            campaign.activeNodeId = backtrack.id
            campaign.lastNodeId = previousNodeId
            appendMoveLog(
                campaign: campaign,
                location: location,
                node: backtrack,
                summary: "Returned to node: \(backtrack.summary) via \(reason)"
            )
            return backtrack
        }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let context = RollContext(
            campaignId: campaign.id,
            sceneId: campaign.activeSceneId,
            locationId: location.id,
            nodeId: currentNode.id,
            tags: ["dungeon", "advance"],
            dangerModifier: location.dangerModifier,
            depth: 0
        )

        let execution = tableEngine.execute(tableId: "dungeon_next_node", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        let newNode = resolveStartNode(from: execution)
        newNode.discovered = true
        newNode.visitedCount = 1
        newNode.location = location

        if newNode.type == "room" {
            applyRoomShape(to: newNode, campaign: campaign, context: context, seed: seed)
            addRoomContents(to: newNode, campaign: campaign, context: context, seed: seed)
        } else if newNode.type == "passage" {
            addPassageFeatures(to: newNode, campaign: campaign, context: context, seed: seed)
        }

        if location.nodes == nil {
            location.nodes = [currentNode, newNode]
        } else {
            location.nodes?.append(newNode)
        }

        edge.toNodeId = newNode.id
        campaign.activeNodeId = newNode.id
        campaign.lastNodeId = previousNodeId

        let logEntry = EventLogEntry(
            summary: "Advanced to new node: \(newNode.summary) via \(reason)",
            sceneId: campaign.activeSceneId,
            rollIds: campaign.tableRolls?.suffix(execution.rollResults.count).map { $0.id },
            entityIds: [location.id, newNode.id]
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }

        return newNode
    }

    private mutating func applyEdgeTemplateIfNeeded(
        _ edge: LocationEdge,
        campaign: Campaign,
        context: RollContext
    ) {
        guard edge.label == nil || edge.label?.isEmpty == true else { return }
        guard var tableEngine else { return }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let execution = tableEngine.execute(tableId: "dungeon_edge", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        guard let spawn = execution.spawnedEdges.first else { return }
        edge.label = spawn.summary
        if edge.type == "passage" {
            edge.type = spawn.edgeType
        }
        edge.isLocked = spawn.tags.contains("locked")
        edge.lockDC = spawn.tags.contains("locked") ? 15 : edge.lockDC
        edge.isTrapped = spawn.tags.contains("trapped")
        edge.oneWay = spawn.tags.contains("oneWay")
    }

    private func resolveBacktrackNode(
        campaign: Campaign,
        location: LocationEntity,
        currentNode: LocationNode,
        reason: String
    ) -> LocationNode? {
        guard shouldBacktrack(reason: reason) else { return nil }
        if let lastId = campaign.lastNodeId,
           lastId != currentNode.id,
           let node = location.nodes?.first(where: { $0.id == lastId }) {
            return node
        }
        if let edge = location.edges?.first(where: { $0.toNodeId == currentNode.id && $0.oneWay == false }),
           let fromId = edge.fromNodeId,
           let node = location.nodes?.first(where: { $0.id == fromId }) {
            return node
        }
        return nil
    }

    private func shouldBacktrack(reason: String) -> Bool {
        let keywords = ["go back", "back", "return", "retreat", "leave", "exit", "head back"]
        return keywords.contains(where: { reason.contains($0) })
    }

    private func resolveConnectedNode(location: LocationEntity, currentNode: LocationNode) -> LocationNode? {
        guard let edges = location.edges else { return nil }
        for edge in edges {
            guard edge.fromNodeId == currentNode.id, let toId = edge.toNodeId else { continue }
            if let node = location.nodes?.first(where: { $0.id == toId }) {
                return node
            }
        }
        return nil
    }

    private func appendMoveLog(campaign: Campaign, location: LocationEntity, node: LocationNode, summary: String) {
        let logEntry = EventLogEntry(
            summary: summary,
            sceneId: campaign.activeSceneId,
            rollIds: nil,
            entityIds: [location.id, node.id]
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }
    }

    private mutating func generateEdgeTemplate(
        campaign: Campaign,
        context: RollContext
    ) -> LocationEdge? {
        guard var tableEngine else { return nil }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let execution = tableEngine.execute(tableId: "dungeon_edge", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        guard let spawn = execution.spawnedEdges.first else { return nil }
        return LocationEdge(
            type: spawn.edgeType,
            label: spawn.summary,
            fromNodeId: nil,
            toNodeId: nil,
            isLocked: spawn.tags.contains("locked"),
            lockDC: spawn.tags.contains("locked") ? 15 : nil,
            isTrapped: spawn.tags.contains("trapped"),
            requiresCheckSkill: nil,
            requiresCheckDC: nil,
            oneWay: spawn.tags.contains("oneWay"),
            origin: "system"
        )
    }

    private mutating func applyRoomShape(
        to node: LocationNode,
        campaign: Campaign,
        context: RollContext,
        seed: UInt64
    ) {
        guard var tableEngine else { return }
        let sequence = campaign.rngSequence ?? 0
        let execution = tableEngine.execute(tableId: "room_shape", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)
        if let note = execution.logs.first, !note.isEmpty {
            node.contentSummary = note
        }
    }

    private mutating func ensureTableEngine() throws {
        if tableEngine != nil { return }
        let pack = try packStore.loadDefaultPack()
        tableEngine = TableEngine(contentPack: pack)
    }

    private func resolveStartNode(from execution: TableExecution) -> LocationNode {
        if let spawn = execution.spawnedNodes.first {
            return LocationNode(
                type: spawn.nodeType,
                summary: spawn.summary,
                discovered: false,
                visitedCount: 0,
                origin: "system",
                tags: spawn.tags
            )
        }
        return LocationNode(type: "room", summary: "Bare stone chamber", discovered: false, visitedCount: 0, origin: "system", tags: ["entry"])
    }

    private mutating func addRoomContents(
        to node: LocationNode,
        campaign: Campaign,
        context: RollContext,
        seed: UInt64
    ) {
        guard var tableEngine else { return }
        let sequence = campaign.rngSequence ?? 0
        let execution = tableEngine.execute(tableId: "room_contents", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)

        if !execution.spawnedTraps.isEmpty {
            let traps = execution.spawnedTraps.map { spawn in
                TrapEntity(
                    name: "\(spawn.category.capitalized) Trap",
                    category: spawn.category,
                    trigger: spawn.trigger,
                    detectionSkill: spawn.detectionSkill,
                    detectionDC: spawn.detectionDC,
                    disarmSkill: spawn.disarmSkill,
                    disarmDC: spawn.disarmDC,
                    saveSkill: spawn.saveSkill,
                    saveDC: spawn.saveDC,
                    effectSummary: spawn.effect,
                    state: "hidden",
                    isResettable: false,
                    origin: "system",
                    locationNodeId: node.id
                )
            }
            node.traps = traps
        }
    }

    private mutating func addPassageFeatures(
        to node: LocationNode,
        campaign: Campaign,
        context: RollContext,
        seed: UInt64
    ) {
        guard var tableEngine else { return }
        let sequence = campaign.rngSequence ?? 0
        let execution = tableEngine.execute(tableId: "passage_features", context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)
        if let note = execution.logs.first, !note.isEmpty {
            node.contentSummary = note
        }
    }

    private func attachTableRolls(
        _ results: [TableRollResult],
        campaign: Campaign,
        context: RollContext
    ) {
        guard !results.isEmpty else { return }
        let logEntries = results.map { result in
            let entryRange = "\(result.entry.min)-\(result.entry.max)"
            let contextSummary = "Location \(context.locationId?.uuidString ?? "n/a") tags: \(context.tags.joined(separator: ", "))"
            return TableRollRecord(
                tableId: result.tableId,
                entryRange: entryRange,
                diceSpec: result.roll.spec,
                rollTotal: result.roll.total,
                modifier: result.roll.modifier,
                seed: result.seed,
                sequence: result.sequence,
                contextSummary: contextSummary,
                outcomeSummary: "Actions: \(result.entry.actions.map { $0.type }.joined(separator: ", "))"
            )
        }

        if campaign.tableRolls == nil {
            campaign.tableRolls = logEntries
        } else {
            campaign.tableRolls?.append(contentsOf: logEntries)
        }

        campaign.rngSequence = results.map { $0.sequence }.max() ?? campaign.rngSequence
    }
}
