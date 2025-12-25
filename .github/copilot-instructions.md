# AI Coding Agent Instructions for Foundation Lab

## Project Overview
Foundation Lab is an iOS/macOS SwiftUI app demonstrating Apple's Foundation Models framework. It combines AI-powered chat conversations with tabletop RPG tools (Mythic GM Emulator), featuring multi-turn context management, tool calling for system integrations, voice interfaces, and health tracking.

## Architecture & Key Components

### Core AI Framework Integration
- **Foundation Models**: Uses `LanguageModelSession` for AI conversations with streaming responses
- **Context Management**: Implements sliding window technique with automatic summarization when context limits are approached
- **Tool Calling**: Extends AI capabilities through custom `Tool` protocol implementations for system integrations

### Major Service Boundaries
- **Chat System** (`ChatViewModel`): Manages conversation sessions, generation options, and context window
- **Health Integration** (`HealthDataManager`, `HealthDataTool`): HealthKit data fetching and AI-powered insights
- **RPG Engine** (`MythicEngine`, `MythicCampaignEngine`): Tabletop RPG scene generation and campaign management
- **Voice System** (`VoiceViewModel`): Speech recognition/synthesis with real-time transcription
- **Tools Ecosystem**: 9 system integration tools (Weather, Web Search, Contacts, Calendar, Reminders, Location, Health, Music, Web Metadata)

## Critical Developer Workflows

### Building & Running
- Open `FoundationLab.xcodeproj` in Xcode 26.0+
- Requires iOS 26.0+/macOS 15.6+ with Apple Intelligence enabled
- Build target: `Foundation Lab` scheme
- Playgrounds run via `#Playground` directive in Xcode's playground editor

### Testing AI Features
- AI availability checked in `FoundationLabApp.checkModelAvailability()`
- Use `SystemLanguageModel.default.availability` to verify Apple Intelligence status
- Test on physical Apple Silicon devices (simulators lack AI support)

### Debugging Context Management
- Monitor `session.transcript.estimatedTokenCount` for context window usage
- Sliding window triggers at `AppConfiguration.TokenManagement.windowThreshold` (80%)
- Automatic summarization creates new sessions with `ConversationSummary` when limits exceeded

## Project-Specific Patterns & Conventions

### AI Schema Generation
Use `@Generable` structs with `@Guide` properties for type-safe AI responses:
```swift
@Generable
struct BookRecommendation {
    @Guide(description: "The title of the book")
    let title: String
    
    @Guide(description: "The author's name")
    let author: String
}
```

### Tool Implementation
Tools follow this pattern in `Foundation Lab/Tools/` or `Foundation Lab/Health/Tools/`:
```swift
struct WeatherTool: Tool {
    let name = "fetchWeather"
    let description = "Get current weather conditions"
    
    @Generable
    struct Arguments {
        @Guide(description: "City name or location")
        var location: String
    }
    
    func call(arguments: Arguments) async throws -> some PromptRepresentable {
        // Implementation returns GeneratedContent
    }
}
```

### ViewModel Architecture
- Use `@Observable` classes for SwiftUI state management
- Separate business logic from UI in dedicated ViewModels
- Handle async operations with `@MainActor` for UI updates

### Error Handling
- Custom `FoundationModelsError` types for AI-specific errors
- `FoundationModelsErrorHandler` provides user-friendly error messages
- Graceful fallbacks for context window exceeded scenarios

### Data Persistence
- SwiftData models stored in `modelContainer` (see `FoundationLabApp`)
- Key entities: `HealthMetric`, `HealthInsight`, `Campaign`, `SceneEntry`, etc.
- Automatic schema migration handled by SwiftData

## Integration Points & Dependencies

### External APIs
- **OpenMeteo**: Weather data (no API key required)
- **Exa AI**: Web search (requires API key in Settings)
- **HealthKit**: Health data (requires user permission)
- **Apple Music**: Music search (requires subscription + permission)

### System Permissions
Auto-requested permissions: Microphone, Speech Recognition, Contacts, Calendar, Reminders, Location, HealthKit, Apple Music

### Multilingual Support
App supports 10 languages with automatic language detection. Language-specific examples in `Playgrounds/13_SupportedLanguagesAndInternationalization/`

## Common Development Tasks

### Adding New AI Tools
1. Create tool struct conforming to `Tool` protocol
2. Define `@Generable Arguments` struct with `@Guide` descriptions
3. Implement `call()` method returning `GeneratedContent`
4. Add to tool arrays in relevant ViewModels
5. Create corresponding UI in `Views/Tools/`

### Extending Health Features
1. Add new `MetricType` cases in `Health/Models/`
2. Update `HealthDataManager` fetch methods
3. Extend `HealthDataTool` to handle new metrics
4. Add UI components in `Health/Views/`

### Adding RPG Features
1. Define data models in `Models/Mythic/`
2. Implement logic in `MythicEngine` or `MythicCampaignEngine`
3. Add SwiftData persistence if needed
4. Create UI in appropriate View directories

## Code Quality Standards

### SwiftLint Configuration
- Line length: 140 chars (warning), ignores comments/URLs
- Function body: 60 lines (warning), 100 (error)
- File length: 600 lines (warning), 800 (error)
- Type nesting: 3 levels (warning), 5 (error)

### Naming Conventions
- Use descriptive names following Swift API Design Guidelines
- Tool names should be action-oriented (e.g., `fetchWeather`, not `weather`)
- ViewModels named as `FeatureViewModel` (e.g., `ChatViewModel`)

## Testing & Validation

### AI Feature Testing
- Verify `SystemLanguageModel.default.availability == .available`
- Test streaming responses don't block UI
- Validate context window management with long conversations
- Check tool calling works across different argument types

### HealthKit Integration Testing
- Test permission flows on clean installs
- Verify data fetching from both HealthKit and SwiftData cache
- Validate metric calculations and formatting

### Voice Feature Testing
- Test speech recognition accuracy across languages
- Verify text-to-speech pronunciation
- Check permission handling for microphone/speech