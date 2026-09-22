import XCTest
import RPGEngine
import WorldState

final class NarratorTurnValidationTests: XCTestCase {
    func testContaminatedNarratorPacketRejectsUnauthorizedFactsBeforeRendering() {
        let campaign = Campaign(title: "Narrator Validation")
        let road = LocationEntity(name: "Roadside Camp", type: "site", origin: "test")
        campaign.locations = [road]
        campaign.activeLocationId = road.id

        let draft = NarratorTurnDraft(
            responsePurpose: "scene_response",
            directAnswer: "not_applicable",
            renderingBeats: [
                NarratorRenderBeatDraft(text: "Rain taps against the roadside brush.", relatedProposalNames: []),
                NarratorRenderBeatDraft(text: "Thorne opens the Hidden Chamber and offers the Crown of Embers.", relatedProposalNames: ["Thorne", "Hidden Chamber", "Crown of Embers"]),
                NarratorRenderBeatDraft(text: "You feel compelled to trust Thorne.", relatedProposalNames: ["Hazel trusts Thorne"])
            ],
            nextPrompt: "What do you do?",
            proposedDeltas: [
                proposal(type: "npc", name: "Thorne", summary: "A new stranger appears."),
                proposal(type: "location_transition", name: "Hidden Chamber", summary: "The player is moved into a chamber."),
                proposal(type: "location_feature", name: "Hidden Chamber", summary: "A concealed chamber appears.", visibility: "hidden_gm"),
                proposal(type: "item", name: "Crown of Embers", summary: "A valuable crown appears."),
                proposal(type: "player_motive", name: "Hazel trusts Thorne", summary: "Hazel feels compelled to trust the stranger.")
            ]
        )

        let result = NarratorTurnValidator().validate(draft, campaign: campaign)

        XCTAssertTrue(result.acceptedChanges.isEmpty)
        XCTAssertEqual(Set(result.rejectedChanges.map(\.name)), [
            "Crown of Embers", "Hazel trusts Thorne", "Hidden Chamber", "Thorne"
        ])
        let approvedText = result.approvedPacket.renderingBeats.joined(separator: " ")
        XCTAssertEqual(approvedText, "Rain taps against the roadside brush.")
        XCTAssertFalse(approvedText.contains("Thorne"))
        XCTAssertFalse(approvedText.contains("Hidden Chamber"))
        XCTAssertFalse(approvedText.contains("Crown of Embers"))
        XCTAssertFalse(approvedText.contains("compelled"))
        XCTAssertTrue(campaign.npcs.isEmpty)
        XCTAssertEqual(campaign.activeLocationId, road.id)
    }

    func testKnownEntityUpdateCanReachApprovedRenderingPacket() {
        let campaign = Campaign(title: "Known Entity Update")
        let road = LocationEntity(name: "Roadside Camp", type: "site", origin: "test")
        let npc = NPCEntry(name: "Mara Vell", species: "Human", roleTag: "Guide", origin: "test")
        npc.currentLocationId = road.id
        campaign.locations = [road]
        campaign.activeLocationId = road.id
        campaign.npcs = [npc]

        let draft = NarratorTurnDraft(
            responsePurpose: "scene_response",
            directAnswer: "not_applicable",
            renderingBeats: [
                NarratorRenderBeatDraft(text: "Mara Vell raises a hand in warning.", relatedProposalNames: ["Mara Vell"])
            ],
            nextPrompt: "What do you do?",
            proposedDeltas: [
                WorldEntityChangeDraft(
                    entityType: "npc",
                    operation: "update",
                    name: "Mara Vell",
                    summary: "Mara Vell is visibly alarmed.",
                    tags: ["reaction"],
                    confidence: 95,
                    isPresentNow: true,
                    relatedLocationName: "Roadside Camp",
                    reason: "Visible reaction in the current scene.",
                    source: "gm_live",
                    visibility: "player_visible",
                    durability: "scene",
                    approval: "engine_required",
                    locationBinding: "Roadside Camp",
                    entityBinding: "Mara Vell",
                    discoveryStatus: "known"
                )
            ]
        )

        let result = NarratorTurnValidator().validate(draft, campaign: campaign)

        XCTAssertEqual(result.acceptedChanges.map(\.name), ["Mara Vell"])
        XCTAssertTrue(result.rejectedChanges.isEmpty)
        XCTAssertEqual(result.approvedPacket.renderingBeats, ["Mara Vell raises a hand in warning."])
    }

    private func proposal(
        type: String,
        name: String,
        summary: String,
        visibility: String = "player_visible"
    ) -> WorldEntityChangeDraft {
        WorldEntityChangeDraft(
            entityType: type,
            operation: "create",
            name: name,
            summary: summary,
            confidence: 95,
            isPresentNow: true,
            reason: "Narrator proposal.",
            source: "gm_live",
            visibility: visibility,
            durability: "campaign",
            approval: "engine_required",
            locationBinding: "Roadside Camp",
            discoveryStatus: "proposed"
        )
    }
}
