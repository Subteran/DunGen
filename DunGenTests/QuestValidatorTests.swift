import Testing
import Foundation
@testable import DunGen

@MainActor
struct QuestValidatorTests {

    @Test("Identifies retrieval quest with 'find' keyword")
    func testIsRetrievalQuestFind() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Find the lost amulet") == true)
    }

    @Test("Identifies retrieval quest with 'retrieve' keyword")
    func testIsRetrievalQuestRetrieve() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Retrieve the sacred scroll") == true)
    }

    @Test("Identifies retrieval quest with 'locate' keyword")
    func testIsRetrievalQuestLocate() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Locate the ancient relic") == true)
    }

    @Test("Identifies retrieval quest with 'discover' keyword")
    func testIsRetrievalQuestDiscover() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Discover the hidden treasure") == true)
    }

    @Test("Identifies retrieval quest with 'stolen' keyword")
    func testIsRetrievalQuestStolen() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Recover the stolen gem") == true)
    }

    @Test("Identifies retrieval quest with 'artifact' keyword")
    func testIsRetrievalQuestArtifact() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Secure the artifact") == true)
    }

    @Test("Returns false for non-retrieval quest (combat)")
    func testIsNotRetrievalQuestCombat() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Defeat the dragon") == false)
    }

    @Test("Combat quest with 'defeat' keyword is not retrieval even with 'artifact'")
    func testCombatQuestNotRetrievalWithArtifact() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Defeat the guardian to find the artifact") == false)
        #expect(validator.isCombatQuest(questGoal: "Defeat the guardian to find the artifact") == true)
    }

    @Test("Identifies combat quest with 'defeat' keyword")
    func testIsCombatQuestDefeat() {
        let validator = QuestValidator()
        #expect(validator.isCombatQuest(questGoal: "Defeat the dragon") == true)
    }

    @Test("Identifies combat quest with 'kill' keyword")
    func testIsCombatQuestKill() {
        let validator = QuestValidator()
        #expect(validator.isCombatQuest(questGoal: "Kill the goblin warlord") == true)
    }

    @Test("Identifies combat quest with 'destroy' keyword")
    func testIsCombatQuestDestroy() {
        let validator = QuestValidator()
        #expect(validator.isCombatQuest(questGoal: "Destroy the undead army") == true)
    }

    @Test("Identifies combat quest with 'slay' keyword")
    func testIsCombatQuestSlay() {
        let validator = QuestValidator()
        #expect(validator.isCombatQuest(questGoal: "Slay the ancient beast") == true)
    }

    @Test("Identifies combat quest with 'stop' keyword")
    func testIsCombatQuestStop() {
        let validator = QuestValidator()
        #expect(validator.isCombatQuest(questGoal: "Stop the invading forces") == true)
    }

    @Test("Returns false for non-retrieval quest (rescue)")
    func testIsNotRetrievalQuestRescue() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "Rescue the princess") == false)
    }

    @Test("Keyword matching is case insensitive")
    func testIsRetrievalQuestCaseInsensitive() {
        let validator = QuestValidator()
        #expect(validator.isRetrievalQuest(questGoal: "FIND the ARTIFACT") == true)
        #expect(validator.isRetrievalQuest(questGoal: "Retrieve THE SCROLL") == true)
    }

    @Test("Validates quest completion with matching artifact")
    func testValidateQuestCompletionArtifact() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Ancient Temple",
            adventureStory: "Find the artifact",
            questGoal: "Find the ancient artifact",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Ancient Artifact"]
        )

        #expect(result != nil)
        #expect(result?.questGoal == "Find the ancient artifact")
        #expect(result?.completingItem == "Ancient Artifact")
    }

    @Test("Validates quest completion with stolen item")
    func testValidateQuestCompletionStolen() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Bandit Camp",
            adventureStory: "Recover stolen goods",
            questGoal: "Recover the stolen jewels",
            currentEncounter: 4,
            totalEncounters: 6,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Stolen Jewels"]
        )

        #expect(result != nil)
        #expect(result?.completingItem == "Stolen Jewels")
    }

    @Test("Validates quest completion with item name in quest goal")
    func testValidateQuestCompletionNameMatch() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Dark Forest",
            adventureStory: "Find the crystal",
            questGoal: "Find the moonstone crystal",
            currentEncounter: 6,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Moonstone Crystal"]
        )

        #expect(result != nil)
        #expect(result?.completingItem == "Moonstone Crystal")
    }

    @Test("Returns nil when quest already completed")
    func testValidateQuestCompletionAlreadyCompleted() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Temple",
            adventureStory: "Find artifact",
            questGoal: "Find the sacred artifact",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: true,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Sacred Artifact"]
        )

        #expect(result == nil)
    }

    @Test("Returns nil when no items acquired")
    func testValidateQuestCompletionNoItems() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Temple",
            adventureStory: "Find artifact",
            questGoal: "Find the ancient artifact",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: nil
        )

        #expect(result == nil)
    }

    @Test("Returns nil when items don't match quest goal")
    func testValidateQuestCompletionNoMatch() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Temple",
            adventureStory: "Find amulet",
            questGoal: "Find the golden amulet",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Silver Ring", "Bronze Sword"]
        )

        #expect(result == nil)
    }

    @Test("Returns nil for non-retrieval quest")
    func testValidateQuestCompletionNonRetrieval() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Dragon Lair",
            adventureStory: "Defeat dragon",
            questGoal: "Defeat the ancient dragon",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Dragon Scale"]
        )

        #expect(result == nil)
    }

    @Test("Item name must be longer than 5 chars for generic match")
    func testValidateQuestCompletionShortItemName() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Cave",
            adventureStory: "Find gem",
            questGoal: "Find the rare gem",
            currentEncounter: 4,
            totalEncounters: 6,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["Gem"]
        )

        #expect(result == nil)
    }

    @Test("Case insensitive item matching")
    func testValidateQuestCompletionCaseInsensitive() {
        let validator = QuestValidator()
        let progress = AdventureProgress(
            locationName: "Ruins",
            adventureStory: "Find relic",
            questGoal: "find the ANCIENT relic",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let result = validator.validateQuestCompletion(
            progress: progress,
            itemsAcquired: ["ancient RELIC"]
        )

        #expect(result != nil)
    }
}
