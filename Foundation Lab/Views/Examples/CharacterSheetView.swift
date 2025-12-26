import SwiftUI
import SwiftData
import WorldState

struct CharacterSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @State private var campaign: Campaign?
    @State private var selectedCharacter: PlayerCharacter?
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    headerSection
                    characterListSection
                    if let character = selectedCharacter {
                        CharacterDetailView(character: character)
                    }
                }
                .padding(.vertical)
            }
            .textSelection(.enabled)
            .navigationTitle("Character Sheet")
            .onAppear { ensureCampaign() }
            .sheet(isPresented: $showAddSheet) {
                CharacterCreateSheet { character in
                    addCharacter(character)
                    selectedCharacter = character
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Build your character bottom-up. Unknown fields can be filled during play.")
                .font(.callout)
                .foregroundColor(.secondary)
                .textSelection(.enabled)

            Button("Add Character") {
                showAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, Spacing.medium)
    }

    private var characterListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let campaign = campaign, campaign.playerCharacters.isEmpty {
                Text("No characters yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            } else {
                ForEach(campaign?.playerCharacters ?? []) { character in
                    Button {
                        selectedCharacter = character
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(character.displayName.isEmpty ? "Unnamed Character" : character.displayName)
                                    .font(.headline)
                                Text(character.rulesetId.uppercased())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
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

    private func addCharacter(_ character: PlayerCharacter) {
        ensureCampaign()
        guard let campaign else { return }
        campaign.playerCharacters.append(character)
        try? modelContext.save()
    }

    private func ensureCampaign() {
        if let existing = campaigns.first(where: { $0.isActive }) ?? campaigns.first {
            campaign = existing
            if selectedCharacter == nil {
                selectedCharacter = existing.playerCharacters.first
            }
        } else {
            let newCampaign = Campaign()
            modelContext.insert(newCampaign)
            campaign = newCampaign
            try? modelContext.save()
        }
    }
}

private struct CharacterDetailView: View {
    @Bindable var character: PlayerCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            nowPanel
            TextField("Display Name", text: $character.displayName, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            ForEach(sectionNames, id: \.self) { section in
                let fields = character.fields.filter { $0.section == section }.sorted { $0.order < $1.order }
                if !fields.isEmpty {
                    DisclosureGroup(section) {
                        ForEach(fields) { field in
                            CharacterFieldRow(field: field)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .onAppear { ensureDefaultFields() }
    }

    private var sectionNames: [String] {
        let seen = Set(character.fields.map { $0.section })
        let ordered = CharacterSheetDefinitions.sectionOrder.filter { seen.contains($0) }
        let extras = seen.subtracting(ordered).sorted()
        return ordered + extras
    }

    private var nowPanel: some View {
        let hpCurrent = fieldValue(key: "hp_current")
        let hpMax = fieldValue(key: "hp_max")
        let ac = fieldValue(key: "ac")
        let conditions = listValue(key: "conditions")

        return VStack(alignment: .leading, spacing: 6) {
            Text("Now")
                .font(.headline)
            HStack(spacing: Spacing.medium) {
                Text("HP: \(hpCurrent.isEmpty ? "?" : hpCurrent)/\(hpMax.isEmpty ? "?" : hpMax)")
                Text("AC: \(ac.isEmpty ? "?" : ac)")
            }
            .font(.callout)
            if !conditions.isEmpty {
                Text("Conditions: \(conditions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }

    private func fieldValue(key: String) -> String {
        guard let field = character.fields.first(where: { $0.key == key }) else { return "" }
        if let valueString = field.valueString, !valueString.isEmpty {
            return valueString
        }
        if let valueInt = field.valueInt {
            return String(valueInt)
        }
        if let valueDouble = field.valueDouble {
            return String(valueDouble)
        }
        return ""
    }

    private func listValue(key: String) -> String {
        guard let list = character.fields.first(where: { $0.key == key })?.valueStringList else { return "" }
        return list.joined(separator: ", ")
    }

    private func ensureDefaultFields() {
        if character.fields.isEmpty {
            character.fields = CharacterSheetDefinitions.defaultFields()
        }
    }
}

private struct CharacterFieldRow: View {
    @Bindable var field: CharacterField

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.caption)
                .foregroundColor(.secondary)
            fieldInput
            Picker("Status", selection: $field.status) {
                ForEach(SheetFieldStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var fieldInput: some View {
        switch field.valueType {
        case "int":
            TextField(field.label, text: Binding(
                get: { field.valueInt.map(String.init) ?? "" },
                set: { newValue in
                    field.valueInt = Int(newValue)
                    field.valueString = newValue.isEmpty ? nil : newValue
                    field.updatedAt = Date()
                }
            ))
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
        case "list":
            TextField(field.label, text: Binding(
                get: { field.valueStringList?.joined(separator: ", ") ?? "" },
                set: { newValue in
                    field.valueStringList = parseCommaList(newValue)
                    field.updatedAt = Date()
                }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
        default:
            TextField(field.label, text: Binding(
                get: { field.valueString ?? "" },
                set: { newValue in
                    field.valueString = newValue
                    field.updatedAt = Date()
                }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
        }
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

private struct CharacterCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var rulesetId = "srd_5e"

    let onCreate: (PlayerCharacter) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Display Name (optional)", text: $name)
                TextField("Ruleset ID", text: $rulesetId)
            }
            .navigationTitle("Add Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let character = PlayerCharacter(displayName: name, rulesetId: rulesetId)
                        onCreate(character)
                        dismiss()
                    }
                }
            }
        }
    }
}
