//
//  FoundationLabApp.swift
//  Foundation Lab
//
//  Created by Rudrank Riyam on 6/9/25.
//

import SwiftUI
import AppIntents
import FoundationModels
import SwiftData

@main
struct FoundationLabApp: App {
    @State private var unavailabilityReason: SystemLanguageModel.Availability.UnavailableReason?
    @State private var showModelUnavailableWarning = false

    var body: some Scene {
        WindowGroup {
            AdaptiveNavigationView()
                .modelContainer(for: [
                    HealthMetric.self,
                    HealthInsight.self,
                    HealthSession.self,
                    Campaign.self,
                    SceneEntry.self,
                    CharacterEntry.self,
                    ThreadEntry.self,
                    SceneInteraction.self,
                    SkillCheckRecord.self,
                    FateQuestionRecord.self,
                    CanonizationRecord.self,
                    Party.self,
                    PartyMember.self,
                    LocationEntity.self,
                    LocationNode.self,
                    LocationEdge.self,
                    TrapEntity.self,
                    SkillCheckEntity.self,
                    EncounterEntity.self,
                    ClueEntity.self,
                    RumorEntity.self,
                    QuestEntity.self,
                    EventLogEntry.self,
                    TableRollRecord.self
                ])
#if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
#endif
                .onAppear {
                    FoundationLabAppShortcuts.updateAppShortcutParameters()
                    checkModelAvailability()
                }
                .tint(.main)
                .sheet(isPresented: $showModelUnavailableWarning) {
                    ModelUnavailableView(reason: unavailabilityReason)
                }
        }
#if os(macOS)
        .defaultSize(width: 1000, height: 700)
#endif
    }

    private func checkModelAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            showModelUnavailableWarning = false
        case .unavailable(let reason):
            unavailabilityReason = reason
            showModelUnavailableWarning = true
        }
    }
}
