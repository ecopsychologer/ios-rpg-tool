import SwiftUI
import Foundation
import RPGEngine

struct SrdImportView: View {
    @State private var statusMessage = ""
    @State private var isLoadingIndex = false
    @State private var index: SrdContentIndex?
    @State private var filterText = ""

    var body: some View {
        List {
            Section {
                Text("Use SRD reference data to power rules-aware prompts, skills, species, and equipment.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            } header: {
                Text("SRD Reference Data")
            }

            Section("Bundled SRD") {
                Text("This SRD is included with the app. Replace it by updating the repo or bundle.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                Button(isLoadingIndex ? "Loading..." : "Reload SRD") {
                    loadIndex(forceBundled: true)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingIndex)

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }

            Section("Current SRD") {
                if let index {
                    Text("Source: \(index.source)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Abilities: \(index.abilities.count)")
                    Text("Skills: \(index.skills.count)")
                    Text("Species: \(index.species.count)")
                    Text("Classes: \(index.classes.count)")
                    Text("Backgrounds: \(index.backgrounds.count)")
                    Text("Subclasses: \(index.subclasses.count)")
                    Text("Feats: \(index.feats.count)")
                    Text("Equipment: \(index.equipment.count)")
                    Text("Spells: \(index.spells.count)")
                    Text("Magic Items: \(index.magicItems.count)")
                    Text("Creatures: \(index.creatures.count)")
                    Text("Conditions: \(index.conditions.count)")
                    Text("Sections: \(index.sections.count)")
                } else if isLoadingIndex {
                    Text("Loading SRD index...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No SRD loaded yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let index {
                Section("Reference Lists") {
                    DisclosureGroup("Abilities (\(filtered(index.abilities).count))") {
                        ForEach(filtered(index.abilities), id: \.self) { ability in
                            Text(ability)
                                .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Skills (\(filteredSkills.count))") {
                        ForEach(filteredSkills, id: \.name) { skill in
                            Text("\(skill.name) (\(skill.defaultAbility))")
                                .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Species (\(filtered(index.species).count))") {
                        ForEach(filtered(index.species), id: \.self) { item in
                            Text(item)
                                .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Classes (\(filtered(index.classes).count))") {
                        ForEach(filtered(index.classes), id: \.self) { item in
                            let details = index.classDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Class",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Backgrounds (\(filtered(index.backgrounds).count))") {
                        ForEach(filtered(index.backgrounds), id: \.self) { item in
                            let details = index.backgroundDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Background",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Subclasses (\(filtered(index.subclasses).count))") {
                        ForEach(filtered(index.subclasses), id: \.self) { item in
                            let details = index.subclassDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Subclass",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Conditions (\(filtered(index.conditions).count))") {
                        ForEach(filtered(index.conditions), id: \.self) { item in
                            let details = index.conditionDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Condition",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Feats (\(filtered(index.feats).count))") {
                        ForEach(filtered(index.feats), id: \.self) { item in
                            let details = index.featDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Feat",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Equipment (\(filtered(index.equipment).count))") {
                        ForEach(filtered(index.equipment), id: \.self) { item in
                            let details = itemDetailLines(for: item, index: index)
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Equipment",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Spells (\(filtered(index.spells).count))") {
                        ForEach(filtered(index.spells), id: \.self) { item in
                            let details = index.spellDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Spell",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Magic Items (\(filtered(index.magicItems).count))") {
                        ForEach(filtered(index.magicItems), id: \.self) { item in
                            let details = itemDetailLines(for: item, index: index)
                            let rarity = index.magicItemRarities[item]
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: rarity.map { "Magic Item · \($0)" } ?? "Magic Item",
                                    lines: details
                                )
                            } label: {
                                HStack {
                                    Text(item)
                                    if let rarity, !rarity.isEmpty {
                                        Text(rarity.capitalized)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Creatures (\(filtered(index.creatures).count))") {
                        ForEach(filtered(index.creatures), id: \.self) { item in
                            let details = creatureDetailLines(for: item, index: index)
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Creature",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }

                    DisclosureGroup("Sections (\(filtered(index.sections).count))") {
                        ForEach(filtered(index.sections), id: \.self) { item in
                            let details = index.sectionDetails[item] ?? []
                            NavigationLink {
                                SrdDetailView(
                                    title: item,
                                    subtitle: "Rules",
                                    lines: details
                                )
                            } label: {
                                Text(item)
                            }
                            .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .textSelection(.enabled)
        .navigationTitle("SRD Library")
        .searchable(text: $filterText, prompt: "Filter SRD content")
        .onAppear { loadIndex(forceBundled: false) }
    }

    private func itemDetailLines(for name: String, index: SrdContentIndex) -> [String] {
        if let record = index.itemRecords.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            var lines: [String] = []
            lines.append("**Category:** \(record.category)")
            if let sub = record.subcategory, !sub.isEmpty {
                lines.append("**Subcategory:** \(sub)")
            }
            if let type = record.itemType, !type.isEmpty {
                lines.append("**Type:** \(type)")
            }
            if let rarity = record.rarity, !rarity.isEmpty {
                lines.append("**Rarity:** \(rarity.capitalized)")
            }
            if record.requiresAttunement {
                lines.append("**Requires Attunement:** Yes")
            }
            if let attune = record.attunementRequirement, !attune.isEmpty {
                lines.append("**Attunement:** \(attune)")
            }
            if let cost = record.cost, !cost.isEmpty {
                lines.append("**Cost:** \(cost)")
            }
            if let weight = record.weight, !weight.isEmpty {
                lines.append("**Weight:** \(weight)")
            }
            if !record.properties.isEmpty {
                lines.append("**Properties:** \(record.properties.joined(separator: ", "))")
            }
            lines.append(contentsOf: record.description)
            return lines
        }
        if let details = index.equipmentDetails[name] {
            return details
        }
        if let details = index.magicItemDetails[name] {
            return details
        }
        return []
    }

    private func creatureDetailLines(for name: String, index: SrdContentIndex) -> [String] {
        if let record = index.creatureRecords.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            var lines: [String] = []
            if let size = record.size, let type = record.creatureType {
                let alignment = record.alignment ?? ""
                lines.append("*\(size) \(type)\(alignment.isEmpty ? "" : ", \(alignment)")*")
            }
            if let armorClass = record.armorClass { lines.append("**Armor Class** \(armorClass)") }
            if let hitPoints = record.hitPoints { lines.append("**Hit Points** \(hitPoints)") }
            if let speed = record.speed { lines.append("**Speed** \(speed)") }
            if !record.abilityScores.isEmpty {
                let scoreLine = record.abilityScores.map { "\($0.key) \($0.value)" }.joined(separator: " | ")
                lines.append(scoreLine)
            }
            if let vulnerabilities = record.damageVulnerabilities { lines.append("**Damage Vulnerabilities** \(vulnerabilities)") }
            if let resistances = record.damageResistances { lines.append("**Damage Resistances** \(resistances)") }
            if let immunities = record.damageImmunities { lines.append("**Damage Immunities** \(immunities)") }
            if let conditions = record.conditionImmunities { lines.append("**Condition Immunities** \(conditions)") }
            if let saves = record.savingThrows { lines.append("**Saving Throws** \(saves)") }
            if let skills = record.skills { lines.append("**Skills** \(skills)") }
            if let senses = record.senses { lines.append("**Senses** \(senses)") }
            if let languages = record.languages { lines.append("**Languages** \(languages)") }
            if let challenge = record.challenge { lines.append("**Challenge** \(challenge)") }
            if !record.traits.isEmpty {
                lines.append("**Traits**")
                lines.append(contentsOf: record.traits)
            }
            if !record.actions.isEmpty {
                lines.append("**Actions**")
                lines.append(contentsOf: record.actions)
            }
            if !record.reactions.isEmpty {
                lines.append("**Reactions**")
                lines.append(contentsOf: record.reactions)
            }
            if !record.legendaryActions.isEmpty {
                lines.append("**Legendary Actions**")
                lines.append(contentsOf: record.legendaryActions)
            }
            return lines
        }
        return index.creatureDetails[name] ?? []
    }

    private func loadIndex(forceBundled: Bool) {
        isLoadingIndex = true
        statusMessage = ""
        Task {
            defer { isLoadingIndex = false }
            if forceBundled {
                _ = try? SrdContentStore().importBundledSRD()
            }
            index = SrdContentStore().loadIndex()
            if index == nil {
                statusMessage = "Bundled SRD not found."
            }
        }
    }

    private func filtered(_ values: [String]) -> [String] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return values }
        return values.filter { $0.range(of: query, options: .caseInsensitive) != nil }
    }

    private var filteredSkills: [SkillDefinition] {
        guard let index else { return [] }
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return index.skills }
        return index.skills.filter {
            $0.name.range(of: query, options: .caseInsensitive) != nil ||
            $0.defaultAbility.range(of: query, options: .caseInsensitive) != nil
        }
    }
}

private struct SrdDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let subtitle: String?
    let lines: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                if lines.isEmpty {
                    Text("No additional detail found in the SRD.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    let markdown = lines.joined(separator: "\n\n")
                    if let attributed = try? AttributedString(markdown: markdown) {
                        Text(attributed)
                            .textSelection(.enabled)
                    } else {
                        Text(markdown)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal, Spacing.medium)
        }
        .textSelection(.enabled)
        .navigationTitle(title)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
        }
    }
}
