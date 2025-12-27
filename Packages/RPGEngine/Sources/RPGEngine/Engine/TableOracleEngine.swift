import Foundation
import TableEngine
import WorldState

public struct TableOracleEngine {
    private var tableEngine: TableEngine?
    private let packStore = ContentPackStore()

    public init() {}

    @discardableResult
    public mutating func rollTable(
        campaign: Campaign,
        tableId: String,
        tags: [String] = []
    ) -> TableExecution? {
        do {
            try ensureTableEngine()
        } catch {
            return nil
        }
        guard var tableEngine else { return nil }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        let context = RollContext(
            campaignId: campaign.id,
            sceneId: campaign.activeSceneId,
            locationId: campaign.activeLocationId,
            nodeId: campaign.activeNodeId,
            tags: tags,
            dangerModifier: 0,
            depth: 0
        )

        let execution = tableEngine.execute(tableId: tableId, context: context, seed: seed, sequence: sequence)
        self.tableEngine = tableEngine
        attachTableRolls(execution.rollResults, campaign: campaign, context: context)
        return execution
    }

    public mutating func rollMessage(
        campaign: Campaign,
        tableId: String,
        tags: [String] = []
    ) -> String? {
        guard let execution = rollTable(campaign: campaign, tableId: tableId, tags: tags) else { return nil }
        return execution.logs.first
    }

    private mutating func ensureTableEngine() throws {
        if tableEngine != nil { return }
        let pack = try packStore.loadDefaultPack()
        tableEngine = TableEngine(contentPack: pack)
    }

    private func attachTableRolls(
        _ results: [TableRollResult],
        campaign: Campaign,
        context: RollContext
    ) {
        guard !results.isEmpty else { return }
        let logEntries = results.map { result in
            let entryRange = "\(result.entry.min)-\(result.entry.max)"
            let contextSummary = "Tags: \(context.tags.joined(separator: ", "))"
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
