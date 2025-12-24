import Foundation

enum SceneType: String, CaseIterable, Hashable {
    case expected
    case altered
    case interrupt

    var title: String {
        rawValue.capitalized
    }
}

struct MeaningWords: Equatable {
    let first: String
    let second: String
}

enum AlterationMethod: CaseIterable, Hashable {
    case nextMostLikely
    case tweakOneElement
    case fateQuestion
    case meaningWords
    case sceneAdjustment

    var label: String {
        switch self {
        case .nextMostLikely:
            return "Next Most Likely"
        case .tweakOneElement:
            return "Tweak One Element (who/what/where/goal/complication)"
        case .fateQuestion:
            return "Ask a Fate Question (yes/no oracle - placeholder, not implemented yet)"
        case .meaningWords:
            return "Meaning Words"
        case .sceneAdjustment:
            return "Scene Adjustment"
        }
    }

    var guidance: String {
        switch self {
        case .nextMostLikely:
            return "Go with the next most likely idea and proceed confidently."
        case .tweakOneElement:
            return "Adjust one element (who/what/where/goal/complication) to make the scene surprising."
        case .fateQuestion:
            return "Frame a yes/no question, roll, and apply the answer to reshape the scene."
        case .meaningWords:
            return "Interpret the two words as a prompt for what changes."
        case .sceneAdjustment:
            return "Apply a small adjustment to shift the scene's direction."
        }
    }
}

enum SceneAdjustment: CaseIterable, Hashable {
    case raiseStakes
    case shiftLocation
    case delayGoal
    case addComplication
    case revealMotivation

    var label: String {
        switch self {
        case .raiseStakes:
            return "Raise the Stakes"
        case .shiftLocation:
            return "Shift the Location"
        case .delayGoal:
            return "Delay the Goal"
        case .addComplication:
            return "Add a Complication"
        case .revealMotivation:
            return "Reveal a Motivation"
        }
    }

    var guidance: String {
        switch self {
        case .raiseStakes:
            return "Something makes success costlier or riskier."
        case .shiftLocation:
            return "Move the action to a nearby, more dramatic place."
        case .delayGoal:
            return "A barrier forces a detour before the goal can be reached."
        case .addComplication:
            return "Introduce a new obstacle or side effect."
        case .revealMotivation:
            return "Expose a hidden reason behind someone's actions."
        }
    }
}

enum RandomEventFocus: String, CaseIterable, Hashable {
    case npcAction = "NPC Action"
    case npcIntroduced = "New NPC"
    case remoteEvent = "Remote Event"
    case moveTowardThread = "Move Toward a Thread"
    case moveAwayFromThread = "Move Away from a Thread"
    case pcNegative = "PC Negative"
    case pcPositive = "PC Positive"
}

struct RandomEvent: Equatable {
    let focus: RandomEventFocus
    let meaningWords: MeaningWords
}

struct SceneRecord: Identifiable {
    let id = UUID()
    let sceneNumber: Int
    let expectedScene: String
    let roll: Int
    let chaosFactor: Int
    let type: SceneType
    var alterationMethod: AlterationMethod?
    var alterationDetail: String?
    var randomEvent: RandomEvent?
}

struct MythicState {
    var chaosFactor: Int = 5
    var threads = WeightedList()
    var characters = WeightedList()
    var sceneNumber: Int = 1
}
