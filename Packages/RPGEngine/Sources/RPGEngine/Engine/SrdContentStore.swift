import Foundation

public struct SrdContentIndex: Sendable {
    public let abilities: [String]
    public let skills: [SkillDefinition]
    public let species: [String]
    public let classes: [String]
    public let backgrounds: [String]
    public let subclasses: [String]
    public let feats: [String]
    public let equipment: [String]
    public let spells: [String]
    public let magicItems: [String]
    public let creatures: [String]
    public let classDetails: [String: [String]]
    public let backgroundDetails: [String: [String]]
    public let subclassDetails: [String: [String]]
    public let subclassesByClass: [String: [String]]
    public let featDetails: [String: [String]]
    public let spellDetails: [String: [String]]
    public let magicItemDetails: [String: [String]]
    public let equipmentDetails: [String: [String]]
    public let creatureDetails: [String: [String]]
    public let spellsByClass: [String: [String]]
    public let magicItemRarities: [String: String]
    public let sections: [String]
    public let sectionDetails: [String: [String]]
    public let source: String

    public init(
        abilities: [String],
        skills: [SkillDefinition],
        species: [String],
        classes: [String],
        backgrounds: [String],
        subclasses: [String],
        feats: [String],
        equipment: [String],
        spells: [String],
        magicItems: [String],
        creatures: [String],
        classDetails: [String: [String]],
        backgroundDetails: [String: [String]],
        subclassDetails: [String: [String]],
        subclassesByClass: [String: [String]],
        featDetails: [String: [String]],
        spellDetails: [String: [String]],
        magicItemDetails: [String: [String]],
        equipmentDetails: [String: [String]],
        creatureDetails: [String: [String]],
        spellsByClass: [String: [String]],
        magicItemRarities: [String: String],
        sections: [String],
        sectionDetails: [String: [String]],
        source: String
    ) {
        self.abilities = abilities
        self.skills = skills
        self.species = species
        self.classes = classes
        self.backgrounds = backgrounds
        self.subclasses = subclasses
        self.feats = feats
        self.equipment = equipment
        self.spells = spells
        self.magicItems = magicItems
        self.creatures = creatures
        self.classDetails = classDetails
        self.backgroundDetails = backgroundDetails
        self.subclassDetails = subclassDetails
        self.subclassesByClass = subclassesByClass
        self.featDetails = featDetails
        self.spellDetails = spellDetails
        self.magicItemDetails = magicItemDetails
        self.equipmentDetails = equipmentDetails
        self.creatureDetails = creatureDetails
        self.spellsByClass = spellsByClass
        self.magicItemRarities = magicItemRarities
        self.sections = sections
        self.sectionDetails = sectionDetails
        self.source = source
    }
}

public struct SrdContentStore {
    public init() {}

    public func loadIndex() -> SrdContentIndex? {
        guard let (data, source) = loadDataAndSource() else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return buildIndex(from: json, source: source)
        }
        if source == "imported",
           let bundledData = loadBundledData(),
           let json = try? JSONSerialization.jsonObject(with: bundledData) as? [String: Any] {
            return buildIndex(from: json, source: "bundled")
        }
        return nil
    }

    private func buildIndex(from json: [String: Any], source: String) -> SrdContentIndex {
        let abilities = parseAbilities(from: json)
        let skills = parseSkills(from: json, abilities: abilities)
        let species = parseSpecies(from: json)
        let classDetails = parseClassDetails(from: json)
        let classes = classDetails.keys.sorted()
        let (backgrounds, backgroundDetails) = parseBackgrounds(from: json)
        let (subclasses, subclassDetails, subclassesByClass) = parseSubclasses(from: json, classNames: classes)
        let (feats, featDetails) = parseFeats(from: json)
        let (spells, spellDetails, spellsByClass) = parseSpells(from: json)
        let (equipment, equipmentDetails) = parseEquipment(from: json)
        let (magicItems, magicItemDetails, magicItemRarities) = parseMagicItems(from: json)
        let (creatures, creatureDetails) = parseCreatures()
        let sections = json.keys.sorted()
        let sectionDetails = parseSectionDetails(from: json)

        return SrdContentIndex(
            abilities: abilities,
            skills: skills,
            species: species,
            classes: classes,
            backgrounds: backgrounds,
            subclasses: subclasses,
            feats: feats,
            equipment: equipment,
            spells: spells,
            magicItems: magicItems,
            creatures: creatures,
            classDetails: classDetails,
            backgroundDetails: backgroundDetails,
            subclassDetails: subclassDetails,
            subclassesByClass: subclassesByClass,
            featDetails: featDetails,
            spellDetails: spellDetails,
            magicItemDetails: magicItemDetails,
            equipmentDetails: equipmentDetails,
            creatureDetails: creatureDetails,
            spellsByClass: spellsByClass,
            magicItemRarities: magicItemRarities,
            sections: sections,
            sectionDetails: sectionDetails,
            source: source
        )
    }

    public func importBundledSRD() throws -> URL? {
        guard let bundleURL = bundledSrdURL() else { return nil }
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destination = directory.appendingPathComponent("srd_import")
        if fileManager.fileExists(atPath: destination.path) { return destination }
        let data = try Data(contentsOf: bundleURL)
        try data.write(to: destination, options: [.atomic])
        return destination
    }

    public func bundledSrdURL() -> URL? {
        if let url = Bundle.module.url(forResource: "5esrd", withExtension: "json", subdirectory: "SRD") {
            return url
        }
        if let url = Bundle.module.url(forResource: "5esrd", withExtension: "json") {
            return url
        }
        if let url = Bundle.main.url(forResource: "5esrd", withExtension: "json", subdirectory: "SRD") {
            return url
        }
        if let url = Bundle.main.url(forResource: "5esrd", withExtension: "json") {
            return url
        }
        return nil
    }

    public func bundledSupplementalURL(named name: String) -> URL? {
        if let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "SRD") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "SRD") {
            return url
        }
        return nil
    }

    public func appSupportURL() -> URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        let url = directory.appendingPathComponent("srd_import")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func loadDataAndSource() -> (Data, String)? {
        if let url = appSupportURL(), let data = try? Data(contentsOf: url) {
            return (data, "imported")
        }
        if let data = loadBundledData() {
            return (data, "bundled")
        }
        return nil
    }

    private func loadBundledData() -> Data? {
        guard let url = bundledSrdURL() else { return nil }
        return try? Data(contentsOf: url)
    }

    private func parseAbilities(from root: [String: Any]) -> [String] {
        guard let using = root["Using Ability Scores"] as? [String: Any],
              let each = using["Using Each Ability"] as? [String: Any] else {
            return []
        }
        let abilities = each.keys.filter { $0.lowercased() != "content" }
        return abilities.sorted()
    }

    private func parseSkills(from root: [String: Any], abilities: [String]) -> [SkillDefinition] {
        guard let using = root["Using Ability Scores"] as? [String: Any],
              let checks = using["Ability Checks"] as? [String: Any],
              let skills = checks["Skills"] as? [String: Any] else {
            return []
        }

        var definitions: [SkillDefinition] = []
        let abilitySet = Set(abilities.map { $0.lowercased() })

        for (ability, value) in skills {
            guard abilitySet.contains(ability.lowercased()) else { continue }
            let entries = extractStringList(from: value)
            for skill in entries {
                definitions.append(SkillDefinition(name: skill, defaultAbility: ability))
            }
        }

        let unique = Dictionary(grouping: definitions, by: { $0.name.lowercased() })
            .compactMap { $0.value.first }
        return unique.sorted { $0.name < $1.name }
    }

    private func parseSpecies(from root: [String: Any]) -> [String] {
        guard let races = root["Races"] as? [String: Any] else { return [] }
        let names = races.keys.filter { $0.lowercased() != "racial traits" }
        return names.sorted()
    }

    private func parseClassDetails(from root: [String: Any]) -> [String: [String]] {
        var details: [String: [String]] = [:]
        for (key, value) in root {
            guard let dict = value as? [String: Any],
                  dict["Class Features"] != nil else { continue }
            let lines = extractTextLines(from: dict, includeKeys: true)
            details[key] = sanitize(lines)
        }
        return details
    }

    private func parseBackgrounds(from root: [String: Any]) -> ([String], [String: [String]]) {
        guard let backgrounds = root["Backgrounds"] as? [String: Any] else { return ([], [:]) }
        let exclusions: Set<String> = [
            "content",
            "proficiencies",
            "languages",
            "equipment",
            "suggested characteristics",
            "customizing a background"
        ]
        var names: [String] = []
        var details: [String: [String]] = [:]

        for (key, value) in backgrounds {
            let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !exclusions.contains(normalized) else { continue }
            let lines = extractTextLines(from: value, includeKeys: true)
            let sanitized = sanitize(lines)
            guard !sanitized.isEmpty else { continue }
            names.append(key)
            details[key] = sanitized
        }

        names.sort()
        return (names, details)
    }

    private func parseSubclasses(
        from root: [String: Any],
        classNames: [String]
    ) -> ([String], [String: [String]], [String: [String]]) {
        let containerKeywords = [
            "archetype", "archetypes",
            "domain", "circle", "oath",
            "tradition", "patron", "college",
            "path", "origin", "school",
            "conclave", "bloodline"
        ]
        let subclassExclusions = [
            "content",
            "domain spells",
            "circle spells",
            "oath spells",
            "spell list",
            "spells"
        ]

        var subclassNames = Set<String>()
        var subclassDetails: [String: [String]] = [:]
        var subclassesByClass: [String: [String]] = [:]

        func collectSubclasses(from value: Any, className: String) {
            if let dict = value as? [String: Any] {
                for (key, nested) in dict {
                    let normalized = key.lowercased()
                    if containerKeywords.contains(where: { normalized.contains($0) }),
                       let container = nested as? [String: Any] {
                        for (subclassName, subclassValue) in container {
                            let lower = subclassName.lowercased()
                            guard !subclassExclusions.contains(lower) else { continue }
                            if lower.contains("spell") { continue }
                            let lines = extractTextLines(from: subclassValue, includeKeys: true)
                            let sanitized = sanitize(lines)
                            guard !sanitized.isEmpty else { continue }
                            subclassNames.insert(subclassName)
                            subclassDetails[subclassName] = sanitized
                            subclassesByClass[className, default: []].append(subclassName)
                        }
                    }
                    collectSubclasses(from: nested, className: className)
                }
            } else if let array = value as? [Any] {
                for nested in array {
                    collectSubclasses(from: nested, className: className)
                }
            }
        }

        for className in classNames {
            guard let classDict = root[className] else { continue }
            collectSubclasses(from: classDict, className: className)
        }

        var cleanedByClass: [String: [String]] = [:]
        for (className, list) in subclassesByClass {
            let unique = Array(Set(list)).sorted()
            if !unique.isEmpty {
                cleanedByClass[className] = unique
            }
        }

        return (Array(subclassNames).sorted(), subclassDetails, cleanedByClass)
    }

    private func parseFeats(from root: [String: Any]) -> ([String], [String: [String]]) {
        guard let feats = root["Feats"] as? [String: Any] else { return ([], [:]) }
        var names: [String] = []
        var details: [String: [String]] = [:]
        for (key, value) in feats where key.lowercased() != "content" {
            names.append(key)
            let lines = extractTextLines(from: value, includeKeys: false)
            details[key] = sanitize(lines)
        }
        names.sort()
        return (names, details)
    }

    private func parseSpells(from root: [String: Any]) -> ([String], [String: [String]], [String: [String]]) {
        guard let spellcasting = root["Spellcasting"] as? [String: Any],
              let lists = spellcasting["Spell Lists"] as? [String: Any] else {
            return ([], [:], [:])
        }
        var spells: Set<String> = []
        var spellsByClass: [String: Set<String>] = [:]
        for (className, value) in lists {
            guard let classList = value as? [String: Any] else { continue }
            var classSpells: Set<String> = []
            for (levelKey, levelValue) in classList where levelKey.lowercased() != "content" {
                let names = extractStringList(from: levelValue)
                spells.formUnion(names)
                classSpells.formUnion(names)
            }
            if !className.isEmpty {
                spellsByClass[className] = (spellsByClass[className] ?? []).union(classSpells)
            }
        }
        let detailMap = parseSpellDetails()
        let detailNames = Set(detailMap.keys)
        spells.formUnion(detailNames)
        let finalizedByClass = spellsByClass.mapValues { Array($0).sorted() }
        return (spells.sorted(), detailMap, finalizedByClass)
    }

    private func parseEquipment(from root: [String: Any]) -> ([String], [String: [String]]) {
        guard let equipment = root["Equipment"] as? [String: Any] else { return ([], [:]) }
        var names: Set<String> = []
        var details: [String: [String]] = [:]
        let columns: Set<String> = [
            "Armor", "Name", "Item", "Tool", "Vehicle", "Mount", "Goods"
        ]
        collectTableStrings(from: equipment, columns: columns, results: &names)
        collectTableDetails(from: equipment, nameColumns: columns, results: &details)
        return (names.sorted(), details)
    }

    private func extractStringList(from value: Any) -> [String] {
        if let list = value as? [String] {
            return sanitize(list)
        }
        if let list = value as? [Any] {
            let strings = list.compactMap { $0 as? String }
            return sanitize(strings)
        }
        if let dict = value as? [String: Any] {
            if let content = dict["content"] as? [Any], let first = content.first {
                if let list = first as? [String] {
                    return sanitize(list)
                }
            }
        }
        return []
    }

    private func sanitize(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func collectTableStrings(from value: Any, columns: Set<String>, results: inout Set<String>) {
        if let dict = value as? [String: Any] {
            if let table = dict["table"] as? [String: Any] {
                for (key, columnValue) in table where columns.contains(key) {
                    let names = extractStringList(from: columnValue)
                    results.formUnion(names)
                }
            }
            for (_, nested) in dict {
                collectTableStrings(from: nested, columns: columns, results: &results)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectTableStrings(from: nested, columns: columns, results: &results)
            }
        }
    }

    private func collectTableDetails(from value: Any, nameColumns: Set<String>, results: inout [String: [String]]) {
        if let dict = value as? [String: Any] {
            if let table = dict["table"] as? [String: Any] {
                mergeTableDetails(table: table, nameColumns: nameColumns, results: &results)
            }
            for (_, nested) in dict {
                collectTableDetails(from: nested, nameColumns: nameColumns, results: &results)
            }
        } else if let array = value as? [Any] {
            for nested in array {
                collectTableDetails(from: nested, nameColumns: nameColumns, results: &results)
            }
        }
    }

    private func mergeTableDetails(table: [String: Any], nameColumns: Set<String>, results: inout [String: [String]]) {
        guard let nameColumn = table.keys.first(where: { nameColumns.contains($0) }) else { return }
        let nameValues = extractStringList(from: table[nameColumn] ?? [])
        guard !nameValues.isEmpty else { return }

        var columns: [String: [String]] = [:]
        for (column, value) in table {
            columns[column] = extractStringList(from: value)
        }

        for (index, name) in nameValues.enumerated() {
            var lines: [String] = []
            for (column, values) in columns where column != nameColumn {
                guard index < values.count else { continue }
                let value = values[index]
                if !value.isEmpty {
                    lines.append("\(column): \(value)")
                }
            }
            if !lines.isEmpty {
                results[name] = lines
            }
        }
    }

    private func parseMagicItems(from root: [String: Any]) -> ([String], [String: [String]], [String: String]) {
        guard let magic = root["Magic Items"] as? [String: Any] else { return ([], [:], [:]) }
        var names: [String] = []
        var details: [String: [String]] = [:]
        var rarities: [String: String] = [:]

        for (key, value) in magic where key.lowercased() != "content" {
            names.append(key)
            let lines = extractTextLines(from: value, includeKeys: false)
            let sanitized = sanitize(lines)
            details[key] = sanitized
            if let rarity = extractRarity(from: sanitized.first) {
                rarities[key] = rarity
            }
        }

        names.sort()
        return (names, details, rarities)
    }

    private func parseCreatures() -> ([String], [String: [String]]) {
        guard let data = loadCreaturesData(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [:])
        }

        var names: [String] = []
        var details: [String: [String]] = [:]

        for (_, sectionValue) in json {
            guard let section = sectionValue as? [String: Any] else { continue }
            for (name, entry) in section where name.lowercased() != "content" {
                let lines = extractTextLines(from: entry, includeKeys: false)
                let sanitized = sanitize(lines)
                names.append(name)
                if !sanitized.isEmpty {
                    details[name] = sanitized
                }
            }
        }

        names = Array(Set(names)).sorted()
        return (names, details)
    }

    private func parseSectionDetails(from root: [String: Any]) -> [String: [String]] {
        var details: [String: [String]] = [:]
        for (key, value) in root where key.lowercased() != "content" {
            let lines = extractTextLines(from: value, includeKeys: true)
            let sanitized = sanitize(lines)
            if !sanitized.isEmpty {
                details[key] = sanitized
            }
        }
        return details
    }

    private func loadCreaturesData() -> Data? {
        if let url = bundledSupplementalURL(named: "creatures"), let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    private func parseSpellDetails() -> [String: [String]] {
        guard let data = loadSpellcastingData(),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let spellcasting = json["Spellcasting"] as? [String: Any],
              let descriptions = spellcasting["Spell Descriptions"] as? [String: Any] else {
            return [:]
        }

        var details: [String: [String]] = [:]
        for (name, value) in descriptions where name.lowercased() != "content" {
            let lines = extractTextLines(from: value, includeKeys: false)
            let sanitized = sanitize(lines)
            if !sanitized.isEmpty {
                details[name] = sanitized
            }
        }
        return details
    }

    private func loadSpellcastingData() -> Data? {
        if let url = bundledSupplementalURL(named: "spellcasting"), let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    private func extractTextLines(from value: Any, includeKeys: Bool) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let array = value as? [Any] {
            return array.flatMap { extractTextLines(from: $0, includeKeys: includeKeys) }
        }
        if let dict = value as? [String: Any] {
            if let table = dict["table"] as? [String: Any] {
                return extractTableLines(from: table)
            }
            var lines: [String] = []
            if let content = dict["content"] {
                lines += extractTextLines(from: content, includeKeys: includeKeys)
            }
            for (key, nested) in dict where key.lowercased() != "content" {
                if includeKeys {
                    lines.append(key)
                }
                lines += extractTextLines(from: nested, includeKeys: includeKeys)
            }
            return lines
        }
        return []
    }

    private func extractTableLines(from table: [String: Any]) -> [String] {
        var columns: [String: [String]] = [:]
        let orderedKeys = table.keys.sorted()
        for key in orderedKeys {
            columns[key] = extractStringList(from: table[key] ?? [])
        }
        guard let firstKey = orderedKeys.first, let rowCount = columns[firstKey]?.count else { return [] }
        var lines: [String] = []
        for index in 0..<rowCount {
            var rowParts: [String] = []
            for key in orderedKeys {
                guard let values = columns[key], index < values.count else { continue }
                rowParts.append("\(key): \(values[index])")
            }
            if !rowParts.isEmpty {
                lines.append(rowParts.joined(separator: " | "))
            }
        }
        return lines
    }

    private func extractRarity(from line: String?) -> String? {
        guard var line else { return nil }
        line = line.replacingOccurrences(of: "*", with: "")
        let lower = line.lowercased()
        let rarities = ["common", "uncommon", "rare", "very rare", "legendary", "artifact", "varies"]
        for rarity in rarities where lower.contains(rarity) {
            return rarity
        }
        return nil
    }
}
