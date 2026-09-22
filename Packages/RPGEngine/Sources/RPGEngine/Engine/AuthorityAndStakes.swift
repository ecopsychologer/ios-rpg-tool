import Foundation
import WorldState

public enum WorldAssumptionKind: String, Codable, Sendable {
    case weather
    case companion
    case characterHistory = "character_history"
    case motive
    case feeling
    case commitment
    case other
}

public enum WorldAssumptionStatus: String, Codable, Sendable {
    case proposed
    case accepted
    case softened
    case rejected
    case confirmationRequired = "confirmation_required"
}

public struct WorldAssumption: Codable, Equatable, Sendable {
    public let kind: WorldAssumptionKind
    public let proposedValue: String
    public let sourceText: String
    public let status: WorldAssumptionStatus
    public let requiresPlayerConfirmation: Bool

    public init(
        kind: WorldAssumptionKind,
        proposedValue: String,
        sourceText: String,
        status: WorldAssumptionStatus = .proposed,
        requiresPlayerConfirmation: Bool = false
    ) {
        self.kind = kind
        self.proposedValue = proposedValue
        self.sourceText = sourceText
        self.status = requiresPlayerConfirmation ? .confirmationRequired : status
        self.requiresPlayerConfirmation = requiresPlayerConfirmation
    }
}

public struct PlayerAuthorityEnvelope: Codable, Equatable, Sendable {
    public let originalInput: String
    public let characterIntent: String
    public let worldAssumptions: [WorldAssumption]

    public init(originalInput: String, characterIntent: String, worldAssumptions: [WorldAssumption]) {
        self.originalInput = originalInput
        self.characterIntent = characterIntent
        self.worldAssumptions = worldAssumptions
    }
}

public struct PlayerAuthorityParser: Sendable {
    public init() {}

    public func parse(_ input: String) -> PlayerAuthorityEnvelope {
        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        var assumptions: [WorldAssumption] = []
        var intent = clean

        if let weather = weatherPhrase(in: lower) {
            assumptions.append(WorldAssumption(kind: .weather, proposedValue: weather.value, sourceText: weather.phrase))
            intent = removingCaseInsensitive(weather.phrase, from: intent)
        }

        let personalPatterns: [(WorldAssumptionKind, [String])] = [
            (.companion, ["sidekick", "companion", "hireling", "familiar"]),
            (.characterHistory, ["grew up", "was raised", "used to live", "my childhood"]),
            (.motive, [" wants ", " seeks ", "desires ", "is determined to"]),
            (.feeling, [" feels ", "feel terrified", "feel afraid", "feel compelled"]),
            (.commitment, ["i swear", "i vow", "will never", "will always"])
        ]
        for (kind, markers) in personalPatterns where markers.contains(where: lower.contains) {
            assumptions.append(
                WorldAssumption(
                    kind: kind,
                    proposedValue: clean,
                    sourceText: clean,
                    requiresPlayerConfirmation: true
                )
            )
        }

        intent = intent.replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: " .", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PlayerAuthorityEnvelope(originalInput: clean, characterIntent: intent, worldAssumptions: assumptions)
    }

    private func weatherPhrase(in lower: String) -> (phrase: String, value: String)? {
        let weatherValues = [
            "violent storm", "thunderstorm", "snowstorm", "storm", "heavy rain", "rain", "blizzard", "fog", "strong wind"
        ]
        for value in weatherValues {
            for prefix in ["in a ", "in the ", "during a ", "through a ", "through the ", "amid a "] {
                let phrase = prefix + value
                if lower.contains(phrase) { return (phrase, value) }
            }
        }
        return nil
    }

    private func removingCaseInsensitive(_ phrase: String, from source: String) -> String {
        guard let range = source.range(of: phrase, options: .caseInsensitive) else { return source }
        var output = source
        output.removeSubrange(range)
        return output
    }
}

public enum WeatherAuthorityPolicy: String, Codable, Sendable {
    case acceptPlausible = "accept_plausible"
    case softenExtreme = "soften_extreme"
    case preserveEstablished = "preserve_established"
}

public enum WeatherAuthorityResolution: String, Codable, Sendable {
    case accepted
    case softened
    case rejected
}

public struct WeatherAuthorityDecision: Codable, Equatable, Sendable {
    public let proposedWeather: String
    public let canonicalWeather: String?
    public let resolution: WeatherAuthorityResolution
    public let rationale: String

    public init(proposedWeather: String, canonicalWeather: String?, resolution: WeatherAuthorityResolution, rationale: String) {
        self.proposedWeather = proposedWeather
        self.canonicalWeather = canonicalWeather
        self.resolution = resolution
        self.rationale = rationale
    }
}

public struct WorldAuthorityEngine: Sendable {
    public init() {}

    public func adjudicateWeather(
        _ assumption: WorldAssumption,
        establishedWeather: String? = nil,
        policy: WeatherAuthorityPolicy = .acceptPlausible
    ) -> WeatherAuthorityDecision {
        precondition(assumption.kind == .weather, "Weather adjudication requires a weather assumption.")
        let proposed = assumption.proposedValue
        switch policy {
        case .acceptPlausible:
            return WeatherAuthorityDecision(
                proposedWeather: proposed,
                canonicalWeather: proposed,
                resolution: .accepted,
                rationale: "The GM accepts the proposed weather as the current external condition."
            )
        case .softenExtreme:
            let softened = proposed.contains("storm") ? "cold storm" : "unsettled \(proposed)"
            return WeatherAuthorityDecision(
                proposedWeather: proposed,
                canonicalWeather: softened,
                resolution: .softened,
                rationale: "The GM keeps the weather premise but limits its severity."
            )
        case .preserveEstablished:
            return WeatherAuthorityDecision(
                proposedWeather: proposed,
                canonicalWeather: establishedWeather,
                resolution: .rejected,
                rationale: "The GM preserves the weather already established for the scene."
            )
        }
    }
}

public enum HiddenThreatKind: String, Codable, Sendable {
    case clue
    case clock
}

public struct HiddenThreatRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let kind: HiddenThreatKind
    public let clockCurrent: Int
    public let clockMaximum: Int

    public init(id: UUID = UUID(), label: String, kind: HiddenThreatKind, clockCurrent: Int, clockMaximum: Int) {
        self.id = id
        self.label = label
        self.kind = kind
        self.clockCurrent = max(0, clockCurrent)
        self.clockMaximum = max(1, clockMaximum)
    }
}

public struct CampaignAuthorityState: Codable, Equatable, Sendable {
    public var weather: String?
    public var weatherDecision: WeatherAuthorityResolution?
    public var hiddenThreats: [HiddenThreatRecord]

    public init(weather: String? = nil, weatherDecision: WeatherAuthorityResolution? = nil, hiddenThreats: [HiddenThreatRecord] = []) {
        self.weather = weather
        self.weatherDecision = weatherDecision
        self.hiddenThreats = hiddenThreats
    }
}

public struct CampaignAuthorityStateStore: Sendable {
    public init() {}

    public func load(from campaign: Campaign) -> CampaignAuthorityState? {
        guard let json = campaign.authorityStateJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CampaignAuthorityState.self, from: data)
    }

    public func save(_ state: CampaignAuthorityState, to campaign: Campaign) -> Bool {
        guard let data = try? JSONEncoder().encode(state),
              let json = String(data: data, encoding: .utf8) else { return false }
        campaign.authorityStateJSON = json
        return true
    }
}

public enum StakesMutationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case sceneFact = "scene_fact"
    case clue
    case hiddenClock = "hidden_clock"
    case lore
    case weather
    case time
    case progress
    case exposure
    case delay
    case encounterRisk = "encounter_risk"
    case map
    case location
    case quest
    case treasure
    case npc
    case item
    case playerChoice = "player_choice"
    case playerFeeling = "player_feeling"
    case playerCommitment = "player_commitment"
}

public enum StakesOutcome: String, Codable, Sendable {
    case criticalSuccess = "critical_success"
    case success
    case partialSuccess = "partial_success"
    case failure
    case criticalFailure = "critical_failure"
}

public struct DeclaredStakes: Codable, Equatable, Sendable {
    public let success: String
    public let partial: String
    public let failure: String
    public let criticalSuccess: String
    public let criticalFailure: String
    public let allowedMutations: [StakesMutationKind]
    public let forbiddenMutations: [StakesMutationKind]

    public init(
        success: String,
        partial: String,
        failure: String,
        criticalSuccess: String,
        criticalFailure: String,
        allowedMutations: [StakesMutationKind],
        forbiddenMutations: [StakesMutationKind]
    ) {
        self.success = success
        self.partial = partial
        self.failure = failure
        self.criticalSuccess = criticalSuccess
        self.criticalFailure = criticalFailure
        self.allowedMutations = allowedMutations
        self.forbiddenMutations = forbiddenMutations
    }
}

public struct StakesResolution: Equatable, Sendable {
    public let outcome: StakesOutcome
    public let consequence: String
    public let approvedMutations: [StakesMutationKind]
    public let rejectedMutations: [StakesMutationKind]
}

public struct StakesResolver: Sendable {
    public init() {}

    public func resolve(
        roll: Int,
        ordinaryOutcome: StakesOutcome,
        stakes: DeclaredStakes,
        proposedMutations: [StakesMutationKind]
    ) -> StakesResolution {
        let outcome: StakesOutcome
        if roll == 20 {
            outcome = .criticalSuccess
        } else if roll == 1 {
            outcome = .criticalFailure
        } else {
            outcome = ordinaryOutcome
        }

        let allowed = Set(stakes.allowedMutations)
        let forbidden = Set(stakes.forbiddenMutations)
        let approved = proposedMutations.filter { allowed.contains($0) && !forbidden.contains($0) }
        let rejected = proposedMutations.filter { !allowed.contains($0) || forbidden.contains($0) }
        let consequence: String
        switch outcome {
        case .criticalSuccess: consequence = stakes.criticalSuccess
        case .success: consequence = stakes.success
        case .partialSuccess: consequence = stakes.partial
        case .failure: consequence = stakes.failure
        case .criticalFailure: consequence = stakes.criticalFailure
        }
        return StakesResolution(
            outcome: outcome,
            consequence: consequence,
            approvedMutations: unique(approved),
            rejectedMutations: unique(rejected)
        )
    }

    private func unique(_ values: [StakesMutationKind]) -> [StakesMutationKind] {
        var seen: Set<StakesMutationKind> = []
        return values.filter { seen.insert($0).inserted }
    }
}
