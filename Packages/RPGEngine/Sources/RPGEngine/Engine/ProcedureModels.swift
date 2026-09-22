import Foundation
import WorldState

public struct TravelRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let originNodeID: UUID?
    public let destinationName: String?
    public let routeLabel: String?
    public let intendedHours: Int
    public let weather: String?

    public init(
        id: UUID = UUID(),
        originNodeID: UUID? = nil,
        destinationName: String? = nil,
        routeLabel: String? = nil,
        intendedHours: Int,
        weather: String? = nil
    ) {
        self.id = id
        self.originNodeID = originNodeID
        self.destinationName = destinationName
        self.routeLabel = routeLabel
        self.intendedHours = max(0, intendedHours)
        self.weather = weather
    }
}

public enum TravelResolutionKind: String, Codable, Sendable {
    case roll
    case noRollTransition = "no_roll_transition"
    case blockedMovement = "blocked_movement"
    case routeChoice = "route_choice"
    case timeResourceUpdate = "time_resource_update"
}

public enum TravelResolutionRoute: Sendable {
    case roll(StakesOutcome)
    case noRollTransition
    case blocked(String)
    case routeChoice
    case timeResourceUpdate
}

public struct TravelResolution: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let requestID: UUID
    public let resolutionKind: TravelResolutionKind
    public let outcome: StakesOutcome?
    public let progress: Int
    public let timeHours: Int
    public let exposure: Int
    public let delay: Int
    public let encounterRisk: Int
    public let detail: String?

    public init(
        id: UUID = UUID(),
        requestID: UUID,
        resolutionKind: TravelResolutionKind,
        outcome: StakesOutcome? = nil,
        progress: Int,
        timeHours: Int,
        exposure: Int,
        delay: Int,
        encounterRisk: Int,
        detail: String? = nil
    ) {
        self.id = id
        self.requestID = requestID
        self.resolutionKind = resolutionKind
        self.outcome = outcome
        self.progress = progress
        self.timeHours = timeHours
        self.exposure = exposure
        self.delay = delay
        self.encounterRisk = encounterRisk
        self.detail = detail
    }
}

public struct TravelProcedureEngine: Sendable {
    public init() {}

    public func resolve(_ request: TravelRequest, route: TravelResolutionRoute) -> TravelResolution {
        switch route {
        case .roll(let outcome):
            switch outcome {
            case .criticalSuccess:
                return travel(request, outcome, progress: 3, exposure: 0, delay: 0, risk: -1)
            case .success:
                return travel(request, outcome, progress: 2, exposure: 0, delay: 0, risk: 0)
            case .partialSuccess:
                return travel(request, outcome, progress: 1, exposure: 1, delay: 1, risk: 1)
            case .failure:
                return travel(request, outcome, progress: 0, exposure: 1, delay: 1, risk: 2)
            case .criticalFailure:
                return travel(request, outcome, progress: 0, exposure: 2, delay: 2, risk: 3)
            }
        case .noRollTransition:
            return TravelResolution(requestID: request.id, resolutionKind: .noRollTransition, progress: 1, timeHours: request.intendedHours, exposure: 0, delay: 0, encounterRisk: 0)
        case .blocked(let reason):
            return TravelResolution(requestID: request.id, resolutionKind: .blockedMovement, progress: 0, timeHours: 0, exposure: 0, delay: 0, encounterRisk: 0, detail: reason)
        case .routeChoice:
            return TravelResolution(requestID: request.id, resolutionKind: .routeChoice, progress: 0, timeHours: 0, exposure: 0, delay: 0, encounterRisk: 0)
        case .timeResourceUpdate:
            return TravelResolution(requestID: request.id, resolutionKind: .timeResourceUpdate, progress: 0, timeHours: request.intendedHours, exposure: 0, delay: 0, encounterRisk: 0)
        }
    }

    private func travel(_ request: TravelRequest, _ outcome: StakesOutcome, progress: Int, exposure: Int, delay: Int, risk: Int) -> TravelResolution {
        TravelResolution(
            requestID: request.id,
            resolutionKind: .roll,
            outcome: outcome,
            progress: progress,
            timeHours: request.intendedHours,
            exposure: exposure,
            delay: delay,
            encounterRisk: risk
        )
    }
}

public enum RestKind: String, Codable, Sendable { case short, long }
public enum RestShelter: String, Codable, Sendable { case none, improvised, secure }
public enum RestWatch: String, Codable, Sendable { case none, soloPassive = "solo_passive", active, companion }
public enum RestFire: String, Codable, Sendable { case noFire = "no_fire", small, full }
public enum RestDetail: String, Codable, Hashable, Sendable { case kind, shelter, watch, fire }
public enum RestRecovery: String, Codable, Sendable { case none, partial, full }

public struct RestPlan: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let kind: RestKind?
    public let locationName: String
    public let shelter: RestShelter?
    public let watch: RestWatch?
    public let fire: RestFire?
    public let suppliesAvailable: Int

    public init(id: UUID = UUID(), kind: RestKind?, locationName: String, shelter: RestShelter? = nil, watch: RestWatch? = nil, fire: RestFire? = nil, suppliesAvailable: Int = 0) {
        self.id = id
        self.kind = kind
        self.locationName = locationName
        self.shelter = shelter
        self.watch = watch
        self.fire = fire
        self.suppliesAvailable = max(0, suppliesAvailable)
    }
}

public struct RestResolution: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let planID: UUID
    public let timeHours: Int
    public let recovery: RestRecovery
    public let suppliesConsumed: Int
    public let exposure: Int
    public let watchRisk: Int
    public let interrupted: Bool
}

public struct RestProcedureEngine: Sendable {
    public init() {}

    public func missingDetails(_ plan: RestPlan) -> [RestDetail] {
        var missing: [RestDetail] = []
        if plan.kind == nil { missing.append(.kind) }
        if plan.shelter == nil { missing.append(.shelter) }
        if plan.watch == nil { missing.append(.watch) }
        if plan.fire == nil { missing.append(.fire) }
        return missing
    }

    public func resolve(_ plan: RestPlan, interrupted: Bool, severeWeather: Bool) -> RestResolution {
        let kind = plan.kind ?? .short
        let hours = kind == .long ? 8 : 1
        let consumed = plan.suppliesAvailable > 0 ? 1 : 0
        let shelterExposure = severeWeather && plan.shelter != .secure ? 1 : 0
        let watchRisk: Int
        switch plan.watch {
        case .active, .companion: watchRisk = 0
        case .soloPassive: watchRisk = 1
        case .some(.none), nil: watchRisk = 2
        }
        let recovery: RestRecovery = interrupted ? .partial : (kind == .long ? .full : .partial)
        return RestResolution(
            id: UUID(),
            planID: plan.id,
            timeHours: hours,
            recovery: recovery,
            suppliesConsumed: consumed,
            exposure: shelterExposure,
            watchRisk: watchRisk,
            interrupted: interrupted
        )
    }
}

public enum SearchMode: String, Codable, Sendable { case movingObservation = "moving_observation", closeInvestigation = "close_investigation" }
public enum HiddenSearchTargetKind: String, Codable, Sendable { case feature, edge, trap, clue }
public enum SearchFinding: String, Codable, Sendable { case revealed, clueOnly = "clue_only", notFound = "not_found", noPreparedTarget = "no_prepared_target" }

public struct HiddenSearchTarget: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: HiddenSearchTargetKind
    public let locationID: UUID?
    public let nodeID: UUID?
    public let boundEntityID: UUID

    public init(id: UUID = UUID(), name: String, kind: HiddenSearchTargetKind, locationID: UUID?, nodeID: UUID?, boundEntityID: UUID) {
        self.id = id
        self.name = name
        self.kind = kind
        self.locationID = locationID
        self.nodeID = nodeID
        self.boundEntityID = boundEntityID
    }
}

public struct SearchRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let mode: SearchMode
    public let locationID: UUID?
    public let nodeID: UUID?
    public let skill: String
    public let dc: Int
    public let stakes: String

    public init(id: UUID = UUID(), mode: SearchMode, locationID: UUID?, nodeID: UUID?, skill: String, dc: Int, stakes: String) {
        self.id = id
        self.mode = mode
        self.locationID = locationID
        self.nodeID = nodeID
        self.skill = skill
        self.dc = dc
        self.stakes = stakes
    }
}

public struct SearchResolution: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let requestID: UUID
    public let outcome: StakesOutcome
    public let finding: SearchFinding
    public let revealedTarget: HiddenSearchTarget?
    public var revealedTargetID: UUID? { revealedTarget?.boundEntityID }
}

public struct SearchProcedureEngine: Sendable {
    public init() {}

    public func resolve(_ request: SearchRequest, outcome: StakesOutcome, preparedTargets: [HiddenSearchTarget]) -> SearchResolution {
        let matching = preparedTargets.first { target in
            (target.locationID == nil || target.locationID == request.locationID)
                && (target.nodeID == nil || target.nodeID == request.nodeID)
        }
        guard let target = matching else {
            return SearchResolution(id: UUID(), requestID: request.id, outcome: outcome, finding: .noPreparedTarget, revealedTarget: nil)
        }
        switch outcome {
        case .criticalSuccess, .success:
            return SearchResolution(id: UUID(), requestID: request.id, outcome: outcome, finding: .revealed, revealedTarget: target)
        case .partialSuccess:
            return SearchResolution(id: UUID(), requestID: request.id, outcome: outcome, finding: .clueOnly, revealedTarget: nil)
        case .failure, .criticalFailure:
            return SearchResolution(id: UUID(), requestID: request.id, outcome: outcome, finding: .notFound, revealedTarget: nil)
        }
    }
}

public struct CampaignProcedureState: Codable, Equatable, Sendable {
    public var lastTravelRequest: TravelRequest?
    public var lastTravel: TravelResolution?
    public var lastRestPlan: RestPlan?
    public var lastRest: RestResolution?
    public var lastSearchRequest: SearchRequest?
    public var lastSearch: SearchResolution?
    public var lastCreative: CreativeEvent?

    public init() {}
}

public struct CampaignProcedureStateStore: Sendable {
    public init() {}

    public func load(from campaign: Campaign) -> CampaignProcedureState? {
        guard let json = campaign.procedureStateJSON, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CampaignProcedureState.self, from: data)
    }

    public func save(_ state: CampaignProcedureState, to campaign: Campaign) -> Bool {
        guard let data = try? JSONEncoder().encode(state), let json = String(data: data, encoding: .utf8) else { return false }
        campaign.procedureStateJSON = json
        return true
    }
}

public enum ProcedureEventAction: String, Codable, Sendable {
    case travelRequest = "travel_request"
    case travelResolution = "travel_resolution"
    case restPlan = "rest_plan"
    case restResolution = "rest_resolution"
    case searchRequest = "search_request"
    case searchResolution = "search_resolution"
    case creativeResolution = "creative_resolution"
    case spatialDiscovery = "spatial_discovery"
    case explicitMovement = "explicit_movement"
}

public struct ProcedureEventData: Codable, Equatable, Sendable {
    public let action: ProcedureEventAction
    public var travelRequest: TravelRequest? = nil
    public var travelResolution: TravelResolution? = nil
    public var restPlan: RestPlan? = nil
    public var restResolution: RestResolution? = nil
    public var searchRequest: SearchRequest? = nil
    public var searchResolution: SearchResolution? = nil
    public var edgeID: UUID? = nil
    public var creativeEvent: CreativeEvent? = nil

    public init(action: ProcedureEventAction) { self.action = action }
}
