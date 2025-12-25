import SwiftUI
import Foundation

struct SrdImportView: View {
    @State private var urlString = ""
    @State private var statusMessage = ""
    @State private var isDownloading = false
    @State private var savedPath: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text("Import SRD Reference Data")
                    .font(.title2)
                Text("Provide a URL to a publicly available SRD JSON or Markdown file. The download is stored locally for offline use.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)

                TextField("SRD file URL", text: $urlString, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button(isDownloading ? "Downloading..." : "Download SRD") {
                    download()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDownloading || urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let savedPath {
                    Text("Saved to: \(savedPath)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical)
            .padding(.horizontal, Spacing.medium)
        }
        .textSelection(.enabled)
        .navigationTitle("SRD Import")
    }

    private func download() {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            statusMessage = "Invalid URL."
            return
        }
        statusMessage = ""
        isDownloading = true
        savedPath = nil

        Task {
            defer { isDownloading = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let fileManager = FileManager.default
                let directory = try fileManager.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let fileURL = directory.appendingPathComponent("srd_import")
                try data.write(to: fileURL, options: [.atomic])
                savedPath = fileURL.path
            } catch {
                statusMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }
}
