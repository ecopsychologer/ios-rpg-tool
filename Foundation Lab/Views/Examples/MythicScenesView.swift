import FoundationModels
import SwiftUI
import SwiftData

struct MythicScenesView: View {
    private enum ScenePhase {
        case setup
        case resolved
        case bookkeeping
        case concluded
    }

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Campaign> { $0.isActive }) private var activeCampaigns: [Campaign]
    @State private var campaign: Campaign?
    @State private var engine = MythicCampaignEngine()
    @State private var phase: ScenePhase = .setup
    @State private var expectedScene = ""
    @State private var currentScene: SceneRecord?

    @State private var selectedMethod: AlterationMethod?
    @State private var selectedAdjustment: SceneAdjustment = .raiseStakes

    @State private var newCharactersInput = ""
    @State private var newThreadsInput = ""
    @State private var featuredCharactersInput = ""
    @State private var featuredThreadsInput = ""
    @State private var removeCharactersInput = ""
    @State private var removeThreadsInput = ""
    @State private var pcsInControl = true
    @State private var adventureConcluded = false
    @State private var sceneSummaryInput = ""

    @State private var narration = ""
    @State private var narrationError: String?
    @State private var isNarrating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                headerSection
                sceneSetupSection

                if let scene = currentScene {
                    sceneSummarySection(scene)

                    if scene.type == .altered {
                        alteredSceneSection(scene)
                    }

                    if scene.type == .interrupt {
                        interruptSceneSection(scene)
                    }

                    narrationSection(scene)
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
        .onAppear(perform: ensureCampaign)
        .navigationTitle("Mythic Scenes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .navigationSubtitle("Resolve scenes with Apple Intelligence")
#endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("RESOLVING SCENES")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Text("Use the Mythic-style loop to resolve scenes, track lists, and keep chaos moving.")
                .font(.callout)
                .foregroundColor(.secondary)
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

            TextEditor(text: $expectedScene)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.medium)
                .frame(minHeight: 90)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .disabled(phase != .setup)

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
        .disabled(expectedScene.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase != .setup || campaign == nil)
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
                        Text("Scene summary (1-3 lines).")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                            .padding(.leading, 16)
                    }
                }

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
                        }
                    } label: {
                        HStack {
                            Text("Scene \(entry.sceneNumber)")
                            Spacer()
                            Text(entry.sceneType.capitalized)
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
        let record = engine.resolveScene(campaign: campaign, expectedScene: expectedScene.trimmingCharacters(in: .whitespacesAndNewlines))
        currentScene = record
        selectedMethod = nil
        selectedAdjustment = .raiseStakes
        narration = ""
        narrationError = nil
        phase = .resolved
    }

    private func applyAlterationMethod(_ method: AlterationMethod?) {
        guard let method, let currentScene else { return }
        let updated = engine.applyAlterationMethod(scene: currentScene, method: method, adjustment: selectedAdjustment)
        self.currentScene = updated
    }

    private func applySceneAdjustment(_ adjustment: SceneAdjustment) {
        guard let method = selectedMethod, let currentScene else { return }
        let updated = engine.applyAlterationMethod(scene: currentScene, method: method, adjustment: adjustment)
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
        let bookkeeping = BookkeepingInput(
            summary: sceneSummaryInput.trimmingCharacters(in: .whitespacesAndNewlines),
            newCharacters: parseCommaList(newCharactersInput),
            newThreads: parseCommaList(newThreadsInput),
            featuredCharacters: parseCommaList(featuredCharactersInput),
            featuredThreads: parseCommaList(featuredThreadsInput),
            removedCharacters: parseCommaList(removeCharactersInput),
            removedThreads: parseCommaList(removeThreadsInput),
            pcsInControl: pcsInControl,
            concluded: adventureConcluded
        )

        _ = engine.finalizeScene(campaign: campaign, scene: currentScene, bookkeeping: bookkeeping)

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
        }
    }

    private func resetSceneInputs() {
        expectedScene = ""
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
        pcsInControl = true
        adventureConcluded = false
        sceneSummaryInput = ""
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
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
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

                let context = engine.buildNarrationContext(campaign: campaign, scene: scene)
                var prompt = """
                You are the game master. In 2-4 lines, narrate the scene opener using the details below.
                Keep it punchy and actionable. Avoid lore dumps.
                Ask clarifying questions if the context is ambiguous.

                Scene #\(context.sceneNumber)
                Expected Scene: \(context.expectedScene)
                Chaos Factor: \(context.chaosFactor)
                Roll: \(context.roll)
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

                if !context.recentScenes.isEmpty {
                    prompt += "\nRecent Scenes:"
                    for entry in context.recentScenes {
                        prompt += "\n- Scene \(entry.sceneNumber): \(entry.summary)"
                    }
                }

                let response = try await session.respond(to: Prompt(prompt))
                narration = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func ensureCampaign() {
        if let existing = activeCampaigns.first {
            campaign = existing
        } else {
            let newCampaign = Campaign()
            modelContext.insert(newCampaign)
            campaign = newCampaign
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        MythicScenesView()
    }
}
