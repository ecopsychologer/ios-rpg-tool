import Foundation
import FoundationModels
import WorldState

@Generable
public struct SceneSummaryReference {
    @Guide(description: "Name of an already canonical entity referenced by the summary")
    public let name: String

    @Guide(description: "Optional canonical entity UUID string")
    public let entityID: String?

    public init(name: String, entityID: String? = nil) {
        self.name = name
        self.entityID = entityID
    }
}

@Generable
public struct SceneSummaryDraft {
    @Guide(description: "Concise summary containing only events that occurred in the player-visible scene")
    public let summary: String

    @Guide(description: "Every named canonical entity referenced in the summary")
    public let entityReferences: [SceneSummaryReference]

    @Guide(description: "Existing campaign threads referenced in the summary")
    public let threadReferences: [String]

    @Guide(description: "Resolved rolls that mattered in the scene")
    public let rollHighlights: [String]

    public init(
        summary: String,
        entityReferences: [SceneSummaryReference],
        threadReferences: [String],
        rollHighlights: [String]
    ) {
        self.summary = summary
        self.entityReferences = entityReferences
        self.threadReferences = threadReferences
        self.rollHighlights = rollHighlights
    }
}

@available(*, deprecated, message: "Use read-only SceneSummaryDraft. SceneWrapUpDraft must not produce world mutations.")
public typealias DeprecatedSceneWrapUpDraft = SceneWrapUpDraft

public struct SceneCanonSnapshot: Equatable, Sendable {
    public let allowedEntityNames: Set<String>
    public let allowedThreadNames: Set<String>
    public let approvedHiddenEntityIDs: Set<UUID>
    public let stateFingerprint: [String]

    public init(campaign: Campaign, approvedHiddenEntityIDs: Set<UUID> = []) {
        var entityNames = campaign.playerCharacters.map(\.displayName)
        entityNames.append(contentsOf: campaign.characters.map(\.name))
        entityNames.append(contentsOf: campaign.npcs.map(\.name))
        entityNames.append(contentsOf: campaign.items.map(\.name))
        entityNames.append(contentsOf: campaign.creatures.map(\.name))
        entityNames.append(contentsOf: campaign.worldLore.map(\.title))
        entityNames.append(contentsOf: (campaign.locations ?? []).map(\.name))
        entityNames.append(contentsOf: (campaign.locations ?? []).flatMap { location in
            (location.nodes ?? []).flatMap { node in
                (node.features ?? []).map(\.name)
            }
        })

        self.allowedEntityNames = Set(entityNames.map(Self.key).filter { !$0.isEmpty })
        self.allowedThreadNames = Set(campaign.threads.map { Self.key($0.name) })
        self.approvedHiddenEntityIDs = approvedHiddenEntityIDs
        self.stateFingerprint = Self.makeFingerprint(campaign: campaign)
    }

    public static func key(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func makeFingerprint(campaign: Campaign) -> [String] {
        var values: [String] = [
            "chaos:\(campaign.chaosFactor)",
            "activeLocation:\(campaign.activeLocationId?.uuidString ?? "nil")",
            "activeNode:\(campaign.activeNodeId?.uuidString ?? "nil")",
            "lastNode:\(campaign.lastNodeId?.uuidString ?? "nil")",
            "rngSeed:\(campaign.rngSeed.map(String.init) ?? "nil")",
            "rngSequence:\(campaign.rngSequence.map(String.init) ?? "nil")",
            "authorityState:\(campaign.authorityStateJSON ?? "nil")",
            "procedureState:\(campaign.procedureStateJSON ?? "nil")"
        ]

        values.append(contentsOf: campaign.characters.map { "character:\($0.id):\($0.name):\($0.weight)" })
        values.append(contentsOf: campaign.threads.map { "thread:\($0.id):\($0.name):\($0.weight)" })
        values.append(contentsOf: campaign.npcs.map { "npc:\($0.id):\($0.name):\($0.roleTag):\($0.currentLocationId?.uuidString ?? "nil")" })
        values.append(contentsOf: campaign.items.map { "item:\($0.id):\($0.name):\($0.ownerId?.uuidString ?? "nil")" })
        values.append(contentsOf: campaign.creatures.map { "creature:\($0.id):\($0.name):\($0.locationId?.uuidString ?? "nil")" })
        values.append(contentsOf: campaign.worldLore.map { "lore:\($0.id):\($0.title):\($0.summary)" })

        for location in campaign.locations ?? [] {
            values.append("location:\(location.id):\(location.name):\(location.type):\(location.dangerModifier)")
            for node in location.nodes ?? [] {
                values.append("node:\(node.id):\(node.name ?? "nil"):\(node.summary):\(node.contentSummary ?? "nil"):\(node.discovered)")
                values.append(contentsOf: (node.features ?? []).map { "feature:\($0.id):\($0.name):\($0.summary)" })
            }
            values.append(contentsOf: (location.edges ?? []).map {
                "edge:\($0.id):\($0.fromNodeId?.uuidString ?? "nil"):\($0.toNodeId?.uuidString ?? "nil"):discovered=\($0.discovered == true):opened=\($0.opened == true)"
            })
        }

        if let party = campaign.party {
            values.append("party:\(party.resourcesSummary):\(party.inventorySummary):\((party.conditions ?? []).joined(separator: "|"))")
        }

        return values.sorted()
    }
}

public struct SceneSummaryValidationResult: Equatable, Sendable {
    public let isValid: Bool
    public let unknownReferences: [String]

    public init(isValid: Bool, unknownReferences: [String]) {
        self.isValid = isValid
        self.unknownReferences = unknownReferences
    }
}

public struct SceneSummaryValidator: Sendable {
    public init() {}

    public func validate(
        _ draft: SceneSummaryDraft,
        against snapshot: SceneCanonSnapshot
    ) -> SceneSummaryValidationResult {
        var unknown: [String] = []

        for reference in draft.entityReferences {
            let name = reference.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let entityID = reference.entityID.flatMap(UUID.init(uuidString:))
            let hiddenReferenceIsApproved = entityID.map(snapshot.approvedHiddenEntityIDs.contains) ?? false
            guard hiddenReferenceIsApproved || snapshot.allowedEntityNames.contains(SceneCanonSnapshot.key(name)) else {
                if !name.isEmpty {
                    unknown.append(name)
                }
                continue
            }
        }

        for thread in draft.threadReferences {
            let name = thread.trimmingCharacters(in: .whitespacesAndNewlines)
            guard snapshot.allowedThreadNames.contains(SceneCanonSnapshot.key(name)) else {
                if !name.isEmpty {
                    unknown.append(name)
                }
                continue
            }
        }

        let genericHallucinations = ["unknown character", "unnamed npc", "mysterious stranger"]
        for phrase in genericHallucinations where draft.summary.lowercased().contains(phrase) {
            if !unknown.contains(where: { SceneCanonSnapshot.key($0) == phrase }) {
                unknown.append(phrase.capitalized)
            }
        }

        return SceneSummaryValidationResult(
            isValid: unknown.isEmpty,
            unknownReferences: Array(Set(unknown)).sorted()
        )
    }
}
