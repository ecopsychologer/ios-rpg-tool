import Foundation

public struct UserTableImporter {
    public init() {}

    public func importTables(from data: Data, scope: String = "user") -> [TableDefinition] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tables = root["table"] as? [[String: Any]] else {
            return []
        }

        var definitions: [TableDefinition] = []
        var usedIds = Set<String>()

        for table in tables {
            guard let name = table["name"] as? String,
                  let rows = table["rows"] as? [Any] else { continue }

            let maxColumns = rows.map { ($0 as? [Any])?.count ?? 0 }.max() ?? 0
            let pairCount = maxColumns >= 4 && maxColumns % 2 == 0 ? (maxColumns / 2) : 1
            var entriesByPair = Array(repeating: [TableEntry](), count: pairCount)

            for rowValue in rows {
                guard let row = rowValue as? [Any] else { continue }
                for pairIndex in 0..<pairCount {
                    let rollIndex = pairIndex * 2
                    let resultIndex = rollIndex + 1
                    guard rollIndex < row.count, resultIndex < row.count else { continue }
                    let rollText = (row[rollIndex] as? String) ?? ""
                    let resultText = (row[resultIndex] as? String) ?? ""
                    guard let range = parseRange(rollText), !resultText.isEmpty else { continue }
                    let action = OutcomeAction(
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
                        message: resultText
                    )
                    entriesByPair[pairIndex].append(TableEntry(min: range.min, max: range.max, actions: [action]))
                }
            }

            for pairIndex in 0..<pairCount {
                let entries = entriesByPair[pairIndex]
                guard !entries.isEmpty else { continue }
                let dieMax = entries.map { $0.max }.max() ?? 0
                let diceSpec = dieMax > 0 ? "d\(dieMax)" : "d100"
                let nameSuffix = pairCount == 1 ? "" : " Part \(pairIndex + 1)"
                let tableName = "\(name)\(nameSuffix)"
                let idBase = slugify(tableName)
                let id = uniqueId(base: idBase, usedIds: &usedIds)
                definitions.append(
                    TableDefinition(
                        id: id,
                        name: tableName,
                        scope: scope,
                        diceSpec: diceSpec,
                        entries: entries
                    )
                )
            }
        }

        return definitions
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

    private func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        let allowed = lowered.map { char -> Character in
            if char.isLetter || char.isNumber { return char }
            return "-"
        }
        let collapsed = String(allowed).split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }

    private func uniqueId(base: String, usedIds: inout Set<String>) -> String {
        var candidate = base
        var counter = 2
        while usedIds.contains(candidate) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }
        usedIds.insert(candidate)
        return candidate
    }
}
