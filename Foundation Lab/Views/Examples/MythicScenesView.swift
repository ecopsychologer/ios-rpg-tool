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

    private enum AlteredMode: String, CaseIterable {
        case guided
        case manual
    }

    private struct InteractionDraft: Identifiable {
        let id = UUID()
        let playerText: String
        let gmText: String
        let turnSignal: String?
    }

    private struct SkillCheckDraft: Identifiable {
        let id = UUID()
        var playerAction: String
        var request: CheckRequest
        var roll: Int?
        var modifier: Int?
        var total: Int?
        var outcome: String?
        var consequence: String?
    }

    private struct FateQuestionDraftState: Identifiable {
        let id = UUID()
        let question: String
        let likelihood: FateLikelihood
        let chaosFactor: Int
        let roll: Int
        let target: Int
        let outcome: String
        let gmText: String
    }

    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Campaign> { $0.isActive }) private var activeCampaigns: [Campaign]
    @State private var campaign: Campaign?
    @State private var engine = MythicCampaignEngine()
    @AppStorage("mythicAlteredMode") private var alteredModeRaw = AlteredMode.guided.rawValue
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
    @State private var rollHighlightsInput = ""
    @State private var pcsInControl = true
    @State private var adventureConcluded = false
    @State private var sceneSummaryInput = ""
    @State private var isDraftingSummary = false
    @AppStorage("mythicAutoDraftNextScene") private var autoDraftNextScene = false
    @State private var isDraftingNextScene = false
    @State private var nextSceneError: String?

    @State private var narration = ""
    @State private var narrationError: String?
    @State private var isNarrating = false

    @State private var interactionDrafts: [InteractionDraft] = []
    @State private var isResponding = false
    @State private var gmResponseError: String?

    @State private var checkDrafts: [SkillCheckDraft] = []
    @State private var pendingCheckID: UUID?
    @State private var fateQuestionDrafts: [FateQuestionDraftState] = []

    private var alteredMode: AlteredMode {
        AlteredMode(rawValue: alteredModeRaw) ?? .guided
    }

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
        .onAppear(perform: ensureCampaign)
        .navigationTitle("Mythic Scenes")
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

            Text("Use the Mythic-style loop to resolve scenes, track lists, and keep chaos moving.")
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

    private func sceneConversationSection(_ scene: SceneRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("SCENE CONVERSATION")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if interactionDrafts.isEmpty {
                Text("No interactions yet. Describe actions, ask questions, or set up the moment.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(interactionDrafts) { interaction in
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

            if pendingCheckID != nil {
                Text("Awaiting roll result for the last check.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            TextField("Ask a question or describe your action...", text: $sceneInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button(action: { requestGMResponse(scene) }) {
                HStack(spacing: Spacing.small) {
                    if isResponding {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isResponding ? "Waiting..." : "GM Respond")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
            }
            .buttonStyle(.glassProminent)
            .disabled(isResponding || sceneInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = gmResponseError {
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
            TextField("Roll highlights? (comma-separated)", text: $rollHighlightsInput)
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

                            if let places = entry.places, !places.isEmpty {
                                let placesList = places.joined(separator: ", ")
                                Text("Places: \(placesList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let curiosities = entry.curiosities, !curiosities.isEmpty {
                                let curiositiesList = curiosities.joined(separator: ", ")
                                Text("Curiosities: \(curiositiesList)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if let rollHighlights = entry.rollHighlights, !rollHighlights.isEmpty {
                                let rollsList = rollHighlights.joined(separator: ", ")
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
        let record = engine.resolveScene(campaign: campaign, expectedScene: sceneInput.trimmingCharacters(in: .whitespacesAndNewlines))
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
        let interactionModels = interactionDrafts.map { SceneInteraction(playerText: $0.playerText, gmText: $0.gmText, turnSignal: $0.turnSignal) }
        let checkModels = checkDrafts.map { draft in
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
        let fateModels = fateQuestionDrafts.map { draft in
            FateQuestionRecord(
                question: draft.question,
                likelihood: draft.likelihood.rawValue,
                chaosFactor: draft.chaosFactor,
                roll: draft.roll,
                target: draft.target,
                outcome: draft.outcome
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
            rollHighlights: parseCommaList(rollHighlightsInput)
        )

        let savedEntry = engine.finalizeScene(campaign: campaign, scene: currentScene, bookkeeping: bookkeeping)

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
        rollHighlightsInput = ""
        pcsInControl = true
        adventureConcluded = false
        sceneSummaryInput = ""
        nextSceneError = nil
        interactionDrafts = []
        gmResponseError = nil
        checkDrafts = []
        pendingCheckID = nil
        fateQuestionDrafts = []
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

                if !interactionDrafts.isEmpty {
                    prompt += "\nRecent Interaction Highlights:"
                    for interaction in interactionDrafts.suffix(3) {
                        prompt += "\n- Player: \(interaction.playerText)"
                        if !interaction.gmText.isEmpty {
                            prompt += " / GM: \(interaction.gmText)"
                        }
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

    private func requestGMResponse(_ scene: SceneRecord) {
        guard let campaign else { return }
        let trimmed = sceneInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        gmResponseError = nil
        isResponding = true

        Task {
            defer { isResponding = false }

            do {
                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)
                let context = engine.buildNarrationContext(campaign: campaign, scene: scene)

                if let pendingID = pendingCheckID,
                   let index = checkDrafts.firstIndex(where: { $0.id == pendingID }) {
                    let rollDraft = try await session.respond(
                        to: Prompt(makeRollParsingPrompt(playerText: trimmed, check: checkDrafts[index])),
                        generating: CheckRollDraft.self
                    )

                    if rollDraft.content.declines {
                        let gmText = "Got it. We move on without attempting the check."
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        pendingCheckID = nil
                        sceneInput = ""
                        return
                    }

                    guard let roll = rollDraft.content.roll else {
                        let gmText = "I need the roll result (and modifier if any) to resolve that."
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        sceneInput = ""
                        return
                    }

                    let modifier = rollDraft.content.modifier ?? 0
                    checkDrafts[index].roll = roll
                    checkDrafts[index].modifier = modifier

                    let result = engine.evaluateCheck(request: checkDrafts[index].request, roll: roll, modifier: modifier)
                    checkDrafts[index].total = result.total
                    checkDrafts[index].outcome = result.outcome
                    appendRollHighlight(for: checkDrafts[index], outcome: result.outcome, total: result.total)

                    let consequence = try await generateCheckConsequence(
                        session: session,
                        context: context,
                        check: checkDrafts[index],
                        result: result
                    )

                    checkDrafts[index].consequence = consequence
                    let outcomeText = result.outcome.replacingOccurrences(of: "_", with: " ")
                    let gmText = "Result: \(outcomeText) (Total \(result.total)). \(consequence)"
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    pendingCheckID = nil
                    sceneInput = ""
                    return
                }

                if isMetaMessage(trimmed) {
                    let gmText = try await generateNormalGMResponse(session: session, context: context, playerText: trimmed, isMeta: true)
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    sceneInput = ""
                    return
                }

                let intent = try await session.respond(
                    to: Prompt(makeIntentPrompt(playerText: trimmed, context: context)),
                    generating: InteractionIntentDraft.self
                )

                let intentValue = intent.content.intent.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if intentValue == "fate_question" {
                    let fateDraft = try await session.respond(
                        to: Prompt(makeFatePrompt(playerText: trimmed, context: context)),
                        generating: FateQuestionDraft.self
                    )

                    if fateDraft.content.isFateQuestion == false {
                        let gmText = try await generateNormalGMResponse(session: session, context: context, playerText: trimmed, isMeta: false)
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        sceneInput = ""
                        return
                    }

                    guard let likelihood = FateLikelihood.from(name: fateDraft.content.likelihood) else {
                        let gmText = "I couldn't judge the odds. Want to rephrase the question?"
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        sceneInput = ""
                        return
                    }

                    let roll = engine.rollD100()
                    let fateRecord = engine.resolveFateQuestion(
                        question: trimmed,
                        likelihood: likelihood,
                        chaosFactor: campaign.chaosFactor,
                        roll: roll
                    )

                    let gmNarration = try await generateFateNarration(
                        session: session,
                        question: trimmed,
                        outcome: fateRecord.outcome
                    )
                    let gmText = "Fate Roll (\(likelihood.rawValue), CF \(campaign.chaosFactor)): \(fateRecord.roll) vs \(fateRecord.target) => \(fateRecord.outcome.uppercased()). \(gmNarration)"

                    fateQuestionDrafts.append(FateQuestionDraftState(
                        question: trimmed,
                        likelihood: likelihood,
                        chaosFactor: campaign.chaosFactor,
                        roll: fateRecord.roll,
                        target: fateRecord.target,
                        outcome: fateRecord.outcome,
                        gmText: gmText
                    ))

                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    sceneInput = ""
                    return
                }

                if intentValue == "skill_check" {
                    let checkDraft = try await session.respond(
                        to: Prompt(makeCheckProposalPrompt(playerText: trimmed, context: context)),
                        generating: CheckRequestDraft.self
                    )

                    if checkDraft.content.requiresRoll == false {
                        let outcome = checkDraft.content.autoOutcome?.isEmpty == false ? checkDraft.content.autoOutcome! : "success"
                        let gmText = "No roll needed. Automatic outcome: \(outcome)."
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        sceneInput = ""
                        return
                    }

                    guard let request = engine.finalizeCheckRequest(from: checkDraft.content) else {
                        let gmText = "I couldn't settle on a clear check. Want to rephrase?"
                        interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                        sceneInput = ""
                        return
                    }

                    let draft = SkillCheckDraft(playerAction: trimmed, request: request, roll: nil, modifier: nil, total: nil, outcome: nil, consequence: nil)
                    checkDrafts.append(draft)
                    pendingCheckID = draft.id

                    let gmText = gmLineForCheck(request)
                    interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                    sceneInput = ""
                    return
                }

                let gmText = try await generateNormalGMResponse(session: session, context: context, playerText: trimmed, isMeta: false)
                interactionDrafts.append(InteractionDraft(playerText: trimmed, gmText: gmText, turnSignal: "gm_response"))
                sceneInput = ""
            } catch {
                gmResponseError = handleFoundationModelsError(error)
            }
        }
    }

    private func gmLineForCheck(_ request: CheckRequest) -> String {
        let skillName = request.skillName
        let ability = request.abilityOverride ?? engine.ruleset.defaultAbility(for: skillName) ?? "Ability"
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
        line += " Want to attempt it?"
        return line
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

    private func makeIntentPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Classify the player's message into one of: fate_question, skill_check, normal.
        Use fate_question only for yes/no questions about the world.
        Use skill_check for action attempts that could require a roll.
        Otherwise use normal.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return an InteractionIntentDraft.
        """
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

    private func makeCheckProposalPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Propose a ruleset-based skill check for a solo RPG.
        - Roll only if the action is uncertain and consequential.
        - No roll for trivial or guaranteed actions; set requiresRoll to false and give autoOutcome.
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
        Ruleset: \(engine.ruleset.displayName)
        Available skills: \(engine.ruleset.skillNames.joined(separator: ", "))
        """
    }

    private func makeRollParsingPrompt(playerText: String, check: SkillCheckDraft) -> String {
        """
        The player is responding to a pending skill check.
        Extract the d20 roll and modifier if present. If they decline, set declines to true.
        If no roll is provided, leave roll as null.

        Check: \(check.request.skillName) DC \(check.request.dc ?? check.request.opponentDC ?? 10)
        Player: \(playerText)

        Return a CheckRollDraft.
        """
    }

    private func generateNormalGMResponse(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        playerText: String,
        isMeta: Bool
    ) async throws -> String {
        var prompt = """
        You are the game master in a solo RPG. Respond conversationally.
        Do not roll dice or change state. Ask clarifying questions when needed.
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
        }

        if !context.activeCharacters.isEmpty {
            let names = context.activeCharacters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Characters: \(names)"
        }

        if !context.activeThreads.isEmpty {
            let names = context.activeThreads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
            prompt += "\nActive Threads: \(names)"
        }

        if !context.recentPlaces.isEmpty {
            prompt += "\nRecent Places: \(context.recentPlaces.joined(separator: ", "))"
        }

        if !context.recentCuriosities.isEmpty {
            prompt += "\nRecent Curiosities: \(context.recentCuriosities.joined(separator: ", "))"
        }

        if !context.recentRollHighlights.isEmpty {
            prompt += "\nRecent Rolls: \(context.recentRollHighlights.joined(separator: ", "))"
        }

        let response = try await session.respond(to: Prompt(prompt))
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func generateCheckConsequence(
        session: LanguageModelSession,
        context: NarrationContextPacket,
        check: SkillCheckDraft,
        result: CheckResult
    ) async throws -> String {
        var prompt = """
        Provide a brief consequence (1-2 sentences) based on the check outcome.
        Keep the story moving and stay grounded.

        Scene #\(context.sceneNumber)
        Player action: \(check.playerAction)
        Skill: \(check.request.skillName)
        Reason: \(check.request.reason)
        Outcome: \(result.outcome)
        Stakes on failure: \(check.request.stakes)
        """

        if let partial = check.request.partialSuccessOutcome, !partial.isEmpty {
            prompt += "\nPartial success: \(partial)"
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
        var existing = parseCommaList(rollHighlightsInput)
        let normalized = existing.map { $0.lowercased() }
        if !normalized.contains(highlight.lowercased()) {
            existing.append(highlight)
            rollHighlightsInput = existing.joined(separator: ", ")
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
                let context = engine.buildNarrationContext(campaign: campaign, scene: currentScene)

                let interactionCount = interactionDrafts.count
                let checkCount = checkDrafts.count
                let fateCount = fateQuestionDrafts.count
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
                Length guidance: \(lengthGuidance)

                Scene #\(context.sceneNumber)
                Expected Scene: \(context.expectedScene)
                Scene Type: \(context.sceneType.rawValue)
                """

                if !interactionDrafts.isEmpty {
                    prompt += "\nInteractions:"
                    for interaction in interactionDrafts {
                        prompt += "\n- Player: \(interaction.playerText)"
                        if !interaction.gmText.isEmpty {
                            prompt += " / GM: \(interaction.gmText)"
                        }
                    }
                }

                if !checkDrafts.isEmpty {
                    prompt += "\nSkill Checks:"
                    for check in checkDrafts {
                        let reason = check.request.reason.isEmpty ? "n/a" : check.request.reason
                        let outcome = check.outcome ?? "unknown"
                        prompt += "\n- \(check.playerAction) (\(check.request.skillName)) outcome: \(outcome), reason: \(reason)"
                    }
                }

                if !fateQuestionDrafts.isEmpty {
                    prompt += "\nFate Questions:"
                    for fate in fateQuestionDrafts {
                        prompt += "\n- \(fate.question) => \(fate.outcome.uppercased())"
                    }
                }

                let response = try await session.respond(to: Prompt(prompt), generating: SceneWrapUpDraft.self)
                let draft = response.content

                sceneSummaryInput = draft.summary
                newCharactersInput = draft.newCharacters.joined(separator: ", ")
                newThreadsInput = draft.newThreads.joined(separator: ", ")
                featuredCharactersInput = draft.featuredCharacters.joined(separator: ", ")
                featuredThreadsInput = draft.featuredThreads.joined(separator: ", ")
                removeCharactersInput = draft.removedCharacters.joined(separator: ", ")
                removeThreadsInput = draft.removedThreads.joined(separator: ", ")
                placesInput = draft.places.joined(separator: ", ")
                curiositiesInput = draft.curiosities.joined(separator: ", ")
                rollHighlightsInput = draft.rollHighlights.joined(separator: ", ")
            } catch {
                narrationError = handleFoundationModelsError(error)
            }
        }
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
                Keep it 1-3 sentences, concrete, and easy to play.
                Return only the scene prompt text.
                """

                if let latestEntry {
                    prompt += """

                    Previous Scene #\(latestEntry.sceneNumber)
                    Summary: \(latestEntry.summary)
                    Scene Type: \(latestEntry.sceneType)
                    Chaos Factor: \(latestEntry.chaosFactor)
                    """

                    if let places = latestEntry.places, !places.isEmpty {
                        let placesList = places.joined(separator: ", ")
                        prompt += "\nPlaces: \(placesList)"
                    }

                    if let curiosities = latestEntry.curiosities, !curiosities.isEmpty {
                        let curiositiesList = curiosities.joined(separator: ", ")
                        prompt += "\nCuriosities: \(curiositiesList)"
                    }

                    if let rollHighlights = latestEntry.rollHighlights, !rollHighlights.isEmpty {
                        let rollsList = rollHighlights.joined(separator: ", ")
                        prompt += "\nRecent Rolls: \(rollsList)"
                    }
                } else {
                    prompt += "\nThere is no previous scene. Ask the player what they want to do next."
                }

                if !campaign.characters.isEmpty {
                    let names = campaign.characters.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Characters: \(names)"
                }

                if !campaign.threads.isEmpty {
                    let names = campaign.threads.map { "\($0.name) (w=\($0.weight))" }.joined(separator: ", ")
                    prompt += "\nActive Threads: \(names)"
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
        } else {
            let newCampaign = Campaign()
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
        _places = State(initialValue: (scene.places ?? []).joined(separator: ", "))
        _curiosities = State(initialValue: (scene.curiosities ?? []).joined(separator: ", "))
        _rollHighlights = State(initialValue: (scene.rollHighlights ?? []).joined(separator: ", "))
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
        scene.places = parseOptionalList(places)
        scene.curiosities = parseOptionalList(curiosities)
        scene.rollHighlights = parseOptionalList(rollHighlights)
        try? modelContext.save()
    }

    private func parseCommaList(_ input: String) -> [String] {
        input.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func parseOptionalList(_ input: String) -> [String]? {
        let values = parseCommaList(input)
        return values.isEmpty ? nil : values
    }
}

#Preview {
    NavigationStack {
        MythicScenesView()
    }
}
