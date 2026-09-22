import XCTest
import RPGEngine
import WorldState

final class AuthorityAndStakesTests: XCTestCase {
    func testPlayerInputSeparatesCharacterIntentFromWeatherAssumption() {
        let parsed = PlayerAuthorityParser().parse("We travel the road at night in a storm for the next few hours.")

        XCTAssertTrue(parsed.characterIntent.lowercased().contains("travel the road"))
        XCTAssertFalse(parsed.characterIntent.lowercased().contains("storm"))
        XCTAssertEqual(parsed.worldAssumptions.count, 1)
        XCTAssertEqual(parsed.worldAssumptions.first?.kind, .weather)
        XCTAssertEqual(parsed.worldAssumptions.first?.proposedValue, "storm")
        XCTAssertEqual(parsed.worldAssumptions.first?.status, .proposed)
    }

    func testWeatherAuthorityCanAcceptSoftenOrRejectInSameTurn() {
        let assumption = WorldAssumption(kind: .weather, proposedValue: "violent storm", sourceText: "in a violent storm")
        let authority = WorldAuthorityEngine()

        XCTAssertEqual(authority.adjudicateWeather(assumption, policy: .acceptPlausible).resolution, .accepted)
        XCTAssertEqual(authority.adjudicateWeather(assumption, policy: .softenExtreme).resolution, .softened)
        XCTAssertEqual(authority.adjudicateWeather(assumption, policy: .preserveEstablished).resolution, .rejected)
    }

    func testAcceptedWeatherEventPersistsCanonicalWeather() throws {
        let campaign = Campaign(title: "Weather authority")
        let decision = WeatherAuthorityDecision(
            proposedWeather: "storm",
            canonicalWeather: "cold storm",
            resolution: .softened,
            rationale: "The GM establishes a cold storm without hurricane-force conditions."
        )
        let event = CampaignEventFactory().weatherAuthorityEvent(decision: decision)

        let result = CampaignReducer().apply(event, to: campaign)
        let state = try XCTUnwrap(CampaignAuthorityStateStore().load(from: campaign))

        XCTAssertEqual(result.status, .applied)
        XCTAssertEqual(state.weather, "cold storm")
        XCTAssertEqual(state.weatherDecision, .softened)
    }

    func testHiddenThreatEventCreatesClockWithoutCreatingNPC() throws {
        let campaign = Campaign(title: "Hidden pressure")
        let event = CampaignEventFactory().hiddenThreatEvent(
            HiddenThreatRecord(label: "Movement beyond the brush", kind: .clue, clockCurrent: 1, clockMaximum: 4)
        )

        let result = CampaignReducer().apply(event, to: campaign)
        let state = try XCTUnwrap(CampaignAuthorityStateStore().load(from: campaign))

        XCTAssertEqual(result.status, .applied)
        XCTAssertTrue(campaign.npcs.isEmpty)
        XCTAssertEqual(state.hiddenThreats.map(\.label), ["Movement beyond the brush"])
        XCTAssertFalse(state.hiddenThreats.contains { $0.label == "Unknown Character" })
    }

    func testPersonalAssumptionsRequirePlayerConfirmation() {
        let cases: [(String, WorldAssumptionKind)] = [
            ("My sidekick watches the rear.", .companion),
            ("I grew up in this ruined keep.", .characterHistory),
            ("Hazel wants revenge.", .motive),
            ("Hazel feels terrified.", .feeling),
            ("I swear I will never leave this road.", .commitment)
        ]

        for (text, expectedKind) in cases {
            let parsed = PlayerAuthorityParser().parse(text)
            let assumption = parsed.worldAssumptions.first { $0.kind == expectedKind }
            XCTAssertEqual(assumption?.requiresPlayerConfirmation, true, text)
        }
    }

    func testNaturalTwentyUsesBestPlausibleDeclaredResult() {
        let stakes = DeclaredStakes(
            success: "The banner distracts any watcher long enough to improve the approach.",
            partial: "The banner draws attention but is lost.",
            failure: "The banner tangles and reveals movement.",
            criticalSuccess: "The distraction grants advantage on the next Stealth check.",
            criticalFailure: "The banner exposes the approach and increases risk.",
            allowedMutations: [.sceneFact, .clue],
            forbiddenMutations: [.npc, .location, .treasure, .playerChoice]
        )

        let resolution = StakesResolver().resolve(
            roll: 20,
            ordinaryOutcome: .success,
            stakes: stakes,
            proposedMutations: [.sceneFact, .npc, .location]
        )

        XCTAssertEqual(resolution.outcome, .criticalSuccess)
        XCTAssertEqual(resolution.consequence, stakes.criticalSuccess)
        XCTAssertEqual(resolution.approvedMutations, [.sceneFact])
        XCTAssertEqual(Set(resolution.rejectedMutations), Set([.npc, .location]))
    }

    func testLorePartialCannotCreateConsequencesOutsideLockedStakes() {
        let stakes = DeclaredStakes(
            success: "The symbol matches a known Windward Expanse warding tradition.",
            partial: "The symbol broadly resembles protective magic, but its origin remains unknown.",
            failure: "The symbol remains unidentified.",
            criticalSuccess: "The symbol's protective purpose and regional tradition are identified.",
            criticalFailure: "The symbol remains unidentified.",
            allowedMutations: [.clue, .lore],
            forbiddenMutations: [.map, .location, .quest, .treasure, .npc]
        )

        let resolution = StakesResolver().resolve(
            roll: 12,
            ordinaryOutcome: .partialSuccess,
            stakes: stakes,
            proposedMutations: [.clue, .map, .location, .quest, .treasure, .npc]
        )

        XCTAssertEqual(resolution.consequence, stakes.partial)
        XCTAssertEqual(resolution.approvedMutations, [.clue])
        XCTAssertEqual(Set(resolution.rejectedMutations), Set([.map, .location, .quest, .treasure, .npc]))
    }

    func testGenericUnknownCharacterWorldDeltaIsRejected() {
        let campaign = Campaign(title: "Unknowns")
        let draft = WorldDeltaDraft(changes: [
            WorldEntityChangeDraft(
                entityType: "npc",
                operation: "create",
                name: "Unknown Character",
                summary: "Someone may be watching from beyond the brush.",
                confidence: 95,
                reason: "Unconfirmed hidden pressure.",
                source: "engine",
                visibility: "hidden_gm",
                durability: "scene",
                approval: "engine_required",
                discoveryStatus: "hidden"
            )
        ])

        let result = WorldDeltaEngine().applyWorldDelta(draft, to: campaign)

        XCTAssertTrue(result.accepted.isEmpty)
        XCTAssertEqual(result.rejected.first?.name, "Unknown Character")
        XCTAssertTrue(campaign.npcs.isEmpty)
    }
}
