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
    case gmResponse(text: String)
    case recordSkillCheck(skill: String, dc: Int, roll: Int, outcome: String, consequence: String)
    case endScene(summary: String, pcsInControl: Bool, concluded: Bool)
    case runScene(description: String, input: String)
    case performSkillCheck(skill: String, difficulty: Int)
    case moveToLocation(label: String)
    case advanceLocation(reason: String)
    case importTables(filename: String)

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
        case .startScene(let expected):
            try container.encode("startScene", forKey: .type)
            try container.encode(expected, forKey: .value1)
        case .playerInput(let text):
            try container.encode("playerInput", forKey: .type)
            try container.encode(text, forKey: .value1)
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
        case .importTables(let filename):
            try container.encode("importTables", forKey: .type)
            try container.encode(filename, forKey: .value1)
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

    private var engine = SoloCampaignEngine()
    private var locationEngine = SoloLocationEngine()
    private let model = SystemLanguageModel(useCase: .general)
    private let prompts = NarratorPrompts()
    private var pendingCheck: DevSkillCheckDraft?
    private var pendingScene: SceneRecord?
    private var pendingInteractions: [SceneInteraction] = []
    private var pendingSkillChecks: [DevSkillCheckDraft] = []
    private var pendingFateQuestions: [FateQuestionRecord] = []
    private var pendingRollHighlights: [String] = []
    private var pendingPlayerText: String?

    @MainActor
    func run(_ scenario: DevTestScenario, modelContext: ModelContext) async {
        log.removeAll()
        DevLogStore.save([])
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
        case .startScene(let expected):
            if let campaign = activeCampaign(in: modelContext) {
                if campaign.activeLocationId == nil {
                    _ = locationEngine.generateDungeonStart(campaign: campaign)
                }
                pendingScene = engine.resolveScene(campaign: campaign, expectedScene: expected)
                pendingInteractions = []
                pendingSkillChecks = []
                pendingFateQuestions = []
                pendingRollHighlights = []
                pendingPlayerText = nil
                append("Scene setup: \(expected)")
            }
        case .playerInput(let text):
            await handlePlayerInput(text, modelContext: modelContext)
        case .gmResponse(let text):
            let playerText = pendingPlayerText ?? ""
            let interaction = SceneInteraction(playerText: playerText, gmText: text)
            pendingInteractions.append(interaction)
            pendingPlayerText = nil
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
            var draft = DevSkillCheckDraft(playerAction: "Dev test \(skill) check", request: request)
            draft.roll = roll
            draft.total = roll
            draft.outcome = outcome
            draft.consequence = consequence
            pendingSkillChecks.append(draft)
            if roll == 20 || roll == 1 {
                pendingRollHighlights.append("Natural \(roll)")
            }
            append("Roll: \(roll) (\(skill) DC \(dc)) → \(outcome)")
        case .endScene(let summary, let pcsInControl, let concluded):
            if let campaign = activeCampaign(in: modelContext), let sceneRecord = pendingScene {
                let wrapUp = await draftSceneSummary(
                    campaign: campaign,
                    scene: sceneRecord,
                    summaryOverride: summary
                )
                let bookkeeping = BookkeepingInput(
                    summary: wrapUp.summary,
                    newCharacters: wrapUp.newCharacters,
                    newThreads: wrapUp.newThreads,
                    featuredCharacters: wrapUp.featuredCharacters,
                    featuredThreads: wrapUp.featuredThreads,
                    removedCharacters: wrapUp.removedCharacters,
                    removedThreads: wrapUp.removedThreads,
                    pcsInControl: pcsInControl,
                    concluded: concluded,
                    interactions: pendingInteractions,
                    skillChecks: buildSkillCheckRecords(from: pendingSkillChecks),
                    fateQuestions: pendingFateQuestions,
                    places: wrapUp.places,
                    curiosities: wrapUp.curiosities,
                    rollHighlights: wrapUp.rollHighlights + pendingRollHighlights,
                    locationId: campaign.activeLocationId,
                    generatedEntityIds: [],
                    canonizations: []
                )
                _ = engine.finalizeScene(campaign: campaign, scene: sceneRecord, bookkeeping: bookkeeping)
                append("GM Summary Draft: \(wrapUp.summary)")
                append("Scene summary saved.")
                pendingScene = nil
                pendingInteractions = []
                pendingSkillChecks = []
                pendingFateQuestions = []
                pendingRollHighlights = []
                pendingPlayerText = nil
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
        case .advanceLocation(let reason):
            if let campaign = activeCampaign(in: modelContext) {
                if campaign.activeLocationId == nil {
                    _ = locationEngine.generateDungeonStart(campaign: campaign)
                }
                let node = locationEngine.advanceToNextNode(campaign: campaign, reason: reason)
                append("Advance location: \(node?.summary ?? "Unknown")")
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
    private func handlePlayerInput(_ text: String, modelContext: ModelContext) async {
        append("Player: \(text)")
        pendingPlayerText = text
        guard let campaign = activeCampaign(in: modelContext),
              let sceneRecord = pendingScene else {
            append("GM: No active scene. Start a scene first.")
            return
        }

        let context = engine.buildNarrationContext(campaign: campaign, scene: sceneRecord)

        if let pendingCheck {
            await resolvePendingCheck(
                pendingCheck,
                playerText: text,
                context: context
            )
            return
        }

        if isAcknowledgementMessage(text) {
            let gmText = await generateGMResponse(
                context: context,
                playerText: text,
                isMeta: false
            )
            appendGMResponse(gmText, playerText: text)
            return
        }

        if await handleMovement(
            playerText: text,
            context: context,
            campaign: campaign,
            modelContext: modelContext
        ) {
            let updatedContext = engine.buildNarrationContext(campaign: campaign, scene: sceneRecord)
            let gmText = await generateGMResponse(
                context: updatedContext,
                playerText: text,
                isMeta: false
            )
            appendGMResponse(gmText, playerText: text)
            return
        }

        if await proposeCheck(
            playerText: text,
            context: context
        ) {
            return
        }

        let gmText = await generateGMResponse(
            context: context,
            playerText: text,
            isMeta: isMetaMessage(text)
        )
        appendGMResponse(gmText, playerText: text)
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
    ) async -> SceneWrapUpDraft {
        let session = makeSession()

        let context = engine.buildNarrationContext(campaign: campaign, scene: scene)
        var prompt = """
        Draft a concise scene wrap-up with suggestions for characters, threads, places, curiosities, and key rolls.
        Only include important elements that clearly matter later.
        Emphasize why rolls happened and their outcomes.
        Use the interactions and checks below.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Scene Type: \(context.sceneType.rawValue)
        """

        if !pendingInteractions.isEmpty {
            prompt += "\nInteractions:"
            for interaction in pendingInteractions {
                prompt += "\n- Player: \(interaction.playerText)"
                if !interaction.gmText.isEmpty {
                    prompt += " / GM: \(interaction.gmText)"
                }
            }
        }

        if !pendingSkillChecks.isEmpty {
            prompt += "\nSkill Checks:"
            for check in pendingSkillChecks {
                let outcome = check.outcome ?? "unknown"
                prompt += "\n- \(check.playerAction) (\(check.request.skillName)) outcome: \(outcome)"
            }
        }

        if !pendingFateQuestions.isEmpty {
            prompt += "\nFate Questions:"
            for fate in pendingFateQuestions {
                prompt += "\n- \(fate.question) => \(fate.outcome.uppercased())"
            }
        }

        prompt += "\nReturn a SceneWrapUpDraft."

        do {
            let response = try await session.respond(to: Prompt(prompt), generating: SceneWrapUpDraft.self)
            return response.content
        } catch {
            return SceneWrapUpDraft(
                summary: summaryOverride,
                newCharacters: [],
                newThreads: [],
                featuredCharacters: [],
                featuredThreads: [],
                removedCharacters: [],
                removedThreads: [],
                places: [],
                curiosities: [],
                rollHighlights: []
            )
        }
    }

    private func buildSkillCheckRecords(from drafts: [DevSkillCheckDraft]) -> [SkillCheckRecord] {
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
                reason: draft.request.reason
            )
            record.rollResult = draft.roll
            record.modifier = draft.modifier
            record.total = draft.total
            record.outcome = draft.outcome
            record.consequence = draft.consequence
            return record
        }
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
            line += " Want to attempt it?"
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
                .playerInput(text: "I scan the platform for traps or tripwires."),
                .playerInput(text: "Natural 20."),
                .playerInput(text: "Yes! Glad that worked."),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .startScene(expected: "The platform opens into a shadowy concourse with murmuring travelers."),
                .playerInput(text: "I try to persuade a dockworker to share the ghost train schedule."),
                .playerInput(text: "Natural 1."),
                .playerInput(text: "Oof. That went badly."),
                .endScene(summary: "", pcsInControl: false, concluded: false),
                .startScene(expected: "A service door stands ajar beside a humming generator."),
                .playerInput(text: "I head through the adjoining doorway."),
                .endScene(summary: "", pcsInControl: true, concluded: false)
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
                .playerInput(text: "I scan the platform for traps or tripwires."),
                .playerInput(text: "Natural 20."),
                .playerInput(text: "Yes! Glad that worked."),
                .endScene(summary: "", pcsInControl: true, concluded: false),
                .startScene(expected: "The platform opens into a shadowy concourse with murmuring travelers."),
                .playerInput(text: "I try to persuade a dockworker to share the ghost train schedule."),
                .playerInput(text: "Natural 1."),
                .playerInput(text: "Oof. That went badly."),
                .endScene(summary: "", pcsInControl: false, concluded: false),
                .startScene(expected: "A service door stands ajar beside a humming generator."),
                .playerInput(text: "I head through the adjoining doorway."),
                .endScene(summary: "", pcsInControl: true, concluded: false)
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
