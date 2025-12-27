import SwiftUI
import Combine
import SwiftData
import RPGEngine
import WorldState
import TableEngine

#if DEV_FIXTURES
struct DevTestScenario: Codable, Identifiable {
    let id: String
    let title: String
    let actions: [TestAction]
}

struct DevAbilities: Codable {
    let strength: Int
    let dexterity: Int
    let constitution: Int
    let intelligence: Int
    let wisdom: Int
    let charisma: Int
}

enum TestAction: Codable {
    case loadFixtures(name: String)
    case createCampaign(name: String)
    case setPartySize(Int)
    case createCharacter(name: String, level: Int, abilities: DevAbilities, proficiencies: [String])
    case createSidekick(name: String, level: Int, abilities: DevAbilities)
    case setWorldLore(title: String, description: String)
    case runScene(description: String, input: String)
    case performSkillCheck(skill: String, difficulty: Int)
    case moveToLocation(label: String)
    case importTables(filename: String)

    private enum CodingKeys: String, CodingKey { case type, value1, value2, value3, value4 }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "loadFixtures":
            let name = try container.decode(String.self, forKey: .value1)
            self = .loadFixtures(name: name)
        case "createCampaign":
            let name = try container.decode(String.self, forKey: .value1)
            self = .createCampaign(name: name)
        case "setPartySize":
            let count = try container.decode(Int.self, forKey: .value1)
            self = .setPartySize(count)
        case "createCharacter":
            let name = try container.decode(String.self, forKey: .value1)
            let level = try container.decode(Int.self, forKey: .value2)
            let abilities = try container.decode(DevAbilities.self, forKey: .value3)
            let proficiencies = try container.decode([String].self, forKey: .value4)
            self = .createCharacter(name: name, level: level, abilities: abilities, proficiencies: proficiencies)
        case "createSidekick":
            let name = try container.decode(String.self, forKey: .value1)
            let level = try container.decode(Int.self, forKey: .value2)
            let abilities = try container.decode(DevAbilities.self, forKey: .value3)
            self = .createSidekick(name: name, level: level, abilities: abilities)
        case "setWorldLore":
            let title = try container.decode(String.self, forKey: .value1)
            let description = try container.decode(String.self, forKey: .value2)
            self = .setWorldLore(title: title, description: description)
        case "runScene":
            let description = try container.decode(String.self, forKey: .value1)
            let input = try container.decode(String.self, forKey: .value2)
            self = .runScene(description: description, input: input)
        case "performSkillCheck":
            let skill = try container.decode(String.self, forKey: .value1)
            let difficulty = try container.decode(Int.self, forKey: .value2)
            self = .performSkillCheck(skill: skill, difficulty: difficulty)
        case "moveToLocation":
            let label = try container.decode(String.self, forKey: .value1)
            self = .moveToLocation(label: label)
        case "importTables":
            let filename = try container.decode(String.self, forKey: .value1)
            self = .importTables(filename: filename)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown TestAction type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .loadFixtures(let name):
            try container.encode("loadFixtures", forKey: .type)
            try container.encode(name, forKey: .value1)
        case .createCampaign(let name):
            try container.encode("createCampaign", forKey: .type)
            try container.encode(name, forKey: .value1)
        case .setPartySize(let count):
            try container.encode("setPartySize", forKey: .type)
            try container.encode(count, forKey: .value1)
        case .createCharacter(let name, let level, let abilities, let proficiencies):
            try container.encode("createCharacter", forKey: .type)
            try container.encode(name, forKey: .value1)
            try container.encode(level, forKey: .value2)
            try container.encode(abilities, forKey: .value3)
            try container.encode(proficiencies, forKey: .value4)
        case .createSidekick(let name, let level, let abilities):
            try container.encode("createSidekick", forKey: .type)
            try container.encode(name, forKey: .value1)
            try container.encode(level, forKey: .value2)
            try container.encode(abilities, forKey: .value3)
        case .setWorldLore(let title, let description):
            try container.encode("setWorldLore", forKey: .type)
            try container.encode(title, forKey: .value1)
            try container.encode(description, forKey: .value2)
        case .runScene(let description, let input):
            try container.encode("runScene", forKey: .type)
            try container.encode(description, forKey: .value1)
            try container.encode(input, forKey: .value2)
        case .performSkillCheck(let skill, let difficulty):
            try container.encode("performSkillCheck", forKey: .type)
            try container.encode(skill, forKey: .value1)
            try container.encode(difficulty, forKey: .value2)
        case .moveToLocation(let label):
            try container.encode("moveToLocation", forKey: .type)
            try container.encode(label, forKey: .value1)
        case .importTables(let filename):
            try container.encode("importTables", forKey: .type)
            try container.encode(filename, forKey: .value1)
        }
    }
}

final class DevTestRunner: ObservableObject {
    @Published var log: [String] = []
    @Published var isRunning = false

    private var engine = SoloCampaignEngine()
    private var locationEngine = SoloLocationEngine()

    @MainActor
    func run(_ scenario: DevTestScenario, modelContext: ModelContext) async {
        log.removeAll()
        isRunning = true
        defer { isRunning = false }

        append("Running: \(scenario.title)")
        for action in scenario.actions {
            await execute(action, modelContext: modelContext)
        }
    }

    @MainActor
    private func execute(_ action: TestAction, modelContext: ModelContext) async {
        switch action {
        case .loadFixtures(let name):
            append("Loading fixtures: \(name)")
            if let fixture = loadFixture(named: name) {
                applyFixture(fixture, modelContext: modelContext)
                append("Fixtures loaded")
            } else {
                append("Fixture not found")
            }
        case .createCampaign(let name):
            let campaign = createCampaign(named: name, modelContext: modelContext)
            append("Created campaign: \(campaign.title)")
        case .setPartySize(let count):
            if let campaign = activeCampaign(in: modelContext) {
                setPartySize(count, campaign: campaign)
                append("Party size set to \(count)")
            }
        case .createCharacter(let name, let level, let abilities, let proficiencies):
            if let campaign = activeCampaign(in: modelContext) {
                let character = createCharacter(
                    name: name,
                    level: level,
                    abilities: abilities,
                    proficiencies: proficiencies
                )
                campaign.playerCharacters.append(character)
                addPartyMember(name: name, level: level, campaign: campaign, isNpc: false, npcId: nil)
                append("Added character: \(name)")
            }
        case .createSidekick(let name, let level, let abilities):
            if let campaign = activeCampaign(in: modelContext) {
                let npc = NPCEntry(name: name, species: "Unknown", roleTag: "Sidekick", importance: NPCImportance.supporting.rawValue, origin: "dev")
                npc.abilityScores = buildNpcAbilityScores(abilities)
                npc.levelOrCR = level
                campaign.npcs.append(npc)
                addPartyMember(name: name, level: level, campaign: campaign, isNpc: true, npcId: npc.id)
                append("Added sidekick: \(name)")
            }
        case .setWorldLore(let title, let description):
            if let campaign = activeCampaign(in: modelContext) {
                let entry = WorldLoreEntry(title: title, summary: description, tags: [], origin: "dev")
                campaign.worldLore.append(entry)
                append("World lore: \(title)")
            }
        case .runScene(let description, let input):
            if let campaign = activeCampaign(in: modelContext) {
                let sceneRecord = engine.resolveScene(campaign: campaign, expectedScene: description)
                let interaction = SceneInteraction(playerText: input, gmText: "Dev test response")
                let bookkeeping = BookkeepingInput(
                    summary: input,
                    newCharacters: [],
                    newThreads: [],
                    featuredCharacters: [],
                    featuredThreads: [],
                    removedCharacters: [],
                    removedThreads: [],
                    pcsInControl: true,
                    concluded: false,
                    interactions: [interaction],
                    skillChecks: [],
                    fateQuestions: [],
                    places: [],
                    curiosities: [],
                    rollHighlights: [],
                    locationId: campaign.activeLocationId,
                    generatedEntityIds: [],
                    canonizations: []
                )
                _ = engine.finalizeScene(campaign: campaign, scene: sceneRecord, bookkeeping: bookkeeping)
                append("Scene resolved: \(description)")
            }
        case .performSkillCheck(let skill, let difficulty):
            if let campaign = activeCampaign(in: modelContext) {
                let record = SkillCheckRecord(
                    playerAction: "Dev test \(skill) check",
                    checkType: CheckType.skillCheck.rawValue,
                    skill: skill,
                    abilityOverride: nil,
                    dc: difficulty,
                    opponentSkill: nil,
                    opponentDC: nil,
                    advantageState: AdvantageState.normal.rawValue,
                    stakes: "Dev test stakes",
                    partialSuccessDC: nil,
                    partialSuccessOutcome: nil,
                    reason: "Dev test"
                )
                if let last = campaign.scenes.last {
                    var checks = last.skillChecks ?? []
                    checks.append(record)
                    last.skillChecks = checks
                }
                append("Skill check queued: \(skill) DC \(difficulty)")
            }
        case .moveToLocation(let label):
            if let campaign = activeCampaign(in: modelContext) {
                if campaign.locations?.isEmpty ?? true {
                    _ = locationEngine.generateDungeonStart(campaign: campaign)
                } else {
                    let location = ensureLocation(named: label, campaign: campaign)
                    campaign.activeLocationId = location.id
                }
                append("Moved to location: \(label)")
            }
        case .importTables(let filename):
            append("Importing tables: \(filename)")
            if let text = loadTextAsset(named: filename, subdirectory: "DevAssets/fixtures") {
                let importer = TableImporter()
                let tables = importer.importMarkdown(text, defaultName: "Dev Imported")
                append("Parsed \(tables.count) table(s)")
            } else {
                append("Table file not found")
            }
        }

        try? modelContext.save()
    }

    @MainActor
    private func createCampaign(named name: String, modelContext: ModelContext) -> Campaign {
        let campaigns = fetchCampaigns(modelContext)
        for campaign in campaigns {
            campaign.isActive = false
        }
        let campaign = Campaign(title: name.isEmpty ? "Dev Campaign" : name)
        modelContext.insert(campaign)
        campaign.isActive = true
        campaign.rulesetName = RulesetCatalog.srd.displayName
        return campaign
    }

    @MainActor
    private func activeCampaign(in modelContext: ModelContext) -> Campaign? {
        let campaigns = fetchCampaigns(modelContext)
        return campaigns.first(where: { $0.isActive }) ?? campaigns.first
    }

    @MainActor
    private func fetchCampaigns(_ modelContext: ModelContext) -> [Campaign] {
        let descriptor = FetchDescriptor<Campaign>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func setPartySize(_ count: Int, campaign: Campaign) {
        let clamped = max(0, count)
        if campaign.party == nil {
            campaign.party = Party()
        }
        let existing = campaign.party?.members ?? []
        if clamped <= existing.count {
            campaign.party?.members = Array(existing.prefix(clamped))
        } else {
            var members = existing
            for index in existing.count..<clamped {
                members.append(PartyMember(name: "Member \(index + 1)", role: "", level: 1, notes: "", isNpc: false))
            }
            campaign.party?.members = members
        }
    }

    private func addPartyMember(name: String, level: Int, campaign: Campaign, isNpc: Bool, npcId: UUID?) {
        if campaign.party == nil {
            campaign.party = Party()
        }
        var members = campaign.party?.members ?? []
        if !members.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            members.append(PartyMember(name: name, role: isNpc ? "Sidekick" : "PC", level: level, notes: "", isNpc: isNpc, npcId: npcId))
            campaign.party?.members = members
        }
    }

    private func ensureLocation(named name: String, campaign: Campaign) -> LocationEntity {
        if let existing = campaign.locations?.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let location = LocationEntity(name: name, type: "site", origin: "dev")
        if campaign.locations == nil {
            campaign.locations = []
        }
        campaign.locations?.append(location)
        return location
    }

    private func createCharacter(
        name: String,
        level: Int,
        abilities: DevAbilities,
        proficiencies: [String]
    ) -> PlayerCharacter {
        let character = PlayerCharacter(displayName: name, rulesetId: RulesetCatalog.srd.id, origin: "dev")
        updateField(character, key: "name", stringValue: name)
        updateField(character, key: "level", intValue: level)
        updateField(character, key: "str", intValue: abilities.strength)
        updateField(character, key: "dex", intValue: abilities.dexterity)
        updateField(character, key: "con", intValue: abilities.constitution)
        updateField(character, key: "int", intValue: abilities.intelligence)
        updateField(character, key: "wis", intValue: abilities.wisdom)
        updateField(character, key: "cha", intValue: abilities.charisma)
        updateField(character, key: "skills", listValue: proficiencies)
        return character
    }

    private func updateField(_ character: PlayerCharacter, key: String, stringValue: String) {
        guard let field = character.fields.first(where: { $0.key == key }) else { return }
        field.valueString = stringValue
        field.status = SheetFieldStatus.confirmed.rawValue
        field.sourceType = "dev"
        field.updatedAt = Date()
    }

    private func updateField(_ character: PlayerCharacter, key: String, intValue: Int) {
        guard let field = character.fields.first(where: { $0.key == key }) else { return }
        field.valueInt = intValue
        field.valueString = String(intValue)
        field.status = SheetFieldStatus.confirmed.rawValue
        field.sourceType = "dev"
        field.updatedAt = Date()
    }

    private func updateField(_ character: PlayerCharacter, key: String, listValue: [String]) {
        guard let field = character.fields.first(where: { $0.key == key }) else { return }
        field.valueStringList = listValue
        field.status = SheetFieldStatus.confirmed.rawValue
        field.sourceType = "dev"
        field.updatedAt = Date()
    }

    private func buildNpcAbilityScores(_ abilities: DevAbilities) -> [NPCAbilityScore] {
        [
            NPCAbilityScore(ability: "STR", score: abilities.strength),
            NPCAbilityScore(ability: "DEX", score: abilities.dexterity),
            NPCAbilityScore(ability: "CON", score: abilities.constitution),
            NPCAbilityScore(ability: "INT", score: abilities.intelligence),
            NPCAbilityScore(ability: "WIS", score: abilities.wisdom),
            NPCAbilityScore(ability: "CHA", score: abilities.charisma)
        ]
    }

    private func loadFixture(named name: String) -> DevCampaignFixture? {
        guard let data = loadDataAsset(named: name, subdirectory: "DevAssets/fixtures") else { return nil }
        return try? JSONDecoder().decode(DevCampaignFixture.self, from: data)
    }

    @MainActor
    private func applyFixture(_ fixture: DevCampaignFixture, modelContext: ModelContext) {
        let campaign = createCampaign(named: fixture.title ?? "Dev Campaign", modelContext: modelContext)
        if let vibe = fixture.worldVibe {
            campaign.worldVibe = vibe
        }
        if let size = fixture.partySize {
            setPartySize(size, campaign: campaign)
        }
        for lore in fixture.worldLore ?? [] {
            campaign.worldLore.append(WorldLoreEntry(title: lore.title, summary: lore.summary, tags: lore.tags ?? [], origin: "dev"))
        }
        for character in fixture.characters ?? [] {
            let pc = createCharacter(
                name: character.name,
                level: character.level ?? 1,
                abilities: character.abilities ?? DevAbilities(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
                proficiencies: character.proficiencies ?? []
            )
            campaign.playerCharacters.append(pc)
            addPartyMember(name: pc.displayName, level: character.level ?? 1, campaign: campaign, isNpc: false, npcId: nil)
        }
    }

    private func loadDataAsset(named name: String, subdirectory: String) -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdirectory) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func loadTextAsset(named name: String, subdirectory: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: subdirectory),
              let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @MainActor
    private func append(_ message: String) {
        log.append(message)
    }
}

struct DevCampaignFixture: Codable {
    let title: String?
    let worldVibe: String?
    let partySize: Int?
    let worldLore: [DevWorldLoreFixture]?
    let characters: [DevCharacterFixture]?
}

struct DevWorldLoreFixture: Codable {
    let title: String
    let summary: String
    let tags: [String]?
}

struct DevCharacterFixture: Codable {
    let name: String
    let level: Int?
    let abilities: DevAbilities?
    let proficiencies: [String]?
}

struct DevTestScenariosView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var runner = DevTestRunner()
    @State private var scenarios: [DevTestScenario] = []
    @State private var selectedScenario: DevTestScenario?
    @State private var showLog = false

    var body: some View {
        List {
            if scenarios.isEmpty {
                Text("No scenarios found. Add JSON files to DevAssets/tests to load them.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(scenarios) { scenario in
                    Button(scenario.title) {
                        selectedScenario = scenario
                        Task {
                            await runner.run(scenario, modelContext: modelContext)
                            showLog = true
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Dev Test Scenarios")
        .onAppear(perform: loadScenarios)
        .sheet(isPresented: $showLog) {
            DevTestLogView(log: runner.log, isRunning: runner.isRunning)
        }
    }

    private func loadScenarios() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "DevAssets/tests") ?? []
        var loaded: [DevTestScenario] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let scenario = try? JSONDecoder().decode(DevTestScenario.self, from: data) else { continue }
            loaded.append(scenario)
        }
        if loaded.isEmpty {
            loaded = [defaultSmokeScenario()]
        }
        scenarios = loaded.sorted { $0.title < $1.title }
    }

    private func defaultSmokeScenario() -> DevTestScenario {
        DevTestScenario(
            id: "smoke_test",
            title: "Smoke Test",
            actions: [
                .createCampaign(name: "Dev Smoke Test"),
                .setWorldLore(title: "Test World", description: "A quick test world to validate scenes."),
                .runScene(description: "Intro", input: "I look around."),
                .performSkillCheck(skill: "Perception", difficulty: 12),
                .runScene(description: "Follow-up", input: "I head down the corridor.")
            ]
        )
    }
}

struct DevSmokeTestView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var runner = DevTestRunner()

    var body: some View {
        DevTestLogView(log: runner.log, isRunning: runner.isRunning)
            .onAppear {
                Task {
                    await runner.run(defaultScenario(), modelContext: modelContext)
                }
            }
    }

    private func defaultScenario() -> DevTestScenario {
        DevTestScenario(
            id: "smoke_test",
            title: "Smoke Test",
            actions: [
                .createCampaign(name: "Dev Smoke Test"),
                .setWorldLore(title: "Test World", description: "A quick test world to validate scenes."),
                .runScene(description: "Intro", input: "I look around."),
                .performSkillCheck(skill: "Perception", difficulty: 12),
                .runScene(description: "Follow-up", input: "I head down the corridor.")
            ]
        )
    }
}

private struct DevTestLogView: View {
    @Environment(\.dismiss) private var dismiss
    let log: [String]
    let isRunning: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if isRunning {
                        Text("Running...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(log.indices, id: \.self) { index in
                        Text(log[index])
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }
                .padding(Spacing.medium)
            }
            .navigationTitle("Dev Logs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
#endif
