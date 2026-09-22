import SwiftUI
import Combine
import SwiftData
import FoundationModels
import NarratorAgent
import RPGEngine
import WorldState
import TableEngine
import UIKit

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
    case startScene(expected: String)
    case playerInput(text: String)
    case playerInputKind(kind: String, text: String)
    case adaptivePlayerInput(goal: String, kind: String, roll: Int)
    case gmResponse(text: String)
    case recordSkillCheck(skill: String, dc: Int, roll: Int, outcome: String, consequence: String)
    case endScene(summary: String, pcsInControl: Bool, concluded: Bool)
    case runScene(description: String, input: String)
    case performSkillCheck(skill: String, difficulty: Int)
    case moveToLocation(label: String)
    case advanceLocation(reason: String)
    case prepareHiddenTransition(label: String)
    case importTables(filename: String)
    case loadCreativeKeywords
    case logReferenceData
    case logTableData
    case logCampaignSnapshot(label: String)
    case assertCampaignState(label: String, minScenes: Int, minInteractions: Int, minSkillChecks: Int, minWorldFacts: Int)

    private enum CodingKeys: String, CodingKey { case type, value1, value2, value3, value4, value5 }

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
        case "startScene":
            let expected = try container.decode(String.self, forKey: .value1)
            self = .startScene(expected: expected)
        case "playerInput":
            let text = try container.decode(String.self, forKey: .value1)
            self = .playerInput(text: text)
        case "playerInputKind":
            let kind = try container.decode(String.self, forKey: .value1)
            let text = try container.decode(String.self, forKey: .value2)
            self = .playerInputKind(kind: kind, text: text)
        case "adaptivePlayerInput":
            let goal = try container.decode(String.self, forKey: .value1)
            let kind = try container.decode(String.self, forKey: .value2)
            let roll = try container.decodeIfPresent(Int.self, forKey: .value3) ?? 12
            self = .adaptivePlayerInput(goal: goal, kind: kind, roll: roll)
        case "gmResponse":
            let text = try container.decode(String.self, forKey: .value1)
            self = .gmResponse(text: text)
        case "recordSkillCheck":
            let skill = try container.decode(String.self, forKey: .value1)
            let dc = try container.decode(Int.self, forKey: .value2)
            let roll = try container.decode(Int.self, forKey: .value3)
            let outcome = try container.decode(String.self, forKey: .value4)
            let consequence = try container.decodeIfPresent(String.self, forKey: .value5) ?? ""
            self = .recordSkillCheck(skill: skill, dc: dc, roll: roll, outcome: outcome, consequence: consequence)
        case "endScene":
            let summary = try container.decode(String.self, forKey: .value1)
            let pcsInControl = try container.decode(Bool.self, forKey: .value2)
            let concluded = try container.decode(Bool.self, forKey: .value3)
            self = .endScene(summary: summary, pcsInControl: pcsInControl, concluded: concluded)
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
        case "advanceLocation":
            let reason = try container.decode(String.self, forKey: .value1)
            self = .advanceLocation(reason: reason)
        case "prepareHiddenTransition":
            let label = try container.decode(String.self, forKey: .value1)
            self = .prepareHiddenTransition(label: label)
        case "importTables":
            let filename = try container.decode(String.self, forKey: .value1)
            self = .importTables(filename: filename)
        case "loadCreativeKeywords":
            self = .loadCreativeKeywords
        case "logReferenceData":
            self = .logReferenceData
        case "logTableData":
            self = .logTableData
        case "logCampaignSnapshot":
            let label = try container.decode(String.self, forKey: .value1)
            self = .logCampaignSnapshot(label: label)
        case "assertCampaignState":
            let label = try container.decode(String.self, forKey: .value1)
            let minScenes = try container.decode(Int.self, forKey: .value2)
            let minInteractions = try container.decode(Int.self, forKey: .value3)
            let minSkillChecks = try container.decode(Int.self, forKey: .value4)
            let minWorldFacts = try container.decode(Int.self, forKey: .value5)
            self = .assertCampaignState(
                label: label,
                minScenes: minScenes,
                minInteractions: minInteractions,
                minSkillChecks: minSkillChecks,
                minWorldFacts: minWorldFacts
            )
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
        case .startScene(let expected):
            try container.encode("startScene", forKey: .type)
            try container.encode(expected, forKey: .value1)
        case .playerInput(let text):
            try container.encode("playerInput", forKey: .type)
            try container.encode(text, forKey: .value1)
        case .playerInputKind(let kind, let text):
            try container.encode("playerInputKind", forKey: .type)
            try container.encode(kind, forKey: .value1)
            try container.encode(text, forKey: .value2)
        case .adaptivePlayerInput(let goal, let kind, let roll):
            try container.encode("adaptivePlayerInput", forKey: .type)
            try container.encode(goal, forKey: .value1)
            try container.encode(kind, forKey: .value2)
            try container.encode(roll, forKey: .value3)
        case .gmResponse(let text):
            try container.encode("gmResponse", forKey: .type)
            try container.encode(text, forKey: .value1)
        case .recordSkillCheck(let skill, let dc, let roll, let outcome, let consequence):
            try container.encode("recordSkillCheck", forKey: .type)
            try container.encode(skill, forKey: .value1)
            try container.encode(dc, forKey: .value2)
            try container.encode(roll, forKey: .value3)
            try container.encode(outcome, forKey: .value4)
            if !consequence.isEmpty {
                try container.encode(consequence, forKey: .value5)
            }
        case .endScene(let summary, let pcsInControl, let concluded):
            try container.encode("endScene", forKey: .type)
            try container.encode(summary, forKey: .value1)
            try container.encode(pcsInControl, forKey: .value2)
            try container.encode(concluded, forKey: .value3)
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
        case .advanceLocation(let reason):
            try container.encode("advanceLocation", forKey: .type)
            try container.encode(reason, forKey: .value1)
        case .prepareHiddenTransition(let label):
            try container.encode("prepareHiddenTransition", forKey: .type)
            try container.encode(label, forKey: .value1)
        case .importTables(let filename):
            try container.encode("importTables", forKey: .type)
            try container.encode(filename, forKey: .value1)
        case .loadCreativeKeywords:
            try container.encode("loadCreativeKeywords", forKey: .type)
        case .logReferenceData:
            try container.encode("logReferenceData", forKey: .type)
        case .logTableData:
            try container.encode("logTableData", forKey: .type)
        case .logCampaignSnapshot(let label):
            try container.encode("logCampaignSnapshot", forKey: .type)
            try container.encode(label, forKey: .value1)
        case .assertCampaignState(let label, let minScenes, let minInteractions, let minSkillChecks, let minWorldFacts):
            try container.encode("assertCampaignState", forKey: .type)
            try container.encode(label, forKey: .value1)
            try container.encode(minScenes, forKey: .value2)
            try container.encode(minInteractions, forKey: .value3)
            try container.encode(minSkillChecks, forKey: .value4)
            try container.encode(minWorldFacts, forKey: .value5)
        }
    }
}

private struct DevTestTurnPlan {
    let text: String
    let kind: PlayerActionKind
    let reason: String
}

private struct DevTestInputInterpreter {
    func lastGMAsksForRoll(_ lastGM: String?) -> Bool {
        asksForRoll((lastGM ?? "").lowercased())
    }

    func planTurn(
        goal: String,
        preferredKind: PlayerActionKind,
        fallbackRoll: Int,
        lastGM: String?,
        hasPendingCheck: Bool,
        hasPendingCanonization: Bool
    ) -> DevTestTurnPlan {
        let gm = (lastGM ?? "").lowercased()
        let clampedRoll = max(1, min(20, fallbackRoll))

        if hasPendingCheck || asksForRoll(gm) {
            return DevTestTurnPlan(
                text: "Natural \(clampedRoll).",
                kind: .auto,
                reason: "Responding to a pending roll prompt with a concrete d20 result."
            )
        }

        if hasPendingCanonization || asksForYesNo(gm) {
            return DevTestTurnPlan(
                text: "Yes.",
                kind: .auto,
                reason: "Confirming a yes/no prompt before continuing scripted intent."
            )
        }

        if asksForClarification(gm) {
            return DevTestTurnPlan(
                text: clarificationAnswer(for: goal, kind: preferredKind),
                kind: preferredKind == .auto ? .other : preferredKind,
                reason: "Answering a clarification prompt using the scenario goal."
            )
        }

        return DevTestTurnPlan(
            text: goal,
            kind: preferredKind,
            reason: "Sending the next scenario intent."
        )
    }

    private func asksForRoll(_ gm: String) -> Bool {
        guard !gm.isEmpty else { return false }
        let resolvedCues = [
            "result:", "success", "partial success", "failure",
            "total ", "=>", "no encounter", "travel continues"
        ]
        if resolvedCues.contains(where: { gm.contains($0) }) {
            let liveCues = [
                "what did you get", "i need the roll result",
                "please roll", "roll it", "give me your roll"
            ]
            return liveCues.contains { gm.contains($0) }
        }

        let cues = [
            "give me a", "give me your roll", "what did you get",
            "please roll", "roll it", "roll and tell", "d20 roll",
            "auto-roll is disabled", "i need the roll result", "awaiting roll",
            "pending check"
        ]
        return cues.contains { gm.contains($0) }
    }

    private func asksForYesNo(_ gm: String) -> Bool {
        gm.contains("(y/n)") ||
            gm.contains("yes or no") ||
            gm.contains("want to attempt") ||
            gm.contains("want to proceed") ||
            gm.contains("roll fate to confirm") ||
            gm.contains("canonize:")
    }

    private func asksForClarification(_ gm: String) -> Bool {
        gm.contains("not sure") ||
            gm.contains("rephrase") ||
            gm.contains("what exactly") ||
            gm.contains("how are you") ||
            gm.contains("which") ||
            gm.contains("clarify")
    }

    private func clarificationAnswer(for goal: String, kind: PlayerActionKind) -> String {
        switch kind {
        case .search:
            return "Carefully and quietly, using Investigation. \(goal)"
        case .movement, .travel:
            return "Carefully, with Hazel leading and watching for danger. \(goal)"
        case .dialogue:
            return "Hazel says it plainly and waits for their answer. \(goal)"
        case .skillCheck, .interact, .explore:
            return "Carefully, accepting the risk if it goes wrong. \(goal)"
        default:
            return goal
        }
    }
}

private struct DevSkillCheckDraft: Identifiable {
    let id = UUID()
    let playerAction: String
    let request: CheckRequest
    var roll: Int?
    var modifier: Int?
    var total: Int?
    var outcome: String?
    var consequence: String?
}

final class DevTestRunner: ObservableObject {
    @Published var log: [String] = []
    @Published var isRunning = false

    private let coordinator: SoloSceneCoordinator
    private var pendingScene: SceneRecord?
    private var devCampaignId: UUID?
    // Legacy helpers retained for tooling paths not used by the smoke test.
    private var engine = SoloCampaignEngine()
    private var locationEngine = SoloLocationEngine()
    private let model = SystemLanguageModel(useCase: .general)
    private let prompts = NarratorPrompts()
    private var pendingCheck: DevSkillCheckDraft?
    private var pendingInteractions: [SceneInteraction] = []
    private var pendingSkillChecks: [DevSkillCheckDraft] = []
    private var pendingFateQuestions: [FateQuestionRecord] = []
    private var pendingRollHighlights: [String] = []
    private var pendingPlayerText: String?
    private var agencyLogCursor = 0
    private let inputInterpreter = DevTestInputInterpreter()

    init(coordinator: SoloSceneCoordinator) {
        self.coordinator = coordinator
    }

    @MainActor
    func run(_ scenario: DevTestScenario, modelContext: ModelContext) async {
        log.removeAll()
        DevLogStore.save([])
        isRunning = true
        defer { isRunning = false }

        coordinator.resetConversation()
        agencyLogCursor = 0
        append("Running: \(scenario.title)")
        for action in scenario.actions {
            await execute(action, modelContext: modelContext)
        }
        appendFinalDiagnostics(modelContext)
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
            let campaign = ensureDevCampaign(modelContext)
            setPartySize(count, campaign: campaign)
            append("Party size set to \(count)")
        case .createCharacter(let name, let level, let abilities, let proficiencies):
            let campaign = ensureDevCampaign(modelContext)
            let character = createCharacter(
                name: name,
                level: level,
                abilities: abilities,
                proficiencies: proficiencies
            )
            campaign.playerCharacters.append(character)
            addPartyMember(name: name, level: level, campaign: campaign, isNpc: false, npcId: nil)
            append("Added character: \(name)")
        case .createSidekick(let name, let level, let abilities):
            let campaign = ensureDevCampaign(modelContext)
            let npc = NPCEntry(name: name, species: "Unknown", roleTag: "Sidekick", importance: NPCImportance.supporting.rawValue, origin: "dev")
            npc.abilityScores = buildNpcAbilityScores(abilities)
            npc.levelOrCR = level
            campaign.npcs.append(npc)
            addPartyMember(name: name, level: level, campaign: campaign, isNpc: true, npcId: npc.id)
            append("Added sidekick: \(name)")
        case .setWorldLore(let title, let description):
            let campaign = ensureDevCampaign(modelContext)
            let entry = WorldLoreEntry(title: title, summary: description, tags: [], origin: "dev")
            campaign.worldLore.append(entry)
            append("World lore: \(title)")
        case .startScene(let expected):
            let campaign = ensureDevCampaign(modelContext)
            coordinator.engine.ruleset = RulesetCatalog.ruleset(for: campaign.rulesetName)
            if campaign.activeLocationId == nil {
                _ = coordinator.locationEngine.generateDungeonStart(campaign: campaign)
            }
            pendingScene = coordinator.engine.resolveScene(campaign: campaign, expectedScene: expected)
            coordinator.resetConversation()
            append("Scene setup: \(expected)")
        case .playerInput(let text):
            await handlePlayerInput(text, actionKind: .auto, modelContext: modelContext)
        case .playerInputKind(let kind, let text):
            let actionKind = PlayerActionKind(rawValue: kind) ?? .auto
            await handlePlayerInput(text, actionKind: actionKind, modelContext: modelContext)
        case .adaptivePlayerInput(let goal, let kind, let roll):
            let actionKind = PlayerActionKind(rawValue: kind) ?? .auto
            if goal == "__ROLL_IF_PROMPTED__",
               coordinator.pendingCheckID == nil,
               !inputInterpreter.lastGMAsksForRoll(coordinator.interactionDrafts.last?.gmText) {
                append("TestDriver: no pending roll prompt; skipped roll \(roll).")
                return
            }
            let plan = inputInterpreter.planTurn(
                goal: goal,
                preferredKind: actionKind,
                fallbackRoll: roll,
                lastGM: coordinator.interactionDrafts.last?.gmText,
                hasPendingCheck: coordinator.pendingCheckID != nil,
                hasPendingCanonization: coordinator.pendingCanonizationId != nil
            )
            append("TestDriver: \(plan.reason)")
            await handlePlayerInput(plan.text, actionKind: plan.kind, modelContext: modelContext)
        case .gmResponse(let text):
            let playerText = coordinator.interactionDrafts.last?.playerText ?? ""
            coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: text, turnSignal: "gm_response"))
            append("GM (scripted): \(text)")
        case .recordSkillCheck(let skill, let dc, let roll, let outcome, let consequence):
            let request = CheckRequest(
                checkType: .skillCheck,
                skillName: skill,
                abilityOverride: nil,
                dc: dc,
                opponentSkill: nil,
                opponentDC: nil,
                advantageState: .normal,
                stakes: consequence.isEmpty ? "Failure changes the situation." : consequence,
                partialSuccessDC: max(5, dc - 5),
                partialSuccessOutcome: "You succeed but at a cost.",
                reason: "Dev test override"
            )
            let draft = SkillCheckDraft(playerAction: "Dev test \(skill) check", request: request, roll: roll, modifier: 0, total: roll, outcome: outcome, consequence: consequence, sourceTrapId: nil, sourceKind: nil)
            coordinator.checkDrafts.append(draft)
            if roll == 20 || roll == 1 {
                let existing = coordinator.rollHighlightsInput
                let highlight = "Natural \(roll)"
                coordinator.rollHighlightsInput = existing.isEmpty ? highlight : "\(existing), \(highlight)"
            }
            append("Roll: \(roll) (\(skill) DC \(dc)) → \(outcome)")
        case .endScene(let summary, let pcsInControl, let concluded):
            let campaign = ensureDevCampaign(modelContext)
            if let sceneRecord = pendingScene {
                let wrapUp = await draftSceneSummary(
                    campaign: campaign,
                    scene: sceneRecord,
                    summaryOverride: summary
                )
                let interactions = coordinator.interactionDrafts.map {
                    SceneInteraction(playerText: $0.playerText, gmText: $0.gmText, turnSignal: $0.turnSignal)
                }
                let bookkeeping = BookkeepingInput(
                    summary: wrapUp.summary,
                    newCharacters: [],
                    newThreads: [],
                    featuredCharacters: [],
                    featuredThreads: wrapUp.threadReferences,
                    removedCharacters: [],
                    removedThreads: [],
                    pcsInControl: pcsInControl,
                    concluded: concluded,
                    interactions: interactions,
                    skillChecks: buildSkillCheckRecords(from: coordinator.checkDrafts),
                    fateQuestions: coordinator.fateQuestionDrafts.map {
                        FateQuestionRecord(
                            question: $0.question,
                            likelihood: $0.likelihood.rawValue,
                            chaosFactor: $0.chaosFactor,
                            roll: $0.roll,
                            target: $0.target,
                            outcome: $0.outcome
                        )
                    },
                    places: [],
                    curiosities: [],
                    rollHighlights: wrapUp.rollHighlights + parseCommaList(coordinator.rollHighlightsInput),
                    locationId: campaign.activeLocationId,
                    generatedEntityIds: [],
                    canonizations: []
                )
                coordinator.engine.applySceneControlOutcome(campaign: campaign, pcsInControl: pcsInControl)
                _ = coordinator.engine.finalizeScene(campaign: campaign, scene: sceneRecord, bookkeeping: bookkeeping)
                append("GM Summary Draft: \(wrapUp.summary)")
                append("Scene summary saved.")
                pendingScene = nil
                coordinator.resetConversation()
            }
        case .runScene(let description, let input):
            let campaign = ensureDevCampaign(modelContext)
            let sceneRecord = coordinator.engine.resolveScene(campaign: campaign, expectedScene: description)
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
            coordinator.engine.applySceneControlOutcome(campaign: campaign, pcsInControl: true)
            _ = coordinator.engine.finalizeScene(campaign: campaign, scene: sceneRecord, bookkeeping: bookkeeping)
            append("Scene resolved: \(description)")
        case .performSkillCheck(let skill, let difficulty):
            let campaign = ensureDevCampaign(modelContext)
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
        case .moveToLocation(let label):
            let campaign = ensureDevCampaign(modelContext)
            let location = ensureLocation(named: label, campaign: campaign)
            campaign.activeLocationId = location.id
            if let node = location.nodes?.first {
                campaign.activeNodeId = node.id
            }
            append("Moved to location: \(label)")
        case .advanceLocation(let reason):
            let campaign = ensureDevCampaign(modelContext)
            if campaign.activeLocationId == nil {
                _ = coordinator.locationEngine.generateDungeonStart(campaign: campaign)
            }
            let node = coordinator.locationEngine.advanceToNextNode(campaign: campaign, reason: reason)
            append("Advance location: \(node?.summary ?? "Unknown")")
        case .prepareHiddenTransition(let label):
            let campaign = ensureDevCampaign(modelContext)
            guard let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }),
                  let node = location.nodes?.first(where: { $0.id == campaign.activeNodeId }) else {
                append("Hidden transition setup failed: no active node")
                break
            }
            let destination = LocationNode(type: "chamber", summary: "An unentered space beyond the transition", discovered: false, origin: "dev_fixture")
            let edge = LocationEdge(type: "trapdoor", label: label, fromNodeId: node.id, toNodeId: destination.id, origin: "dev_fixture")
            if location.nodes == nil { location.nodes = [] }
            if location.edges == nil { location.edges = [] }
            location.nodes?.append(destination)
            location.edges?.append(edge)
            append("Prepared hidden transition: \(label) discovered=\(edge.discovered == true) opened=\(edge.opened == true)")
        case .loadCreativeKeywords:
            let store = CreativeKeywordStore()
            let keywords = store.loadBundledKeywords()
            append("Creative keywords loaded: \(keywords.count)")
            let sample = store.drawKeywords(count: 2, from: keywords, seed: 42).map { $0.word }
            if !sample.isEmpty {
                append("Creative keywords sample: \(sample.joined(separator: ", "))")
            }
        case .logReferenceData:
            let store = SrdContentStore()
            if let dataURL = store.ensureUserDataDirectory() {
                append("User data folder: \(dataURL.path)")
            }
            if let index = store.loadIndex() {
                append("Reference data: source=\(index.source)")
                append("Counts: skills=\(index.skills.count) senses=\(index.senses.count) actions=\(index.actions.count) encounters=\(index.encounters.count)")
                append("Counts: objects=\(index.objects.count) loot=\(index.loot.count) baseItems=\(index.baseItems.count) tables=\(index.tables.count)")
            } else {
                append("Reference data unavailable")
            }
        case .logTableData:
            do {
                let pack = try ContentPackStore().loadDefaultPack()
                let userTables = pack.tables.filter { $0.scope == "user" }
                append("Tables loaded: \(pack.tables.count) (user \(userTables.count))")
            } catch {
                append("Tables load failed: \(error.localizedDescription)")
            }
        case .logCampaignSnapshot(let label):
            appendCampaignSnapshot(label: label, campaign: ensureDevCampaign(modelContext))
        case .assertCampaignState(let label, let minScenes, let minInteractions, let minSkillChecks, let minWorldFacts):
            appendCampaignAssertions(
                label: label,
                campaign: ensureDevCampaign(modelContext),
                minScenes: minScenes,
                minInteractions: minInteractions,
                minSkillChecks: minSkillChecks,
                minWorldFacts: minWorldFacts
            )
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
    private func appendFinalDiagnostics(_ modelContext: ModelContext) {
        appendCampaignSnapshot(label: "Final", campaign: ensureDevCampaign(modelContext))
        append("=== TEST LOG HANDOFF ===")
        append("Send this whole log to Codex when debugging. It includes separated intent/assumptions, declared stakes, proposal approvals/rejections, campaign events, procedure state, retries/fallbacks, structural assertions, snapshots, and stored world memory.")
    }

    @MainActor
    private func appendCampaignSnapshot(label: String, campaign: Campaign) {
        let interactionCount = campaign.scenes.reduce(0) { $0 + ($1.interactions?.count ?? 0) } + coordinator.interactionDrafts.count
        let skillCheckCount = campaign.scenes.reduce(0) { $0 + ($1.skillChecks?.count ?? 0) } + coordinator.checkDrafts.count
        let fateCount = campaign.scenes.reduce(0) { $0 + ($1.fateQuestions?.count ?? 0) } + coordinator.fateQuestionDrafts.count
        let locationCount = campaign.locations?.count ?? 0
        let featureCount = (campaign.locations ?? []).flatMap { $0.nodes ?? [] }.reduce(0) { $0 + ($1.features?.count ?? 0) }
        let worldFactCount = campaign.npcs.count + campaign.items.count + campaign.creatures.count + campaign.worldLore.count + locationCount + featureCount

        append("=== CAMPAIGN SNAPSHOT: \(label) ===")
        append("Scenes=\(campaign.scenes.count) PendingInteractions=\(coordinator.interactionDrafts.count) TotalInteractions=\(interactionCount)")
        append("Checks=\(skillCheckCount) FateQuestions=\(fateCount) CanonPrompts=\(coordinator.canonizationDrafts.count)")
        append("WorldFacts=\(worldFactCount) NPCs=\(campaign.npcs.count) Objects=\(campaign.items.count) Creatures=\(campaign.creatures.count) Lore=\(campaign.worldLore.count) Locations=\(locationCount) Features=\(featureCount)")
        if let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }) {
            append("ActiveLocation=\(location.name) type=\(location.type) origin=\(location.origin)")
        }
        if !campaign.npcs.isEmpty {
            append("NPCNames=\(campaign.npcs.prefix(6).map(\.name).joined(separator: ", "))")
        }
        if !campaign.items.isEmpty {
            append("ObjectNames=\(campaign.items.prefix(6).map(\.name).joined(separator: ", "))")
        }
        if !campaign.creatures.isEmpty {
            append("CreatureNames=\(campaign.creatures.prefix(6).map(\.name).joined(separator: ", "))")
        }
        if let authority = CampaignAuthorityStateStore().load(from: campaign) {
            append("AuthorityState weather=\(authority.weather ?? "none") weatherDecision=\(authority.weatherDecision?.rawValue ?? "none") hiddenThreats=\(authority.hiddenThreats.count)")
        } else {
            append("AuthorityState none")
        }
        if let procedure = CampaignProcedureStateStore().load(from: campaign) {
            if let travel = procedure.lastTravel {
                append("Procedure Travel kind=\(travel.resolutionKind.rawValue) progress=\(travel.progress) time=\(travel.timeHours) exposure=\(travel.exposure) delay=\(travel.delay) risk=\(travel.encounterRisk)")
            }
            if let rest = procedure.lastRest {
                append("Procedure Rest recovery=\(rest.recovery.rawValue) time=\(rest.timeHours) supplies=\(rest.suppliesConsumed) exposure=\(rest.exposure) watchRisk=\(rest.watchRisk) interrupted=\(rest.interrupted)")
            } else if let plan = procedure.lastRestPlan {
                append("Procedure Rest pending missing=\(RestProcedureEngine().missingDetails(plan).map(\.rawValue).joined(separator: ","))")
            }
            if let search = procedure.lastSearch {
                append("Procedure Search finding=\(search.finding.rawValue) revealed=\(search.revealedTarget?.name ?? "none")")
            }
            if let creative = procedure.lastCreative {
                append("Procedure Creative roll=\(creative.roll) keywords=\(creative.keywords.joined(separator: ",")) effect=\(creative.effectKind.rawValue) valence=\(creative.valence.rawValue)")
            }
        } else {
            append("ProcedureState none")
        }
        let transitions = (campaign.locations ?? []).flatMap { $0.edges ?? [] }
        if !transitions.isEmpty {
            append("Transitions=\(transitions.prefix(8).map { "\($0.label ?? $0.type):discovered=\($0.discovered == true):opened=\($0.opened == true)" }.joined(separator: ", "))")
        }
        let campaignEvents = (campaign.eventLog ?? []).filter { $0.eventType != nil }
        append("CampaignEvents=\(campaignEvents.count) Types=\(campaignEvents.compactMap(\.eventType).suffix(10).joined(separator: ","))")
        appendAgencyLogsIfNeeded()
    }

    @MainActor
    private func appendCampaignAssertions(
        label: String,
        campaign: Campaign,
        minScenes: Int,
        minInteractions: Int,
        minSkillChecks: Int,
        minWorldFacts: Int
    ) {
        let interactionCount = campaign.scenes.reduce(0) { $0 + ($1.interactions?.count ?? 0) } + coordinator.interactionDrafts.count
        let skillCheckCount = campaign.scenes.reduce(0) { $0 + ($1.skillChecks?.count ?? 0) } + coordinator.checkDrafts.count
        let locationCount = campaign.locations?.count ?? 0
        let featureCount = (campaign.locations ?? []).flatMap { $0.nodes ?? [] }.reduce(0) { $0 + ($1.features?.count ?? 0) }
        let worldFactCount = campaign.npcs.count + campaign.items.count + campaign.creatures.count + campaign.worldLore.count + locationCount + featureCount

        var failures: [String] = []
        if campaign.scenes.count < minScenes {
            failures.append("scenes \(campaign.scenes.count) < \(minScenes)")
        }
        if interactionCount < minInteractions {
            failures.append("interactions \(interactionCount) < \(minInteractions)")
        }
        if skillCheckCount < minSkillChecks {
            failures.append("skillChecks \(skillCheckCount) < \(minSkillChecks)")
        }
        if worldFactCount < minWorldFacts {
            failures.append("worldFacts \(worldFactCount) < \(minWorldFacts)")
        }
        let fullLog = log.joined(separator: "\n").lowercased()
        let agencyPhrases = [
            "the party decided",
            "the party decides",
            "the player decided",
            "the player decides",
            "prompting them to",
            "what you don't see",
            "what you don’t see"
        ]
        if let phrase = agencyPhrases.first(where: { fullLog.contains($0) }) {
            failures.append("agency phrase found: \(phrase)")
        }
        let forbiddenNpcNames = ["finn", "the unseen adversary"]
        let storedNpcNames = Set(campaign.npcs.map { $0.name.lowercased() })
        if let npc = forbiddenNpcNames.first(where: { storedNpcNames.contains($0) }) {
            failures.append("forbidden auto-created NPC stored: \(npc)")
        }
        if let invalidD20 = firstInvalidD20EncounterLog() {
            failures.append("invalid d20 encounter log: \(invalidD20)")
        }
        if fullLog.contains("engine [structural_assertion_failure]") {
            failures.append("structural assertion failure logged")
        }
        if label.lowercased().contains("thorough"),
           let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }) {
            let lowerLocation = location.name.lowercased()
            if lowerLocation.contains("flicker") || lowerLocation == "dungeon entrance" {
                failures.append("unexpected active location after thorough test: \(location.name)")
            }
        }
        if label.lowercased().contains("smoke") || label.lowercased().contains("thorough") {
            if CampaignAuthorityStateStore().load(from: campaign)?.weather == nil {
                failures.append("weather authority state missing")
            }
            let procedure = CampaignProcedureStateStore().load(from: campaign)
            if procedure?.lastTravel == nil { failures.append("travel procedure resolution missing") }
            if procedure?.lastSearch == nil { failures.append("search procedure resolution missing") }
        }
        if label.lowercased().contains("thorough") {
            let procedure = CampaignProcedureStateStore().load(from: campaign)
            if procedure?.lastRest == nil { failures.append("rest procedure resolution missing") }
            if procedure?.lastCreative == nil { failures.append("creative procedure resolution missing") }
            let forbiddenGenericNames = ["unknown character", "the unseen adversary"]
            if let name = campaign.npcs.map({ $0.name.lowercased() }).first(where: forbiddenGenericNames.contains) {
                failures.append("generic hidden NPC stored: \(name)")
            }
        }

        if failures.isEmpty {
            append("ASSERT PASS [\(label)] scenes=\(campaign.scenes.count) interactions=\(interactionCount) checks=\(skillCheckCount) worldFacts=\(worldFactCount)")
        } else {
            append("ASSERT FAIL [\(label)] \(failures.joined(separator: "; "))")
        }
    }

    private func firstInvalidD20EncounterLog() -> String? {
        for line in log where line.contains("Encounter check d20") {
            guard let markerRange = line.range(of: "Encounter check d20"),
                  let colon = line[markerRange.upperBound...].firstIndex(of: ":") else { continue }
            let afterColon = line[line.index(after: colon)...]
            let rollText = afterColon
                .split(separator: " ")
                .first?
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard let rollText, let roll = Int(rollText), !(1...20).contains(roll) else { continue }
            return line
        }
        return nil
    }

    @MainActor
    private func handlePlayerInput(_ text: String, actionKind: PlayerActionKind, modelContext: ModelContext) async {
        if actionKind == .auto {
            append("Player: \(text)")
        } else {
            append("Player [\(actionKind.label)]: \(text)")
        }
        let campaign = ensureDevCampaign(modelContext)
        guard let sceneRecord = pendingScene else {
            append("GM: No active scene. Start a scene first.")
            return
        }
        let gmText = await coordinator.requestGMResponse(
            campaign: campaign,
            scene: sceneRecord,
            playerText: text,
            actionKind: actionKind,
            autoRollEnabled: UserDefaults.standard.bool(forKey: "soloAutoRollEnabled"),
            gmRunsCompanionsEnabled: UserDefaults.standard.bool(forKey: "soloGMRunsCompanions"),
            modelContext: modelContext
        )
        if let gmText {
            append("GM: \(gmText)")
            appendAgencyLogsIfNeeded()
        } else if let error = coordinator.gmResponseError {
            append("GM: \(error)")
            appendAgencyLogsIfNeeded()
        } else {
            append("GM: (no response)")
            appendAgencyLogsIfNeeded()
        }
    }

    @MainActor
    private func resolvePendingCheck(
        _ draft: DevSkillCheckDraft,
        playerText: String,
        context: NarrationContextPacket
    ) async {
        if let parsed = parseRollFallback(from: playerText) {
            if parsed.declines {
                let gmText = "Understood. We’ll skip that check. What do you do instead?"
                appendGMResponse(gmText, playerText: playerText)
                pendingCheck = nil
                return
            }
            if parsed.autoRoll {
                let roll = Int.random(in: 1...20)
                await finalizeCheck(draft, roll: roll, modifier: 0, context: context, playerText: playerText)
                return
            }
            if let roll = parsed.roll {
                await finalizeCheck(draft, roll: roll, modifier: parsed.modifier ?? 0, context: context, playerText: playerText)
                return
            }
        }
        do {
            let session = makeSession()
            let rollDraft = try await session.respond(
                to: Prompt(makeRollParsingPrompt(playerText: playerText, check: draft)),
                generating: CheckRollDraft.self
            )

            if rollDraft.content.declines {
                let gmText = "Understood. We’ll skip that check. What do you do instead?"
                appendGMResponse(gmText, playerText: playerText)
                pendingCheck = nil
                return
            }

            if rollDraft.content.autoRoll {
                let roll = Int.random(in: 1...20)
                await finalizeCheck(draft, roll: roll, modifier: 0, context: context, playerText: playerText)
                return
            }

            guard let roll = rollDraft.content.roll else {
                let gmText = "I need your d20 roll to resolve that. What did you get?"
                appendGMResponse(gmText, playerText: playerText)
                return
            }

            let modifier = rollDraft.content.modifier ?? 0
            await finalizeCheck(draft, roll: roll, modifier: modifier, context: context, playerText: playerText)
        } catch {
            append("GM: Check resolution failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func finalizeCheck(
        _ draft: DevSkillCheckDraft,
        roll: Int,
        modifier: Int,
        context: NarrationContextPacket,
        playerText: String
    ) async {
        var updated = draft
        updated.roll = roll
        updated.modifier = modifier
        let result = engine.evaluateCheck(request: draft.request, roll: roll, modifier: modifier)
        updated.total = result.total
        updated.outcome = result.outcome
        updated.consequence = await generateCheckConsequence(
            context: context,
            check: updated,
            result: result
        )
        pendingSkillChecks.append(updated)
        if roll == 1 || roll == 20 {
            pendingRollHighlights.append("Natural \(roll)")
        }
        pendingCheck = nil

        let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
        let gmText = "Roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(updated.consequence ?? "")"
        appendGMResponse(gmText, playerText: playerText)
    }

    @MainActor
    private func handleMovement(
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign,
        modelContext: ModelContext
    ) async -> Bool {
        do {
            let session = makeSession()
            let prompt = prompts.makeMovementIntentPrompt(playerText: playerText, context: context)
            let response = try await session.respond(to: Prompt(prompt), generating: MovementIntentDraft.self)
            let movement = response.content
            if !movement.isMovement {
                return containsMovementKeyword(playerText) ? advanceFallbackMovement(campaign: campaign, reason: playerText, modelContext: modelContext) : false
            }

            if let exitLabel = movement.exitLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
               !exitLabel.isEmpty {
                if let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }),
                   let nodeId = campaign.activeNodeId,
                   let node = location.nodes?.first(where: { $0.id == nodeId }),
                   let edge = edgeForExitLabel(exitLabel, location: location, node: node) {
                    _ = locationEngine.advanceAlongEdge(campaign: campaign, edge: edge, reason: movement.summary)
                } else {
                    _ = locationEngine.advanceToNextNode(campaign: campaign, reason: movement.summary)
                }
            } else {
                _ = locationEngine.advanceToNextNode(campaign: campaign, reason: movement.summary)
            }
            try? modelContext.save()
            append("Movement resolved: \(movement.summary)")
            return true
        } catch {
            append("GM: Movement check failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    private func advanceFallbackMovement(
        campaign: Campaign,
        reason: String,
        modelContext: ModelContext
    ) -> Bool {
        _ = locationEngine.advanceToNextNode(campaign: campaign, reason: reason)
        try? modelContext.save()
        append("Movement resolved (fallback): \(reason)")
        return true
    }

    @MainActor
    private func proposeCheck(
        playerText: String,
        context: NarrationContextPacket
    ) async -> Bool {
        do {
            let session = makeSession()
            let checkDraft = try await session.respond(
                to: Prompt(makeCheckProposalPrompt(playerText: playerText, context: context)),
                generating: CheckRequestDraft.self
            )

            if checkDraft.content.requiresRoll == false {
                if shouldForceSkillCheck(for: playerText), let forcedRequest = forcedCheckRequest(for: playerText) {
                    let draft = DevSkillCheckDraft(playerAction: playerText, request: forcedRequest)
                    pendingCheck = draft
                    let gmText = gmLineForCheck(forcedRequest)
                    appendGMResponse(gmText, playerText: playerText)
                    return true
                }
                return false
            }

            guard let request = engine.finalizeCheckRequest(from: checkDraft.content) else {
                appendGMResponse("I couldn't settle on a clear check. Want to rephrase?", playerText: playerText)
                return true
            }

            if shouldForceSkillCheck(for: playerText),
               shouldOverrideTrapSkill(proposedSkill: request.skillName) {
                if let forcedRequest = forcedCheckRequest(for: playerText) {
                    let draft = DevSkillCheckDraft(playerAction: playerText, request: forcedRequest)
                    pendingCheck = draft
                    let gmText = gmLineForCheck(forcedRequest)
                    appendGMResponse(gmText, playerText: playerText)
                    return true
                }
            }

            let draft = DevSkillCheckDraft(playerAction: playerText, request: request)
            pendingCheck = draft
            let gmText = gmLineForCheck(request)
            appendGMResponse(gmText, playerText: playerText)
            return true
        } catch {
            append("GM: Check proposal failed: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    private func generateGMResponse(
        context: NarrationContextPacket,
        playerText: String,
        isMeta: Bool
    ) async -> String {
        do {
            let session = makeSession()
            var prompt = """
            You are the game master in a solo RPG. Respond conversationally.
            Do not roll dice or change state. Ask clarifying questions when needed.
            Never narrate player actions as if they already happened.
            End with a short prompt like \"What do you do?\"
            """

            if isMeta {
                prompt += "\nThe player is speaking out of character to the GM. Keep it short and practical."
            }

            prompt += "\nContext Card:\n\(buildContextCard(context: context))"
            prompt += "\nPlayer: \(playerText)"
            prompt += "\nReturn a NarrationPlanDraft."

            let response = try await session.respond(to: Prompt(prompt), generating: NarrationPlanDraft.self)
            let content = renderNarrationPlan(response.content)
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "I hit a snag generating a response. Could you rephrase?"
        }
    }

    @MainActor
    private func draftSceneSummary(
        campaign: Campaign,
        scene: SceneRecord,
        summaryOverride: String
    ) async -> SceneSummaryDraft {
        let session = makeSession()
        let snapshot = SceneCanonSnapshot(campaign: campaign)

        let context = coordinator.engine.buildNarrationContext(campaign: campaign, scene: scene)
        var prompt = """
        Draft a concise, read-only scene summary.
        Include only events that occurred in the player-visible interactions or resolved checks below.
        Do not introduce, rename, remove, or imply any character, thread, place, object, creature, quest, or lore fact.
        List every named canonical entity used by the summary in entityReferences.
        List only already-established campaign threads in threadReferences.
        Emphasize why rolls happened and their outcomes.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Scene Type: \(context.sceneType.rawValue)
        """

        if !coordinator.interactionDrafts.isEmpty {
            prompt += "\nInteractions:"
            for interaction in coordinator.interactionDrafts {
                prompt += "\n- Player: \(interaction.playerText)"
                if !interaction.gmText.isEmpty {
                    prompt += " / GM: \(interaction.gmText)"
                }
            }
        }

        if !coordinator.checkDrafts.isEmpty {
            prompt += "\nSkill Checks:"
            for check in coordinator.checkDrafts {
                let outcome = check.outcome ?? "unknown"
                prompt += "\n- \(check.playerAction) (\(check.request.skillName)) outcome: \(outcome)"
            }
        }

        if !coordinator.fateQuestionDrafts.isEmpty {
            prompt += "\nFate Questions:"
            for fate in coordinator.fateQuestionDrafts {
                prompt += "\n- \(fate.question) => \(fate.outcome.uppercased())"
            }
        }

        prompt += "\nAllowed canonical names: \(snapshot.allowedEntityNames.sorted().joined(separator: ", "))"
        prompt += "\nAllowed thread names: \(snapshot.allowedThreadNames.sorted().joined(separator: ", "))"
        prompt += "\nReturn a SceneSummaryDraft."

        do {
            let response = try await session.respond(to: Prompt(prompt), generating: SceneSummaryDraft.self)
            let validation = SceneSummaryValidator().validate(response.content, against: snapshot)
            guard validation.isValid else {
                append("Engine [summary_hallucination]: rejected \(validation.unknownReferences.joined(separator: ", "))")
                return deterministicSceneSummary(summaryOverride: summaryOverride)
            }
            return response.content
        } catch {
            return deterministicSceneSummary(summaryOverride: summaryOverride)
        }
    }

    @MainActor
    private func deterministicSceneSummary(summaryOverride: String) -> SceneSummaryDraft {
        let resolvedChecks = coordinator.checkDrafts.compactMap { check -> String? in
            guard let outcome = check.outcome else { return nil }
            return "\(check.request.skillName): \(outcome.replacingOccurrences(of: "_", with: " "))"
        }
        let summary: String
        if !summaryOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summary = summaryOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if resolvedChecks.isEmpty {
            summary = "The scene recorded \(coordinator.interactionDrafts.count) player interaction(s)."
        } else {
            summary = "Resolved checks: \(resolvedChecks.joined(separator: "; "))."
        }
        return SceneSummaryDraft(
            summary: summary,
            entityReferences: [],
            threadReferences: [],
            rollHighlights: resolvedChecks
        )
    }

    private func buildSkillCheckRecords(from drafts: [SkillCheckDraft]) -> [SkillCheckRecord] {
        drafts.map { draft in
            let record = SkillCheckRecord(
                playerAction: draft.playerAction,
                checkType: draft.request.checkType.rawValue,
                skill: draft.request.skillName,
                abilityOverride: draft.request.abilityOverride,
                dc: draft.request.dc,
                opponentSkill: draft.request.opponentSkill,
                opponentDC: draft.request.opponentDC,
                advantageState: draft.request.advantageState.rawValue,
                stakes: draft.request.stakes,
                partialSuccessDC: draft.request.partialSuccessDC,
                partialSuccessOutcome: draft.request.partialSuccessOutcome,
                reason: draft.request.reason,
                declaredStakesJSON: draft.request.declaredStakes.flatMap { stakes in
                    guard let data = try? JSONEncoder().encode(stakes) else { return nil }
                    return String(data: data, encoding: .utf8)
                }
            )
            record.rollResult = draft.roll
            record.modifier = draft.modifier
            record.total = draft.total
            record.outcome = draft.outcome
            record.consequence = draft.consequence
            return record
        }
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(model: model)
    }

    private func renderNarrationPlan(_ plan: NarrationPlanDraft) -> String {
        var parts: [String] = []
        if !plan.segments.isEmpty {
            for segment in plan.segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if segment.channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "dialogue" {
                    if text.hasPrefix("\"") || text.hasPrefix("“") {
                        parts.append(text)
                    } else {
                        parts.append("\"\(text)\"")
                    }
                } else {
                    parts.append(text)
                }
            }
            return parts.joined(separator: "\n")
        }

        let narration = plan.narrationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !narration.isEmpty {
            parts.append(narration)
        }

        let questions = plan.questionsToPlayer
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !questions.isEmpty {
            parts.append(questions.joined(separator: " "))
        }

        let options = plan.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !options.isEmpty {
            parts.append("Options: " + options.joined(separator: " • "))
        }

        if let ruleSummary = plan.ruleSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ruleSummary.isEmpty {
            parts.append(ruleSummary)
        }

        return parts.joined(separator: "\n")
    }

    @MainActor
    private func appendGMResponse(_ text: String, playerText: String) {
        let interaction = SceneInteraction(playerText: playerText, gmText: text, turnSignal: "gm_response")
        pendingInteractions.append(interaction)
        pendingPlayerText = nil
        append("GM: \(text)")
        appendAgencyLogsIfNeeded()
    }

    @MainActor
    private func appendAgencyLogsIfNeeded() {
        guard agencyLogCursor < coordinator.agencyLogs.count else { return }
        let newLogs = coordinator.agencyLogs[agencyLogCursor...]
        for entry in newLogs {
            append("Engine [\(entry.stage)]: \(entry.message)")
        }
        agencyLogCursor = coordinator.agencyLogs.count
    }

    private func makeCheckProposalPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Propose a ruleset-based skill check for a solo RPG.
        - Roll only if the action is uncertain and consequential.
        - If failure would change the situation in a meaningful way, a roll is required.
        - No roll for trivial or guaranteed actions; set requiresRoll to false and give autoOutcome.
        - Searching for traps or hidden dangers always requires a roll and should use Perception or Investigation.
        - Use DC bands 5, 10, 15, 20, 25, 30.
        - Advantage for strong leverage; disadvantage for harsh conditions.
        - Provide a concrete, in-fiction reason for the chosen DC.
        Return a CheckRequestDraft.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Chaos Factor: \(context.chaosFactor)
        Player action: \(playerText)
        Ruleset: \(engine.ruleset.displayName)
        Available skills: \(engine.ruleset.skillNames.joined(separator: ", "))
        """
    }

    private func makeRollParsingPrompt(playerText: String, check: DevSkillCheckDraft) -> String {
        """
        The player is responding to a pending skill check.
        Extract the d20 roll and modifier if present. If they decline, set declines to true.
        If they explicitly ask for an auto-roll ("auto"), set autoRoll to true.
        Otherwise set autoRoll to false.
        Recognize "natural 1", "natural 20", "nat 1", or "nat 20" as rolls.
        If no roll is provided, leave roll as null.

        Check: \(check.request.skillName) DC \(check.request.dc ?? check.request.opponentDC ?? 10)
        Player: \(playerText)

        Return a CheckRollDraft.
        """
    }

    private func gmLineForCheck(_ request: CheckRequest) -> String {
        let skillName = request.skillName
        let ability = request.abilityOverride ?? engine.ruleset.defaultAbility(for: skillName) ?? "Ability"
        let abilityLine = "\(ability) (\(skillName))"
        let advantageLine: String
        switch request.advantageState {
        case .advantage:
            advantageLine = "with advantage"
        case .disadvantage:
            advantageLine = "with disadvantage"
        case .normal:
            advantageLine = "normally"
        }

        var line = "Okay - give me a \(abilityLine) check, \(advantageLine)."
        if let dc = request.dc {
            line += " DC \(dc)."
        } else if let opponentDC = request.opponentDC {
            let opponent = request.opponentSkill ?? "opponent"
            line += " Opposed by \(opponent) (DC \(opponentDC))."
        }
        if !request.reason.isEmpty {
            line += " Reason: \(request.reason)."
        }
        line += " If you fail, \(request.stakes)"
        if let partialDC = request.partialSuccessDC,
           let partialText = request.partialSuccessOutcome,
           !partialText.isEmpty {
            line += " On a partial (DC \(partialDC)), \(partialText)"
        }
        if UserDefaults.standard.bool(forKey: "soloAutoRollEnabled") {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Tell me the d20 result and modifier, or say \"use my bonus\" if you want me to add it."
        }
        return line
    }

    private func normalizedSkillName(_ skill: String) -> String {
        if let match = engine.ruleset.skillNames.first(where: { $0.caseInsensitiveCompare(skill) == .orderedSame }) {
            return match
        }
        if let fallback = engine.ruleset.skillNames.first(where: { $0.caseInsensitiveCompare("Investigation") == .orderedSame }) {
            return fallback
        }
        return engine.ruleset.skillNames.first ?? skill
    }

    private func shouldForceSkillCheck(for playerText: String) -> Bool {
        let lower = playerText.lowercased()
        let keywords = [
            "check for traps", "search for traps", "look for traps", "scan for traps", "inspect for traps",
            "search", "investigate", "examine", "inspect", "sneak", "hide", "pick",
            "climb", "jump", "force", "lift", "break", "convince", "persuade", "intimidate",
            "listen", "peek", "track"
        ]
        return keywords.contains(where: { lower.contains($0) })
    }

    private func shouldOverrideTrapSkill(proposedSkill: String) -> Bool {
        let lower = proposedSkill.lowercased()
        return !(lower.contains("perception") || lower.contains("investigation"))
    }

    private func isAcknowledgementMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        let acknowledgements = [
            "glad", "thanks", "thank you", "nice", "great", "cool", "ok", "okay",
            "awesome", "sweet", "oof", "dang", "yikes", "phew", "ugh", "yep", "yeah"
        ]
        guard acknowledgements.contains(where: { lower.contains($0) }) else { return false }
        let actionVerbs = ["try", "attempt", "go", "move", "open", "search", "look", "ask", "talk", "persuade", "investigate"]
        return !actionVerbs.contains(where: { lower.contains($0) })
    }

    private struct RollParseFallback {
        let roll: Int?
        let modifier: Int?
        let autoRoll: Bool
        let declines: Bool
    }

    private func parseRollFallback(from text: String) -> RollParseFallback? {
        let lower = text.lowercased()
        if lower.contains("auto") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: true, declines: false)
        }
        if lower.contains("skip") || lower.contains("decline") || lower.contains("pass") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: false, declines: true)
        }

        let rollPattern = "(?i)(natural|nat)\\s*(\\d+)"
        if let match = lower.range(of: rollPattern, options: .regularExpression) {
            let slice = lower[match]
            let digits = slice.split(whereSeparator: { !$0.isNumber })
            if let value = digits.compactMap({ Int($0) }).first, (1...20).contains(value) {
                return RollParseFallback(roll: value, modifier: nil, autoRoll: false, declines: false)
            }
        }

        let numbers = lower.split { !$0.isNumber }.compactMap { Int($0) }.filter { (1...20).contains($0) }
        if numbers.count == 1, let roll = numbers.first {
            return RollParseFallback(roll: roll, modifier: nil, autoRoll: false, declines: false)
        }
        return nil
    }

    private func forcedCheckRequest(for playerText: String) -> CheckRequest? {
        let lower = playerText.lowercased()
        let skill: String
        if lower.contains("trap") || lower.contains("investigate") || lower.contains("search") || lower.contains("inspect") {
            skill = normalizedSkillName("Investigation")
        } else if lower.contains("sneak") || lower.contains("hide") || lower.contains("stealth") {
            skill = normalizedSkillName("Stealth")
        } else if lower.contains("persuade") || lower.contains("convince") {
            skill = normalizedSkillName("Persuasion")
        } else if lower.contains("intimidate") {
            skill = normalizedSkillName("Intimidation")
        } else if lower.contains("climb") || lower.contains("jump") || lower.contains("force") || lower.contains("break") || lower.contains("lift") {
            skill = normalizedSkillName("Athletics")
        } else if lower.contains("balance") || lower.contains("acrobat") {
            skill = normalizedSkillName("Acrobatics")
        } else if lower.contains("listen") || lower.contains("peek") || lower.contains("spot") {
            skill = normalizedSkillName("Perception")
        } else {
            skill = normalizedSkillName("Investigation")
        }

        return CheckRequest(
            checkType: .skillCheck,
            skillName: skill,
            abilityOverride: nil,
            dc: 15,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "Failure complicates the attempt or leaves you exposed to consequences.",
            partialSuccessDC: 10,
            partialSuccessOutcome: "You make progress but introduce a complication.",
            reason: "The action is uncertain and failure would matter."
        )
    }

    private func generateCheckConsequence(
        context: NarrationContextPacket,
        check: DevSkillCheckDraft,
        result: CheckResult
    ) async -> String {
        let session = makeSession()
        var prompt = """
        Provide a brief consequence (1-2 sentences) based on the check outcome.
        Keep the story moving and stay grounded.
        If the d20 roll is a natural 20, make it an extraordinary success.
        If the d20 roll is a natural 1, make it a significant failure.

        Scene #\(context.sceneNumber)
        Player action: \(check.playerAction)
        Skill: \(check.request.skillName)
        Reason: \(check.request.reason)
        Outcome: \(result.outcome)
        Stakes on failure: \(check.request.stakes)
        """
        if let roll = check.roll {
            prompt += "\nD20 roll: \(roll)"
        }
        let response = try? await session.respond(to: Prompt(prompt))
        return response?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? result.consequence
    }

    private func buildContextCard(context: NarrationContextPacket) -> String {
        var lines: [String] = []
        lines.append("Scene: \(context.expectedScene)")
        if let location = context.currentLocation {
            lines.append("Location: \(location)")
        }
        if let node = context.currentNode {
            lines.append("Node: \(node)")
        }
        if !context.activeCharacters.isEmpty {
            let names = context.activeCharacters.prefix(4).map { $0.name }
            lines.append("Active Entities: \(names.joined(separator: ", "))")
        }
        if !context.currentExits.isEmpty {
            lines.append("Exits: \(context.currentExits.joined(separator: " · "))")
        }
        return lines.joined(separator: "\n")
    }

    private func isMetaMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("gm") || lower.contains("dm") || lower.contains("rules")
    }

    private func containsMovementKeyword(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = ["move", "go", "head", "walk", "enter", "leave", "exit", "door", "doorway", "adjoining", "hall", "corridor"]
        return keywords.contains(where: { lower.contains($0) })
    }

    private func edgeForExitLabel(
        _ label: String,
        location: LocationEntity,
        node: LocationNode
    ) -> LocationEdge? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let exits = (location.edges ?? []).filter { $0.fromNodeId == node.id }
        return exits.first(where: { edge in
            let edgeLabel = (edge.label?.isEmpty == false) ? (edge.label ?? edge.type) : edge.type
            return edgeLabel.lowercased().contains(trimmed) || edge.type.lowercased().contains(trimmed)
        })
    }

    @MainActor
    private func createCampaign(named name: String, modelContext: ModelContext) -> Campaign {
        let campaign = ensureDevCampaign(modelContext)
        resetCampaign(campaign, title: name.isEmpty ? "Dev Test Campaign" : name)
        coordinator.engine.ruleset = RulesetCatalog.srd
        return campaign
    }

    @MainActor
    private func ensureDevCampaign(_ modelContext: ModelContext) -> Campaign {
        let campaigns = fetchCampaigns(modelContext)
        if let devId = devCampaignId, let existing = campaigns.first(where: { $0.id == devId }) {
            return existing
        }
        if let existing = campaigns.first(where: { $0.title == "Dev Test Campaign" }) {
            devCampaignId = existing.id
            return existing
        }
        let campaign = Campaign(title: "Dev Test Campaign")
        campaign.isActive = false
        campaign.rulesetName = RulesetCatalog.srd.displayName
        modelContext.insert(campaign)
        devCampaignId = campaign.id
        return campaign
    }

    @MainActor
    private func resetCampaign(_ campaign: Campaign, title: String) {
        campaign.title = title
        campaign.isActive = false
        campaign.chaosFactor = 5
        campaign.sceneNumber = 1
        campaign.scenes = []
        campaign.characters = []
        campaign.threads = []
        campaign.npcs = []
        campaign.items = []
        campaign.creatures = []
        campaign.worldLore = []
        campaign.playerCharacters = []
        campaign.party = nil
        campaign.activeSceneId = nil
        campaign.activeLocationId = nil
        campaign.activeNodeId = nil
        campaign.lastNodeId = nil
        campaign.locations = nil
        campaign.eventLog = nil
        campaign.tableRolls = nil
        campaign.rngSeed = nil
        campaign.rngSequence = nil
        campaign.worldVibe = ""
        campaign.rulesetName = RulesetCatalog.srd.displayName
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
        let node = LocationNode(type: "area", summary: name, discovered: true, origin: "dev")
        location.nodes = [node]
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
        updateField(character, key: "hp_max", intValue: 15)
        updateField(character, key: "hp_current", intValue: 15)
        updateField(character, key: "ac", intValue: 13)
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
        DevLogStore.save(log)
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
    let coordinator: SoloSceneCoordinator
    @Environment(\.modelContext) private var modelContext
    @StateObject private var runner: DevTestRunner
    @State private var scenarios: [DevTestScenario] = []
    @State private var selectedScenario: DevTestScenario?
    @State private var showLog = false

    @MainActor init(coordinator: SoloSceneCoordinator) {
        self.coordinator = coordinator
        _runner = StateObject(wrappedValue: DevTestRunner(coordinator: coordinator))
    }

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
                        showLog = true
                        Task {
                            await runner.run(scenario, modelContext: modelContext)
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
            loaded = [defaultSmokeScenario(), defaultThoroughScenario()]
        }
        scenarios = loaded.sorted { $0.title < $1.title }
    }

    private func defaultSmokeScenario() -> DevTestScenario {
        DevTestScenario(
            id: "smoke_test",
            title: "Smoke Test",
            actions: [
                .loadCreativeKeywords,
                .logReferenceData,
                .logTableData,
                .createCampaign(name: "Dev Smoke Test"),
                .setPartySize(1),
                .setWorldLore(title: "Ethereal Steam", description: "A fog-drenched city with ghost trains and hidden elites."),
                .createCharacter(
                    name: "Hazel Woods",
                    level: 1,
                    abilities: DevAbilities(strength: 9, dexterity: 14, constitution: 15, intelligence: 16, wisdom: 13, charisma: 17),
                    proficiencies: ["Investigation", "Perception", "Persuasion"]
                ),
                .moveToLocation(label: "Roadside Camp"),
                .prepareHiddenTransition(label: "Root-Covered Trapdoor"),
                .startScene(expected: "A lone road crosses the fog-drenched outskirts."),
                .adaptivePlayerInput(goal: "I travel the road in a storm for two hours.", kind: PlayerActionKind.travel.rawValue, roll: 14),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 14),
                .adaptivePlayerInput(goal: "GM, is there a hidden door here?", kind: PlayerActionKind.question.rawValue, roll: 15),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 15),
                .adaptivePlayerInput(goal: "I open and enter the Root-Covered Trapdoor.", kind: PlayerActionKind.movement.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .startScene(expected: "The platform opens into a shadowy concourse with murmuring travelers."),
                .adaptivePlayerInput(goal: "I try to persuade a dockworker to share the ghost train schedule.", kind: PlayerActionKind.skillCheck.rawValue, roll: 1),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 1),
                .adaptivePlayerInput(goal: "Oof. That went badly.", kind: PlayerActionKind.other.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: false, concluded: false),
                .startScene(expected: "A service door stands ajar beside a humming generator."),
                .adaptivePlayerInput(goal: "I head through the adjoining doorway.", kind: PlayerActionKind.movement.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .logCampaignSnapshot(label: "Smoke complete"),
                .assertCampaignState(label: "Smoke baseline", minScenes: 3, minInteractions: 3, minSkillChecks: 2, minWorldFacts: 2)
            ]
        )
    }

    private func defaultThoroughScenario() -> DevTestScenario {
        DevTestScenario(
            id: "thorough_test",
            title: "Thorough Dev Test",
            actions: [
                .loadCreativeKeywords,
                .logReferenceData,
                .logTableData,
                .createCampaign(name: "Dev Thorough Test"),
                .setPartySize(1),
                .setWorldLore(title: "Windward Expanse", description: "Rolling plains, lonely roads, and ruins half-swallowed by grass."),
                .createCharacter(
                    name: "Hazel Woods",
                    level: 1,
                    abilities: DevAbilities(strength: 9, dexterity: 14, constitution: 15, intelligence: 16, wisdom: 13, charisma: 17),
                    proficiencies: ["Investigation", "Perception", "Survival"]
                ),
                .moveToLocation(label: "Roadside Camp"),
                .startScene(expected: "Traveling the road at dusk, the party keeps an eye out for trouble."),
                .adaptivePlayerInput(goal: "We travel the road at night in a storm for the next few hours.", kind: PlayerActionKind.travel.rawValue, roll: 14),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 14),
                .adaptivePlayerInput(goal: "Do we encounter anyone on the road?", kind: PlayerActionKind.question.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "We push deeper into the wilds through the storm.", kind: PlayerActionKind.travel.rawValue, roll: 9),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 9),
                .adaptivePlayerInput(goal: "I check the path for hazards or traps.", kind: PlayerActionKind.search.rawValue, roll: 15),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 15),
                .adaptivePlayerInput(goal: "I ask Hazel's sidekick to watch the rear while I inspect the road.", kind: PlayerActionKind.dialogue.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .logCampaignSnapshot(label: "After travel scene"),
                .startScene(expected: "A small ruin appears off the path."),
                .prepareHiddenTransition(label: "Root-Covered Trapdoor"),
                .adaptivePlayerInput(goal: "I search the ruin for anything unusual.", kind: PlayerActionKind.search.rawValue, roll: 10),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 10),
                .adaptivePlayerInput(goal: "GM, is there a hidden door here?", kind: PlayerActionKind.question.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "I open and enter the Root-Covered Trapdoor.", kind: PlayerActionKind.movement.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "I try an impossible solution: I use the wind and a loose banner to distract anything watching us.", kind: PlayerActionKind.interact.rawValue, roll: 20),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 20),
                .adaptivePlayerInput(goal: "I take a careful look at any object or symbol the GM just described.", kind: PlayerActionKind.explore.rawValue, roll: 13),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 13),
                .endScene(summary: "", pcsInControl: false, concluded: false),
                .logCampaignSnapshot(label: "After ruin scene"),
                .startScene(expected: "The night grows colder as you make camp."),
                .adaptivePlayerInput(goal: "We make camp and keep watch.", kind: PlayerActionKind.rest.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "Long rest in our roadside camp, keep watch, no fire.", kind: PlayerActionKind.rest.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "GM, summarize the immediate threats we still know about.", kind: PlayerActionKind.gmCommand.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "I ask whether the strange ruin symbol matches anything from the Windward Expanse lore.", kind: PlayerActionKind.question.rawValue, roll: 12),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .logCampaignSnapshot(label: "Thorough complete"),
                .assertCampaignState(label: "Thorough baseline", minScenes: 3, minInteractions: 8, minSkillChecks: 3, minWorldFacts: 4)
            ]
        )
    }
}

struct DevSmokeTestView: View {
    @Environment(\.modelContext) private var modelContext
    let coordinator: SoloSceneCoordinator
    @StateObject private var runner: DevTestRunner

    @MainActor init(coordinator: SoloSceneCoordinator) {
        self.coordinator = coordinator
        _runner = StateObject(wrappedValue: DevTestRunner(coordinator: coordinator))
    }

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
                .loadCreativeKeywords,
                .logReferenceData,
                .logTableData,
                .createCampaign(name: "Dev Smoke Test"),
                .setPartySize(1),
                .setWorldLore(title: "Ethereal Steam", description: "A fog-drenched city with ghost trains and hidden elites."),
                .createCharacter(
                    name: "Hazel Woods",
                    level: 1,
                    abilities: DevAbilities(strength: 9, dexterity: 14, constitution: 15, intelligence: 16, wisdom: 13, charisma: 17),
                    proficiencies: ["Investigation", "Perception", "Persuasion"]
                ),
                .moveToLocation(label: "Dungeon Entrance"),
                .startScene(expected: "Arrive at the fog-choked station as the ghost train hisses to a stop."),
                .adaptivePlayerInput(goal: "I scan the platform for traps or tripwires.", kind: PlayerActionKind.search.rawValue, roll: 20),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 20),
                .adaptivePlayerInput(goal: "Yes! Glad that worked.", kind: PlayerActionKind.other.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .startScene(expected: "The platform opens into a shadowy concourse with murmuring travelers."),
                .adaptivePlayerInput(goal: "I try to persuade a dockworker to share the ghost train schedule.", kind: PlayerActionKind.skillCheck.rawValue, roll: 1),
                .adaptivePlayerInput(goal: "__ROLL_IF_PROMPTED__", kind: PlayerActionKind.auto.rawValue, roll: 1),
                .adaptivePlayerInput(goal: "Oof. That went badly.", kind: PlayerActionKind.other.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: false, concluded: false),
                .startScene(expected: "A service door stands ajar beside a humming generator."),
                .adaptivePlayerInput(goal: "I head through the adjoining doorway.", kind: PlayerActionKind.movement.rawValue, roll: 12),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .logCampaignSnapshot(label: "Smoke complete"),
                .assertCampaignState(label: "Smoke baseline", minScenes: 3, minInteractions: 3, minSkillChecks: 2, minWorldFacts: 2)
            ]
        )
    }
}

private struct DevTestLogView: View {
    @Environment(\.dismiss) private var dismiss
    let log: [String]
    let isRunning: Bool
    @State private var didCopy = false

    private var logText: String {
        log.joined(separator: "\n")
    }

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
            .textSelection(.enabled)
            .navigationTitle("Dev Logs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(didCopy ? "Copied" : "Copy All") {
                        UIPasteboard.general.string = logText
                        didCopy = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: logText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

final class DevLogStore {
    private static let key = "devTestLogs"

    static func load() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let logs = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return logs
    }

    static func save(_ logs: [String]) {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct DevLogsView: View {
    @State private var logs: [String] = DevLogStore.load()
    @State private var didCopy = false

    private var logText: String {
        logs.joined(separator: "\n")
    }

    var body: some View {
        List {
            if logs.isEmpty {
                Text("No dev logs yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(logs.indices, id: \.self) { index in
                    Text(logs[index])
                        .textSelection(.enabled)
                }
            }
        }
        .textSelection(.enabled)
        .navigationTitle("Dev Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(didCopy ? "Copied" : "Copy All") {
                    UIPasteboard.general.string = logText
                    didCopy = true
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: logText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Clear") {
                    DevLogStore.clear()
                    logs = []
                    didCopy = false
                }
            }
        }
        .onAppear {
            logs = DevLogStore.load()
            didCopy = false
        }
    }
}
#endif
