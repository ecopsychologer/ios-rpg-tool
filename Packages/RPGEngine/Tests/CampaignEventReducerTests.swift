import XCTest
import RPGEngine
import WorldState

final class CampaignEventReducerTests: XCTestCase {
    func testApprovedEventMutatesStateAndPersistsReplayMetadata() {
        let campaign = campaignAtRoad()
        let event = makeEvent(name: "Mara Vell")

        let result = CampaignReducer().apply(event, to: campaign)

        XCTAssertEqual(result.status, .applied)
        XCTAssertEqual(campaign.npcs.map(\.name), ["Mara Vell"])
        let log = campaign.eventLog?.last
        XCTAssertEqual(log?.eventId, event.id)
        XCTAssertEqual(log?.eventType, CampaignEventType.worldDelta.rawValue)
        XCTAssertEqual(log?.eventSource, CampaignEventSource.engine.rawValue)
        XCTAssertNotNil(log?.eventPayloadJSON)
    }

    func testRejectedEventMutatesNothingAndIsNotPersisted() {
        let campaign = campaignAtRoad()
        let before = SceneCanonSnapshot(campaign: campaign)
        var event = makeEvent(name: "Rumored Stranger")
        event.payload.operation = WorldDeltaOperation.reference.rawValue

        let result = CampaignReducer().apply(event, to: campaign)

        XCTAssertEqual(result.status, .rejected)
        XCTAssertEqual(SceneCanonSnapshot(campaign: campaign), before)
        XCTAssertTrue(campaign.eventLog?.isEmpty ?? true)
    }

    func testDuplicateEventIsIdempotent() {
        let campaign = campaignAtRoad()
        let event = makeEvent(name: "Mara Vell")
        let reducer = CampaignReducer()

        let first = reducer.apply(event, to: campaign)
        let second = reducer.apply(event, to: campaign)

        XCTAssertEqual(first.status, .applied)
        XCTAssertEqual(second.status, .duplicate)
        XCTAssertEqual(campaign.npcs.map(\.name), ["Mara Vell"])
        XCTAssertEqual(campaign.eventLog?.filter { $0.eventId == event.id }.count, 1)
    }

    func testReplayProducesEquivalentCanonicalState() throws {
        let original = campaignAtRoad()
        let events = [
            makeEvent(name: "Mara Vell"),
            CampaignEvent(
                type: .worldDelta,
                payload: CampaignEventPayload(
                    entityType: WorldDeltaEntityKind.lore.rawValue,
                    operation: WorldDeltaOperation.create.rawValue,
                    name: "Storm Marks",
                    summary: "Storm marks warn travelers away from exposed ground.",
                    tags: ["weather", "warning"]
                ),
                metadata: CampaignEventMetadata(source: .engine, visibility: .playerVisible, durability: .campaign, approval: .engineRequired)
            )
        ]
        let reducer = CampaignReducer()
        events.forEach { _ = reducer.apply($0, to: original) }

        let encodedLogs = try XCTUnwrap(original.eventLog)
        let replayEvents = CampaignEventStore().events(from: encodedLogs)
        let replayed = campaignAtRoad()
        replayEvents.forEach { _ = reducer.apply($0, to: replayed, persistEvent: false) }

        XCTAssertEqual(replayed.npcs.map(\.name), original.npcs.map(\.name))
        XCTAssertEqual(replayed.worldLore.map(\.title), original.worldLore.map(\.title))
        XCTAssertEqual(activeLocationName(replayed), activeLocationName(original))
    }

    func testLegacyLogEntryLoadsWithoutBecomingAnEvent() {
        let legacy = EventLogEntry(summary: "Legacy movement note", origin: "system")

        let events = CampaignEventStore().events(from: [legacy])

        XCTAssertTrue(events.isEmpty)
    }

    func testWorldDeltaEngineRoutesAcceptedChangeThroughReducer() {
        let campaign = campaignAtRoad()
        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "npc",
                operation: "create",
                name: "Mara Vell",
                summary: "Mara Vell is a guide waiting beside the road.",
                tags: ["guide"],
                confidence: 95,
                isPresentNow: true,
                reason: "Approved engine creation.",
                source: "engine",
                visibility: "player_visible",
                durability: "campaign",
                approval: "engine_required",
                locationBinding: "Roadside Camp",
                discoveryStatus: "discovered"
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertEqual(result.accepted.map(\.name), ["Mara Vell"])
        XCTAssertEqual(campaign.npcs.map(\.name), ["Mara Vell"])
        XCTAssertEqual(campaign.eventLog?.last?.eventType, CampaignEventType.worldDelta.rawValue)
    }

    private func campaignAtRoad() -> Campaign {
        let campaign = Campaign(title: "Event Test")
        let road = LocationEntity(name: "Roadside Camp", type: "site", origin: "test")
        let node = LocationNode(type: "exterior", summary: "A camp beside the road", discovered: true, origin: "test")
        road.nodes = [node]
        campaign.locations = [road]
        campaign.activeLocationId = road.id
        campaign.activeNodeId = node.id
        return campaign
    }

    private func makeEvent(name: String) -> CampaignEvent {
        CampaignEvent(
            type: .worldDelta,
            payload: CampaignEventPayload(
                entityType: WorldDeltaEntityKind.npc.rawValue,
                operation: WorldDeltaOperation.create.rawValue,
                name: name,
                summary: "\(name) is a guide waiting beside the road.",
                tags: ["guide"],
                isPresentNow: true,
                relatedLocationName: "Roadside Camp"
            ),
            metadata: CampaignEventMetadata(
                source: .engine,
                visibility: .playerVisible,
                durability: .campaign,
                approval: .engineRequired,
                locationBinding: "Roadside Camp"
            )
        )
    }

    private func activeLocationName(_ campaign: Campaign) -> String? {
        guard let id = campaign.activeLocationId else { return nil }
        return campaign.locations?.first(where: { $0.id == id })?.name
    }
}
