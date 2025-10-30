import Testing
import Foundation
@testable import DunGen

@MainActor
struct QuestCompletionTests {

    @Test("Retrieval quest does not auto-complete when player only approaches artifact")
    func testRetrievalQuestDoesNotCompleteOnApproach() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        var progress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the sacred artifact",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )
        progress.questObjective = "sacred artifact"
        engine.adventureProgress = progress

        let turn = AdventureTurn(
            adventureProgress: engine.adventureProgress,
            playerPrompt: nil,
            suggestedActions: ["Take the artifact", "Examine the pedestal"],
            currentEnvironment: "Temple Chamber",
            itemsAcquired: nil,
            goldSpent: nil,
            narration: "You see a glowing artifact resting on a pedestal in the center of the chamber."
        )

        await turnProcessor.handleQuestCompletion(
            playerAction: "Follow the light to the source",
            turn: turn,
            questValidator: questValidator
        )

        #expect(engine.adventureProgress?.completed == false, "Quest should not complete when player only approaches artifact")
    }

    @Test("Retrieval quest completes when player takes artifact")
    func testRetrievalQuestCompletesOnTake() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        var progress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the sacred artifact",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )
        progress.questObjective = "sacred artifact"
        engine.adventureProgress = progress

        let turn = AdventureTurn(
            adventureProgress: engine.adventureProgress,
            playerPrompt: nil,
            suggestedActions: ["Take the artifact", "Examine the pedestal"],
            currentEnvironment: "Temple Chamber",
            itemsAcquired: nil,
            goldSpent: nil,
            narration: "You see a glowing artifact resting on a pedestal in the center of the chamber."
        )

        await turnProcessor.handleQuestCompletion(
            playerAction: "Take the sacred artifact",
            turn: turn,
            questValidator: questValidator
        )

        #expect(engine.adventureProgress?.completed == true, "Quest should complete when player takes artifact")
    }

    @Test("Retrieval quest completes when narrative shows acquisition")
    func testRetrievalQuestCompletesOnNarrativeAcquisition() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        var progress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the sacred artifact",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )
        progress.questObjective = "sacred artifact"
        engine.adventureProgress = progress

        let turn = AdventureTurn(
            adventureProgress: engine.adventureProgress,
            playerPrompt: nil,
            suggestedActions: ["Continue"],
            currentEnvironment: "Temple Chamber",
            itemsAcquired: nil,
            goldSpent: nil,
            narration: "📦 Acquired: Sacred Artifact\n\nYou carefully lift the artifact from the pedestal."
        )

        await turnProcessor.handleQuestCompletion(
            playerAction: "Pick up the artifact",
            turn: turn,
            questValidator: questValidator
        )

        #expect(engine.adventureProgress?.completed == true, "Quest should complete when narrative shows acquisition")
    }

    @Test("Retrieval quest does not complete before final encounter")
    func testRetrievalQuestRequiresFinalEncounter() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        engine.adventureProgress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the sacred artifact",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let turn = AdventureTurn(
            adventureProgress: engine.adventureProgress,
            playerPrompt: nil,
            suggestedActions: ["Continue searching"],
            currentEnvironment: "Temple Hallway",
            itemsAcquired: nil,
            goldSpent: nil,
            narration: "You find a clue about the artifact's location."
        )

        await turnProcessor.handleQuestCompletion(
            playerAction: "Take the artifact",
            turn: turn,
            questValidator: questValidator
        )

        #expect(engine.adventureProgress?.completed == false, "Quest should not complete before final encounter")
    }

    @Test("Non-retrieval quest is not handled by auto-completion")
    func testNonRetrievalQuestNotHandled() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        engine.adventureProgress = AdventureProgress(
            locationName: "Dragon Lair",
            adventureStory: "Slay the dragon",
            questGoal: "Defeat the ancient dragon",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let turn = AdventureTurn(
            adventureProgress: engine.adventureProgress,
            playerPrompt: nil,
            suggestedActions: ["Attack", "Flee"],
            currentEnvironment: "Dragon's Den",
            itemsAcquired: nil,
            goldSpent: nil,
            narration: "The dragon roars and prepares to attack."
        )

        await turnProcessor.handleQuestCompletion(
            playerAction: "Take the treasure",
            turn: turn,
            questValidator: questValidator
        )

        #expect(engine.adventureProgress?.completed == false, "Combat quest should not use retrieval auto-completion")
    }

    @Test("Retrieval quest with various artifact keywords")
    func testRetrievalQuestWithVariousKeywords() async {
        let engine = LLMGameEngine(disablePersistence: true)
        engine.setupManagers()
        let turnProcessor = TurnProcessor()
        turnProcessor.gameEngine = engine
        let questValidator = QuestValidator()

        let testCases: [(action: String, objective: String, shouldComplete: Bool, description: String)] = [
            ("Grab the amulet", "amulet", true, "grab + amulet"),
            ("Collect the crown", "crown", true, "collect + crown"),
            ("Retrieve the scroll", "scroll", true, "retrieve + scroll"),
            ("Get the gem", "gem", true, "get + gem"),
            ("Examine the orb", "orb", false, "examine + orb (no completion verb)"),
            ("Walk to the artifact", "artifact", false, "walk + artifact (no completion verb)"),
            ("Take it", "artifact", false, "take without artifact mention")
        ]

        for (action, objective, shouldComplete, description) in testCases {
            var progress = AdventureProgress(
                locationName: "Test Location",
                adventureStory: "Find item",
                questGoal: "Find the lost \(objective)",
                currentEncounter: 5,
                totalEncounters: 5,
                completed: false,
                encounterSummaries: []
            )
            progress.questObjective = objective
            engine.adventureProgress = progress

            let turn = AdventureTurn(
                adventureProgress: engine.adventureProgress,
                playerPrompt: nil,
                suggestedActions: ["Take it"],
                currentEnvironment: "Chamber",
                itemsAcquired: nil,
                goldSpent: nil,
                narration: "You see the item you've been searching for."
            )

            await turnProcessor.handleQuestCompletion(
                playerAction: action,
                turn: turn,
                questValidator: questValidator
            )

            #expect(
                engine.adventureProgress?.completed == shouldComplete,
                "Test case '\(description)': expected completed=\(shouldComplete) for action '\(action)'"
            )
        }
    }
}
