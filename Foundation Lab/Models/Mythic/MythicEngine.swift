import Foundation

protocol WordListProvider {
    var listA: [String] { get }
    var listB: [String] { get }
}

struct DefaultWordListProvider: WordListProvider {
    // Placeholder word lists; replace with your own tables if desired.
    let listA: [String] = [
        "ancient", "bold", "broken", "calm", "chaotic", "cold", "distant", "eager",
        "fragile", "grim", "hidden", "honest", "jagged", "luminous", "muffled", "narrow",
        "ominous", "quiet", "restless", "scarred", "silent", "tangled", "urgent", "worn"
    ]

    let listB: [String] = [
        "ally", "barrier", "bridge", "cargo", "crowd", "debt", "doorway", "echo",
        "fire", "garden", "hunger", "key", "memory", "message", "path", "promise",
        "refuge", "signal", "storm", "trail", "vault", "warning", "whisper", "wound"
    ]
}

struct MythicEngine {
    var wordListProvider: WordListProvider
    var focusOptions: [RandomEventFocus]

    init(
        wordListProvider: WordListProvider = DefaultWordListProvider(),
        focusOptions: [RandomEventFocus] = RandomEventFocus.allCases
    ) {
        self.wordListProvider = wordListProvider
        self.focusOptions = focusOptions
    }

    func rollD10() -> Int {
        Int.random(in: 1...10)
    }

    func classifyScene(chaosFactor: Int, roll: Int) -> SceneType {
        if roll > chaosFactor {
            return .expected
        }
        if roll.isMultiple(of: 2) {
            return .interrupt
        }
        return .altered
    }

    func generateMeaningWords() -> MeaningWords {
        let listA = wordListProvider.listA
        let listB = wordListProvider.listB
        let first = listA[Int.random(in: 0..<listA.count)]
        let second = listB[Int.random(in: 0..<listB.count)]
        return MeaningWords(first: first, second: second)
    }

    func generateRandomEvent() -> RandomEvent {
        let focus = focusOptions[Int.random(in: 0..<focusOptions.count)]
        let words = generateMeaningWords()
        return RandomEvent(focus: focus, meaningWords: words)
    }

    func updateChaosFactor(current: Int, pcsInControl: Bool) -> Int {
        if pcsInControl {
            return max(1, current - 1)
        }
        return min(9, current + 1)
    }
}
