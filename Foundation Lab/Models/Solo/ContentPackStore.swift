import Foundation

struct ContentPackStore {
    let fileName = "solo_default_tables.json"

    func loadDefaultPack() throws -> ContentPack {
        let url = try ensureDefaultPackExists()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ContentPack.self, from: data)
    }

    func ensureDefaultPackExists() throws -> URL {
        let fileManager = FileManager.default
        let directory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = directory.appendingPathComponent(fileName)
        if !fileManager.fileExists(atPath: url.path) {
            let data = Data(defaultPackJSON.utf8)
            try data.write(to: url, options: [.atomic])
        }
        return url
    }

    private var defaultPackJSON: String {
        """
        {
          "id": "solo_default",
          "version": "0.1",
          "tables": [
            {
              "id": "dungeon_start",
              "name": "Dungeon Start",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "spawnNode", "nodeType": "room", "summary": "Rough-hewn entry chamber", "tags": ["entry"] } ] },
                { "min": 3, "max": 4, "actions": [ { "type": "spawnNode", "nodeType": "passage", "summary": "Narrow corridor leading inward", "tags": ["entry"] } ] },
                { "min": 5, "max": 6, "actions": [ { "type": "spawnNode", "nodeType": "room", "summary": "Stairs descend into darkness", "tags": ["entry", "stairs"] } ] }
              ]
            },
            {
              "id": "room_shape",
              "name": "Room Shape",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "log", "message": "The room is square with rough stone walls." } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "The room is circular with a high ceiling." } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "The room is long and rectangular with alcoves." } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "The room is irregular, carved by age and water." } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "The room is segmented with low partitions." } ] }
              ]
            },
            {
              "id": "passage_features",
              "name": "Passage Features",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "log", "message": "A damp draft chills the corridor." } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "Footprints are visible in the dust." } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "Faint chanting echoes from ahead." } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "Moss and water streak the stone." } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "A side alcove hides a broken crate." } ] }
              ]
            },
            {
              "id": "door_properties",
              "name": "Door Properties",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "spawnEdge", "edgeType": "door", "summary": "A sturdy wooden door with iron bands.", "tags": ["door", "wood"] } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "spawnEdge", "edgeType": "door", "summary": "A stone door etched with simple runes.", "tags": ["door", "stone"] } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "spawnEdge", "edgeType": "door", "summary": "A warped metal door hanging ajar.", "tags": ["door", "metal"] } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "spawnEdge", "edgeType": "door", "summary": "A locked door with a complex mechanism.", "tags": ["door", "locked"] } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "spawnEdge", "edgeType": "door", "summary": "A door marked with warning sigils.", "tags": ["door", "warded"] } ] }
              ]
            },
            {
              "id": "stairs_properties",
              "name": "Stairs",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "spawnEdge", "edgeType": "stairs", "summary": "Narrow stairs descending into shadow.", "tags": ["stairs", "down"] } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "spawnEdge", "edgeType": "stairs", "summary": "Broad stairs rising to a landing.", "tags": ["stairs", "up"] } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "spawnEdge", "edgeType": "stairs", "summary": "Spiral stairs slick with moisture.", "tags": ["stairs", "down"] } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "spawnEdge", "edgeType": "stairs", "summary": "Broken steps with a gap to jump.", "tags": ["stairs", "hazard"] } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "spawnEdge", "edgeType": "stairs", "summary": "A ladder well with iron rungs.", "tags": ["stairs", "ladder"] } ] }
              ]
            },
            {
              "id": "trap_variants",
              "name": "Trap Variants",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "spawnTrap", "category": "mechanical", "trigger": "floor plate", "detectionSkill": "Investigation", "detectionDC": 13, "disarmSkill": "Thieves' Tools", "disarmDC": 14, "saveSkill": "Acrobatics", "saveDC": 14, "effect": "A dart fires from the wall." } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "spawnTrap", "category": "mechanical", "trigger": "tripwire", "detectionSkill": "Perception", "detectionDC": 12, "disarmSkill": "Thieves' Tools", "disarmDC": 13, "saveSkill": "Acrobatics", "saveDC": 13, "effect": "A scything blade sweeps the corridor." } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "spawnTrap", "category": "alchemical", "trigger": "tampered chest", "detectionSkill": "Investigation", "detectionDC": 14, "disarmSkill": "Thieves' Tools", "disarmDC": 15, "saveSkill": "Acrobatics", "saveDC": 14, "effect": "A burst of acidic vapor fills the space." } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "spawnTrap", "category": "arcane", "trigger": "rune circle", "detectionSkill": "Arcana", "detectionDC": 15, "disarmSkill": "Arcana", "disarmDC": 15, "saveSkill": "Arcana", "saveDC": 15, "effect": "A pulse of force knocks intruders back." } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "spawnTrap", "category": "mechanical", "trigger": "loose step", "detectionSkill": "Perception", "detectionDC": 12, "disarmSkill": "Thieves' Tools", "disarmDC": 12, "saveSkill": "Athletics", "saveDC": 13, "effect": "The floor tilts, dumping you into a pit." } ] }
              ]
            },
            {
              "id": "room_contents",
              "name": "Room Contents",
              "scope": "dungeon",
              "diceSpec": "d10",
              "entries": [
                { "min": 1, "max": 4, "actions": [ { "type": "log", "message": "The room is quiet and empty." } ] },
                { "min": 5, "max": 6, "actions": [ { "type": "rollOnTable", "tableId": "trap_variants" } ] },
                { "min": 7, "max": 8, "actions": [ { "type": "log", "message": "You notice signs of prior activity." } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "A subtle clue is left behind." } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "rollOnTable", "tableId": "encounter_seed" } ] }
              ]
            },
            {
              "id": "encounter_seed",
              "name": "Encounter Seed",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "log", "message": "A nervous scout withdraws into the dark." } ] },
                { "min": 3, "max": 4, "actions": [ { "type": "log", "message": "You hear distant movement, then silence." } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "A rival explorer crosses your path." } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "Something stirs ahead, ready to ambush." } ] }
              ]
            }
          ]
        }
        """
    }
}
