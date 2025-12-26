import Foundation

public struct ContentPack: Codable {
    public let id: String
    public let version: String
    public let tables: [TableDefinition]
}

public struct TableDefinition: Codable {
    public let id: String
    public let name: String
    public let scope: String
    public let diceSpec: String
    public let entries: [TableEntry]
}

public struct TableEntry: Codable {
    public let min: Int
    public let max: Int
    public let actions: [OutcomeAction]
}

public struct OutcomeAction: Codable {
    public let type: String
    public let nodeType: String?
    public let edgeType: String?
    public let summary: String?
    public let tags: [String]?
    public let category: String?
    public let trigger: String?
    public let detectionSkill: String?
    public let detectionDC: Int?
    public let disarmSkill: String?
    public let disarmDC: Int?
    public let saveSkill: String?
    public let saveDC: Int?
    public let effect: String?
    public let tableId: String?
    public let diceSpec: String?
    public let threshold: Int?
    public let modifier: Int?
    public let thenActions: [OutcomeAction]?
    public let elseActions: [OutcomeAction]?
    public let message: String?
}

public struct RollContext {
    public let campaignId: UUID
    public let sceneId: UUID?
    public let locationId: UUID?
    public let nodeId: UUID?
    public let tags: [String]
    public let dangerModifier: Int
    public let depth: Int
}

public struct TableRollResult {
    public let tableId: String
    public let entry: TableEntry
    public let roll: DiceRoll
    public let sequence: Int
    public let seed: UInt64
}

public struct TableExecution {
    public let rollResults: [TableRollResult]
    public let spawnedNodes: [TableSpawnNode]
    public let spawnedEdges: [TableSpawnEdge]
    public let spawnedTraps: [TableSpawnTrap]
    public let logs: [String]
}

public struct TableSpawnNode {
    public let nodeType: String
    public let summary: String
    public let tags: [String]
}

public struct TableSpawnEdge {
    public let edgeType: String
    public let summary: String
    public let tags: [String]
}

public struct TableSpawnTrap {
    public let category: String
    public let trigger: String
    public let detectionSkill: String
    public let detectionDC: Int
    public let disarmSkill: String
    public let disarmDC: Int
    public let saveSkill: String?
    public let saveDC: Int?
    public let effect: String
}

public struct DiceRoll {
    public let spec: String
    public let rolls: [Int]
    public let modifier: Int
    public let total: Int
}

public struct DiceSpec {
    public let count: Int
    public let sides: Int
    public let modifier: Int

    public static func parse(_ input: String) -> DiceSpec? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = normalized.split(separator: "d", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }

        let count = Int(parts[0].isEmpty ? "1" : parts[0]) ?? 1
        let remainder = parts[1]
        let modifierSplit = remainder.split(separator: "+", maxSplits: 1).map(String.init)
        let sides = Int(modifierSplit[0]) ?? 0
        let modifier = modifierSplit.count > 1 ? (Int(modifierSplit[1]) ?? 0) : 0
        guard sides > 0 else { return nil }
        return DiceSpec(count: count, sides: sides, modifier: modifier)
    }
}

public struct SeededRNG {
    private(set) var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    public mutating func nextInt(upperBound: Int) -> Int {
        let value = next()
        return Int(value % UInt64(upperBound))
    }
}

public struct DiceRoller {
    private var rng: SeededRNG
    private(set) var sequence: Int

    public init(seed: UInt64, sequence: Int) {
        self.rng = SeededRNG(seed: seed)
        self.sequence = sequence
        if sequence > 0 {
            for _ in 0..<sequence {
                _ = rng.next()
            }
        }
    }

    public mutating func roll(spec: String) -> DiceRoll {
        let diceSpec = DiceSpec.parse(spec) ?? DiceSpec(count: 1, sides: 100, modifier: 0)
        var results: [Int] = []
        for _ in 0..<diceSpec.count {
            let roll = rng.nextInt(upperBound: diceSpec.sides) + 1
            results.append(roll)
            sequence += 1
        }
        let total = results.reduce(0, +) + diceSpec.modifier
        return DiceRoll(spec: spec, rolls: results, modifier: diceSpec.modifier, total: total)
    }
}

public struct TableEngine {
    public let tables: [String: TableDefinition]

    public init(contentPack: ContentPack) {
        var tableMap: [String: TableDefinition] = [:]
        for table in contentPack.tables {
            tableMap[table.id] = table
        }
        self.tables = tableMap
    }

    public func table(id: String) -> TableDefinition? {
        tables[id]
    }

    public mutating func execute(
        tableId: String,
        context: RollContext,
        seed: UInt64,
        sequence: Int
    ) -> TableExecution {
        guard let table = tables[tableId] else {
            return TableExecution(rollResults: [], spawnedNodes: [], spawnedEdges: [], spawnedTraps: [], logs: ["Missing table: \(tableId)"])
        }

        var roller = DiceRoller(seed: seed, sequence: sequence)
        let roll = roller.roll(spec: table.diceSpec)
        let entry = resolveEntry(for: roll.total, in: table) ?? table.entries.first!
        let rollResult = TableRollResult(tableId: tableId, entry: entry, roll: roll, sequence: roller.sequence, seed: seed)

        let actionResult = executeActions(entry.actions, context: context, seed: seed, sequence: roller.sequence)

        return TableExecution(
            rollResults: [rollResult] + actionResult.rollResults,
            spawnedNodes: actionResult.spawnedNodes,
            spawnedEdges: actionResult.spawnedEdges,
            spawnedTraps: actionResult.spawnedTraps,
            logs: actionResult.logs
        )
    }

    private func resolveEntry(for roll: Int, in table: TableDefinition) -> TableEntry? {
        table.entries.first(where: { roll >= $0.min && roll <= $0.max })
    }

    private mutating func executeActions(
        _ actions: [OutcomeAction],
        context: RollContext,
        seed: UInt64,
        sequence: Int
    ) -> TableExecution {
        var rollResults: [TableRollResult] = []
        var nodes: [TableSpawnNode] = []
        var edges: [TableSpawnEdge] = []
        var traps: [TableSpawnTrap] = []
        var logs: [String] = []

        var currentSequence = sequence

        for action in actions {
            switch action.type {
            case "spawnNode":
                let nodeType = action.nodeType ?? "room"
                let summary = action.summary ?? "Unremarkable space"
                let tags = action.tags ?? []
                nodes.append(TableSpawnNode(nodeType: nodeType, summary: summary, tags: tags))
            case "spawnEdge":
                let edgeType = action.edgeType ?? "open"
                let summary = action.summary ?? "Connection"
                let tags = action.tags ?? []
                edges.append(TableSpawnEdge(edgeType: edgeType, summary: summary, tags: tags))
            case "spawnTrap":
                let trap = TableSpawnTrap(
                    category: action.category ?? "mechanical",
                    trigger: action.trigger ?? "pressure plate",
                    detectionSkill: action.detectionSkill ?? "Investigation",
                    detectionDC: action.detectionDC ?? 13,
                    disarmSkill: action.disarmSkill ?? "Thieves' Tools",
                    disarmDC: action.disarmDC ?? 13,
                    saveSkill: action.saveSkill,
                    saveDC: action.saveDC,
                    effect: action.effect ?? "Alarm and minor injury"
                )
                traps.append(trap)
            case "rollOnTable":
                guard let tableId = action.tableId else { continue }
                let nested = execute(tableId: tableId, context: context, seed: seed, sequence: currentSequence)
                rollResults.append(contentsOf: nested.rollResults)
                nodes.append(contentsOf: nested.spawnedNodes)
                edges.append(contentsOf: nested.spawnedEdges)
                traps.append(contentsOf: nested.spawnedTraps)
                logs.append(contentsOf: nested.logs)
                currentSequence = nested.rollResults.last?.sequence ?? currentSequence
            case "conditionalRoll":
                guard let diceSpec = action.diceSpec, let threshold = action.threshold else { continue }
                var roller = DiceRoller(seed: seed, sequence: currentSequence)
                let roll = roller.roll(spec: diceSpec)
                currentSequence = roller.sequence
                let entry = TableEntry(min: roll.total, max: roll.total, actions: [])
                rollResults.append(TableRollResult(tableId: "conditional", entry: entry, roll: roll, sequence: currentSequence, seed: seed))
                let branchActions = roll.total <= threshold ? (action.thenActions ?? []) : (action.elseActions ?? [])
                let nested = executeActions(branchActions, context: context, seed: seed, sequence: currentSequence)
                rollResults.append(contentsOf: nested.rollResults)
                nodes.append(contentsOf: nested.spawnedNodes)
                edges.append(contentsOf: nested.spawnedEdges)
                traps.append(contentsOf: nested.spawnedTraps)
                logs.append(contentsOf: nested.logs)
                currentSequence = nested.rollResults.last?.sequence ?? currentSequence
            case "log":
                if let message = action.message {
                    logs.append(message)
                }
            default:
                continue
            }
        }

        return TableExecution(
            rollResults: rollResults,
            spawnedNodes: nodes,
            spawnedEdges: edges,
            spawnedTraps: traps,
            logs: logs
        )
    }
}
