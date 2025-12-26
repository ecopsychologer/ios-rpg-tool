import Foundation

public struct WeightedList: Sendable {
    struct Entry: Identifiable, Sendable, Equatable {
        let id = UUID()
        let name: String
        let weight: Int
    }

    private struct StoredEntry: Sendable {
        var name: String
        var weight: Int
        let key: String
    }

    private var entries: [StoredEntry] = []
    private var indexByKey: [String: Int] = [:]

    public var allEntries: [Entry] {
        entries.map { Entry(name: $0.name, weight: $0.weight) }
    }

    public var isEmpty: Bool {
        entries.isEmpty
    }

    public mutating func addNew(_ names: [String]) {
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard indexByKey[key] == nil else { continue }
            let entry = StoredEntry(name: trimmed, weight: 1, key: key)
            indexByKey[key] = entries.count
            entries.append(entry)
        }
    }

    public mutating func featureExisting(_ names: [String]) {
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard let index = indexByKey[key] else { continue }
            entries[index].weight = min(3, entries[index].weight + 1)
        }
    }

    public mutating func remove(_ names: [String]) {
        var keysToRemove: Set<String> = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            keysToRemove.insert(trimmed.lowercased())
        }
        guard !keysToRemove.isEmpty else { return }
        entries.removeAll { keysToRemove.contains($0.key) }
        rebuildIndex()
    }

    private mutating func rebuildIndex() {
        indexByKey = [:]
        for (index, entry) in entries.enumerated() {
            indexByKey[entry.key] = index
        }
    }
}
