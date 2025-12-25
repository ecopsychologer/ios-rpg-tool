import Foundation
import FoundationModels

enum CheckType: String, CaseIterable {
    case skillCheck = "skill_check"
    case contestedCheck = "contested_check"
}

enum AdvantageState: String, CaseIterable {
    case advantage
    case disadvantage
    case normal
}

enum FateLikelihood: String, CaseIterable {
    case impossible
    case unlikely
    case fiftyFifty = "50_50"
    case likely
    case veryLikely
    case nearlyCertain
}

struct SkillDefinition: Hashable {
    let name: String
    let defaultAbility: String
}

protocol Ruleset {
    var id: String { get }
    var displayName: String { get }
    var abilities: [String] { get }
    var skills: [SkillDefinition] { get }
    var dcBands: [Int] { get }
    var contestedPairs: [(String, String)] { get }
    func defaultAbility(for skill: String) -> String?
}

extension Ruleset {
    var skillNames: [String] {
        skills.map { $0.name }
    }

    func defaultAbility(for skill: String) -> String? {
        skills.first { $0.name.caseInsensitiveCompare(skill) == .orderedSame }?.defaultAbility
    }
}

struct DndRuleset: Ruleset {
    let id = "dnd_5e"
    let displayName = "D&D 5E"

    let abilities = [
        "Strength",
        "Dexterity",
        "Constitution",
        "Intelligence",
        "Wisdom",
        "Charisma"
    ]

    let skills: [SkillDefinition] = [
        SkillDefinition(name: "Athletics", defaultAbility: "Strength"),
        SkillDefinition(name: "Acrobatics", defaultAbility: "Dexterity"),
        SkillDefinition(name: "Sleight of Hand", defaultAbility: "Dexterity"),
        SkillDefinition(name: "Stealth", defaultAbility: "Dexterity"),
        SkillDefinition(name: "Arcana", defaultAbility: "Intelligence"),
        SkillDefinition(name: "History", defaultAbility: "Intelligence"),
        SkillDefinition(name: "Investigation", defaultAbility: "Intelligence"),
        SkillDefinition(name: "Nature", defaultAbility: "Intelligence"),
        SkillDefinition(name: "Religion", defaultAbility: "Intelligence"),
        SkillDefinition(name: "Animal Handling", defaultAbility: "Wisdom"),
        SkillDefinition(name: "Insight", defaultAbility: "Wisdom"),
        SkillDefinition(name: "Medicine", defaultAbility: "Wisdom"),
        SkillDefinition(name: "Perception", defaultAbility: "Wisdom"),
        SkillDefinition(name: "Survival", defaultAbility: "Wisdom"),
        SkillDefinition(name: "Deception", defaultAbility: "Charisma"),
        SkillDefinition(name: "Intimidation", defaultAbility: "Charisma"),
        SkillDefinition(name: "Performance", defaultAbility: "Charisma"),
        SkillDefinition(name: "Persuasion", defaultAbility: "Charisma")
    ]

    let dcBands = [5, 10, 15, 20, 25, 30]

    let contestedPairs: [(String, String)] = [
        ("Stealth", "Perception"),
        ("Deception", "Insight"),
        ("Persuasion", "Insight"),
        ("Athletics", "Athletics"),
        ("Acrobatics", "Acrobatics")
    ]
}

struct RulesetCatalog {
    static let dnd = DndRuleset()
}

struct SkillCheckHeuristics {
    static let rollWhen = [
        "Uncertain and consequential actions should call for a roll.",
        "Trivial, cosmetic, or guaranteed actions should not roll.",
        "Automatic success when capable and unpressured.",
        "Automatic failure when impossible without special means."
    ]

    static let dcGuidelines = [
        "5 trivial / very favorable",
        "10 routine",
        "15 challenging under pressure",
        "20 hard and risky",
        "25 extreme",
        "30 legendary"
    ]

    static let advantageGuidelines = [
        "Advantage for strong leverage, perfect setup, or help.",
        "Disadvantage for harsh conditions, injury, or hostile attention.",
        "Normal otherwise."
    ]
}

struct CheckRequest {
    let checkType: CheckType
    let skillName: String
    let abilityOverride: String?
    let dc: Int?
    let opponentSkill: String?
    let opponentDC: Int?
    let advantageState: AdvantageState
    let stakes: String
    let partialSuccessDC: Int?
    let partialSuccessOutcome: String?
    let reason: String
}

struct CheckResult {
    let total: Int
    let outcome: String
    let consequence: String
}

@Generable
struct CheckRequestDraft {
    @Guide(description: "Whether a roll is required based on uncertainty and consequence")
    let requiresRoll: Bool

    @Guide(description: "If no roll, outcome is success or failure")
    let autoOutcome: String?

    @Guide(description: "Type of check: skill_check or contested_check")
    let checkType: String

    @Guide(description: "Skill name such as Stealth, Persuasion, Investigation")
    let skill: String

    @Guide(description: "Optional ability override like Strength for Intimidation")
    let abilityOverride: String?

    @Guide(description: "DC for a skill check using 5, 10, 15, 20, 25, 30")
    let dc: Int?

    @Guide(description: "Opponent skill for contested checks")
    let opponentSkill: String?

    @Guide(description: "Opponent DC for contested checks")
    let opponentDC: Int?

    @Guide(description: "advantage, disadvantage, or normal")
    let advantageState: String

    @Guide(description: "One concise sentence describing what failure looks like")
    let stakes: String

    @Guide(description: "Optional partial success threshold (usually DC-5)")
    let partialSuccessDC: Int?

    @Guide(description: "Outcome text for partial success")
    let partialSuccessOutcome: String?

    @Guide(description: "One concrete fiction reason for the DC")
    let reason: String
}

@Generable
struct FateQuestionDraft {
    @Guide(description: "Is this a yes/no fate question that should be rolled? true or false")
    let isFateQuestion: Bool

    @Guide(description: "Likelihood: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain")
    let likelihood: String

    @Guide(description: "One short reason for the likelihood")
    let reason: String
}

@Generable
struct InteractionIntentDraft {
    @Guide(description: "Intent: fate_question, skill_check, or normal")
    let intent: String
}

@Generable
struct CanonizationDraft {
    @Guide(description: "True if the player is asserting a new fact that should be canonized")
    let shouldCanonize: Bool

    @Guide(description: "The assumption or fact the player wants to establish")
    let assumption: String

    @Guide(description: "Likelihood for the fate roll: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain")
    let likelihood: String
}

@Generable
struct CheckRollDraft {
    @Guide(description: "The d20 roll result if provided")
    let roll: Int?

    @Guide(description: "The modifier applied to the roll if provided")
    let modifier: Int?

    @Guide(description: "True if the player declines to attempt the check")
    let declines: Bool
}

@Generable
struct SceneWrapUpDraft {
    @Guide(description: "2-4 lines summarizing what happened in the scene")
    let summary: String

    @Guide(description: "Important new characters introduced")
    let newCharacters: [String]

    @Guide(description: "Important new threads or goals introduced")
    let newThreads: [String]

    @Guide(description: "Existing characters that featured strongly")
    let featuredCharacters: [String]

    @Guide(description: "Existing threads that featured strongly")
    let featuredThreads: [String]

    @Guide(description: "Characters no longer relevant")
    let removedCharacters: [String]

    @Guide(description: "Threads no longer relevant")
    let removedThreads: [String]

    @Guide(description: "Important places or locations mentioned")
    let places: [String]

    @Guide(description: "Curiosities, mysteries, or notable details")
    let curiosities: [String]

    @Guide(description: "Rolls or checks that mattered in the scene")
    let rollHighlights: [String]
}

struct RulesetHelpers {
    static func passiveScore(modifier: Int) -> Int {
        10 + modifier
    }
}
