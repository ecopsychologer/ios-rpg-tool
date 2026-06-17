import Foundation
import FoundationModels
import WorldState

public enum WorldDeltaEntityKind: String, CaseIterable, Sendable {
    case npc
    case location
    case locationFeature = "location_feature"
    case item
    case creature
    case lore
}

public enum WorldDeltaOperation: String, CaseIterable, Sendable {
    case create
    case update
    case reference
}

@Generable
public struct WorldEntityChangeDraft {
    @Guide(description: "Entity type: npc, location, location_feature, item, creature, or lore")
    public let entityType: String

    @Guide(description: "Operation: create, update, or reference. Use reference for mentions that should not mutate state.")
    public let operation: String

    @Guide(description: "Concrete entity name or lore title")
    public let name: String

    @Guide(description: "One-sentence durable fact. Exclude transient action beats and player intent.")
    public let summary: String

    @Guide(description: "Short relevance tags such as faction, place, theme, hazard, object, or NPC role")
    public let tags: [String]

    @Guide(description: "0-100 confidence that this is a stable world fact worth storing")
    public let confidence: Int

    @Guide(description: "True only if the entity is physically present at the current location or node")
    public let isPresentNow: Bool

    @Guide(description: "Optional existing location name this entity belongs to")
    public let relatedLocationName: String?

    @Guide(description: "Short reason this should be stored")
    public let reason: String

    public init(
        entityType: String,
        operation: String,
        name: String,
        summary: String,
        tags: [String] = [],
        confidence: Int,
        isPresentNow: Bool = false,
        relatedLocationName: String? = nil,
        reason: String = ""
    ) {
        self.entityType = entityType
        self.operation = operation
        self.name = name
        self.summary = summary
        self.tags = tags
        self.confidence = confidence
        self.isPresentNow = isPresentNow
        self.relatedLocationName = relatedLocationName
        self.reason = reason
    }
}

@Generable
public struct WorldDeltaDraft {
    @Guide(description: "True if player clarification is required before any world state mutation is safe")
    public let needsClarification: Bool

    @Guide(description: "Question to ask when needsClarification is true")
    public let clarificationQuestion: String?

    @Guide(description: "Stable world changes proposed by the narrator")
    public let changes: [WorldEntityChangeDraft]

    public init(
        needsClarification: Bool = false,
        clarificationQuestion: String? = nil,
        changes: [WorldEntityChangeDraft] = []
    ) {
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
        self.changes = changes
    }
}

public struct AcceptedWorldDelta: Sendable {
    public let entityId: UUID
    public let entityType: WorldDeltaEntityKind
    public let operation: WorldDeltaOperation
    public let name: String

    public init(entityId: UUID, entityType: WorldDeltaEntityKind, operation: WorldDeltaOperation, name: String) {
        self.entityId = entityId
        self.entityType = entityType
        self.operation = operation
        self.name = name
    }
}

public struct RejectedWorldDelta: Sendable {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}

public struct WorldDeltaApplicationResult: Sendable {
    public let accepted: [AcceptedWorldDelta]
    public let rejected: [RejectedWorldDelta]
    public let clarificationQuestion: String?

    public var generatedEntityIds: [UUID] {
        accepted.map(\.entityId)
    }

    public init(
        accepted: [AcceptedWorldDelta] = [],
        rejected: [RejectedWorldDelta] = [],
        clarificationQuestion: String? = nil
    ) {
        self.accepted = accepted
        self.rejected = rejected
        self.clarificationQuestion = clarificationQuestion
    }
}

public struct RelevantWorldContext: Sendable {
    public let lore: [String]
    public let npcs: [String]
    public let locations: [String]
    public let items: [String]
    public let creatures: [String]

    public var isEmpty: Bool {
        lore.isEmpty && npcs.isEmpty && locations.isEmpty && items.isEmpty && creatures.isEmpty
    }

    public init(
        lore: [String] = [],
        npcs: [String] = [],
        locations: [String] = [],
        items: [String] = [],
        creatures: [String] = []
    ) {
        self.lore = lore
        self.npcs = npcs
        self.locations = locations
        self.items = items
        self.creatures = creatures
    }
}

public struct WorldDeltaEngine {
    public let minimumConfidence: Int

    public init(minimumConfidence: Int = 65) {
        self.minimumConfidence = minimumConfidence
    }

    public func applyWorldDelta(
        _ draft: WorldDeltaDraft,
        to campaign: Campaign,
        sceneId: UUID? = nil
    ) -> WorldDeltaApplicationResult {
        if draft.needsClarification {
            return WorldDeltaApplicationResult(
                rejected: draft.changes.map { RejectedWorldDelta(name: $0.name, reason: "Clarification required before mutation.") },
                clarificationQuestion: draft.clarificationQuestion
            )
        }

        var accepted: [AcceptedWorldDelta] = []
        var rejected: [RejectedWorldDelta] = []

        for change in draft.changes {
            let name = change.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = change.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                rejected.append(RejectedWorldDelta(name: change.name, reason: "Missing entity name."))
                continue
            }
            guard !summary.isEmpty else {
                rejected.append(RejectedWorldDelta(name: name, reason: "Missing durable summary."))
                continue
            }
            guard change.confidence >= minimumConfidence else {
                rejected.append(RejectedWorldDelta(name: name, reason: "Confidence below storage threshold."))
                continue
            }
            guard let kind = WorldDeltaEntityKind(rawValue: normalized(change.entityType)) else {
                rejected.append(RejectedWorldDelta(name: name, reason: "Unsupported entity type."))
                continue
            }
            guard let operation = WorldDeltaOperation(rawValue: normalized(change.operation)) else {
                rejected.append(RejectedWorldDelta(name: name, reason: "Unsupported operation."))
                continue
            }
            guard operation != .reference else {
                rejected.append(RejectedWorldDelta(name: name, reason: "Reference mention does not mutate state."))
                continue
            }

            let entityId = apply(change: change, kind: kind, operation: operation, name: name, summary: summary, to: campaign, sceneId: sceneId)
            accepted.append(AcceptedWorldDelta(entityId: entityId, entityType: kind, operation: operation, name: name))
        }

        return WorldDeltaApplicationResult(accepted: accepted, rejected: rejected)
    }

    public func relevantContext(
        for campaign: Campaign,
        focusText: String,
        limit: Int = 4
    ) -> RelevantWorldContext {
        let focusTokens = tokens(in: focusText + " " + campaign.worldVibe)
        let activeLocationId = campaign.activeLocationId

        let lore = ranked(campaign.worldLore, limit: limit) { entry in
            score(
                tokens: focusTokens,
                fields: [entry.title, entry.summary] + entry.tags,
                bonus: [
                    entry.relatedLocationId == activeLocationId ? 3 : 0,
                    entry.relatedSceneId == campaign.activeSceneId ? 2 : 0
                ]
            )
        } render: { entry in
            "\(entry.title): \(entry.summary)"
        }

        let npcs = ranked(campaign.npcs, limit: limit) { npc in
            score(
                tokens: focusTokens,
                fields: [
                    npc.name,
                    npc.roleTag,
                    npc.species,
                    npc.appearanceShort,
                    npc.derivedSummary ?? "",
                    npc.currentMood
                ] + npc.personalityTraits + npc.goalsImmediate + npc.goalsLongTerm,
                bonus: [npc.currentLocationId == activeLocationId ? 5 : 0]
            )
        } render: { npc in
            let summary = npc.derivedSummary?.isEmpty == false ? npc.derivedSummary! : npc.appearanceShort
            return "\(npc.name) (\(npc.roleTag)): \(summary)"
        }

        let locations = ranked(campaign.locations ?? [], limit: limit) { location in
            score(
                tokens: focusTokens,
                fields: [location.name, location.type] + (location.tags ?? []) + (location.themeTags ?? []),
                bonus: [location.id == activeLocationId ? 6 : 0]
            )
        } render: { location in
            "\(location.name) (\(location.type))"
        }

        let items = ranked(campaign.items, limit: limit) { item in
            score(
                tokens: focusTokens,
                fields: [item.name, item.category, item.subcategory ?? "", item.itemType ?? ""] + item.properties + item.detailLines,
                bonus: [item.ownerId == activeLocationId ? 4 : 0]
            )
        } render: { item in
            let detail = item.detailLines.first ?? item.category
            return "\(item.name): \(detail)"
        }

        let creatures = ranked(campaign.creatures, limit: limit) { creature in
            score(
                tokens: focusTokens,
                fields: [creature.name, creature.creatureType ?? "", creature.challenge ?? ""] + creature.traits + creature.actions,
                bonus: [creature.locationId == activeLocationId ? 5 : 0]
            )
        } render: { creature in
            let detail = creature.traits.first ?? creature.creatureType ?? "creature"
            return "\(creature.name): \(detail)"
        }

        return RelevantWorldContext(lore: lore, npcs: npcs, locations: locations, items: items, creatures: creatures)
    }

    private func apply(
        change: WorldEntityChangeDraft,
        kind: WorldDeltaEntityKind,
        operation: WorldDeltaOperation,
        name: String,
        summary: String,
        to campaign: Campaign,
        sceneId: UUID?
    ) -> UUID {
        switch kind {
        case .npc:
            let npc = campaign.npcs.first { keysMatch($0.name, name) } ?? {
                let entry = NPCEntry(
                    name: name,
                    species: "Unknown",
                    roleTag: change.tags.first ?? "Unknown",
                    importance: NPCImportance.minor.rawValue,
                    origin: "narrator"
                )
                campaign.npcs.append(entry)
                return entry
            }()
            npc.derivedSummary = mergeText(npc.derivedSummary, summary)
            if npc.appearanceShort.isEmpty {
                npc.appearanceShort = summary
            }
            npc.updatedAt = Date()
            if change.isPresentNow {
                npc.currentLocationId = campaign.activeLocationId
                npc.lastSeenSceneId = sceneId
                npc.lastSeenAt = Date()
            }
            return npc.id

        case .location:
            if campaign.locations == nil {
                campaign.locations = []
            }
            let location = campaign.locations?.first { keysMatch($0.name, name) } ?? {
                let entry = LocationEntity(
                    name: name,
                    type: change.tags.first ?? "location",
                    tags: cleanTags(change.tags),
                    origin: "narrator"
                )
                campaign.locations?.append(entry)
                return entry
            }()
            location.tags = mergeTags(location.tags, change.tags)
            if campaign.activeLocationId == nil, change.isPresentNow {
                campaign.activeLocationId = location.id
            }
            upsertLore(title: name, summary: summary, tags: change.tags, campaign: campaign, locationId: location.id, sceneId: sceneId)
            return location.id

        case .locationFeature:
            let feature = upsertLocationFeature(name: name, summary: summary, tags: change.tags, campaign: campaign)
            return feature.id

        case .item:
            let item = campaign.items.first { keysMatch($0.name, name) } ?? {
                let entry = ItemEntry(
                    name: name,
                    category: change.tags.first ?? "object",
                    properties: cleanTags(change.tags),
                    detailLines: [summary],
                    source: "narrator",
                    ownerId: change.isPresentNow ? campaign.activeLocationId : nil,
                    ownerKind: change.isPresentNow ? "location" : nil
                )
                campaign.items.append(entry)
                return entry
            }()
            item.detailLines = mergeLines(item.detailLines, [summary])
            item.properties = mergeLines(item.properties, cleanTags(change.tags))
            item.updatedAt = Date()
            return item.id

        case .creature:
            let creature = campaign.creatures.first { keysMatch($0.name, name) } ?? {
                let entry = CreatureEntry(
                    name: name,
                    creatureType: change.tags.first,
                    traits: [summary],
                    origin: "narrator",
                    locationId: change.isPresentNow ? campaign.activeLocationId : nil
                )
                campaign.creatures.append(entry)
                return entry
            }()
            creature.traits = mergeLines(creature.traits, [summary])
            if change.isPresentNow {
                creature.locationId = campaign.activeLocationId
            }
            creature.updatedAt = Date()
            return creature.id

        case .lore:
            let lore = upsertLore(title: name, summary: summary, tags: change.tags, campaign: campaign, locationId: campaign.activeLocationId, sceneId: sceneId)
            return lore.id
        }
    }

    private func upsertLocationFeature(
        name: String,
        summary: String,
        tags: [String],
        campaign: Campaign
    ) -> LocationFeature {
        guard let location = activeLocation(in: campaign),
              let node = activeNode(in: campaign, location: location) else {
            let lore = upsertLore(title: name, summary: summary, tags: tags, campaign: campaign, locationId: campaign.activeLocationId, sceneId: campaign.activeSceneId)
            return LocationFeature(name: lore.title, summary: lore.summary, category: "feature", tags: tags, origin: "narrator")
        }

        if let existing = node.features?.first(where: { keysMatch($0.name, name) }) {
            existing.summary = mergeText(existing.summary, summary) ?? summary
            existing.tags = mergeTags(existing.tags, tags)
            return existing
        }

        let feature = LocationFeature(
            name: name,
            summary: summary,
            category: tags.first ?? "feature",
            tags: cleanTags(tags),
            origin: "narrator",
            locationNodeId: node.id
        )
        if node.features == nil {
            node.features = []
        }
        node.features?.append(feature)
        return feature
    }

    @discardableResult
    private func upsertLore(
        title: String,
        summary: String,
        tags: [String],
        campaign: Campaign,
        locationId: UUID?,
        sceneId: UUID?
    ) -> WorldLoreEntry {
        if let existing = campaign.worldLore.first(where: { keysMatch($0.title, title) }) {
            existing.summary = mergeText(existing.summary, summary) ?? summary
            existing.tags = mergeLines(existing.tags, cleanTags(tags))
            existing.relatedLocationId = existing.relatedLocationId ?? locationId
            existing.relatedSceneId = existing.relatedSceneId ?? sceneId
            existing.updatedAt = Date()
            return existing
        }

        let lore = WorldLoreEntry(
            title: title,
            summary: summary,
            tags: cleanTags(tags),
            origin: "narrator",
            relatedLocationId: locationId,
            relatedSceneId: sceneId
        )
        campaign.worldLore.append(lore)
        return lore
    }

    private func activeLocation(in campaign: Campaign) -> LocationEntity? {
        guard let activeId = campaign.activeLocationId else { return nil }
        return campaign.locations?.first { $0.id == activeId }
    }

    private func activeNode(in campaign: Campaign, location: LocationEntity) -> LocationNode? {
        guard let nodeId = campaign.activeNodeId else { return nil }
        return location.nodes?.first { $0.id == nodeId }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private func keysMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalized(lhs) == normalized(rhs)
    }

    private func cleanTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private func mergeTags(_ existing: [String]?, _ additions: [String]) -> [String] {
        mergeLines(existing ?? [], cleanTags(additions))
    }

    private func mergeText(_ existing: String?, _ addition: String) -> String? {
        let trimmed = addition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        guard let existing, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return trimmed
        }
        guard !existing.lowercased().contains(trimmed.lowercased()) else { return existing }
        return existing + " " + trimmed
    }

    private func mergeLines(_ existing: [String], _ additions: [String]) -> [String] {
        var seen = Set(existing.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var result = existing
        for addition in additions {
            let trimmed = addition.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private func tokens(in text: String) -> Set<String> {
        let words = text.lowercased().split { character in
            !character.isLetter && !character.isNumber
        }
        let ignored: Set<Substring> = ["the", "and", "with", "that", "this", "from", "into", "what", "where", "when", "your", "you"]
        return Set(words.filter { $0.count > 2 && !ignored.contains($0) }.map(String.init))
    }

    private func score(tokens focusTokens: Set<String>, fields: [String], bonus: [Int] = []) -> Int {
        let fieldText = fields.joined(separator: " ")
        let fieldTokens = tokens(in: fieldText)
        return focusTokens.intersection(fieldTokens).count + bonus.reduce(0, +)
    }

    private func ranked<T>(
        _ values: [T],
        limit: Int,
        score: (T) -> Int,
        render: (T) -> String
    ) -> [String] {
        values
            .map { value in (value, score(value)) }
            .filter { $0.1 > 0 }
            .sorted { lhs, rhs in lhs.1 > rhs.1 }
            .prefix(limit)
            .map { render($0.0) }
    }
}
