import SwiftUI
import SwiftData
import FoundationModels
import WorldState

struct WorldLoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @State private var campaign: Campaign?
    @State private var showAddSheet = false
    @State private var editingEntry: WorldLoreEntry?
    @State private var draftPrompt = ""
    @State private var isDrafting = false
    @State private var draftError: String?
    @State private var setupSummary = ""
    @State private var isSummarizingSetup = false
    @State private var setupError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection
                campaignSetupSection
                draftSection
                loreListSection
            }
            .padding(.vertical)
        }
        .textSelection(.enabled)
        .navigationTitle("World Lore")
        .onAppear { ensureCampaign() }
        .sheet(isPresented: $showAddSheet) {
            WorldLoreEditSheet(
                title: "Add Lore",
                entry: nil,
                onSave: saveEntry
            )
        }
        .sheet(item: $editingEntry) { entry in
            WorldLoreEditSheet(
                title: "Edit Lore",
                entry: entry,
                onSave: { _ in
                    entry.updatedAt = Date()
                    try? modelContext.save()
                }
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Capture setting lore and persistent world facts outside of scene play.")
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            Button("Add Lore Entry") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private var campaignSetupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("CAMPAIGN SETUP")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let campaign {
                TextField("World vibe or tone", text: Binding(
                    get: { campaign.worldVibe },
                    set: { newValue in
                        campaign.worldVibe = newValue
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)

                if campaign.party == nil {
                    Button("Create Party") {
                        campaign.party = Party()
                        try? modelContext.save()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    partyEditorSection
                }

                if !setupSummary.isEmpty {
                    Text(setupSummary)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                if let setupError {
                    Text(setupError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }

                Button(isSummarizingSetup ? "Summarizing..." : "Summarize Setup") {
                    summarizeSetup()
                }
                .buttonStyle(.bordered)
                .disabled(isSummarizingSetup)
            } else {
                Text("Create a campaign to configure setup.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    private var partyEditorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let party = campaign?.party {
                Stepper("Party Size: \(party.members?.count ?? 0)", value: Binding(
                    get: { party.members?.count ?? 0 },
                    set: { newValue in
                        updatePartySize(newValue)
                    }
                ), in: 0...8)

                ForEach(party.members ?? []) { member in
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: Binding(
                            get: { member.name },
                            set: { member.name = $0; try? modelContext.save() }
                        ))
                        TextField("Role/Notes", text: Binding(
                            get: { member.role },
                            set: { member.role = $0; try? modelContext.save() }
                        ))
                        Toggle("NPC Sidekick", isOn: Binding(
                            get: { member.isNpc },
                            set: { member.isNpc = $0; try? modelContext.save() }
                        ))
                    }
                    .padding(Spacing.small)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var draftSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Lore Builder")
                .font(.headline)
            TextField("Describe the lore you want to establish", text: $draftPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            if let draftError {
                Text(draftError)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Button(isDrafting ? "Drafting..." : "Draft Entry with AI") {
                draftLore()
            }
            .buttonStyle(.bordered)
            .disabled(isDrafting || draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private var loreListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if let campaign = campaign, campaign.worldLore.isEmpty {
                Text("No lore entries yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            } else {
                ForEach(campaign?.worldLore ?? []) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(entry.summary)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            if !entry.tags.isEmpty {
                                Text("Tags: \(entry.tags.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(Spacing.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
    }

    private func saveEntry(_ entry: WorldLoreEntry) {
        ensureCampaign()
        guard let campaign else { return }
        if !campaign.worldLore.contains(where: { $0.id == entry.id }) {
            campaign.worldLore.append(entry)
        }
        try? modelContext.save()
    }

    private func ensureCampaign() {
        if let existing = campaigns.first(where: { $0.isActive }) ?? campaigns.first {
            campaign = existing
        } else {
            let newCampaign = Campaign()
            modelContext.insert(newCampaign)
            campaign = newCampaign
            try? modelContext.save()
        }
    }

    private func draftLore() {
        if campaign == nil {
            ensureCampaign()
        }
        guard campaign != nil else { return }
        let promptText = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else { return }
        draftError = nil
        isDrafting = true

        Task {
            defer { isDrafting = false }
            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)
                let prompt = """
                Draft a concise lore entry for a solo RPG setting.
                Keep it grounded, 1-3 sentences, and avoid contradictions.
                Include short tags for filtering.
                Do not ask questions or request confirmation.

                Prompt: \(promptText)
                """
                let draft = try await session.respond(to: Prompt(prompt), generating: WorldLoreDraft.self)
                let entry = WorldLoreEntry(
                    title: draft.content.title,
                    summary: draft.content.summary,
                    tags: draft.content.tags,
                    origin: "ai"
                )
                saveEntry(entry)
                draftPrompt = ""
            } catch {
                draftError = error.localizedDescription
            }
        }
    }

    private func updatePartySize(_ newSize: Int) {
        guard let campaign, let party = campaign.party else { return }
        var members = party.members ?? []
        if newSize > members.count {
            let start = members.count + 1
            for index in start...newSize {
                members.append(PartyMember(name: "PC \(index)"))
            }
        } else if newSize < members.count {
            members = Array(members.prefix(newSize))
        }
        party.members = members
        try? modelContext.save()
    }

    private func summarizeSetup() {
        guard let campaign else { return }
        setupError = nil
        isSummarizingSetup = true

        Task {
            defer { isSummarizingSetup = false }
            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)
                let partyNames = campaign.party?.members?.map { $0.name }.joined(separator: ", ") ?? "None"
                let prompt = """
                Summarize the campaign setup in 2-3 sentences for a static summary field.
                Do not ask questions or request confirmation.
                World vibe: \(campaign.worldVibe)
                Party members: \(partyNames)
                """
                let response = try await session.respond(to: Prompt(prompt))
                setupSummary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                setupError = error.localizedDescription
            }
        }
    }
}

private struct WorldLoreEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let entry: WorldLoreEntry?
    let onSave: (WorldLoreEntry) -> Void

    @State private var loreTitle: String = ""
    @State private var summary: String = ""
    @State private var tags: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $loreTitle)
                TextField("Summary", text: $summary, axis: .vertical)
                TextField("Tags (comma-separated)", text: $tags, axis: .vertical)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let item = entry ?? WorldLoreEntry(title: loreTitle, summary: summary, tags: parseCommaList(tags))
                        item.title = loreTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.tags = parseCommaList(tags)
                        item.updatedAt = Date()
                        onSave(item)
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let entry {
                    loreTitle = entry.title
                    summary = entry.summary
                    tags = entry.tags.joined(separator: ", ")
                }
            }
        }
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
