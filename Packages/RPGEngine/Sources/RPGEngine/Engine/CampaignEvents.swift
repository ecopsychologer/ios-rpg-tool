import Foundation
import WorldState

public enum CampaignEventType: String, Codable, Sendable {
    case worldDelta = "world_delta"
    case weatherAuthority = "weather_authority"
    case hiddenThreat = "hidden_threat"
    case procedure
}

public enum CampaignEventSource: String, Codable, Sendable {
    case gmLive = "gm_live"
    case engine
    case oracle
    case tableRoll = "table_roll"
    case playerConfirmed = "player_confirmed"
}

public enum CampaignEventVisibility: String, Codable, Sendable {
    case playerVisible = "player_visible"
    case hiddenGM = "hidden_gm"
    case mechanicalOnly = "mechanical_only"
}

public enum CampaignEventDurability: String, Codable, Sendable {
    case scene
    case session
    case campaign
}

public enum CampaignEventApproval: String, Codable, Sendable {
    case automatic
    case engineRequired = "engine_required"
    case playerRequired = "player_required"
}

public struct CampaignEventMetadata: Codable, Equatable, Sendable {
    public var source: CampaignEventSource
    public var visibility: CampaignEventVisibility
    public var durability: CampaignEventDurability
    public var approval: CampaignEventApproval
    public var locationBinding: String?
    public var entityBinding: String?
    public var sceneId: UUID?

    public init(
        source: CampaignEventSource,
        visibility: CampaignEventVisibility,
        durability: CampaignEventDurability,
        approval: CampaignEventApproval,
        locationBinding: String? = nil,
        entityBinding: String? = nil,
        sceneId: UUID? = nil
    ) {
        self.source = source
        self.visibility = visibility
        self.durability = durability
        self.approval = approval
        self.locationBinding = locationBinding
        self.entityBinding = entityBinding
        self.sceneId = sceneId
    }
}

public struct CampaignEventPayload: Codable, Equatable, Sendable {
    public var entityType: String
    public var operation: String
    public var name: String
    public var summary: String
    public var tags: [String]
    public var isPresentNow: Bool
    public var relatedLocationName: String?
    public var structuredDataJSON: String?

    public init(
        entityType: String,
        operation: String,
        name: String,
        summary: String,
        tags: [String] = [],
        isPresentNow: Bool = false,
        relatedLocationName: String? = nil,
        structuredDataJSON: String? = nil
    ) {
        self.entityType = entityType
        self.operation = operation
        self.name = name
        self.summary = summary
        self.tags = tags
        self.isPresentNow = isPresentNow
        self.relatedLocationName = relatedLocationName
        self.structuredDataJSON = structuredDataJSON
    }
}

public struct CampaignEvent: Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var type: CampaignEventType
    public var payload: CampaignEventPayload
    public var metadata: CampaignEventMetadata

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: CampaignEventType,
        payload: CampaignEventPayload,
        metadata: CampaignEventMetadata
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
        self.metadata = metadata
    }
}

public enum CampaignEventApplicationStatus: String, Equatable, Sendable {
    case applied
    case duplicate
    case rejected
}

public struct CampaignEventApplicationResult: Equatable, Sendable {
    public let status: CampaignEventApplicationStatus
    public let entityId: UUID?
    public let reason: String?

    public init(status: CampaignEventApplicationStatus, entityId: UUID? = nil, reason: String? = nil) {
        self.status = status
        self.entityId = entityId
        self.reason = reason
    }
}

public struct CampaignEventFactory: Sendable {
    public init() {}

    public func worldDeltaEvent(from change: WorldEntityChangeDraft, sceneId: UUID?) -> CampaignEvent {
        CampaignEvent(
            type: .worldDelta,
            payload: CampaignEventPayload(
                entityType: change.entityType,
                operation: change.operation,
                name: change.name,
                summary: change.summary,
                tags: change.tags,
                isPresentNow: change.isPresentNow,
                relatedLocationName: change.relatedLocationName
            ),
            metadata: CampaignEventMetadata(
                source: CampaignEventSource(rawValue: normalized(change.source)) ?? .gmLive,
                visibility: CampaignEventVisibility(rawValue: normalized(change.visibility)) ?? .playerVisible,
                durability: CampaignEventDurability(rawValue: normalized(change.durability)) ?? .campaign,
                approval: CampaignEventApproval(rawValue: normalized(change.approval)) ?? .engineRequired,
                locationBinding: change.locationBinding,
                entityBinding: change.entityBinding,
                sceneId: sceneId
            )
        )
    }

    public func weatherAuthorityEvent(decision: WeatherAuthorityDecision, sceneId: UUID? = nil) -> CampaignEvent {
        CampaignEvent(
            type: .weatherAuthority,
            payload: CampaignEventPayload(
                entityType: "weather",
                operation: "set",
                name: decision.canonicalWeather ?? decision.proposedWeather,
                summary: decision.rationale,
                tags: [decision.resolution.rawValue],
                structuredDataJSON: encoded(decision)
            ),
            metadata: CampaignEventMetadata(
                source: .engine,
                visibility: .playerVisible,
                durability: .scene,
                approval: .engineRequired,
                sceneId: sceneId
            )
        )
    }

    public func hiddenThreatEvent(_ threat: HiddenThreatRecord, sceneId: UUID? = nil) -> CampaignEvent {
        CampaignEvent(
            type: .hiddenThreat,
            payload: CampaignEventPayload(
                entityType: threat.kind.rawValue,
                operation: "create",
                name: threat.label,
                summary: "Hidden pressure tracked by the engine.",
                tags: ["hidden", threat.kind.rawValue],
                structuredDataJSON: encoded(threat)
            ),
            metadata: CampaignEventMetadata(
                source: .engine,
                visibility: .hiddenGM,
                durability: .scene,
                approval: .engineRequired,
                sceneId: sceneId
            )
        )
    }

    public func travelResolutionEvent(request: TravelRequest, resolution: TravelResolution, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .travelResolution)
        data.travelRequest = request
        data.travelResolution = resolution
        return procedureEvent(data, name: request.destinationName ?? "Travel", sceneId: sceneId)
    }

    public func travelRequestEvent(_ request: TravelRequest, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .travelRequest)
        data.travelRequest = request
        return procedureEvent(data, name: request.destinationName ?? "Travel request", sceneId: sceneId)
    }

    public func restPlanEvent(_ plan: RestPlan, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .restPlan)
        data.restPlan = plan
        return procedureEvent(data, name: "Rest plan", sceneId: sceneId)
    }

    public func restResolutionEvent(plan: RestPlan, resolution: RestResolution, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .restResolution)
        data.restPlan = plan
        data.restResolution = resolution
        return procedureEvent(data, name: "\(plan.kind?.rawValue ?? "pending") rest", sceneId: sceneId)
    }

    public func searchResolutionEvent(request: SearchRequest, resolution: SearchResolution, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .searchResolution)
        data.searchRequest = request
        data.searchResolution = resolution
        return procedureEvent(data, name: "\(request.mode.rawValue) search", sceneId: sceneId)
    }

    public func searchRequestEvent(_ request: SearchRequest, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .searchRequest)
        data.searchRequest = request
        return procedureEvent(data, name: "\(request.mode.rawValue) search request", sceneId: sceneId)
    }

    public func creativeResolutionEvent(_ creative: CreativeEvent, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .creativeResolution)
        data.creativeEvent = creative
        return procedureEvent(data, name: "Creative solution", sceneId: sceneId)
    }

    public func spatialDiscoveryEvent(edgeID: UUID, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .spatialDiscovery)
        data.edgeID = edgeID
        return procedureEvent(data, name: "Discovered transition", sceneId: sceneId)
    }

    public func explicitMovementEvent(edgeID: UUID, sceneId: UUID? = nil) -> CampaignEvent {
        var data = ProcedureEventData(action: .explicitMovement)
        data.edgeID = edgeID
        return procedureEvent(data, name: "Explicit movement", sceneId: sceneId)
    }

    private func procedureEvent(_ data: ProcedureEventData, name: String, sceneId: UUID?) -> CampaignEvent {
        CampaignEvent(
            type: .procedure,
            payload: CampaignEventPayload(
                entityType: "procedure",
                operation: data.action.rawValue,
                name: name,
                summary: "Engine-owned procedure event.",
                structuredDataJSON: encoded(data)
            ),
            metadata: CampaignEventMetadata(
                source: .engine,
                visibility: .mechanicalOnly,
                durability: .campaign,
                approval: .automatic,
                sceneId: sceneId
            )
        )
    }

    private func encoded<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "-", with: "_")
    }
}

public struct CampaignEventStore: Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func logEntry(for event: CampaignEvent, entityId: UUID?) -> EventLogEntry? {
        guard let data = try? encoder.encode(event), let json = String(data: data, encoding: .utf8) else { return nil }
        return EventLogEntry(
            summary: "Campaign event: \(event.type.rawValue) \(event.payload.operation) \(event.payload.entityType):\(event.payload.name)",
            sceneId: event.metadata.sceneId,
            entityIds: entityId.map { [$0] },
            origin: "campaign_event",
            eventId: event.id,
            eventType: event.type.rawValue,
            eventPayloadJSON: json,
            eventSource: event.metadata.source.rawValue,
            eventVisibility: event.metadata.visibility.rawValue,
            eventDurability: event.metadata.durability.rawValue,
            eventApproval: event.metadata.approval.rawValue,
            eventLocationBinding: event.metadata.locationBinding,
            eventEntityBinding: event.metadata.entityBinding
        )
    }

    public func events(from entries: [EventLogEntry]) -> [CampaignEvent] {
        entries.compactMap { entry in
            guard entry.eventType != nil,
                  let json = entry.eventPayloadJSON,
                  let data = json.data(using: .utf8) else { return nil }
            return try? decoder.decode(CampaignEvent.self, from: data)
        }
    }
}

public struct CampaignReducer: Sendable {
    public init() {}

    @discardableResult
    public func apply(
        _ event: CampaignEvent,
        to campaign: Campaign,
        persistEvent: Bool = true
    ) -> CampaignEventApplicationResult {
        if persistEvent, campaign.eventLog?.contains(where: { $0.eventId == event.id }) == true {
            return CampaignEventApplicationResult(status: .duplicate)
        }
        switch event.type {
        case .weatherAuthority:
            return applyWeatherAuthority(event, to: campaign, persistEvent: persistEvent)
        case .hiddenThreat:
            return applyHiddenThreat(event, to: campaign, persistEvent: persistEvent)
        case .procedure:
            return applyProcedure(event, to: campaign, persistEvent: persistEvent)
        case .worldDelta:
            break
        }
        guard let kind = WorldDeltaEntityKind(rawValue: normalized(event.payload.entityType)),
              let operation = WorldDeltaOperation(rawValue: normalized(event.payload.operation)),
              operation != .reference else {
            return CampaignEventApplicationResult(status: .rejected, reason: "World event must contain a supported mutating operation.")
        }
        let name = event.payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = event.payload.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !summary.isEmpty else {
            return CampaignEventApplicationResult(status: .rejected, reason: "World event is missing a name or summary.")
        }
        if operation == .update, !entityExists(kind: kind, name: name, campaign: campaign) {
            return CampaignEventApplicationResult(status: .rejected, reason: "Update requires an existing canonical entity.")
        }

        let entityId = mutate(event.payload, kind: kind, name: name, summary: summary, campaign: campaign, sceneId: event.metadata.sceneId, origin: event.metadata.source.rawValue)
        if persistEvent, let entry = CampaignEventStore().logEntry(for: event, entityId: entityId) {
            if campaign.eventLog == nil { campaign.eventLog = [] }
            campaign.eventLog?.append(entry)
        }
        return CampaignEventApplicationResult(status: .applied, entityId: entityId)
    }

    private func applyWeatherAuthority(
        _ event: CampaignEvent,
        to campaign: Campaign,
        persistEvent: Bool
    ) -> CampaignEventApplicationResult {
        guard let decision: WeatherAuthorityDecision = decoded(event.payload.structuredDataJSON) else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Weather event is missing a valid authority decision.")
        }
        var state = CampaignAuthorityStateStore().load(from: campaign) ?? CampaignAuthorityState()
        if decision.resolution != .rejected {
            state.weather = decision.canonicalWeather
        }
        state.weatherDecision = decision.resolution
        guard CampaignAuthorityStateStore().save(state, to: campaign) else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Weather authority state could not be encoded.")
        }
        persist(event, entityId: nil, to: campaign, enabled: persistEvent)
        return CampaignEventApplicationResult(status: .applied)
    }

    private func applyHiddenThreat(
        _ event: CampaignEvent,
        to campaign: Campaign,
        persistEvent: Bool
    ) -> CampaignEventApplicationResult {
        guard let threat: HiddenThreatRecord = decoded(event.payload.structuredDataJSON),
              normalized(threat.label) != "unknown character" else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Hidden pressure requires a concrete clue or clock label.")
        }
        var state = CampaignAuthorityStateStore().load(from: campaign) ?? CampaignAuthorityState()
        if !state.hiddenThreats.contains(where: { $0.id == threat.id }) {
            state.hiddenThreats.append(threat)
        }
        guard CampaignAuthorityStateStore().save(state, to: campaign) else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Hidden threat state could not be encoded.")
        }
        persist(event, entityId: nil, to: campaign, enabled: persistEvent)
        return CampaignEventApplicationResult(status: .applied)
    }

    private func applyProcedure(
        _ event: CampaignEvent,
        to campaign: Campaign,
        persistEvent: Bool
    ) -> CampaignEventApplicationResult {
        guard let data: ProcedureEventData = decoded(event.payload.structuredDataJSON) else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Procedure event is missing valid data.")
        }
        var state = CampaignProcedureStateStore().load(from: campaign) ?? CampaignProcedureState()
        switch data.action {
        case .travelRequest:
            guard let request = data.travelRequest else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Travel request event is incomplete.")
            }
            state.lastTravelRequest = request
        case .travelResolution:
            guard let request = data.travelRequest, let resolution = data.travelResolution else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Travel event is incomplete.")
            }
            state.lastTravelRequest = request
            state.lastTravel = resolution
        case .restPlan:
            guard let plan = data.restPlan else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Rest plan event is incomplete.")
            }
            state.lastRestPlan = plan
        case .restResolution:
            guard let plan = data.restPlan, let resolution = data.restResolution else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Rest event is incomplete.")
            }
            state.lastRestPlan = plan
            state.lastRest = resolution
        case .searchRequest:
            guard let request = data.searchRequest else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Search request event is incomplete.")
            }
            state.lastSearchRequest = request
        case .searchResolution:
            guard let request = data.searchRequest, let resolution = data.searchResolution else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Search event is incomplete.")
            }
            state.lastSearchRequest = request
            state.lastSearch = resolution
            if let target = resolution.revealedTarget {
                reveal(target, campaign: campaign)
            }
        case .creativeResolution:
            guard let creative = data.creativeEvent else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Creative event is incomplete.")
            }
            state.lastCreative = creative
        case .spatialDiscovery:
            guard let edgeID = data.edgeID, let edge = edge(with: edgeID, campaign: campaign) else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Discovery requires an existing edge.")
            }
            edge.discovered = true
            if edge.opened == nil { edge.opened = false }
        case .explicitMovement:
            guard let edgeID = data.edgeID,
                  let edge = edge(with: edgeID, campaign: campaign),
                  edge.discovered == true,
                  let destinationID = edge.toNodeId,
                  edge.fromNodeId == nil || edge.fromNodeId == campaign.activeNodeId else {
                return CampaignEventApplicationResult(status: .rejected, reason: "Movement requires a discovered edge from the active node.")
            }
            campaign.lastNodeId = campaign.activeNodeId
            campaign.activeNodeId = destinationID
            edge.opened = true
            for location in campaign.locations ?? [] {
                if let node = location.nodes?.first(where: { $0.id == destinationID }) {
                    node.discovered = true
                    campaign.activeLocationId = location.id
                    break
                }
            }
        }
        guard CampaignProcedureStateStore().save(state, to: campaign) else {
            return CampaignEventApplicationResult(status: .rejected, reason: "Procedure state could not be encoded.")
        }
        persist(event, entityId: nil, to: campaign, enabled: persistEvent)
        return CampaignEventApplicationResult(status: .applied)
    }

    private func reveal(_ target: HiddenSearchTarget, campaign: Campaign) {
        switch target.kind {
        case .edge:
            if let edge = edge(with: target.boundEntityID, campaign: campaign) {
                edge.discovered = true
                if edge.opened == nil { edge.opened = false }
            }
        case .feature:
            for feature in (campaign.locations ?? []).flatMap({ $0.nodes ?? [] }).flatMap({ $0.features ?? [] }) where feature.id == target.boundEntityID {
                var tags = feature.tags ?? []
                if !tags.contains(where: { $0.caseInsensitiveCompare("discovered") == .orderedSame }) { tags.append("discovered") }
                feature.tags = tags
            }
        case .trap:
            for trap in (campaign.locations ?? []).flatMap({ $0.nodes ?? [] }).flatMap({ $0.traps ?? [] }) where trap.id == target.boundEntityID {
                trap.state = "revealed"
            }
        case .clue:
            break
        }
    }

    private func edge(with id: UUID, campaign: Campaign) -> LocationEdge? {
        (campaign.locations ?? []).flatMap { $0.edges ?? [] }.first { $0.id == id }
    }

    private func decoded<T: Decodable>(_ json: String?) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func persist(_ event: CampaignEvent, entityId: UUID?, to campaign: Campaign, enabled: Bool) {
        guard enabled, let entry = CampaignEventStore().logEntry(for: event, entityId: entityId) else { return }
        if campaign.eventLog == nil { campaign.eventLog = [] }
        campaign.eventLog?.append(entry)
    }

    private func mutate(
        _ payload: CampaignEventPayload,
        kind: WorldDeltaEntityKind,
        name: String,
        summary: String,
        campaign: Campaign,
        sceneId: UUID?,
        origin: String
    ) -> UUID {
        switch kind {
        case .npc:
            let npc = campaign.npcs.first(where: { keysMatch($0.name, name) }) ?? {
                let value = NPCEntry(name: name, species: "Unknown", roleTag: payload.tags.first ?? "Unknown", importance: NPCImportance.minor.rawValue, origin: origin)
                campaign.npcs.append(value)
                return value
            }()
            npc.derivedSummary = mergeText(npc.derivedSummary, summary)
            if npc.appearanceShort.isEmpty { npc.appearanceShort = summary }
            npc.updatedAt = Date()
            if payload.isPresentNow {
                npc.currentLocationId = campaign.activeLocationId
                npc.lastSeenSceneId = sceneId
                npc.lastSeenAt = Date()
            }
            return npc.id
        case .location:
            if campaign.locations == nil { campaign.locations = [] }
            let location = campaign.locations?.first(where: { keysMatch($0.name, name) }) ?? {
                let value = LocationEntity(name: name, type: payload.tags.first ?? "location", tags: cleanTags(payload.tags), origin: origin)
                campaign.locations?.append(value)
                return value
            }()
            location.tags = mergeTags(location.tags, payload.tags)
            return location.id
        case .locationFeature:
            return upsertFeature(payload, name: name, summary: summary, campaign: campaign, origin: origin).id
        case .item:
            let item = campaign.items.first(where: { keysMatch($0.name, name) }) ?? {
                let value = ItemEntry(name: name, category: payload.tags.first ?? "object", properties: cleanTags(payload.tags), detailLines: [summary], source: origin, ownerId: payload.isPresentNow ? campaign.activeLocationId : nil, ownerKind: payload.isPresentNow ? "location" : nil)
                campaign.items.append(value)
                return value
            }()
            item.detailLines = mergeLines(item.detailLines, [summary])
            item.properties = mergeLines(item.properties, cleanTags(payload.tags))
            item.updatedAt = Date()
            return item.id
        case .creature:
            let creature = campaign.creatures.first(where: { keysMatch($0.name, name) }) ?? {
                let value = CreatureEntry(name: name, creatureType: payload.tags.first, traits: [summary], origin: origin, locationId: payload.isPresentNow ? campaign.activeLocationId : nil)
                campaign.creatures.append(value)
                return value
            }()
            creature.traits = mergeLines(creature.traits, [summary])
            if payload.isPresentNow { creature.locationId = campaign.activeLocationId }
            creature.updatedAt = Date()
            return creature.id
        case .lore:
            return upsertLore(payload, title: name, summary: summary, campaign: campaign, sceneId: sceneId, origin: origin).id
        }
    }

    private func upsertFeature(_ payload: CampaignEventPayload, name: String, summary: String, campaign: Campaign, origin: String) -> LocationFeature {
        guard let location = activeLocation(campaign), let node = activeNode(campaign, location: location) else {
            let lore = upsertLore(payload, title: name, summary: summary, campaign: campaign, sceneId: nil, origin: origin)
            return LocationFeature(name: lore.title, summary: lore.summary, category: "feature", tags: payload.tags, origin: origin)
        }
        if let feature = node.features?.first(where: { keysMatch($0.name, name) }) {
            feature.summary = mergeText(feature.summary, summary) ?? summary
            feature.tags = mergeTags(feature.tags, payload.tags)
            return feature
        }
        let feature = LocationFeature(name: name, summary: summary, category: payload.tags.first ?? "feature", tags: cleanTags(payload.tags), origin: origin, locationNodeId: node.id)
        if node.features == nil { node.features = [] }
        node.features?.append(feature)
        return feature
    }

    private func upsertLore(_ payload: CampaignEventPayload, title: String, summary: String, campaign: Campaign, sceneId: UUID?, origin: String) -> WorldLoreEntry {
        if let lore = campaign.worldLore.first(where: { keysMatch($0.title, title) }) {
            lore.summary = mergeText(lore.summary, summary) ?? summary
            lore.tags = mergeLines(lore.tags, cleanTags(payload.tags))
            lore.relatedLocationId = lore.relatedLocationId ?? campaign.activeLocationId
            lore.relatedSceneId = lore.relatedSceneId ?? sceneId
            lore.updatedAt = Date()
            return lore
        }
        let lore = WorldLoreEntry(title: title, summary: summary, tags: cleanTags(payload.tags), origin: origin, relatedLocationId: campaign.activeLocationId, relatedSceneId: sceneId)
        campaign.worldLore.append(lore)
        return lore
    }

    private func entityExists(kind: WorldDeltaEntityKind, name: String, campaign: Campaign) -> Bool {
        switch kind {
        case .npc: return campaign.npcs.contains { keysMatch($0.name, name) }
        case .location: return (campaign.locations ?? []).contains { keysMatch($0.name, name) }
        case .locationFeature: return (campaign.locations ?? []).flatMap { $0.nodes ?? [] }.flatMap { $0.features ?? [] }.contains { keysMatch($0.name, name) }
        case .item: return campaign.items.contains { keysMatch($0.name, name) }
        case .creature: return campaign.creatures.contains { keysMatch($0.name, name) }
        case .lore: return campaign.worldLore.contains { keysMatch($0.title, name) }
        }
    }

    private func activeLocation(_ campaign: Campaign) -> LocationEntity? {
        guard let id = campaign.activeLocationId else { return nil }
        return campaign.locations?.first { $0.id == id }
    }

    private func activeNode(_ campaign: Campaign, location: LocationEntity) -> LocationNode? {
        guard let id = campaign.activeNodeId else { return nil }
        return location.nodes?.first { $0.id == id }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "-", with: "_")
    }

    private func keysMatch(_ lhs: String, _ rhs: String) -> Bool { normalized(lhs) == normalized(rhs) }
    private func cleanTags(_ tags: [String]) -> [String] { mergeLines([], tags) }
    private func mergeTags(_ existing: [String]?, _ added: [String]) -> [String] { mergeLines(existing ?? [], cleanTags(added)) }
    private func mergeLines(_ existing: [String], _ added: [String]) -> [String] {
        var output = existing.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var seen = Set(output.map(normalized))
        for value in added {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, seen.insert(normalized(clean)).inserted else { continue }
            output.append(clean)
        }
        return output
    }
    private func mergeText(_ existing: String?, _ added: String) -> String? {
        let old = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let new = added.trimmingCharacters(in: .whitespacesAndNewlines)
        if old.isEmpty { return new.isEmpty ? nil : new }
        if new.isEmpty || normalized(old).contains(normalized(new)) { return old }
        return old + " " + new
    }
}
