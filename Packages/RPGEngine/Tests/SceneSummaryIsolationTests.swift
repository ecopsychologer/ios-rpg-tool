import XCTest
import RPGEngine
import WorldState

final class SceneSummaryIsolationTests: XCTestCase {
    func testSceneFinalizationDoesNotApplySummarySuggestedCanon() {
        let campaign = Campaign(title: "Summary Isolation")
        let location = LocationEntity(name: "Roadside Camp", type: "site", origin: "test")
        let node = LocationNode(type: "exterior", summary: "A camp beside the road", discovered: true, origin: "test")
        location.nodes = [node]
        campaign.locations = [location]
        campaign.activeLocationId = location.id
        campaign.activeNodeId = node.id
        campaign.worldLore = [WorldLoreEntry(title: "Windward Expanse", summary: "Open roads and old ruins.", origin: "test")]

        var engine = SoloCampaignEngine()
        let scene = engine.resolveScene(campaign: campaign, expectedScene: "Travel along the road")
        let before = SceneCanonSnapshot(campaign: campaign)

        let bookkeeping = BookkeepingInput(
            summary: "Thorne emerges beside a hidden palace and offers a new quest.",
            newCharacters: ["Thorne", "Unknown Character"],
            newThreads: ["The Hidden Palace"],
            featuredCharacters: [],
            featuredThreads: [],
            removedCharacters: [],
            removedThreads: [],
            pcsInControl: true,
            concluded: false,
            interactions: [],
            skillChecks: [],
            fateQuestions: [],
            places: ["Hidden Palace"],
            curiosities: ["A jeweled map reveals a secret chamber"],
            rollHighlights: [],
            locationId: location.id,
            generatedEntityIds: [],
            canonizations: []
        )

        _ = engine.finalizeScene(campaign: campaign, scene: scene, bookkeeping: bookkeeping)

        XCTAssertEqual(SceneCanonSnapshot(campaign: campaign), before)
        XCTAssertTrue(campaign.npcs.isEmpty)
        XCTAssertEqual(location.name, "Roadside Camp")
        XCTAssertNil(node.contentSummary)
        XCTAssertEqual(campaign.scenes.count, 1, "Scene finalization may still append its read-only scene record.")
    }

    func testSummaryValidatorRejectsUnknownEntityReferences() {
        let campaign = Campaign(title: "Summary Validator")
        campaign.playerCharacters = [PlayerCharacter(displayName: "Hazel Woods")]
        campaign.worldLore = [WorldLoreEntry(title: "Windward Expanse", summary: "Known campaign lore.", origin: "test")]
        let snapshot = SceneCanonSnapshot(campaign: campaign)
        let draft = SceneSummaryDraft(
            summary: "Hazel crosses the Windward Expanse. Thorne emerges from the shadows.",
            entityReferences: [
                SceneSummaryReference(name: "Hazel Woods"),
                SceneSummaryReference(name: "Windward Expanse"),
                SceneSummaryReference(name: "Thorne")
            ],
            threadReferences: [],
            rollHighlights: []
        )

        let result = SceneSummaryValidator().validate(draft, against: snapshot)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.unknownReferences, ["Thorne"])
    }

    func testSummaryValidatorAllowsApprovedHiddenEntityIDWithoutExposingItsName() {
        let hiddenID = UUID()
        let campaign = Campaign(title: "Hidden Summary Reference")
        let snapshot = SceneCanonSnapshot(campaign: campaign, approvedHiddenEntityIDs: [hiddenID])
        let draft = SceneSummaryDraft(
            summary: "An unresolved hidden pressure remains active.",
            entityReferences: [
                SceneSummaryReference(name: "Hidden pressure", entityID: hiddenID.uuidString)
            ],
            threadReferences: [],
            rollHighlights: []
        )

        let result = SceneSummaryValidator().validate(draft, against: snapshot)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.unknownReferences.isEmpty)
    }
}
