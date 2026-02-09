import Foundation

public struct SrdContentIndex: Sendable {
    public let abilities: [String]
    public let skills: [SkillDefinition]
    public let senses: [String]
    public let species: [String]
    public let classes: [String]
    public let backgrounds: [String]
    public let subclasses: [String]
    public let feats: [String]
    public let equipment: [String]
    public let spells: [String]
    public let magicItems: [String]
    public let creatures: [String]
    public let conditions: [String]
    public let actions: [String]
    public let encounters: [String]
    public let objects: [String]
    public let loot: [String]
    public let baseItems: [String]
    public let tables: [String]
    public let classDetails: [String: [String]]
    public let backgroundDetails: [String: [String]]
    public let subclassDetails: [String: [String]]
    public let subclassesByClass: [String: [String]]
    public let featDetails: [String: [String]]
    public let spellDetails: [String: [String]]
    public let magicItemDetails: [String: [String]]
    public let equipmentDetails: [String: [String]]
    public let creatureDetails: [String: [String]]
    public let conditionDetails: [String: [String]]
    public let spellsByClass: [String: [String]]
    public let magicItemRarities: [String: String]
    public let itemRecords: [SrdItemRecord]
    public let creatureRecords: [SrdCreatureRecord]
    public let sections: [String]
    public let sectionDetails: [String: [String]]
    public let source: String

    public init(
        abilities: [String],
        skills: [SkillDefinition],
        senses: [String],
        species: [String],
        classes: [String],
        backgrounds: [String],
        subclasses: [String],
        feats: [String],
        equipment: [String],
        spells: [String],
        magicItems: [String],
        creatures: [String],
        conditions: [String],
        actions: [String],
        encounters: [String],
        objects: [String],
        loot: [String],
        baseItems: [String],
        tables: [String],
        classDetails: [String: [String]],
        backgroundDetails: [String: [String]],
        subclassDetails: [String: [String]],
        subclassesByClass: [String: [String]],
        featDetails: [String: [String]],
        spellDetails: [String: [String]],
        magicItemDetails: [String: [String]],
        equipmentDetails: [String: [String]],
        creatureDetails: [String: [String]],
        conditionDetails: [String: [String]],
        spellsByClass: [String: [String]],
        magicItemRarities: [String: String],
        itemRecords: [SrdItemRecord],
        creatureRecords: [SrdCreatureRecord],
        sections: [String],
        sectionDetails: [String: [String]],
        source: String
    ) {
        self.abilities = abilities
        self.skills = skills
        self.senses = senses
        self.species = species
        self.classes = classes
        self.backgrounds = backgrounds
        self.subclasses = subclasses
        self.feats = feats
        self.equipment = equipment
        self.spells = spells
        self.magicItems = magicItems
        self.creatures = creatures
        self.conditions = conditions
        self.actions = actions
        self.encounters = encounters
        self.objects = objects
        self.loot = loot
        self.baseItems = baseItems
        self.tables = tables
        self.classDetails = classDetails
        self.backgroundDetails = backgroundDetails
        self.subclassDetails = subclassDetails
        self.subclassesByClass = subclassesByClass
        self.featDetails = featDetails
        self.spellDetails = spellDetails
        self.magicItemDetails = magicItemDetails
        self.equipmentDetails = equipmentDetails
        self.creatureDetails = creatureDetails
        self.conditionDetails = conditionDetails
        self.spellsByClass = spellsByClass
        self.magicItemRarities = magicItemRarities
        self.itemRecords = itemRecords
        self.creatureRecords = creatureRecords
        self.sections = sections
        self.sectionDetails = sectionDetails
        self.source = source
    }
}

public struct SrdContentStore {
    private let devSupplementalFlagKey = "devEnableSupplementalRules"

    public init() {}

    public func loadIndex() -> SrdContentIndex? {
        guard let (data, source) = loadDataAndSource() else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let baseIndex = buildIndex(from: json, source: source)
            var mergedIndex = baseIndex
            if let userSupplemental = loadUserSupplementalContent() {
                mergedIndex = merge(base: mergedIndex, supplemental: userSupplemental, sourceSuffix: "user")
            }
            if let devSupplemental = loadDevSupplementalContent() {
                mergedIndex = merge(base: mergedIndex, supplemental: devSupplemental, sourceSuffix: "dev")
            }
            return mergedIndex
        }
        if source == "imported",
           let bundledData = loadBundledData(),
           let json = try? JSONSerialization.jsonObject(with: bundledData) as? [String: Any] {
            let baseIndex = buildIndex(from: json, source: "bundled")
            var mergedIndex = baseIndex
            if let userSupplemental = loadUserSupplementalContent() {
                mergedIndex = merge(base: mergedIndex, supplemental: userSupplemental, sourceSuffix: "user")
            }
            if let devSupplemental = loadDevSupplementalContent() {
                mergedIndex = merge(base: mergedIndex, supplemental: devSupplemental, sourceSuffix: "dev")
            }
            return mergedIndex
        }
        return nil
    }

    private func buildIndex(from json: [String: Any], source: String) -> SrdContentIndex {
        let abilities = parseAbilities(from: json)
        let skills = parseSkills(from: json, abilities: abilities)
        let senses: [String] = []
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
        let (conditions, conditionDetails) = parseConditions(from: json)
        let actions: [String] = []
        let encounters: [String] = []
        let objects: [String] = []
        let loot: [String] = []
        let baseItems: [String] = []
        let tables: [String] = []
        let itemRecords = parseItemRecords(from: json, source: source)
        let creatureRecords = parseCreatureRecords(from: json, source: source)
        let sections = json.keys.sorted()
        let sectionDetails = parseSectionDetails(from: json)

        return SrdContentIndex(
            abilities: abilities,
            skills: skills,
            senses: senses,
            species: species,
            classes: classes,
            backgrounds: backgrounds,
            subclasses: subclasses,
            feats: feats,
            equipment: equipment,
            spells: spells,
            magicItems: magicItems,
            creatures: creatures,
            conditions: conditions,
            actions: actions,
            encounters: encounters,
            objects: objects,
            loot: loot,
            baseItems: baseItems,
            tables: tables,
            classDetails: classDetails,
            backgroundDetails: backgroundDetails,
            subclassDetails: subclassDetails,
            subclassesByClass: subclassesByClass,
            featDetails: featDetails,
            spellDetails: spellDetails,
            magicItemDetails: magicItemDetails,
            equipmentDetails: equipmentDetails,
            creatureDetails: creatureDetails,
            conditionDetails: conditionDetails,
            spellsByClass: spellsByClass,
            magicItemRarities: magicItemRarities,
            itemRecords: itemRecords,
            creatureRecords: creatureRecords,
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

    private func parseConditions(from root: [String: Any]) -> ([String], [String: [String]]) {
        guard let appendix = root["Appendix PH-A: Conditions"] as? [String: Any] else { return ([], [:]) }
        var names: [String] = []
        var details: [String: [String]] = [:]

        for (key, value) in appendix where key.lowercased() != "content" {
            let lines = extractTextLines(from: value, includeKeys: false)
            let sanitized = sanitize(lines)
            guard !sanitized.isEmpty else { continue }
            names.append(key)
            details[key] = sanitized
        }

        names.sort()
        return (names, details)
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

    private func parseItemRecords(from json: [String: Any], source: String) -> [SrdItemRecord] {
        var records: [SrdItemRecord] = []
        records.append(contentsOf: parseEquipmentRecords(from: json, source: source))
        records.append(contentsOf: parseMagicItemRecords(from: json, source: source))
        return records
    }

    private func parseEquipmentRecords(from json: [String: Any], source: String) -> [SrdItemRecord] {
        guard let equipment = json["Equipment"] as? [String: Any] else { return [] }
        var results: [SrdItemRecord] = []

        func walk(node: Any, path: [String]) {
            if let dict = node as? [String: Any], isEquipmentTable(dict) {
                let records = equipmentRecords(from: dict, path: path, source: source)
                results.append(contentsOf: records)
                return
            }
            if let dict = node as? [String: Any] {
                for (key, value) in dict {
                    walk(node: value, path: path + [key])
                }
            } else if let list = node as? [Any] {
                for item in list {
                    walk(node: item, path: path)
                }
            }
        }

        walk(node: equipment, path: [])
        return results
    }

    private func isEquipmentTable(_ dict: [String: Any]) -> Bool {
        let arrays = dict.values.compactMap { $0 as? [Any] }
        guard !arrays.isEmpty else { return false }
        let counts = Set(arrays.map { $0.count })
        return counts.count == 1 && (counts.first ?? 0) > 0
    }

    private func equipmentRecords(from dict: [String: Any], path: [String], source: String) -> [SrdItemRecord] {
        let nameColumns = ["Armor", "Weapon", "Item", "Gear", "Tool", "Mount", "Vehicle", "Service", "Trade Good", "Product", "Ammunition"]
        guard let nameKey = nameColumns.first(where: { dict[$0] != nil }),
              let names = dict[nameKey] as? [Any] else { return [] }

        let category = path.first(where: { !$0.isEmpty }) ?? "Equipment"
        let subcategory = path.last(where: { $0 != category && !$0.isEmpty })

        func stringColumn(_ key: String, index: Int) -> String? {
            guard let values = dict[key] as? [Any], index < values.count else { return nil }
            return values[index] as? String
        }

        let count = names.count
        var records: [SrdItemRecord] = []
        records.reserveCapacity(count)

        for index in 0..<count {
            guard let rawName = names[index] as? String else { continue }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let cost = stringColumn("Cost", index: index) ?? stringColumn("Price", index: index)
            let weight = stringColumn("Weight", index: index)
            var properties: [String] = []
            if let props = stringColumn("Properties", index: index) {
                properties.append(contentsOf: props.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            }

            let extraKeys = dict.keys.filter { key in
                ![nameKey, "Cost", "Price", "Weight", "Properties"].contains(key)
            }
            for key in extraKeys {
                if let value = stringColumn(key, index: index), !value.isEmpty {
                    properties.append("\(key): \(value)")
                }
            }

            let record = SrdItemRecord(
                name: name,
                category: category,
                subcategory: subcategory,
                itemType: nil,
                rarity: nil,
                requiresAttunement: false,
                attunementRequirement: nil,
                cost: cost,
                weight: weight,
                properties: properties,
                description: [],
                source: source
            )
            records.append(record)
        }

        return records
    }

    private func parseMagicItemRecords(from json: [String: Any], source: String) -> [SrdItemRecord] {
        guard let magic = json["Magic Items"] as? [String: Any] else { return [] }
        var results: [SrdItemRecord] = []

        func walk(node: Any, path: [String]) {
            guard let dict = node as? [String: Any] else { return }
            if let content = dict["content"] as? [Any],
               let name = path.last,
               let record = magicItemRecord(name: name, content: content, source: source) {
                results.append(record)
            }
            for (key, value) in dict where key != "content" {
                walk(node: value, path: path + [key])
            }
        }

        walk(node: magic, path: [])
        return results
    }

    private func magicItemRecord(name: String, content: [Any], source: String) -> SrdItemRecord? {
        let lines = content.compactMap { $0 as? String }
        guard let typeLine = lines.first(where: { $0.contains("*") && $0.lowercased().contains("item") }) else { return nil }

        let cleaned = typeLine.replacingOccurrences(of: "*", with: "")
        let requiresAttunement = cleaned.lowercased().contains("attunement")
        let rarity = extractRarity(from: cleaned)
        let itemType = cleaned.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let attunementRequirement = requiresAttunement ? cleaned : nil
        let description = lines.filter { $0 != typeLine }

        return SrdItemRecord(
            name: name,
            category: "Magic Item",
            subcategory: nil,
            itemType: itemType,
            rarity: rarity,
            requiresAttunement: requiresAttunement,
            attunementRequirement: attunementRequirement,
            cost: nil,
            weight: nil,
            properties: [],
            description: description,
            source: source
        )
    }

    private func parseCreatureRecords(from json: [String: Any], source: String) -> [SrdCreatureRecord] {
        guard let monsters = json["Monsters"] as? [String: Any] else { return [] }
        var records: [SrdCreatureRecord] = []

        for (section, value) in monsters where section.hasPrefix("Monsters (") {
            guard let entries = value as? [String: Any] else { continue }
            for (name, entry) in entries {
                guard name != "content",
                      let dict = entry as? [String: Any],
                      let content = dict["content"] as? [Any] else { continue }
                if let record = creatureRecord(name: name, content: content, source: source) {
                    records.append(record)
                }
            }
        }

        return records
    }

    private func creatureRecord(name: String, content: [Any], source: String) -> SrdCreatureRecord? {
        let lines = content.compactMap { $0 as? String }
        guard !lines.isEmpty else { return nil }

        let headerLine = lines.first(where: { $0.contains("*") }) ?? ""
        let headerClean = headerLine.replacingOccurrences(of: "*", with: "")
        let headerParts = headerClean.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let sizeTypePart = headerParts.first ?? ""
        let alignment = headerParts.count > 1 ? headerParts[1] : nil
        let sizeTypeParts = sizeTypePart.split(separator: " ", maxSplits: 1)
        let size = sizeTypeParts.first.map(String.init)
        let creatureType = sizeTypeParts.count > 1 ? String(sizeTypeParts[1]) : nil

        var armorClass: String?
        var hitPoints: String?
        var speed: String?
        var savingThrows: String?
        var skills: String?
        var senses: String?
        var languages: String?
        var challenge: String?
        var damageVulnerabilities: String?
        var damageResistances: String?
        var damageImmunities: String?
        var conditionImmunities: String?
        var abilityScores: [String: String] = [:]
        var traits: [String] = []
        var actions: [String] = []
        var reactions: [String] = []
        var legendary: [String] = []

        var section = "traits"

        for item in content {
            if let line = item as? String {
                if line.contains("***Actions***") || line.contains("**Actions**") {
                    section = "actions"
                    continue
                }
                if line.contains("***Reactions***") || line.contains("**Reactions**") {
                    section = "reactions"
                    continue
                }
                if line.contains("Legendary Actions") {
                    section = "legendary"
                    continue
                }

                if let value = extractValue(from: line, prefix: "**Armor Class**") {
                    armorClass = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Hit Points**") {
                    hitPoints = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Speed**") {
                    speed = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Saving Throws**") {
                    savingThrows = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Skills**") {
                    skills = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Senses**") {
                    senses = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Damage Vulnerabilities**") {
                    damageVulnerabilities = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Damage Resistances**") {
                    damageResistances = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Damage Immunities**") {
                    damageImmunities = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Condition Immunities**") {
                    conditionImmunities = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Languages**") {
                    languages = value
                    continue
                }
                if let value = extractValue(from: line, prefix: "**Challenge**") {
                    challenge = value
                    continue
                }

                if line.hasPrefix("***") || line.hasPrefix("**") {
                    switch section {
                    case "actions":
                        actions.append(line)
                    case "reactions":
                        reactions.append(line)
                    case "legendary":
                        legendary.append(line)
                    default:
                        traits.append(line)
                    }
                }
            } else if let dict = item as? [String: Any] {
                if let table = dict["table"] as? [String: Any] {
                    abilityScores.merge(parseAbilityTable(table)) { current, _ in current }
                } else if dict.keys.contains("STR") {
                    abilityScores.merge(parseAbilityTable(dict)) { current, _ in current }
                }
            }
        }

        return SrdCreatureRecord(
            name: name,
            size: size,
            creatureType: creatureType,
            alignment: alignment,
            armorClass: armorClass,
            hitPoints: hitPoints,
            speed: speed,
            savingThrows: savingThrows,
            skills: skills,
            senses: senses,
            languages: languages,
            challenge: challenge,
            damageVulnerabilities: damageVulnerabilities,
            damageResistances: damageResistances,
            damageImmunities: damageImmunities,
            conditionImmunities: conditionImmunities,
            abilityScores: abilityScores,
            traits: traits,
            actions: actions,
            reactions: reactions,
            legendaryActions: legendary,
            source: source
        )
    }

    private func parseAbilityTable(_ table: [String: Any]) -> [String: String] {
        let abilities = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
        var results: [String: String] = [:]
        for ability in abilities {
            if let values = table[ability] as? [Any], let first = values.first as? String {
                results[ability] = first
            }
        }
        return results
    }

    private func extractValue(from line: String, prefix: String) -> String? {
        guard line.hasPrefix(prefix) else { return nil }
        return line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
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

private struct SupplementalContent {
    var species: [String] = []
    var classes: [String] = []
    var subclasses: [String] = []
    var backgrounds: [String] = []
    var feats: [String] = []
    var spells: [String] = []
    var equipment: [String] = []
    var magicItems: [String] = []
    var creatures: [String] = []
    var skills: [SkillDefinition] = []
    var senses: [String] = []
    var actions: [String] = []
    var encounters: [String] = []
    var objects: [String] = []
    var loot: [String] = []
    var baseItems: [String] = []
    var tables: [String] = []
    var classDetails: [String: [String]] = [:]
    var subclassDetails: [String: [String]] = [:]
    var backgroundDetails: [String: [String]] = [:]
    var featDetails: [String: [String]] = [:]
    var spellDetails: [String: [String]] = [:]
    var equipmentDetails: [String: [String]] = [:]
    var magicItemDetails: [String: [String]] = [:]
    var creatureDetails: [String: [String]] = [:]
    var magicItemRarities: [String: String] = [:]
    var subclassesByClass: [String: [String]] = [:]
}

private extension SupplementalContent {
    var isEmpty: Bool {
        species.isEmpty &&
        classes.isEmpty &&
        subclasses.isEmpty &&
        backgrounds.isEmpty &&
        feats.isEmpty &&
        spells.isEmpty &&
        equipment.isEmpty &&
        magicItems.isEmpty &&
        creatures.isEmpty &&
        skills.isEmpty &&
        senses.isEmpty &&
        actions.isEmpty &&
        encounters.isEmpty &&
        objects.isEmpty &&
        loot.isEmpty &&
        baseItems.isEmpty &&
        tables.isEmpty &&
        classDetails.isEmpty &&
        subclassDetails.isEmpty &&
        backgroundDetails.isEmpty &&
        featDetails.isEmpty &&
        spellDetails.isEmpty &&
        equipmentDetails.isEmpty &&
        magicItemDetails.isEmpty &&
        creatureDetails.isEmpty &&
        magicItemRarities.isEmpty &&
        subclassesByClass.isEmpty
    }
}

extension SrdContentStore {
    public func ensureUserDataDirectory() -> URL? {
        guard let documents = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }
        let dataURL = documents.appendingPathComponent("data", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dataURL.path) {
            try? FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        }
        return dataURL
    }

    private func loadUserSupplementalContent() -> SupplementalContent? {
        guard let rootURL = ensureUserDataDirectory() else { return nil }
        return loadSupplementalContent(from: rootURL)
    }

    private func loadDevSupplementalContent() -> SupplementalContent? {
        guard UserDefaults.standard.bool(forKey: devSupplementalFlagKey) else { return nil }
        guard let rootURL = devContentDataURL() else { return nil }
        return loadSupplementalContent(from: rootURL)
    }

    private func loadSupplementalContent(from rootURL: URL) -> SupplementalContent? {
        let parser = UserContentParser()

        var content = SupplementalContent()

        if let (names, details) = parser.loadBackgrounds(from: rootURL) {
            content.backgrounds = names
            content.backgroundDetails = details
        }

        if let (names, details) = parser.loadFeats(from: rootURL) {
            content.feats = names
            content.featDetails = details
        }

        if let (names, _) = parser.loadSpecies(from: rootURL) {
            content.species = names
        }

        if let (classes, classDetails, subclasses, subclassDetails, subclassesByClass) = parser.loadClasses(from: rootURL) {
            content.classes = classes
            content.classDetails = classDetails
            content.subclasses = subclasses
            content.subclassDetails = subclassDetails
            content.subclassesByClass = subclassesByClass
        }

        if let (spells, details) = parser.loadSpells(from: rootURL) {
            content.spells = spells
            content.spellDetails = details
        }

        if let (equipment, equipmentDetails, magicItems, magicItemDetails, magicItemRarities) = parser.loadItems(from: rootURL) {
            content.equipment = equipment
            content.equipmentDetails = equipmentDetails
            content.magicItems = magicItems
            content.magicItemDetails = magicItemDetails
            content.magicItemRarities = magicItemRarities
        }

        if let (creatures, creatureDetails) = parser.loadCreatures(from: rootURL) {
            content.creatures = creatures
            content.creatureDetails = creatureDetails
        }

        if let skills = parser.loadSkills(from: rootURL) {
            content.skills = skills
        }

        if let senses = parser.loadSenses(from: rootURL) {
            content.senses = senses
        }

        if let actions = parser.loadActions(from: rootURL) {
            content.actions = actions
        }

        if let encounters = parser.loadEncounters(from: rootURL) {
            content.encounters = encounters
        }

        if let objects = parser.loadObjects(from: rootURL) {
            content.objects = objects
        }

        if let loot = parser.loadLoot(from: rootURL) {
            content.loot = loot
        }

        if let baseItems = parser.loadBaseItems(from: rootURL) {
            content.baseItems = baseItems
        }

        if let tables = parser.loadTables(from: rootURL) {
            content.tables = tables
        }

        return content.isEmpty ? nil : content
    }

    private func devContentDataURL() -> URL? {
        if let url = Bundle.main.url(forResource: "data", withExtension: nil, subdirectory: "DevAssets/data") {
            return url
        }
        return nil
    }

    private func merge(base: SrdContentIndex, supplemental: SupplementalContent, sourceSuffix: String) -> SrdContentIndex {
        let mergedSpecies = mergeStrings(base.species, supplemental.species)
        let mergedClasses = mergeStrings(base.classes, supplemental.classes)
        let mergedSubclasses = mergeStrings(base.subclasses, supplemental.subclasses)
        let mergedBackgrounds = mergeStrings(base.backgrounds, supplemental.backgrounds)
        let mergedFeats = mergeStrings(base.feats, supplemental.feats)
        let mergedSpells = mergeStrings(base.spells, supplemental.spells)
        let mergedEquipment = mergeStrings(base.equipment, supplemental.equipment)
        let mergedMagicItems = mergeStrings(base.magicItems, supplemental.magicItems)
        let mergedCreatures = mergeStrings(base.creatures, supplemental.creatures)
        let mergedSkills = mergeSkills(base.skills, supplemental.skills)
        let mergedSenses = mergeStrings(base.senses, supplemental.senses)
        let mergedActions = mergeStrings(base.actions, supplemental.actions)
        let mergedEncounters = mergeStrings(base.encounters, supplemental.encounters)
        let mergedObjects = mergeStrings(base.objects, supplemental.objects)
        let mergedLoot = mergeStrings(base.loot, supplemental.loot)
        let mergedBaseItems = mergeStrings(base.baseItems, supplemental.baseItems)
        let mergedTables = mergeStrings(base.tables, supplemental.tables)

        let classDetails = mergeDetails(base.classDetails, supplemental.classDetails)
        let subclassDetails = mergeDetails(base.subclassDetails, supplemental.subclassDetails)
        let backgroundDetails = mergeDetails(base.backgroundDetails, supplemental.backgroundDetails)
        let featDetails = mergeDetails(base.featDetails, supplemental.featDetails)
        let spellDetails = mergeDetails(base.spellDetails, supplemental.spellDetails)
        let equipmentDetails = mergeDetails(base.equipmentDetails, supplemental.equipmentDetails)
        let magicItemDetails = mergeDetails(base.magicItemDetails, supplemental.magicItemDetails)
        let creatureDetails = mergeDetails(base.creatureDetails, supplemental.creatureDetails)

        let magicItemRarities = mergeRarities(base.magicItemRarities, supplemental.magicItemRarities)
        let subclassesByClass = mergeStringMap(base.subclassesByClass, supplemental.subclassesByClass)

        let mergedSource = appendSource(base.source, suffix: sourceSuffix)

        return SrdContentIndex(
            abilities: base.abilities,
            skills: mergedSkills,
            senses: mergedSenses,
            species: mergedSpecies,
            classes: mergedClasses,
            backgrounds: mergedBackgrounds,
            subclasses: mergedSubclasses,
            feats: mergedFeats,
            equipment: mergedEquipment,
            spells: mergedSpells,
            magicItems: mergedMagicItems,
            creatures: mergedCreatures,
            conditions: base.conditions,
            actions: mergedActions,
            encounters: mergedEncounters,
            objects: mergedObjects,
            loot: mergedLoot,
            baseItems: mergedBaseItems,
            tables: mergedTables,
            classDetails: classDetails,
            backgroundDetails: backgroundDetails,
            subclassDetails: subclassDetails,
            subclassesByClass: subclassesByClass,
            featDetails: featDetails,
            spellDetails: spellDetails,
            magicItemDetails: magicItemDetails,
            equipmentDetails: equipmentDetails,
            creatureDetails: creatureDetails,
            conditionDetails: base.conditionDetails,
            spellsByClass: base.spellsByClass,
            magicItemRarities: magicItemRarities,
            itemRecords: base.itemRecords,
            creatureRecords: base.creatureRecords,
            sections: base.sections,
            sectionDetails: base.sectionDetails,
            source: mergedSource
        )
    }

    private func mergeStrings(_ base: [String], _ extra: [String]) -> [String] {
        var seen: [String: String] = [:]
        for item in base {
            let key = item.lowercased()
            if seen[key] == nil {
                seen[key] = item
            }
        }
        for item in extra {
            let key = item.lowercased()
            if seen[key] == nil {
                seen[key] = item
            }
        }
        return seen.values.sorted()
    }

    private func mergeSkills(_ base: [SkillDefinition], _ extra: [SkillDefinition]) -> [SkillDefinition] {
        var seen: [String: SkillDefinition] = [:]
        for skill in base {
            let key = skill.name.lowercased()
            if seen[key] == nil {
                seen[key] = skill
            }
        }
        for skill in extra {
            let key = skill.name.lowercased()
            if seen[key] == nil {
                seen[key] = skill
            }
        }
        return seen.values.sorted { $0.name < $1.name }
    }

    private func appendSource(_ base: String, suffix: String) -> String {
        let tokens = base
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if tokens.contains(suffix.lowercased()) {
            return base
        }
        return "\(base) + \(suffix)"
    }

    private func mergeDetails(_ base: [String: [String]], _ extra: [String: [String]]) -> [String: [String]] {
        var merged = base
        var map = Dictionary(uniqueKeysWithValues: base.keys.map { ($0.lowercased(), $0) })
        for (key, lines) in extra {
            let lower = key.lowercased()
            if let existing = map[lower] {
                if (merged[existing]?.isEmpty ?? true), !lines.isEmpty {
                    merged[existing] = lines
                }
            } else {
                merged[key] = lines
                map[lower] = key
            }
        }
        return merged
    }

    private func mergeRarities(_ base: [String: String], _ extra: [String: String]) -> [String: String] {
        var merged = base
        var map = Dictionary(uniqueKeysWithValues: base.keys.map { ($0.lowercased(), $0) })
        for (key, rarity) in extra {
            let lower = key.lowercased()
            if map[lower] == nil {
                merged[key] = rarity
                map[lower] = key
            }
        }
        return merged
    }

    private func mergeStringMap(_ base: [String: [String]], _ extra: [String: [String]]) -> [String: [String]] {
        var merged = base
        for (key, list) in extra {
            let existing = merged[key] ?? []
            merged[key] = mergeStrings(existing, list)
        }
        return merged
    }
}

private struct UserContentParser {
    func loadBackgrounds(from root: URL) -> ([String], [String: [String]])? {
        guard let data = loadJSON(from: root.appendingPathComponent("backgrounds.json")),
              let list = data["background"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: backgroundDetail)
    }

    func loadFeats(from root: URL) -> ([String], [String: [String]])? {
        guard let data = loadJSON(from: root.appendingPathComponent("feats.json")),
              let list = data["feat"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail)
    }

    func loadSpecies(from root: URL) -> ([String], [String: [String]])? {
        guard let data = loadJSON(from: root.appendingPathComponent("races.json")) else { return nil }
        var list: [[String: Any]] = []
        if let races = data["race"] as? [[String: Any]] {
            list.append(contentsOf: races)
        }
        if let subraces = data["subrace"] as? [[String: Any]] {
            list.append(contentsOf: subraces)
        }
        return parseEntries(list, detailBuilder: simpleDetail, nameTransform: raceName)
    }

    func loadClasses(from root: URL) -> ([String], [String: [String]], [String], [String: [String]], [String: [String]])? {
        let classFolder = root.appendingPathComponent("class")
        guard let files = listJSONFiles(in: classFolder, prefix: "class-") else { return nil }
        var classList: [String] = []
        var classDetails: [String: [String]] = [:]
        var subclassList: [String] = []
        var subclassDetails: [String: [String]] = [:]
        var subclassesByClass: [String: [String]] = [:]

        for file in files {
            guard let data = loadJSON(from: file) else { continue }
            if let classes = data["class"] as? [[String: Any]] {
                let parsed = parseEntries(classes, detailBuilder: classDetail)
                classList.append(contentsOf: parsed.names)
                classDetails.merge(parsed.details) { current, _ in current }
            }
            if let subclasses = data["subclass"] as? [[String: Any]] {
                for entry in subclasses {
                    guard let name = entry["name"] as? String else { continue }
                    let className = entry["className"] as? String ?? "Unknown Class"
                    subclassList.append(name)
                    let details = classDetail(entry)
                    if !details.isEmpty {
                        subclassDetails[name] = details
                    }
                    subclassesByClass[className, default: []].append(name)
                }
            }
        }

        classList = uniqueSorted(classList)
        subclassList = uniqueSorted(subclassList)
        for (key, list) in subclassesByClass {
            subclassesByClass[key] = uniqueSorted(list)
        }

        return (classList, classDetails, subclassList, subclassDetails, subclassesByClass)
    }

    func loadSpells(from root: URL) -> ([String], [String: [String]])? {
        let spellsFolder = root.appendingPathComponent("spells")
        guard let files = listJSONFiles(in: spellsFolder, prefix: "spells-") else { return nil }
        var names: [String] = []
        var details: [String: [String]] = [:]
        for file in files {
            guard let data = loadJSON(from: file),
                  let list = data["spell"] as? [[String: Any]] else { continue }
            let parsed = parseEntries(list, detailBuilder: spellDetail)
            names.append(contentsOf: parsed.names)
            details.merge(parsed.details) { current, _ in current }
        }
        return (uniqueSorted(names), details)
    }

    func loadItems(from root: URL) -> ([String], [String: [String]], [String], [String: [String]], [String: String])? {
        guard let data = loadJSON(from: root.appendingPathComponent("items.json")),
              let list = data["item"] as? [[String: Any]] else { return nil }
        var equipment: [String] = []
        var equipmentDetails: [String: [String]] = [:]
        var magicItems: [String] = []
        var magicItemDetails: [String: [String]] = [:]
        var magicItemRarities: [String: String] = [:]

        for entry in list {
            guard let name = entry["name"] as? String else { continue }
            let rarity = entry["rarity"] as? String ?? ""
            let details = itemDetail(entry)
            if !rarity.isEmpty && rarity.lowercased() != "none" {
                magicItems.append(name)
                magicItemDetails[name] = details
                magicItemRarities[name] = rarity.lowercased()
            } else {
                equipment.append(name)
                equipmentDetails[name] = details
            }
        }

        return (
            uniqueSorted(equipment),
            equipmentDetails,
            uniqueSorted(magicItems),
            magicItemDetails,
            magicItemRarities
        )
    }

    func loadCreatures(from root: URL) -> ([String], [String: [String]])? {
        let bestiaryFolder = root.appendingPathComponent("bestiary")
        guard let files = listJSONFiles(in: bestiaryFolder, prefix: "bestiary-") else { return nil }
        var names: [String] = []
        var details: [String: [String]] = [:]
        for file in files {
            guard let data = loadJSON(from: file),
                  let list = data["monster"] as? [[String: Any]] else { continue }
            let parsed = parseEntries(list, detailBuilder: creatureDetail)
            names.append(contentsOf: parsed.names)
            details.merge(parsed.details) { current, _ in current }
        }
        return (uniqueSorted(names), details)
    }

    func loadSkills(from root: URL) -> [SkillDefinition]? {
        guard let data = loadJSON(from: root.appendingPathComponent("skills.json")),
              let list = data["skill"] as? [[String: Any]] else { return nil }
        var definitions: [SkillDefinition] = []
        for entry in list {
            guard let name = entry["name"] as? String else { continue }
            let abilityCode = entry["ability"] as? String
            guard let abilityName = abilityName(from: abilityCode) else { continue }
            definitions.append(SkillDefinition(name: name, defaultAbility: abilityName))
        }
        return uniqueSortedSkills(definitions)
    }

    func loadSenses(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("senses.json")),
              let list = data["sense"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    func loadActions(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("actions.json")),
              let list = data["action"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    func loadEncounters(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("encounters.json")),
              let list = data["encounter"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    func loadObjects(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("objects.json")),
              let list = data["object"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    func loadLoot(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("loot.json")) else { return nil }
        var names: [String] = []
        let keys = ["individual", "hoard", "dragon", "gems", "artObjects", "magicItems", "dragonMundaneItems"]
        for key in keys {
            guard let list = data[key] as? [[String: Any]] else { continue }
            for entry in list {
                if let name = entry["name"] as? String {
                    names.append(name)
                } else if let item = entry["item"] as? String {
                    names.append(item)
                }
            }
        }
        return uniqueSorted(names)
    }

    func loadBaseItems(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("items-base.json")),
              let list = data["baseitem"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    func loadTables(from root: URL) -> [String]? {
        guard let data = loadJSON(from: root.appendingPathComponent("tables.json")),
              let list = data["table"] as? [[String: Any]] else { return nil }
        return parseEntries(list, detailBuilder: simpleDetail).names
    }

    private func parseEntries(
        _ list: [[String: Any]],
        detailBuilder: ([String: Any]) -> [String],
        nameTransform: (([String: Any]) -> String?)? = nil
    ) -> (names: [String], details: [String: [String]]) {
        var names: [String] = []
        var details: [String: [String]] = [:]
        for entry in list {
            guard let name = nameTransform?(entry) ?? (entry["name"] as? String) else { continue }
            names.append(name)
            let lines = detailBuilder(entry)
            if !lines.isEmpty {
                details[name] = lines
            }
        }
        return (uniqueSorted(names), details)
    }

    private func backgroundDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        lines += extractEntries(from: entry["entries"])
        return sanitize(lines)
    }

    private func classDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        if let hitDice = entry["hd"] as? [String: Any], let faces = hitDice["faces"] as? Int {
            lines.append("Hit Die: d\(faces)")
        }
        if let subclassTitle = entry["subclassTitle"] as? String {
            lines.append("Subclass: \(subclassTitle)")
        }
        lines += extractEntries(from: entry["entries"])
        return sanitize(lines)
    }

    private func simpleDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        lines += extractEntries(from: entry["entries"])
        return sanitize(lines)
    }

    private func spellDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        if let level = entry["level"] as? Int {
            lines.append("Level: \(level)")
        }
        if let school = entry["school"] as? String {
            lines.append("School: \(school)")
        }
        if let range = entry["range"] as? [String: Any] {
            if let rangeType = range["type"] as? String {
                lines.append("Range: \(rangeType)")
            }
        }
        if let duration = entry["duration"] as? [[String: Any]],
           let first = duration.first,
           let durationType = first["type"] as? String {
            lines.append("Duration: \(durationType)")
        }
        lines += extractEntries(from: entry["entries"])
        return sanitize(lines)
    }

    private func itemDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        if let rarity = entry["rarity"] as? String, !rarity.isEmpty {
            lines.append("Rarity: \(rarity)")
        }
        if let itemType = entry["type"] as? String {
            lines.append("Type: \(itemType)")
        }
        lines += extractEntries(from: entry["entries"])
        return sanitize(lines)
    }

    private func creatureDetail(_ entry: [String: Any]) -> [String] {
        var lines = sourceLine(entry)
        if let size = entry["size"] as? [String], let first = size.first {
            lines.append("Size: \(first)")
        }
        if let type = entry["type"] as? String {
            lines.append("Type: \(type)")
        }
        if let cr = entry["cr"] {
            lines.append("CR: \(formatValue(cr))")
        }
        if let alignment = entry["alignment"] {
            lines.append("Alignment: \(formatValue(alignment))")
        }
        return sanitize(lines)
    }

    private func raceName(_ entry: [String: Any]) -> String? {
        let name = entry["name"] as? String
        if let raceName = entry["raceName"] as? String,
           let name, !raceName.isEmpty {
            return "\(raceName) (\(name))"
        }
        return name
    }

    private func sourceLine(_ entry: [String: Any]) -> [String] {
        if let source = entry["source"] as? String {
            return ["Source: \(source)"]
        }
        return []
    }

    private func extractEntries(from value: Any?) -> [String] {
        guard let value else { return [] }
        return flattenText(value)
    }

    private func flattenText(_ value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }
        if let array = value as? [Any] {
            return array.flatMap { flattenText($0) }
        }
        if let dict = value as? [String: Any] {
            if let entries = dict["entries"] {
                var lines = flattenText(entries)
                if let name = dict["name"] as? String {
                    lines.insert(name, at: 0)
                }
                return lines
            }
            if let items = dict["items"] {
                return flattenText(items)
            }
            if let entry = dict["entry"] {
                return flattenText(entry)
            }
            if let text = dict["text"] as? String {
                return [text]
            }
            return dict.values.flatMap { flattenText($0) }
        }
        return []
    }

    private func listJSONFiles(in directory: URL, prefix: String) -> [URL]? {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return nil
        }
        return files.filter { url in
            url.pathExtension == "json" && url.lastPathComponent.hasPrefix(prefix)
        }
    }

    private func loadJSON(from url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func uniqueSorted(_ values: [String]) -> [String] {
        var seen: [String: String] = [:]
        for value in values {
            let key = value.lowercased()
            if seen[key] == nil {
                seen[key] = value
            }
        }
        return seen.values.sorted()
    }

    private func uniqueSortedSkills(_ values: [SkillDefinition]) -> [SkillDefinition] {
        var seen: [String: SkillDefinition] = [:]
        for value in values {
            let key = value.name.lowercased()
            if seen[key] == nil {
                seen[key] = value
            }
        }
        return seen.values.sorted { $0.name < $1.name }
    }

    private func abilityName(from code: String?) -> String? {
        guard let code else { return nil }
        switch code.lowercased() {
        case "str":
            return "Strength"
        case "dex":
            return "Dexterity"
        case "con":
            return "Constitution"
        case "int":
            return "Intelligence"
        case "wis":
            return "Wisdom"
        case "cha":
            return "Charisma"
        default:
            return nil
        }
    }

    private func sanitize(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func formatValue(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let dict = value as? [String: Any],
           let cr = dict["cr"] {
            return formatValue(cr)
        }
        if let array = value as? [Any] {
            return array.compactMap { formatValue($0) }.joined(separator: ", ")
        }
        return "\(value)"
    }
}
