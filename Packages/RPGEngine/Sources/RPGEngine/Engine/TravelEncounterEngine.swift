import Foundation
import TableEngine
import WorldState

public enum TravelEnvironment: String, CaseIterable, Sendable {
    case road
    case wilderness
    case wilds
    case underground
    case city
}

public enum TravelTimeOfDay: String, CaseIterable, Sendable {
    case day
    case night
}

public struct TravelConditions: Sendable {
    public let timeOfDay: TravelTimeOfDay
    public let badWeather: Bool

    public init(timeOfDay: TravelTimeOfDay, badWeather: Bool) {
        self.timeOfDay = timeOfDay
        self.badWeather = badWeather
    }
}

public struct EncounterFrequency: Sendable {
    public let dieSpec: String
    public let intervalHours: Int
    public let encounterRange: ClosedRange<Int>
    public let notes: String

    public init(dieSpec: String, intervalHours: Int, encounterRange: ClosedRange<Int>, notes: String) {
        self.dieSpec = dieSpec
        self.intervalHours = intervalHours
        self.encounterRange = encounterRange
        self.notes = notes
    }
}

public struct EncounterCheckOutcome: Sendable {
    public let environment: TravelEnvironment
    public let conditions: TravelConditions
    public let dieSpec: String
    public let roll: Int
    public let modifier: Int
    public let modifiedRoll: Int
    public let encounterRange: ClosedRange<Int>
    public let notes: String

    public var triggered: Bool {
        encounterRange.contains(modifiedRoll)
    }
}

public struct TravelEventOutcome: Sendable {
    public let event: String
    public let followUps: [String]
    public let encounterIntensity: String?
}

public struct TravelEventResolution: Sendable {
    public let check: EncounterCheckOutcome
    public let event: TravelEventOutcome?
}

public struct TravelEncounterEngine {
    private var tableOracle = TableOracleEngine()

    public init() {}

    public func frequency(for environment: TravelEnvironment) -> EncounterFrequency {
        switch environment {
        case .road:
            return EncounterFrequency(
                dieSpec: "d20",
                intervalHours: 4,
                encounterRange: 18...20,
                notes: "Lower chance due to safety."
            )
        case .wilderness:
            return EncounterFrequency(
                dieSpec: "d20",
                intervalHours: 3,
                encounterRange: 15...20,
                notes: "Standard overland travel."
            )
        case .wilds:
            return EncounterFrequency(
                dieSpec: "d12",
                intervalHours: 2,
                encounterRange: 8...12,
                notes: "Denser terrain increases chances."
            )
        case .underground:
            return EncounterFrequency(
                dieSpec: "d12",
                intervalHours: 1,
                encounterRange: 7...12,
                notes: "Frequent checks reflect confined danger."
            )
        case .city:
            return EncounterFrequency(
                dieSpec: "d20",
                intervalHours: 6,
                encounterRange: 19...20,
                notes: "Rare encounters in civilized areas."
            )
        }
    }

    public mutating func resolveTravelEvent(
        campaign: Campaign,
        environment: TravelEnvironment,
        conditions: TravelConditions,
        travelModifier: Int = 0
    ) -> TravelEventResolution {
        let freq = frequency(for: environment)
        let baseModifier = encounterModifier(for: conditions)
        let modifier = baseModifier + travelModifier
        let roll = rollEncounterCheck(campaign: campaign, dieSpec: freq.dieSpec, modifier: modifier, environment: environment)
        let modified = roll + modifier
        let check = EncounterCheckOutcome(
            environment: environment,
            conditions: conditions,
            dieSpec: freq.dieSpec,
            roll: roll,
            modifier: modifier,
            modifiedRoll: modified,
            encounterRange: freq.encounterRange,
            notes: freq.notes
        )

        guard check.triggered else {
            return TravelEventResolution(check: check, event: nil)
        }

        guard let event = tableOracle.rollMessage(
            campaign: campaign,
            tableId: "travel_event",
            tags: ["travel_event", environment.rawValue]
        ) else {
            return TravelEventResolution(check: check, event: nil)
        }

        let followUpTables = followUpTableIds(for: event)
        var followUps: [String] = []
        for tableId in followUpTables {
            if let result = tableOracle.rollMessage(
                campaign: campaign,
                tableId: tableId,
                tags: ["travel_followup", tableId]
            ) {
                followUps.append(result)
            }
        }

        var intensity: String?
        if requiresCombatIntensity(event: event),
           let result = tableOracle.rollMessage(
                campaign: campaign,
                tableId: "combat_encounter_intensity",
                tags: ["combat_encounter", environment.rawValue]
           ) {
            intensity = result
        }

        let outcome = TravelEventOutcome(event: event, followUps: followUps, encounterIntensity: intensity)
        return TravelEventResolution(check: check, event: outcome)
    }

    public mutating func rollExplorationFeature(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "exploration_feature", tags: ["exploration_feature"])
    }

    public mutating func rollWeather(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "weather_conditions", tags: ["weather"])
    }

    public mutating func rollObstacle(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "travel_obstacle", tags: ["obstacle"])
    }

    public mutating func rollPhenomenon(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "phenomenon", tags: ["phenomenon"])
    }

    public mutating func rollNpcReaction(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "npc_reaction", tags: ["npc_reaction"])
    }

    public mutating func rollAnimalEncounter(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "animal_encounter", tags: ["animal_encounter"])
    }

    public mutating func rollQuestHook(campaign: Campaign) -> String? {
        tableOracle.rollMessage(campaign: campaign, tableId: "quest_hook", tags: ["quest_hook"])
    }

    private func encounterModifier(for conditions: TravelConditions) -> Int {
        var modifier = 0
        switch conditions.timeOfDay {
        case .day:
            modifier -= 1
        case .night:
            modifier += 1
        }
        if conditions.badWeather {
            modifier += 2
        }
        return modifier
    }

    private mutating func rollEncounterCheck(
        campaign: Campaign,
        dieSpec: String,
        modifier: Int,
        environment: TravelEnvironment
    ) -> Int {
        let seed = campaign.rngSeed ?? UInt64(Date().timeIntervalSince1970)
        let sequence = campaign.rngSequence ?? 0
        campaign.rngSeed = seed

        var roller = DiceRoller(seed: seed, sequence: sequence)
        let roll = roller.roll(spec: dieSpec)
        let newSequence = sequence + roll.rolls.count
        campaign.rngSequence = newSequence

        let contextSummary = "Travel encounter check (\(environment.rawValue))"
        let record = TableRollRecord(
            tableId: "encounter_check",
            entryRange: "check",
            diceSpec: roll.spec,
            rollTotal: roll.total,
            modifier: modifier,
            seed: seed,
            sequence: newSequence,
            contextSummary: contextSummary,
            outcomeSummary: "Encounter check roll"
        )
        if campaign.tableRolls == nil {
            campaign.tableRolls = [record]
        } else {
            campaign.tableRolls?.append(record)
        }

        return roll.total
    }

    private func followUpTableIds(for event: String) -> [String] {
        let lower = event.lowercased()
        var tables: [String] = []

        if lower.contains("weather") {
            tables.append("weather_conditions")
        }
        if lower.contains("terrain") || lower.contains("hazard") || lower.contains("road hazard") || lower.contains("difficult") {
            tables.append("travel_obstacle")
        }
        if lower.contains("travellers") || lower.contains("traveler") || lower.contains("merchant") || lower.contains("patrol") || lower.contains("authorities") {
            tables.append("npc_reaction")
        }
        if lower.contains("wildlife") {
            tables.append("animal_encounter")
        }
        if lower.contains("clue") || lower.contains("quest") || lower.contains("lost item") {
            tables.append("quest_hook")
        }
        if lower.contains("phenomenon") {
            tables.append("phenomenon")
        }
        if lower.contains("discovery") || lower.contains("landmark") || lower.contains("ruin") {
            tables.append("exploration_feature")
        }

        return tables
    }

    private func requiresCombatIntensity(event: String) -> Bool {
        let lower = event.lowercased()
        return lower.contains("ambush") || lower.contains("dangerous creature") || lower.contains("combat")
    }
}
