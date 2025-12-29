import Foundation
import WorldState

public enum MagicItemRarity: String, CaseIterable, Sendable {
    case common
    case uncommon
    case rare
    case veryRare
    case legendary
}

public struct LootItem: Sendable {
    public let name: String
    public let category: String
    public let rarity: MagicItemRarity?
    public let source: String
}

public struct LootEngine {
    public init() {}

    public func randomLoot(
        campaign: Campaign,
        characterLevel: Int,
        includeMagic: Bool = true
    ) -> [LootItem] {
        guard let index = RulesetCatalog.srdIndex() else { return [] }
        var results: [LootItem] = []

        if includeMagic, let rarity = pickMagicRarity(level: characterLevel) {
            let magicItems = index.magicItemRarities
                .filter { matchesRarity($0.value, target: rarity) }
                .map { $0.key }
            if let itemName = magicItems.randomElement() {
                results.append(
                    LootItem(
                        name: itemName,
                        category: "Magic Item",
                        rarity: rarity,
                        source: index.source
                    )
                )
            }
        }

        if results.isEmpty, let itemName = index.equipment.randomElement() {
            results.append(
                LootItem(
                    name: itemName,
                    category: "Equipment",
                    rarity: nil,
                    source: index.source
                )
            )
        }

        return results
    }

    private func pickMagicRarity(level: Int) -> MagicItemRarity? {
        if level >= 17 {
            return MagicItemRarity.allCases.randomElement()
        }
        if level >= 11 {
            return [MagicItemRarity.common, .uncommon, .rare, .veryRare].randomElement()
        }
        if level >= 5 {
            return [MagicItemRarity.common, .uncommon, .rare].randomElement()
        }
        if level >= 1 {
            return [MagicItemRarity.common, .uncommon].randomElement()
        }
        return nil
    }

    private func matchesRarity(_ value: String, target: MagicItemRarity) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == target.rawValue.lowercased()
    }
}
