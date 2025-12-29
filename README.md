# Foundation Models Framework Example

## Requirements

- iOS 26.0+ or macOS 26.0+ (Xcode 26.0+)
- **Xcode 26 official is required**
- Apple Intelligence enabled
- Compatible Apple device with Apple Silicon

## Getting Started

- Clone the repository
- Open `FoundationLab.xcodeproj` in Xcode
- Ensure you have a device with Apple Intelligence enabled
- Build and run the project
- (Optional) For web search functionality:
  - Get an API key from [Exa AI](https://exa.ai)
  - Tap the gear icon in the app to access Settings
  - Enter your Exa API key in the settings screen
- Explore the different capabilities through the examples!

## What's Inside

The app has four main sections:

### Chat
Multi-turn conversations with context management, streaming responses, and a feedback system. Includes automatic context window management with session summarization when needed.

### Tools
Nine system integration tools that extend the model's capabilities:
- **Weather** - Current weather for any location (OpenMeteo API)
- **Web Search** - Real-time search via Exa AI (requires API key)
- **Contacts** - Search and access system contacts
- **Calendar** - Create and manage calendar events
- **Reminders** - AI-assisted reminder creation with priority levels
- **Location** - Current location and geocoding
- **Health** - HealthKit integration for health data queries
- **Music** - Apple Music search (requires subscription)
- **Web Metadata** - Extract metadata and generate social media summaries

### Voice Interface
Talk to the model using speech:
- Voice-to-text with real-time transcription
- Text-to-speech responses
- Create reminders by voice
- Audio-reactive visualization
- Handles all permissions automatically

### Health Dashboard
AI-powered health tracking with HealthKit:
- Personal health coach with contextual insights
- Trend analysis and correlations
- Predictive analytics
- Weekly summaries and personalized health plans
- Multiple health metrics tracking

### Integrations Hub
Three sections for exploring advanced features:
- **Tools** - All nine system integration examples
- **Schemas** - Dynamic schema examples from basic to expert level
- **Languages** - Multilingual features and language detection

### Examples
Nine different example types showing framework capabilities:
- One-shot prompts
- Business idea generation
- Creative writing
- Structured data generation
- Streaming responses
- Model availability checking
- Generation guides
- Generation options (temperature, tokens, fitness)
- Health dashboard

## Solo RPG Tool Additions

This repo includes a solo roleplaying system built on top of the on-device model. It is split into two layers:
- **Campaign engine** (non-AI): state, randomness, persistence, and rules logic.
- **Narrator** (on-device model): interpretation, conversation, and narration only.

### Data Structure Overview
- **Campaign**: scenes, characters, threads, chaos factor, party, and RNG state.
- **Locations**: persistent location graphs with nodes, edges, and traps.
- **Interactive challenges**: skill checks, traps, and fate-style questions, each stored as records.
- **Table engine**: JSON-defined tables with deterministic rolls and action scripts.
- **Event logs**: stored roll results and entity changes so sessions can be replayed.
- **SRD conditions**: condition list and details parsed and available in SRD Library + character sheet pickers.

### Modules in the App
- **Solo Scenes**: the main scene loop and conversation interface.
- **Campaign Data**: browse saved campaign structures and generated entities.
- **Tables**: edit the JSON tables stored on device.
- **NPCs**: generate and edit NPCs with expandable details.
- **World Lore**: store persistent setting facts and campaign setup.
- **Character Sheet**: living sheet with unknown/provisional/confirmed fields.

### Expansion Progress
Current stage: persistent locations, scene chat loop, skill checks, and content pack tables are live. Movement intent parsing is active (with exit label matching). NPCs, world lore, and character sheets are implemented as separate modules. Markdown table import (paste or file) is now available in Tables (log-only actions by default). Location navigation now exposes exits for deterministic traversal and reuse, and narrator context includes current exits.
Dev tooling: optional DEV_FIXTURES build flag adds a developer test runner with scripted scenarios and a quick smoke test. A local-only supplemental rules data loader can merge extra data at build time when enabled (not included in release builds).
SRD integration: structured item and creature records are parsed for engine use (equipment/magic items and monsters/creatures) and surfaced in SRD detail views and inventory pickers.
Content tables: travel/exploration/encounter tables are now bundled in `rpg_tables.json` for TableEngine use.
Encounter pacing + travel/exploration hooks: the engine can now roll encounter checks, travel events, and exploration features from the bundled tables.
Loot selection: magic item rarity logic uses SRD item lists (no separate treasure tables).
Social/encounter seeding: NPC reactions can update attitudes and travel events can seed encounter entities on the current node.

Work-in-progress task list (engine expansion):
- **Architecture**: define module boundaries (engine, narrator, world state, tables) and plan a Swift package split without breaking current UI.
- **Tables**: finish markdown/JSON import pipeline, validate ranges, and add import UI for custom tables. (Import UI added; wiring to action scripts still in progress.)
- **World state**: harden location graph continuity (no duplicate nodes on revisit; now reuses existing nodes and exposes exits), add region/settlement layers.
- **Tables**: edge labels now come from a dedicated dungeon edge table for more descriptive exits.
- **Persistence**: versioned migrations and safe backups for campaign data.
- **Narrator**: stricter tool-based contract (engine decides outcomes, narrator only interprets).
- **Scene control**: end-of-scene detection and next-scene drafting based on last action.
- **UI**: add a lightweight pending-check reminder chip in the scene view (non-blocking).
- **Scene flow**: reinforce pending-check reminders when the player asks unrelated questions mid-check.
- **Skill checks**: contested checks, passive checks, and check-to-oracle modifiers.
- **Encounters**: encounter clocks and repeatable encounter state.
- **Campaign tools**: import/export, duplicate campaigns, and per-campaign rulesets.
- **Character mechanics**: proficiency bonus by level, saves, skills, and level progression tracking.

### SRD Mechanics Roadmap (Outline)
This is the mechanical task list for bringing the engine up to SRD parity. The narrator should only render outcomes supplied by these systems.
- **Ruleset ingestion**: parse SRD abilities, skills, species, classes, feats, spells, and equipment into structured models with stable IDs.
- **Character mechanics**: proficiency bonus by level, ability modifiers, saving throws, skill proficiency, class features, and level progression.
- **Combat system**: initiative, turn order, action economy, attack resolution, damage types, conditions, death saves, and recovery.
- **Spellcasting**: slots/points, prepared vs known, casting time, range/area, concentration, and component requirements.
- **Equipment & inventory**: armor/shield AC, weapon properties, damage dice, encumbrance, and item tags. (Structured item records + inventory picker done.)
- **Creatures/monsters**: CR/XP, resistances/immunities, and special actions. (Structured statblock parsing + SRD detail views done.)
- **Rest & recovery**: short/long rest rules, resource recovery, and condition clearing.
- **Exploration & travel**: movement pace, vision/light, stealth/surprise logic, and hazards.
- **Encounter pacing**: difficulty estimation and activity clocks tied to party size/level.

Known gaps that will need dedicated tables or research:
- **Shop availability**: market checks and item sourcing logic per settlement size.
- **Downtime activities**: structured options and consequences.
- **Environmental hazards**: regional/weather hazard tables and effects.

### Module Split Plan (Draft)
Goal: separate engine and narrator concerns while keeping the current UI intact.
- **WorldState**: data models + persistence helpers (Campaign, Locations, NPCs, Character sheet).
- **TableEngine**: table execution, dice, seeded RNG, table import utilities.
- **RPGEngine**: scene logic, chaos/fate checks, skill checks, location traversal.
- **NarratorAgent**: prompt assembly, intent routing, and AI response orchestration.
- **AppUI**: SwiftUI views that call into the engines.
Dependency rule: WorldState + TableEngine at the base; RPGEngine depends on them; NarratorAgent depends on RPGEngine; AppUI depends on all.

### Module Split Plan (Detailed)
Aligned with the engine/narrator separation in `info/Solo_RPG_Engine_Expansion_Guide.md`.

**WorldState (base layer)**
- `Foundation Lab/Models/Solo/CampaignModels.swift`
- `Foundation Lab/Models/Solo/LocationModels.swift`
- `Foundation Lab/Models/Solo/NpcModels.swift`
- `Foundation Lab/Models/Solo/CharacterModels.swift`
- `Foundation Lab/Models/Solo/WorldLoreModels.swift`
- `Foundation Lab/Models/Solo/PartyModels.swift`
- Persistence helpers (future): `WorldStateStore.swift`

**TableEngine (base layer)**
- `Foundation Lab/Models/Solo/TableEngine.swift`
- `Foundation Lab/Models/Solo/TableImporter.swift`
- `Foundation Lab/Models/Solo/ContentPackStore.swift`

**RPGEngine (logic layer)**
- `Foundation Lab/Models/Solo/SkillCheckModels.swift`
- `Foundation Lab/Models/Solo/Ruleset.swift`
- `Foundation Lab/Models/Solo/LocationEngine.swift`
- `Foundation Lab/Models/Solo/NpcEngine.swift`
- `Foundation Lab/Models/Solo/SoloEngine.swift`

**NarratorAgent (AI orchestration)**
- `Foundation Lab/Models/Solo/NarrationContext.swift`
- `Foundation Lab/Models/Solo/NarrationPrompts.swift`
- Intent parsing + GM response helpers currently inside `Foundation Lab/Views/Examples/SoloScenesView.swift` (to extract later).

**AppUI (SwiftUI)**
- `Foundation Lab/Views/Examples/SoloScenesView.swift`
- `Foundation Lab/Views/Examples/NPCsView.swift`
- `Foundation Lab/Views/Examples/WorldLoreView.swift`
- `Foundation Lab/Views/Examples/CharacterSheetView.swift`
- `Foundation Lab/Views/Examples/CampaignDataView.swift`
- `Foundation Lab/Views/Examples/TablesView.swift`
- `Foundation Lab/Views/SettingsView.swift`

**Split sequence**
1) Create Swift packages with empty targets and shared types.
2) Move base models (WorldState) first, then TableEngine.
3) Move RPGEngine logic next (LocationEngine, SoloEngine, skill checks).
4) Extract NarratorAgent helpers from SoloScenesView.
5) Update imports in AppUI.

Status: Step 1 complete (package scaffolding added under `Packages/`). Step 2 complete (TableEngine + WorldState sources moved into packages and imported). Step 3 in progress (RPGEngine sources moved into package and imported). Step 4 started (NarratorAgent prompt scaffolding added).

### Planned Features
- Wilderness and settlement generation (travel segments, districts, rumors).
- Encounter clocks for pacing area activity.
- Multi-step skill challenges.
- Table content packs with import/export and versioning.
- Shop availability checks: track when the party is searching for a specific item and roll availability in a shop using SRD-style rarity/market logic.
- Expanded editing tools for all campaign entities.

## Features

### Core Capabilities
- **Chat**: Multi-turn conversations with context management
- **Streaming**: Real-time response streaming
- **Structured Generation**: Type-safe data with `@Generable`
- **Generation Guides**: Constrained outputs with `@Guide`
- **Tool Calling**: System integrations for extended functionality
- **Voice**: Speech-to-text and text-to-speech
- **Health**: HealthKit integration with AI insights
- **Multilingual**: Works in 10 languages (English, German, Spanish, French, Italian, Japanese, Korean, Portuguese, Chinese)

### Dynamic Schemas
The app includes 11 dynamic schema examples ranging from basic to expert:
- Basic schemas
- Arrays and collections
- Enums and union types
- Nested objects
- Schema references
- Form builders
- Invoice processing
- Error handling patterns

### Playground Examples
Four chapters with hands-on examples:
- **Chapter 2**: Getting Started with Sessions (16 examples)
- **Chapter 3**: Generation Options and Sampling Control (5 examples)
- **Chapter 8**: Basic Tool Use (9 examples)
- **Chapter 13**: Languages and Internationalization (7 examples)

Run these directly in Xcode using the `#Playground` directive.

## Usage Examples

### Basic Chat
```swift
let session = LanguageModelSession()
let response = try await session.respond(
    to: "Suggest a catchy name for a new coffee shop."
)
print(response.content)
```

### Structured Data Generation
```swift
let session = LanguageModelSession()
let bookInfo = try await session.respond(
    to: "Suggest a sci-fi book.",
    generating: BookRecommendation.self
)
print("Title: \(bookInfo.content.title)")
print("Author: \(bookInfo.content.author)")
```

### Tool Calling
```swift
// Single tool
let weatherSession = LanguageModelSession(tools: [WeatherTool()])
let response = try await weatherSession.respond(
    to: "Is it hotter in New Delhi or Cupertino?"
)

// Multiple tools
let multiSession = LanguageModelSession(tools: [
    WeatherTool(),
    WebTool(),
    ContactsTool()
])
let multiResponse = try await multiSession.respond(
    to: "Check the weather and find my friend John's contact"
)
```

### Streaming Responses
```swift
let session = LanguageModelSession()
let stream = session.streamResponse(to: "Write a short poem about technology.")

for try await partialText in stream {
    print("Partial: \(partialText)")
}
```

### Voice Interface
```swift
// Speech recognition
let recognizer = SpeechRecognizer()
await recognizer.startRecording()

// Text-to-speech
let synthesizer = SpeechSynthesizer()
synthesizer.speak("Hello, how can I help you?")
```

### Health Data
```swift
let session = LanguageModelSession(tools: [HealthDataTool()])
let response = try await session.respond(
    to: "Show me my step count trends this week"
)
```

## Data Models

The app includes various `@Generable` data models for different use cases:

### General Purpose
```swift
@Generable
struct BookRecommendation {
    @Guide(description: "The title of the book")
    let title: String

    @Guide(description: "The author's name")
    let author: String

    @Guide(description: "Genre of the book")
    let genre: Genre
}

@Generable
struct ProductReview {
    @Guide(description: "Product name")
    let productName: String

    @Guide(description: "Rating from 1 to 5")
    let rating: Int

    @Guide(description: "Key pros and cons")
    let pros: [String]
    let cons: [String]
}

@Generable
struct StoryOutline {
    let title: String
    let protagonist: String
    let conflict: String
    let setting: String
    let genre: StoryGenre
    let themes: [String]
}

@Generable
struct BusinessIdea {
    let name: String
    let description: String
    let targetMarket: String
    let revenueModel: String
    let advantages: [String]
    let estimatedStartupCost: String
    let timeline: String
}
```

### Health Models
```swift
@Generable
struct HealthAI {
    let greeting: String
    let mood: HealthAIMood
    let motivationalMessage: String
    let focusMetrics: [String]
    let suggestions: [String]
}

@Generable
struct HealthAnalysis {
    let healthScore: Int
    let trends: HealthTrends
    let insights: [HealthInsightDetail]
    let correlations: [MetricCorrelation]
    let predictions: [HealthPrediction]
    let recommendations: [String]
}

@Generable
struct PersonalizedHealthPlan {
    let title: String
    let overview: String
    let currentStatus: String
    let weeklyActivities: [String]
    let nutritionGuidelines: NutritionPlan
    let sleepStrategy: String
    let milestones: [String]
}
```

### Chat Context
```swift
@Generable
struct ConversationSummary {
    let summary: String
    let keyTopics: [String]
    let userPreferences: [String]
}
```

## Tools Details

### Weather Tool
- Uses OpenMeteo API for real-time weather
- Temperature, humidity, wind speed, conditions
- Automatic geocoding
- No API key required

### Web Search Tool
- Real-time search via Exa AI
- Returns text content from pages
- Requires API key from [Exa AI](https://exa.ai)
- Configure in Settings

### Contacts Tool
- Search system contacts
- Natural language queries
- Requires contacts permission

### Calendar Tool
- Create and manage events
- Timezone and locale aware
- Supports relative dates ("today", "tomorrow")
- Requires calendar permission

### Reminders Tool
- Create reminders with AI
- Priority levels: None, Low, Medium, High
- Due dates and notes
- Requires reminders permission

### Location Tool
- Current location information
- Geocoding support
- Requires location permission

### Health Tool
- HealthKit integration
- Query health metrics
- AI-powered insights
- Requires HealthKit permission

### Music Tool
- Apple Music search
- Songs, artists, albums
- Requires Apple Music subscription
- Requires music permission

### Web Metadata Tool
- Extract webpage metadata
- Generate social media summaries
- Platform-specific formatting
- No API key required

## Multilingual Support

The app works in 10 languages:
- English
- German
- Spanish
- French
- Italian
- Japanese
- Korean
- Portuguese (Brazil)
- Chinese (Simplified)
- Chinese (Traditional)

Language detection and code-switching examples are included in the Integrations section.

## Permissions

The app may request the following permissions depending on which features you use:
- Microphone (for voice input)
- Speech Recognition
- Contacts
- Calendar
- Reminders
- Location
- HealthKit
- Apple Music

All permissions are requested at the appropriate time and can be managed in Settings.

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
