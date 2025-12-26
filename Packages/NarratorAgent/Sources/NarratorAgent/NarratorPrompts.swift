import Foundation
import RPGEngine

public struct NarratorPrompts {
    public init() {}

    public func makeIntentCategoryPrompt(playerText: String, context: NarrationContextPacket) -> String {
        """
        Classify the player's message into one of:
        - player_intent (an action the player wants to attempt)
        - player_question (a question about the world)
        - roleplay_dialogue (in-character dialogue only)
        - gm_command (meta request to the GM)
        - unclear (ambiguous)

        Never assume the player took an action.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)

        Return an IntentCategoryDraft.
        """
    }

    public func makePlayerIntentPrompt(playerText: String, context: NarrationContextPacket, gmRunsCompanionsEnabled: Bool) -> String {
        var prompt = """
        Extract the player's intent without assuming any action occurred.
        Provide a short summary of what they are attempting.
        Only include party members if the player explicitly mentions them.
        If they ask for auto-resolution, set requestedMode to auto_resolve.
        Otherwise use ask_before_rolling.

        Scene #\(context.sceneNumber)
        Scene Type: \(context.sceneType.rawValue)
        Player: \(playerText)
        """

        prompt += "\nGM runs companions: \(gmRunsCompanionsEnabled ? "enabled" : "disabled")"
        prompt += "\nReturn a PlayerIntentDraft."
        return prompt
    }

    public func makeMovementIntentPrompt(playerText: String, context: NarrationContextPacket) -> String {
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

        if let location = context.currentLocation {
            prompt += "\nLocation: \(location)"
        }
        if let node = context.currentNode {
            prompt += "\nCurrent Node: \(node)"
        }
        if !context.currentExits.isEmpty {
            prompt += "\nKnown Exits: \(context.currentExits.joined(separator: " · "))"
        }

        prompt += "\nReturn a MovementIntentDraft."
        return prompt
    }

    public func makeCanonizationPrompt(
        playerText: String,
        context: NarrationContextPacket,
        knownFacts: String
    ) -> String {
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

        if !knownFacts.isEmpty {
            prompt += "\nKnown system facts: \(knownFacts)"
        }

        return prompt
    }

    public func makeFatePrompt(playerText: String, context: NarrationContextPacket) -> String {
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
}
