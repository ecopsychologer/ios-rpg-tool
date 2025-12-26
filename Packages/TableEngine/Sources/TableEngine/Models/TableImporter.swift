import Foundation

public struct ImportedTable: Identifiable {
    public let id: UUID
    public let name: String
    public let dieMax: Int
    public let entries: [ImportedTableEntry]
    public let tags: [String]

    public init(name: String, dieMax: Int, entries: [ImportedTableEntry], tags: [String] = []) {
        self.id = UUID()
        self.name = name
        self.dieMax = dieMax
        self.entries = entries
        self.tags = tags
    }
}

public struct ImportedTableEntry: Identifiable {
    public let id: UUID
    public let min: Int
    public let max: Int
    public let result: String

    public init(min: Int, max: Int, result: String) {
        self.id = UUID()
        self.min = min
        self.max = max
        self.result = result
    }
}

public struct TableImporter {
    public func importMarkdown(_ text: String, defaultName: String = "Imported Table") -> [ImportedTable] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var tables: [ImportedTable] = []
        var currentHeading = defaultName
        var index = 0

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if let heading = parseHeading(line) {
                currentHeading = heading
                i += 1
                continue
            }

            if isTableHeader(line), i + 1 < lines.count, isSeparatorLine(lines[i + 1]) {
                let (rows, nextIndex) = collectTableRows(from: lines, startIndex: i)
                let parsedTables = parseTableRows(rows, baseName: currentHeading, indexOffset: index)
                tables.append(contentsOf: parsedTables)
                index += parsedTables.count
                i = nextIndex
                continue
            }
            i += 1
        }
        return tables
    }

    private func parseHeading(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = trimmed.drop { $0 == "#" }.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func isTableHeader(_ line: String) -> Bool {
        line.contains("|")
    }

    private func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.replacingOccurrences(of: "|", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }

    private func collectTableRows(from lines: [String], startIndex: Int) -> ([String], Int) {
        var rows: [String] = []
        var index = startIndex + 2
        while index < lines.count {
            let line = lines[index]
            if !line.contains("|") { break }
            rows.append(line)
            index += 1
        }
        return (rows, index)
    }

    private func parseTableRows(_ rows: [String], baseName: String, indexOffset: Int) -> [ImportedTable] {
        let parsedRows = rows.map(parseRow)
        guard let maxColumns = parsedRows.map({ $0.count }).max(), maxColumns >= 2 else { return [] }

        let columnPairs = maxColumns >= 4 && maxColumns % 2 == 0 ? (maxColumns / 2) : 1
        var tables: [ImportedTable] = []

        for pairIndex in 0..<columnPairs {
            var entries: [ImportedTableEntry] = []
            let rollIndex = pairIndex * 2
            let resultIndex = rollIndex + 1

            for row in parsedRows {
                guard rollIndex < row.count, resultIndex < row.count else { continue }
                let rollText = row[rollIndex]
                let resultText = row[resultIndex]
                guard let range = parseRange(rollText), !resultText.isEmpty else { continue }
                entries.append(ImportedTableEntry(min: range.min, max: range.max, result: resultText))
            }

            guard !entries.isEmpty else { continue }
            let dieMax = entries.map { $0.max }.max() ?? 0
            let name = columnPairs == 1 ? baseName : "\(baseName) \(pairIndex + 1 + indexOffset)"
            tables.append(ImportedTable(name: name, dieMax: dieMax, entries: entries))
        }

        return tables
    }

    private func parseRow(_ line: String) -> [String] {
        var parts = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let first = parts.first, first.isEmpty { parts.removeFirst() }
        if let last = parts.last, last.isEmpty { parts.removeLast() }
        return parts
    }

    private func parseRange(_ text: String) -> (min: Int, max: Int)? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if cleaned.contains("-") {
            let parts = cleaned.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2,
                  let min = parseNumber(parts[0]),
                  let max = parseNumber(parts[1]) else { return nil }
            return (min: min, max: max)
        }

        if cleaned.hasSuffix("+") {
            let numberText = cleaned.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            guard let min = parseNumber(String(numberText)) else { return nil }
            return (min: min, max: min)
        }

        if let value = parseNumber(cleaned) {
            return (min: value, max: value)
        }
        return nil
    }

    private func parseNumber(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "00" { return 100 }
        return Int(trimmed)
    }
}
