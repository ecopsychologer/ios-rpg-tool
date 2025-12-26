import Foundation
import TableEngine
import WorldState

public struct NpcGenerationOptions {
    public var name: String?
    public var species: String?
    public var roleTag: String?
    public var importance: NPCImportance
}

public struct SoloNpcEngine {
    private var tableEngine: TableEngine?
    private let packStore = ContentPackStore()

    public mutating func generateNPC(campaign: Campaign, options: NpcGenerationOptions) -> NPCEntry? {
        do {
            try ensureTableEngine()
        } catch {
            return nil
        }
        guard var tableEngine else { return nil }

        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        campaign.rngSeed = seed

        let context = RollContext(
            campaignId: campaign.id,
            sceneId: campaign.activeSceneId,
            locationId: campaign.activeLocationId,
            nodeId: campaign.activeNodeId,
            tags: ["npc", options.importance.rawValue],
            dangerModifier: 0,
            depth: 0
        )

        var rolls: [NPCGenerationRoll] = []

        func rollText(_ tableId: String) -> String? {
            let execution = tableEngine.execute(tableId: tableId, context: context, seed: seed, sequence: campaign.rngSequence ?? 0)
            self.tableEngine = tableEngine
            if let roll = execution.rollResults.first {
                let entryId = "\(roll.entry.min)-\(roll.entry.max)"
                let text = execution.logs.first ?? ""
                rolls.append(NPCGenerationRoll(tableId: tableId, rollValue: roll.roll.total, pickedEntryId: entryId, resultText: text))
                campaign.rngSequence = execution.rollResults.map { $0.sequence }.max() ?? campaign.rngSequence
                return text
            }
            return nil
        }

        let srdSpecies = loadSrdSpecies()
        let species = options.species ?? srdSpecies.randomElement() ?? rollText("npc_species") ?? "Unknown"
        let roleTag = options.roleTag ?? rollText("npc_role") ?? "Wanderer"
        let mood = rollText("npc_mood") ?? "neutral"
        let voice = rollText("npc_voice") ?? ""
        let mannerism = rollText("npc_mannerism") ?? ""

        let notableCount: Int
        switch options.importance {
        case .minor:
            notableCount = 1
        case .supporting:
            notableCount = 2
        case .major:
            notableCount = 3
        }

        var notableFeatures: [String] = []
        for _ in 0..<notableCount {
            if let feature = rollText("npc_notable_feature"), !feature.isEmpty, !notableFeatures.contains(feature) {
                notableFeatures.append(feature)
            }
        }

        var quirks: [String] = []
        var flaws: [String] = []
        if options.importance == .minor {
            if let quirk = rollText("npc_quirk"), !quirk.isEmpty {
                quirks.append(quirk)
            }
        } else {
            if let quirk = rollText("npc_quirk"), !quirk.isEmpty {
                quirks.append(quirk)
            }
            if let flaw = rollText("npc_flaw"), !flaw.isEmpty {
                flaws.append(flaw)
            }
        }

        var goalsImmediate: [String] = []
        if let goal = rollText("npc_goal"), !goal.isEmpty {
            goalsImmediate.append(goal)
        }

        var goalsLongTerm: [String] = []
        if options.importance != .minor, let goal = rollText("npc_goal"), !goal.isEmpty {
            goalsLongTerm.append(goal)
        }

        var backstoryEvents: [String] = []
        if options.importance == .major, let event = rollText("npc_life_event"), !event.isEmpty {
            backstoryEvents.append(event)
        }

        let nameOverride = options.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (nameOverride?.isEmpty == false) ? nameOverride! : generateName(using: { rollText($0) })

        let npc = NPCEntry(
            name: resolvedName,
            species: species,
            roleTag: roleTag,
            importance: options.importance.rawValue,
            origin: "generator"
        )

        npc.currentMood = mood
        npc.speechStyle = voice.isEmpty ? nil : voice
        npc.mannerisms = mannerism.isEmpty ? [] : [mannerism]
        npc.notableFeatures = notableFeatures
        npc.quirks = quirks
        npc.flaws = flaws
        npc.goalsImmediate = goalsImmediate
        npc.goalsLongTerm = goalsLongTerm
        npc.backstoryKeyEvents = backstoryEvents
        npc.appearanceShort = buildAppearanceShort(roleTag: roleTag, species: species, features: notableFeatures)
        npc.derivedAppearanceShort = npc.appearanceShort
        npc.generationSeed = String(seed)
        npc.generationCreatedBy = "generator"
        npc.generationRolls = rolls
        npc.generationVersion = "solo_default@0.1"

        return npc
    }

    private func buildAppearanceShort(roleTag: String, species: String, features: [String]) -> String {
        guard let first = features.first else {
            return "\(roleTag) \(species)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "\(roleTag) \(species) with \(first.lowercased())"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateName(using rollText: (String) -> String?) -> String {
        let core = rollText("npc_name_core") ?? "Rin"
        let style = rollText("npc_name_style") ?? "nb"
        let suffixTable: String
        switch style {
        case "masc":
            suffixTable = "npc_name_suffix_masc"
        case "femme":
            suffixTable = "npc_name_suffix_femme"
        default:
            suffixTable = "npc_name_suffix_nb"
        }
        let suffix = rollText(suffixTable) ?? ""
        return "\(core)\(suffix)"
    }

    private func loadSrdSpecies() -> [String] {
        if let imported = loadSpeciesFromImportedSRD(), !imported.isEmpty {
            return imported
        }
        if let local = loadSpeciesFromLocalSRD(), !local.isEmpty {
            return local
        }
        return []
    }

    private func loadSpeciesFromImportedSRD() -> [String]? {
        let fileManager = FileManager.default
        guard let directory = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let url = directory.appendingPathComponent("srd_import")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return parseSpecies(from: url)
    }

    private func loadSpeciesFromLocalSRD() -> [String]? {
        let url = URL(fileURLWithPath: "dnd-5e-srd/json/01 races.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return parseSpecies(from: url)
    }

    private func parseSpecies(from url: URL) -> [String]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let dict = json as? [String: Any], let races = dict["Races"] as? [String: Any] else { return nil }
        let names = races.keys.filter { $0.lowercased() != "racial traits" }
        return names.sorted()
    }

    private mutating func ensureTableEngine() throws {
        if tableEngine != nil { return }
        let pack = try packStore.loadDefaultPack()
        tableEngine = TableEngine(contentPack: pack)
    }
}
