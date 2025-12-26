import Foundation
import RPGEngine

public struct NarratorAgentPipeline {
    public init() {}

    public func classifyMessagePrompt(playerText: String, context: NarrationContextPacket) -> String {
        NarratorPrompts().makeIntentCategoryPrompt(playerText: playerText, context: context)
    }

    public func extractPlayerIntentPrompt(
        playerText: String,
        context: NarrationContextPacket,
        gmRunsCompanionsEnabled: Bool
    ) -> String {
        NarratorPrompts().makePlayerIntentPrompt(
            playerText: playerText,
            context: context,
            gmRunsCompanionsEnabled: gmRunsCompanionsEnabled
        )
    }

    public func needsClarification(_ intent: PlayerIntentDraft) -> Bool {
        let verb = intent.verb.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = intent.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return verb.isEmpty || summary.isEmpty
    }

    public func buildAdjudicationRequest(
        intent: PlayerIntent,
        checkRequest: CheckRequest?,
        fateLikelihood: FateLikelihood?,
        stakes: String,
        reason: String
    ) -> GMAdjudicationRequest {
        let kind: AdjudicationKind
        if checkRequest != nil {
            kind = .skillCheck
        } else if fateLikelihood != nil {
            kind = .fateOracle
        } else {
            kind = .none
        }

        return GMAdjudicationRequest(
            kind: kind,
            checkRequest: checkRequest,
            fateLikelihood: fateLikelihood,
            stakes: stakes,
            reason: reason,
            requiredRolls: []
        )
    }

    public func validateNarrationDoesNotAssumePlayerAction(_ text: String) -> Bool {
        let lower = " " + text.lowercased()
        let forbidden = ["you decide", "you charge", "you attack", "you cast", "you open", "you search"]
        return !forbidden.contains { lower.contains($0) }
    }
}
