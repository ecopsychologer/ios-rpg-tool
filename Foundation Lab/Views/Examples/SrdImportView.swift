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
                    Text("Feats: \(index.feats.count)")
                    Text("Equipment: \(index.equipment.count)")
                    Text("Spells: \(index.spells.count)")
                    Text("Magic Items: \(index.magicItems.count)")
                    Text("Creatures: \(index.creatures.count)")
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
                            let details = index.equipmentDetails[item] ?? []
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
                            let details = index.magicItemDetails[item] ?? []
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
                            let details = index.creatureDetails[item] ?? []
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
                            Text(item)
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
                }
                if lines.isEmpty {
                    Text("No additional detail found in the SRD.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal, Spacing.medium)
        }
        .navigationTitle(title)
    }
}
