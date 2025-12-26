import Foundation

public protocol WordListProvider {
    var listA: [String] { get }
    var listB: [String] { get }
}

public struct DefaultWordListProvider: WordListProvider {
    // Placeholder word lists; replace with your own tables if desired.
    public let listA: [String] = [
        "ancient", "bold", "broken", "calm", "chaotic", "cold", "distant", "eager",
        "fragile", "grim", "hidden", "honest", "jagged", "luminous", "muffled", "narrow",
        "ominous", "quiet", "restless", "scarred", "silent", "tangled", "urgent", "worn"
    ]

    public let listB: [String] = [
        "ally", "barrier", "bridge", "cargo", "crowd", "debt", "doorway", "echo",
        "fire", "garden", "hunger", "key", "memory", "message", "path", "promise",
        "refuge", "signal", "storm", "trail", "vault", "warning", "whisper", "wound"
    ]

    public init() {}
}

public struct SoloOracleEngine {
    public var wordListProvider: WordListProvider
    public var focusOptions: [RandomEventFocus]

    public init(
        wordListProvider: WordListProvider = DefaultWordListProvider(),
        focusOptions: [RandomEventFocus] = RandomEventFocus.allCases
    ) {
        self.wordListProvider = wordListProvider
        self.focusOptions = focusOptions
    }

    public func rollD10() -> Int {
        Int.random(in: 1...10)
    }

    public func rollD100() -> Int {
        Int.random(in: 1...100)
    }

    public func classifyScene(chaosFactor: Int, roll: Int) -> SceneType {
        if roll > chaosFactor {
            return .expected
        }
        if roll.isMultiple(of: 2) {
            return .interrupt
        }
        return .altered
    }

    public func generateMeaningWords() -> MeaningWords {
        let listA = wordListProvider.listA
        let listB = wordListProvider.listB
        let first = listA[Int.random(in: 0..<listA.count)]
        let second = listB[Int.random(in: 0..<listB.count)]
        return MeaningWords(first: first, second: second)
    }

    public func generateRandomEvent() -> RandomEvent {
        let focus = focusOptions[Int.random(in: 0..<focusOptions.count)]
        let words = generateMeaningWords()
        return RandomEvent(focus: focus, meaningWords: words)
    }

    public func updateChaosFactor(current: Int, pcsInControl: Bool) -> Int {
        if pcsInControl {
            return max(1, current - 1)
        }
        return min(9, current + 1)
    }
}
