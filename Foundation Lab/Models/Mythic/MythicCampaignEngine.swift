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
}

struct MythicCampaignEngine {
    var resolver: MythicEngine

    init(resolver: MythicEngine = MythicEngine()) {
        self.resolver = resolver
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
            activeThreads: campaign.threads.sorted { $0.weight > $1.weight }
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
            concluded: bookkeeping.concluded
        )

        campaign.scenes.append(entry)

        if !bookkeeping.concluded {
            campaign.sceneNumber += 1
        }

        return entry
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
}

protocol ListEntryProtocol: AnyObject {
    var name: String { get set }
    var key: String { get set }
    var weight: Int { get set }
}

extension CharacterEntry: ListEntryProtocol {}
extension ThreadEntry: ListEntryProtocol {}
