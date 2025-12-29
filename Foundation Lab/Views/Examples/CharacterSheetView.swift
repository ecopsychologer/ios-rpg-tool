import SwiftUI
import SwiftData
import Foundation
import WorldState
import RPGEngine

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
                                Text(RulesetCatalog.descriptor(for: character.rulesetId)?.displayName ?? character.rulesetId.uppercased())
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
    @Environment(\.modelContext) private var modelContext
    @Bindable var character: PlayerCharacter
    @State private var srdIndex: SrdContentIndex?

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
                            CharacterFieldRow(
                                field: field,
                                srdOptions: srdOptions(for: field),
                                onInventorySelection: field.key == "inventory" ? handleInventorySelection : nil
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.medium)
        .onAppear {
            ensureDefaultFields()
            loadSrdIndex()
        }
        .onChange(of: character.rulesetId) { loadSrdIndex() }
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

    private func loadSrdIndex() {
        srdIndex = RulesetCatalog.contentIndex(for: character.rulesetId)
    }

    private func srdOptions(for field: CharacterField) -> SrdFieldOptions? {
        guard let index = srdIndex else { return nil }
        switch field.key {
        case "species":
            return SrdFieldOptions(
                title: "Species",
                items: index.species,
                detailMap: [:],
                mode: .replace
            )
        case "class":
            return SrdFieldOptions(
                title: "Class",
                items: index.classes,
                detailMap: index.classDetails,
                mode: .replace
            )
        case "background":
            return SrdFieldOptions(
                title: "Background",
                items: index.backgrounds,
                detailMap: index.backgroundDetails,
                mode: .replace
            )
        case "subclass":
            let className = matchedClassName(from: fieldValue(key: "class"), in: index)
            let subclasses = className.flatMap { index.subclassesByClass[$0] } ?? index.subclasses
            guard !subclasses.isEmpty else { return nil }
            return SrdFieldOptions(
                title: "Subclass",
                items: subclasses,
                detailMap: index.subclassDetails,
                mode: .replace
            )
        case "skills":
            let names = index.skills.map { $0.name }
            let details = Dictionary(uniqueKeysWithValues: index.skills.map {
                ($0.name, ["Default ability: \($0.defaultAbility)"])
            })
            return SrdFieldOptions(
                title: "Skills",
                items: names,
                detailMap: details,
                mode: .append
            )
        case "saves":
            return SrdFieldOptions(
                title: "Saves",
                items: index.abilities,
                detailMap: [:],
                mode: .append
            )
        case "feats":
            return SrdFieldOptions(
                title: "Feats",
                items: index.feats,
                detailMap: index.featDetails,
                mode: .append
            )
        case "spells_known":
            let className = matchedClassName(from: fieldValue(key: "class"), in: index)
            let filteredSpells = className.flatMap { index.spellsByClass[$0] } ?? index.spells
            return SrdFieldOptions(
                title: "Spells",
                items: filteredSpells,
                detailMap: index.spellDetails,
                mode: .append
            )
        case "inventory":
            let combined: [String]
            let details: [String: [String]]
            if index.itemRecords.isEmpty {
                combined = Array(Set(index.equipment + index.magicItems)).sorted()
                var merged = index.equipmentDetails
                index.magicItemDetails.forEach { merged[$0.key] = $0.value }
                details = merged
            } else {
                combined = Array(Set(index.itemRecords.map { $0.name })).sorted()
                details = itemDetailMap(from: index)
            }
            return SrdFieldOptions(
                title: "Inventory",
                items: combined,
                detailMap: details,
                mode: .append
            )
        case "conditions":
            return SrdFieldOptions(
                title: "Conditions",
                items: index.conditions,
                detailMap: index.conditionDetails,
                mode: .append
            )
        default:
            return nil
        }
    }

    private func matchedClassName(from rawValue: String, in index: SrdContentIndex) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let exact = index.classes.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exact
        }
        return index.classes.first(where: { $0.lowercased().contains(trimmed.lowercased()) })
    }

    private func handleInventorySelection(_ selection: String) {
        guard let index = srdIndex else { return }
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let ownerId: UUID? = character.id
        let name = trimmed
        let predicate = #Predicate<ItemEntry> { entry in
            entry.ownerId == ownerId && entry.name == name
        }
        if let existing = try? modelContext.fetch(FetchDescriptor<ItemEntry>(predicate: predicate)),
           !existing.isEmpty {
            return
        }

        let record = index.itemRecords.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame })
        let entry = ItemEntry(
            name: trimmed,
            category: record?.category ?? "Item",
            subcategory: record?.subcategory,
            itemType: record?.itemType,
            rarity: record?.rarity,
            requiresAttunement: record?.requiresAttunement ?? false,
            attunementRequirement: record?.attunementRequirement,
            cost: record?.cost,
            weight: record?.weight,
            properties: record?.properties ?? [],
            detailLines: record?.description ?? [],
            source: record?.source ?? "srd",
            ownerId: character.id,
            ownerKind: "player"
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func itemDetailMap(from index: SrdContentIndex) -> [String: [String]] {
        var details: [String: [String]] = [:]
        for record in index.itemRecords {
            details[record.name] = itemDetailLines(for: record)
        }
        return details
    }

    private func itemDetailLines(for record: SrdItemRecord) -> [String] {
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
}

private struct CharacterFieldRow: View {
    @Bindable var field: CharacterField
    let srdOptions: SrdFieldOptions?
    let onInventorySelection: ((String) -> Void)?
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.label)
                .font(.caption)
                .foregroundColor(.secondary)
            fieldInput
            if srdOptions != nil {
                Button("Pick from SRD") {
                    showPicker = true
                }
                .buttonStyle(.bordered)
            }
            Picker("Status", selection: $field.status) {
                ForEach(SheetFieldStatus.allCases) { status in
                    Text(status.rawValue.capitalized).tag(status.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showPicker) {
            if let srdOptions {
                SrdPickerView(
                    title: srdOptions.title,
                    items: srdOptions.items,
                    detailMap: srdOptions.detailMap,
                    onSelect: { selection in
                        applySelection(selection, mode: srdOptions.mode)
                        showPicker = false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var fieldInput: some View {
        if let srdOptions, srdOptions.mode == .replace, field.valueType == "string" {
            let selectionBinding = Binding(
                get: { field.valueString ?? "" },
                set: { newValue in
                    field.valueString = newValue
                    field.updatedAt = Date()
                }
            )
            Picker("SRD \(srdOptions.title)", selection: selectionBinding) {
                Text("Custom").tag("")
                ForEach(srdOptions.items, id: \.self) { item in
                    Text(item).tag(item)
                }
            }
            .pickerStyle(.menu)
        }

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

    private func applySelection(_ selection: String, mode: SrdFieldMode) {
        switch field.valueType {
        case "list":
            var list = field.valueStringList ?? []
            if mode == .replace {
                list = [selection]
            } else if !list.contains(selection) {
                list.append(selection)
            }
            field.valueStringList = list
            if field.key == "inventory" {
                onInventorySelection?(selection)
            }
        default:
            field.valueString = selection
        }
        field.updatedAt = Date()
    }
}

private enum SrdFieldMode {
    case replace
    case append
}

private struct SrdFieldOptions {
    let title: String
    let items: [String]
    let detailMap: [String: [String]]
    let mode: SrdFieldMode
}

private struct SrdPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [String]
    let detailMap: [String: [String]]
    let onSelect: (String) -> Void

    @State private var filterText = ""
    @State private var detailSelection: SrdDetailSelection?

    var body: some View {
        NavigationStack {
            List(filteredItems, id: \.self) { item in
                HStack {
                    Button(item) {
                        onSelect(item)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    if let details = detailMap[item], !details.isEmpty {
                        Button {
                            detailSelection = SrdDetailSelection(title: item, lines: details)
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .searchable(text: $filterText, prompt: "Filter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $detailSelection) { selection in
                NavigationStack {
                    SrdDetailView(title: selection.title, subtitle: nil, lines: selection.lines)
                }
            }
        }
    }

    private var filteredItems: [String] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { $0.range(of: query, options: .caseInsensitive) != nil }
    }
}

private struct SrdDetailSelection: Identifiable {
    let id = UUID()
    let title: String
    let lines: [String]
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
        .navigationTitle(title)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") { dismiss() }
            }
        }
    }
}

private struct CharacterCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedRulesetId = RulesetCatalog.srd.id
    @State private var customRulesetId = ""

    let onCreate: (PlayerCharacter) -> Void
    private let rulesets = RulesetCatalog.descriptors
    private let customId = "__custom"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Display Name (optional)", text: $name)
                Picker("Ruleset", selection: $selectedRulesetId) {
                    ForEach(rulesets) { ruleset in
                        Text(ruleset.displayName).tag(ruleset.id)
                    }
                    Text("Custom").tag(customId)
                }
                if selectedRulesetId == customId {
                    TextField("Ruleset ID", text: $customRulesetId)
                }
            }
            .navigationTitle("Add Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let rulesetId: String
                        if selectedRulesetId == customId {
                            rulesetId = customRulesetId.trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            rulesetId = selectedRulesetId
                        }
                        let character = PlayerCharacter(displayName: name, rulesetId: rulesetId)
                        onCreate(character)
                        dismiss()
                    }
                }
            }
        }
    }
}
