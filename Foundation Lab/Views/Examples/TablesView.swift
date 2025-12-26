import SwiftUI
import UniformTypeIdentifiers
import TableEngine

struct TablesView: View {
    @State private var rawJSON: String = ""
    @State private var pack: ContentPack?
    @State private var errorMessage: String?
    @State private var importMessage: String?
    @State private var markdownInput: String = ""
    @State private var isSaving = false
    @State private var fileURL: URL?
    @State private var showFileImporter = false

    private let store = ContentPackStore()
    private let importer = TableImporter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection
                fileSection
                importSection
                tableListSection
                editorSection
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.large)
        }
        .textSelection(.enabled)
        .navigationTitle("Tables")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .onAppear(perform: loadPack)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: markdownFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("TABLES")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Edit the table JSON stored on device. These tables drive location generation.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    private var fileSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("FILE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let fileURL {
                Text(fileURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("File path unavailable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: Spacing.small) {
                Button("Reload") {
                    loadPack()
                }
                .buttonStyle(.glassProminent)

                Button(isSaving ? "Saving..." : "Save") {
                    savePack()
                }
                .buttonStyle(.glassProminent)
                .disabled(isSaving || rawJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var importSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("MARKDOWN IMPORT")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Paste a markdown table to import. Imported tables use log-only actions by default.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $markdownInput)
                .font(.system(.footnote, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(Spacing.medium)
                .frame(minHeight: 160)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

            HStack(spacing: Spacing.small) {
                Button("Import Markdown") {
                    importMarkdownTables()
                }
                .buttonStyle(.glassProminent)

                Button("Import Markdown File") {
                    showFileImporter = true
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    markdownInput = ""
                }
                .buttonStyle(.bordered)
            }

            if let importMessage {
                Text(importMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var tableListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("TABLE LIST")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let pack, !pack.tables.isEmpty {
                ForEach(pack.tables, id: \.id) { table in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(table.name) (\(table.id))")
                            .font(.callout)
                        Text("Scope: \(table.scope) · Dice: \(table.diceSpec)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(Spacing.small)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
            } else {
                Text("No tables loaded.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("TABLE JSON")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextEditor(text: $rawJSON)
                .font(.system(.footnote, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(Spacing.medium)
                .frame(minHeight: 240)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private func loadPack() {
        do {
            let url = try store.ensureDefaultPackExists()
            fileURL = url
            let data = try Data(contentsOf: url)
            rawJSON = String(decoding: data, as: UTF8.self)
            pack = try JSONDecoder().decode(ContentPack.self, from: data)
            errorMessage = nil
            importMessage = nil
        } catch {
            errorMessage = "Failed to load tables: \(error.localizedDescription)"
        }
    }

    private func savePack() {
        guard let fileURL else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let data = Data(rawJSON.utf8)
            _ = try JSONDecoder().decode(ContentPack.self, from: data)
            try data.write(to: fileURL, options: [.atomic])
            pack = try JSONDecoder().decode(ContentPack.self, from: data)
            errorMessage = nil
            importMessage = "Saved tables."
        } catch {
            errorMessage = "Failed to save tables: \(error.localizedDescription)"
        }
    }

    private func importMarkdownTables() {
        let trimmed = markdownInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importMessage = "Paste markdown table text first."
            return
        }
        importMarkdownTables(from: trimmed)
    }

    private func importMarkdownTables(from text: String) {
        let imported = importer.importMarkdown(text, defaultName: "Imported Table")
        guard !imported.isEmpty else {
            importMessage = "No tables detected."
            return
        }

        var updatedPack = pack ?? ContentPack(id: "solo_imported", version: "0.1", tables: [])
        var usedIds = Set(updatedPack.tables.map { $0.id })
        var newTables: [TableDefinition] = []

        for table in imported {
            let tableId = uniqueTableId(from: table.name, usedIds: &usedIds)
            let diceSpec = table.dieMax > 0 ? "d\(table.dieMax)" : "d100"
            let entries = table.entries.map { entry in
                TableEntry(min: entry.min, max: entry.max, actions: [
                    OutcomeAction(
                        type: "log",
                        nodeType: nil,
                        edgeType: nil,
                        summary: nil,
                        tags: nil,
                        category: nil,
                        trigger: nil,
                        detectionSkill: nil,
                        detectionDC: nil,
                        disarmSkill: nil,
                        disarmDC: nil,
                        saveSkill: nil,
                        saveDC: nil,
                        effect: nil,
                        tableId: nil,
                        diceSpec: nil,
                        threshold: nil,
                        modifier: nil,
                        thenActions: nil,
                        elseActions: nil,
                        message: entry.result
                    )
                ])
            }
            let definition = TableDefinition(id: tableId, name: table.name, scope: "imported", diceSpec: diceSpec, entries: entries)
            newTables.append(definition)
        }

        updatedPack = ContentPack(id: updatedPack.id, version: updatedPack.version, tables: updatedPack.tables + newTables)
        pack = updatedPack
        rawJSON = encodePack(updatedPack)
        importMessage = "Imported \(newTables.count) table(s). Save to persist."
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importMessage = "No file selected."
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    importMessage = "Unable to read file as UTF-8 text."
                    return
                }
                markdownInput = text
                importMarkdownTables(from: text)
            } catch {
                importMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func uniqueTableId(from name: String, usedIds: inout Set<String>) -> String {
        let base = slugify(name)
        var candidate = base.isEmpty ? "table" : base
        var index = 1
        while usedIds.contains(candidate) {
            index += 1
            candidate = "\(base)_\(index)"
        }
        usedIds.insert(candidate)
        return candidate
    }

    private func slugify(_ text: String) -> String {
        let lower = text.lowercased()
        let allowed = lower.map { char -> String in
            if char.isLetter || char.isNumber {
                return String(char)
            }
            if char == " " || char == "-" || char == "_" {
                return "_"
            }
            return ""
        }
        let joined = allowed.joined()
        let collapsed = joined.replacingOccurrences(of: "__", with: "_")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func encodePack(_ pack: ContentPack) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(pack) {
            return String(decoding: data, as: UTF8.self)
        }
        return rawJSON
    }

    private var markdownFileTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let markdown = UTType(filenameExtension: "md") {
            types.append(markdown)
        }
        return types
    }
}

#Preview {
    NavigationStack {
        TablesView()
    }
}
