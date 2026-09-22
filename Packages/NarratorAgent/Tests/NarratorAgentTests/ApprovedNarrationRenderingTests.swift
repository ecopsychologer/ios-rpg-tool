import XCTest
import NarratorAgent
import RPGEngine

final class ApprovedNarrationRenderingTests: XCTestCase {
    func testFallbackRendererUsesOnlyApprovedPacket() {
        let packet = ApprovedNarrationPacket(
            responsePurpose: .sceneResponse,
            directAnswer: .notApplicable,
            renderingBeats: ["Rain hisses through the roadside brush."],
            nextPrompt: "What do you do?",
            approvedFactNames: ["Roadside Camp"]
        )

        let text = NarratorAgentPipeline().renderDeterministicFallback(packet)

        XCTAssertEqual(text, "Rain hisses through the roadside brush.\n\nWhat do you do?")
        XCTAssertFalse(text.contains("Thorne"))
        XCTAssertFalse(text.contains("Hidden Chamber"))
    }
}
