import Foundation

struct SoloLocationEngine {
    private var tableEngine: TableEngine?
    private let packStore = ContentPackStore()

    mutating func generateDungeonStart(campaign: Campaign) -> LocationEntity? {
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
