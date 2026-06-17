import XCTest
import RPGEngine
import WorldState

final class WorldDeltaEngineTests: XCTestCase {
    func testAppliesHighConfidenceNarratorCreations() {
        let campaign = Campaign(title: "Delta Test")
        let location = LocationEntity(name: "Glass Market", type: "settlement", tags: ["market"])
        let node = LocationNode(type: "district", summary: "A rain-bright plaza", discovered: true, origin: "test")
        location.nodes = [node]
        campaign.locations = [location]
        campaign.activeLocationId = location.id
        campaign.activeNodeId = node.id

        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "npc",
                operation: "create",
                name: "Mara Vell",
                summary: "Mara Vell is a cautious informant who trades in dock rumors.",
                tags: ["informant", "dock"],
                confidence: 90,
                isPresentNow: true
            ),
            WorldEntityChangeDraft(
                entityType: "item",
                operation: "create",
                name: "Brass Compass",
                summary: "The compass needle points toward recent lies.",
                tags: ["relic", "truth"],
                confidence: 88,
                isPresentNow: true
            ),
            WorldEntityChangeDraft(
                entityType: "location_feature",
                operation: "create",
                name: "Bell Tower",
                summary: "A cracked bell tower overlooks the plaza.",
                tags: ["landmark"],
                confidence: 82,
                isPresentNow: true
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertEqual(result.accepted.count, 3)
        XCTAssertEqual(campaign.npcs.first?.name, "Mara Vell")
        XCTAssertEqual(campaign.npcs.first?.currentLocationId, location.id)
        XCTAssertEqual(campaign.items.first?.name, "Brass Compass")
        XCTAssertEqual(campaign.items.first?.ownerId, location.id)
        XCTAssertEqual(node.features?.first?.name, "Bell Tower")
    }

    func testRejectsReferencesAndLowConfidenceChanges() {
        let campaign = Campaign(title: "Reject Test")
        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "npc",
                operation: "reference",
                name: "Old Captain",
                summary: "The old captain is mentioned as a rumor.",
                confidence: 95
            ),
            WorldEntityChangeDraft(
                entityType: "creature",
                operation: "create",
                name: "Mist Hound",
                summary: "Something like a hound may be in the fog.",
                confidence: 30
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.rejected.count, 2)
        XCTAssertTrue(campaign.npcs.isEmpty)
        XCTAssertTrue(campaign.creatures.isEmpty)
    }

    func testRelevantContextPrioritizesActiveAndKeywordMatches() {
        let campaign = Campaign(title: "Relevance Test")
        let market = LocationEntity(name: "Glass Market", type: "settlement", tags: ["market", "glass"])
        campaign.locations = [market]
        campaign.activeLocationId = market.id
        campaign.worldLore.append(WorldLoreEntry(
            title: "Glass Guild",
            summary: "The guild controls mirror trade and pays spies in silver.",
            tags: ["glass", "spies"],
            origin: "test",
            relatedLocationId: market.id
        ))
        campaign.items.append(ItemEntry(
            name: "Mirror Token",
            category: "relic",
            properties: ["glass", "guild"],
            detailLines: ["A token carried by guild spies."],
            source: "test",
            ownerId: market.id,
            ownerKind: "location"
        ))

        let context = WorldDeltaEngine().relevantContext(
            for: campaign,
            focusText: "Who in the glass market knows about spies?",
            limit: 2
        )

        XCTAssertTrue(context.locations.contains { $0.contains("Glass Market") })
        XCTAssertTrue(context.lore.contains { $0.contains("Glass Guild") })
        XCTAssertTrue(context.items.contains { $0.contains("Mirror Token") })
    }
}
