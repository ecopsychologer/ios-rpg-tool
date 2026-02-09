import Foundation

public struct CreativeKeywordImporter {
    public init() {}

    public func loadBundledKeywords() -> [String] {
        guard let url = Bundle.module.url(forResource: "creative_keywords", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return parseKeywords(from: data)
    }

    public func parseKeywords(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let list = json as? [String] {
            return dedupeKeywords(list)
        }
        if let dict = json as? [String: Any],
           let list = dict["keywords"] as? [String] {
            return dedupeKeywords(list)
        }
        return []
    }

    private func dedupeKeywords(_ list: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        for word in list {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append(trimmed)
        }
        return results
    }
}

public struct CreativeKeywordPicker {
    public init() {}

    public func draw(from keywords: [String], count: Int, seed: UInt64, sequence: Int = 0) -> [String] {
        guard !keywords.isEmpty, count > 0 else { return [] }
        var rng = SeededRNG(seed: seed)
        if sequence > 0 {
            for _ in 0..<sequence {
                _ = rng.next()
            }
        }
        var pool = keywords
        var picks: [String] = []
        let drawCount = min(count, pool.count)
        for _ in 0..<drawCount {
            let index = rng.nextInt(upperBound: pool.count)
            picks.append(pool.remove(at: index))
        }
        return picks
    }
}
