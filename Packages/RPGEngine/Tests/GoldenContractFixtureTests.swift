import XCTest

final class GoldenContractFixtureTests: XCTestCase {
    func testGMAuthorityGoldenFixtureContainsRequiredBoundaries() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "gm_authority_golden", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let defaults = try XCTUnwrap(object["defaults"] as? [String: Any])
        let cases = try XCTUnwrap(object["cases"] as? [[String: Any]])
        let ids = Set(cases.compactMap { $0["id"] as? String })

        XCTAssertEqual(defaults["strictGMWorldAuthority"] as? Bool, true)
        XCTAssertEqual(defaults["promptMode"] as? String, "open_table")
        XCTAssertEqual(defaults["maximumNarrationRetries"] as? Int, 1)
        XCTAssertTrue(ids.isSuperset(of: [
            "summary_is_read_only",
            "weather_is_gm_authorized",
            "hidden_door_discovery_not_entry",
            "meta_zero_diff",
            "bounded_creative_natural_20"
        ]))
    }
}
