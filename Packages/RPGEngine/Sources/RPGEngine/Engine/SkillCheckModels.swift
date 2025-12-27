import Foundation
import FoundationModels

public enum CheckType: String, CaseIterable, Sendable {
    case skillCheck = "skill_check"
    case contestedCheck = "contested_check"
}

public enum AdvantageState: String, CaseIterable, Sendable {
    case advantage
    case disadvantage
    case normal
}

public enum FateLikelihood: String, CaseIterable, Sendable {
    case impossible
    case unlikely
    case fiftyFifty = "50_50"
    case likely
    case veryLikely
    case nearlyCertain
}

public struct SkillDefinition: Hashable, Sendable {
    public let name: String
    public let defaultAbility: String
}

public protocol Ruleset {
    var id: String { get }
    var displayName: String { get }
    var abilities: [String] { get }
    var skills: [SkillDefinition] { get }
    var dcBands: [Int] { get }
    var contestedPairs: [(String, String)] { get }
    func defaultAbility(for skill: String) -> String?
}

extension Ruleset {
    public var skillNames: [String] {
        skills.map { $0.name }
    }

    public func defaultAbility(for skill: String) -> String? {
        skills.first { $0.name.caseInsensitiveCompare(skill) == .orderedSame }?.defaultAbility
    }
}

public struct SrdRuleset: Ruleset, Sendable {
    public let id: String
    public let displayName: String
    public let abilities: [String]
    public let skills: [SkillDefinition]
    public let species: [String]
    public let classes: [String]
    public let feats: [String]
    public let equipment: [String]
    public let spells: [String]
    public let dcBands: [Int]
    public let contestedPairs: [(String, String)]

    public init(index: SrdContentIndex? = nil) {
        id = "srd_5e"
        displayName = "SRD 5E"

        let defaultAbilities = [
            "Strength",
            "Dexterity",
            "Constitution",
            "Intelligence",
            "Wisdom",
            "Charisma"
        ]
        let defaultSkills: [SkillDefinition] = [
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

        if let abilities = index?.abilities, !abilities.isEmpty {
            self.abilities = abilities
        } else {
            self.abilities = defaultAbilities
        }

        if let skills = index?.skills, !skills.isEmpty {
            self.skills = skills
        } else {
            self.skills = defaultSkills
        }

        species = index?.species ?? []
        classes = index?.classes ?? []
        feats = index?.feats ?? []
        equipment = index?.equipment ?? []
        spells = index?.spells ?? []
        dcBands = [5, 10, 15, 20, 25, 30]
        contestedPairs = [
            ("Stealth", "Perception"),
            ("Deception", "Insight"),
            ("Persuasion", "Insight"),
            ("Athletics", "Athletics"),
            ("Acrobatics", "Acrobatics")
        ]
    }
}

public struct RulesetDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let summary: String

    public init(id: String, displayName: String, summary: String) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
    }
}

public struct RulesetCatalog {
    public static let srd = SrdRuleset()
    public static let srdDescriptor = RulesetDescriptor(
        id: srd.id,
        displayName: srd.displayName,
        summary: "Open SRD ruleset with standard abilities and skills."
    )
    public static let descriptors: [RulesetDescriptor] = [srdDescriptor]

    public static func srdRuleset() -> SrdRuleset {
        if let index = SrdContentStore().loadIndex() {
            return SrdRuleset(index: index)
        }
        return srd
    }

    public static func ruleset(for nameOrId: String?) -> any Ruleset {
        guard let nameOrId = nameOrId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !nameOrId.isEmpty else {
            return srd
        }
        if nameOrId.caseInsensitiveCompare(srd.id) == .orderedSame ||
            nameOrId.caseInsensitiveCompare(srd.displayName) == .orderedSame {
            return srdRuleset()
        }
        return srdRuleset()
    }

    public static func descriptor(for nameOrId: String?) -> RulesetDescriptor? {
        guard let nameOrId = nameOrId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !nameOrId.isEmpty else {
            return srdDescriptor
        }
        if srdDescriptor.id.caseInsensitiveCompare(nameOrId) == .orderedSame ||
            srdDescriptor.displayName.caseInsensitiveCompare(nameOrId) == .orderedSame {
            return srdDescriptor
        }
        return nil
    }
}

public struct SkillCheckHeuristics {
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

public struct CheckRequest: Sendable {
    public let checkType: CheckType
    public let skillName: String
    public let abilityOverride: String?
    public let dc: Int?
    public let opponentSkill: String?
    public let opponentDC: Int?
    public let advantageState: AdvantageState
    public let stakes: String
    public let partialSuccessDC: Int?
    public let partialSuccessOutcome: String?
    public let reason: String

    public init(
        checkType: CheckType,
        skillName: String,
        abilityOverride: String?,
        dc: Int?,
        opponentSkill: String?,
        opponentDC: Int?,
        advantageState: AdvantageState,
        stakes: String,
        partialSuccessDC: Int?,
        partialSuccessOutcome: String?,
        reason: String
    ) {
        self.checkType = checkType
        self.skillName = skillName
        self.abilityOverride = abilityOverride
        self.dc = dc
        self.opponentSkill = opponentSkill
        self.opponentDC = opponentDC
        self.advantageState = advantageState
        self.stakes = stakes
        self.partialSuccessDC = partialSuccessDC
        self.partialSuccessOutcome = partialSuccessOutcome
        self.reason = reason
    }
}

public struct CheckResult {
    public let total: Int
    public let outcome: String
    public let consequence: String
}

@Generable
public struct CheckRequestDraft {
    @Guide(description: "Whether a roll is required based on uncertainty and consequence")
    public let requiresRoll: Bool

    @Guide(description: "If no roll, outcome is success or failure")
    public let autoOutcome: String?

    @Guide(description: "Type of check: skill_check or contested_check")
    public let checkType: String

    @Guide(description: "Skill name such as Stealth, Persuasion, Investigation")
    public let skill: String

    @Guide(description: "Optional ability override like Strength for Intimidation")
    public let abilityOverride: String?

    @Guide(description: "DC for a skill check using 5, 10, 15, 20, 25, 30")
    public let dc: Int?

    @Guide(description: "Opponent skill for contested checks")
    public let opponentSkill: String?

    @Guide(description: "Opponent DC for contested checks")
    public let opponentDC: Int?

    @Guide(description: "advantage, disadvantage, or normal")
    public let advantageState: String

    @Guide(description: "One concise sentence describing what failure looks like")
    public let stakes: String

    @Guide(description: "Optional partial success threshold (usually DC-5)")
    public let partialSuccessDC: Int?

    @Guide(description: "Outcome text for partial success")
    public let partialSuccessOutcome: String?

    @Guide(description: "One concrete fiction reason for the DC")
    public let reason: String
}

@Generable
public struct FateQuestionDraft {
    @Guide(description: "Is this a yes/no fate question that should be rolled? true or false")
    public let isFateQuestion: Bool

    @Guide(description: "Likelihood: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain")
    public let likelihood: String

    @Guide(description: "One short reason for the likelihood")
    public let reason: String
}

@Generable
public struct InteractionIntentDraft {
    @Guide(description: "Intent: fate_question, skill_check, or normal")
    public let intent: String
}

@Generable
public struct MovementIntentDraft {
    @Guide(description: "True if the player is moving into a new space or leaving the current location")
    public let isMovement: Bool

    @Guide(description: "Short summary of the movement intent for logging")
    public let summary: String

    @Guide(description: "Optional destination or direction, if specified")
    public let destination: String?

    @Guide(description: "Optional exit label or type if the player referenced a specific exit")
    public let exitLabel: String?
}

@Generable
public struct CanonizationDraft {
    @Guide(description: "True if the player is asserting a new fact that should be canonized")
    public let shouldCanonize: Bool

    @Guide(description: "The assumption or fact the player wants to establish")
    public let assumption: String

    @Guide(description: "Likelihood for the fate roll: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain")
    public let likelihood: String
}

@Generable
public struct CheckRollDraft {
    @Guide(description: "The d20 roll result if provided")
    public let roll: Int?

    @Guide(description: "The modifier applied to the roll if provided")
    public let modifier: Int?

    @Guide(description: "True if the player asks the system to auto-roll")
    public let autoRoll: Bool

    @Guide(description: "True if the player declines to attempt the check")
    public let declines: Bool
}

@Generable
public struct SceneWrapUpDraft {
    @Guide(description: "2-4 lines summarizing what happened in the scene")
    public let summary: String

    @Guide(description: "Important new characters introduced")
    public let newCharacters: [String]

    @Guide(description: "Important new threads or goals introduced")
    public let newThreads: [String]

    @Guide(description: "Existing characters that featured strongly")
    public let featuredCharacters: [String]

    @Guide(description: "Existing threads that featured strongly")
    public let featuredThreads: [String]

    @Guide(description: "Characters no longer relevant")
    public let removedCharacters: [String]

    @Guide(description: "Threads no longer relevant")
    public let removedThreads: [String]

    @Guide(description: "Important places or locations mentioned")
    public let places: [String]

    @Guide(description: "Curiosities, mysteries, or notable details")
    public let curiosities: [String]

    @Guide(description: "Rolls or checks that mattered in the scene")
    public let rollHighlights: [String]

    public init(
        summary: String,
        newCharacters: [String],
        newThreads: [String],
        featuredCharacters: [String],
        featuredThreads: [String],
        removedCharacters: [String],
        removedThreads: [String],
        places: [String],
        curiosities: [String],
        rollHighlights: [String]
    ) {
        self.summary = summary
        self.newCharacters = newCharacters
        self.newThreads = newThreads
        self.featuredCharacters = featuredCharacters
        self.featuredThreads = featuredThreads
        self.removedCharacters = removedCharacters
        self.removedThreads = removedThreads
        self.places = places
        self.curiosities = curiosities
        self.rollHighlights = rollHighlights
    }
}

public struct RulesetHelpers {
    public static func passiveScore(modifier: Int) -> Int {
        10 + modifier
    }
}

@Generable
public struct LocationFeatureDraft {
    @Guide(description: "Stable inanimate features worth remembering")
    public let items: [LocationFeatureDraftItem]
}

@Generable
public struct LocationFeatureDraftItem {
    @Guide(description: "Short name of the feature")
    public let name: String

    @Guide(description: "One sentence summary")
    public let summary: String
}
