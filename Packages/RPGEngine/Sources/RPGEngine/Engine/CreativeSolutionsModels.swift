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

public enum CreativeEventValence: String, Codable, Sendable {
    case beneficial
    case neutral
    case harmful
}

public enum CreativeEffectKind: String, Codable, Sendable {
    case gift
    case reaction
    case terrain
    case complication
}

public struct CreativeEvent: Codable, Equatable, Sendable {
    public let action: String
    public let roll: Int
    public let keywords: [String]
    public let effectKind: CreativeEffectKind
    public let valence: CreativeEventValence
    public let mutations: [StakesMutationKind]
    public let engineEffect: String
}

public struct CreativeSolutionsEngine: Sendable {
    public init() {}

    public var requestPrompt: String {
        "What do you do? Explain your action, and give me a straight d20 roll."
    }

    public func resolve(
        action: String,
        roll: Int,
        keywords: [CreativeKeyword],
        seed: UInt64,
        sequence: Int = 0
    ) -> CreativeEvent {
        let boundedRoll = min(max(roll, 1), 20)
        let drawCount = 2 + Int((seed &+ UInt64(max(0, sequence))) % 2)
        let selected = CreativeKeywordStore().drawKeywords(
            count: drawCount,
            from: keywords,
            seed: seed,
            sequence: sequence
        ).map(\.word)
        var rng = SeededRNG(seed: seed &+ UInt64(max(0, sequence)))
        let kinds: [CreativeEffectKind] = [.gift, .reaction, .terrain, .complication]
        let kind = kinds[rng.nextInt(upperBound: kinds.count)]
        let valence: CreativeEventValence
        let mutations: [StakesMutationKind]
        switch boundedRoll {
        case 20:
            valence = .beneficial
            mutations = [.sceneFact, .clue]
        case 15...19:
            valence = .beneficial
            mutations = [.sceneFact]
        case 8...14:
            valence = .neutral
            mutations = [.sceneFact, .delay]
        default:
            valence = .harmful
            mutations = [.encounterRisk, .delay]
        }
        let anchor = selected.isEmpty ? "the surroundings" : selected.joined(separator: " and ")
        let effect: String
        switch valence {
        case .beneficial:
            effect = "The \(kind.rawValue) creates a brief opening tied to \(anchor); gain advantage on the next directly related check."
        case .neutral:
            effect = "The \(kind.rawValue) changes the scene through \(anchor), but costs time before the next action."
        case .harmful:
            effect = "The \(kind.rawValue) reacts through \(anchor); delay and encounter risk each increase by 1."
        }
        return CreativeEvent(
            action: action,
            roll: boundedRoll,
            keywords: selected,
            effectKind: kind,
            valence: valence,
            mutations: mutations,
            engineEffect: effect
        )
    }
}
