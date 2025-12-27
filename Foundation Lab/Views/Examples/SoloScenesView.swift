import FoundationModels
import SwiftUI
import SwiftData
import WorldState
import RPGEngine
import TableEngine

struct SoloScenesView: View {
    private enum ScenePhase {
        case setup
        case resolved
        case bookkeeping
        case concluded
    }

    private enum AlteredMode: String, CaseIterable {
        case guided
        case manual
    }

    private struct ExitDisplay: Identifiable {
        let id: UUID
        let label: String
        let targetSummary: String
        let edge: LocationEdge
    }

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Campaign> { $0.isActive }) private var activeCampaigns: [Campaign]
    @State private var campaign: Campaign?
    // Engine and location engine are owned by the shared coordinator.
    @StateObject private var coordinator = SoloSceneCoordinator()
    @AppStorage("soloAlteredMode") private var alteredModeRaw = AlteredMode.guided.rawValue
    @AppStorage("soloAutoRollEnabled") private var autoRollEnabled = false
    @AppStorage("soloGMRunsCompanions") private var gmRunsCompanionsEnabled = false
    @State private var phase: ScenePhase = .setup
    @State private var sceneInput = ""
    @State private var currentScene: SceneRecord?
    @State private var editingScene: SceneEntry?

    @State private var selectedMethod: AlterationMethod?
    @State private var selectedAdjustment: SceneAdjustment = .raiseStakes

    @State private var newCharactersInput = ""
    @State private var newThreadsInput = ""
    @State private var featuredCharactersInput = ""
    @State private var featuredThreadsInput = ""
    @State private var removeCharactersInput = ""
    @State private var removeThreadsInput = ""
    @State private var placesInput = ""
    @State private var curiositiesInput = ""
    @State private var pcsInControl = true
    @State private var adventureConcluded = false
    @State private var sceneSummaryInput = ""
    @State private var isDraftingSummary = false
    @AppStorage("soloAutoDraftNextScene") private var autoDraftNextScene = false
    @State private var isDraftingNextScene = false
    @State private var nextSceneError: String?
    @AppStorage("soloShowLocationDebug") private var showLocationDebug = false

    @State private var narration = ""
    @State private var narrationError: String?
    @State private var isNarrating = false

    private var alteredMode: AlteredMode {
        AlteredMode(rawValue: alteredModeRaw) ?? .guided
    }

    @MainActor init(coordinator: SoloSceneCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection
                sceneSetupSection
                locationSection

                if let scene = currentScene {
                    sceneSummarySection(scene)

                    if scene.type == .altered {
                        alteredSceneSection(scene)
                    }

                    if scene.type == .interrupt {
                        interruptSceneSection(scene)
                    }

                    narrationSection(scene)
                    sceneConversationSection(scene)
                    playOutSection
                }

                if phase == .bookkeeping {
                    bookkeepingSection
                }

                if phase == .concluded {
                    conclusionSection
                }

                currentListsSection
                campaignJournalSection
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.large)
        }
        .textSelection(.enabled)
        .onAppear(perform: ensureCampaign)
        .navigationTitle("Solo Scenes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .navigationSubtitle("Resolve scenes with Apple Intelligence")
#endif
        .sheet(item: $editingScene) { scene in
            SceneEditorSheet(scene: scene)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("RESOLVING SCENES")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Use the solo GM loop to resolve scenes, track lists, and keep chaos moving.")
                .font(.callout)
                .foregroundColor(.secondary)

            Picker("Altered Scene Mode", selection: $alteredModeRaw) {
                Text("Guided default").tag(AlteredMode.guided.rawValue)
                Text("Manual choice").tag(AlteredMode.manual.rawValue)
            }
            .pickerStyle(.segmented)
        }
    }

    private var sceneSetupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("SCENE SETUP")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Scene #\(campaign?.sceneNumber ?? 1)")
                .font(.headline)

            if phase == .setup {
                TextEditor(text: $sceneInput)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.medium)
                    .frame(minHeight: 90)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(alignment: .topLeading) {
                        if sceneInput.isEmpty {
                            Text("Describe the expected scene...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                                .padding(.leading, 16)
                        }
                    }

                HStack(spacing: Spacing.small) {
                    Button(action: resolveScene) {
                        HStack(spacing: Spacing.small) {
                            Image(systemName: "dice")
                            Text("Resolve Scene")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.small)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(sceneInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || campaign == nil)

                    Button(action: { draftNextScenePrompt(previousEntry: nil) }) {
                        HStack(spacing: Spacing.small) {
                            if isDraftingNextScene {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isDraftingNextScene ? "Drafting..." : "Draft Next Scene")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.small)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isDraftingNextScene || campaign == nil)
                }

                Toggle("Auto-draft next scene prompt", isOn: $autoDraftNextScene)
                    .font(.callout)

                if let error = nextSceneError {
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Scene setup is locked for the current scene.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func sceneSummarySection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("SCENE SUMMARY")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Expected: \(scene.expectedScene)")
                .font(.callout)

            HStack {
                Text("Roll: \(scene.roll)")
                Spacer()
                Text("CF: \(scene.chaosFactor)")
                Spacer()
                Text("Type: \(scene.type.title)")
            }
            .font(.callout)

            if let method = scene.alterationMethod {
                Text("Alteration: \(method.label)")
                    .font(.callout)
            }

            if let detail = scene.alterationDetail {
                Text("Detail: \(detail)")
                    .font(.callout)
            }

            if let event = scene.randomEvent {
                Text("Interrupt Focus: \(event.focus.rawValue)")
                    .font(.callout)
                Text("Meaning Words: \(event.meaningWords.first) / \(event.meaningWords.second)")
                    .font(.callout)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func alteredSceneSection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("ALTERED SCENE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("The Scene is Altered. Go with the next most likely idea OR choose an alteration method.")
                .font(.callout)

            if alteredMode == .manual {
                Picker("Alteration Method", selection: $selectedMethod) {
                    Text("Select a method").tag(Optional<AlterationMethod>.none)
                    ForEach(AlterationMethod.allCases, id: \.self) { method in
                        Text(method.label).tag(Optional(method))
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: selectedMethod) { _, newValue in
                    applyAlterationMethod(newValue)
                }
            } else {
                Text("Default method: Meaning Words")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if let method = selectedMethod {
                Text(method.guidance)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if selectedMethod == .meaningWords, let detail = scene.alterationDetail {
                Text("Meaning Words: \(detail)")
                    .font(.callout)
            }

            if selectedMethod == .sceneAdjustment {
                Picker("Scene Adjustment", selection: $selectedAdjustment) {
                    ForEach(SceneAdjustment.allCases, id: \.self) { adjustment in
                        Text(adjustment.label).tag(adjustment)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: selectedAdjustment) { _, newValue in
                    applySceneAdjustment(newValue)
                }

                Text(selectedAdjustment.guidance)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func interruptSceneSection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("INTERRUPT SCENE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("The Scene is an Interrupt. Generate a Random Event and use it as the new scene start.")
                .font(.callout)

            if let event = scene.randomEvent {
                Text("Focus: \(event.focus.rawValue)")
                    .font(.callout)
                Text("Meaning Words: \(event.meaningWords.first) / \(event.meaningWords.second)")
                    .font(.callout)
                Text("Interpret this as what is happening right now.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func narrationSection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("APPLE INTELLIGENCE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: { generateNarration(scene) }) {
                HStack(spacing: Spacing.small) {
                    if isNarrating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isNarrating ? "Narrating..." : "Generate GM narration")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(isNarrating || !isSceneReadyForNarration())

            if let error = narrationError {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if !narration.isEmpty {
                Text(narration)
                    .font(.callout)
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("LOCATION")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let campaign {
                Button(action: generateDungeonStart) {
                    HStack(spacing: Spacing.small) {
                        Image(systemName: "map")
                        Text("Generate Dungeon Start")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
                }
                .buttonStyle(.glassProminent)

                Button(action: regenerateActiveLocation) {
                    HStack(spacing: Spacing.small) {
                        Image(systemName: "arrow.clockwise")
                        Text("Override: Regenerate Location")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
                }
                .buttonStyle(.glassProminent)
                .tint(.secondary)
                .disabled(campaign.activeLocationId == nil)

                if let location = activeLocation(in: campaign) {
                    Text("Active Location: \(location.name) (\(location.type))")
                        .font(.callout)

                    if showLocationDebug {
                        let nodeCount = location.nodes?.count ?? 0
                        let edgeCount = location.edges?.count ?? 0
                        Text("Nodes: \(nodeCount) · Edges: \(edgeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let node = activeNode(in: campaign, location: location) {
                            Text("Current Node: \(node.summary)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let contentSummary = node.contentSummary, !contentSummary.isEmpty {
                                Text("Details: \(contentSummary)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let features = node.features, !features.isEmpty {
                                let featureNames = features.map { $0.name }.joined(separator: ", ")
                                Text("Features: \(featureNames)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let traps = node.traps, !traps.isEmpty {
                                let trapNames = traps.map { "\($0.name) [\($0.state)]" }.joined(separator: ", ")
                                Text("Traps: \(trapNames)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Traps: none detected")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if !showLocationDebug,
                       let node = activeNode(in: campaign, location: location),
                       let features = node.features,
                       !features.isEmpty {
                        let featureNames = features.map { $0.name }.joined(separator: ", ")
                        Text("Known Features: \(featureNames)")
                            .font(.callout)
                    }

                    if let node = activeNode(in: campaign, location: location) {
                        let exitItems = exitDisplays(for: location, node: node)
                        if !exitItems.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Exits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ForEach(exitItems) { item in
                                    HStack(alignment: .top, spacing: Spacing.small) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.label)
                                                .font(.callout)
                                            Text(item.targetSummary)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("Go") {
                                            traverseEdge(item.edge, reason: item.label)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }

                    if !coordinator.pendingLocationFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pending Features:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(coordinator.pendingLocationFeatures) { feature in
                                Text("- \(feature.name): \(feature.summary)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            HStack(spacing: Spacing.small) {
                                Button("Apply") {
                                    applyPendingLocationFeatures()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Dismiss") {
                                    coordinator.pendingLocationFeatures = []
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                } else {
                    Text("No active location yet.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Start a campaign to generate locations.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private func sceneConversationSection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("SCENE CONVERSATION")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if coordinator.interactionDrafts.isEmpty {
                Text("No interactions yet. Describe actions, ask questions, or set up the moment.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(coordinator.interactionDrafts) { interaction in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("You: \(interaction.playerText)")
                            .font(.callout)
                        if !interaction.gmText.isEmpty {
                            Text("GM: \(interaction.gmText)")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(Spacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            }

            if coordinator.pendingCheckID != nil {
                Text("Awaiting roll result for the last check.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            TextField("Ask a question or describe your action...", text: $sceneInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button(action: { requestGMResponse(scene) }) {
                HStack(spacing: Spacing.small) {
                    if coordinator.isResponding {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(coordinator.isResponding ? "Waiting..." : "GM Respond")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(coordinator.isResponding || sceneInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = coordinator.gmResponseError {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var playOutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("PLAY OUT SCENE")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Button(action: { phase = .bookkeeping }) {
                Text("Scene action complete")
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(!isSceneReadyForNarration() || phase != .resolved)
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var bookkeepingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("END OF SCENE BOOKKEEPING")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            TextEditor(text: $sceneSummaryInput)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.medium)
                .frame(minHeight: 90)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .overlay(alignment: .topLeading) {
                    if sceneSummaryInput.isEmpty {
                        Text("Scene summary (length varies by scene).")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                            .padding(.leading, 16)
                    }
                }

            Button(action: draftSceneSummary) {
                HStack(spacing: Spacing.small) {
                    if isDraftingSummary {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isDraftingSummary ? "Drafting..." : "Draft Summary with AI")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(isDraftingSummary || currentScene == nil)

            TextField("Any important NEW Characters?", text: $newCharactersInput)
                .textFieldStyle(.roundedBorder)
            TextField("Any important NEW Threads?", text: $newThreadsInput)
                .textFieldStyle(.roundedBorder)
            TextField("Existing Characters that featured strongly?", text: $featuredCharactersInput)
                .textFieldStyle(.roundedBorder)
            TextField("Existing Threads that featured strongly?", text: $featuredThreadsInput)
                .textFieldStyle(.roundedBorder)
            TextField("Remove Characters no longer relevant?", text: $removeCharactersInput)
                .textFieldStyle(.roundedBorder)
            TextField("Remove Threads no longer relevant?", text: $removeThreadsInput)
                .textFieldStyle(.roundedBorder)
            TextField("Places to remember? (comma-separated)", text: $placesInput)
                .textFieldStyle(.roundedBorder)
            TextField("Curiosities or mysteries? (comma-separated)", text: $curiositiesInput)
                .textFieldStyle(.roundedBorder)
            TextField("Roll highlights? (comma-separated)", text: $coordinator.rollHighlightsInput)
                .textFieldStyle(.roundedBorder)

            Toggle("Were the PCs mostly in control during this scene?", isOn: $pcsInControl)
                .font(.callout)

            Toggle("Is the adventure concluded?", isOn: $adventureConcluded)
                .font(.callout)

            Button(action: applyBookkeeping) {
                Text(adventureConcluded ? "Conclude Adventure" : "Continue to Next Scene")
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(sceneSummaryInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var conclusionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("ADVENTURE CONCLUSION")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Write 2-4 lines summarizing what changed and what's resolved.")
                .font(.callout)

            Button(action: resetAdventure) {
                Text("Start a New Adventure")
                    .font(.callout)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var currentListsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("CURRENT LISTS")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Chaos Factor: \(campaign?.chaosFactor ?? 5)")
                .font(.callout)

            Text("Characters: \(formattedEntries(campaign?.characters ?? []))")
                .font(.callout)

            Text("Threads: \(formattedEntries(campaign?.threads ?? []))")
                .font(.callout)
        }
        .padding(Spacing.medium)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }

    private var campaignJournalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("CAMPAIGN JOURNAL")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if let scenes = campaign?.scenes.sorted(by: { $0.sceneNumber > $1.sceneNumber }), !scenes.isEmpty {
                ForEach(scenes) { entry in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text(entry.summary)
                                .font(.callout)

                            Text("Chaos Factor: \(entry.chaosFactor)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Edit Scene") {
                                editingScene = entry
                            }
                            .buttonStyle(.bordered)

                            if !entry.charactersAdded.isEmpty {
                                let newCharactersList = entry.charactersAdded.joined(separator: ", ")
                                Text("New Characters: \(newCharactersList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !entry.threadsAdded.isEmpty {
                                let newThreadsList = entry.threadsAdded.joined(separator: ", ")
                                Text("New Threads: \(newThreadsList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !entry.places.isEmpty {
                                let placesList = entry.places.joined(separator: ", ")
                                Text("Places: \(placesList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !entry.curiosities.isEmpty {
                                let curiositiesList = entry.curiosities.joined(separator: ", ")
                                Text("Curiosities: \(curiositiesList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if !entry.rollHighlights.isEmpty {
                                let rollsList = entry.rollHighlights.joined(separator: ", ")
                                Text("Rolls: \(rollsList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Scene \(entry.sceneNumber)")
                            Spacer()
                            Text(entry.sceneType.capitalized)
                                .foregroundColor(.secondary)
                            Text("CF \(entry.chaosFactor)")
                                .foregroundColor(.secondary)
                        }
                        .font(.callout)
                    }
                    .padding(Spacing.medium)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                }
            } else {
                Text("No scenes recorded yet.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func resolveScene() {
        guard let campaign else { return }
        let record = coordinator.engine.resolveScene(campaign: campaign, expectedScene: sceneInput.trimmingCharacters(in: .whitespacesAndNewlines))
        currentScene = record
        selectedMethod = nil
        selectedAdjustment = .raiseStakes
        narration = ""
        narrationError = nil
        phase = .resolved
        sceneInput = ""

        if record.type == .altered && alteredMode == .guided {
            selectedMethod = .meaningWords
            applyAlterationMethod(selectedMethod)
        }
    }

    private func applyAlterationMethod(_ method: AlterationMethod?) {
        guard let method, let currentScene else { return }
        let updated = coordinator.engine.applyAlterationMethod(scene: currentScene, method: method, adjustment: selectedAdjustment)
        self.currentScene = updated
    }

    private func applySceneAdjustment(_ adjustment: SceneAdjustment) {
        guard let method = selectedMethod, let currentScene else { return }
        let updated = coordinator.engine.applyAlterationMethod(scene: currentScene, method: method, adjustment: adjustment)
        self.currentScene = updated
    }

    private func isSceneReadyForNarration() -> Bool {
        guard let scene = currentScene else { return false }
        if scene.type == .altered {
            return scene.alterationMethod != nil
        }
        return true
    }

    private func applyBookkeeping() {
        guard let campaign, let currentScene else { return }
        let interactionModels = coordinator.interactionDrafts.map { SceneInteraction(playerText: $0.playerText, gmText: $0.gmText, turnSignal: $0.turnSignal) }
        let checkModels = coordinator.checkDrafts.map { draft in
            let record = SkillCheckRecord(
                playerAction: draft.playerAction,
                checkType: draft.request.checkType.rawValue,
                skill: draft.request.skillName,
                abilityOverride: draft.request.abilityOverride,
                dc: draft.request.dc,
                opponentSkill: draft.request.opponentSkill,
                opponentDC: draft.request.opponentDC,
                advantageState: draft.request.advantageState.rawValue,
                stakes: draft.request.stakes,
                partialSuccessDC: draft.request.partialSuccessDC,
                partialSuccessOutcome: draft.request.partialSuccessOutcome,
                reason: draft.request.reason
            )
            record.rollResult = draft.roll
            record.modifier = draft.modifier
            record.total = draft.total
            record.outcome = draft.outcome
            record.consequence = draft.consequence
            return record
        }
        let fateModels = coordinator.fateQuestionDrafts.map { draft in
            FateQuestionRecord(
                question: draft.question,
                likelihood: draft.likelihood.rawValue,
                chaosFactor: draft.chaosFactor,
                roll: draft.roll,
                target: draft.target,
                outcome: draft.outcome
            )
        }
        let canonModels = coordinator.canonizationDrafts.compactMap { draft -> CanonizationRecord? in
            guard let roll = draft.roll, let target = draft.target, let outcome = draft.outcome else { return nil }
            return CanonizationRecord(
                assumption: draft.assumption,
                likelihood: draft.likelihood.rawValue,
                chaosFactor: draft.chaosFactor,
                roll: roll,
                target: target,
                outcome: outcome
            )
        }

        let bookkeeping = BookkeepingInput(
            summary: sceneSummaryInput.trimmingCharacters(in: .whitespacesAndNewlines),
            newCharacters: parseCommaList(newCharactersInput),
            newThreads: parseCommaList(newThreadsInput),
            featuredCharacters: parseCommaList(featuredCharactersInput),
            featuredThreads: parseCommaList(featuredThreadsInput),
            removedCharacters: parseCommaList(removeCharactersInput),
            removedThreads: parseCommaList(removeThreadsInput),
            pcsInControl: pcsInControl,
            concluded: adventureConcluded,
            interactions: interactionModels,
            skillChecks: checkModels,
            fateQuestions: fateModels,
            places: parseCommaList(placesInput),
            curiosities: parseCommaList(curiositiesInput),
            rollHighlights: parseCommaList(coordinator.rollHighlightsInput),
            locationId: campaign.activeLocationId,
            generatedEntityIds: [],
            canonizations: canonModels
        )

        let savedEntry = coordinator.engine.finalizeScene(campaign: campaign, scene: currentScene, bookkeeping: bookkeeping)
        campaign.activeSceneId = savedEntry.id

        do {
            try modelContext.save()
        } catch {
            narrationError = handleFoundationModelsError(error)
        }

        if adventureConcluded {
            phase = .concluded
        } else {
            resetSceneInputs()
            phase = .setup
            if autoDraftNextScene {
                draftNextScenePrompt(previousEntry: savedEntry)
            }
        }
    }

    private func resetSceneInputs() {
        sceneInput = ""
        currentScene = nil
        selectedMethod = nil
        selectedAdjustment = .raiseStakes
        narration = ""
        narrationError = nil
        newCharactersInput = ""
        newThreadsInput = ""
        featuredCharactersInput = ""
        featuredThreadsInput = ""
        removeCharactersInput = ""
        removeThreadsInput = ""
        placesInput = ""
        curiositiesInput = ""
        coordinator.rollHighlightsInput = ""
        pcsInControl = true
        adventureConcluded = false
        sceneSummaryInput = ""
        nextSceneError = nil
        coordinator.resetConversation()
    }

    private func resetAdventure() {
        campaign?.chaosFactor = 5
        campaign?.sceneNumber = 1
        campaign?.scenes.removeAll()
        campaign?.characters.removeAll()
        campaign?.threads.removeAll()
        try? modelContext.save()
        resetSceneInputs()
        phase = .setup
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func formattedEntries<T: ListEntryProtocol>(_ entries: [T]) -> String {
        guard !entries.isEmpty else { return "None" }
        return entries.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
    }

    private func generateNarration(_ scene: SceneRecord) {
        guard let campaign else { return }
        narration = ""
        narrationError = nil
        isNarrating = true

        Task {
            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)

                let context = coordinator.engine.buildNarrationContext(campaign: campaign, scene: scene)
                var prompt = """
                You are the game master. In 2-4 lines, narrate the scene opener using the details below.
                Keep it punchy and actionable. Avoid lore dumps.
                Do not mention mechanics, rolls, or chaos factors.
                Do not ask the player to invent threats or obstacles; discover those through play.
                Do not narrate the player's actions as if they already happened.
                If clarification is needed, ask only about immediate positioning or intent.
                End with a clear "What do you do?" prompt.

                Scene #\(context.sceneNumber)
                Expected Scene: \(context.expectedScene)
                Scene Type: \(context.sceneType.rawValue)
                """

                if let method = context.alterationMethod {
                    prompt += "\nAlteration Method: \(method.label)"
                }
                if let detail = context.alterationDetail {
                    prompt += "\nAlteration Detail: \(detail)"
                }
                if let event = context.randomEvent {
                    prompt += "\nRandom Event Focus: \(event.focus.rawValue)"
                    prompt += "\nMeaning Words: \(event.meaningWords.first), \(event.meaningWords.second)"
                }

                if !context.activeCharacters.isEmpty {
                    let names = context.activeCharacters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Characters: \(names)"
                }

                if !context.activeThreads.isEmpty {
                    let names = context.activeThreads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Threads: \(names)"
                }

                if let campaignLocation = activeLocation(in: campaign) {
                    prompt += "\nLocation: \(campaignLocation.name) (\(campaignLocation.type))"
                    if let node = activeNode(in: campaign, location: campaignLocation) {
                        prompt += "\nCurrent Node: \(node.summary)"
                        let featureSummary = locationFeatureSummary(for: node)
                        if !featureSummary.isEmpty {
                            prompt += "\nKnown Features: \(featureSummary)"
                        }
                    }
                }

                if !context.currentExits.isEmpty {
                    prompt += "\nCurrent Exits: \(context.currentExits.joined(separator: " · "))"
                }

                if !context.recentScenes.isEmpty {
                    prompt += "\nRecent Scenes:"
                    for entry in context.recentScenes {
                        prompt += "\n- Scene \(entry.sceneNumber): \(entry.summary)"
                    }
                }

                if !coordinator.interactionDrafts.isEmpty {
                    prompt += "\nRecent Interaction Highlights:"
                    for interaction in coordinator.interactionDrafts.suffix(3) {
                        prompt += "\n- Player: \(interaction.playerText)"
                        if !interaction.gmText.isEmpty {
                            prompt += " / GM: \(interaction.gmText)"
                        }
                    }
                }

                if shouldForeshadowLine() {
                    prompt += "\nAdd one line starting with \"What you don't see is ...\" about an unseen consequence."
                }

                let response = try await session.respond(to: Prompt(prompt))
                narration = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                await captureLocationFeatures(from: narration, session: session, campaign: campaign)
            } catch {
                narrationError = handleFoundationModelsError(error)
            }

            isNarrating = false
        }
    }

    private func handleFoundationModelsError(_ error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            return FoundationModelsErrorHandler.handleGenerationError(generationError)
        } else if let toolCallError = error as? LanguageModelSession.ToolCallError {
            return FoundationModelsErrorHandler.handleToolCallError(toolCallError)
        } else if let customError = error as? FoundationModelsError {
            return customError.localizedDescription
        } else {
            return "Unexpected error: \(error.localizedDescription)"
        }
    }

    private func requestGMResponse(_ scene: SceneRecord) {
        guard let campaign else { return }
        let trimmed = sceneInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            let gmText = await coordinator.requestGMResponse(
                campaign: campaign,
                scene: scene,
                playerText: trimmed,
                autoRollEnabled: autoRollEnabled,
                gmRunsCompanionsEnabled: gmRunsCompanionsEnabled,
                modelContext: modelContext
            )
            if gmText != nil {
                sceneInput = ""
            }
        }
    }

    private func gmLineForCheck(_ request: CheckRequest) -> String {
        let skillName = request.skillName
        let ability = request.abilityOverride ?? coordinator.engine.ruleset.defaultAbility(for: skillName) ?? "Ability"
        let abilityLine = "\(ability) (\(skillName))"
        let advantageLine: String
        switch request.advantageState {
        case .advantage:
            advantageLine = "with advantage"
        case .disadvantage:
            advantageLine = "with disadvantage"
        case .normal:
            advantageLine = "normally"
        }

        var line = "Okay - give me a \(abilityLine) check, \(advantageLine)."
        if let dc = request.dc {
            line += " DC \(dc)."
        } else if let opponentDC = request.opponentDC {
            let opponent = request.opponentSkill ?? "opponent"
            line += " Opposed by \(opponent) (DC \(opponentDC))."
        }
        if !request.reason.isEmpty {
            line += " Reason: \(request.reason)."
        }
        line += " If you fail, \(request.stakes)"
        if let partialDC = request.partialSuccessDC, let partialText = request.partialSuccessOutcome, !partialText.isEmpty {
            line += " On a partial (DC \(partialDC)), \(partialText)"
        }
        if autoRollEnabled {
            line += " Roll it, or say \"auto\" if you want me to roll."
        } else {
            line += " Want to attempt it?"
        }
        return line
    }

    private func needsClarification(_ intent: PlayerIntentDraft) -> Bool {
        let verb = intent.verb.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = intent.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        return verb.isEmpty || summary.isEmpty
    }

    private func logAgency(stage: String, message: String) {
        coordinator.agencyLogs.append(AgencyLogEntry(stage: stage, message: message))
    }

    private func availableTableIds() -> [String] {
        do {
            let pack = try ContentPackStore().loadDefaultPack()
            return pack.tables.map { $0.id }.sorted()
        } catch {
            return []
        }
    }

    private func resolveTableRollIfNeeded(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        campaign: Campaign
    ) async throws -> TableRollOutcome? {
        let tableIds = availableTableIds()
        guard !tableIds.isEmpty else { return nil }

        let draft = try await session.respond(
            to: Prompt(makeTableRollPrompt(playerText: playerText, context: context, tableIds: tableIds)),
            generating: TableRollRequestDraft.self
        )

        guard draft.content.shouldRoll,
              let tableId = draft.content.tableId,
              tableIds.contains(tableId) else { return nil }

        var tableOracle = TableOracleEngine()
        let result = tableOracle.rollMessage(campaign: campaign, tableId: tableId, tags: ["table_oracle", tableId])
        if let result {
            return TableRollOutcome(tableId: tableId, result: result, reason: draft.content.reason)
        }
        return nil
    }

    private func resolveSrdLookupIfNeeded(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String
    ) async throws -> SrdLookupOutcome? {
        guard let index = SrdContentStore().loadIndex() else { return nil }

        let draft = try await session.respond(
            to: Prompt(makeSrdLookupPrompt(playerText: playerText, context: context)),
            generating: SrdLookupRequestDraft.self
        )

        guard draft.content.shouldLookup,
              let rawName = draft.content.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else { return nil }

        let category = draft.content.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let reason = draft.content.reason

        switch category {
        case "class":
            guard let name = matchSrdName(rawName, in: index.classes),
                  let lines = index.classDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Class", name: name, lines: lines, reason: reason)
        case "background":
            guard let name = matchSrdName(rawName, in: index.backgrounds),
                  let lines = index.backgroundDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Background", name: name, lines: lines, reason: reason)
        case "subclass":
            guard let name = matchSrdName(rawName, in: index.subclasses),
                  let lines = index.subclassDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Subclass", name: name, lines: lines, reason: reason)
        case "spell":
            guard let name = matchSrdName(rawName, in: index.spells),
                  let lines = index.spellDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Spell", name: name, lines: lines, reason: reason)
        case "feat":
            guard let name = matchSrdName(rawName, in: index.feats),
                  let lines = index.featDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Feat", name: name, lines: lines, reason: reason)
        case "item":
            guard let name = matchSrdName(rawName, in: index.magicItems),
                  let lines = index.magicItemDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Magic Item", name: name, lines: lines, reason: reason)
        case "equipment":
            guard let name = matchSrdName(rawName, in: index.equipment),
                  let lines = index.equipmentDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Equipment", name: name, lines: lines, reason: reason)
        case "creature", "monster":
            guard let name = matchSrdName(rawName, in: index.creatures),
                  let lines = index.creatureDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Creature", name: name, lines: lines, reason: reason)
        case "rule", "section":
            guard let name = matchSrdName(rawName, in: index.sections),
                  let lines = index.sectionDetails[name], !lines.isEmpty else { return nil }
            return SrdLookupOutcome(category: "Rule", name: name, lines: lines, reason: reason)
        default:
            return nil
        }
    }

    private func matchSrdName(_ name: String, in candidates: [String]) -> String? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return nil }
        if let exact = candidates.first(where: { $0.lowercased() == normalized }) {
            return exact
        }
        if let contains = candidates.first(where: { $0.lowercased().contains(normalized) }) {
            return contains
        }
        if let inverse = candidates.first(where: { normalized.contains($0.lowercased()) }) {
            return inverse
        }
        return nil
    }

    private func isMetaMessage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lower = trimmed.lowercased()

        let metaPrefixes = ["gm", "dm", "game master", "dungeon master"]
        for prefix in metaPrefixes {
            guard lower.hasPrefix(prefix) else { continue }
            let endIndex = lower.index(lower.startIndex, offsetBy: prefix.count)
            if endIndex == lower.endIndex {
                return true
            }
            let nextChar = lower[endIndex]
            if nextChar.isWhitespace || nextChar == ":" || nextChar == "," {
                return true
            }
        }
        return false
    }

    private func isAffirmativeResponse(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["y", "yes", "yeah", "yep", "sure", "ok", "okay", "please"].contains(normalized)
    }

    private func isNegativeResponse(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["n", "no", "nope", "nah", "skip"].contains(normalized)
    }

    private func trapSearchDraftIfNeeded(playerText: String, campaign: Campaign) -> SkillCheckDraft? {
        let lower = playerText.lowercased()
        let searchKeywords = ["check for traps", "search for traps", "look for traps", "scan for traps", "inspect for traps"]
        guard searchKeywords.contains(where: { lower.contains($0) }) else { return nil }
        guard let trap = currentHiddenTrap(in: campaign) else { return nil }

        let skillName = normalizedSkillName(trap.detectionSkill)
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: skillName,
            abilityOverride: nil,
            dc: trap.detectionDC,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "You miss the trap and remain at risk of triggering it.",
            partialSuccessDC: max(5, trap.detectionDC - 5),
            partialSuccessOutcome: "You notice hints but not the exact trigger.",
            reason: "Hidden \(trap.category) trap: \(trap.trigger)."
        )

        return SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: trap.id,
            sourceKind: "trap_detection"
        )
    }

    private func trapTriggerDraftIfNeeded(playerText: String, campaign: Campaign) -> SkillCheckDraft? {
        let lower = playerText.lowercased()
        let triggerKeywords = ["open", "pull", "push", "touch", "step", "cross", "enter", "lift"]
        guard triggerKeywords.contains(where: { lower.contains($0) }) else { return nil }
        guard let trap = currentHiddenTrap(in: campaign) else { return nil }

        trap.state = "triggered"
        try? modelContext.save()
        let skillName = normalizedSkillName(trap.saveSkill ?? "Acrobatics")
        let dc = trap.saveDC ?? trap.detectionDC
        let request = CheckRequest(
            checkType: .skillCheck,
            skillName: skillName,
            abilityOverride: nil,
            dc: dc,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: trap.effectSummary,
            partialSuccessDC: max(5, dc - 5),
            partialSuccessOutcome: "You avoid the worst of it but still suffer a complication.",
            reason: "Trap trigger: \(trap.trigger)."
        )

        return SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: trap.id,
            sourceKind: "trap_trigger"
        )
    }

    private func applyTrapOutcomeIfNeeded(for draft: SkillCheckDraft, outcome: String) {
        guard let campaign, let trapId = draft.sourceTrapId else { return }
        guard let location = activeLocation(in: campaign) else { return }
        guard let node = activeNode(in: campaign, location: location) else { return }
        guard let traps = node.traps else { return }
        guard let trapIndex = traps.firstIndex(where: { $0.id == trapId }) else { return }

        let trap = traps[trapIndex]
        switch draft.sourceKind {
        case "trap_detection":
            if outcome == "success" || outcome == "partial_success" {
                trap.state = "spotted"
            }
        case "trap_trigger":
            trap.state = "triggered"
        default:
            break
        }
        try? modelContext.save()
    }

    private func currentHiddenTrap(in campaign: Campaign) -> TrapEntity? {
        guard let location = activeLocation(in: campaign) else { return nil }
        guard let node = activeNode(in: campaign, location: location) else { return nil }
        return node.traps?.first(where: { $0.state == "hidden" })
    }

    private func resolveMovementIntent(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        campaign: Campaign
    ) async throws -> Bool {
        guard campaign.activeLocationId != nil else { return false }
        let movementDraft = try await session.respond(
            to: Prompt(makeMovementIntentPrompt(playerText: playerText, context: context)),
            generating: MovementIntentDraft.self
        )
        guard movementDraft.content.isMovement else { return false }

        let summary = movementDraft.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = movementDraft.content.destination?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let exitLabel = movementDraft.content.exitLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reason: String
        if !destination.isEmpty && !summary.isEmpty {
            reason = "\(summary) (\(destination))"
        } else if !summary.isEmpty {
            reason = summary
        } else if !destination.isEmpty {
            reason = destination
        } else {
            reason = playerText
        }

        if let location = activeLocation(in: campaign),
           let node = activeNode(in: campaign, location: location),
           let edge = edgeForExitLabel(exitLabel, location: location, node: node) {
            _ = coordinator.locationEngine.advanceAlongEdge(campaign: campaign, edge: edge, reason: reason)
        } else {
            _ = coordinator.locationEngine.advanceToNextNode(campaign: campaign, reason: reason)
        }
        try? modelContext.save()
        return true
    }

    private func normalizedSkillName(_ skill: String) -> String {
        if let match = coordinator.engine.ruleset.skillNames.first(where: { $0.caseInsensitiveCompare(skill) == .orderedSame }) {
            return match
        }
        if let fallback = coordinator.engine.ruleset.skillNames.first(where: { $0.caseInsensitiveCompare("Investigation") == .orderedSame }) {
            return fallback
        }
        return coordinator.engine.ruleset.skillNames.first ?? skill
    }

    private func shouldForceSkillCheck(for playerText: String) -> Bool {
        let lower = playerText.lowercased()
        let keywords = [
            "check for traps", "search for traps", "look for traps", "scan for traps", "inspect for traps",
            "search", "investigate", "examine", "inspect", "sneak", "hide", "pick",
            "climb", "jump", "force", "lift", "break", "convince", "persuade", "intimidate",
            "listen", "peek", "track"
        ]
        return keywords.contains(where: { lower.contains($0) })
    }

    private func shouldOverrideTrapSkill(proposedSkill: String) -> Bool {
        let lower = proposedSkill.lowercased()
        return !(lower.contains("perception") || lower.contains("investigation"))
    }

    private struct RollParseFallback {
        let roll: Int?
        let modifier: Int?
        let autoRoll: Bool
        let declines: Bool
    }

    private func parseRollFallback(from text: String) -> RollParseFallback? {
        let lower = text.lowercased()
        if lower.contains("auto") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: true, declines: false)
        }
        if lower.contains("skip") || lower.contains("decline") || lower.contains("pass") {
            return RollParseFallback(roll: nil, modifier: nil, autoRoll: false, declines: true)
        }

        let rollPattern = "(?i)(natural|nat)\\s*(\\d+)"
        if let match = lower.range(of: rollPattern, options: .regularExpression) {
            let slice = lower[match]
            let digits = slice.split(whereSeparator: { !$0.isNumber })
            if let value = digits.compactMap({ Int($0) }).first, (1...20).contains(value) {
                return RollParseFallback(roll: value, modifier: nil, autoRoll: false, declines: false)
            }
        }

        let numbers = lower.split { !$0.isNumber }.compactMap { Int($0) }.filter { (1...20).contains($0) }
        if numbers.count == 1, let roll = numbers.first {
            return RollParseFallback(roll: roll, modifier: nil, autoRoll: false, declines: false)
        }
        return nil
    }

    private func forcedCheckRequest(for playerText: String) -> CheckRequest? {
        let lower = playerText.lowercased()
        let skill: String
        if lower.contains("trap") || lower.contains("investigate") || lower.contains("search") || lower.contains("inspect") {
            skill = normalizedSkillName("Investigation")
        } else if lower.contains("sneak") || lower.contains("hide") || lower.contains("stealth") {
            skill = normalizedSkillName("Stealth")
        } else if lower.contains("persuade") || lower.contains("convince") {
            skill = normalizedSkillName("Persuasion")
        } else if lower.contains("intimidate") {
            skill = normalizedSkillName("Intimidation")
        } else if lower.contains("climb") || lower.contains("jump") || lower.contains("force") || lower.contains("break") || lower.contains("lift") {
            skill = normalizedSkillName("Athletics")
        } else if lower.contains("balance") || lower.contains("acrobat") {
            skill = normalizedSkillName("Acrobatics")
        } else if lower.contains("listen") || lower.contains("peek") || lower.contains("spot") {
            skill = normalizedSkillName("Perception")
        } else {
            skill = normalizedSkillName("Investigation")
        }

        return CheckRequest(
            checkType: .skillCheck,
            skillName: skill,
            abilityOverride: nil,
            dc: 15,
            opponentSkill: nil,
            opponentDC: nil,
            advantageState: .normal,
            stakes: "Failure complicates the attempt or leaves you exposed to consequences.",
            partialSuccessDC: 10,
            partialSuccessOutcome: "You make progress but introduce a complication.",
            reason: "The action is uncertain and failure would matter."
        )
    }

    private func activeLocationName(for context: NarrationContextPacket) -> String {
        guard let campaign else { return "none" }
        if let location = activeLocation(in: campaign) {
            if let node = activeNode(in: campaign, location: location) {
                return "\(location.name) (\(location.type)) - \(node.summary)"
            }
            return "\(location.name) (\(location.type))"
        }
        return "none"
    }

    private func canonizationFacts(for campaign: Campaign) -> String {
        guard let location = activeLocation(in: campaign) else { return "" }
        var facts: [String] = ["Location: \(location.name) (\(location.type))"]
        if let node = activeNode(in: campaign, location: location) {
            facts.append("Node: \(node.summary)")
            if let traps = node.traps, !traps.isEmpty {
                let trapFacts = traps.map { "\($0.name) [\($0.state)]" }.joined(separator: ", ")
                facts.append("Traps: \(trapFacts)")
            }
        }
        return facts.joined(separator: " · ")
    }

    private func makeIntentCategoryPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Classify the player's message into one of:
        - player_intent (an action the player wants to attempt)
        - player_question (a question about the world)
        - roleplay_dialogue (in-character dialogue only)
        - gm_command (meta request to the GM)
        - unclear (ambiguous)

        Never assume the player took an action. If intent is unclear, choose unclear.
        If the player uses quotes or speaks as their character, prefer roleplay_dialogue.
        If the player addresses GM/DM directly, prefer gm_command.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return an IntentCategoryDraft.
        """
    }

    private func makePlayerIntentPrompt(playerText: String, context: NarrationContextPacket) -> String {
        var prompt = """
        Extract the player's intent without assuming any action occurred.
        Provide a short summary of what they are attempting.
        Only include party members if the player explicitly mentions them.
        If they ask for auto-resolution, set requestedMode to auto_resolve.
        Otherwise use ask_before_rolling.
        Do not infer NPC actions or dialogue from the player's text.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if gmRunsCompanionsEnabled {
            prompt += "\nGM runs companions is ENABLED, but still require explicit player intent."
        }

        prompt += "\nReturn a PlayerIntentDraft."
        return prompt
    }

    private func makeMovementIntentPrompt(playerText: String, context: NarrationContextPacket) -> String {
        var prompt = """
        Decide if the player is moving into a new space or leaving the current location.
        Return isMovement = true only when they explicitly move to a different room, corridor, exit, or location.
        Return false for questions, investigations, conversations, or actions that stay in the current space.
        Provide a short summary and optional destination if present.
        If they reference a specific exit, include its label or type in exitLabel.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if let campaign, let location = activeLocation(in: campaign) {
            prompt += "\nLocation: \(location.name) (\(location.type))"
            if let node = activeNode(in: campaign, location: location) {
                prompt += "\nCurrent Node: \(node.summary)"
            }
        }

        if !context.currentExits.isEmpty {
            prompt += "\nKnown Exits: \(context.currentExits.joined(separator: " · "))"
        }

        prompt += "\nReturn a MovementIntentDraft."
        return prompt
    }

    private func makeCanonizationPrompt(playerText: String, context: NarrationContextPacket) -> String {
        var prompt = """
        Determine if the player is asserting a new concrete fact about the world that should be canonized.
        Only return shouldCanonize = true when the player explicitly states a detail as true
        (not a question, not a plan, not dialogue) and it would matter if accepted.
        Never infer NPC abilities, motives, or magical traits beyond what the player stated.
        If they are asking a question, speaking in character, or describing an action, return false.
        Provide a concise assumption and a likelihood for a fate roll.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Player: \(playerText)
        """
        if let campaign {
            let facts = canonizationFacts(for: campaign)
            if !facts.isEmpty {
                prompt += "\nKnown system facts: \(facts)"
            }
        }
        return prompt
    }

    private func makeFatePrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Decide if the player's message is a yes/no fate question and pick likelihood.
        Use likelihood values: impossible, unlikely, 50_50, likely, veryLikely, nearlyCertain.
        Return a FateQuestionDraft.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Chaos Factor: \(context.chaosFactor)
        Player: \(playerText)
        """
    }

    private func shouldSkipCanonization(for playerText: String) -> Bool {
        let trimmed = playerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let lower = trimmed.lowercased()
        if lower.contains("?") { return true }
        if lower.contains("\"") || lower.contains("“") || lower.contains("”") { return true }
        if lower.hasPrefix("gm ") || lower.hasPrefix("dm ") || lower.hasPrefix("ooc") { return true }

        let assertionMarkers = [
            "there is", "there are", "there's", "you see", "i notice", "i spot",
            "the room has", "the area has", "this place has", "the hall has"
        ]
        let actionPrefixes = ["i ", "we ", "my ", "our "]
        if actionPrefixes.contains(where: { lower.hasPrefix($0) }) && !assertionMarkers.contains(where: { lower.contains($0) }) {
            return true
        }
        return false
    }

    private func shouldForeshadowLine() -> Bool {
        coordinator.engine.rollD100() <= 15
    }

    private func shouldCaptureLocationFeatures(from text: String) -> Bool {
        let lower = text.lowercased()
        let cues = ["you see", "there is", "there are", "you notice", "the room", "the hall", "the chamber", "the area"]
        return cues.contains(where: { lower.contains($0) }) && text.count > 20
    }

    private func makeLocationFeaturePrompt(text: String, location: LocationEntity, node: LocationNode) -> String {
        let existing = (node.features ?? []).map { $0.name }.joined(separator: ", ")
        return """
        Extract stable, inanimate location features worth persisting.
        Include furniture, fixtures, structures, and notable objects.
        Exclude NPCs, creatures, actions, or temporary effects.
        Limit to 0-5 items and keep summaries short.

        Location: \(location.name) (\(location.type))
        Node: \(node.summary)
        Known features: \(existing.isEmpty ? "none" : existing)

        Text: \(text)
        """
    }

    private func captureLocationFeatures(
        from text: String,
        session: LanguageModelSession,
        campaign: Campaign
    ) async {
        guard shouldCaptureLocationFeatures(from: text) else { return }
        guard let location = activeLocation(in: campaign),
              let node = activeNode(in: campaign, location: location) else { return }
        do {
            let prompt = makeLocationFeaturePrompt(text: text, location: location, node: node)
            let draft = try await session.respond(
                to: Prompt(prompt),
                generating: LocationFeatureDraft.self
            )
            let pendingNames = await MainActor.run {
                coordinator.pendingLocationFeatures.map { $0.name.lowercased() }
            }
            let existingFeatureNames = await MainActor.run {
                (node.features ?? []).map { $0.name.lowercased() }
            }
            let existingNames = Set(existingFeatureNames + pendingNames)
            let candidates = draft.content.items.compactMap { item -> PendingLocationFeature? in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let summary = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                guard !existingNames.contains(name.lowercased()) else { return nil }
                return PendingLocationFeature(name: name, summary: summary)
            }
            guard !candidates.isEmpty else { return }
            await MainActor.run {
                coordinator.pendingLocationFeatures.append(contentsOf: candidates)
            }
        } catch {
            return
        }
    }

    private func locationFeatureSummary(for node: LocationNode) -> String {
        guard let features = node.features, !features.isEmpty else { return "" }
        let summaries = features.prefix(4).map { feature in
            if feature.summary.isEmpty {
                return feature.name
            }
            return "\(feature.name) (\(feature.summary))"
        }
        return summaries.joined(separator: ", ")
    }

    private func makeCheckProposalPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Propose a ruleset-based skill check for a solo RPG.
        - Roll only if the action is uncertain and consequential.
        - If failure would change the situation in a meaningful way, a roll is required.
        - No roll for trivial or guaranteed actions; set requiresRoll to false and give autoOutcome.
        - Searching for traps or hidden dangers always requires a roll and should use Perception or Investigation.
        - Use DC bands 5, 10, 15, 20, 25, 30.
        - Advantage for strong leverage; disadvantage for harsh conditions.
        - Provide a concrete, in-fiction reason for the chosen DC.
        Return a CheckRequestDraft.

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Chaos Factor: \(context.chaosFactor)
        Player action: \(playerText)
        Recent places: \(context.recentPlaces.joined(separator: ", "))
        Recent curiosities: \(context.recentCuriosities.joined(separator: ", "))
        Active location: \(activeLocationName(for: context))
        Ruleset: \(coordinator.engine.ruleset.displayName)
        Available skills: \(coordinator.engine.ruleset.skillNames.joined(separator: ", "))
        """
    }

    private func resolveSkillCheckProposal(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        intentSummary: String? = nil,
        requestedMode: PlayerRequestedMode = .askBeforeRolling
    ) async throws -> Bool {
        let checkDraft = try await session.respond(
            to: Prompt(makeCheckProposalPrompt(playerText: playerText, context: context)),
            generating: CheckRequestDraft.self
        )

        if checkDraft.content.requiresRoll == false {
            if shouldForceSkillCheck(for: playerText), let forcedRequest = forcedCheckRequest(for: playerText) {
                let draft = SkillCheckDraft(
                    playerAction: playerText,
                    request: forcedRequest,
                    roll: nil,
                    modifier: nil,
                    total: nil,
                    outcome: nil,
                    consequence: nil,
                    sourceTrapId: nil,
                    sourceKind: nil
                )
                coordinator.checkDrafts.append(draft)
                coordinator.pendingCheckID = draft.id
                let preface = intentSummary.map { "Got it: \($0). " } ?? ""
                let gmText = preface + gmLineForCheck(forcedRequest)
                coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
                sceneInput = ""
                return true
            }
            let outcome = checkDraft.content.autoOutcome?.isEmpty == false ? checkDraft.content.autoOutcome! : "success"
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + "No roll needed. Automatic outcome: \(outcome). Want to proceed?"
            coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            sceneInput = ""
            return true
        }

        guard let request = coordinator.engine.finalizeCheckRequest(from: checkDraft.content) else {
            let gmText = "I couldn't settle on a clear check. Want to rephrase?"
            coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            sceneInput = ""
            return true
        }
        if shouldForceSkillCheck(for: playerText),
           shouldOverrideTrapSkill(proposedSkill: request.skillName),
           let forcedRequest = forcedCheckRequest(for: playerText) {
            let draft = SkillCheckDraft(
                playerAction: playerText,
                request: forcedRequest,
                roll: nil,
                modifier: nil,
                total: nil,
                outcome: nil,
                consequence: nil,
                sourceTrapId: nil,
                sourceKind: nil
            )
            coordinator.checkDrafts.append(draft)
            coordinator.pendingCheckID = draft.id
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + gmLineForCheck(forcedRequest)
            coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            sceneInput = ""
            return true
        }
        logAgency(stage: "adjudication_request", message: "\(request.skillName) dc=\(request.dc ?? request.opponentDC ?? 0) reason=\(request.reason)")

        let draft = SkillCheckDraft(
            playerAction: playerText,
            request: request,
            roll: nil,
            modifier: nil,
            total: nil,
            outcome: nil,
            consequence: nil,
            sourceTrapId: nil,
            sourceKind: nil
        )
        coordinator.checkDrafts.append(draft)
        coordinator.pendingCheckID = draft.id

        if autoRollEnabled, requestedMode == .autoResolve {
            let roll = Int.random(in: 1...20)
            let modifier = 0
            coordinator.checkDrafts[coordinator.checkDrafts.count - 1].roll = roll
            coordinator.checkDrafts[coordinator.checkDrafts.count - 1].modifier = modifier
            let result = coordinator.engine.evaluateCheck(request: request, roll: roll, modifier: modifier)
            coordinator.checkDrafts[coordinator.checkDrafts.count - 1].total = result.total
            coordinator.checkDrafts[coordinator.checkDrafts.count - 1].outcome = result.outcome
            appendRollHighlight(for: coordinator.checkDrafts[coordinator.checkDrafts.count - 1], outcome: result.outcome, total: result.total)
            logAgency(stage: "resolution", message: "Auto-roll check \(request.skillName) => \(result.outcome) total \(result.total)")
            let consequence = try await generateCheckConsequence(
                session: session,
                context: context,
                check: coordinator.checkDrafts[coordinator.checkDrafts.count - 1],
                result: result
            )
            coordinator.checkDrafts[coordinator.checkDrafts.count - 1].consequence = consequence
            let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
            let preface = intentSummary.map { "Got it: \($0). " } ?? ""
            let gmText = preface + "Auto-roll: \(roll) + \(modifier) = \(result.total). \(outcomeText.capitalized). \(consequence)"
            coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
            coordinator.pendingCheckID = nil
            sceneInput = ""
            return true
        }

        let preface = intentSummary.map { "Got it: \($0). " } ?? ""
        let gmText = preface + gmLineForCheck(request)
        coordinator.interactionDrafts.append(InteractionDraft(playerText: playerText, gmText: gmText, turnSignal: "gm_response"))
        sceneInput = ""
        return true
    }

    private func makeRollParsingPrompt(playerText: String, check: SkillCheckDraft) -> String {
        """
        The player is responding to a pending skill check.
        Extract the d20 roll and modifier if present. If they decline, set declines to true.
        If they explicitly ask for an auto-roll (\"auto\"), set autoRoll to true.
        Otherwise set autoRoll to false.
        Recognize \"natural 1\", \"natural 20\", \"nat 1\", or \"nat 20\" as rolls.
        If no roll is provided, leave roll as null.

        Check: \(check.request.skillName) DC \(check.request.dc ?? check.request.opponentDC ?? 10)
        Player: \(playerText)

        Return a CheckRollDraft.
        """
    }

    private func makeTableRollPrompt(
        playerText: String,
        context: NarrationContextPacket,
        tableIds: [String]
    ) -> String {
        let tableList = tableIds.joined(separator: ", ")
        return """
        Decide if a random table roll would help answer the player.
        Only request a roll when it directly supports the response.
        If a roll is needed, choose one table id from the provided list.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        Available Tables: \(tableList)

        Return a TableRollRequestDraft.
        """
    }

    private func makeSrdLookupPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Decide if an SRD lookup is needed to answer the player (rules text, class, subclass, background, spell, feat, item, equipment, creature).
        Only request a lookup when the player explicitly references something from the rules.
        If a lookup is needed, provide the category and name as stated by the player.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return a SrdLookupRequestDraft.
        """
    }

    private func generateNormalGMResponse(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        isMeta: Bool,
        playerInputKind: IntentCategory? = nil,
        tableRoll: TableRollOutcome? = nil,
        srdLookup: SrdLookupOutcome? = nil
    ) async throws -> String {
        var prompt = """
        You are the game master in a solo RPG. Respond conversationally.
        Do not roll dice or change state. Ask clarifying questions when needed.
        Do not mention mechanics, chaos factor, or internal rolls.
        Do not ask the player to invent threats or obstacles; discover them through play.
        Never narrate player actions or decisions as if they already happened.
        Use conditional phrasing or ask the player to choose.
        """

        if gmRunsCompanionsEnabled {
            prompt += "\nGM runs companions is enabled. You may narrate companion actions, but avoid taking major decisions without prompting."
        } else {
            prompt += "\nDo not move the party or companions unless the player explicitly says so."
        }

        if let playerInputKind {
            prompt += "\nPlayer input type: \(playerInputKind.rawValue)"
        }

        if let intentSummary = coordinator.lastPlayerIntentSummary, !intentSummary.isEmpty {
            prompt += "\nPlayer intent echo: \(intentSummary)"
        }

        if playerInputKind == .roleplayDialogue {
            prompt += "\nTreat the player's message as their character's dialogue. Do not attribute it to NPCs."
        }

        prompt += "\nContext Card:\n\(buildContextCard(context: context))"

        prompt += """

        If the player pushes beyond the current scene scope, suggest ending the scene and offer:
        - Use a relevant sense from here to perceive what lies beyond, or
        - Move that way and start a new scene.
        """

        if isMeta {
            prompt += """

            The player is speaking out of character to the GM about rules, retcons, or clarifications.
            Keep it short and practical. Confirm any changes before assuming they apply.
            """
        }

        prompt += """

        Scene #\(context.sceneNumber)
        Expected Scene: \(context.expectedScene)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        if !isMeta {
            prompt += "\nAssume the player is speaking in character unless they address the GM directly."
            prompt += "\nEnd with a short question like \"What do you do?\""
        }

        if !context.activeCharacters.isEmpty {
            let names = context.activeCharacters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Characters: \(names)"
        }

        if !context.activeThreads.isEmpty {
            let names = context.activeThreads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Threads: \(names)"
        }

        if let campaign, let location = activeLocation(in: campaign) {
            prompt += "\nLocation: \(location.name) (\(location.type))"
            if let node = activeNode(in: campaign, location: location) {
                prompt += "\nCurrent Node: \(node.summary)"
                let featureSummary = locationFeatureSummary(for: node)
                if !featureSummary.isEmpty {
                    prompt += "\nKnown Features: \(featureSummary)"
                }
            }
        }

        if !context.currentExits.isEmpty {
            prompt += "\nCurrent Exits: \(context.currentExits.joined(separator: " · "))"
        }

        prompt += "\nGM runs companions: \(gmRunsCompanionsEnabled ? "enabled" : "disabled")"

        if !context.recentPlaces.isEmpty {
            prompt += "\nRecent Places: \(context.recentPlaces.joined(separator: ", "))"
        }

        if !context.recentCuriosities.isEmpty {
            prompt += "\nRecent Curiosities: \(context.recentCuriosities.joined(separator: ", "))"
        }

        if !context.recentRollHighlights.isEmpty {
            prompt += "\nRecent Rolls: \(context.recentRollHighlights.joined(separator: ", "))"
        }

        if let tableRoll {
            prompt += "\nTable Roll (\(tableRoll.tableId)): \(tableRoll.result)"
            if !tableRoll.reason.isEmpty {
                prompt += "\nTable Roll Reason: \(tableRoll.reason)"
            }
        }

        if let srdLookup {
            let detailSummary = srdLookup.lines.prefix(8).joined(separator: " ")
            prompt += "\nSRD Reference (\(srdLookup.category)): \(srdLookup.name)"
            if !srdLookup.reason.isEmpty {
                prompt += "\nSRD Lookup Reason: \(srdLookup.reason)"
            }
            if !detailSummary.isEmpty {
                prompt += "\nSRD Details: \(detailSummary)"
            }
        }

        prompt += """
        
        Build 1-4 segments. Use speaker=gm for narration and prompts.
        Use speaker=npc only if an NPC is explicitly present in the context.
        Never use speaker=player. Dialogue should only appear in dialogue segments.
        """
        prompt += "\nReturn a NarrationPlanDraft."

        let response = try await session.respond(to: Prompt(prompt), generating: NarrationPlanDraft.self)
        let content = renderNarrationPlan(response.content)
        if violatesAgencyBoundary(content) {
            logAgency(stage: "agency_violation", message: "Rewriting narration to avoid assumed player action.")
            return try await rewriteForAgency(
                session: session,
                context: context,
                playerText: playerText,
                draft: content
            )
        }
        return content
    }

    private func generateFateNarration(
        session: LanguageModelSession,
        question: String,
        outcome: String
    ) async throws -> String {
        let prompt = """
        Answer the fate question with the given outcome in 1-2 sentences.
        Question: \(question)
        Outcome: \(outcome.uppercased())
        """
        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func violatesAgencyBoundary(_ text: String) -> Bool {
        let lower = " " + text.lowercased()
        let allowedVerbs = [
            "see", "hear", "notice", "spot", "feel", "smell", "sense", "recall", "realize"
        ]
        let bannedVerbs = [
            "decide", "charge", "attack", "cast", "open", "search", "inspect", "climb",
            "move", "enter", "leave", "take", "grab", "draw", "say", "says", "speak",
            "speaks", "tell", "tells", "go", "goes", "went", "use", "uses", "try", "tries",
            "attempt", "attempts", "pick", "picks", "persuade", "persuades", "sneak",
            "sneaks", "steal", "steals", "look", "looks", "run", "runs", "rush", "rushes"
        ]
        let conditionalPrefixes = [
            "if you", "would you", "could you", "do you", "can you", "should you",
            "when you", "as you", "you could", "you can", "you might", "you may"
        ]

        for verb in bannedVerbs {
            let token = "you \(verb)"
            guard lower.contains(token) else { continue }
            if allowedVerbs.contains(verb) { continue }
            if conditionalPrefixes.contains(where: { lower.contains("\($0) \(verb)") }) { continue }
            return true
        }
        return false
    }

    private func rewriteForAgency(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        draft: String
    ) async throws -> String {
        let prompt = """
        Rewrite the GM response to avoid assuming any player action occurred.
        Use conditional phrasing or ask the player to choose.
        Keep it to 1-3 short paragraphs, end with a short question.

        Player: \(playerText)
        Draft response: \(draft)

        Return only the rewritten response.
        """
        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renderNarrationPlan(_ plan: NarrationPlanDraft) -> String {
        var parts: [String] = []
        if !plan.segments.isEmpty {
            for segment in plan.segments {
                let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                if segment.channel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "dialogue" {
                    if text.hasPrefix("\"") || text.hasPrefix("“") {
                        parts.append(text)
                    } else {
                        parts.append("\"\(text)\"")
                    }
                } else {
                    parts.append(text)
                }
            }
            return parts.joined(separator: "\n")
        }

        let narration = plan.narrationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !narration.isEmpty {
            parts.append(narration)
        }

        let questions = plan.questionsToPlayer
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !questions.isEmpty {
            parts.append(questions.joined(separator: " "))
        }

        let options = plan.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !options.isEmpty {
            parts.append("Options: " + options.joined(separator: " • "))
        }

        if let ruleSummary = plan.ruleSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !ruleSummary.isEmpty {
            parts.append(ruleSummary)
        }

        return parts.joined(separator: "\n")
    }

    private func buildContextCard(context: NarrationContextPacket) -> String {
        var lines: [String] = []
        lines.append("Scene: \(context.expectedScene)")

        if let location = context.currentLocation {
            lines.append("Location: \(location)")
        }
        if let node = context.currentNode {
            lines.append("Node: \(node)")
        }

        if !context.activeCharacters.isEmpty {
            let names = context.activeCharacters.prefix(4).map { $0.name }
            lines.append("Active Entities: \(names.joined(separator: ", "))")
        }

        if !context.recentPlaces.isEmpty {
            lines.append("Known Places: \(context.recentPlaces.prefix(5).joined(separator: ", "))")
        }
        if !context.recentCuriosities.isEmpty {
            lines.append("Known Facts: \(context.recentCuriosities.prefix(5).joined(separator: ", "))")
        }

        if !context.currentExits.isEmpty {
            lines.append("Exits: \(context.currentExits.joined(separator: " · "))")
        }

        if let intentSummary = coordinator.lastPlayerIntentSummary, !intentSummary.isEmpty {
            lines.append("Player Intent: \(intentSummary)")
        }

        return lines.joined(separator: "\n")
    }

    private func generateCheckConsequence(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        check: SkillCheckDraft,
        result: CheckResult
    ) async throws -> String {
        var prompt = """
        Provide a brief consequence (1-2 sentences) based on the check outcome.
        Keep the story moving and stay grounded.
        If the d20 roll is a natural 20, make it an extraordinary success.
        If the d20 roll is a natural 1, make it a significant failure.

        Scene #\(context.sceneNumber)
        Player action: \(check.playerAction)
        Skill: \(check.request.skillName)
        Reason: \(check.request.reason)
        Outcome: \(result.outcome)
        Stakes on failure: \(check.request.stakes)
        """
        if let roll = check.roll {
            prompt += "\nD20 roll: \(roll)"
        }

        if let partial = check.request.partialSuccessOutcome, !partial.isEmpty {
            prompt += "\nPartial success: \(partial)"
        }

        if shouldForeshadowLine() {
            prompt += "\nAdd a second line starting with \"What you don't see is ...\" about a subtle consequence."
        }

        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendRollHighlight(for check: SkillCheckDraft, outcome: String, total: Int?) {
        let dc = check.request.dc ?? check.request.opponentDC ?? 10
        let totalText = total.map { " (Total \($0))" } ?? ""
        let cleanedOutcome = outcome.replacingOccurrences(of: "_", with: " ")
        let reasonText = check.request.reason.isEmpty ? "" : " Reason: \(check.request.reason)."
        let natMarker: String
        if let roll = check.roll {
            if roll == 1 {
                natMarker = " Nat 1."
            } else if roll == 20 {
                natMarker = " Nat 20."
            } else {
                natMarker = ""
            }
        } else {
            natMarker = ""
        }
        let highlight = "\(check.request.skillName) DC \(dc)\(totalText): \(cleanedOutcome).\(reasonText)\(natMarker)".trimmingCharacters(in: .whitespacesAndNewlines)
        var existing = parseCommaList(coordinator.rollHighlightsInput)
        let normalized = existing.map { $0.lowercased() }
        if !normalized.contains(highlight.lowercased()) {
            existing.append(highlight)
            coordinator.rollHighlightsInput = existing.joined(separator: ", ")
        }
    }

    private func draftSceneSummary() {
        guard let campaign, let currentScene else { return }
        isDraftingSummary = true

        Task {
            defer { isDraftingSummary = false }
            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)
                let context = coordinator.engine.buildNarrationContext(campaign: campaign, scene: currentScene)

                let interactionCount = coordinator.interactionDrafts.count
                let checkCount = coordinator.checkDrafts.count
                let fateCount = coordinator.fateQuestionDrafts.count
                let totalBeats = interactionCount + checkCount + fateCount
                let lengthGuidance: String
                if totalBeats <= 2 {
                    lengthGuidance = "2-3 sentences."
                } else if totalBeats <= 6 {
                    lengthGuidance = "4-6 sentences."
                } else {
                    lengthGuidance = "6-10 sentences."
                }

                var prompt = """
                Draft a concise scene wrap-up with suggestions for characters, threads, places, curiosities, and key rolls.
                Only include important elements that clearly matter later.
                Emphasize why rolls happened and their outcomes; mention totals only for notable nat 1/20 results.
                Only list characters that were explicitly named in the scene; do not invent names.
                Length guidance: \(lengthGuidance)

                Scene #\(context.sceneNumber)
                Expected Scene: \(context.expectedScene)
                Scene Type: \(context.sceneType.rawValue)
                """

                if !coordinator.interactionDrafts.isEmpty {
                    prompt += "\nInteractions:"
                    for interaction in coordinator.interactionDrafts {
                        prompt += "\n- Player: \(interaction.playerText)"
                        if !interaction.gmText.isEmpty {
                            prompt += " / GM: \(interaction.gmText)"
                        }
                    }
                }

                if !coordinator.checkDrafts.isEmpty {
                    prompt += "\nSkill Checks:"
                    for check in coordinator.checkDrafts {
                        let reason = check.request.reason.isEmpty ? "n/a" : check.request.reason
                        let outcome = check.outcome ?? "unknown"
                        prompt += "\n- \(check.playerAction) (\(check.request.skillName)) outcome: \(outcome), reason: \(reason)"
                    }
                }

                if !coordinator.fateQuestionDrafts.isEmpty {
                    prompt += "\nFate Questions:"
                    for fate in coordinator.fateQuestionDrafts {
                        prompt += "\n- \(fate.question) => \(fate.outcome.uppercased())"
                    }
                }

                if !coordinator.canonizationDrafts.isEmpty {
                    prompt += "\nCanonizations:"
                    for canon in coordinator.canonizationDrafts {
                        let outcome = canon.outcome?.uppercased() ?? "PENDING"
                        prompt += "\n- \(canon.assumption) => \(outcome)"
                    }
                }

                let response = try await session.respond(to: Prompt(prompt), generating: SceneWrapUpDraft.self)
                let draft = response.content
                let interactionText = coordinator.interactionDrafts.map { "\($0.playerText) \($0.gmText)" }.joined(separator: " ").lowercased()
                let knownCharacters = campaign.characters.map { $0.name }
                let filteredNewCharacters = filterNames(draft.newCharacters, from: interactionText)
                let filteredFeaturedCharacters = filterNames(draft.featuredCharacters, from: interactionText, allowList: knownCharacters)
                let filteredRemovedCharacters = filterNames(draft.removedCharacters, from: interactionText, allowList: knownCharacters)

                sceneSummaryInput = draft.summary
                newCharactersInput = filteredNewCharacters.joined(separator: ", ")
                newThreadsInput = draft.newThreads.joined(separator: ", ")
                featuredCharactersInput = filteredFeaturedCharacters.joined(separator: ", ")
                featuredThreadsInput = draft.featuredThreads.joined(separator: ", ")
                removeCharactersInput = filteredRemovedCharacters.joined(separator: ", ")
                removeThreadsInput = draft.removedThreads.joined(separator: ", ")
                placesInput = draft.places.joined(separator: ", ")
                curiositiesInput = draft.curiosities.joined(separator: ", ")
                coordinator.rollHighlightsInput = draft.rollHighlights.joined(separator: ", ")
            } catch {
                narrationError = handleFoundationModelsError(error)
            }
        }
    }

    private func filterNames(_ names: [String], from interactionText: String, allowList: [String] = []) -> [String] {
        let allowed = Set(allowList.map { $0.lowercased() })
        return names.filter { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let lower = trimmed.lowercased()
            if allowed.contains(lower) { return true }
            return interactionText.contains(lower)
        }
    }

    private func generateDungeonStart() {
        guard let campaign else { return }
        let location = coordinator.locationEngine.generateDungeonStart(campaign: campaign)
        if location == nil {
            coordinator.gmResponseError = "Could not generate a dungeon location."
            return
        }
        try? modelContext.save()
    }

    private func regenerateActiveLocation() {
        guard let campaign else { return }
        if let activeId = campaign.activeLocationId {
            campaign.locations?.removeAll { $0.id == activeId }
        }
        campaign.activeLocationId = nil
        campaign.activeNodeId = nil
        generateDungeonStart()
    }

    private func traverseEdge(_ edge: LocationEdge, reason: String) {
        guard let campaign else { return }
        _ = coordinator.locationEngine.advanceAlongEdge(campaign: campaign, edge: edge, reason: reason)
        try? modelContext.save()
    }

    private func exitDisplays(for location: LocationEntity, node: LocationNode) -> [ExitDisplay] {
        let exits = (location.edges ?? []).filter { $0.fromNodeId == node.id }
        return exits.map { edge in
            let label = (edge.label?.isEmpty == false) ? (edge.label ?? edge.type.capitalized) : edge.type.capitalized
            let targetSummary: String
            if let toId = edge.toNodeId,
               let target = location.nodes?.first(where: { $0.id == toId }) {
                targetSummary = "Leads to: \(target.summary)"
            } else {
                targetSummary = "Unexplored"
            }
            return ExitDisplay(id: edge.id, label: label, targetSummary: targetSummary, edge: edge)
        }
    }

    private func edgeForExitLabel(
        _ label: String,
        location: LocationEntity,
        node: LocationNode
    ) -> LocationEdge? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let exits = (location.edges ?? []).filter { $0.fromNodeId == node.id }
        return exits.first(where: { edge in
            let edgeLabel = (edge.label?.isEmpty == false) ? (edge.label ?? edge.type) : edge.type
            return edgeLabel.lowercased().contains(trimmed) || edge.type.lowercased().contains(trimmed)
        })
    }

    private func activeLocation(in campaign: Campaign) -> LocationEntity? {
        guard let activeId = campaign.activeLocationId else { return nil }
        return campaign.locations?.first(where: { $0.id == activeId })
    }

    private func activeNode(in campaign: Campaign, location: LocationEntity) -> LocationNode? {
        guard let nodeId = campaign.activeNodeId else { return nil }
        return location.nodes?.first(where: { $0.id == nodeId })
    }

    private func applyPendingLocationFeatures() {
        guard let campaign, let location = activeLocation(in: campaign), let node = activeNode(in: campaign, location: location) else {
            coordinator.pendingLocationFeatures = []
            return
        }

        let existing = (node.features ?? []).map { $0.name.lowercased() }
        var newFeatures: [LocationFeature] = node.features ?? []

        for feature in coordinator.pendingLocationFeatures {
            if existing.contains(feature.name.lowercased()) { continue }
            let item = LocationFeature(
                name: feature.name,
                summary: feature.summary,
                category: "feature",
                tags: nil,
                origin: "ai",
                locationNodeId: node.id
            )
            newFeatures.append(item)
        }

        node.features = newFeatures
        coordinator.pendingLocationFeatures = []
        try? modelContext.save()
    }

    private func draftNextScenePrompt(previousEntry: SceneEntry?) {
        guard let campaign else { return }
        let latestEntry = previousEntry ?? campaign.scenes.sorted { $0.sceneNumber > $1.sceneNumber }.first
        isDraftingNextScene = true
        nextSceneError = nil

        Task {
            defer { isDraftingNextScene = false }
            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)

                var prompt = """
                Draft the next expected scene for a solo RPG.
                Keep it 1-2 sentences, concrete, and easy to play.
                Continue directly from the previous scene's outcome; do not repeat resolved obstacles.
                Do not introduce new NPCs, enemies, or locations here. Those happen during scene play.
                Advance time or position based on the last action.
                Do not ask what the player does next.
                Return only the scene prompt text.
                """

                if let latestEntry {
                    let lastInteraction = latestEntry.interactions?.last?.playerText ?? ""
                    prompt += """

                    Previous Scene #\(latestEntry.sceneNumber)
                    Summary: \(latestEntry.summary)
                    Scene Type: \(latestEntry.sceneType)
                    Chaos Factor: \(latestEntry.chaosFactor)
                    """
                    if !lastInteraction.isEmpty {
                        prompt += "\nLast Action: \(lastInteraction)"
                    }

                    if !latestEntry.places.isEmpty {
                        let placesList = latestEntry.places.joined(separator: ", ")
                        prompt += "\nPlaces: \(placesList)"
                    }

                    if !latestEntry.curiosities.isEmpty {
                        let curiositiesList = latestEntry.curiosities.joined(separator: ", ")
                        prompt += "\nCuriosities: \(curiositiesList)"
                    }

                    if !latestEntry.rollHighlights.isEmpty {
                        let rollsList = latestEntry.rollHighlights.joined(separator: ", ")
                        prompt += "\nRecent Rolls: \(rollsList)"
                    }
                } else {
                    prompt += "\nThere is no previous scene. Provide a short neutral setup snippet."
                }

                if !campaign.characters.isEmpty {
                    let names = campaign.characters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Characters: \(names)"
                }

                if !campaign.threads.isEmpty {
                    let names = campaign.threads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Threads: \(names)"
                }

                if let location = activeLocation(in: campaign) {
                    prompt += "\nCurrent Location: \(location.name) (\(location.type))"
                    if let node = activeNode(in: campaign, location: location) {
                        prompt += "\nCurrent Node: \(node.summary)"
                    }
                }

                let response = try await session.respond(to: Prompt(prompt))
                sceneInput = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                nextSceneError = handleFoundationModelsError(error)
            }
        }
    }

    private func ensureCampaign() {
        if let existing = activeCampaigns.first {
            campaign = existing
            coordinator.engine.ruleset = RulesetCatalog.ruleset(for: existing.rulesetName)
        } else {
            let newCampaign = Campaign()
            newCampaign.rulesetName = coordinator.engine.ruleset.displayName
            newCampaign.contentPackVersion = "solo_default@0.1"
            modelContext.insert(newCampaign)
            campaign = newCampaign
            try? modelContext.save()
        }
    }
}

private struct SceneEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let scene: SceneEntry

    @State private var intent: String
    @State private var summary: String
    @State private var charactersAdded: String
    @State private var charactersFeatured: String
    @State private var charactersRemoved: String
    @State private var threadsAdded: String
    @State private var threadsFeatured: String
    @State private var threadsRemoved: String
    @State private var places: String
    @State private var curiosities: String
    @State private var rollHighlights: String

    init(scene: SceneEntry) {
        self.scene = scene
        _intent = State(initialValue: scene.intent)
        _summary = State(initialValue: scene.summary)
        _charactersAdded = State(initialValue: scene.charactersAdded.joined(separator: ", "))
        _charactersFeatured = State(initialValue: scene.charactersFeatured.joined(separator: ", "))
        _charactersRemoved = State(initialValue: scene.charactersRemoved.joined(separator: ", "))
        _threadsAdded = State(initialValue: scene.threadsAdded.joined(separator: ", "))
        _threadsFeatured = State(initialValue: scene.threadsFeatured.joined(separator: ", "))
        _threadsRemoved = State(initialValue: scene.threadsRemoved.joined(separator: ", "))
        _places = State(initialValue: scene.places.joined(separator: ", "))
        _curiosities = State(initialValue: scene.curiosities.joined(separator: ", "))
        _rollHighlights = State(initialValue: scene.rollHighlights.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Scene") {
                    Text("Scene #\(scene.sceneNumber)")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    TextField("Scene intent", text: $intent, axis: .vertical)
                    TextField("Summary", text: $summary, axis: .vertical)
                }

                Section("Characters") {
                    TextField("New Characters", text: $charactersAdded, axis: .vertical)
                    TextField("Featured Characters", text: $charactersFeatured, axis: .vertical)
                    TextField("Removed Characters", text: $charactersRemoved, axis: .vertical)
                }

                Section("Threads") {
                    TextField("New Threads", text: $threadsAdded, axis: .vertical)
                    TextField("Featured Threads", text: $threadsFeatured, axis: .vertical)
                    TextField("Removed Threads", text: $threadsRemoved, axis: .vertical)
                }

                Section("World Notes") {
                    TextField("Places", text: $places, axis: .vertical)
                    TextField("Curiosities", text: $curiosities, axis: .vertical)
                    TextField("Roll Highlights", text: $rollHighlights, axis: .vertical)
                }
            }
            .navigationTitle("Edit Scene")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyEdits()
                        dismiss()
                    }
                }
            }
        }
    }

    private func applyEdits() {
        scene.intent = intent.trimmingCharacters(in: .whitespacesAndNewlines)
        scene.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        scene.charactersAdded = parseCommaList(charactersAdded)
        scene.charactersFeatured = parseCommaList(charactersFeatured)
        scene.charactersRemoved = parseCommaList(charactersRemoved)
        scene.threadsAdded = parseCommaList(threadsAdded)
        scene.threadsFeatured = parseCommaList(threadsFeatured)
        scene.threadsRemoved = parseCommaList(threadsRemoved)
        scene.places = parseCommaList(places)
        scene.curiosities = parseCommaList(curiosities)
        scene.rollHighlights = parseCommaList(rollHighlights)
        try? modelContext.save()
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

}

#Preview {
    @MainActor in
    NavigationStack {
        SoloScenesView(coordinator: SoloSceneCoordinator())
    }
}
