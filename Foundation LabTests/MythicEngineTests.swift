import XCTest
@testable import FoundationLab

final class MythicEngineTests: XCTestCase {
    func testSceneClassificationAcrossChaosFactorBoundaries() {
        let engine = MythicEngine()
        let chaosFactors = [1, 5, 9]

        for chaosFactor in chaosFactors {
            for roll in 1...10 {
                let sceneType = engine.classifyScene(chaosFactor: chaosFactor, roll: roll)
                if roll > chaosFactor {
                    XCTAssertEqual(sceneType, .expected, "CF \(chaosFactor) roll \(roll) should be expected")
                } else if roll.isMultiple(of: 2) {
                    XCTAssertEqual(sceneType, .interrupt, "CF \(chaosFactor) roll \(roll) should be interrupt")
                } else {
                    XCTAssertEqual(sceneType, .altered, "CF \(chaosFactor) roll \(roll) should be altered")
                }
            }
        }
    }

    func testOddEvenAlteredVsInterruptWhenRollBelowChaosFactor() {
        let engine = MythicEngine()
        let chaosFactor = 5

        let oddRoll = 3
        XCTAssertEqual(engine.classifyScene(chaosFactor: chaosFactor, roll: oddRoll), .altered)

        let evenRoll = 4
        XCTAssertEqual(engine.classifyScene(chaosFactor: chaosFactor, roll: evenRoll), .interrupt)
    }

    func testChaosFactorClamping() {
        let engine = MythicEngine()
        XCTAssertEqual(engine.updateChaosFactor(current: 1, pcsInControl: true), 1)
        XCTAssertEqual(engine.updateChaosFactor(current: 9, pcsInControl: false), 9)
    }

    func testWeightedListBehavior() {
        var list = WeightedList()

        list.addNew(["Alyx", "Borin"])
        XCTAssertEqual(list.allEntries.count, 2)
        XCTAssertEqual(list.allEntries.first { $0.name == "Alyx" }?.weight, 1)

        list.featureExisting(["alyx", "ALYX"])
        XCTAssertEqual(list.allEntries.first { $0.name == "Alyx" }?.weight, 3)

        list.addNew(["ALYX"])
        XCTAssertEqual(list.allEntries.count, 2, "Case-insensitive add should de-dupe")

        list.remove(["borin"])
        XCTAssertNil(list.allEntries.first { $0.name.lowercased() == "borin" })
    }

    func testCheckEvaluationSuccessAndFailure() {
        var engine = MythicCampaignEngine()
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: "Stealth",
            abilityOverride: nil,
            dc: 15,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "You are spotted.",
            partialSuccessDC: 10,
            partialSuccessOutcome: "You slip through but leave a trace.",
            reason: "Guards are alert in the rain."
        )

        let success = engine.evaluateCheck(request: request, roll: 14, modifier: 2)
        XCTAssertEqual(success.outcome, "success")

        let partial = engine.evaluateCheck(request: request, roll: 10, modifier: 0)
        XCTAssertEqual(partial.outcome, "partial_success")

        let failure = engine.evaluateCheck(request: request, roll: 4, modifier: 0)
        XCTAssertEqual(failure.outcome, "failure")
    }

    func testFateQuestionUsesChaosFactor() {
        let engine = MythicCampaignEngine()
        let record = engine.resolveFateQuestion(
            question: "Is there a chandelier?",
            likelihood: .likely,
            chaosFactor: 9,
            roll: 42
        )
        XCTAssertEqual(record.target, 90)
    }
}
