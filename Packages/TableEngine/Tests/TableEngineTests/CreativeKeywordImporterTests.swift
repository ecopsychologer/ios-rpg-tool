import XCTest
@testable import TableEngine

final class CreativeKeywordImporterTests: XCTestCase {
    func testBundledKeywordsAreUnique() {
        let importer = CreativeKeywordImporter()
        let keywords = importer.loadBundledKeywords()
        XCTAssertFalse(keywords.isEmpty)
        let normalized = keywords.map { $0.lowercased() }
        XCTAssertEqual(Set(normalized).count, normalized.count)
    }

    func testDeterministicKeywordDraw() {
        let importer = CreativeKeywordImporter()
        let keywords = importer.loadBundledKeywords()
        let picker = CreativeKeywordPicker()
        let first = picker.draw(from: keywords, count: 2, seed: 42)
        let second = picker.draw(from: keywords, count: 2, seed: 42)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 2)
    }
}
