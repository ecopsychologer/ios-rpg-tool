import Foundation
import Combine
import FoundationModels
import SwiftData
import WorldState
import RPGEngine
import TableEngine

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
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        return gmText
                    }

                    if let roll = fallback.roll {
                        let modifier = fallback.modifier ?? (wantsAutoBonus(trimmed) ? computedSkillBonus(for: checkDrafts[index], campaign: campaign) : nil) ?? 0
                        checkDrafts[index].roll = roll
                        checkDrafts[index].modifier = modifier

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
                let travelDraft = travelCheckDraft(for: trimmed, campaign: campaign)
                checkDrafts.append(travelDraft)
                pendingCheckID = travelDraft.id
                let gmText = gmLineForTravelCheck(travelDraft.request)
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                return gmText
            }

            if actionKind == .auto, isMetaMessage(trimmed) {
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
        if !request.reason.isEmpty {
            line += " Reason: \(request.reason)."
        }
        line += " If you fail, \(request.stakes)"
        if let partialDC = request.partialSuccessDC, let partialText = request.partialSuccessOutcome, !partialText.isEmpty {
            line += " On a partial (DC \(partialDC)), \(partialText)"
        }
        line += " Include your modifier in the roll total, or say \"use my bonus\" if you want me to add it."
        if autoRollEnabled {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Want to attempt it?"
        }
        return line
    }

    private func gmLineForTravelCheck(_ request: CheckRequest) -> String {
        let skillName = request.skillName
        let ability = request.abilityOverride ?? engine.ruleset.defaultAbility(for: skillName) ?? "Ability"
        let abilityLine = "\(ability) (\(skillName))"
        var line = "Travel check: Who’s leading the journey? Give me a \(abilityLine) roll (or another skill you can justify)."
        line += " Higher rolls reduce the odds of trouble; low rolls increase risk."
        line += " Include your modifier in the roll total, or say \"use my bonus\" if you want me to add it."
        if autoRollEnabled {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Want to attempt it?"
        }
        return line
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
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: skillName,
            abilityOverride: nil,
            dc: nil,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "This roll shapes the odds of trouble on the journey.",
            partialSuccessDC: nil,
            partialSuccessOutcome: nil,
            reason: "Travel leadership check."
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
            sourceKind: "travel_check"
        )
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
                sourceKind: "trap_detection"
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
            sourceKind: "trap_search"
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
            _ = locationEngine.advanceAlongEdge(campaign: campaign, edge: edge, reason: reason)
            logAgency(stage: "movement", message: "Advance via edge: \(edge.type) (\(edge.label ?? "")) reason=\(reason)")
        } else {
            _ = locationEngine.advanceToNextNode(campaign: campaign, reason: reason)
            logAgency(stage: "movement", message: "Advance to next node reason=\(reason)")
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
            reason: reason
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

    private func shouldForeshadowLine() -> Bool {
        engine.rollD100() <= 15
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
                to: Prompt(prompt),
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
        - Use DC bands 5, 10, 15, 20, 25, 30.
        - Advantage for strong leverage; disadvantage for harsh conditions.
        - Provide a concrete, in-fiction reason for the chosen DC.
        Return a CheckRequestDraft.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Chaos Factor: \(context.chaosFactor)
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
            to: Prompt(makeCheckProposalPrompt(playerText: playerText, context: context)),
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
                let preface = intentSummary.map { "Got it: \($0). " } ?? ""
                let gmText = preface + gmLineForCheck(tunedRequest)
                interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
                return true
            }
            let outcome = checkDraft.content.autoOutcome?.isEmpty == false ? checkDraft.content.autoOutcome! : "success"
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + "No roll needed. Automatic outcome: \(outcome). Want to proceed?"
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
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + gmLineForCheck(tunedForced)
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
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + "Auto-roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(consequence)"
            interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            pendingCheckID = nil
            return true
        }

        let preface = intentSummary.map { "Got it: \($0). " } ?? ""
        let gmText = preface + gmLineForCheck(request)
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
            Keep it short and practical. Confirm any changes before assuming they apply.
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
            prompt += "\nEnd with a short question like \"What do you do?\""
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
        
        Build 1-4 segments. Use speaker=gm for narration and prompts.
        Use speaker=npc only if an NPC is explicitly present in the context.
        Never use speaker=player. Dialogue should only appear in dialogue segments.
        """
        prompt += "\nReturn a NarrationPlanDraft."

        let response = try await session.respond(to: Prompt(prompt), generating: NarrationPlanDraft.self)
        let content = renderNarrationPlan(response.content)
        if violatesAgencyBoundary(content) {
            logAgency(stage: "agency_violation", message: "Rewriting narration to avoid assumed player action.")
            return try await rewriteForAgency(
                session: session,
                context: context,
                playerText: playerText,
                draft: content
            )
        }
        return content
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
        let response = try await session.respond(to: Prompt(prompt))
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
        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func violatesAgencyBoundary(_ text: String) -> Bool {
        let lower = " " + text.lowercased()
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
        Keep it to 1-3 short paragraphs, end with a short question.

        Player: \(playerText)
        Draft response: \(draft)

        Return only the rewritten response.
        """
        let response = try await session.respond(to: Prompt(prompt))
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
        Include a short reference to the reason and the stakes in your response.

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

        if shouldForeshadowLine() {
            prompt += "\nAdd a second line starting with \"What you don't see is ...\" about a subtle consequence."
        }

        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

        let consequence = try await generateTravelOutcomeNarration(
            session: session,
            context: context,
            roll: roll,
            modifier: modifier,
            total: total,
            outcome: outcome.outcome,
            travelEvent: travelOutcomeResult
        )
        checkDrafts[draftIndex].consequence = consequence

        let outcomeText = outcome.outcome.replacingOccurrences(of: "_", with: " ")
        return "Travel check: \(roll) + \(modifier) = \(total). \(outcomeText.capitalized). \(consequence)"
    }

    private func generateTravelOutcomeNarration(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        roll: Int,
        modifier: Int,
        total: Int,
        outcome: String,
        travelEvent: TableRollOutcome?
    ) async throws -> String {
        var prompt = """
        Summarize the travel check outcome in 1-3 sentences.
        Higher rolls mean safer travel; lower rolls increase risk.
        Do not mention DCs, modifiers, or internal table rolls.
        If the roll is a natural 20, make it an extraordinary outcome.
        If the roll is a natural 1, make it a significant failure.
        """
        if let travelEvent {
            prompt += "\nTravel result: \(travelEvent.result)"
        } else {
            prompt += "\nTravel result: No encounter."
        }
        prompt += """

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Outcome: \(outcome)
        Roll: \(roll) (total \(total))
        """
        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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
