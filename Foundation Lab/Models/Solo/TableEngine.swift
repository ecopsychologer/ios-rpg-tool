import Foundation

struct ContentPack: Codable {
    let id: String
    let version: String
    let tables: [TableDefinition]
}

struct TableDefinition: Codable {
    let id: String
    let name: String
    let scope: String
    let diceSpec: String
    let entries: [TableEntry]
}

struct TableEntry: Codable {
    let min: Int
    let max: Int
    let actions: [OutcomeAction]
}

struct OutcomeAction: Codable {
    let type: String
    let nodeType: String?
    let edgeType: String?
    let summary: String?
    let tags: [String]?
    let category: String?
    let trigger: String?
    let detectionSkill: String?
    let detectionDC: Int?
    let disarmSkill: String?
    let disarmDC: Int?
    let saveSkill: String?
    let saveDC: Int?
    let effect: String?
    let tableId: String?
    let diceSpec: String?
    let threshold: Int?
    let modifier: Int?
    let thenActions: [OutcomeAction]?
    let elseActions: [OutcomeAction]?
    let message: String?
}

struct RollContext {
    let campaignId: UUID
    let sceneId: UUID?
    let locationId: UUID?
    let nodeId: UUID?
    let tags: [String]
    let dangerModifier: Int
    let depth: Int
}

struct TableRollResult {
    let tableId: String
    let entry: TableEntry
    let roll: DiceRoll
    let sequence: Int
    let seed: UInt64
}

struct TableExecution {
    let rollResults: [TableRollResult]
    let spawnedNodes: [TableSpawnNode]
    let spawnedEdges: [TableSpawnEdge]
    let spawnedTraps: [TableSpawnTrap]
    let logs: [String]
}

struct TableSpawnNode {
    let nodeType: String
    let summary: String
    let tags: [String]
}

struct TableSpawnEdge {
    let edgeType: String
    let summary: String
    let tags: [String]
}

struct TableSpawnTrap {
    let category: String
    let trigger: String
    let detectionSkill: String
    let detectionDC: Int
    let disarmSkill: String
    let disarmDC: Int
    let saveSkill: String?
    let saveDC: Int?
    let effect: String
}

struct DiceRoll {
    let spec: String
    let rolls: [Int]
    let modifier: Int
    let total: Int
}

struct DiceSpec {
    let count: Int
    let sides: Int
    let modifier: Int

    static func parse(_ input: String) -> DiceSpec? {
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

struct SeededRNG {
    private(set) var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        let value = next()
        return Int(value % UInt64(upperBound))
    }
}

struct DiceRoller {
    private var rng: SeededRNG
    private(set) var sequence: Int

    init(seed: UInt64, sequence: Int) {
        self.rng = SeededRNG(seed: seed)
        self.sequence = sequence
        if sequence > 0 {
            for _ in 0..<sequence {
                _ = rng.next()
            }
        }
    }

    mutating func roll(spec: String) -> DiceRoll {
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

struct TableEngine {
    let tables: [String: TableDefinition]

    init(contentPack: ContentPack) {
        var tableMap: [String: TableDefinition] = [:]
        for table in contentPack.tables {
            tableMap[table.id] = table
        }
        self.tables = tableMap
    }

    func table(id: String) -> TableDefinition? {
        tables[id]
    }

    mutating func execute(
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
