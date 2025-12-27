//
//  SettingsView.swift
//  FoundationLab
//
//  Created by Rudrank Riyam on 6/15/25.
//

import SwiftUI
import SwiftData
import LiquidGlasKit
import WorldState
import RPGEngine

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @AppStorage("exaAPIKey") private var exaAPIKey: String = ""
    @AppStorage("soloShowLocationDebug") private var showLocationDebug = false
    @AppStorage("soloAutoRollEnabled") private var autoRollEnabled = false
    @AppStorage("soloGMRunsCompanions") private var gmRunsCompanionsEnabled = false
    @State private var tempAPIKey: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @FocusState private var isAPIFieldFocused: Bool
    @State private var showCampaignSheet = false
    @State private var showClearAllAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Exa Web Search")
                    .font(.headline)

                Text("Configure your Exa API key to enable web search functionality.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("API Key")
                    .font(.subheadline)
                    .fontWeight(.medium)

                SecureField("Enter your Exa API key", text: $tempAPIKey)
                    .textFieldStyle(.roundedBorder)
                    .focused($isAPIFieldFocused)
                    .onAppear {
                        tempAPIKey = exaAPIKey
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        saveAPIKey()
                    }

                Text("Get your free Exa API key:")
                Link("https://exa.ai/api", destination: URL(string: "https://exa.ai/api")!)
                    .font(.caption)

                Text("The API key is stored on the device and only used for web search requests.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassCard()
            .padding([.horizontal, .top])

            HStack {
                Button("Save") {
                    saveAPIKey()
                }
                .controlSize(.large)
                .buttonStyle(.glassProminent)
                .disabled(tempAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !exaAPIKey.isEmpty {
                    Button("Clear") {
                        clearAPIKey()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.secondary)
                    .foregroundColor(.red)
                }
            }

            if !exaAPIKey.isEmpty {
                Text("API key configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Campaign Data")
                    .font(.headline)

                Text("Manage multiple campaigns and switch which one is active.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if campaigns.isEmpty {
                    Text("No campaigns yet.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(campaigns) { campaign in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(campaign.title)
                                        .font(.subheadline)
                                    Text(campaign.rulesetName ?? "ruleset: default")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if campaign.isActive {
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Button("Set Active") {
                                        setActiveCampaign(campaign)
                                    }
                                    .buttonStyle(.bordered)
                                }
                                Button(role: .destructive) {
                                    deleteCampaign(campaign)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                            }
                            .padding(Spacing.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(10)
                        }
                    }
                }

                HStack(spacing: Spacing.medium) {
                    Button("New Campaign") {
                        showCampaignSheet = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Clear All Campaign Data") {
                        showClearAllAlert = true
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .glassCard()
            .padding([.horizontal, .top])

            VStack(alignment: .leading, spacing: 8) {
                Text("Solo RPG Tools")
                    .font(.headline)

                Toggle("Auto-roll checks", isOn: $autoRollEnabled)
                    .font(.callout)

                Text("When enabled, you can say “auto” to let the GM roll for you.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("GM runs companions", isOn: $gmRunsCompanionsEnabled)
                    .font(.callout)

                Text("When enabled, the GM may narrate companion actions without prompting.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Show generated location details", isOn: $showLocationDebug)
                    .font(.callout)

                Text("Expose behind-the-scenes location data for debugging and editing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassCard()
            .padding([.horizontal, .top])

            VStack(alignment: .leading, spacing: 16) {
                Link(destination: URL(string: "https://github.com/rudrankriyam/Foundation-Models-Framework-Example/issues")!) {
                    HStack {
                        Text("Bug/Feature Request")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)

                Link(destination: URL(string: "https://x.com/rudrankriyam")!) {
                    HStack {
                        Text("Made by Rudrank Riyam")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                .foregroundColor(.primary)

                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .foregroundColor(.secondary)
                }
                Text("Explore on-device AI with Apple's Foundation Models framework.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .glassCard()
            .padding([.horizontal, .top])
        }
#if os(macOS)
        .padding()
#endif
        .navigationTitle("Settings")
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Clear Campaign Data", isPresented: $showClearAllAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                clearAllCampaignData()
            }
        } message: {
            Text("This will permanently remove all campaign data from this device.")
        }
        .sheet(isPresented: $showCampaignSheet) {
            CampaignCreateSheet { title, ruleset in
                createCampaign(title: title, ruleset: ruleset)
                showCampaignSheet = false
            }
        }
    }

    private func saveAPIKey() {
        let trimmedKey = tempAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            alertMessage = "Please enter a valid API key"
            showingAlert = true
            return
        }

        dismissKeyboard()
        exaAPIKey = trimmedKey
        alertMessage = "API key saved successfully!"
        showingAlert = true
    }

    private func clearAPIKey() {
        dismissKeyboard()
        exaAPIKey = ""
        tempAPIKey = ""
        alertMessage = "API key cleared"
        showingAlert = true
    }

    private func dismissKeyboard() {
        isAPIFieldFocused = false
    }

    private func createCampaign(title: String, ruleset: String) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let campaign = Campaign(title: name.isEmpty ? "Solo Campaign" : name)
        let trimmedRuleset = ruleset.trimmingCharacters(in: .whitespacesAndNewlines)
        campaign.rulesetName = trimmedRuleset.isEmpty ? nil : trimmedRuleset
        campaign.isActive = true
        campaigns.forEach { $0.isActive = false }
        modelContext.insert(campaign)
        try? modelContext.save()
    }

    private func setActiveCampaign(_ campaign: Campaign) {
        campaigns.forEach { $0.isActive = false }
        campaign.isActive = true
        try? modelContext.save()
    }

    private func deleteCampaign(_ campaign: Campaign) {
        modelContext.delete(campaign)
        try? modelContext.save()
    }

    private func clearAllCampaignData() {
        deleteAll(Campaign.self)
        deleteAll(SceneEntry.self)
        deleteAll(CharacterEntry.self)
        deleteAll(ThreadEntry.self)
        deleteAll(NPCEntry.self)
        deleteAll(WorldLoreEntry.self)
        deleteAll(PlayerCharacter.self)
        deleteAll(CharacterField.self)
        deleteAll(CharacterFact.self)
        deleteAll(CharacterChange.self)
        deleteAll(LocationEntity.self)
        deleteAll(LocationNode.self)
        deleteAll(LocationEdge.self)
        deleteAll(TrapEntity.self)
        deleteAll(LocationFeature.self)
        deleteAll(EventLogEntry.self)
        deleteAll(TableRollRecord.self)
        deleteAll(SkillCheckRecord.self)
        deleteAll(FateQuestionRecord.self)
        deleteAll(SceneInteraction.self)
        deleteAll(CanonizationRecord.self)
        deleteAll(Party.self)
        deleteAll(PartyMember.self)
        try? modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                modelContext.delete(item)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

private struct CampaignCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedRulesetId = RulesetCatalog.srd.id
    @State private var customRulesetName = ""

    let onCreate: (String, String) -> Void
    private let rulesets = RulesetCatalog.descriptors
    private let customId = "__custom"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Campaign name", text: $title)
                Picker("Ruleset", selection: $selectedRulesetId) {
                    ForEach(rulesets) { ruleset in
                        Text(ruleset.displayName).tag(ruleset.id)
                    }
                    Text("Custom").tag(customId)
                }
                if selectedRulesetId == customId {
                    TextField("Ruleset (optional)", text: $customRulesetName)
                }
            }
            .navigationTitle("New Campaign")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let rulesetName: String
                        if selectedRulesetId == customId {
                            rulesetName = customRulesetName
                        } else {
                            rulesetName = rulesets.first(where: { $0.id == selectedRulesetId })?.displayName ?? selectedRulesetId
                        }
                        onCreate(title, rulesetName)
                        dismiss()
                    }
                }
            }
        }
    }
}
