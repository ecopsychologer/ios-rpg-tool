import Foundation
import WorldState

public enum CampaignStateQuery: String, Codable, Sendable {
    case hiddenDoor = "hidden_door"
    case visiblePeople = "visible_people"
    case knownImmediateThreats = "known_immediate_threats"
    case metaThreatSummary = "meta_threat_summary"
}

public struct CampaignStateQueryResult: Sendable {
    public let directAnswer: NarratorDirectAnswer
    public let playerVisibleFacts: [String]
    public let checkRequest: CheckRequest?
    public let proposedEvents: [CampaignEvent]

    public init(
        directAnswer: NarratorDirectAnswer,
        playerVisibleFacts: [String],
        checkRequest: CheckRequest? = nil,
        proposedEvents: [CampaignEvent] = []
    ) {
        self.directAnswer = directAnswer
        self.playerVisibleFacts = playerVisibleFacts
        self.checkRequest = checkRequest
        self.proposedEvents = proposedEvents
    }
}

public struct CampaignStateQueryEngine: Sendable {
    public init() {}

    public func answer(_ query: CampaignStateQuery, campaign: Campaign) -> CampaignStateQueryResult {
        switch query {
        case .hiddenDoor:
            return hiddenDoorAnswer(campaign: campaign)
        case .visiblePeople:
            return visiblePeopleAnswer(campaign: campaign)
        case .knownImmediateThreats, .metaThreatSummary:
            return threatSummary(campaign: campaign, isMeta: query == .metaThreatSummary)
        }
    }

    private func hiddenDoorAnswer(campaign: Campaign) -> CampaignStateQueryResult {
        guard let location = activeLocation(campaign), let node = activeNode(campaign, location: location) else {
            return CampaignStateQueryResult(
                directAnswer: .unknown,
                playerVisibleFacts: ["There is no active area to inspect."]
            )
        }

        let knownFeatures = (node.features ?? []).filter { feature in
            let text = ([feature.name, feature.summary, feature.category] + (feature.tags ?? [])).joined(separator: " ").lowercased()
            return text.contains("door") && (text.contains("discover") || !text.contains("hidden"))
        }
        let knownEdges = (location.edges ?? []).filter { edge in
            guard edge.fromNodeId == nil || edge.fromNodeId == node.id else { return false }
            return [edge.type, edge.label ?? ""].joined(separator: " ").lowercased().contains("door")
        }
        if let feature = knownFeatures.first {
            return CampaignStateQueryResult(
                directAnswer: .yes,
                playerVisibleFacts: ["\(feature.name): \(feature.summary)"]
            )
        }
        if let edge = knownEdges.first {
            let label = edge.label?.isEmpty == false ? edge.label! : edge.type
            return CampaignStateQueryResult(
                directAnswer: .yes,
                playerVisibleFacts: ["A known \(label) connects from this area."]
            )
        }

        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: "Investigation",
            abilityOverride: nil,
            dc: 15,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "Visible signs remain inconclusive.",
            partialSuccessDC: 10,
            partialSuccessOutcome: "You notice an odd seam or draft but cannot confirm a door.",
            reason: "A close search may identify an already prepared hidden feature.",
            declaredStakes: DeclaredStakes(
                success: "Any existing hidden exit in the searched area is revealed.",
                partial: "You notice an inconclusive seam, draft, or disturbance.",
                failure: "You find no reliable sign of a hidden exit.",
                criticalSuccess: "Any existing hidden exit is revealed with one useful operational detail.",
                criticalFailure: "You find no reliable sign; no new trap or threat is created.",
                allowedMutations: [.clue, .sceneFact],
                forbiddenMutations: [.location, .npc, .treasure, .quest, .playerChoice]
            )
        )
        return CampaignStateQueryResult(
            directAnswer: .checkRequired,
            playerVisibleFacts: ["No hidden door is currently known here."],
            checkRequest: request
        )
    }

    private func visiblePeopleAnswer(campaign: Campaign) -> CampaignStateQueryResult {
        let visible = campaign.npcs.filter { npc in
            npc.currentLocationId == campaign.activeLocationId && npc.partyStatus != "hidden"
        }
        if visible.isEmpty {
            return CampaignStateQueryResult(directAnswer: .no, playerVisibleFacts: ["No person is visible here."])
        }
        return CampaignStateQueryResult(
            directAnswer: .yes,
            playerVisibleFacts: visible.map { "\($0.name) is visible here." }
        )
    }

    private func threatSummary(campaign: Campaign, isMeta: Bool) -> CampaignStateQueryResult {
        var facts: [String] = []
        if let weather = CampaignAuthorityStateStore().load(from: campaign)?.weather {
            facts.append("Current weather pressure: \(weather).")
        }
        if let location = activeLocation(campaign), let node = activeNode(campaign, location: location) {
            facts.append(contentsOf: (node.traps ?? []).filter { $0.state == "revealed" || $0.state == "disarmed" }.map {
                "Known trap: \($0.name) (\($0.state))."
            })
            facts.append(contentsOf: (node.features ?? []).filter { feature in
                let tags = (feature.tags ?? []).map { $0.lowercased() }
                return tags.contains("hazard") || tags.contains("threat")
            }.map { "Known hazard: \($0.name)." })
        }
        if facts.isEmpty { facts = ["No immediate threat is currently confirmed."] }
        return CampaignStateQueryResult(
            directAnswer: isMeta ? .notApplicable : .unknown,
            playerVisibleFacts: facts
        )
    }

    private func activeLocation(_ campaign: Campaign) -> LocationEntity? {
        guard let id = campaign.activeLocationId else { return nil }
        return campaign.locations?.first { $0.id == id }
    }

    private func activeNode(_ campaign: Campaign, location: LocationEntity) -> LocationNode? {
        guard let id = campaign.activeNodeId else { return nil }
        return location.nodes?.first { $0.id == id }
    }
}

public enum NarratorOutputViolation: String, Hashable, Sendable {
    case directAnswerNotFirst = "direct_answer_not_first"
    case impliedAllies = "implied_allies"
    case sceneContamination = "scene_contamination"
    case missingDecisionPrompt = "missing_decision_prompt"
}

public enum NarrationEnvironment: String, Sendable {
    case outdoors
    case indoors
    case unknown
}

public struct NarratorOutputContext: Sendable {
    public let isSolo: Bool
    public let presentAllyCount: Int
    public let environment: NarrationEnvironment
    public let hasEstablishedBuilding: Bool

    public init(isSolo: Bool, presentAllyCount: Int, environment: NarrationEnvironment, hasEstablishedBuilding: Bool) {
        self.isSolo = isSolo
        self.presentAllyCount = presentAllyCount
        self.environment = environment
        self.hasEstablishedBuilding = hasEstablishedBuilding
    }

    public static let outdoorSolo = NarratorOutputContext(
        isSolo: true,
        presentAllyCount: 0,
        environment: .outdoors,
        hasEstablishedBuilding: false
    )
}

public struct NarratorOutputValidationResult: Sendable {
    public let violations: [NarratorOutputViolation]
    public var isValid: Bool { violations.isEmpty }
}

public struct NarratorOutputContractValidator: Sendable {
    public init() {}

    public func validate(
        _ text: String,
        packet: ApprovedNarrationPacket,
        context: NarratorOutputContext
    ) -> NarratorOutputValidationResult {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        var violations: [NarratorOutputViolation] = []

        if let required = directAnswerPrefix(packet.directAnswer), !lower.hasPrefix(required) {
            violations.append(.directAnswerNotFirst)
        }
        if context.isSolo, context.presentAllyCount == 0, impliesPresentAllies(lower) {
            violations.append(.impliedAllies)
        }
        if context.environment == .outdoors, !context.hasEstablishedBuilding,
           ["window", "windowsill", "windowpane"].contains(where: lower.contains) {
            violations.append(.sceneContamination)
        }
        if !clean.hasSuffix(packet.nextPrompt) {
            violations.append(.missingDecisionPrompt)
        }
        return NarratorOutputValidationResult(violations: Array(Set(violations)))
    }

    private func directAnswerPrefix(_ answer: NarratorDirectAnswer) -> String? {
        switch answer {
        case .yes: return "yes."
        case .no: return "no."
        case .unknown: return "you do not know yet."
        case .checkRequired: return "you can check."
        case .notApplicable: return nil
        }
    }

    private func impliesPresentAllies(_ lower: String) -> Bool {
        let allowedAbsence = ["no companions", "no party members", "party size is 1", "party size: 1"]
        if allowedAbsence.contains(where: lower.contains) { return false }
        return ["the party", "your companions", "the group", "your allies"].contains(where: lower.contains)
    }
}

public enum PlayerPromptMode: String, Codable, Sendable {
    case openTable = "open_table"
    case guided
}

public struct PlayerPromptComposer: Sendable {
    public init() {}

    public func prompt(mode: PlayerPromptMode = .openTable, suggestions: [String] = []) -> String {
        guard mode == .guided else { return "What do you do?" }
        let choices = suggestions.prefix(3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        guard !choices.isEmpty else { return "What do you do?" }
        let joined: String
        switch choices.count {
        case 1: joined = choices[0]
        case 2: joined = "\(choices[0]) or \(choices[1])"
        default: joined = "\(choices[0]), \(choices[1]), or \(choices[2])"
        }
        return "You could \(joined) - or try something else. What do you do?"
    }
}

public enum NarrationFailureAction: String, Equatable, Sendable {
    case retry
    case fallback
}

public struct NarrationFailurePolicy: Sendable {
    public let maximumRetries: Int

    public init(maximumRetries: Int = 1) {
        self.maximumRetries = max(0, maximumRetries)
    }

    public func action(afterValidationFailures failures: Int) -> NarrationFailureAction {
        failures <= maximumRetries ? .retry : .fallback
    }

    public func safeFallback(knownState: [String]) -> String {
        let facts = knownState.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let state = facts.isEmpty ? "no additional facts" : facts.joined(separator: "; ")
        return "The narrator could not safely add detail. Known state: \(state). What do you do?"
    }
}
