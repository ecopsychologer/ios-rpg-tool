import Foundation
import FoundationModels
import WorldState

public enum NarratorResponsePurpose: String, CaseIterable, Codable, Sendable {
    case sceneResponse = "scene_response"
    case directQuestion = "direct_question"
    case metaSummary = "meta_summary"
    case checkConsequence = "check_consequence"
    case clarification

    public static func from(_ value: String) -> NarratorResponsePurpose {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first(where: { $0.rawValue == key }) ?? .sceneResponse
    }
}

public enum NarratorDirectAnswer: String, CaseIterable, Codable, Sendable {
    case yes
    case no
    case unknown
    case checkRequired = "check_required"
    case notApplicable = "not_applicable"

    public static func from(_ value: String) -> NarratorDirectAnswer {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first(where: { $0.rawValue == key }) ?? .notApplicable
    }
}

@Generable
public struct NarratorRenderBeatDraft {
    @Guide(description: "A concrete player-visible fact or rendering instruction, not an unapproved invention")
    public let text: String

    @Guide(description: "Names of proposed deltas this beat depends on")
    public let relatedProposalNames: [String]

    public init(text: String, relatedProposalNames: [String] = []) {
        self.text = text
        self.relatedProposalNames = relatedProposalNames
    }
}

@Generable
public struct NarratorTurnDraft {
    @Guide(description: "Purpose: scene_response, direct_question, meta_summary, check_consequence, or clarification")
    public let responsePurpose: String

    @Guide(description: "Direct answer: yes, no, unknown, check_required, or not_applicable")
    public let directAnswer: String

    @Guide(description: "Ordered concrete facts and sensory rendering instructions")
    public let renderingBeats: [NarratorRenderBeatDraft]

    @Guide(description: "Open prompt or focused clarification question")
    public let nextPrompt: String

    @Guide(description: "Typed world-state proposals; these are not authoritative until engine validation")
    public let proposedDeltas: [WorldEntityChangeDraft]

    public init(
        responsePurpose: String,
        directAnswer: String,
        renderingBeats: [NarratorRenderBeatDraft],
        nextPrompt: String,
        proposedDeltas: [WorldEntityChangeDraft]
    ) {
        self.responsePurpose = responsePurpose
        self.directAnswer = directAnswer
        self.renderingBeats = renderingBeats
        self.nextPrompt = nextPrompt
        self.proposedDeltas = proposedDeltas
    }
}

public struct ApprovedNarrationPacket: Sendable {
    public let responsePurpose: NarratorResponsePurpose
    public let directAnswer: NarratorDirectAnswer
    public let renderingBeats: [String]
    public let nextPrompt: String
    public let approvedFactNames: [String]

    public init(
        responsePurpose: NarratorResponsePurpose,
        directAnswer: NarratorDirectAnswer,
        renderingBeats: [String],
        nextPrompt: String,
        approvedFactNames: [String]
    ) {
        self.responsePurpose = responsePurpose
        self.directAnswer = directAnswer
        self.renderingBeats = renderingBeats
        self.nextPrompt = nextPrompt
        self.approvedFactNames = approvedFactNames
    }
}

public struct NarratorTurnValidationResult {
    public let approvedPacket: ApprovedNarrationPacket
    public let acceptedChanges: [WorldEntityChangeDraft]
    public let rejectedChanges: [RejectedWorldDelta]

    public init(
        approvedPacket: ApprovedNarrationPacket,
        acceptedChanges: [WorldEntityChangeDraft],
        rejectedChanges: [RejectedWorldDelta]
    ) {
        self.approvedPacket = approvedPacket
        self.acceptedChanges = acceptedChanges
        self.rejectedChanges = rejectedChanges
    }
}

public struct NarratorTurnValidator {
    public init() {}

    public func validate(_ draft: NarratorTurnDraft, campaign: Campaign) -> NarratorTurnValidationResult {
        var accepted: [WorldEntityChangeDraft] = []
        var rejected: [RejectedWorldDelta] = []

        for change in draft.proposedDeltas {
            if let reason = rejectionReason(for: change, campaign: campaign) {
                rejected.append(RejectedWorldDelta(name: change.name, reason: reason))
            } else {
                accepted.append(change)
            }
        }

        let rejectedNames = Set(rejected.map { key($0.name) })
        let safeBeats = draft.renderingBeats.compactMap { beat -> String? in
            let text = beat.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let dependencies = Set(beat.relatedProposalNames.map(key))
            guard dependencies.isDisjoint(with: rejectedNames) else { return nil }
            guard !rejectedNames.contains(where: { !($0.isEmpty) && key(text).contains($0) }) else { return nil }
            guard !violatesPlayerAuthority(text) else { return nil }
            return text
        }

        let packet = ApprovedNarrationPacket(
            responsePurpose: NarratorResponsePurpose.from(draft.responsePurpose),
            directAnswer: NarratorDirectAnswer.from(draft.directAnswer),
            renderingBeats: safeBeats,
            nextPrompt: safePrompt(draft.nextPrompt),
            approvedFactNames: accepted.map(\.name)
        )
        return NarratorTurnValidationResult(
            approvedPacket: packet,
            acceptedChanges: accepted,
            rejectedChanges: rejected
        )
    }

    private func rejectionReason(for change: WorldEntityChangeDraft, campaign: Campaign) -> String? {
        let source = key(change.source)
        let visibility = key(change.visibility)
        let durability = key(change.durability)
        let approval = key(change.approval)
        let operation = key(change.operation)
        let type = key(change.entityType)
        let allowedSources = ["gm_live", "engine", "oracle", "table_roll", "player_confirmed"]
        let allowedVisibilities = ["player_visible", "hidden_gm", "mechanical_only"]
        let allowedDurabilities = ["scene", "session", "campaign"]
        let allowedApprovals = ["automatic", "engine_required", "player_required"]

        guard allowedSources.contains(source), source != "summary" else {
            return "Unsupported or read-only proposal source."
        }
        guard allowedVisibilities.contains(visibility), allowedDurabilities.contains(durability), allowedApprovals.contains(approval) else {
            return "Invalid proposal authority metadata."
        }
        guard ["create", "update", "reference"].contains(operation) else {
            return "Unsupported proposal operation."
        }
        guard WorldDeltaEntityKind(rawValue: type) != nil else {
            return "Unsupported entity type."
        }
        if type == WorldDeltaEntityKind.npc.rawValue,
           ["unknown character", "unknown npc", "unseen adversary", "unseen enemy"].contains(key(change.name)) {
            return "Generic unknowns must be represented by an engine-owned clue or clock."
        }

        if operation == "update" || operation == "reference" {
            return entityExists(type: type, name: change.name, campaign: campaign)
                ? nil
                : "Updates and references require an existing canonical entity."
        }

        if source == "engine" || source == "oracle" || source == "table_roll" || source == "player_confirmed" {
            return nil
        }

        if type == WorldDeltaEntityKind.locationFeature.rawValue,
           visibility == "player_visible",
           durability == "scene",
           key(change.discoveryStatus) == "discovered",
           locationBindingMatches(change, campaign: campaign) {
            return nil
        }

        return "Live narrator creation requires a separate engine, oracle, table, or player-confirmed authority event."
    }

    private func entityExists(type: String, name: String, campaign: Campaign) -> Bool {
        let target = key(name)
        switch WorldDeltaEntityKind(rawValue: type) {
        case .npc:
            return campaign.npcs.contains { key($0.name) == target }
        case .location:
            return (campaign.locations ?? []).contains { key($0.name) == target }
        case .locationFeature:
            return (campaign.locations ?? []).flatMap { $0.nodes ?? [] }.flatMap { $0.features ?? [] }.contains { key($0.name) == target }
        case .item:
            return campaign.items.contains { key($0.name) == target }
        case .creature:
            return campaign.creatures.contains { key($0.name) == target }
        case .lore:
            return campaign.worldLore.contains { key($0.title) == target }
        case nil:
            return false
        }
    }

    private func locationBindingMatches(_ change: WorldEntityChangeDraft, campaign: Campaign) -> Bool {
        guard let activeID = campaign.activeLocationId,
              let active = campaign.locations?.first(where: { $0.id == activeID }) else { return false }
        let binding = change.locationBinding ?? change.relatedLocationName ?? ""
        return key(binding) == key(active.name)
    }

    private func violatesPlayerAuthority(_ text: String) -> Bool {
        let lower = key(text)
        let forbidden = [
            "you decide", "you choose", "you feel compelled", "you can't help but", "you can’t help but",
            "the player decides", "the party decides", "the player feels"
        ]
        return forbidden.contains(where: lower.contains)
    }

    private func safePrompt(_ value: String) -> String {
        let prompt = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.isEmpty || violatesPlayerAuthority(prompt) {
            return "What do you do?"
        }
        return prompt
    }

    private func key(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
