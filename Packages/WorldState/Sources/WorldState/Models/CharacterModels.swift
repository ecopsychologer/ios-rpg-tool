import Foundation
import SwiftData

public enum SheetFieldStatus: String, CaseIterable, Identifiable {
    case unknown
    case provisional
    case confirmed

    public var id: String { rawValue }
}

@Model
public final class PlayerCharacter {
    public var id: UUID
    public var displayName: String
    public var rulesetId: String
    public var createdAt: Date
    public var updatedAt: Date
    public var fields: [CharacterField]
    public var facts: [CharacterFact]?
    public var changes: [CharacterChange]?
    public var derivedSummary: String?
    public var origin: String

    public init(
        displayName: String = "",
        rulesetId: String = "srd_5e",
        origin: String = "player"
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.rulesetId = rulesetId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.fields = CharacterSheetDefinitions.defaultFields()
        self.facts = nil
        self.changes = nil
        self.derivedSummary = nil
        self.origin = origin
    }
}

@Model
public final class CharacterField {
    public var id: UUID
    public var section: String
    public var key: String
    public var label: String
    public var valueType: String
    public var valueString: String?
    public var valueInt: Int?
    public var valueDouble: Double?
    public var valueStringList: [String]?
    public var status: String
    public var sourceType: String
    public var sourceId: String?
    public var note: String?
    public var updatedAt: Date
    public var order: Int

    public init(
        section: String,
        key: String,
        label: String,
        valueType: String,
        status: SheetFieldStatus = .unknown,
        sourceType: String = "system",
        order: Int
    ) {
        self.id = UUID()
        self.section = section
        self.key = key
        self.label = label
        self.valueType = valueType
        self.valueString = nil
        self.valueInt = nil
        self.valueDouble = nil
        self.valueStringList = nil
        self.status = status.rawValue
        self.sourceType = sourceType
        self.sourceId = nil
        self.note = nil
        self.updatedAt = Date()
        self.order = order
    }
}

@Model
public final class CharacterFact {
    public var id: UUID
    public var kind: String
    public var payload: String
    public var status: String
    public var sourceType: String
    public var sourceId: String?
    public var note: String?
    public var createdAt: Date
    public var sceneId: UUID?

    public init(
        kind: String,
        payload: String,
        status: String = SheetFieldStatus.provisional.rawValue,
        sourceType: String = "system",
        sourceId: String? = nil,
        note: String? = nil,
        sceneId: UUID? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.payload = payload
        self.status = status
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.note = note
        self.createdAt = Date()
        self.sceneId = sceneId
    }
}

@Model
public final class CharacterChange {
    public var id: UUID
    public var fieldKey: String
    public var oldValue: String?
    public var newValue: String?
    public var changedAt: Date
    public var changedBy: String

    public init(fieldKey: String, oldValue: String?, newValue: String?, changedBy: String = "player") {
        self.id = UUID()
        self.fieldKey = fieldKey
        self.oldValue = oldValue
        self.newValue = newValue
        self.changedAt = Date()
        self.changedBy = changedBy
    }
}

public struct CharacterSheetDefinitions {
    public static let sectionOrder: [String] = [
        "Identity",
        "Progression",
        "Abilities",
        "Skills",
        "Saves",
        "Combat",
        "Resources",
        "Backstory",
        "Notes"
    ]

    public static func defaultFields() -> [CharacterField] {
        var order = 0
        func field(section: String, key: String, label: String, type: String) -> CharacterField {
            order += 1
            return CharacterField(section: section, key: key, label: label, valueType: type, order: order)
        }

        var fields: [CharacterField] = []
        fields.append(field(section: "Identity", key: "name", label: "Name", type: "string"))
        fields.append(field(section: "Identity", key: "pronouns", label: "Pronouns", type: "string"))
        fields.append(field(section: "Identity", key: "species", label: "Species/Ancestry", type: "string"))
        fields.append(field(section: "Identity", key: "age", label: "Age", type: "string"))
        fields.append(field(section: "Identity", key: "description", label: "Description", type: "string"))

        fields.append(field(section: "Progression", key: "class", label: "Class/Archetype", type: "string"))
        fields.append(field(section: "Progression", key: "subclass", label: "Subclass", type: "string"))
        fields.append(field(section: "Progression", key: "level", label: "Level", type: "int"))
        fields.append(field(section: "Progression", key: "background", label: "Background", type: "string"))
        fields.append(field(section: "Progression", key: "alignment", label: "Ethos", type: "string"))

        fields.append(field(section: "Abilities", key: "str", label: "Strength", type: "int"))
        fields.append(field(section: "Abilities", key: "dex", label: "Dexterity", type: "int"))
        fields.append(field(section: "Abilities", key: "con", label: "Constitution", type: "int"))
        fields.append(field(section: "Abilities", key: "int", label: "Intelligence", type: "int"))
        fields.append(field(section: "Abilities", key: "wis", label: "Wisdom", type: "int"))
        fields.append(field(section: "Abilities", key: "cha", label: "Charisma", type: "int"))

        fields.append(field(section: "Skills", key: "skills", label: "Skill Proficiencies", type: "list"))
        fields.append(field(section: "Saves", key: "saves", label: "Saving Throw Proficiencies", type: "list"))

        fields.append(field(section: "Combat", key: "hp_max", label: "HP Max", type: "int"))
        fields.append(field(section: "Combat", key: "hp_current", label: "HP Current", type: "int"))
        fields.append(field(section: "Combat", key: "ac", label: "Armor Class", type: "int"))
        fields.append(field(section: "Combat", key: "initiative", label: "Initiative Bonus", type: "int"))
        fields.append(field(section: "Combat", key: "speed", label: "Speed", type: "int"))
        fields.append(field(section: "Combat", key: "conditions", label: "Conditions", type: "list"))

        fields.append(field(section: "Resources", key: "inventory", label: "Inventory", type: "list"))
        fields.append(field(section: "Resources", key: "currency", label: "Currency", type: "string"))
        fields.append(field(section: "Resources", key: "consumables", label: "Consumables", type: "list"))
        fields.append(field(section: "Resources", key: "resources", label: "Tracked Resources", type: "list"))

        fields.append(field(section: "Backstory", key: "facts", label: "Backstory Facts", type: "list"))
        fields.append(field(section: "Backstory", key: "bonds", label: "Bonds", type: "list"))
        fields.append(field(section: "Backstory", key: "ideals", label: "Ideals", type: "list"))
        fields.append(field(section: "Backstory", key: "flaws", label: "Flaws", type: "list"))

        fields.append(field(section: "Notes", key: "notes", label: "Notes", type: "string"))
        return fields
    }
}
