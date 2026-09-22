import Foundation
import Combine
import FoundationModels
import SwiftData
import WorldState
import RPGEngine
import TableEngine
import NarratorAgent

struct InteractionDraft: Identifiable {
    let id = UUID()
    let playerText: String
    let gmText: String
    let turnSignal: String?
}

struct SkillCheckDraft: Identifiable {
    let id = UUID()
    var playerAction: String
    var request: CheckRequest
    var roll: Int?
    var modifier: Int?
    var total: Int?
    var outcome: String?
    var consequence: String?
    var sourceTrapId: UUID?
    var sourceKind: String?
    var travelRequest: TravelRequest? = nil
    var searchRequest: SearchRequest? = nil
    var searchResolution: SearchResolution? = nil
}

struct FateQuestionDraftState: Identifiable {
    let id = UUID()
    let question: String
    let likelihood: FateLikelihood
    let chaosFactor: Int
    let roll: Int
    let target: Int
    let outcome: String
    let gmText: String
}

struct CanonizationDraftState: Identifiable {
    let id = UUID()
    let assumption: String
    let likelihood: FateLikelihood
    let chaosFactor: Int
    let roll: Int?
    let target: Int?
    let outcome: String?
}

struct TableRollOutcome {
    let tableId: String
    let result: String
    let reason: String
}

struct SrdLookupOutcome {
    let category: String
    let name: String
    let lines: [String]
    let reason: String
}

struct PendingLocationFeature: Identifiable {
    let id = UUID()
    let name: String
    let summary: String
}

enum PlayerActionKind: String, CaseIterable, Identifiable {
    case auto
    case question
    case dialogue
    case movement
    case skillCheck
    case search
    case interact
    case explore
    case travel
    case rest
    case combatAttack
    case combatDash
    case combatDisengage
    case combatDodge
    case combatHelp
    case combatHide
    case combatReady
    case combatUseObject
    case castSpell
    case useItem
    case gmCommand
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:
            return "Auto (GM infers)"
        case .question:
            return "Question / Perceive"
        case .dialogue:
            return "Dialogue (in character)"
        case .movement:
            return "Move / Change location"
        case .skillCheck:
            return "Skill Check"
        case .search:
            return "Search / Investigate"
        case .interact:
            return "Interact / Manipulate"
        case .explore:
            return "Explore / Observe"
        case .travel:
            return "Travel / Journey"
        case .rest:
            return "Rest / Downtime"
        case .combatAttack:
            return "Combat: Attack"
        case .combatDash:
            return "Combat: Dash"
        case .combatDisengage:
            return "Combat: Disengage"
        case .combatDodge:
            return "Combat: Dodge"
        case .combatHelp:
            return "Combat: Help"
        case .combatHide:
            return "Combat: Hide"
        case .combatReady:
            return "Combat: Ready"
        case .combatUseObject:
            return "Combat: Use Object"
        case .castSpell:
            return "Cast Spell / Power"
        case .useItem:
            return "Use Item / Inventory"
        case .gmCommand:
            return "GM / Meta"
        case .other:
            return "Other"
        }
    }

    var intentCategoryOverride: IntentCategory? {
        switch self {
        case .question:
            return .playerQuestion
        case .dialogue:
            return .roleplayDialogue
        case .gmCommand:
            return .gmCommand
        case .auto:
            return nil
        default:
            return .playerIntent
        }
    }

    var forcesMovement: Bool {
        self == .movement || self == .travel
    }

    var shouldProposeCheck: Bool {
        switch self {
        case .skillCheck, .search, .interact, .explore,
             .combatAttack, .combatDash, .combatDisengage, .combatDodge,
             .combatHelp, .combatHide, .combatReady, .combatUseObject,
             .castSpell, .useItem:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class SoloSceneCoordinator: ObservableObject {

    @Published var interactionDrafts: [InteractionDraft] = []
    @Published var checkDrafts: [SkillCheckDraft] = []
    @Published var pendingCheckID: UUID?
    @Published var fateQuestionDrafts: [FateQuestionDraftState] = []
    @Published var canonizationDrafts: [CanonizationDraftState] = []
    @Published var pendingCanonizationId: UUID?
    @Published var pendingLocationFeatures: [PendingLocationFeature] = []
    @Published var agencyLogs: [AgencyLogEntry] = []
    @Published var lastPlayerIntentSummary: String?
    @Published var gmResponseError: String?
    @Published var isResponding = false
    @Published var rollHighlightsInput = ""

    var engine = SoloCampaignEngine()
    var locationEngine = SoloLocationEngine()
    var travelEngine = TravelEncounterEngine()

    private var autoRollEnabled = false
    private var gmRunsCompanionsEnabled = false
    private let promptInputTokenBudget = 3_000

    init(
        engine: SoloCampaignEngine = SoloCampaignEngine(),
        locationEngine: SoloLocationEngine = SoloLocationEngine(),
        travelEngine: TravelEncounterEngine = TravelEncounterEngine()
    ) {
        self.engine = engine
        self.locationEngine = locationEngine
        self.travelEngine = travelEngine
    }

    func resetConversation() {
        interactionDrafts = []
        checkDrafts = []
        pendingCheckID = nil
        fateQuestionDrafts = []
        canonizationDrafts = []
        pendingCanonizationId = nil
        pendingLocationFeatures = []
        agencyLogs = []
        lastPlayerIntentSummary = nil
        gmResponseError = nil
        isResponding = false
        rollHighlightsInput = ""
    }

    func requestGMResponse(
        campaign: Campaign,
        scene: SceneRecord,
        playerText: String,
        actionKind: PlayerActionKind = .auto,
        autoRollEnabled: Bool,
        gmRunsCompanionsEnabled: Bool,
        modelContext: ModelContext
    ) async -> String? {
        let trimmed = playerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        engine.ruleset = RulesetCatalog.ruleset(for: campaign.rulesetName)
        self.autoRollEnabled = autoRollEnabled
        self.gmRunsCompanionsEnabled = gmRunsCompanionsEnabled

        gmResponseError = nil
        isResponding = true
        defer { isResponding = false }

        do {
            let model = SystemLanguageModel(useCase: .general)
            let session = LanguageModelSession(model: model)
            var context = engine.buildNarrationContext(campaign: campaign, scene: scene)

            if let pendingID = pendingCheckID,
               let index = checkDrafts.firstIndex(where: { $0.id == pendingID }) {
                if let fallback = parseRollFallback(from: trimmed) {
                    if fallback.declines {
                        let gmText = "Got it. We move on without attempting the check."
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }

                    if fallback.autoRoll {
                        if !autoRollEnabled {
                            let gmText = "Auto-roll is disabled. Please roll and tell me the result, or enable auto-roll in Settings."
                            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                            return gmText
                        }

                        let roll = Int.random(in: 1...20)
                        let modifier = fallback.modifier ?? computedSkillBonus(for: checkDrafts[index], campaign: campaign) ?? 0
                        checkDrafts[index].roll = roll
                        checkDrafts[index].modifier = modifier

                        if checkDrafts[index].sourceKind == "creative_solution" {
                            let gmText = try await resolveCreativeCheck(session: session, draftIndex: index, roll: roll, campaign: campaign)
                            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                            pendingCheckID = nil
                            return gmText
                        }

                        if checkDrafts[index].sourceKind == "travel_check" {
                            let gmText = try await resolveTravelCheck(
                                session: session,
                                context: context,
                                draftIndex: index,
                                roll: roll,
                                modifier: modifier,
                                campaign: campaign,
                                modelContext: modelContext
                            )
                            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                            pendingCheckID = nil
                            return gmText
                        }

                        let result = engine.evaluateCheck(request: checkDrafts[index].request, roll: roll, modifier: modifier)
                        checkDrafts[index].total = result.total
                        checkDrafts[index].outcome = result.outcome
                        appendRollHighlight(for: checkDrafts[index], outcome: result.outcome, total: result.total)
                        applyTrapOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign, modelContext: modelContext)
                        checkDrafts[index].searchResolution = applySearchProcedureOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign)
                        logAgency(stage: "resolution", message: "Auto-roll check \(checkDrafts[index].request.skillName) => \(result.outcome) total \(result.total)")

                        let consequence = try await generateCheckConsequence(
                            session: session,
                            context: context,
                            check: checkDrafts[index],
                            result: result
                        )

                        checkDrafts[index].consequence = consequence
                        let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
                        let gmText = "Auto-roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(consequence)"
                        await captureWorldDelta(from: gmText, session: session, context: context, playerText: checkDrafts[index].playerAction, campaign: campaign)
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }

                    if let roll = fallback.roll {
                        let modifier = fallback.modifier ?? (wantsAutoBonus(trimmed) ? computedSkillBonus(for: checkDrafts[index], campaign: campaign) : nil) ?? 0
                        checkDrafts[index].roll = roll
                        checkDrafts[index].modifier = modifier

                        if checkDrafts[index].sourceKind == "creative_solution" {
                            let gmText = try await resolveCreativeCheck(session: session, draftIndex: index, roll: roll, campaign: campaign)
                            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                            pendingCheckID = nil
                            return gmText
                        }

                        if checkDrafts[index].sourceKind == "travel_check" {
                            let gmText = try await resolveTravelCheck(
                                session: session,
                                context: context,
                                draftIndex: index,
                                roll: roll,
                                modifier: modifier,
                                campaign: campaign,
                                modelContext: modelContext
                            )
                            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                            pendingCheckID = nil
                            return gmText
                        }

                        let result = engine.evaluateCheck(request: checkDrafts[index].request, roll: roll, modifier: modifier)
                        checkDrafts[index].total = result.total
                        checkDrafts[index].outcome = result.outcome
                        appendRollHighlight(for: checkDrafts[index], outcome: result.outcome, total: result.total)
                        applyTrapOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign, modelContext: modelContext)
                        checkDrafts[index].searchResolution = applySearchProcedureOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign)
                        logAgency(stage: "resolution", message: "Check \(checkDrafts[index].request.skillName) => \(result.outcome) total \(result.total)")

                        let consequence = try await generateCheckConsequence(
                            session: session,
                            context: context,
                            check: checkDrafts[index],
                            result: result
                        )

                        checkDrafts[index].consequence = consequence
                        let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
                        let gmText = "Result: \(outcomeText) (Total \(result.total)). \(consequence)"
                        await captureWorldDelta(from: gmText, session: session, context: context, playerText: checkDrafts[index].playerAction, campaign: campaign)
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }
                }

                if isBonusInquiry(trimmed) {
                    var gmText = bonusInquiryResponse(for: checkDrafts[index], campaign: campaign)
                    gmText += "\nPending check: \(pendingCheckReminder(for: checkDrafts[index].request))"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                if isLikelyQuestion(trimmed) {
                    let tableRoll = try await resolveTableRollIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        campaign: campaign
                    )
                    let srdLookup = try await resolveSrdLookupIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed
                    )
                    var gmText = try await generateNormalGMResponse(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        isMeta: false,
                        playerInputKind: .playerQuestion,
                        tableRoll: tableRoll,
                        srdLookup: srdLookup,
                        campaign: campaign
                    )
                    gmText += "\nPending check: \(pendingCheckReminder(for: checkDrafts[index].request))"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let rollDraft = try await session.respond(
                    to: Prompt(makeRollParsingPrompt(playerText: trimmed, check: checkDrafts[index])),
                    generating: CheckRollDraft.self
                )

                if rollDraft.content.declines {
                    let gmText = "Got it. We move on without attempting the check."
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    pendingCheckID = nil
                    return gmText
                }

                if rollDraft.content.autoRoll {
                    if !autoRollEnabled {
                        let gmText = "Auto-roll is disabled. Please roll and tell me the result, or enable auto-roll in Settings."
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        return gmText
                    }

                    let roll = Int.random(in: 1...20)
                    let modifier = rollDraft.content.modifier ?? computedSkillBonus(for: checkDrafts[index], campaign: campaign) ?? 0
                    checkDrafts[index].roll = roll
                    checkDrafts[index].modifier = modifier

                    if checkDrafts[index].sourceKind == "creative_solution" {
                        let gmText = try await resolveCreativeCheck(session: session, draftIndex: index, roll: roll, campaign: campaign)
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }

                    if checkDrafts[index].sourceKind == "travel_check" {
                        let gmText = try await resolveTravelCheck(
                            session: session,
                            context: context,
                            draftIndex: index,
                            roll: roll,
                            modifier: modifier,
                            campaign: campaign,
                            modelContext: modelContext
                        )
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }

                    let result = engine.evaluateCheck(request: checkDrafts[index].request, roll: roll, modifier: modifier)
                    checkDrafts[index].total = result.total
                    checkDrafts[index].outcome = result.outcome
                    appendRollHighlight(for: checkDrafts[index], outcome: result.outcome, total: result.total)
                    applyTrapOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign, modelContext: modelContext)
                    checkDrafts[index].searchResolution = applySearchProcedureOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign)
                    logAgency(stage: "resolution", message: "Auto-roll check \(checkDrafts[index].request.skillName) => \(result.outcome) total \(result.total)")

                    let consequence = try await generateCheckConsequence(
                        session: session,
                        context: context,
                        check: checkDrafts[index],
                        result: result
                    )

                    checkDrafts[index].consequence = consequence
                    let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
                    let gmText = "Auto-roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(consequence)"
                    await captureWorldDelta(from: gmText, session: session, context: context, playerText: checkDrafts[index].playerAction, campaign: campaign)
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    pendingCheckID = nil
                    return gmText
                }

                guard let roll = rollDraft.content.roll else {
                    let gmText = "I need the roll result (and modifier if any) to resolve that."
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let modifier = rollDraft.content.modifier
                    ?? explicitNoModifier(from: trimmed)
                    ?? (wantsAutoBonus(trimmed) ? computedSkillBonus(for: checkDrafts[index], campaign: campaign) : nil)
                    ?? 0

                checkDrafts[index].roll = roll
                checkDrafts[index].modifier = modifier

                if checkDrafts[index].sourceKind == "creative_solution" {
                    let gmText = try await resolveCreativeCheck(session: session, draftIndex: index, roll: roll, campaign: campaign)
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    pendingCheckID = nil
                    return gmText
                }

                if checkDrafts[index].sourceKind == "travel_check" {
                    let gmText = try await resolveTravelCheck(
                        session: session,
                        context: context,
                        draftIndex: index,
                        roll: roll,
                        modifier: modifier,
                        campaign: campaign,
                        modelContext: modelContext
                    )
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    pendingCheckID = nil
                    return gmText
                }

                let result = engine.evaluateCheck(request: checkDrafts[index].request, roll: roll, modifier: modifier)
                checkDrafts[index].total = result.total
                checkDrafts[index].outcome = result.outcome
                appendRollHighlight(for: checkDrafts[index], outcome: result.outcome, total: result.total)
                applyTrapOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign, modelContext: modelContext)
                checkDrafts[index].searchResolution = applySearchProcedureOutcomeIfNeeded(for: checkDrafts[index], outcome: result.outcome, campaign: campaign)
                logAgency(stage: "resolution", message: "Check \(checkDrafts[index].request.skillName) => \(result.outcome) total \(result.total)")

                let consequence = try await generateCheckConsequence(
                    session: session,
                    context: context,
                    check: checkDrafts[index],
                    result: result
                )

                checkDrafts[index].consequence = consequence
                let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
                let gmText = "Result: \(outcomeText) (Total \(result.total)). \(consequence)"
                await captureWorldDelta(from: gmText, session: session, context: context, playerText: checkDrafts[index].playerAction, campaign: campaign)
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                pendingCheckID = nil
                return gmText
            }

            if let pendingId = pendingCanonizationId,
               let index = canonizationDrafts.firstIndex(where: { $0.id == pendingId }) {
                let lower = trimmed.lowercased()
                if isAffirmativeResponse(lower) {
                    let likelihood = canonizationDrafts[index].likelihood
                    let roll = engine.rollD100()
                    let record = engine.resolveFateQuestion(
                        question: canonizationDrafts[index].assumption,
                        likelihood: likelihood,
                        chaosFactor: campaign.chaosFactor,
                        roll: roll
                    )
                    canonizationDrafts[index] = CanonizationDraftState(
                        assumption: canonizationDrafts[index].assumption,
                        likelihood: likelihood,
                        chaosFactor: campaign.chaosFactor,
                        roll: record.roll,
                        target: record.target,
                        outcome: record.outcome
                    )
                    pendingCanonizationId = nil
                    let gmText = "Canon roll (\(likelihood.rawValue), CF \(campaign.chaosFactor)): \(record.roll) vs \(record.target) => \(record.outcome.uppercased())."
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                if isNegativeResponse(lower) {
                    pendingCanonizationId = nil
                    let gmText = "Okay. We will leave that unconfirmed for now."
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let gmText = "Want to roll fate to canonize that assumption? (y/n)"
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

                if isAcknowledgementMessage(trimmed) {
                    let gmText = try await generateAcknowledgementResponse(
                        session: session,
                        context: context,
                        playerText: trimmed
                    )
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

            if actionKind != .auto {
                recordIntentLabel(actionKind, playerText: trimmed, campaign: campaign, modelContext: modelContext)
                logAgency(stage: "intent_override", message: "\(actionKind.rawValue): \(trimmed)")
            }

            let authorityEnvelope = PlayerAuthorityParser().parse(trimmed)
            logAuthorityEnvelope(authorityEnvelope)

            if let gmText = deterministicContractResponseIfNeeded(
                actionKind: actionKind,
                playerText: trimmed,
                context: context,
                campaign: campaign
            ) {
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .gmCommand {
                let tableRoll = try await resolveTableRollIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign
                )
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: true,
                    playerInputKind: .gmCommand,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .question {
                let tableRoll = try await resolveTableRollIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign
                )
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: false,
                    playerInputKind: .playerQuestion,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .dialogue {
                let travelOutcome = resolveTravelEventIfNeeded(
                    playerText: trimmed,
                    intentSummary: lastPlayerIntentSummary,
                    campaign: campaign,
                    modelContext: modelContext
                )
                let tableRoll: TableRollOutcome?
                if let travelOutcome {
                    tableRoll = travelOutcome
                } else {
                    tableRoll = try await resolveTableRollIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        campaign: campaign
                    )
                }
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: false,
                    playerInputKind: .roleplayDialogue,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .travel {
                let weatherRuling = adjudicateWeatherAssumptionIfNeeded(authorityEnvelope, campaign: campaign)
                let intent = authorityEnvelope.characterIntent.isEmpty ? trimmed : authorityEnvelope.characterIntent
                let travelDraft = travelCheckDraft(for: intent, campaign: campaign)
                checkDrafts.append(travelDraft)
                pendingCheckID = travelDraft.id
                if let request = travelDraft.travelRequest {
                    dispatchProcedureEvent(CampaignEventFactory().travelRequestEvent(request, sceneId: campaign.activeSceneId), campaign: campaign)
                }
                let gmText = [weatherRuling, gmLineForTravelCheck(travelDraft.request)]
                    .compactMap { $0 }
                    .joined(separator: " ")
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .auto, isMetaMessage(trimmed) {
                if let gmText = deterministicMetaResponseIfNeeded(playerText: trimmed, context: context, campaign: campaign) {
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }
                let tableRoll = try await resolveTableRollIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign
                )
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: true,
                    playerInputKind: .gmCommand,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if let trapDraft = trapSearchDraftIfNeeded(playerText: trimmed, campaign: campaign) {
                checkDrafts.append(trapDraft)
                pendingCheckID = trapDraft.id
                if let request = trapDraft.searchRequest {
                    dispatchProcedureEvent(CampaignEventFactory().searchRequestEvent(request, sceneId: campaign.activeSceneId), campaign: campaign)
                }
                let gmText = gmLineForCheck(trapDraft.request)
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if let trapTriggerDraft = trapTriggerDraftIfNeeded(playerText: trimmed, campaign: campaign, modelContext: modelContext) {
                checkDrafts.append(trapTriggerDraft)
                pendingCheckID = trapTriggerDraft.id
                let gmText = "Trap triggered: \(trapTriggerDraft.request.stakes) " + gmLineForCheck(trapTriggerDraft.request)
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if let joinResponse = attemptNpcJoinIfRequested(playerText: trimmed, campaign: campaign, modelContext: modelContext) {
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: joinResponse, turnSignal: "gm_response"))
                return joinResponse
            }

            let shouldAttemptMovement = actionKind == .auto || actionKind.forcesMovement
            if shouldAttemptMovement {
                let didAdvance = try await resolveMovementIntent(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign,
                    modelContext: modelContext
                )
                if didAdvance {
                    context = engine.buildNarrationContext(campaign: campaign, scene: scene)
                }
            }

            if actionKind.shouldProposeCheck {
                if try await resolveSkillCheckProposal(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    intentSummary: trimmed,
                    requestedMode: .askBeforeRolling,
                    campaign: campaign
                ) {
                    return interactionDrafts.last?.gmText
                }
            }

            if actionKind == .auto, shouldForceSkillCheck(for: trimmed) {
                if try await resolveSkillCheckProposal(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    intentSummary: nil,
                    requestedMode: .askBeforeRolling,
                    campaign: campaign
                ) {
                    return interactionDrafts.last?.gmText
                }
            }

            if actionKind != .auto {
                let travelOutcome = resolveTravelEventIfNeeded(
                    playerText: trimmed,
                    intentSummary: lastPlayerIntentSummary,
                    campaign: campaign,
                    modelContext: modelContext
                )
                let tableRoll: TableRollOutcome?
                if let travelOutcome {
                    tableRoll = travelOutcome
                } else {
                    tableRoll = try await resolveTableRollIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        campaign: campaign
                    )
                }
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: false,
                    playerInputKind: actionKind.intentCategoryOverride ?? .playerIntent,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                await captureLocationFeatures(from: gmText, session: session, campaign: campaign)

                if shouldSkipCanonization(for: trimmed) {
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let canonDraft = try await session.respond(
                    to: Prompt(makeCanonizationPrompt(playerText: trimmed, context: context, campaign: campaign)),
                    generating: CanonizationDraft.self
                )

                if canonDraft.content.shouldCanonize,
                   let likelihood = FateLikelihood.from(name: canonDraft.content.likelihood) {
                    let state = CanonizationDraftState(
                        assumption: canonDraft.content.assumption,
                        likelihood: likelihood,
                        chaosFactor: campaign.chaosFactor,
                        roll: nil,
                        target: nil,
                        outcome: nil
                    )
                    canonizationDrafts.append(state)
                    pendingCanonizationId = state.id
                    let gmTextWithCanon = gmText + "\nCanonize: \(canonDraft.content.assumption). Roll fate to confirm? (y/n)"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmTextWithCanon, turnSignal: "gm_response"))
                    return gmTextWithCanon
                }

                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            // Legacy auto intent classification path (used only when actionKind == .auto).
            let intentCategoryDraft = try await session.respond(
                to: Prompt(makeIntentCategoryPrompt(playerText: trimmed, context: context)),
                generating: IntentCategoryDraft.self
            )
            logAgency(stage: "intent_category", message: "\(intentCategoryDraft.content.category): \(intentCategoryDraft.content.reason)")

            guard let intentCategory = IntentCategory.from(name: intentCategoryDraft.content.category) else {
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: false,
                    playerInputKind: .unclear,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if intentCategory == .gmCommand {
                let tableRoll = try await resolveTableRollIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign
                )
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: true,
                    playerInputKind: .gmCommand,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if intentCategory == .unclear {
                let gmText = "I’m not sure what you want to do. Are you asking a question, attempting an action, or speaking in character?"
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if intentCategory == .playerQuestion {
                let fateDraft = try await session.respond(
                    to: Prompt(makeFatePrompt(playerText: trimmed, context: context)),
                    generating: FateQuestionDraft.self
                )

                if fateDraft.content.isFateQuestion == false {
                    let tableRoll = try await resolveTableRollIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        campaign: campaign
                    )
                    let srdLookup = try await resolveSrdLookupIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed
                    )
                    let gmText = try await generateNormalGMResponse(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        isMeta: false,
                        playerInputKind: .playerQuestion,
                        tableRoll: tableRoll,
                        srdLookup: srdLookup,
                        campaign: campaign
                    )
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                guard let likelihood = FateLikelihood.from(name: fateDraft.content.likelihood) else {
                    let gmText = "I couldn't judge the odds. Want to rephrase the question?"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let roll = engine.rollD100()
                let fateRecord = engine.resolveFateQuestion(
                    question: trimmed,
                    likelihood: likelihood,
                    chaosFactor: campaign.chaosFactor,
                    roll: roll
                )
                logAgency(stage: "resolution", message: "Fate \(likelihood.rawValue) => \(fateRecord.outcome) roll \(fateRecord.roll)")

                let gmNarration = try await generateFateNarration(
                    session: session,
                    question: trimmed,
                    outcome: fateRecord.outcome
                )
                let gmText = "Fate Roll (\(likelihood.rawValue), CF \(campaign.chaosFactor)): \(fateRecord.roll) vs \(fateRecord.target) => \(fateRecord.outcome.uppercased()). \(gmNarration)"

                fateQuestionDrafts.append(FateQuestionDraftState(
                    question: trimmed,
                    likelihood: likelihood,
                    chaosFactor: campaign.chaosFactor,
                    roll: fateRecord.roll,
                    target: fateRecord.target,
                    outcome: fateRecord.outcome,
                    gmText: gmText
                ))

                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if intentCategory == .playerIntent {
                let intentDraft = try await session.respond(
                    to: Prompt(makePlayerIntentPrompt(playerText: trimmed, context: context)),
                    generating: PlayerIntentDraft.self
                )
                logAgency(stage: "intent_extract", message: intentDraft.content.summary)
                lastPlayerIntentSummary = intentDraft.content.summary

                if needsClarification(intentDraft.content) {
                    let gmText = "I want to make sure I understand. What exactly are you trying to do?"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                if let travelOutcome = resolveTravelEventIfNeeded(
                    playerText: trimmed,
                    intentSummary: intentDraft.content.summary,
                    campaign: campaign,
                    modelContext: modelContext
                ) {
                    let gmText = try await generateNormalGMResponse(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        isMeta: false,
                        playerInputKind: .playerIntent,
                        tableRoll: travelOutcome,
                        srdLookup: nil,
                        campaign: campaign
                    )
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    return gmText
                }

                let requestedMode = PlayerRequestedMode.from(name: intentDraft.content.requestedMode) ?? .askBeforeRolling
                if try await resolveSkillCheckProposal(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    intentSummary: intentDraft.content.summary,
                    requestedMode: requestedMode,
                    campaign: campaign
                ) {
                    return interactionDrafts.last?.gmText
                }
            }

            if intentCategory == .roleplayDialogue {
                let travelOutcome = resolveTravelEventIfNeeded(
                    playerText: trimmed,
                    intentSummary: lastPlayerIntentSummary,
                    campaign: campaign,
                    modelContext: modelContext
                )
                let tableRoll: TableRollOutcome?
                if let travelOutcome {
                    tableRoll = travelOutcome
                } else {
                    tableRoll = try await resolveTableRollIfNeeded(
                        session: session,
                        context: context,
                        playerText: trimmed,
                        campaign: campaign
                    )
                }
                let srdLookup = try await resolveSrdLookupIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed
                )
                let gmText = try await generateNormalGMResponse(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    isMeta: false,
                    playerInputKind: .roleplayDialogue,
                    tableRoll: tableRoll,
                    srdLookup: srdLookup,
                    campaign: campaign
                )
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            let travelOutcome = resolveTravelEventIfNeeded(
                playerText: trimmed,
                intentSummary: lastPlayerIntentSummary,
                campaign: campaign,
                modelContext: modelContext
            )
            let tableRoll: TableRollOutcome?
            if let travelOutcome {
                tableRoll = travelOutcome
            } else {
                tableRoll = try await resolveTableRollIfNeeded(
                    session: session,
                    context: context,
                    playerText: trimmed,
                    campaign: campaign
                )
            }
            let srdLookup = try await resolveSrdLookupIfNeeded(
                session: session,
                context: context,
                playerText: trimmed
            )
            let gmText = try await generateNormalGMResponse(
                session: session,
                context: context,
                playerText: trimmed,
                isMeta: false,
                playerInputKind: intentCategory,
                tableRoll: tableRoll,
                srdLookup: srdLookup,
                campaign: campaign
            )
            await captureLocationFeatures(from: gmText, session: session, campaign: campaign)

            if shouldSkipCanonization(for: trimmed) {
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            let canonDraft = try await session.respond(
                to: Prompt(makeCanonizationPrompt(playerText: trimmed, context: context, campaign: campaign)),
                generating: CanonizationDraft.self
            )

            if canonDraft.content.shouldCanonize,
               let likelihood = FateLikelihood.from(name: canonDraft.content.likelihood) {
                let state = CanonizationDraftState(
                    assumption: canonDraft.content.assumption,
                    likelihood: likelihood,
                    chaosFactor: campaign.chaosFactor,
                    roll: nil,
                    target: nil,
                    outcome: nil
                )
                canonizationDrafts.append(state)
                pendingCanonizationId = state.id
                let combined = "\(gmText)\nCanonize: \(state.assumption). Roll fate to confirm? (y/n)"
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: combined, turnSignal: "gm_response"))
                return combined
            }

            interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
            return gmText
        } catch {
            gmResponseError = handleFoundationModelsError(error)
            return nil
        }
    }

    private func handleFoundationModelsError(_ error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            return FoundationModelsErrorHandler.handleGenerationError(generationError)
        } else if let toolCallError = error as? LanguageModelSession.ToolCallError {
            return FoundationModelsErrorHandler.handleToolCallError(toolCallError)
        } else if let customError = error as? FoundationModelsError {
            return customError.localizedDescription
        } else {
            return "Unexpected error: \(error.localizedDescription)"
        }
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
        let reason = cleanedSentence(request.reason)
        if !reason.isEmpty {
            line += " Reason: \(reason)."
        }
        let failure = cleanedFailureStakes(request.stakes)
        if !failure.isEmpty {
            line += " Failure: \(failure)."
        }
        if let partialDC = request.partialSuccessDC, let partialText = request.partialSuccessOutcome, !partialText.isEmpty {
            line += " Partial (DC \(partialDC)): \(cleanedSentence(partialText))."
        }
        if autoRollEnabled {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Tell me the d20 result and modifier, or say \"use my bonus\" if you want me to add it."
        }
        return line
    }

    private func gmLineForTravelCheck(_ request: CheckRequest) -> String {
        let skillName = request.skillName
        let ability = request.abilityOverride ?? engine.ruleset.defaultAbility(for: skillName) ?? "Ability"
        let abilityLine = "\(ability) (\(skillName))"
        var line = "Travel check: Since Hazel is traveling alone, she leads by default. Give me \(abilityLine), DC \(request.dc ?? 15), unless you justify a different skill."
        line += " Success means progress without trouble; partial success means progress with delay, exposure, or rising risk; failure means the journey creates a real complication."
        if autoRollEnabled {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Tell me the d20 result and modifier, or say \"use my bonus\" if you want me to add it."
        }
        return line
    }

    private func cleanedFailureStakes(_ text: String) -> String {
        var cleaned = cleanedSentence(text)
        if cleaned.hasPrefix("If you fail, ") {
            cleaned.removeFirst("If you fail, ".count)
        } else if cleaned.hasPrefix("if you fail, ") {
            cleaned.removeFirst("if you fail, ".count)
        } else if cleaned.hasPrefix("Failure to ") {
            cleaned.removeFirst("Failure to ".count)
            cleaned = "failing to " + cleaned
        } else if cleaned.hasPrefix("failure to ") {
            cleaned.removeFirst("failure to ".count)
            cleaned = "failing to " + cleaned
        } else if cleaned.hasPrefix("Failure would ") {
            cleaned.removeFirst("Failure would ".count)
        } else if cleaned.hasPrefix("failure would ") {
            cleaned.removeFirst("failure would ".count)
        }
        return cleanedSentence(cleaned)
    }

    private func cleanedSentence(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix(".") {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func pendingCheckReminder(for request: CheckRequest) -> String {
        let skillName = request.skillName
        if let dc = request.dc {
            return "\(skillName) check pending (DC \(dc)). Give me your roll when you're ready."
        }
        return "\(skillName) check pending. Give me your roll when you're ready."
    }

    private func modifierPromptText(for request: CheckRequest) -> String {
        let skillName = request.skillName
        return "Got the roll. What modifier should I add for \(skillName)? (Say \"flat\" if none.)"
    }

    private func wantsAutoBonus(_ text: String) -> Bool {
        let lower = text.lowercased()
        let phrases = ["use my bonus", "add my bonus", "use my modifier", "add my modifier", "apply my bonus", "with my bonus", "with my modifier"]
        return phrases.contains(where: { lower.contains($0) })
    }

    private func travelCheckDraft(for playerText: String, campaign: Campaign) -> SkillCheckDraft {
        let skillName = normalizedSkillName("Survival")
        let weather = CampaignAuthorityStateStore().load(from: campaign)?.weather
        let condition = weather.map { "Travel through \($0)" } ?? "Travel in uncertain conditions"
        let declared = DeclaredStakes(
            success: "You make progress and stay oriented without a new complication.",
            partial: "You make progress, but exposure, delay, or encounter risk increases.",
            failure: "You lose progress or face a declared travel complication.",
            criticalSuccess: "You make strong progress and gain a bounded positioning or shelter advantage.",
            criticalFailure: "Travel progress stalls and one declared risk worsens.",
            allowedMutations: [.progress, .time, .exposure, .delay, .encounterRisk, .sceneFact],
            forbiddenMutations: [.npc, .location, .quest, .treasure, .playerChoice, .playerFeeling]
        )
        let travelRequest = TravelRequest(
            originNodeID: campaign.activeNodeId,
            destinationName: nil,
            routeLabel: activeLocation(in: campaign)?.name,
            intendedHours: intendedTravelHours(from: playerText),
            weather: weather
        )
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: skillName,
            abilityOverride: nil,
            dc: 15,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "You lose time, risk exposure, or trigger an encounter check.",
            partialSuccessDC: 10,
            partialSuccessOutcome: "You make progress, but the weather, terrain, or timing creates a cost.",
            reason: "\(condition) is uncertain and consequential.",
            declaredStakes: declared
        )
        return SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: "travel_check",
            travelRequest: travelRequest
        )
    }

    private func intendedTravelHours(from text: String) -> Int {
        let lower = text.lowercased()
        for value in 1...12 where lower.contains("\(value) hour") || lower.contains("\(value) hr") {
            return value
        }
        return lower.contains("few hours") ? 3 : 1
    }

    private func travelOutcome(for total: Int) -> (outcome: String, modifier: Int) {
        switch total {
        case 20...:
            return ("success", -3)
        case 16...19:
            return ("success", -2)
        case 12...15:
            return ("partial_success", -1)
        case 8...11:
            return ("partial_success", 0)
        case 4...7:
            return ("failure", 1)
        default:
            return ("failure", 2)
        }
    }

    private func isBonusInquiry(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("bonus") || lower.contains("modifier") || lower.contains("mod") || lower.contains("what do i add")
    }

    private func isLikelyQuestion(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.contains("?") { return true }
        return ["do i", "is there", "can i", "what", "where", "when", "how", "who"].contains { lower.hasPrefix($0) }
    }

    private func explicitNoModifier(from text: String) -> Int? {
        let lower = text.lowercased()
        if lower.contains("no modifier") || lower.contains("no mod") || lower.contains("flat") || lower.contains("zero mod") {
            return 0
        }
        return nil
    }

    private func bonusInquiryResponse(for draft: SkillCheckDraft, campaign: Campaign) -> String {
        guard let pc = campaign.playerCharacters.first else {
            return "I don't have a character sheet on file yet. Tell me your modifier or update the character sheet."
        }

        let abilityName = draft.request.abilityOverride ?? engine.ruleset.defaultAbility(for: draft.request.skillName) ?? "Ability"
        guard let abilityScore = abilityScore(for: abilityName, in: pc) else {
            return "I don't have your \(abilityName) score yet. Tell me your modifier or update the character sheet."
        }
        let abilityMod = Int(floor(Double(abilityScore - 10) / 2.0))
        let isProficient = isProficientInSkill(draft.request.skillName, character: pc)

        if isProficient {
            guard let level = characterLevel(for: pc) else {
                return "I can see your \(abilityName) mod is \(abilityMod >= 0 ? "+\(abilityMod)" : "\(abilityMod)"), but I don't have your level/proficiency bonus. What's your total modifier?"
            }
            let prof = proficiencyBonus(for: level)
            let total = abilityMod + prof
            return "Your \(draft.request.skillName) bonus looks like \(total >= 0 ? "+\(total)" : "\(total)") (\(abilityName) mod \(abilityMod >= 0 ? "+\(abilityMod)" : "\(abilityMod)") + proficiency \(prof >= 0 ? "+\(prof)" : "\(prof)"))."
        }

        return "Your \(draft.request.skillName) bonus is \(abilityMod >= 0 ? "+\(abilityMod)" : "\(abilityMod)") based on \(abilityName). If that’s wrong, tell me your total modifier."
    }

    private func computedSkillBonus(for draft: SkillCheckDraft, campaign: Campaign) -> Int? {
        guard let pc = campaign.playerCharacters.first else { return nil }
        let abilityName = draft.request.abilityOverride ?? engine.ruleset.defaultAbility(for: draft.request.skillName) ?? "Ability"
        guard let abilityScore = abilityScore(for: abilityName, in: pc) else { return nil }
        let abilityMod = Int(floor(Double(abilityScore - 10) / 2.0))
        if isProficientInSkill(draft.request.skillName, character: pc) {
            guard let level = characterLevel(for: pc) else { return nil }
            return abilityMod + proficiencyBonus(for: level)
        }
        return abilityMod
    }

    private func abilityScore(for ability: String, in character: PlayerCharacter) -> Int? {
        let key = abilityKey(for: ability)
        return fieldInt(character, key: key)
    }

    private func abilityKey(for ability: String) -> String {
        let lower = ability.lowercased()
        if lower.contains("strength") || lower == "str" { return "str" }
        if lower.contains("dexterity") || lower == "dex" { return "dex" }
        if lower.contains("constitution") || lower == "con" { return "con" }
        if lower.contains("intelligence") || lower == "int" { return "int" }
        if lower.contains("wisdom") || lower == "wis" { return "wis" }
        if lower.contains("charisma") || lower == "cha" { return "cha" }
        return lower
    }

    private func characterLevel(for character: PlayerCharacter) -> Int? {
        fieldInt(character, key: "level")
    }

    private func fieldInt(_ character: PlayerCharacter, key: String) -> Int? {
        character.fields.first(where: { $0.key == key })?.valueInt
    }

    private func fieldList(_ character: PlayerCharacter, key: String) -> [String] {
        character.fields.first(where: { $0.key == key })?.valueStringList ?? []
    }

    private func isProficientInSkill(_ skill: String, character: PlayerCharacter) -> Bool {
        let skills = fieldList(character, key: "skills")
        return skills.contains(where: { $0.caseInsensitiveCompare(skill) == .orderedSame })
    }

    private func proficiencyBonus(for level: Int) -> Int {
        switch level {
        case ...4:
            return 2
        case 5...8:
            return 3
        case 9...12:
            return 4
        case 13...16:
            return 5
        default:
            return 6
        }
    }

    private func needsClarification(_ intent: PlayerIntentDraft) -> Bool {
        let verb = intent.verb.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = intent.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return verb.isEmpty || summary.isEmpty
    }

    private func logAgency(stage: String, message: String) {
        agencyLogs.append(AgencyLogEntry(stage: stage, message: message))
    }

    private func dispatchProcedureEvent(_ event: CampaignEvent, campaign: Campaign) {
        let result = CampaignReducer().apply(event, to: campaign)
        logAgency(
            stage: "procedure_event",
            message: "\(event.id) action=\(event.payload.operation) status=\(result.status.rawValue)"
        )
        if result.status == .rejected {
            logAgency(stage: "structural_assertion_failure", message: result.reason ?? "Procedure reducer rejected event.")
        }
    }

    private func logAuthorityEnvelope(_ envelope: PlayerAuthorityEnvelope) {
        let assumptions = envelope.worldAssumptions.map {
            "\($0.kind.rawValue)=\($0.proposedValue) status=\($0.status.rawValue) confirmation=\($0.requiresPlayerConfirmation)"
        }
        logAgency(
            stage: "intent_assumptions",
            message: "intent=\(envelope.characterIntent) assumptions=[\(assumptions.joined(separator: "; "))]"
        )
    }

    private func adjudicateWeatherAssumptionIfNeeded(
        _ envelope: PlayerAuthorityEnvelope,
        campaign: Campaign
    ) -> String? {
        guard let assumption = envelope.worldAssumptions.first(where: { $0.kind == .weather }) else { return nil }
        let established = CampaignAuthorityStateStore().load(from: campaign)?.weather
        let proposed = assumption.proposedValue.lowercased()
        let policy: WeatherAuthorityPolicy
        if let established, established.caseInsensitiveCompare(assumption.proposedValue) != .orderedSame {
            policy = .preserveEstablished
        } else if proposed.contains("violent") || proposed.contains("blizzard") {
            policy = .softenExtreme
        } else {
            policy = .acceptPlausible
        }

        let decision = WorldAuthorityEngine().adjudicateWeather(
            assumption,
            establishedWeather: established,
            policy: policy
        )
        let event = CampaignEventFactory().weatherAuthorityEvent(decision: decision, sceneId: campaign.activeSceneId)
        let application = CampaignReducer().apply(event, to: campaign)
        logAgency(
            stage: decision.resolution == .rejected ? "authority_proposal_rejected" : "authority_proposal_approved",
            message: "weather proposed=\(decision.proposedWeather) canonical=\(decision.canonicalWeather ?? "unchanged") resolution=\(decision.resolution.rawValue)"
        )
        logAgency(stage: "campaign_event", message: "\(event.id) \(event.type.rawValue) status=\(application.status.rawValue)")

        switch decision.resolution {
        case .accepted:
            let weather = decision.canonicalWeather ?? decision.proposedWeather
            return "Weather accepted: the GM establishes \(article(for: weather)) \(weather)."
        case .softened:
            let weather = decision.canonicalWeather ?? decision.proposedWeather
            return "Weather adjusted: the GM establishes \(article(for: weather)) \(weather)."
        case .rejected:
            if let established = decision.canonicalWeather {
                return "Weather unchanged: \(established) remains established."
            }
            return "Weather rejected: the proposed condition is not established."
        }
    }

    private func article(for value: String) -> String {
        guard let first = value.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    private func budgetedPrompt(_ text: String, label: String) -> Prompt {
        Prompt(compactedPromptIfNeeded(text, label: label))
    }

    private func compactedPromptIfNeeded(_ text: String, label: String) -> String {
        let estimated = estimatedTokenCount(text)
        guard estimated > promptInputTokenBudget else { return text }

        let maxCharacters = promptInputTokenBudget * 4
        let marker = "\n\n[Older context compacted to preserve output budget. Use only the remaining current scene facts and instructions.]\n\n"
        let markerCount = marker.count
        let headCount = max(2_000, (maxCharacters - markerCount) / 2)
        let tailCount = max(2_000, maxCharacters - markerCount - headCount)
        let compacted = String(text.prefix(headCount)) + marker + String(text.suffix(tailCount))
        logAgency(stage: "prompt_budget", message: "\(label) compacted from ~\(estimated) tokens to ~\(estimatedTokenCount(compacted)) tokens")
        return compacted
    }

    private func estimatedTokenCount(_ text: String) -> Int {
        max(1, (text.count + 3) / 4)
    }

    private func deterministicContractResponseIfNeeded(
        actionKind: PlayerActionKind,
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String? {
        if actionKind == .gmCommand || isMetaMessage(playerText) {
            return deterministicMetaResponseIfNeeded(playerText: playerText, context: context, campaign: campaign)
        }

        if actionKind == .question || isLikelyQuestion(playerText) {
            if let answer = deterministicQuestionResponseIfNeeded(playerText: playerText, context: context, campaign: campaign) {
                return answer
            }
        }

        if let companionResponse = unestablishedCompanionResponseIfNeeded(playerText: playerText, campaign: campaign) {
            return companionResponse
        }

        if actionKind == .rest {
            return restSetupResponse(playerText: playerText, campaign: campaign)
        }

        if let impossibleResponse = impossibleActionResponseIfNeeded(playerText: playerText) {
            return impossibleResponse
        }

        return nil
    }

    private func deterministicMetaResponseIfNeeded(
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String? {
        let lower = playerText.lowercased()
        guard lower.contains("summarize") || lower.contains("summary") || lower.contains("threat") else {
            return nil
        }

        let before = SceneCanonSnapshot(campaign: campaign)
        let result = CampaignStateQueryEngine().answer(.metaThreatSummary, campaign: campaign)
        if SceneCanonSnapshot(campaign: campaign) != before {
            logAgency(stage: "structural_assertion_failure", message: "Meta state query changed canonical state.")
        }
        let facts = result.playerVisibleFacts.joined(separator: " ")
        return "Known immediate threats: \(facts) Unknowns remain unknown until checked. What do you do?"
    }

    private func deterministicQuestionResponseIfNeeded(
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String? {
        let lower = playerText.lowercased()

        if lower.contains("hidden door") || lower.contains("secret door") {
            let result = CampaignStateQueryEngine().answer(.hiddenDoor, campaign: campaign)
            if let request = result.checkRequest {
                let tuned = tunedCheckRequest(request, campaign: campaign)
                enqueueCheck(playerText: playerText, request: tuned, sourceKind: "question_hidden_door", campaign: campaign)
                return "You can check. \(result.playerVisibleFacts.joined(separator: " ")) \(gmLineForCheck(tuned))"
            }
            return renderStateQuery(result)
        }

        if (lower.contains("symbol") || lower.contains("rune") || lower.contains("mark"))
            && (lower.contains("lore") || lower.contains("match") || lower.contains("windward")) {
            let request = tunedCheckRequest(
                CheckRequest(
                    checkType: .skillCheck,
                    skillName: normalizedSkillName("Arcana"),
                    abilityOverride: nil,
                    dc: 15,
                    opponentSkill: nil,
                    opponentDC: nil,
                    advantageState: .normal,
                    stakes: "The symbol remains unidentified for now.",
                    partialSuccessDC: 10,
                    partialSuccessOutcome: "You identify a broad theme, but not its exact origin or meaning.",
                    reason: "Matching a strange symbol to established lore requires magical or historical interpretation.",
                    declaredStakes: DeclaredStakes(
                        success: "The symbol matches a known Windward Expanse tradition and reveals its established purpose.",
                        partial: "The symbol broadly resembles protective magic, but its exact origin and meaning remain unknown.",
                        failure: "The symbol remains unidentified.",
                        criticalSuccess: "The symbol's purpose and its established regional tradition are identified.",
                        criticalFailure: "The symbol remains unidentified; no new danger is created.",
                        allowedMutations: [.clue, .lore],
                        forbiddenMutations: [.map, .location, .quest, .treasure, .npc, .item]
                    )
                ),
                campaign: campaign
            )
            enqueueCheck(playerText: playerText, request: request, sourceKind: "question_lore_symbol", campaign: campaign)
            return "You don't know yet from sight alone. \(gmLineForCheck(request))"
        }

        if lower.contains("encounter anyone") || lower.contains("see anyone") || lower.contains("is anyone") || lower.contains("anyone on the road") {
            let result = CampaignStateQueryEngine().answer(.visiblePeople, campaign: campaign)
            let answer = renderStateQuery(result, prompt: "A deliberate search is needed to detect anyone hidden from view. What do you do?")
            return answer.replacingOccurrences(of: "No person is visible here.", with: "No person is visible on the road.")
        }

        return nil
    }

    private func renderStateQuery(_ result: CampaignStateQueryResult, prompt: String = "What do you do?") -> String {
        let answer: String
        switch result.directAnswer {
        case .yes: answer = "Yes."
        case .no: answer = "No."
        case .unknown: answer = "You do not know yet."
        case .checkRequired: answer = "You can check."
        case .notApplicable: answer = ""
        }
        return [answer, result.playerVisibleFacts.joined(separator: " "), prompt]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func enqueueCheck(playerText: String, request: CheckRequest, sourceKind: String, campaign: Campaign) {
        let searchRequest = sourceKind == "question_hidden_door"
            ? makeSearchRequest(playerText: playerText, skill: request.skillName, dc: request.dc ?? 15, campaign: campaign)
            : nil
        let draft = SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: sourceKind,
            searchRequest: searchRequest
        )
        checkDrafts.append(draft)
        pendingCheckID = draft.id
        if let searchRequest {
            dispatchProcedureEvent(CampaignEventFactory().searchRequestEvent(searchRequest, sceneId: campaign.activeSceneId), campaign: campaign)
        }
    }

    private func makeSearchRequest(playerText: String, skill: String, dc: Int, campaign: Campaign) -> SearchRequest {
        let lower = playerText.lowercased()
        let mode: SearchMode = lower.contains("scan") || lower.contains("while moving") ? .movingObservation : .closeInvestigation
        return SearchRequest(
            mode: mode,
            locationID: campaign.activeLocationId,
            nodeID: campaign.activeNodeId,
            skill: skill,
            dc: dc,
            stakes: "Reveal an existing prepared target or report no reliable sign without inventing one."
        )
    }

    private func unestablishedCompanionResponseIfNeeded(playerText: String, campaign: Campaign) -> String? {
        let lower = playerText.lowercased()
        let companionTerms = ["sidekick", "companion", "hireling", "familiar"]
        guard companionTerms.contains(where: { lower.contains($0) }) else { return nil }
        guard !hasEstablishedCompanion(in: campaign) else { return nil }
        return "No sidekick or companion is currently established in the party. Did you mean an existing NPC, or do you want to create a formal companion before relying on them?"
    }

    private func hasEstablishedCompanion(in campaign: Campaign) -> Bool {
        if let members = campaign.party?.members {
            if members.contains(where: { member in
                member.isNpc || member.role.lowercased().contains("sidekick") || member.role.lowercased().contains("companion")
            }) {
                return true
            }
        }
        return campaign.npcs.contains { npc in
            npc.currentLocationId == campaign.activeLocationId
                && (npc.roleTag.lowercased().contains("sidekick") || npc.roleTag.lowercased().contains("companion"))
        }
    }

    private func restSetupResponse(playerText: String, campaign: Campaign) -> String {
        let locationName = activeLocation(in: campaign)?.name ?? "the current area"
        let lower = playerText.lowercased()
        let kind: RestKind? = lower.contains("long rest") ? .long : (lower.contains("short rest") ? .short : nil)
        let shelter: RestShelter?
        if ["inn", "house", "secure shelter", "fort"].contains(where: lower.contains) {
            shelter = .secure
        } else if ["camp", "tent", "cave", "ruin", "shelter"].contains(where: lower.contains) {
            shelter = .improvised
        } else {
            shelter = nil
        }
        let watch: RestWatch? = lower.contains("keep watch") || lower.contains("keeping watch") ? .soloPassive : (lower.contains("no watch") ? RestWatch.none : nil)
        let fire: RestFire? = lower.contains("no fire") ? .noFire : (lower.contains("fire") ? .small : nil)
        let plan = RestPlan(
            kind: kind,
            locationName: locationName,
            shelter: shelter,
            watch: watch,
            fire: fire,
            suppliesAvailable: 1
        )
        dispatchProcedureEvent(CampaignEventFactory().restPlanEvent(plan, sceneId: campaign.activeSceneId), campaign: campaign)

        let missing = RestProcedureEngine().missingDetails(plan)
        if !missing.isEmpty {
            let questions = missing.map { detail -> String in
                switch detail {
                case .kind: return "Short rest or long rest?"
                case .shelter: return "What shelter are you using?"
                case .watch: return "How are you handling watch?"
                case .fire: return "Fire or no fire?"
                }
            }
            logAgency(stage: "procedure_state", message: "rest pending missing=\(missing.map(\.rawValue).joined(separator: ","))")
            return "You begin setting camp at \(locationName). \(questions.joined(separator: " "))"
        }

        let authority = CampaignAuthorityStateStore().load(from: campaign)
        let severeWeather = authority?.weather?.lowercased().contains("storm") == true
        let interrupted = !(authority?.hiddenThreats.isEmpty ?? true) && plan.watch == RestWatch.none
        let resolution = RestProcedureEngine().resolve(plan, interrupted: interrupted, severeWeather: severeWeather)
        dispatchProcedureEvent(
            CampaignEventFactory().restResolutionEvent(plan: plan, resolution: resolution, sceneId: campaign.activeSceneId),
            campaign: campaign
        )
        logAgency(
            stage: "procedure_state",
            message: "rest time=\(resolution.timeHours) recovery=\(resolution.recovery.rawValue) supplies=\(resolution.suppliesConsumed) exposure=\(resolution.exposure) watch_risk=\(resolution.watchRisk) interrupted=\(resolution.interrupted)"
        )
        let interruption = resolution.interrupted ? "The rest is interrupted by an established pressure." : "The rest is not interrupted."
        return "\(resolution.timeHours) hours pass. Recovery: \(resolution.recovery.rawValue). Supplies used: \(resolution.suppliesConsumed). Exposure: \(resolution.exposure). \(interruption) What do you do?"
    }

    private func impossibleActionResponseIfNeeded(playerText: String) -> String? {
        let lower = playerText.lowercased()
        guard lower.contains("impossible") else { return nil }
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: "Creative Solution",
            abilityOverride: nil,
            dc: 10,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "The scene reacts with a bounded complication.",
            partialSuccessDC: 8,
            partialSuccessOutcome: "The tactic changes the scene but costs time.",
            reason: "The tactic is unusual, so the creative engine resolves a straight d20 within the established fiction.",
            declaredStakes: DeclaredStakes(
                success: "The tactic creates a bounded opening.",
                partial: "The tactic changes the scene but costs time.",
                failure: "Delay and encounter risk increase.",
                criticalSuccess: "The best plausible bounded opening grants advantage on the next related check.",
                criticalFailure: "Delay and encounter risk increase without inventing an enemy.",
                allowedMutations: [.sceneFact, .clue, .delay, .encounterRisk],
                forbiddenMutations: [.npc, .location, .quest, .treasure, .playerChoice]
            )
        )
        let draft = SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: 0,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: "creative_solution"
        )
        checkDrafts.append(draft)
        pendingCheckID = draft.id
        return CreativeSolutionsEngine().requestPrompt
    }

    private func knownImmediateThreats(context: NarrationContextPacket, campaign: Campaign) -> [String] {
        var threats: [String] = []
        let text = ([context.expectedScene, context.currentLocation ?? "", context.currentNode ?? ""] + context.recentCuriosities + context.recentRollHighlights).joined(separator: " ").lowercased()

        if text.contains("storm") || text.contains("cold") || text.contains("night") {
            threats.append("storm, darkness, and cold exposure")
        }
        if text.contains("trap") || text.contains("hazard") {
            threats.append("possible traps or path hazards")
        }
        if text.contains("symbol") || text.contains("rune") || text.contains("glow") {
            threats.append("unresolved strange symbol or glow")
        }

        let presentCreatures = campaign.creatures.filter { $0.locationId == campaign.activeLocationId }.map(\.name)
        threats.append(contentsOf: presentCreatures.map { "confirmed creature: \($0)" })

        var seen: Set<String> = []
        return threats.filter { threat in
            let key = threat.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func recordIntentLabel(
        _ actionKind: PlayerActionKind,
        playerText: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) {
        guard actionKind != .auto else { return }
        let summary = "Intent label: \(actionKind.rawValue) | \(playerText)"
        let entry = EventLogEntry(summary: summary, sceneId: campaign.activeSceneId, origin: "intent_label")
        if campaign.eventLog == nil {
            campaign.eventLog = []
        }
        campaign.eventLog?.append(entry)
        try? modelContext.save()
    }

    private func availableTableIds() -> [String] {
        do {
            let pack = try ContentPackStore().loadDefaultPack()
            return pack.tables.map { $0.id }.sorted()
        } catch {
            return []
        }
    }

    private func resolveTableRollIfNeeded(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        campaign: Campaign
    ) async throws -> TableRollOutcome? {
        let tableIds = availableTableIds()
        guard !tableIds.isEmpty else { return nil }

        let draft = try await session.respond(
            to: Prompt(makeTableRollPrompt(playerText: playerText, context: context, tableIds: tableIds)),
            generating: TableRollRequestDraft.self
        )

        guard draft.content.shouldRoll,
              let tableId = draft.content.tableId,
              tableIds.contains(tableId) else { return nil }

        var tableOracle = TableOracleEngine()
        let result = tableOracle.rollMessage(campaign: campaign, tableId: tableId, tags: ["table_oracle", tableId])
        if let result {
            return TableRollOutcome(tableId: tableId, result: result, reason: draft.content.reason)
        }
        return nil
    }

    private func resolveSrdLookupIfNeeded(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String
    ) async throws -> SrdLookupOutcome? {
        let index = RulesetCatalog.contentIndex(for: engine.ruleset.id)
            ?? RulesetCatalog.contentIndex(for: engine.ruleset.displayName)
        guard let index else { return nil }

        let draft = try await session.respond(
            to: Prompt(makeSrdLookupPrompt(playerText: playerText, context: context)),
            generating: SrdLookupRequestDraft.self
        )

        guard draft.content.shouldLookup,
              let rawName = draft.content.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else { return nil }

        let category = draft.content.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let reason = draft.content.reason

        switch category {
        case "class":
            guard let name = matchSrdName(rawName, in: index.classes),
                  let lines = index.classDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Class", name: name, lines: lines, reason: reason)
        case "background":
            guard let name = matchSrdName(rawName, in: index.backgrounds),
                  let lines = index.backgroundDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Background", name: name, lines: lines, reason: reason)
        case "subclass":
            guard let name = matchSrdName(rawName, in: index.subclasses),
                  let lines = index.subclassDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Subclass", name: name, lines: lines, reason: reason)
        case "spell":
            guard let name = matchSrdName(rawName, in: index.spells),
                  let lines = index.spellDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Spell", name: name, lines: lines, reason: reason)
        case "feat":
            guard let name = matchSrdName(rawName, in: index.feats),
                  let lines = index.featDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Feat", name: name, lines: lines, reason: reason)
        case "item":
            guard let name = matchSrdName(rawName, in: index.magicItems),
                  let lines = itemDetailLines(for: name, index: index),
                  !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Magic Item", name: name, lines: lines, reason: reason)
        case "equipment":
            guard let name = matchSrdName(rawName, in: index.equipment),
                  let lines = itemDetailLines(for: name, index: index),
                  !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Equipment", name: name, lines: lines, reason: reason)
        case "creature", "monster":
            guard let name = matchSrdName(rawName, in: index.creatures),
                  let lines = creatureDetailLines(for: name, index: index),
                  !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Creature", name: name, lines: lines, reason: reason)
        case "condition":
            guard let name = matchSrdName(rawName, in: index.conditions),
                  let lines = index.conditionDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Condition", name: name, lines: lines, reason: reason)
        case "rule", "section":
            guard let name = matchSrdName(rawName, in: index.sections),
                  let lines = index.sectionDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Rule", name: name, lines: lines, reason: reason)
        default:
            return nil
        }
    }

    private func matchSrdName(_ name: String, in candidates: [String]) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return nil }
        if let exact = candidates.first(where: { $0.lowercased() == normalized }) {
            return exact
        }
        if let contains = candidates.first(where: { $0.lowercased().contains(normalized) }) {
            return contains
        }
        if let inverse = candidates.first(where: { normalized.contains($0.lowercased()) }) {
            return inverse
        }
        return nil
    }

    private func resolveTravelEventIfNeeded(
        playerText: String,
        intentSummary: String?,
        campaign: Campaign,
        modelContext: ModelContext,
        travelModifier: Int? = nil
    ) -> TableRollOutcome? {
        guard shouldProcessTravelEvent(playerText: playerText, intentSummary: intentSummary, campaign: campaign) else {
            return nil
        }

        let environment = travelEnvironment(for: playerText, campaign: campaign)
        let conditions = travelConditions(for: playerText)
        let travelMod = travelModifier ?? 0
        let resolution = travelEngine.resolveTravelEvent(
            campaign: campaign,
            environment: environment,
            conditions: conditions,
            travelModifier: travelMod
        )

        let summary = encounterCheckSummary(from: resolution.check)
        if let event = resolution.event {
            applyNpcReactionIfNeeded(from: event, campaign: campaign, modelContext: modelContext)
            createEncounterIfNeeded(from: event, campaign: campaign, modelContext: modelContext)
            spawnNpcIfNeeded(from: event, campaign: campaign, modelContext: modelContext)
            var parts = ["Travel event: \(event.event)"]
            if let intensity = event.encounterIntensity {
                parts.append("Encounter intensity: \(intensity)")
            }
            if !event.followUps.isEmpty {
                parts.append("Follow-ups: \(event.followUps.joined(separator: " | "))")
            }
            let modInfo = travelMod == 0 ? "" : " travel_mod=\(travelMod)"
            logAgency(stage: "travel_event", message: "\(parts.joined(separator: " ")) [\(summary)]\(modInfo)")
            return TableRollOutcome(
                tableId: "travel_event",
                result: parts.joined(separator: " "),
                reason: summary
            )
        }

        let modInfo = travelMod == 0 ? "" : " travel_mod=\(travelMod)"
        logAgency(stage: "travel_event", message: "No travel event. \(summary)\(modInfo)")
        return TableRollOutcome(
            tableId: "encounter_check",
            result: "Travel continues without incident.",
            reason: summary
        )
    }

    private func encounterCheckSummary(from outcome: EncounterCheckOutcome) -> String {
        let modifierText = outcome.modifier == 0 ? "" : (outcome.modifier > 0 ? "+\(outcome.modifier)" : "\(outcome.modifier)")
        let range = "\(outcome.encounterRange.lowerBound)-\(outcome.encounterRange.upperBound)"
        let resultText = outcome.triggered ? "Encounter triggered." : "No encounter."
        return "Encounter check \(outcome.dieSpec)\(modifierText): \(outcome.roll) -> \(outcome.modifiedRoll) vs \(range). \(resultText)"
    }

    private func applyNpcReactionIfNeeded(
        from event: TravelEventOutcome,
        campaign: Campaign,
        modelContext: ModelContext
    ) {
        guard let reaction = event.followUps.first(where: { $0.lowercased().contains("hostile") || $0.lowercased().contains("friendly") || $0.lowercased().contains("neutral") || $0.lowercased().contains("unfriendly") || $0.lowercased().contains("helpful") }) else {
            return
        }
        guard let locationId = campaign.activeLocationId else { return }
        guard let npc = campaign.npcs.first(where: { $0.currentLocationId == locationId }) else { return }

        let attitude = attitudeFromReaction(reaction)
        npc.attitudeToParty = attitude.rawValue
        npc.updatedAt = Date()

        let logEntry = EventLogEntry(
            summary: "NPC reaction set: \(npc.name) is now \(attitude.rawValue).",
            sceneId: campaign.activeSceneId,
            rollIds: nil,
            entityIds: [npc.id],
            origin: "system"
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }
        try? modelContext.save()
    }

    private func createEncounterIfNeeded(
        from event: TravelEventOutcome,
        campaign: Campaign,
        modelContext: ModelContext
    ) {
        guard let intensity = event.encounterIntensity else { return }
        guard let location = activeLocation(in: campaign) else { return }
        let node = activeNode(in: campaign, location: location)

        let encounter = EncounterEntity(
            type: "combat",
            difficulty: intensity,
            participantsSummary: event.event,
            hooks: event.followUps.isEmpty ? nil : event.followUps,
            resolved: false,
            origin: "system",
            locationNodeId: node?.id
        )

        if let node {
            if node.encounters == nil {
                node.encounters = [encounter]
            } else {
                node.encounters?.append(encounter)
            }
        }

        let logEntry = EventLogEntry(
            summary: "Generated encounter: \(intensity) — \(event.event)",
            sceneId: campaign.activeSceneId,
            rollIds: nil,
            entityIds: [encounter.id],
            origin: "system"
        )
        if campaign.eventLog == nil {
            campaign.eventLog = [logEntry]
        } else {
            campaign.eventLog?.append(logEntry)
        }
        try? modelContext.save()
    }

    private func spawnNpcIfNeeded(
        from event: TravelEventOutcome,
        campaign: Campaign,
        modelContext: ModelContext
    ) {
        guard let locationId = campaign.activeLocationId else { return }
        let present = campaign.npcs.first(where: { $0.currentLocationId == locationId })
        guard present == nil else { return }

        let lower = ([event.event] + event.followUps).joined(separator: " ").lowercased()
        let role: String?
        if lower.contains("scout") {
            role = "Scout"
        } else if lower.contains("merchant") || lower.contains("traveler") || lower.contains("travellers") || lower.contains("caravan") {
            role = "Traveler"
        } else if lower.contains("patrol") || lower.contains("guard") || lower.contains("watch") || lower.contains("authorities") {
            role = "Guard"
        } else if lower.contains("bandit") || lower.contains("raider") {
            role = "Bandit"
        } else {
            role = nil
        }
        guard let roleTag = role else { return }

        var npcEngine = SoloNpcEngine()
        let options = NpcGenerationOptions(name: nil, species: nil, roleTag: roleTag, importance: .minor)
        if let npc = npcEngine.generateNPC(campaign: campaign, options: options) {
            npc.currentLocationId = locationId
            campaign.npcs.append(npc)
            let logEntry = EventLogEntry(
                summary: "Spawned NPC: \(npc.name) (\(npc.roleTag))",
                sceneId: campaign.activeSceneId,
                rollIds: nil,
                entityIds: [npc.id],
                origin: "system"
            )
            if campaign.eventLog == nil {
                campaign.eventLog = [logEntry]
            } else {
                campaign.eventLog?.append(logEntry)
            }
            try? modelContext.save()
        }
    }

    private func attitudeFromReaction(_ reaction: String) -> NPCAttitude {
        let lower = reaction.lowercased()
        if lower.contains("hostile") {
            return .hostile
        }
        if lower.contains("unfriendly") {
            return .wary
        }
        if lower.contains("helpful") {
            return .friendly
        }
        if lower.contains("friendly") {
            return .friendly
        }
        return .neutral
    }

    private func shouldProcessTravelEvent(
        playerText: String,
        intentSummary: String?,
        campaign: Campaign
    ) -> Bool {
        let lower = playerText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return false }

        let travelKeywords = [
            "travel", "journey", "road", "path", "trail", "march", "ride", "sail",
            "set out", "head out", "continue", "keep going", "overland", "make camp", "camp"
        ]
        let encounterKeywords = ["encounter", "meet anyone", "anyone on the road", "ambush", "bandit", "patrol"]
        let summaryLower = intentSummary?.lowercased() ?? ""

        let hasTravelCue = travelKeywords.contains(where: { lower.contains($0) || summaryLower.contains($0) })
        let hasEncounterCue = encounterKeywords.contains(where: { lower.contains($0) })
        guard hasTravelCue || hasEncounterCue else { return false }

        if let location = activeLocation(in: campaign),
           location.type.lowercased() == "dungeon" {
            let dungeonMoveWords = ["door", "doorway", "hall", "hallway", "corridor", "room", "stair", "stairs", "passage"]
            if dungeonMoveWords.contains(where: { lower.contains($0) }) {
                return false
            }
        }

        return true
    }

    private func travelEnvironment(for playerText: String, campaign: Campaign) -> TravelEnvironment {
        let lower = playerText.lowercased()
        if lower.contains("road") || lower.contains("trail") || lower.contains("path") {
            return .road
        }
        if lower.contains("city") || lower.contains("street") || lower.contains("market") {
            return .city
        }
        if lower.contains("swamp") || lower.contains("jungle") || lower.contains("wilds") || lower.contains("hostile") {
            return .wilds
        }
        if lower.contains("dungeon") || lower.contains("ruin") || lower.contains("cave") || lower.contains("tunnel") {
            return .underground
        }
        if let location = activeLocation(in: campaign) {
            let type = location.type.lowercased()
            if type.contains("dungeon") || type.contains("ruin") {
                return .underground
            }
            if type.contains("settlement") || type.contains("city") || type.contains("urban") {
                return .city
            }
        }
        return .wilderness
    }

    private func travelConditions(for playerText: String) -> TravelConditions {
        let lower = playerText.lowercased()
        let nightWords = ["night", "dark", "evening", "midnight"]
        let badWeatherWords = ["storm", "rain", "blizzard", "snow", "gale", "fog", "heat wave"]
        let timeOfDay: TravelTimeOfDay = nightWords.contains(where: { lower.contains($0) }) ? .night : .day
        let badWeather = badWeatherWords.contains(where: { lower.contains($0) })
        return TravelConditions(timeOfDay: timeOfDay, badWeather: badWeather)
    }

    private func itemDetailLines(for name: String, index: SrdContentIndex) -> [String]? {
        if let record = index.itemRecords.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            var lines: [String] = []
            lines.append("**Category:** \(record.category)")
            if let sub = record.subcategory, !sub.isEmpty {
                lines.append("**Subcategory:** \(sub)")
            }
            if let type = record.itemType, !type.isEmpty {
                lines.append("**Type:** \(type)")
            }
            if let rarity = record.rarity, !rarity.isEmpty {
                lines.append("**Rarity:** \(rarity.capitalized)")
            }
            if record.requiresAttunement {
                lines.append("**Requires Attunement:** Yes")
            }
            if let attune = record.attunementRequirement, !attune.isEmpty {
                lines.append("**Attunement:** \(attune)")
            }
            if let cost = record.cost, !cost.isEmpty {
                lines.append("**Cost:** \(cost)")
            }
            if let weight = record.weight, !weight.isEmpty {
                lines.append("**Weight:** \(weight)")
            }
            if !record.properties.isEmpty {
                lines.append("**Properties:** \(record.properties.joined(separator: ", "))")
            }
            lines.append(contentsOf: record.description)
            return lines
        }
        if let details = index.magicItemDetails[name], !details.isEmpty {
            return details
        }
        if let details = index.equipmentDetails[name], !details.isEmpty {
            return details
        }
        return nil
    }

    private func creatureDetailLines(for name: String, index: SrdContentIndex) -> [String]? {
        if let record = index.creatureRecords.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            var lines: [String] = []
            if let size = record.size, let type = record.creatureType {
                let alignment = record.alignment ?? ""
                lines.append("*\(size) \(type)\(alignment.isEmpty ? "" : ", \(alignment)")*")
            }
            if let armorClass = record.armorClass { lines.append("**Armor Class** \(armorClass)") }
            if let hitPoints = record.hitPoints { lines.append("**Hit Points** \(hitPoints)") }
            if let speed = record.speed { lines.append("**Speed** \(speed)") }
            if !record.abilityScores.isEmpty {
                let scoreLine = record.abilityScores.map { "\($0.key) \($0.value)" }.joined(separator: " | ")
                lines.append(scoreLine)
            }
            if let vulnerabilities = record.damageVulnerabilities { lines.append("**Damage Vulnerabilities** \(vulnerabilities)") }
            if let resistances = record.damageResistances { lines.append("**Damage Resistances** \(resistances)") }
            if let immunities = record.damageImmunities { lines.append("**Damage Immunities** \(immunities)") }
            if let conditions = record.conditionImmunities { lines.append("**Condition Immunities** \(conditions)") }
            if let saves = record.savingThrows { lines.append("**Saving Throws** \(saves)") }
            if let skills = record.skills { lines.append("**Skills** \(skills)") }
            if let senses = record.senses { lines.append("**Senses** \(senses)") }
            if let languages = record.languages { lines.append("**Languages** \(languages)") }
            if let challenge = record.challenge { lines.append("**Challenge** \(challenge)") }
            if !record.traits.isEmpty {
                lines.append("**Traits**")
                lines.append(contentsOf: record.traits)
            }
            if !record.actions.isEmpty {
                lines.append("**Actions**")
                lines.append(contentsOf: record.actions)
            }
            if !record.reactions.isEmpty {
                lines.append("**Reactions**")
                lines.append(contentsOf: record.reactions)
            }
            if !record.legendaryActions.isEmpty {
                lines.append("**Legendary Actions**")
                lines.append(contentsOf: record.legendaryActions)
            }
            return lines
        }
        if let details = index.creatureDetails[name], !details.isEmpty {
            return details
        }
        return nil
    }

    private func isMetaMessage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()

        let metaPrefixes = ["gm", "dm", "game master", "dungeon master"]
        for prefix in metaPrefixes {
            guard lower.hasPrefix(prefix) else { continue }
            let endIndex = lower.index(lower.startIndex, offsetBy: prefix.count)
            if endIndex == lower.endIndex {
                return true
            }
            let nextChar = lower[endIndex]
            if nextChar.isWhitespace || nextChar == ":" || nextChar == "," {
                return true
            }
        }
        return false
    }

    private func isAffirmativeResponse(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["y", "yes", "yeah", "yep", "sure", "ok", "okay", "please"].contains(normalized)
    }

    private func isNegativeResponse(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["n", "no", "nope", "nah", "skip"].contains(normalized)
    }

    private func isAcknowledgementMessage(_ text: String) -> Bool {
        let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let acknowledgements = [
            "glad", "thanks", "thank you", "nice", "great", "cool", "ok", "okay",
            "awesome", "sweet", "oof", "dang", "yikes", "phew", "ugh", "yep", "yeah"
        ]
        guard acknowledgements.contains(where: { lower.contains($0) }) else { return false }
        let actionVerbs = ["try", "attempt", "go", "move", "open", "search", "look", "ask", "talk", "persuade", "investigate"]
        return !actionVerbs.contains(where: { lower.contains($0) })
    }

    private func trapSearchDraftIfNeeded(playerText: String, campaign: Campaign) -> SkillCheckDraft? {
        let lower = playerText.lowercased()
        let searchKeywords = ["check for traps", "search for traps", "look for traps", "scan for traps", "inspect for traps"]
        guard searchKeywords.contains(where: { lower.contains($0) }) else { return nil }
        if let trap = currentHiddenTrap(in: campaign) {
            let skillName = normalizedSkillName(trap.detectionSkill)
            let tuned = tunedCheckRequest(
                CheckRequest(
                    checkType: .skillCheck,
                    skillName: skillName,
                    abilityOverride: nil,
                    dc: trap.detectionDC,
                    opponentSkill: nil,
                    opponentDC: nil,
                    advantageState: .normal,
                    stakes: "You miss the trap and remain at risk of triggering it.",
                    partialSuccessDC: max(5, trap.detectionDC - 5),
                    partialSuccessOutcome: "You notice hints but not the exact trigger.",
                    reason: "Hidden \(trap.category) trap: \(trap.trigger)."
                ),
                campaign: campaign
            )
            return SkillCheckDraft(
                playerAction: playerText,
                request: tuned,
                roll: nil,
                modifier: nil,
                total: nil,
                outcome: nil,
                consequence: nil,
                sourceTrapId: trap.id,
                sourceKind: "trap_detection",
                searchRequest: makeSearchRequest(playerText: playerText, skill: tuned.skillName, dc: tuned.dc ?? trap.detectionDC, campaign: campaign)
            )
        }

        let baseDC = defaultTrapSearchDC(campaign: campaign)
        let request = tunedCheckRequest(
            CheckRequest(
                checkType: .skillCheck,
                skillName: normalizedSkillName("Investigation"),
                abilityOverride: nil,
                dc: baseDC,
                opponentSkill: nil,
                opponentDC: nil,
                advantageState: .normal,
                stakes: "You could miss a hidden danger and remain at risk of triggering it.",
                partialSuccessDC: max(5, baseDC - 5),
                partialSuccessOutcome: "You notice something off but can’t confirm a specific trigger.",
                reason: "You are deliberately searching the area for traps."
            ),
            campaign: campaign
        )
        return SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: "trap_search",
            searchRequest: makeSearchRequest(playerText: playerText, skill: request.skillName, dc: request.dc ?? baseDC, campaign: campaign)
        )
    }

    private func trapTriggerDraftIfNeeded(
        playerText: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) -> SkillCheckDraft? {
        let lower = playerText.lowercased()
        let triggerKeywords = ["open", "pull", "push", "touch", "step", "cross", "enter", "lift"]
        guard triggerKeywords.contains(where: { lower.contains($0) }) else { return nil }
        guard let trap = currentHiddenTrap(in: campaign) else { return nil }

        trap.state = "triggered"
        try? modelContext.save()
        let skillName = normalizedSkillName(trap.saveSkill ?? "Acrobatics")
        let dc = trap.saveDC ?? trap.detectionDC
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: skillName,
            abilityOverride: nil,
            dc: dc,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: trap.effectSummary,
            partialSuccessDC: max(5, dc - 5),
            partialSuccessOutcome: "You avoid the worst of it but still suffer a complication.",
            reason: "Trap trigger: \(trap.trigger)."
        )

        return SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: trap.id,
            sourceKind: "trap_trigger"
        )
    }

    private func applyTrapOutcomeIfNeeded(
        for draft: SkillCheckDraft,
        outcome: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) {
        if draft.searchRequest != nil { return }
        guard let trapId = draft.sourceTrapId else { return }
        guard let location = activeLocation(in: campaign) else { return }
        guard let node = activeNode(in: campaign, location: location) else { return }
        guard let traps = node.traps else { return }
        guard let trapIndex = traps.firstIndex(where: { $0.id == trapId }) else { return }

        let trap = traps[trapIndex]
        switch draft.sourceKind {
        case "trap_detection":
            if outcome == "success" || outcome == "partial_success" {
                trap.state = "spotted"
            }
        case "trap_trigger":
            trap.state = "triggered"
        default:
            break
        }
        try? modelContext.save()
    }

    private func applySearchProcedureOutcomeIfNeeded(
        for draft: SkillCheckDraft,
        outcome: String,
        campaign: Campaign
    ) -> SearchResolution? {
        guard let request = draft.searchRequest else { return nil }
        let stakesOutcome = StakesOutcome(rawValue: outcome) ?? .failure
        var targets: [HiddenSearchTarget] = []
        if let location = activeLocation(in: campaign), let node = activeNode(in: campaign, location: location) {
            targets.append(contentsOf: (node.traps ?? []).filter { $0.state == "hidden" }.map {
                HiddenSearchTarget(name: $0.name, kind: .trap, locationID: location.id, nodeID: node.id, boundEntityID: $0.id)
            })
            targets.append(contentsOf: (location.edges ?? []).filter {
                ($0.fromNodeId == nil || $0.fromNodeId == node.id) && $0.discovered != true
            }.map {
                HiddenSearchTarget(name: $0.label ?? $0.type, kind: .edge, locationID: location.id, nodeID: node.id, boundEntityID: $0.id)
            })
            targets.append(contentsOf: (node.features ?? []).filter { feature in
                let tags = (feature.tags ?? []).map { $0.lowercased() }
                return tags.contains("hidden") && !tags.contains("discovered")
            }.map {
                HiddenSearchTarget(name: $0.name, kind: .feature, locationID: location.id, nodeID: node.id, boundEntityID: $0.id)
            })
        }
        let resolution = SearchProcedureEngine().resolve(request, outcome: stakesOutcome, preparedTargets: targets)
        dispatchProcedureEvent(
            CampaignEventFactory().searchResolutionEvent(request: request, resolution: resolution, sceneId: campaign.activeSceneId),
            campaign: campaign
        )
        logAgency(
            stage: "procedure_state",
            message: "search mode=\(request.mode.rawValue) outcome=\(outcome) prepared_targets=\(targets.count) finding=\(resolution.finding.rawValue) revealed=\(resolution.revealedTarget?.name ?? "none")"
        )
        return resolution
    }

    private func currentHiddenTrap(in campaign: Campaign) -> TrapEntity? {
        guard let location = activeLocation(in: campaign) else { return nil }
        guard let node = activeNode(in: campaign, location: location) else { return nil }
        return node.traps?.first(where: { $0.state == "hidden" })
    }

    private func resolveMovementIntent(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) async throws -> Bool {
        guard campaign.activeLocationId != nil else { return false }
        let movementDraft = try await session.respond(
            to: Prompt(makeMovementIntentPrompt(playerText: playerText, context: context, campaign: campaign)),
            generating: MovementIntentDraft.self
        )
        if !movementDraft.content.isMovement {
            guard let fallback = fallbackMovementIntent(for: playerText) else { return false }
            return applyMovementIntent(
                summary: fallback.summary,
                destination: fallback.destination,
                exitLabel: fallback.exitLabel,
                playerText: playerText,
                campaign: campaign,
                modelContext: modelContext
            )
        }

        return applyMovementIntent(
            summary: movementDraft.content.summary,
            destination: movementDraft.content.destination,
            exitLabel: movementDraft.content.exitLabel,
            playerText: playerText,
            campaign: campaign,
            modelContext: modelContext
        )
    }

    private struct MovementFallback {
        let summary: String
        let destination: String?
        let exitLabel: String?
    }

    private func fallbackMovementIntent(for playerText: String) -> MovementFallback? {
        let trimmed = playerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if isLikelyQuestion(lower) { return nil }

        let blocked = ["check", "search", "scan", "look", "ask", "talk", "persuade", "investigate", "listen", "peek"]
        if blocked.contains(where: { lower.contains($0) }) {
            return nil
        }

        let movementVerbs = ["go", "move", "head", "enter", "step", "walk", "proceed", "leave", "exit", "approach", "follow", "advance", "climb"]
        guard movementVerbs.contains(where: { lower.contains($0) }) else { return nil }

        let exitKeywords = ["door", "doorway", "archway", "hall", "hallway", "corridor", "passage", "stair", "stairs", "gate", "path", "tunnel"]
        let exitLabel = exitKeywords.first(where: { lower.contains($0) })
        let destination = extractDestination(from: lower)

        return MovementFallback(summary: trimmed, destination: destination, exitLabel: exitLabel)
    }

    private func extractDestination(from text: String) -> String? {
        let tokens = ["to", "into", "through", "toward", "towards", "out of", "across"]
        for token in tokens {
            if let range = text.range(of: "\(token) ") {
                let candidate = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return String(candidate)
                }
            }
        }
        return nil
    }

    private func applyMovementIntent(
        summary: String,
        destination: String?,
        exitLabel: String?,
        playerText: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) -> Bool {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedExit = exitLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reason: String
        if !trimmedDestination.isEmpty && !trimmedSummary.isEmpty {
            reason = "\(trimmedSummary) (\(trimmedDestination))"
        } else if !trimmedSummary.isEmpty {
            reason = trimmedSummary
        } else if !trimmedDestination.isEmpty {
            reason = trimmedDestination
        } else {
            reason = playerText
        }

        if let location = activeLocation(in: campaign),
           let node = activeNode(in: campaign, location: location),
           let edge = edgeForExitLabel(trimmedExit, location: location, node: node) {
            guard edge.discovered == true else {
                logAgency(stage: "movement_blocked", message: "Undiscovered transition cannot be entered: \(edge.type) reason=\(reason)")
                return false
            }
            let event = CampaignEventFactory().explicitMovementEvent(edgeID: edge.id, sceneId: campaign.activeSceneId)
            let result = CampaignReducer().apply(event, to: campaign)
            logAgency(stage: "movement", message: "Explicit edge movement: \(edge.type) (\(edge.label ?? "")) status=\(result.status.rawValue) reason=\(reason)")
            guard result.status == .applied else { return false }
        } else {
            logAgency(stage: "movement_blocked", message: "No established transition matches reason=\(reason)")
            return false
        }
        try? modelContext.save()
        return true
    }

    private func attemptNpcJoinIfRequested(
        playerText: String,
        campaign: Campaign,
        modelContext: ModelContext
    ) -> String? {
        let lower = playerText.lowercased()
        let joinPhrases = ["join the party", "join our party", "come with us", "come along", "travel with us", "join us", "tag along"]
        guard joinPhrases.contains(where: { lower.contains($0) }) else { return nil }

        guard let npc = referencedNpc(in: playerText, campaign: campaign) else {
            return "Which NPC are you asking to join the party?"
        }

        let partyCount = currentPartyCount(campaign: campaign)
        guard partyCount < 5 else {
            npc.partyStatus = "declined"
            try? modelContext.save()
            return "\(npc.name) shakes their head. \"Your group is already full.\""
        }

        let attitude = npc.attitudeToParty.lowercased()
        guard attitude == NPCAttitude.friendly.rawValue else {
            npc.partyStatus = "declined"
            try? modelContext.save()
            return "\(npc.name) seems hesitant and declines to join right now."
        }

        let roll = engine.rollD100()
        if roll <= 20 {
            npc.partyStatus = "consented"
            npc.currentLocationId = campaign.activeLocationId
            engine.syncPartyMembers(campaign: campaign)
            try? modelContext.save()
            return "\(npc.name) agrees to travel with you as a sidekick."
        } else {
            npc.partyStatus = "declined"
            try? modelContext.save()
            return "\(npc.name) apologizes and decides to stay behind for now."
        }
    }

    private func referencedNpc(in text: String, campaign: Campaign) -> NPCEntry? {
        let lower = text.lowercased()
        return campaign.npcs.first(where: { npc in
            let name = npc.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return false }
            return lower.contains(name.lowercased())
        })
    }

    private func currentPartyCount(campaign: Campaign) -> Int {
        let pcs = campaign.playerCharacters.filter { !$0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let consentingNpcs = campaign.npcs.filter { $0.partyStatus == "consented" }
        return pcs.count + consentingNpcs.count
    }

    private func currentPartyAverageLevel(campaign: Campaign) -> Int {
        if let party = campaign.party, party.averageLevel > 0 {
            return party.averageLevel
        }
        if let members = campaign.party?.members, !members.isEmpty {
            let total = members.map { max(1, $0.level) }.reduce(0, +)
            return max(1, Int(round(Double(total) / Double(members.count))))
        }
        let levels = campaign.playerCharacters.compactMap { characterLevel(for: $0) }
        if !levels.isEmpty {
            let total = levels.reduce(0, +)
            return max(1, Int(round(Double(total) / Double(levels.count))))
        }
        return 1
    }

    private func maxDcForPartyLevel(_ level: Int) -> Int {
        switch level {
        case ...4:
            return 20
        case 5...10:
            return 25
        case 11...16:
            return 30
        default:
            return 30
        }
    }

    private func tunedCheckRequest(_ request: CheckRequest, campaign: Campaign) -> CheckRequest {
        let partyLevel = currentPartyAverageLevel(campaign: campaign)
        let maxDc = maxDcForPartyLevel(partyLevel)
        let adjustedDC = request.dc.map { min($0, maxDc) }
        let adjustedOpp = request.opponentDC.map { min($0, maxDc) }
        let baseDC = adjustedDC ?? adjustedOpp
        let adjustedPartial: Int?
        if baseDC != nil {
            adjustedPartial = max(5, (baseDC ?? 10) - 5)
        } else {
            adjustedPartial = request.partialSuccessDC
        }
        var reason = request.reason
        if adjustedDC != request.dc || adjustedOpp != request.opponentDC {
            reason = reason.isEmpty ? "Adjusted for party level." : "\(reason) Adjusted for party level."
        }
        return CheckRequest(
            checkType: request.checkType,
            skillName: request.skillName,
            abilityOverride: request.abilityOverride,
            dc: adjustedDC,
            opponentSkill: request.opponentSkill,
            opponentDC: adjustedOpp,
            advantageState: request.advantageState,
            stakes: request.stakes,
            partialSuccessDC: adjustedPartial,
            partialSuccessOutcome: request.partialSuccessOutcome,
            reason: reason,
            declaredStakes: request.declaredStakes
        )
    }

    private func defaultTrapSearchDC(campaign: Campaign) -> Int {
        let base = 10 + (activeLocation(in: campaign)?.dangerModifier ?? 0)
        return min(max(base, 5), maxDcForPartyLevel(currentPartyAverageLevel(campaign: campaign)))
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

    private struct RollParseFallback {
        let roll: Int?
        let modifier: Int?
        let autoRoll: Bool
        let declines: Bool
    }

    private func parseRollFallback(from text: String) -> RollParseFallback? {
        let lower = text.lowercased()
        let hasRollSignal = lower.contains("roll") || lower.contains("rolled") || lower.contains("got") || lower.contains("nat") || lower.contains("natural")
        if (lower.contains("bonus") || lower.contains("modifier")) && !hasRollSignal {
            return nil
        }
        if lower.contains("auto") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: true, declines: false)
        }
        if lower.contains("skip") || lower.contains("decline") || lower.contains("pass") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: false, declines: true)
        }
        if let modifier = explicitNoModifier(from: lower) {
            let rollPattern = "(?i)(natural|nat)\\s*(\\d+)"
            if let match = lower.range(of: rollPattern, options: .regularExpression) {
                let slice = lower[match]
                let digits = slice.split(whereSeparator: { !$0.isNumber })
                if let value = digits.compactMap({ Int($0) }).first, (1...20).contains(value) {
                    return RollParseFallback(roll: value, modifier: modifier, autoRoll: false, declines: false)
                }
            }

            let numbers = lower.split { !$0.isNumber }.compactMap { Int($0) }.filter { (1...20).contains($0) }
            if numbers.count == 1, let roll = numbers.first {
                return RollParseFallback(roll: roll, modifier: modifier, autoRoll: false, declines: false)
            }
        }

        let rollPattern = "(?i)(natural|nat)\\s*(\\d+)"
        if let match = lower.range(of: rollPattern, options: .regularExpression) {
            let slice = lower[match]
            let digits = slice.split(whereSeparator: { !$0.isNumber })
            if let value = digits.compactMap({ Int($0) }).first, (1...20).contains(value) {
                return RollParseFallback(roll: value, modifier: nil, autoRoll: false, declines: false)
            }
        }

        if lower.contains("dc") && !(lower.contains("roll") || lower.contains("rolled") || lower.contains("got")) {
            return nil
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

    private func activeLocation(in campaign: Campaign) -> LocationEntity? {
        guard let activeId = campaign.activeLocationId else { return nil }
        return campaign.locations?.first(where: { $0.id == activeId })
    }

    private func activeNode(in campaign: Campaign, location: LocationEntity) -> LocationNode? {
        guard let nodeId = campaign.activeNodeId else { return nil }
        return location.nodes?.first(where: { $0.id == nodeId })
    }

    private func activeLocationName(for context: NarrationContextPacket) -> String {
        guard let location = context.currentLocation else { return "none" }
        if let node = context.currentNode, !node.isEmpty {
            return "\(location) - \(node)"
        }
        return location
    }

    private func canonizationFacts(for campaign: Campaign) -> String {
        guard let location = activeLocation(in: campaign) else { return "" }
        var facts: [String] = ["Location: \(location.name) (\(location.type))"]
        if let node = activeNode(in: campaign, location: location) {
            facts.append("Node: \(node.summary)")
            if let traps = node.traps, !traps.isEmpty {
                let trapFacts = traps.map { "\($0.name) [\($0.state)]" }.joined(separator: ", ")
                facts.append("Traps: \(trapFacts)")
            }
        }
        return facts.joined(separator: " · ")
    }

    private func makeIntentCategoryPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Classify the player's message into one of:
        - player_intent (an action the player wants to attempt)
        - player_question (a question about the world)
        - roleplay_dialogue (in-character dialogue only)
        - gm_command (meta request to the GM)
        - unclear (ambiguous)

        Never assume the player took an action. If intent is unclear, choose unclear.
        If the player uses quotes or speaks as their character, prefer roleplay_dialogue.
        If the player addresses GM/DM directly, prefer gm_command.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return an IntentCategoryDraft.
        """
    }

    private func makePlayerIntentPrompt(playerText: String, context: NarrationContextPacket) -> String {
        var prompt = """
        Extract the player's intent without assuming any action occurred.
        Provide a short summary of what they are attempting.
        Only include party members if the player explicitly mentions them.
        If they ask for auto-resolution, set requestedMode to auto_resolve.
        Otherwise use ask_before_rolling.
        Do not infer NPC actions or dialogue from the player's text.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if gmRunsCompanionsEnabled {
            prompt += "\nGM runs companions is ENABLED, but still require explicit player intent."
        }

        prompt += "\nReturn a PlayerIntentDraft."
        return prompt
    }

    private func makeMovementIntentPrompt(
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String {
        var prompt = """
        Decide if the player is moving into a new space or leaving the current location.
        Return isMovement = true only when they explicitly move to a different room, corridor, exit, or location.
        Return false for questions, investigations, conversations, or actions that stay in the current space.
        Provide a short summary and optional destination if present.
        If they reference a specific exit, include its label or type in exitLabel.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if let location = activeLocation(in: campaign) {
            prompt += "\nLocation: \(location.name) (\(location.type))"
            if let node = activeNode(in: campaign, location: location) {
                prompt += "\nCurrent Node: \(node.summary)"
            }
        }

        if !context.currentExits.isEmpty {
            prompt += "\nKnown Exits: \(context.currentExits.joined(separator: " · "))"
        }

        prompt += "\nReturn a MovementIntentDraft."
        return prompt
    }

    private func makeCanonizationPrompt(
        playerText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String {
        var prompt = """
        Determine if the player is asserting a new concrete fact about the world that should be canonized.
        Only return shouldCanonize = true when the player explicitly states a detail as true
        (not a question, not a plan, not dialogue) and it would matter if accepted.
        Never infer NPC abilities, motives, or magical traits beyond what the player stated.
        If they are asking a question, speaking in character, or describing an action, return false.
        Provide a concise assumption and a likelihood for a fate roll.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Player: \(playerText)
        """
        let facts = canonizationFacts(for: campaign)
        if !facts.isEmpty {
            prompt += "\nKnown system facts: \(facts)"
        }
        return prompt
    }

    private func makeFatePrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Decide if the player's message is a yes/no fate question and pick likelihood.
        Use likelihood values: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain.
        Return a FateQuestionDraft.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Chaos Factor: \(context.chaosFactor)
        Player: \(playerText)
        """
    }

    private func shouldSkipCanonization(for playerText: String) -> Bool {
        let trimmed = playerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lower = trimmed.lowercased()
        if lower.contains("?") { return true }
        if lower.contains("\"") || lower.contains("“") || lower.contains("”") { return true }
        if lower.hasPrefix("gm ") || lower.hasPrefix("dm ") || lower.hasPrefix("ooc") { return true }

        let assertionMarkers = [
            "there is", "there are", "there's", "you see", "i notice", "i spot",
            "the room has", "the area has", "this place has", "the hall has"
        ]
        let actionPrefixes = ["i ", "we ", "my ", "our "]
        if actionPrefixes.contains(where: { lower.hasPrefix($0) }) && !assertionMarkers.contains(where: { lower.contains($0) }) {
            return true
        }
        return false
    }

    private func shouldCaptureLocationFeatures(from text: String) -> Bool {
        let lower = text.lowercased()
        let cues = ["you see", "there is", "there are", "you notice", "the room", "the hall", "the chamber", "the area"]
        return cues.contains(where: { lower.contains($0) }) && text.count > 20
    }

    private func makeLocationFeaturePrompt(text: String, location: LocationEntity, node: LocationNode) -> String {
        let existing = (node.features ?? []).map { $0.name }.joined(separator: ", ")
        return """
        Extract stable, inanimate location features worth persisting.
        Include furniture, fixtures, structures, and notable objects.
        Exclude NPCs, creatures, actions, or temporary effects.
        Limit to 0-5 items and keep summaries short.

        Location: \(location.name) (\(location.type))
        Node: \(node.summary)
        Known features: \(existing.isEmpty ? "none" : existing)

        Text: \(text)
        """
    }

    private func captureLocationFeatures(
        from text: String,
        session: LanguageModelSession,
        campaign: Campaign
    ) async {
        guard shouldCaptureLocationFeatures(from: text) else { return }
        guard let location = activeLocation(in: campaign),
              let node = activeNode(in: campaign, location: location) else { return }
        do {
            let prompt = makeLocationFeaturePrompt(text: text, location: location, node: node)
            let draft = try await session.respond(
                to: budgetedPrompt(prompt, label: "location_feature_extract"),
                generating: LocationFeatureDraft.self
            )
            let pendingNames = pendingLocationFeatures.map { $0.name.lowercased() }
            let existingFeatureNames = (node.features ?? []).map { $0.name.lowercased() }
            let existingNames = Set(existingFeatureNames + pendingNames)
            let candidates = draft.content.items.compactMap { item -> PendingLocationFeature? in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                guard !existingNames.contains(name.lowercased()) else { return nil }
                return PendingLocationFeature(name: name, summary: summary)
            }
            guard !candidates.isEmpty else { return }
            pendingLocationFeatures.append(contentsOf: candidates)
        } catch {
            return
        }
    }

    private func locationFeatureSummary(for node: LocationNode) -> String {
        guard let features = node.features, !features.isEmpty else { return "" }
        let summaries = features.prefix(4).map { feature in
            if feature.summary.isEmpty {
                return feature.name
            }
            return "\(feature.name) (\(feature.summary))"
        }
        return summaries.joined(separator: ", ")
    }

    private func makeCheckProposalPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Propose a ruleset-based skill check for a solo RPG.
        - Roll only if the action is uncertain and consequential.
        - If failure would change the situation in a meaningful way, a roll is required.
        - No roll for trivial or guaranteed actions; set requiresRoll to false and give autoOutcome.
        - Searching for traps or hidden dangers always requires a roll and should use Perception or Investigation.
        - Use DC bands: 5 obvious, 10 easy, 15 moderate, 20 hard, 25 very hard, 30 exceptional.
        - Prefer Perception for noticing sights, sounds, smells, or movement.
        - Prefer Investigation for close searching, deduction, mechanisms, and hidden compartments.
        - Prefer Survival for weather, navigation, tracks, and wilderness hazards.
        - Prefer Arcana, History, Religion, or Nature for lore based on the symbol or subject.
        - Advantage for strong leverage; disadvantage for harsh conditions.
        - Provide a concrete, in-fiction reason for the chosen DC.
        - Never cite chaos factor, test harness details, or a dungeon entrance unless the active location explicitly says that.
        - State concrete success, failure, and partial-success stakes; do not use placeholders.
        Return a CheckRequestDraft.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Player action: \(playerText)
        Recent places: \(context.recentPlaces.joined(separator: ", "))
        Recent curiosities: \(context.recentCuriosities.joined(separator: ", "))
        Active location: \(activeLocationName(for: context))
        Ruleset: \(engine.ruleset.displayName)
        Available skills: \(engine.ruleset.skillNames.joined(separator: ", "))
        """
    }

    private func resolveSkillCheckProposal(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        intentSummary: String? = nil,
        requestedMode: PlayerRequestedMode = .askBeforeRolling,
        campaign: Campaign
    ) async throws -> Bool {
        let checkDraft = try await session.respond(
            to: budgetedPrompt(makeCheckProposalPrompt(playerText: playerText, context: context), label: "check_proposal"),
            generating: CheckRequestDraft.self
        )

        if checkDraft.content.requiresRoll == false {
            if shouldForceSkillCheck(for: playerText), let forcedRequest = forcedCheckRequest(for: playerText) {
                let tunedRequest = tunedCheckRequest(forcedRequest, campaign: campaign)
                let draft = SkillCheckDraft(
                    playerAction: playerText,
                    request: tunedRequest,
                    roll: nil,
                    modifier: nil,
                    total: nil,
                    outcome: nil,
                    consequence: nil,
                    sourceTrapId: nil,
                    sourceKind: nil
                )
                checkDrafts.append(draft)
                pendingCheckID = draft.id
                let gmText = gmLineForCheck(tunedRequest)
                interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
                return true
            }
            let outcome = checkDraft.content.autoOutcome?.isEmpty == false ? checkDraft.content.autoOutcome! : "success"
            let gmText = "No roll needed. \(concreteAutomaticOutcome(outcome, playerText: playerText))"
            interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            return true
        }

        guard let request = engine.finalizeCheckRequest(from: checkDraft.content) else {
            let gmText = "I couldn't settle on a clear check. Want to rephrase?"
            interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            return true
        }
        let tunedRequest = tunedCheckRequest(request, campaign: campaign)
        if shouldForceSkillCheck(for: playerText),
           shouldOverrideTrapSkill(proposedSkill: request.skillName),
           let forcedRequest = forcedCheckRequest(for: playerText) {
            let tunedForced = tunedCheckRequest(forcedRequest, campaign: campaign)
            let draft = SkillCheckDraft(
                playerAction: playerText,
                request: tunedForced,
                roll: nil,
                modifier: nil,
                total: nil,
                outcome: nil,
                consequence: nil,
                sourceTrapId: nil,
                sourceKind: nil
            )
            checkDrafts.append(draft)
            pendingCheckID = draft.id
            let gmText = gmLineForCheck(tunedForced)
            interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            return true
        }
        logAgency(stage: "adjudication_request", message: "\(tunedRequest.skillName) dc=\(tunedRequest.dc ?? tunedRequest.opponentDC ?? 0) reason=\(tunedRequest.reason)")

        let draft = SkillCheckDraft(
            playerAction: playerText,
            request: tunedRequest,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: nil
        )
        checkDrafts.append(draft)
        pendingCheckID = draft.id

        if autoRollEnabled, requestedMode == .autoResolve {
            let roll = Int.random(in: 1...20)
            let modifier = computedSkillBonus(for: checkDrafts[checkDrafts.count - 1], campaign: campaign) ?? 0
            checkDrafts[checkDrafts.count - 1].roll = roll
            checkDrafts[checkDrafts.count - 1].modifier = modifier
            let result = engine.evaluateCheck(request: tunedRequest, roll: roll, modifier: modifier)
            checkDrafts[checkDrafts.count - 1].total = result.total
            checkDrafts[checkDrafts.count - 1].outcome = result.outcome
            appendRollHighlight(for: checkDrafts[checkDrafts.count - 1], outcome: result.outcome, total: result.total)
            logAgency(stage: "resolution", message: "Auto-roll check \(tunedRequest.skillName) => \(result.outcome) total \(result.total)")
            let consequence = try await generateCheckConsequence(
                session: session,
                context: context,
                check: checkDrafts[checkDrafts.count - 1],
                result: result
            )
            checkDrafts[checkDrafts.count - 1].consequence = consequence
            let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
            let gmText = "Auto-roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(consequence)"
            await captureWorldDelta(from: gmText, session: session, context: context, playerText: playerText, campaign: campaign)
            interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            pendingCheckID = nil
            return true
        }

        let gmText = gmLineForCheck(tunedRequest)
        interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
        return true
    }

    private func makeRollParsingPrompt(playerText: String, check: SkillCheckDraft) -> String {
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

    private func makeTableRollPrompt(
        playerText: String,
        context: NarrationContextPacket,
        tableIds: [String]
    ) -> String {
        let tableList = tableIds.joined(separator: ", ")
        return """
        Decide if a random table roll would help answer the player.
        Only request a roll when it directly supports the response.
        If a roll is needed, choose one table id from the provided list.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        Available Tables: \(tableList)

        Return a TableRollRequestDraft.
        """
    }

    private func makeSrdLookupPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Decide if an SRD lookup is needed to answer the player (rules text, class, subclass, background, spell, feat, item, equipment, creature).
        Only request a lookup when the player explicitly references something from the rules.
        If a lookup is needed, provide the category and name as stated by the player.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return a SrdLookupRequestDraft.
        """
    }

    private func generateNormalGMResponse(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        isMeta: Bool,
        playerInputKind: IntentCategory? = nil,
        tableRoll: TableRollOutcome? = nil,
        srdLookup: SrdLookupOutcome? = nil,
        campaign: Campaign
    ) async throws -> String {
        var prompt = """
        You are the game master in a solo RPG. Respond conversationally.
        Do not roll dice or change state. Ask clarifying questions when needed.
        Do not mention mechanics, chaos factor, or internal rolls.
        Do not ask the player to invent threats or obstacles; discover them through play.
        Never narrate player actions or decisions as if they already happened.
        Never say "you decide", "the party decides", "the player decides", "you feel compelled", or "what you don't see".
        Do not move the party into a new location unless the engine context already says the active location changed.
        Do not invent sidekicks, companions, hirelings, named NPCs, hidden enemies, treasures, or new locations as durable facts.
        If the player asks a direct question, answer first with "Yes", "No", "You don't know yet", or "You can check" before any narration.
        If the player asks for a GM/meta summary, summarize known state only and introduce no new fiction.
        Do not repeat or quote the player's input back as narration.
        Never say "several clues", "potential risks", "valuable information", or similar placeholders without naming the concrete clue, risk, object, sound, track, NPC reaction, exit, or changed condition.
        Every response must leave at least one actionable hook the player can inspect, avoid, confront, follow, ignore, or ask about.
        Use conditional phrasing or ask the player to choose.
        """

        if gmRunsCompanionsEnabled {
            prompt += "\nGM runs companions is enabled. You may narrate companion actions, but avoid taking major decisions without prompting."
        } else {
            prompt += "\nDo not move the party or companions unless the player explicitly says so."
        }

        if let playerInputKind {
            prompt += "\nPlayer input type: \(playerInputKind.rawValue)"
        }

        if let lastPlayerIntentSummary, !lastPlayerIntentSummary.isEmpty {
            prompt += "\nPlayer intent echo: \(lastPlayerIntentSummary)"
        }

        if playerInputKind == .roleplayDialogue {
            prompt += "\nTreat the player's message as their character's dialogue. Do not attribute it to NPCs."
        }

        prompt += "\nContext Card:\n\(buildContextCard(context: context))"

        prompt += """

        If the player pushes beyond the current scene scope, suggest ending the scene and offer:
        - Use a relevant sense from here to perceive what lies beyond, or
        - Move that way and start a new scene.
        """

        if isMeta {
            prompt += """

            The player is speaking out of character to the GM about rules, retcons, or clarifications.
            Keep it short and practical. Answer in GM/system voice, not NPC dialogue.
            Confirm any changes before assuming they apply.
            """
        }

        prompt += """

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if !isMeta {
            prompt += "\nAssume the player is speaking in character unless they address the GM directly."
            prompt += "\nEnd with a short actionable prompt like \"What do you do?\" after naming something concrete the player can respond to."
        }

        if !context.activeCharacters.isEmpty {
            let names = context.activeCharacters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Characters: \(names)"
        }

        if !context.activeThreads.isEmpty {
            let names = context.activeThreads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Threads: \(names)"
        }

        let presentNpcs = campaign.npcs.filter { $0.currentLocationId == campaign.activeLocationId }
        if !presentNpcs.isEmpty {
            let names = presentNpcs.map { "\($0.name) (\($0.roleTag))" }.joined(separator: ", ")
            prompt += "\nPresent NPCs: \(names)"
            prompt += "\nIf you refer to a present NPC again, use their name or \"the <role>\" rather than introducing \"a <role>\"."
        }
        let knownNpcs = campaign.npcs.filter { $0.currentLocationId != campaign.activeLocationId }
        if !knownNpcs.isEmpty {
            let names = knownNpcs.prefix(5).map { "\($0.name) (\($0.roleTag))" }.joined(separator: ", ")
            prompt += "\nKnown NPCs (not present): \(names)"
        }

        if let location = activeLocation(in: campaign) {
            prompt += "\nLocation: \(location.name) (\(location.type))"
            if let node = activeNode(in: campaign, location: location) {
                prompt += "\nCurrent Node: \(node.summary)"
                let featureSummary = locationFeatureSummary(for: node)
                if !featureSummary.isEmpty {
                    prompt += "\nKnown Features: \(featureSummary)"
                }
            }
        }

        if !context.currentExits.isEmpty {
            prompt += "\nCurrent Exits: \(context.currentExits.joined(separator: " · "))"
        }

        prompt += "\nGM runs companions: \(gmRunsCompanionsEnabled ? "enabled" : "disabled")"

        if !context.recentPlaces.isEmpty {
            prompt += "\nRecent Places: \(context.recentPlaces.joined(separator: ", "))"
        }

        if !context.recentCuriosities.isEmpty {
            prompt += "\nRecent Curiosities: \(context.recentCuriosities.joined(separator: ", "))"
        }

        if !context.recentRollHighlights.isEmpty {
            prompt += "\nRecent Rolls: \(context.recentRollHighlights.joined(separator: ", "))"
        }

        if let tableRoll {
            prompt += "\nTable Roll (\(tableRoll.tableId)): \(tableRoll.result)"
            if !tableRoll.reason.isEmpty {
                prompt += "\nTable Roll Reason: \(tableRoll.reason)"
            }
        }

        if let srdLookup {
            let detailSummary = srdLookup.lines.prefix(8).joined(separator: " ")
            prompt += "\nSRD Reference (\(srdLookup.category)): \(srdLookup.name)"
            if !srdLookup.reason.isEmpty {
                prompt += "\nSRD Lookup Reason: \(srdLookup.reason)"
            }
            if !detailSummary.isEmpty {
                prompt += "\nSRD Details: \(detailSummary)"
            }
        }

        prompt += """

        Return a NarratorTurnDraft, not final prose.
        Put only concrete rendering facts or sensory instructions in renderingBeats.
        Bind every beat that depends on a proposed delta using relatedProposalNames.
        proposedDeltas are proposals only; the engine will reject anything outside its authority.
        Use directAnswer=yes, no, unknown, check_required, or not_applicable.
        """

        let response = try await session.respond(
            to: budgetedPrompt(prompt, label: "narrator_turn_draft"),
            generating: NarratorTurnDraft.self
        )
        let validation = NarratorTurnValidator().validate(response.content, campaign: campaign)
        if !validation.rejectedChanges.isEmpty {
            let rejected = validation.rejectedChanges.map { "\($0.name) (\($0.reason))" }.joined(separator: ", ")
            logAgency(stage: "narrator_delta_rejected", message: rejected)
        }

        if !isMeta, !validation.acceptedChanges.isEmpty {
            let delta = WorldDeltaDraft(changes: validation.acceptedChanges)
            let result = WorldDeltaEngine().applyWorldDelta(delta, to: campaign, sceneId: campaign.activeSceneId)
            if !result.accepted.isEmpty {
                let names = result.accepted.map { "\($0.entityType.rawValue):\($0.name)" }.joined(separator: ", ")
                logAgency(stage: "narrator_delta_approved", message: names)
            }
            if !result.rejected.isEmpty {
                let names = result.rejected.map { "\($0.name) (\($0.reason))" }.joined(separator: ", ")
                logAgency(stage: "narrator_delta_rejected", message: names)
            }
        }

        let pipeline = NarratorAgentPipeline()
        let packetFallback = pipeline.renderDeterministicFallback(validation.approvedPacket)
        let fallback: String
        if validation.approvedPacket.directAnswer != .notApplicable {
            fallback = packetFallback
        } else {
            fallback = NarrationFailurePolicy().safeFallback(
                knownState: fallbackKnownState(packet: validation.approvedPacket, campaign: campaign)
            )
        }
        guard !validation.approvedPacket.renderingBeats.isEmpty else {
            logAgency(stage: "narrator_fallback", message: "No approved rendering beats remained after validation.")
            return fallback
        }

        let rejectedNames = validation.rejectedChanges.map(\.name)
        let outputContext = narratorOutputContext(campaign: campaign)
        for attempt in 0...NarrationFailurePolicy().maximumRetries {
            let renderResponse = try await session.respond(
                to: budgetedPrompt(pipeline.approvedRenderingPrompt(validation.approvedPacket), label: "approved_narration_render")
            )
            let rendered = renderResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let containsRejectedFact = rejectedNames.contains { name in
                !name.isEmpty && rendered.localizedCaseInsensitiveContains(name)
            }
            let structural = NarratorOutputContractValidator().validate(
                rendered,
                packet: validation.approvedPacket,
                context: outputContext
            )
            if !rendered.isEmpty, !containsRejectedFact, !violatesAgencyBoundary(rendered), structural.isValid {
                return rendered
            }
            let failures = attempt + 1
            let action = NarrationFailurePolicy().action(afterValidationFailures: failures)
            logAgency(
                stage: action == .retry ? "narrator_retry" : "narrator_fallback",
                message: "render validation failure=\(failures) violations=\(structural.violations.map(\.rawValue).joined(separator: ",")) rejected_fact=\(containsRejectedFact) agency=\(violatesAgencyBoundary(rendered))"
            )
        }
        return fallback
    }

    private func fallbackKnownState(packet: ApprovedNarrationPacket, campaign: Campaign) -> [String] {
        var facts = packet.renderingBeats
        if let location = activeLocation(in: campaign) { facts.append(location.name) }
        if let weather = CampaignAuthorityStateStore().load(from: campaign)?.weather { facts.append(weather) }
        return Array(facts.prefix(4))
    }

    private func narratorOutputContext(campaign: Campaign) -> NarratorOutputContext {
        let members = campaign.party?.members ?? []
        let playerCount = members.filter { !$0.isNpc }.count
        let presentAllies = campaign.npcs.filter { $0.currentLocationId == campaign.activeLocationId }.count
        let location = activeLocation(in: campaign)
        let locationText = ([location?.name ?? "", location?.type ?? ""] + (location?.tags ?? [])).joined(separator: " ").lowercased()
        let nodeText: String
        if let location, let node = activeNode(in: campaign, location: location) {
            nodeText = ([node.type, node.summary] + (node.tags ?? [])).joined(separator: " ").lowercased()
        } else {
            nodeText = ""
        }
        let combined = locationText + " " + nodeText
        let buildingTerms = ["building", "room", "chamber", "house", "inn", "interior"]
        let outdoorTerms = ["outdoor", "road", "route", "trail", "wild", "forest", "camp"]
        let hasBuilding = buildingTerms.contains(where: combined.contains)
        let environment: NarrationEnvironment = hasBuilding ? .indoors : (outdoorTerms.contains(where: combined.contains) ? .outdoors : .unknown)
        return NarratorOutputContext(
            isSolo: playerCount <= 1,
            presentAllyCount: presentAllies,
            environment: environment,
            hasEstablishedBuilding: hasBuilding
        )
    }

    private func makeWorldDeltaPrompt(
        playerText: String,
        gmText: String,
        context: NarrationContextPacket,
        campaign: Campaign
    ) -> String {
        var prompt = """
        Extract durable world-state changes from the GM narration.
        The narrator may invent flavor, but only stable facts should become state.
        Return create or update changes for concrete NPCs, locations, location features, objects, creatures, or lore.
        Return reference for entities merely mentioned, remembered, hypothetical, or already known without a new durable fact.
        Do not store player intent, player emotions, questions, rules explanations, dice results, prompts, or temporary action beats.
        Do not create new locations from suggested routes, lights, crevices, exits, or possible destinations unless the engine explicitly transitioned there.
        Do not create companions, sidekicks, hidden enemies, unseen adversaries, or "what you don't see" facts from narrator prose.
        Use location_feature for present visible details that belong to the current location, not location.
        Set needsClarification true if the narration depends on an ambiguous interpretation of the player's input.
        Use confidence below 65 for uncertain or decorative details so the engine will reject them.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Player: \(playerText)
        GM narration: \(gmText)
        """

        if let location = context.currentLocation {
            prompt += "\nCurrent Location: \(location)"
        }
        if let node = context.currentNode {
            prompt += "\nCurrent Node: \(node)"
        }

        let existingNpcNames = campaign.npcs.prefix(10).map(\.name).joined(separator: ", ")
        if !existingNpcNames.isEmpty {
            prompt += "\nKnown NPCs: \(existingNpcNames)"
        }
        let existingLocationNames = (campaign.locations ?? []).prefix(10).map(\.name).joined(separator: ", ")
        if !existingLocationNames.isEmpty {
            prompt += "\nKnown Locations: \(existingLocationNames)"
        }
        let existingItemNames = campaign.items.prefix(10).map(\.name).joined(separator: ", ")
        if !existingItemNames.isEmpty {
            prompt += "\nKnown Objects: \(existingItemNames)"
        }
        let existingCreatureNames = campaign.creatures.prefix(10).map(\.name).joined(separator: ", ")
        if !existingCreatureNames.isEmpty {
            prompt += "\nKnown Creatures: \(existingCreatureNames)"
        }

        prompt += "\nReturn a WorldDeltaDraft."
        return prompt
    }

    private func captureWorldDelta(
        from gmText: String,
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        campaign: Campaign
    ) async {
        do {
            let response = try await session.respond(
                to: budgetedPrompt(makeWorldDeltaPrompt(playerText: playerText, gmText: gmText, context: context, campaign: campaign), label: "world_delta"),
                generating: WorldDeltaDraft.self
            )
            let result = WorldDeltaEngine().applyWorldDelta(response.content, to: campaign, sceneId: campaign.activeSceneId)
            if !result.accepted.isEmpty {
                let names = result.accepted.map { "\($0.entityType.rawValue):\($0.name)" }.joined(separator: ", ")
                logAgency(stage: "world_delta", message: "stored \(names)")
            }
            if let question = result.clarificationQuestion, !question.isEmpty {
                logAgency(stage: "world_delta_clarification", message: question)
            }
            if !result.rejected.isEmpty {
                let names = result.rejected.prefix(3).map { "\($0.name) (\($0.reason))" }.joined(separator: ", ")
                logAgency(stage: "world_delta_rejected", message: names)
            }
        } catch {
            logAgency(stage: "world_delta_error", message: error.localizedDescription)
        }
    }

    private func generateFateNarration(
        session: LanguageModelSession,
        question: String,
        outcome: String
    ) async throws -> String {
        let prompt = """
        Answer the fate question with the given outcome in 1-2 sentences.
        Question: \(question)
        Outcome: \(outcome.uppercased())
        """
        let response = try await session.respond(to: budgetedPrompt(prompt, label: "fate_narration"))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func generateAcknowledgementResponse(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String
    ) async throws -> String {
        let lastGM = interactionDrafts.last?.gmText ?? ""
        let prompt = """
        Respond to the player's acknowledgement in 1-2 sentences.
        Stay in character as the GM. Do not advance the scene or assume new actions.
        Keep it grounded in the current moment. Do not ask \"what do you do next\".

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Last GM response: \(lastGM)
        Player: \(playerText)
        """
        let response = try await session.respond(to: budgetedPrompt(prompt, label: "acknowledgement"))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func violatesAgencyBoundary(_ text: String) -> Bool {
        let lower = " " + text.lowercased()
        let bannedPhrases = [
            "the party decided",
            "the party decides",
            "the player decided",
            "the player decides",
            "the players decided",
            "the players decide",
            "you decide",
            "you feel compelled",
            "you can't help but",
            "you can’t help but",
            "prompting them to",
            "prompting you to",
            "creating a small opening for their party to slip",
            "what you don't see",
            "what you don’t see"
        ]
        if bannedPhrases.contains(where: { lower.contains($0) }) {
            return true
        }
        let allowedVerbs = [
            "see", "hear", "notice", "spot", "feel", "smell", "sense", "recall", "realize"
        ]
        let bannedVerbs = [
            "decide", "charge", "attack", "cast", "open", "search", "inspect", "climb",
            "move", "enter", "leave", "take", "grab", "draw", "say", "says", "speak",
            "speaks", "tell", "tells", "go", "goes", "went", "use", "uses", "try", "tries",
            "attempt", "attempts", "pick", "picks", "persuade", "persuades", "sneak",
            "sneaks", "steal", "steals", "look", "looks", "run", "runs", "rush", "rushes"
        ]
        let conditionalPrefixes = [
            "if you", "would you", "could you", "do you", "can you", "should you",
            "when you", "as you", "you could", "you can", "you might", "you may"
        ]

        for verb in bannedVerbs {
            let token = "you \(verb)"
            guard lower.contains(token) else { continue }
            if allowedVerbs.contains(verb) { continue }
            if conditionalPrefixes.contains(where: { lower.contains("\($0) \(verb)") }) { continue }
            return true
        }
        return false
    }

    private func rewriteForAgency(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        draft: String
    ) async throws -> String {
        let prompt = """
        Rewrite the GM response to avoid assuming any player action occurred.
        Use conditional phrasing or ask the player to choose.
        Do not say "you decide", "the party decides", "the player decides", "you feel compelled", or "what you don't see".
        Do not move the party into a new location unless the player already chose that movement.
        Keep it to 1-3 short paragraphs, end with a short question.

        Player: \(playerText)
        Draft response: \(draft)

        Return only the rewritten response.
        """
        let response = try await session.respond(to: budgetedPrompt(prompt, label: "agency_rewrite"))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

        if !context.recentPlaces.isEmpty {
            lines.append("Known Places: \(context.recentPlaces.prefix(5).joined(separator: ", "))")
        }
        if !context.recentCuriosities.isEmpty {
            lines.append("Known Facts: \(context.recentCuriosities.prefix(5).joined(separator: ", "))")
        }

        if !context.currentExits.isEmpty {
            lines.append("Exits: \(context.currentExits.joined(separator: " · "))")
        }

        if !context.relevantLore.isEmpty {
            lines.append("Relevant Lore: \(context.relevantLore.prefix(3).joined(separator: " | "))")
        }
        if !context.relevantNPCs.isEmpty {
            lines.append("Relevant NPCs: \(context.relevantNPCs.prefix(3).joined(separator: " | "))")
        }
        if !context.relevantLocations.isEmpty {
            lines.append("Relevant Locations: \(context.relevantLocations.prefix(3).joined(separator: " | "))")
        }
        if !context.relevantItems.isEmpty {
            lines.append("Relevant Objects: \(context.relevantItems.prefix(3).joined(separator: " | "))")
        }
        if !context.relevantCreatures.isEmpty {
            lines.append("Relevant Creatures: \(context.relevantCreatures.prefix(3).joined(separator: " | "))")
        }

        if let lastPlayerIntentSummary, !lastPlayerIntentSummary.isEmpty {
            lines.append("Player Intent: \(lastPlayerIntentSummary)")
        }

        return lines.joined(separator: "\n")
    }

    private func generateCheckConsequence(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        check: SkillCheckDraft,
        result: CheckResult
    ) async throws -> String {
        if let search = check.searchResolution {
            switch search.finding {
            case .revealed:
                let target = search.revealedTarget?.name ?? "the prepared hidden feature"
                return "You reveal \(target). It is now available to inspect, but it remains unopened and you have not entered it. What do you do?"
            case .clueOnly:
                return "You notice an inconclusive seam, draft, or disturbance, but cannot confirm a hidden feature. What do you do?"
            case .notFound, .noPreparedTarget:
                return "You find no reliable sign of a hidden target in the searched area. No new threat or location is created. What do you do?"
            }
        }
        if let stakes = check.request.declaredStakes {
            let ordinaryOutcome = StakesOutcome(rawValue: result.outcome) ?? .failure
            let resolution = StakesResolver().resolve(
                roll: check.roll ?? 0,
                ordinaryOutcome: ordinaryOutcome,
                stakes: stakes,
                proposedMutations: []
            )
            logAgency(
                stage: "declared_stakes",
                message: "outcome=\(resolution.outcome.rawValue) allowed=\(stakes.allowedMutations.map(\.rawValue).joined(separator: ",")) forbidden=\(stakes.forbiddenMutations.map(\.rawValue).joined(separator: ","))"
            )
            return "\(resolution.consequence) What do you do?"
        }
        if check.sourceKind == "trap_search", check.sourceTrapId == nil {
            switch result.outcome {
            case "success":
                return "You don’t spot any traps or tripwires here."
            case "partial_success":
                return "You notice a few suspicious details, but you can’t confirm any specific trap."
            default:
                return "You don’t find anything, but you can’t be sure the area is safe."
            }
        }
        var prompt = """
        Provide a brief consequence (1-2 sentences) based on the check outcome.
        Keep the story moving and stay grounded.
        If the d20 roll is a natural 20, make it an extraordinary success.
        If the d20 roll is a natural 1, make it a significant failure.
        Do not advance the player into a new location or scene unless they explicitly said so.
        Do not describe the player taking actions they did not state.
        Do not echo the player's action back.
        If the outcome is success, name the concrete clue, object, feature, route, NPC reaction, or changed condition discovered.
        If the outcome is partial_success, name both the progress and the specific cost, pressure, warning sign, or complication.
        If the outcome is failure, name the immediate consequence or visible danger now present.
        Never use vague placeholders like "several clues", "potential risks", "valuable information", or "closer to the goal" without naming what exists in the scene.
        End with a hook the player can respond to.

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

        if let partial = check.request.partialSuccessOutcome, !partial.isEmpty {
            prompt += "\nPartial success: \(partial)"
        }

        let response = try await session.respond(to: budgetedPrompt(prompt, label: "check_consequence"))
        let draft = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await repairVagueNarrationIfNeeded(
            session: session,
            context: context,
            playerText: check.playerAction,
            draft: draft,
            focus: "check consequence"
        )
    }

    private func resolveTravelCheck(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        draftIndex: Int,
        roll: Int,
        modifier: Int,
        campaign: Campaign,
        modelContext: ModelContext
    ) async throws -> String {
        let total = roll + modifier
        let outcome = travelOutcome(for: total)
        checkDrafts[draftIndex].total = total
        checkDrafts[draftIndex].outcome = outcome.outcome
        logAgency(stage: "resolution", message: "Travel check => \(outcome.outcome) total \(total) travel_mod=\(outcome.modifier)")

        let travelOutcomeResult = resolveTravelEventIfNeeded(
            playerText: checkDrafts[draftIndex].playerAction,
            intentSummary: lastPlayerIntentSummary,
            campaign: campaign,
            modelContext: modelContext,
            travelModifier: outcome.modifier
        )

        if let request = checkDrafts[draftIndex].travelRequest {
            let stakesOutcome: StakesOutcome
            if roll == 20 {
                stakesOutcome = .criticalSuccess
            } else if roll == 1 {
                stakesOutcome = .criticalFailure
            } else {
                stakesOutcome = StakesOutcome(rawValue: outcome.outcome) ?? .failure
            }
            let procedureResolution = TravelProcedureEngine().resolve(request, route: .roll(stakesOutcome))
            dispatchProcedureEvent(
                CampaignEventFactory().travelResolutionEvent(
                    request: request,
                    resolution: procedureResolution,
                    sceneId: campaign.activeSceneId
                ),
                campaign: campaign
            )
            logAgency(
                stage: "procedure_state",
                message: "travel progress=\(procedureResolution.progress) time=\(procedureResolution.timeHours) exposure=\(procedureResolution.exposure) delay=\(procedureResolution.delay) encounter_risk=\(procedureResolution.encounterRisk)"
            )
        }

        let consequence = try await generateTravelOutcomeNarration(
            session: session,
            context: context,
            roll: roll,
            modifier: modifier,
            total: total,
            outcome: outcome.outcome,
            travelEvent: travelOutcomeResult,
            campaign: campaign
        )
        checkDrafts[draftIndex].consequence = consequence

        let outcomeText = outcome.outcome.replacingOccurrences(of: "_", with: " ")
        let gmText = "Travel check: \(roll) + \(modifier) = \(total). \(outcomeText.capitalized). \(consequence)"
        if travelOutcomeResult?.tableId == "travel_event" {
            await captureWorldDelta(from: gmText, session: session, context: context, playerText: checkDrafts[draftIndex].playerAction, campaign: campaign)
        }
        return gmText
    }

    private func resolveCreativeCheck(
        session: LanguageModelSession,
        draftIndex: Int,
        roll: Int,
        campaign: Campaign
    ) async throws -> String {
        let keywords = CreativeKeywordStore().loadBundledKeywords()
        let seed = campaign.rngSeed ?? 0xC0FFEE
        let sequence = campaign.eventLog?.count ?? 0
        let creative = CreativeSolutionsEngine().resolve(
            action: checkDrafts[draftIndex].playerAction,
            roll: roll,
            keywords: keywords,
            seed: seed,
            sequence: sequence
        )
        dispatchProcedureEvent(
            CampaignEventFactory().creativeResolutionEvent(creative, sceneId: campaign.activeSceneId),
            campaign: campaign
        )
        checkDrafts[draftIndex].total = roll
        checkDrafts[draftIndex].outcome = creative.valence.rawValue
        checkDrafts[draftIndex].consequence = creative.engineEffect
        logAgency(
            stage: "procedure_state",
            message: "creative roll=\(roll) keywords=\(creative.keywords.joined(separator: ",")) kind=\(creative.effectKind.rawValue) valence=\(creative.valence.rawValue) mutations=\(creative.mutations.map(\.rawValue).joined(separator: ","))"
        )

        let prompt = """
        Render one short sensory sentence for this engine-approved creative RPG effect.
        Use the listed keywords as imagery. Do not add an NPC, enemy, location, treasure, player action, feeling, decision, or mechanical effect.
        Do not alter the approved effect. Do not use "you decide" or describe another player action.
        Keywords: \(creative.keywords.joined(separator: ", "))
        Approved effect: \(creative.engineEffect)
        """
        let response = try await session.respond(to: budgetedPrompt(prompt, label: "creative_flavor"))
        let flavor = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFlavor = flavor.isEmpty || violatesAgencyBoundary(flavor) ? "The surroundings answer through \(creative.keywords.joined(separator: " and "))." : flavor
        return "Creative solution: straight d20 = \(roll). \(creative.engineEffect) \(safeFlavor) What do you do?"
    }

    private func generateTravelOutcomeNarration(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        roll: Int,
        modifier: Int,
        total: Int,
        outcome: String,
        travelEvent: TableRollOutcome?,
        campaign: Campaign
    ) async throws -> String {
        let canonicalWeather = CampaignAuthorityStateStore().load(from: campaign)?.weather?.lowercased()
        let hasStorm = canonicalWeather?.contains("storm") == true || canonicalWeather?.contains("rain") == true
        let weatherCost = hasStorm ? "the rain soaks through your outer layers and the cold starts to matter" : "the route takes longer than expected"
        let eventLine: String
        if let travelEvent, travelEvent.tableId == "travel_event" {
            eventLine = "The engine also confirms a travel event: \(travelEvent.result)"
        } else {
            eventLine = "No encounter appears on the road yet."
        }

        if roll == 20 {
            return "You keep the route cleanly and gain ground despite the conditions. \(eventLine) The next clear choice is whether to press on, look for shelter, or pause to check the road. What do you do?"
        }
        if roll == 1 {
            return "The journey turns against you: \(weatherCost), and the road becomes hard to read. \(eventLine) You need to choose between stopping for shelter, backtracking to a clearer marker, or pushing forward at increased risk. What do you do?"
        }

        switch outcome {
        case "success":
            return "You stay oriented and make real progress. \(eventLine) Ahead, the road dips toward a darker stretch where runoff crosses the path. What do you do?"
        case "partial_success":
            return "You keep the road, but \(weatherCost). \(eventLine) A shallow drainage cut and a wind-bent stand of brush offer the first possible shelter or scouting point. What do you do?"
        default:
            return "You lose the easiest line of travel, and \(weatherCost). \(eventLine) The immediate choice is to stop and reorient, search for shelter, or continue with increased risk. What do you do?"
        }
    }

    private func concreteAutomaticOutcome(_ outcome: String, playerText: String) -> String {
        let lower = playerText.lowercased()
        if lower.contains("look") || lower.contains("observe") || lower.contains("inspect") || lower.contains("search") {
            return "You can study the obvious details without pressure: the nearest useful feature, exit, or sign is clear enough to examine directly. What do you focus on?"
        }
        if lower.contains("talk") || lower.contains("ask") || lower.contains("say") {
            return "The conversation can proceed without a roll. What exactly do you say or ask?"
        }
        if lower.contains("move") || lower.contains("go") || lower.contains("walk") || lower.contains("head") {
            return "The route is open and nothing immediately blocks movement. Do you proceed, scout first, or pause to check the surroundings?"
        }
        return "The action is straightforward enough to proceed without a roll. What detail do you focus on next?"
    }

    private func repairVagueNarrationIfNeeded(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        draft: String,
        focus: String
    ) async throws -> String {
        guard shouldRepairNarration(draft, playerText: playerText) || violatesAgencyBoundary(draft) else {
            return draft
        }

        let prompt = """
        Rewrite this GM \(focus) so it is concrete and playable.
        Keep it to 1-3 short sentences.
        Do not repeat or quote the player's input.
        Do not narrate player choices, feelings, next actions, or hidden facts the character cannot perceive.
        Never say "you decide", "the party decides", "the player decides", "prompting them to", or "what you don't see".
        Do not say "several clues", "potential risks", "valuable information", "closer to the goal", or similar placeholders.
        Name 1-2 concrete facts in the scene: a clue, sound, mark, object, hazard, NPC reaction, exit, weather change, track, smell, or visible decision point.
        End with a clear action hook or "What do you do?"
        Preserve the same outcome; do not add a new roll.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Player: \(playerText)
        Draft: \(draft)

        Return only the rewritten GM text.
        """

        let response = try await session.respond(to: budgetedPrompt(prompt, label: "narration_repair"))
        let rewritten = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return rewritten.isEmpty ? draft : rewritten
    }

    private func shouldRepairNarration(_ text: String, playerText: String) -> Bool {
        let lower = text.lowercased()
        let vaguePhrases = [
            "several clues",
            "closer to their goal",
            "closer to your goal",
            "potential risks",
            "some potential risks",
            "relatively safe",
            "valuable information",
            "useful information",
            "important information",
            "hidden dangers",
            "secrets waiting",
            "what lies beyond the horizon",
            "mix of excitement and apprehension",
            "minor risk of encountering",
            "risk of encountering"
        ]
        if vaguePhrases.contains(where: { lower.contains($0) }) {
            return true
        }

        let normalizedPlayer = playerText
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if normalizedPlayer.count > 28,
           lower.contains(normalizedPlayer) {
            return true
        }

        return false
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func appendRollHighlight(for check: SkillCheckDraft, outcome: String, total: Int?) {
        if check.sourceKind == "travel_check" {
            return
        }
        let dc = check.request.dc ?? check.request.opponentDC ?? 10
        let totalText = total.map { " (Total \($0))" } ?? ""
        let cleanedOutcome = outcome.replacingOccurrences(of: "_", with: " ")
        let reasonText = check.request.reason.isEmpty ? "" : " Reason: \(check.request.reason)."
        let natMarker: String
        if let roll = check.roll {
            if roll == 1 {
                natMarker = " Nat 1."
            } else if roll == 20 {
                natMarker = " Nat 20."
            } else {
                natMarker = ""
            }
        } else {
            natMarker = ""
        }
        let highlight = "\(check.request.skillName) DC \(dc)\(totalText): \(cleanedOutcome).\(reasonText)\(natMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
        var existing = parseCommaList(rollHighlightsInput)
        let normalized = existing.map { $0.lowercased() }
        if !normalized.contains(highlight.lowercased()) {
            existing.append(highlight)
            rollHighlightsInput = existing.joined(separator: ", ")
        }
    }
}
