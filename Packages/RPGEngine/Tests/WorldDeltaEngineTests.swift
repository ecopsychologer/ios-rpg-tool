import XCTest
import RPGEngine
import TableEngine
import WorldState

final class WorldDeltaEngineTests: XCTestCase {
    func testBareDiceSpecsStayWithinTheirDieRange() {
        var d20Roller = DiceRoller(seed: 42, sequence: 0)
        for _ in 0..<100 {
            let roll = d20Roller.roll(spec: "d20")
            XCTAssertEqual(roll.spec, "d20")
            XCTAssertEqual(roll.rolls.count, 1)
            XCTAssertTrue((1...20).contains(roll.total), "d20 produced \(roll.total)")
        }

        var d100Roller = DiceRoller(seed: 42, sequence: 0)
        for _ in 0..<100 {
            let roll = d100Roller.roll(spec: "d100")
            XCTAssertEqual(roll.spec, "d100")
            XCTAssertEqual(roll.rolls.count, 1)
            XCTAssertTrue((1...100).contains(roll.total), "d100 produced \(roll.total)")
        }
    }

    func testDiceSpecsSupportImplicitOneDieAndModifiers() throws {
        let d20 = try XCTUnwrap(DiceSpec.parse("d20"))
        XCTAssertEqual(d20.count, 1)
        XCTAssertEqual(d20.sides, 20)
        XCTAssertEqual(d20.modifier, 0)

        let d6Plus = try XCTUnwrap(DiceSpec.parse("2d6+3"))
        XCTAssertEqual(d6Plus.count, 2)
        XCTAssertEqual(d6Plus.sides, 6)
        XCTAssertEqual(d6Plus.modifier, 3)

        let d12Minus = try XCTUnwrap(DiceSpec.parse("d12-1"))
        XCTAssertEqual(d12Minus.count, 1)
        XCTAssertEqual(d12Minus.sides, 12)
        XCTAssertEqual(d12Minus.modifier, -1)
    }

    func testRulesContentUsesImportOrFallbackWithoutBundledSource() throws {
        let index = try XCTUnwrap(SrdContentStore().loadIndex())

        XCTAssertFalse(index.source.lowercased().contains("bundled"))
        XCTAssertGreaterThanOrEqual(index.abilities.count, 6)
        XCTAssertGreaterThanOrEqual(index.skills.count, 18)
    }

    func testDevRulesFixtureLoadsFromEnvironmentWhenConfigured() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SOLO_RPG_RULES_PREFER_DEV"] == "1",
              let path = environment["SOLO_RPG_RULES_JSON"],
              FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("No dev rules fixture configured.")
        }

        let index = try XCTUnwrap(SrdContentStore().loadIndex())

        XCTAssertTrue(index.source.lowercased().contains("dev"))
        XCTAssertFalse(index.classes.isEmpty)
        XCTAssertFalse(index.equipment.isEmpty)
        XCTAssertFalse(index.conditions.isEmpty)
    }

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

    func testRejectsHiddenOrVagueNarratorEntities() {
        let campaign = Campaign(title: "Hidden Entity Reject Test")
        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "npc",
                operation: "create",
                name: "The Unseen Adversary",
                summary: "What you don't see is an unseen adversary following the party.",
                tags: ["hidden", "enemy"],
                confidence: 95,
                isPresentNow: true,
                reason: "Narration implied a hidden enemy."
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.rejected.first?.reason, "Hidden or vague narrator phrasing is not durable world state.")
        XCTAssertTrue(campaign.npcs.isEmpty)
    }

    func testRejectsNarratorCreatedLocationsWithoutEngineDiscovery() {
        let campaign = Campaign(title: "Location Reject Test")
        let road = LocationEntity(name: "Roadside Camp", type: "road", origin: "test")
        campaign.locations = [road]
        campaign.activeLocationId = road.id

        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "location",
                operation: "create",
                name: "Flicker Cave",
                summary: "A cave is suggested by distant light near the road.",
                tags: ["cave"],
                confidence: 90,
                isPresentNow: true
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.rejected.first?.reason, "New locations require an engine transition or explicit discovery before storage.")
        XCTAssertEqual(campaign.locations?.map(\.name), ["Roadside Camp"])
        XCTAssertEqual(campaign.activeLocationId, road.id)
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
