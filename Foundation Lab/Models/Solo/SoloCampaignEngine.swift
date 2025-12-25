import Foundation

struct NarrationContextPacket {
    let sceneNumber: Int
    let expectedScene: String
    let chaosFactor: Int
    let roll: Int
    let sceneType: SceneType
    let alterationMethod: AlterationMethod?
    let alterationDetail: String?
    let randomEvent: RandomEvent?
    let recentScenes: [SceneEntry]
    let activeCharacters: [CharacterEntry]
    let activeThreads: [ThreadEntry]
    let recentPlaces: [String]
    let recentCuriosities: [String]
    let recentRollHighlights: [String]
}

struct BookkeepingInput {
    let summary: String
    let newCharacters: [String]
    let newThreads: [String]
    let featuredCharacters: [String]
    let featuredThreads: [String]
    let removedCharacters: [String]
    let removedThreads: [String]
    let pcsInControl: Bool
    let concluded: Bool
    let interactions: [SceneInteraction]
    let skillChecks: [SkillCheckRecord]
    let fateQuestions: [FateQuestionRecord]
    let places: [String]
    let curiosities: [String]
    let rollHighlights: [String]
    let locationId: UUID?
    let generatedEntityIds: [UUID]
    let canonizations: [CanonizationRecord]
}

struct SoloCampaignEngine {
    var resolver: SoloOracleEngine
    var ruleset: any Ruleset

    init(resolver: SoloOracleEngine = SoloOracleEngine(), ruleset: any Ruleset = RulesetCatalog.dnd) {
        self.resolver = resolver
        self.ruleset = ruleset
    }

    func rollD100() -> Int {
        resolver.rollD100()
    }

    mutating func resolveScene(campaign: Campaign, expectedScene: String) -> SceneRecord {
        let roll = resolver.rollD10()
        let type = resolver.classifyScene(chaosFactor: campaign.chaosFactor, roll: roll)

        var record = SceneRecord(
            sceneNumber: campaign.sceneNumber,
            expectedScene: expectedScene,
            roll: roll,
            chaosFactor: campaign.chaosFactor,
            type: type,
            alterationMethod: nil,
            alterationDetail: nil,
            randomEvent: nil
        )

        if type == .interrupt {
            record.randomEvent = resolver.generateRandomEvent()
        }

        return record
    }

    mutating func applyAlterationMethod(
        scene: SceneRecord,
        method: AlterationMethod,
        adjustment: SceneAdjustment
    ) -> SceneRecord {
        var updated = scene
        updated.alterationMethod = method
        updated.alterationDetail = nil

        if method == .meaningWords {
            let words = resolver.generateMeaningWords()
            updated.alterationDetail = "\(words.first) / \(words.second)"
        } else if method == .sceneAdjustment {
            updated.alterationDetail = adjustment.label
        }

        return updated
    }

    func buildNarrationContext(
        campaign: Campaign,
        scene: SceneRecord,
        recentCount: Int = 3
    ) -> NarrationContextPacket {
        let recentScenes = campaign.scenes.sorted { $0.sceneNumber > $1.sceneNumber }
            .prefix(recentCount)
            .sorted { $0.sceneNumber < $1.sceneNumber }

        let recentPlaces = uniqueStrings(from: recentScenes.flatMap { $0.places ?? [] })
        let recentCuriosities = uniqueStrings(from: recentScenes.flatMap { $0.curiosities ?? [] })
        let recentRollHighlights = uniqueStrings(from: recentScenes.flatMap { $0.rollHighlights ?? [] })

        return NarrationContextPacket(
            sceneNumber: scene.sceneNumber,
            expectedScene: scene.expectedScene,
            chaosFactor: scene.chaosFactor,
            roll: scene.roll,
            sceneType: scene.type,
            alterationMethod: scene.alterationMethod,
            alterationDetail: scene.alterationDetail,
            randomEvent: scene.randomEvent,
            recentScenes: Array(recentScenes),
            activeCharacters: campaign.characters.sorted { $0.weight > $1.weight },
            activeThreads: campaign.threads.sorted { $0.weight > $1.weight },
            recentPlaces: recentPlaces,
            recentCuriosities: recentCuriosities,
            recentRollHighlights: recentRollHighlights
        )
    }

    func finalizeCheckRequest(from draft: CheckRequestDraft) -> CheckRequest? {
        guard draft.requiresRoll else { return nil }
        let type = CheckType(rawValue: draft.checkType.trimmingCharacters(in: .whitespacesAndNewlines))
        let skillName = draft.skill.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let type, !skillName.isEmpty else { return nil }
        guard ruleset.skillNames.contains(where: { $0.caseInsensitiveCompare(skillName) == .orderedSame }) else { return nil }

        let abilityOverride = draft.abilityOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOverride = abilityOverride?.isEmpty == false ? abilityOverride : nil
        let validOverride = normalizedOverride.flatMap { override in
            ruleset.abilities.first { $0.caseInsensitiveCompare(override) == .orderedSame }
        }
        let advantage = AdvantageState.from(name: draft.advantageState) ?? .normal

        let dc = clampDC(draft.dc)
        let opponentSkill = draft.opponentSkill?.trimmingCharacters(in: .whitespacesAndNewlines)
        let opponentDC = clampDC(draft.opponentDC)
        let fallbackPartialDC: Int? = {
            guard let dc, draft.partialSuccessOutcome?.isEmpty == false else { return nil }
            return defaultPartialSuccessDC(for: dc)
        }()

        return CheckRequest(
            checkType: type,
            skillName: skillName,
            abilityOverride: validOverride,
            dc: type == .skillCheck ? (dc ?? 10) : nil,
            opponentSkill: type == .contestedCheck ? opponentSkill : nil,
            opponentDC: type == .contestedCheck ? (opponentDC ?? 10) : nil,
            advantageState: advantage,
            stakes: draft.stakes.trimmingCharacters(in: .whitespacesAndNewlines),
            partialSuccessDC: clampDC(draft.partialSuccessDC) ?? fallbackPartialDC,
            partialSuccessOutcome: draft.partialSuccessOutcome?.trimmingCharacters(in: .whitespacesAndNewlines),
            reason: draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func evaluateCheck(request: CheckRequest, roll: Int, modifier: Int) -> CheckResult {
        let total = roll + modifier
        let outcome: String

        switch request.checkType {
        case .skillCheck:
            let dc = request.dc ?? 10
            if total >= dc {
                outcome = "success"
            } else if let partialDC = request.partialSuccessDC, total >= partialDC {
                outcome = "partial_success"
            } else {
                outcome = "failure"
            }
        case .contestedCheck:
            let opponentDC = request.opponentDC ?? 10
            if total >= opponentDC {
                outcome = "success"
            } else {
                outcome = "failure"
            }
        }

        let consequence = outcome == "success" ? "Success." :
            (outcome == "partial_success" ? (request.partialSuccessOutcome ?? "Partial success.") : request.stakes)

        return CheckResult(total: total, outcome: outcome, consequence: consequence)
    }

    func defaultPartialSuccessDC(for dc: Int) -> Int {
        max(5, dc - 5)
    }

    func resolveFateQuestion(
        question: String,
        likelihood: FateLikelihood,
        chaosFactor: Int,
        roll: Int
    ) -> FateQuestionRecord {
        let target = fateTarget(likelihood: likelihood, chaosFactor: chaosFactor)
        let outcome = roll <= target ? "yes" : "no"
        return FateQuestionRecord(
            question: question,
            likelihood: likelihood.rawValue,
            chaosFactor: chaosFactor,
            roll: roll,
            target: target,
            outcome: outcome
        )
    }

    mutating func finalizeScene(
        campaign: Campaign,
        scene: SceneRecord,
        bookkeeping: BookkeepingInput
    ) -> SceneEntry {
        updateCharacters(campaign: campaign, new: bookkeeping.newCharacters, featured: bookkeeping.featuredCharacters, removed: bookkeeping.removedCharacters)
        updateThreads(campaign: campaign, new: bookkeeping.newThreads, featured: bookkeeping.featuredThreads, removed: bookkeeping.removedThreads)

        let updatedChaos = resolver.updateChaosFactor(current: campaign.chaosFactor, pcsInControl: bookkeeping.pcsInControl)
        campaign.chaosFactor = updatedChaos

        let entry = SceneEntry(
            sceneNumber: scene.sceneNumber,
            intent: scene.expectedScene,
            roll: scene.roll,
            chaosFactor: scene.chaosFactor,
            sceneType: scene.type.rawValue,
            alterationMethod: scene.alterationMethod?.label,
            alterationDetail: scene.alterationDetail,
            randomEventFocus: scene.randomEvent?.focus.rawValue,
            meaningWord1: scene.randomEvent?.meaningWords.first,
            meaningWord2: scene.randomEvent?.meaningWords.second,
            summary: bookkeeping.summary,
            charactersAdded: bookkeeping.newCharacters,
            charactersFeatured: bookkeeping.featuredCharacters,
            charactersRemoved: bookkeeping.removedCharacters,
            threadsAdded: bookkeeping.newThreads,
            threadsFeatured: bookkeeping.featuredThreads,
            threadsRemoved: bookkeeping.removedThreads,
            pcsInControl: bookkeeping.pcsInControl,
            concluded: bookkeeping.concluded,
            interactions: bookkeeping.interactions.isEmpty ? nil : bookkeeping.interactions,
            skillChecks: bookkeeping.skillChecks.isEmpty ? nil : bookkeeping.skillChecks,
            fateQuestions: bookkeeping.fateQuestions.isEmpty ? nil : bookkeeping.fateQuestions,
            places: bookkeeping.places.isEmpty ? nil : bookkeeping.places,
            curiosities: bookkeeping.curiosities.isEmpty ? nil : bookkeeping.curiosities,
            rollHighlights: bookkeeping.rollHighlights.isEmpty ? nil : bookkeeping.rollHighlights,
            locationId: bookkeeping.locationId,
            generatedEntityIds: bookkeeping.generatedEntityIds.isEmpty ? nil : bookkeeping.generatedEntityIds,
            canonizations: bookkeeping.canonizations.isEmpty ? nil : bookkeeping.canonizations
        )

        campaign.scenes.append(entry)

        if !bookkeeping.concluded {
            campaign.sceneNumber += 1
        }

        return entry
    }

    private func clampDC(_ dc: Int?) -> Int? {
        guard let dc else { return nil }
        return ruleset.dcBands.min(by: { abs($0 - dc) < abs($1 - dc) })
    }

    private func updateCharacters(
        campaign: Campaign,
        new: [String],
        featured: [String],
        removed: [String]
    ) {
        applyListUpdates(entries: &campaign.characters, new: new, featured: featured, removed: removed, entryFactory: CharacterEntry.init)
    }

    private func updateThreads(
        campaign: Campaign,
        new: [String],
        featured: [String],
        removed: [String]
    ) {
        applyListUpdates(entries: &campaign.threads, new: new, featured: featured, removed: removed, entryFactory: ThreadEntry.init)
    }

    private func applyListUpdates<T: AnyObject>(
        entries: inout [T],
        new: [String],
        featured: [String],
        removed: [String],
        entryFactory: (String, Int) -> T
    ) where T: ListEntryProtocol {
        _ = normalizedKeys(from: new)
        let featuredKeys = normalizedKeys(from: featured)
        let removedKeys = normalizedKeys(from: removed)

        for name in new {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard entries.first(where: { $0.key == key }) == nil else { continue }
            entries.append(entryFactory(trimmed, 1))
        }

        for entry in entries where featuredKeys.contains(entry.key) {
            entry.weight = min(3, entry.weight + 1)
        }

        if !removedKeys.isEmpty {
            entries.removeAll { removedKeys.contains($0.key) }
        }
    }

    private func normalizedKeys(from names: [String]) -> Set<String> {
        Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
    }

    private func uniqueStrings(from values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private func fateTarget(likelihood: FateLikelihood, chaosFactor: Int) -> Int {
        let base: Int
        switch likelihood {
        case .impossible:
            base = 5
        case .unlikely:
            base = 25
        case .fiftyFifty:
            base = 50
        case .likely:
            base = 70
        case .veryLikely:
            base = 85
        case .nearlyCertain:
            base = 95
        }

        let modifier = (chaosFactor - 5) * 5
        return max(5, min(95, base + modifier))
    }
}

protocol ListEntryProtocol: AnyObject {
    var name: String { get set }
    var key: String { get set }
    var weight: Int { get set }
}

extension CharacterEntry: ListEntryProtocol {}
extension ThreadEntry: ListEntryProtocol {}

extension AdvantageState {
    static func from(name: String?) -> AdvantageState? {
        guard let name else { return nil }
        return AdvantageState.allCases.first { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame }
    }
}

extension FateLikelihood {
    static func from(name: String?) -> FateLikelihood? {
        guard let name else { return nil }
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "")
        return FateLikelihood.allCases.first { $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame }
    }
}
