import Foundation
import FoundationModels

public enum IntentCategory: String, CaseIterable, Codable, Sendable {
    case playerIntent = "player_intent"
    case playerQuestion = "player_question"
    case roleplayDialogue = "roleplay_dialogue"
    case gmCommand = "gm_command"
    case unclear
}

extension IntentCategory {
    public static func from(name: String?) -> IntentCategory? {
        guard let name else { return nil }
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return IntentCategory.allCases.first { $0.rawValue == normalized }
    }
}

public enum PlayerRequestedMode: String, CaseIterable, Codable, Sendable {
    case askBeforeRolling = "ask_before_rolling"
    case autoResolve = "auto_resolve"
    case narrateOnly = "narrate_only"
}

extension PlayerRequestedMode {
    public static func from(name: String?) -> PlayerRequestedMode? {
        guard let name else { return nil }
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return PlayerRequestedMode.allCases.first { $0.rawValue == normalized }
    }
}

public struct PlayerIntent: Codable, Sendable {
    public let verb: String
    public let target: String?
    public let approach: String?
    public let partyInvolved: [String]
    public let requestedMode: PlayerRequestedMode
    public let summary: String
    public let rawText: String

    public init(
        verb: String,
        target: String? = nil,
        approach: String? = nil,
        partyInvolved: [String] = [],
        requestedMode: PlayerRequestedMode = .askBeforeRolling,
        summary: String,
        rawText: String
    ) {
        self.verb = verb
        self.target = target
        self.approach = approach
        self.partyInvolved = partyInvolved
        self.requestedMode = requestedMode
        self.summary = summary
        self.rawText = rawText
    }
}

public enum AdjudicationKind: String, CaseIterable, Codable, Sendable {
    case skillCheck = "skill_check"
    case contestedCheck = "contested_check"
    case fateOracle = "fate_oracle"
    case attack
    case save
    case none
}

public struct GMAdjudicationRequest: Sendable {
    public let kind: AdjudicationKind
    public let checkRequest: CheckRequest?
    public let fateLikelihood: FateLikelihood?
    public let stakes: String
    public let reason: String
    public let requiredRolls: [String]

    public init(
        kind: AdjudicationKind,
        checkRequest: CheckRequest? = nil,
        fateLikelihood: FateLikelihood? = nil,
        stakes: String,
        reason: String,
        requiredRolls: [String] = []
    ) {
        self.kind = kind
        self.checkRequest = checkRequest
        self.fateLikelihood = fateLikelihood
        self.stakes = stakes
        self.reason = reason
        self.requiredRolls = requiredRolls
    }
}

public enum ResolutionOutcome: String, CaseIterable, Codable, Sendable {
    case success
    case partialSuccess = "partial_success"
    case failure
    case yes
    case no
    case mixed
    case unknown
}

public struct ResolutionResult: Sendable {
    public let outcome: ResolutionOutcome
    public let rollTotal: Int?
    public let rollDetails: String?
    public let consequence: String
    public let followUpPrompt: String?
    public let changedEntityIds: [UUID]

    public init(
        outcome: ResolutionOutcome,
        rollTotal: Int? = nil,
        rollDetails: String? = nil,
        consequence: String,
        followUpPrompt: String? = nil,
        changedEntityIds: [UUID] = []
    ) {
        self.outcome = outcome
        self.rollTotal = rollTotal
        self.rollDetails = rollDetails
        self.consequence = consequence
        self.followUpPrompt = followUpPrompt
        self.changedEntityIds = changedEntityIds
    }
}

public struct NarrationPlan: Sendable {
    public let narrationText: String
    public let questionsToPlayer: [String]
    public let options: [String]
    public let ruleSummary: String?

    public init(
        narrationText: String,
        questionsToPlayer: [String] = [],
        options: [String] = [],
        ruleSummary: String? = nil
    ) {
        self.narrationText = narrationText
        self.questionsToPlayer = questionsToPlayer
        self.options = options
        self.ruleSummary = ruleSummary
    }
}

public struct AgencyLogEntry: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let stage: String
    public let message: String

    public init(stage: String, message: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.stage = stage
        self.message = message
    }
}

@Generable
public struct IntentCategoryDraft {
    @Guide(description: "Category: player_intent, player_question, roleplay_dialogue, gm_command, unclear")
    public let category: String

    @Guide(description: "Short reason for the classification")
    public let reason: String
}

@Generable
public struct PlayerIntentDraft {
    @Guide(description: "Verb describing the player's intent, like sneak, search, persuade")
    public let verb: String

    @Guide(description: "Target of the action, if any")
    public let target: String?

    @Guide(description: "Approach or method, if stated")
    public let approach: String?

    @Guide(description: "Who is acting (player, party, or named character)")
    public let partyInvolved: [String]

    @Guide(description: "Requested mode: ask_before_rolling, auto_resolve, narrate_only")
    public let requestedMode: String

    @Guide(description: "One-line restatement of the intent")
    public let summary: String
}

@Generable
public struct NarrationPlanDraft {
    @Guide(description: "Narration text that does not assume player actions")
    public let narrationText: String

    @Guide(description: "One or two short questions for the player")
    public let questionsToPlayer: [String]

    @Guide(description: "Optional suggested options")
    public let options: [String]

    @Guide(description: "Optional rule summary line")
    public let ruleSummary: String?
}
