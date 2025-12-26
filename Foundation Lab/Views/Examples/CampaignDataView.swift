import SwiftUI
import SwiftData
import WorldState

struct CampaignDataView: View {
    @Query private var campaigns: [Campaign]
    @Query private var clues: [ClueEntity]
    @Query private var rumors: [RumorEntity]
    @Query private var quests: [QuestEntity]
    @Query private var encounters: [EncounterEntity]
    @State private var selectedCampaignId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection

                if let campaign = activeCampaign {
                    campaignOverviewSection(campaign)
                    scenesSection(campaign)
                    locationsSection(campaign)
                    npcsSection(campaign)
                    playerCharactersSection(campaign)
                    worldLoreSection(campaign)
                    rollsSection(campaign)
                    extraEntitiesSection
                } else {
                    Text("No campaigns yet. Start a solo scene to create one.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.large)
        }
        .textSelection(.enabled)
        .navigationTitle("Campaign Data")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }

    private var activeCampaign: Campaign? {
        if let selectedCampaignId {
            return campaigns.first(where: { $0.id == selectedCampaignId })
        }
        return campaigns.first(where: { $0.isActive }) ?? campaigns.first
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("CAMPAIGN DATA")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Browse saved campaign structures, locations, and rolls.")
                .font(.callout)
                .foregroundColor(.secondary)

            if !campaigns.isEmpty {
                Picker("Campaign", selection: $selectedCampaignId) {
                    Text("Active campaign").tag(Optional<UUID>.none)
                    ForEach(campaigns) { campaign in
                        Text(campaign.title).tag(Optional(campaign.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func campaignOverviewSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("OVERVIEW")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Title: \(campaign.title)")
            Text("Created: \(campaign.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Ruleset: \(campaign.rulesetName ?? "Unknown")")
            Text("Content Pack: \(campaign.contentPackVersion ?? "Unknown")")
            Text("Chaos Factor: \(campaign.chaosFactor)")
            Text("Scene #: \(campaign.sceneNumber)")
            if !campaign.worldVibe.isEmpty {
                Text("World Vibe: \(campaign.worldVibe)")
            }
            if let party = campaign.party {
                let names = party.members?.map { $0.name }.joined(separator: ", ") ?? "None"
                Text("Party: \(names)")
            }

            if let location = campaign.locations?.first(where: { $0.id == campaign.activeLocationId }) {
                Text("Active Location: \(location.name) (\(location.type))")
            } else {
                Text("Active Location: none")
                    .foregroundColor(.secondary)
            }
        }
        .font(.callout)
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func scenesSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("SCENES")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if campaign.scenes.isEmpty {
                Text("No scenes recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(campaign.scenes.sorted(by: { $0.sceneNumber > $1.sceneNumber })) { scene in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text(scene.summary)
                            Text("Type: \(scene.sceneType.capitalized) · CF \(scene.chaosFactor)")
                                .foregroundColor(.secondary)

                            if let locationId = scene.locationId {
                                Text("Location ID: \(locationId.uuidString)")
                                    .foregroundColor(.secondary)
                            }

                            if let canon = scene.canonizations, !canon.isEmpty {
                                let list = canon.map { "\($0.assumption) => \($0.outcome.uppercased())" }.joined(separator: " | ")
                                Text("Canonizations: \(list)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.callout)
                    } label: {
                        Text("Scene \(scene.sceneNumber)")
                            .font(.callout)
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func locationsSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("LOCATIONS")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let locations = campaign.locations, !locations.isEmpty {
                ForEach(locations) { location in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("Type: \(location.type)")
                            Text("Origin: \(location.origin)")
                                .foregroundColor(.secondary)

                            if let nodes = location.nodes, !nodes.isEmpty {
                                Text("Nodes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(nodes) { node in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(node.summary)
                                        Text("Type: \(node.type) · Origin: \(node.origin)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if let traps = node.traps, !traps.isEmpty {
                                            let trapText = traps.map { "\($0.name) [\($0.state)] (\($0.origin))" }.joined(separator: ", ")
                                            Text("Traps: \(trapText)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        if let features = node.features, !features.isEmpty {
                                            let featureText = features.map { "\($0.name) (\($0.origin))" }.joined(separator: ", ")
                                            Text("Features: \(featureText)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(Spacing.small)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }

                            if let edges = location.edges, !edges.isEmpty {
                                Text("Edges")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(edges) { edge in
                                    Text("\(edge.type) · Locked: \(edge.isLocked ? "Yes" : "No") · Trapped: \(edge.isTrapped ? "Yes" : "No") · \(edge.origin)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .font(.callout)
                    } label: {
                        Text(location.name)
                            .font(.callout)
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            } else {
                Text("No locations generated yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func npcsSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("NPCS")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if campaign.npcs.isEmpty {
                Text("No NPCs recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(campaign.npcs) { npc in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(npc.species) · \(npc.roleTag) · \(npc.importance)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !npc.currentMood.isEmpty {
                                Text("Mood: \(npc.currentMood) · Attitude: \(npc.attitudeToParty)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !npc.goalsImmediate.isEmpty {
                                Text("Goals: \(npc.goalsImmediate.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if !npc.notableFeatures.isEmpty {
                                Text("Notable: \(npc.notableFeatures.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.callout)
                    } label: {
                        Text(npc.name.isEmpty ? "Unnamed NPC" : npc.name)
                            .font(.callout)
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func playerCharactersSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("PLAYER CHARACTERS")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if campaign.playerCharacters.isEmpty {
                Text("No player characters recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(campaign.playerCharacters) { character in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(character.displayName.isEmpty ? "Unnamed Character" : character.displayName)
                            .font(.callout)
                        Text("Ruleset: \(character.rulesetId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func worldLoreSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("WORLD LORE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if campaign.worldLore.isEmpty {
                Text("No lore recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(campaign.worldLore) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                            .font(.callout)
                        Text(entry.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if !entry.tags.isEmpty {
                            Text("Tags: \(entry.tags.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            }
        }
    }

    private func rollsSection(_ campaign: Campaign) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("TABLE ROLLS")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let rolls = campaign.tableRolls, !rolls.isEmpty {
                ForEach(rolls.sorted(by: { $0.timestamp > $1.timestamp }).prefix(10)) { roll in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Table: \(roll.tableId) · Roll: \(roll.rollTotal)")
                        Text("Context: \(roll.contextSummary)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.callout)
                    .padding(Spacing.small)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                Text("No table rolls recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var extraEntitiesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("OTHER ENTITIES")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if !clues.isEmpty {
                Text("Clues")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(clues) { clue in
                    Text("\(clue.text) · \(clue.confidence) · \(clue.origin)")
                        .font(.callout)
                }
            }

            if !rumors.isEmpty {
                Text("Rumors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(rumors) { rumor in
                    Text("\(rumor.text) · \(rumor.origin)")
                        .font(.callout)
                }
            }

            if !quests.isEmpty {
                Text("Quests")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(quests) { quest in
                    Text("\(quest.title) · \(quest.progress) · \(quest.origin)")
                        .font(.callout)
                }
            }

            if !encounters.isEmpty {
                Text("Encounters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(encounters) { encounter in
                    Text("\(encounter.type) · \(encounter.difficulty) · \(encounter.origin)")
                        .font(.callout)
                }
            }

            if clues.isEmpty && rumors.isEmpty && quests.isEmpty && encounters.isEmpty {
                Text("No additional entities recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        CampaignDataView()
    }
}
