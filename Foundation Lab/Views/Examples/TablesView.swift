import SwiftUI

struct TablesView: View {
    @State private var rawJSON: String = ""
    @State private var pack: ContentPack?
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var fileURL: URL?

    private let store = ContentPackStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection
                fileSection
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
        } catch {
            errorMessage = "Failed to save tables: \(error.localizedDescription)"
        }
    }
}

#Preview {
    NavigationStack {
        TablesView()
    }
}
