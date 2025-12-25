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
              "id": "dungeon_next_node",
              "name": "Dungeon Next Node",
              "scope": "dungeon",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 3, "actions": [ { "type": "spawnNode", "nodeType": "room", "summary": "Stone chamber beyond", "tags": ["room"] } ] },
                { "min": 4, "max": 5, "actions": [ { "type": "spawnNode", "nodeType": "passage", "summary": "Narrow passage extending ahead", "tags": ["passage"] } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "spawnNode", "nodeType": "room", "summary": "Small annex with low ceiling", "tags": ["room"] } ] }
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
            },
            {
              "id": "npc_species",
              "name": "NPC Species",
              "scope": "npc",
              "diceSpec": "d10",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "human" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "elf" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "dwarf" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "halfling" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "gnome" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "orc" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "half-elf" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "half-orc" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "dragonborn" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "goblin" } ] }
              ]
            },
            {
              "id": "npc_role",
              "name": "NPC Role",
              "scope": "npc",
              "diceSpec": "d12",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "cook" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "guard captain" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "wandering druid" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "merchant" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "scout" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "scholar" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "healer" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "artisan" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "smuggler" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "sailor" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "priest" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "ranger" } ] }
              ]
            },
            {
              "id": "npc_name_core",
              "name": "NPC Name Core",
              "scope": "npc",
              "diceSpec": "d12",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "Ar" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "Bel" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "Cor" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "Del" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "Eli" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "Fen" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "Gal" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "Har" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "Iri" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "Jor" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "Kael" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "Mira" } ] }
              ]
            },
            {
              "id": "npc_name_style",
              "name": "NPC Name Style",
              "scope": "npc",
              "diceSpec": "d6",
              "entries": [
                { "min": 1, "max": 2, "actions": [ { "type": "log", "message": "masc" } ] },
                { "min": 3, "max": 4, "actions": [ { "type": "log", "message": "femme" } ] },
                { "min": 5, "max": 6, "actions": [ { "type": "log", "message": "nb" } ] }
              ]
            },
            {
              "id": "npc_name_suffix_masc",
              "name": "NPC Name Suffix (Masc)",
              "scope": "npc",
              "diceSpec": "d8",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "an" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "or" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "en" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "ric" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "th" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "mar" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "drin" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "vek" } ] }
              ]
            },
            {
              "id": "npc_name_suffix_femme",
              "name": "NPC Name Suffix (Femme)",
              "scope": "npc",
              "diceSpec": "d8",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "a" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "elle" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "ira" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "wyn" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "eth" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "lyn" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "ara" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "is" } ] }
              ]
            },
            {
              "id": "npc_name_suffix_nb",
              "name": "NPC Name Suffix (NB)",
              "scope": "npc",
              "diceSpec": "d8",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "en" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "is" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "rin" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "iv" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "ash" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "el" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "ai" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "on" } ] }
              ]
            },
            {
              "id": "npc_notable_feature",
              "name": "NPC Notable Feature",
              "scope": "npc",
              "diceSpec": "d20",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "a scar across the cheek" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "bright, watchful eyes" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "a braided beard or mane" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "a weathered cloak" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "a silver nose ring" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "ink-stained fingertips" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "a missing tooth" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "a distinctive tattoo" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "a limp from an old injury" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "a polished walking staff" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "a rasping voice" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "a heavy scent of incense" } ] },
                { "min": 13, "max": 13, "actions": [ { "type": "log", "message": "a bright sash of office" } ] },
                { "min": 14, "max": 14, "actions": [ { "type": "log", "message": "calloused hands" } ] },
                { "min": 15, "max": 15, "actions": [ { "type": "log", "message": "a crooked smile" } ] },
                { "min": 16, "max": 16, "actions": [ { "type": "log", "message": "a ritual pendant" } ] },
                { "min": 17, "max": 17, "actions": [ { "type": "log", "message": "sunburned skin" } ] },
                { "min": 18, "max": 18, "actions": [ { "type": "log", "message": "an oversized hat" } ] },
                { "min": 19, "max": 19, "actions": [ { "type": "log", "message": "a chipped blade at the belt" } ] },
                { "min": 20, "max": 20, "actions": [ { "type": "log", "message": "a striking birthmark" } ] }
              ]
            },
            {
              "id": "npc_quirk",
              "name": "NPC Quirk",
              "scope": "npc",
              "diceSpec": "d20",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "hums when thinking" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "collects buttons" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "speaks in short phrases" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "obsesses over clean hands" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "always carries a small notebook" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "chews on a straw of grass" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "laughs at their own jokes" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "constantly scans exits" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "keeps coins stacked by size" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "taps a ring while speaking" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "avoids eye contact" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "gives people nicknames" } ] },
                { "min": 13, "max": 13, "actions": [ { "type": "log", "message": "keeps a lucky charm in hand" } ] },
                { "min": 14, "max": 14, "actions": [ { "type": "log", "message": "counts under their breath" } ] },
                { "min": 15, "max": 15, "actions": [ { "type": "log", "message": "refuses to sit with their back exposed" } ] },
                { "min": 16, "max": 16, "actions": [ { "type": "log", "message": "squints as if reading invisible text" } ] },
                { "min": 17, "max": 17, "actions": [ { "type": "log", "message": "always smells of smoke" } ] },
                { "min": 18, "max": 18, "actions": [ { "type": "log", "message": "insists on precise measurements" } ] },
                { "min": 19, "max": 19, "actions": [ { "type": "log", "message": "keeps a pet insect in a vial" } ] },
                { "min": 20, "max": 20, "actions": [ { "type": "log", "message": "never raises their voice" } ] }
              ]
            },
            {
              "id": "npc_flaw",
              "name": "NPC Flaw",
              "scope": "npc",
              "diceSpec": "d20",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "quick to anger" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "overly proud" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "greedy and impatient" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "easily frightened" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "holds grudges" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "bad at keeping secrets" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "too trusting" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "impulsive" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "suspicious of outsiders" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "easily distracted" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "craves attention" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "stubborn to a fault" } ] },
                { "min": 13, "max": 13, "actions": [ { "type": "log", "message": "fearful of authority" } ] },
                { "min": 14, "max": 14, "actions": [ { "type": "log", "message": "liable to panic under pressure" } ] },
                { "min": 15, "max": 15, "actions": [ { "type": "log", "message": "treats rumors as facts" } ] },
                { "min": 16, "max": 16, "actions": [ { "type": "log", "message": "avoids responsibility" } ] },
                { "min": 17, "max": 17, "actions": [ { "type": "log", "message": "resentful of success in others" } ] },
                { "min": 18, "max": 18, "actions": [ { "type": "log", "message": "slow to forgive" } ] },
                { "min": 19, "max": 19, "actions": [ { "type": "log", "message": "always expects betrayal" } ] },
                { "min": 20, "max": 20, "actions": [ { "type": "log", "message": "reckless with safety" } ] }
              ]
            },
            {
              "id": "npc_goal",
              "name": "NPC Goal",
              "scope": "npc",
              "diceSpec": "d20",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "recover a lost item" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "protect a loved one" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "secure safe passage" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "gain favor with a local leader" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "prove their worth" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "settle a debt" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "hide a personal secret" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "escort someone to safety" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "map an unknown place" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "repair a damaged reputation" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "obtain rare supplies" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "buy time for an ally" } ] },
                { "min": 13, "max": 13, "actions": [ { "type": "log", "message": "avoid a looming threat" } ] },
                { "min": 14, "max": 14, "actions": [ { "type": "log", "message": "teach someone a lesson" } ] },
                { "min": 15, "max": 15, "actions": [ { "type": "log", "message": "find a missing friend" } ] },
                { "min": 16, "max": 16, "actions": [ { "type": "log", "message": "recover a family heirloom" } ] },
                { "min": 17, "max": 17, "actions": [ { "type": "log", "message": "secure shelter for the night" } ] },
                { "min": 18, "max": 18, "actions": [ { "type": "log", "message": "learn a forbidden truth" } ] },
                { "min": 19, "max": 19, "actions": [ { "type": "log", "message": "recruit allies" } ] },
                { "min": 20, "max": 20, "actions": [ { "type": "log", "message": "keep an oath intact" } ] }
              ]
            },
            {
              "id": "npc_life_event",
              "name": "NPC Life Event",
              "scope": "npc",
              "diceSpec": "d12",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "survived a fire that destroyed their home" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "served in a distant conflict" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "apprenticed under a demanding mentor" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "escaped a failed expedition" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "lost someone important in a storm" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "found a relic they cannot explain" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "made a promise to a dying friend" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "was framed for a crime" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "survived a near-fatal illness" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "stole something powerful by accident" } ] },
                { "min": 11, "max": 11, "actions": [ { "type": "log", "message": "helped build a local landmark" } ] },
                { "min": 12, "max": 12, "actions": [ { "type": "log", "message": "betrayed someone and regrets it" } ] }
              ]
            },
            {
              "id": "npc_mood",
              "name": "NPC Mood",
              "scope": "npc",
              "diceSpec": "d10",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "guarded" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "jovial" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "spooked" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "weary" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "curious" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "suspicious" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "hopeful" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "irritable" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "eager" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "cautious" } ] }
              ]
            },
            {
              "id": "npc_voice",
              "name": "NPC Voice",
              "scope": "npc",
              "diceSpec": "d10",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "soft and measured" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "raspy and low" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "bright and quick" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "gravelly with long pauses" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "clipped and formal" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "warm and reassuring" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "nasal and fast" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "breathy and quiet" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "flat and emotionless" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "booming and theatrical" } ] }
              ]
            },
            {
              "id": "npc_mannerism",
              "name": "NPC Mannerism",
              "scope": "npc",
              "diceSpec": "d10",
              "entries": [
                { "min": 1, "max": 1, "actions": [ { "type": "log", "message": "taps their foot while listening" } ] },
                { "min": 2, "max": 2, "actions": [ { "type": "log", "message": "avoids direct eye contact" } ] },
                { "min": 3, "max": 3, "actions": [ { "type": "log", "message": "keeps hands folded at all times" } ] },
                { "min": 4, "max": 4, "actions": [ { "type": "log", "message": "traces symbols in the air" } ] },
                { "min": 5, "max": 5, "actions": [ { "type": "log", "message": "gestures widely when excited" } ] },
                { "min": 6, "max": 6, "actions": [ { "type": "log", "message": "pauses to choose words carefully" } ] },
                { "min": 7, "max": 7, "actions": [ { "type": "log", "message": "leans in to whisper" } ] },
                { "min": 8, "max": 8, "actions": [ { "type": "log", "message": "checks over their shoulder often" } ] },
                { "min": 9, "max": 9, "actions": [ { "type": "log", "message": "counts on their fingers" } ] },
                { "min": 10, "max": 10, "actions": [ { "type": "log", "message": "runs a thumb along a scar" } ] }
              ]
            }
          ]
        }
        """
    }
}
