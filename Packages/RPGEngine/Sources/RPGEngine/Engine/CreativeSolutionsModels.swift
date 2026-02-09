import Foundation
import TableEngine

public struct CreativeKeyword: Hashable, Codable, Identifiable, Sendable {
    public let id: UUID
    public let word: String

    public init(word: String, id: UUID = UUID()) {
        self.id = id
        self.word = word
    }
}

public struct CreativeKeywordStore {
    public init() {}

    public func loadBundledKeywords() -> [CreativeKeyword] {
        let importer = CreativeKeywordImporter()
        let words = importer.loadBundledKeywords()
        return words.map { CreativeKeyword(word: $0) }
    }

    public func drawKeywords(
        count: Int,
        from keywords: [CreativeKeyword],
        seed: UInt64,
        sequence: Int = 0
    ) -> [CreativeKeyword] {
        let words = keywords.map(\.word)
        let picks = CreativeKeywordPicker().draw(from: words, count: count, seed: seed, sequence: sequence)
        return picks.map { CreativeKeyword(word: $0) }
    }
}
