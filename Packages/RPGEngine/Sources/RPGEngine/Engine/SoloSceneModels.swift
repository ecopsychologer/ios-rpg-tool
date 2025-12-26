import Foundation

public enum SceneType: String, CaseIterable, Hashable {
    case expected
    case altered
    case interrupt

    public var title: String {
        rawValue.capitalized
    }
}

public struct MeaningWords: Equatable {
    public let first: String
    public let second: String
}

public enum AlterationMethod: CaseIterable, Hashable {
    case nextMostLikely
    case tweakOneElement
    case fateQuestion
    case meaningWords
    case sceneAdjustment

    public var label: String {
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

    public var guidance: String {
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

public enum SceneAdjustment: CaseIterable, Hashable {
    case raiseStakes
    case shiftLocation
    case delayGoal
    case addComplication
    case revealMotivation

    public var label: String {
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

    public var guidance: String {
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

public enum RandomEventFocus: String, CaseIterable, Hashable {
    case npcAction = "NPC Action"
    case npcIntroduced = "New NPC"
    case remoteEvent = "Remote Event"
    case moveTowardThread = "Move Toward a Thread"
    case moveAwayFromThread = "Move Away from a Thread"
    case pcNegative = "PC Negative"
    case pcPositive = "PC Positive"
}

public struct RandomEvent: Equatable {
    public let focus: RandomEventFocus
    public let meaningWords: MeaningWords
}

public struct SceneRecord: Identifiable {
    public let id = UUID()
    public let sceneNumber: Int
    public let expectedScene: String
    public let roll: Int
    public let chaosFactor: Int
    public let type: SceneType
    public var alterationMethod: AlterationMethod?
    public var alterationDetail: String?
    public var randomEvent: RandomEvent?
}

public struct SoloState {
    public var chaosFactor: Int = 5
    public var threads = WeightedList()
    public var characters = WeightedList()
    public var sceneNumber: Int = 1
}
