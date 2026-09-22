import XCTest
import RPGEngine
import WorldState

final class QuestionAndOutputContractTests: XCTestCase {
    func testKnownHiddenDoorIsAnsweredFromCanonicalFeaturesWithoutCheck() {
        let campaign = outdoorCampaign()
        let node = campaign.locations?.first?.nodes?.first
        node?.features = [
            LocationFeature(name: "Root-Covered Trapdoor", summary: "A discovered wooden trapdoor remains closed.", category: "door", tags: ["hidden", "discovered"], locationNodeId: node?.id)
        ]

        let result = CampaignStateQueryEngine().answer(.hiddenDoor, campaign: campaign)

        XCTAssertEqual(result.directAnswer, .yes)
        XCTAssertNil(result.checkRequest)
        XCTAssertTrue(result.playerVisibleFacts.joined().contains("Root-Covered Trapdoor"))
    }

    func testUnknownHiddenDoorRequiresCheckWithoutInventingTarget() {
        let campaign = outdoorCampaign()

        let result = CampaignStateQueryEngine().answer(.hiddenDoor, campaign: campaign)

        XCTAssertEqual(result.directAnswer, .checkRequired)
        XCTAssertEqual(result.checkRequest?.skillName, "Investigation")
        XCTAssertFalse(result.playerVisibleFacts.joined().lowercased().contains("assassin"))
        XCTAssertTrue(campaign.npcs.isEmpty)
    }

    func testMetaThreatSummaryHasZeroCanonicalStateDiff() {
        let campaign = outdoorCampaign()
        let before = SceneCanonSnapshot(campaign: campaign)

        let result = CampaignStateQueryEngine().answer(.metaThreatSummary, campaign: campaign)

        XCTAssertEqual(result.directAnswer, .notApplicable)
        XCTAssertTrue(result.proposedEvents.isEmpty)
        XCTAssertEqual(SceneCanonSnapshot(campaign: campaign), before)
    }

    func testDirectAnswerMustRenderFirst() {
        let packet = ApprovedNarrationPacket(
            responsePurpose: .directQuestion,
            directAnswer: .no,
            renderingBeats: ["No person is visible on the road."],
            nextPrompt: "What do you do?",
            approvedFactNames: []
        )
        let validator = NarratorOutputContractValidator()

        XCTAssertTrue(validator.validate("No.\n\nNo person is visible on the road.\n\nWhat do you do?", packet: packet, context: .outdoorSolo).isValid)
        XCTAssertFalse(validator.validate("Rain crosses the road. No one is visible.", packet: packet, context: .outdoorSolo).isValid)
    }

    func testSoloLanguageRejectsImpliedAlliesButAllowsExplicitAbsence() {
        let validator = NarratorOutputContractValidator()
        let packet = ApprovedNarrationPacket(
            responsePurpose: .sceneResponse,
            directAnswer: .notApplicable,
            renderingBeats: [],
            nextPrompt: "What do you do?",
            approvedFactNames: []
        )

        XCTAssertFalse(validator.validate("The party presses on. What do you do?", packet: packet, context: .outdoorSolo).isValid)
        XCTAssertTrue(validator.validate("No companions are present. What do you do?", packet: packet, context: .outdoorSolo).isValid)
    }

    func testOutdoorSceneRejectsUnestablishedWindows() {
        let packet = ApprovedNarrationPacket(
            responsePurpose: .sceneResponse,
            directAnswer: .notApplicable,
            renderingBeats: [],
            nextPrompt: "What do you do?",
            approvedFactNames: []
        )
        let result = NarratorOutputContractValidator().validate(
            "Rain rattles the windows. What do you do?",
            packet: packet,
            context: .outdoorSolo
        )

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.violations.contains(.sceneContamination))
    }

    func testOpenTableDefaultAndGuidedLimitsSuggestions() {
        let composer = PlayerPromptComposer()

        XCTAssertEqual(composer.prompt(mode: .openTable, suggestions: ["Inspect", "Leave"]), "What do you do?")
        XCTAssertEqual(
            composer.prompt(mode: .guided, suggestions: ["Inspect", "Leave", "Listen", "Rest"]),
            "You could inspect, leave, or listen - or try something else. What do you do?"
        )
    }

    func testNarrationFailurePolicyRetriesOnceThenFallsBack() {
        let policy = NarrationFailurePolicy(maximumRetries: 1)

        XCTAssertEqual(policy.action(afterValidationFailures: 1), .retry)
        XCTAssertEqual(policy.action(afterValidationFailures: 2), .fallback)
        XCTAssertEqual(
            policy.safeFallback(knownState: ["cold storm", "roadside camp"]),
            "The narrator could not safely add detail. Known state: cold storm; roadside camp. What do you do?"
        )
    }

    private func outdoorCampaign() -> Campaign {
        let campaign = Campaign(title: "Question contract")
        let location = LocationEntity(name: "Roadside Camp", type: "route", tags: ["outdoors"], origin: "test")
        let node = LocationNode(type: "road", summary: "An exposed road", discovered: true, origin: "test", tags: ["outdoors"])
        location.nodes = [node]
        campaign.locations = [location]
        campaign.activeLocationId = location.id
        campaign.activeNodeId = node.id
        campaign.party = Party(name: "Hazel", members: [PartyMember(name: "Hazel", role: "player", isNpc: false)])
        return campaign
    }
}
