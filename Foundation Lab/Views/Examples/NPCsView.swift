import SwiftUI
import SwiftData

struct NPCsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @State private var campaign: Campaign?
    @State private var npcEngine = SoloNpcEngine()
    @State private var showAddSheet = false
    @State private var showGenerateSheet = false
    @State private var editingNpc: NPCEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection

                if let campaign = campaign, campaign.npcs.isEmpty {
                    Text("No NPCs yet. Add or generate one to start building your cast.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                } else {
                    npcListSection
                }
            }
            .padding(.vertical)
        }
        .textSelection(.enabled)
        .navigationTitle("NPCs")
        .onAppear { ensureCampaign() }
        .sheet(isPresented: $showAddSheet) {
            NPCEditSheet(
                title: "Add NPC",
                npc: nil,
                onSave: { npc in
                    addNpc(npc)
                }
            )
        }
        .sheet(isPresented: $showGenerateSheet) {
            NPCGenerateSheet(
                onGenerate: { options in
                    generateNpc(options: options)
                    showGenerateSheet = false
                }
            )
        }
        .sheet(item: $editingNpc) { npc in
            NPCEditSheet(
                title: "Edit NPC",
                npc: npc,
                onSave: { _ in
                    npc.updatedAt = Date()
                    try? modelContext.save()
                }
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Track major and minor NPCs with fast reference fields and expandable details.")
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            HStack(spacing: Spacing.medium) {
                Button("Add NPC") {
                    showAddSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("Generate NPC") {
                    showGenerateSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    private var npcListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            ForEach(campaign?.npcs ?? []) { npc in
                Button {
                    editingNpc = npc
                } label: {
                    NPCHeaderCard(npc: npc)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func addNpc(_ npc: NPCEntry) {
        ensureCampaign()
        guard let campaign else { return }
        campaign.npcs.append(npc)
        try? modelContext.save()
    }

    private func generateNpc(options: NpcGenerationOptions) {
        ensureCampaign()
        guard let campaign else { return }
        if let npc = npcEngine.generateNPC(campaign: campaign, options: options) {
            campaign.npcs.append(npc)
            try? modelContext.save()
        }
    }

    private func ensureCampaign() {
        if let existing = campaigns.first {
            campaign = existing
        } else {
            let newCampaign = Campaign()
            modelContext.insert(newCampaign)
            campaign = newCampaign
            try? modelContext.save()
        }
    }
}

private struct NPCHeaderCard: View {
    let npc: NPCEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(npc.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(npc.species) - \(npc.roleTag)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(npc.importance.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !npc.currentMood.isEmpty || !npc.attitudeToParty.isEmpty {
                Text("Mood: \(npc.currentMood.isEmpty ? "unknown" : npc.currentMood) | Attitude: \(npc.attitudeToParty)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let ac = npc.ac, let hpMax = npc.hpMax {
                let hpText = npc.hpCurrent.map { "\($0)/\(hpMax)" } ?? "\(hpMax)"
                Text("AC \(ac) | HP \(hpText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let goal = npc.goalsImmediate.first {
                Text("Goal: \(goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !npc.notableFeatures.isEmpty {
                Text("Notable: \(npc.notableFeatures.prefix(2).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

private struct NPCGenerateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var species = ""
    @State private var roleTag = ""
    @State private var importance: NPCImportance = .minor

    let onGenerate: (NpcGenerationOptions) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Optional Overrides") {
                    TextField("Name (optional)", text: $name)
                    TextField("Species (optional)", text: $species)
                    TextField("Role Tag (optional)", text: $roleTag)
                    Picker("Importance", selection: $importance) {
                        ForEach(NPCImportance.allCases) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                }
            }
            .navigationTitle("Generate NPC")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        let options = NpcGenerationOptions(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name,
                            species: species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : species,
                            roleTag: roleTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : roleTag,
                            importance: importance
                        )
                        onGenerate(options)
                    }
                }
            }
        }
    }
}

private struct NPCEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let npc: NPCEntry?
    let onSave: (NPCEntry) -> Void

    @State private var name: String = ""
    @State private var species: String = ""
    @State private var roleTag: String = ""
    @State private var importance: String = NPCImportance.minor.rawValue
    @State private var mood: String = ""
    @State private var attitude: String = NPCAttitude.neutral.rawValue
    @State private var ac: String = ""
    @State private var hpMax: String = ""
    @State private var hpCurrent: String = ""
    @State private var notableFeatures: String = ""
    @State private var goalsImmediate: String = ""
    @State private var quirks: String = ""
    @State private var flaws: String = ""
    @State private var appearanceShort: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                    TextField("Species", text: $species)
                    TextField("Role Tag", text: $roleTag)
                    Picker("Importance", selection: $importance) {
                        ForEach(NPCImportance.allCases) { value in
                            Text(value.rawValue.capitalized).tag(value.rawValue)
                        }
                    }
                }

                Section("State") {
                    TextField("Current Mood", text: $mood)
                    Picker("Attitude", selection: $attitude) {
                        ForEach(NPCAttitude.allCases) { value in
                            Text(value.rawValue.capitalized).tag(value.rawValue)
                        }
                    }
                }

                Section("Combat Snapshot") {
                    TextField("AC", text: $ac)
                        .keyboardType(.numberPad)
                    TextField("HP Max", text: $hpMax)
                        .keyboardType(.numberPad)
                    TextField("HP Current", text: $hpCurrent)
                        .keyboardType(.numberPad)
                }

                Section("Quick Reference") {
                    TextField("Appearance Short", text: $appearanceShort, axis: .vertical)
                    TextField("Notable Features (comma-separated)", text: $notableFeatures, axis: .vertical)
                    TextField("Immediate Goals (comma-separated)", text: $goalsImmediate, axis: .vertical)
                    TextField("Quirks (comma-separated)", text: $quirks, axis: .vertical)
                    TextField("Flaws (comma-separated)", text: $flaws, axis: .vertical)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = npc ?? NPCEntry(name: name, species: species, roleTag: roleTag)
                        entry.name = name
                        entry.species = species
                        entry.roleTag = roleTag
                        entry.importance = importance
                        entry.currentMood = mood
                        entry.attitudeToParty = attitude
                        entry.ac = Int(ac)
                        entry.hpMax = Int(hpMax)
                        entry.hpCurrent = Int(hpCurrent)
                        entry.appearanceShort = appearanceShort
                        entry.notableFeatures = parseCommaList(notableFeatures)
                        entry.goalsImmediate = parseCommaList(goalsImmediate)
                        entry.quirks = parseCommaList(quirks)
                        entry.flaws = parseCommaList(flaws)
                        entry.updatedAt = Date()
                        onSave(entry)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let npc {
                    name = npc.name
                    species = npc.species
                    roleTag = npc.roleTag
                    importance = npc.importance
                    mood = npc.currentMood
                    attitude = npc.attitudeToParty
                    ac = npc.ac.map(String.init) ?? ""
                    hpMax = npc.hpMax.map(String.init) ?? ""
                    hpCurrent = npc.hpCurrent.map(String.init) ?? ""
                    notableFeatures = npc.notableFeatures.joined(separator: ", ")
                    goalsImmediate = npc.goalsImmediate.joined(separator: ", ")
                    quirks = npc.quirks.joined(separator: ", ")
                    flaws = npc.flaws.joined(separator: ", ")
                    appearanceShort = npc.appearanceShort
                }
            }
        }
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
