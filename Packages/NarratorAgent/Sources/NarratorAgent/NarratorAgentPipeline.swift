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

    public func approvedRenderingPrompt(_ packet: ApprovedNarrationPacket) -> String {
        var lines = [
            "Render a concise solo-RPG GM response using only the approved facts below.",
            "Do not add names, entities, locations, threats, treasure, player motives, actions, or mechanics.",
            "Do not state hidden facts. Do not choose an action or emotion for the player.",
            "Use one or two short paragraphs followed by the exact approved prompt."
        ]
        if packet.directAnswer != .notApplicable {
            lines.append("Direct answer: \(packet.directAnswer.rawValue)")
        }
        if !packet.renderingBeats.isEmpty {
            lines.append("Approved rendering facts:")
            lines.append(contentsOf: packet.renderingBeats.map { "- \($0)" })
        }
        if !packet.approvedFactNames.isEmpty {
            lines.append("Approved fact names: \(packet.approvedFactNames.joined(separator: ", "))")
        }
        lines.append("End exactly with: \(packet.nextPrompt)")
        return lines.joined(separator: "\n")
    }

    public func renderDeterministicFallback(_ packet: ApprovedNarrationPacket) -> String {
        var parts: [String] = []
        if packet.directAnswer != .notApplicable {
            switch packet.directAnswer {
            case .yes: parts.append("Yes.")
            case .no: parts.append("No.")
            case .unknown: parts.append("You do not know yet.")
            case .checkRequired: parts.append("You can check.")
            case .notApplicable: break
            }
        }
        if !packet.renderingBeats.isEmpty {
            parts.append(packet.renderingBeats.joined(separator: " "))
        }
        parts.append(packet.nextPrompt)
        return parts.joined(separator: "\n\n")
    }
}
