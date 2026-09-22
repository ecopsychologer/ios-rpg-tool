import XCTest
import RPGEngine
import WorldState

final class ProcedureStateMachineTests: XCTestCase {
    func testPartialTravelTracksProgressTimeExposureDelayAndRiskSeparately() throws {
        let campaign = campaignWithRoadEdge()
        let request = TravelRequest(
            originNodeID: campaign.activeNodeId,
            destinationName: "North marker",
            routeLabel: "North road",
            intendedHours: 3,
            weather: "cold storm"
        )
        let resolution = TravelProcedureEngine().resolve(request, route: .roll(.partialSuccess))
        let event = CampaignEventFactory().travelResolutionEvent(request: request, resolution: resolution)

        XCTAssertEqual(CampaignReducer().apply(event, to: campaign).status, .applied)
        let state = try XCTUnwrap(CampaignProcedureStateStore().load(from: campaign))
        XCTAssertEqual(state.lastTravel?.progress, 1)
        XCTAssertEqual(state.lastTravel?.timeHours, 3)
        XCTAssertEqual(state.lastTravel?.exposure, 1)
        XCTAssertEqual(state.lastTravel?.delay, 1)
        XCTAssertEqual(state.lastTravel?.encounterRisk, 1)
    }

    func testTravelCanResolveAsNoRollTransitionOrBlockedMovement() {
        let request = TravelRequest(destinationName: "Near shelter", intendedHours: 1)
        let engine = TravelProcedureEngine()

        XCTAssertEqual(engine.resolve(request, route: .noRollTransition).resolutionKind, .noRollTransition)
        XCTAssertEqual(engine.resolve(request, route: .blocked("Flooded crossing")).resolutionKind, .blockedMovement)
    }

    func testRestPlanAsksOnlyForMissingDetailsAndResolvesDeterministically() {
        let incomplete = RestPlan(kind: .long, locationName: "Roadside Camp")
        XCTAssertEqual(Set(RestProcedureEngine().missingDetails(incomplete)), Set([.shelter, .watch, .fire]))

        let complete = RestPlan(
            kind: .long,
            locationName: "Roadside Camp",
            shelter: .improvised,
            watch: .soloPassive,
            fire: .noFire,
            suppliesAvailable: 2
        )
        let resolution = RestProcedureEngine().resolve(complete, interrupted: false, severeWeather: true)

        XCTAssertEqual(resolution.timeHours, 8)
        XCTAssertEqual(resolution.recovery, .full)
        XCTAssertEqual(resolution.suppliesConsumed, 1)
        XCTAssertEqual(resolution.exposure, 1)
        XCTAssertFalse(resolution.interrupted)
    }

    func testSearchCannotInventHiddenTargetOnSuccess() {
        let request = SearchRequest(
            mode: .closeInvestigation,
            locationID: UUID(),
            nodeID: UUID(),
            skill: "Investigation",
            dc: 15,
            stakes: "Reveal an existing hidden feature or find no reliable sign."
        )

        let resolution = SearchProcedureEngine().resolve(request, outcome: .success, preparedTargets: [])

        XCTAssertNil(resolution.revealedTargetID)
        XCTAssertEqual(resolution.finding, .noPreparedTarget)
    }

    func testSearchRevealsPreparedTargetWithoutEnteringIt() throws {
        let campaign = campaignWithRoadEdge()
        let edge = try XCTUnwrap(campaign.locations?.first?.edges?.first)
        let target = HiddenSearchTarget(
            name: "Root-Covered Trapdoor",
            kind: .edge,
            locationID: campaign.activeLocationId,
            nodeID: campaign.activeNodeId,
            boundEntityID: edge.id
        )
        let request = SearchRequest(
            mode: .closeInvestigation,
            locationID: campaign.activeLocationId,
            nodeID: campaign.activeNodeId,
            skill: "Investigation",
            dc: 15,
            stakes: "Reveal an existing hidden feature or find no reliable sign."
        )
        let resolution = SearchProcedureEngine().resolve(request, outcome: .success, preparedTargets: [target])
        let event = CampaignEventFactory().searchResolutionEvent(request: request, resolution: resolution)
        let originalNode = campaign.activeNodeId

        XCTAssertEqual(CampaignReducer().apply(event, to: campaign).status, .applied)
        XCTAssertEqual(campaign.activeNodeId, originalNode)
        XCTAssertEqual(edge.discovered, true)
        XCTAssertEqual(edge.opened, false)
    }

    func testExplicitMovementIsRequiredAfterDiscovery() throws {
        let campaign = campaignWithRoadEdge()
        let edge = try XCTUnwrap(campaign.locations?.first?.edges?.first)
        let originalNode = campaign.activeNodeId

        XCTAssertEqual(CampaignReducer().apply(CampaignEventFactory().spatialDiscoveryEvent(edgeID: edge.id), to: campaign).status, .applied)
        XCTAssertEqual(campaign.activeNodeId, originalNode)

        XCTAssertEqual(CampaignReducer().apply(CampaignEventFactory().explicitMovementEvent(edgeID: edge.id), to: campaign).status, .applied)
        XCTAssertEqual(campaign.activeNodeId, edge.toNodeId)
    }

    func testCreativeSolutionIsSeededStraightD20AndEngineBounded() {
        let keywords = ["moon", "outlaw", "rust", "echo", "bridge"].map { CreativeKeyword(word: $0) }
        let engine = CreativeSolutionsEngine()

        let first = engine.resolve(action: "Use the banner as a distraction", roll: 20, keywords: keywords, seed: 42)
        let second = engine.resolve(action: "Use the banner as a distraction", roll: 20, keywords: keywords, seed: 42)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.roll, 20)
        XCTAssertTrue((2...3).contains(first.keywords.count))
        XCTAssertEqual(first.valence, .beneficial)
        XCTAssertTrue(Set(first.mutations).isSubset(of: Set([.sceneFact, .clue, .encounterRisk, .delay])))
        XCTAssertFalse(first.mutations.contains(.npc))
        XCTAssertFalse(first.mutations.contains(.location))
    }

    private func campaignWithRoadEdge() -> Campaign {
        let campaign = Campaign(title: "Procedure test")
        let road = LocationEntity(name: "Roadside Camp", type: "route", origin: "test")
        let start = LocationNode(type: "road", summary: "A storm-swept road", discovered: true, origin: "test")
        let destination = LocationNode(type: "shelter", summary: "A shallow roadside shelter", discovered: false, origin: "test")
        let edge = LocationEdge(type: "trapdoor", label: "Root-Covered Trapdoor", fromNodeId: start.id, toNodeId: destination.id, origin: "test")
        road.nodes = [start, destination]
        road.edges = [edge]
        campaign.locations = [road]
        campaign.activeLocationId = road.id
        campaign.activeNodeId = start.id
        return campaign
    }
}
