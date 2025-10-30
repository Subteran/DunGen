import Testing
import Foundation
@testable import DunGen

@MainActor
struct QuestProgressManagerTests {

    @Test("Quest failure check returns true after 3 extra encounters")
    func testQuestFailureAfterThreeExtraEncounters() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dark Forest",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the ancient relic",
            currentEncounter: 10,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let hasFailed = manager.checkQuestFailure(adventure: progress)
        #expect(hasFailed == true)
    }

    @Test("Quest failure check returns false before 3 extra encounters")
    func testQuestNotFailedBeforeThreeExtraEncounters() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dark Forest",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the ancient relic",
            currentEncounter: 9,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let hasFailed = manager.checkQuestFailure(adventure: progress)
        #expect(hasFailed == false)
    }

    @Test("Quest failure check returns false when completed")
    func testQuestNotFailedWhenCompleted() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dark Forest",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the ancient relic",
            currentEncounter: 10,
            totalEncounters: 7,
            completed: true,
            encounterSummaries: []
        )

        let hasFailed = manager.checkQuestFailure(adventure: progress)
        #expect(hasFailed == false)
    }

    @Test("Quest failure check returns false when not at final encounter")
    func testQuestNotFailedBeforeFinalEncounter() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dark Forest",
            adventureStory: "Find the artifact",
            questGoal: "Retrieve the ancient relic",
            currentEncounter: 5,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let hasFailed = manager.checkQuestFailure(adventure: progress)
        #expect(hasFailed == false)
    }

    @Test("Early stage guidance includes setup keywords")
    func testEarlyStageGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Ancient Ruins",
            adventureStory: "Explore ruins",
            questGoal: "Find the lost scroll",
            currentEncounter: 2,
            totalEncounters: 9,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("STAGE-EARLY"))
        #expect(guidance.contains("Intro clues"))
        #expect(guidance.contains(progress.questGoal))
    }

    @Test("Middle stage guidance includes progress keywords")
    func testMiddleStageGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Mountain Pass",
            adventureStory: "Cross mountains",
            questGoal: "Defeat the dragon",
            currentEncounter: 5,
            totalEncounters: 8,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("STAGE-MID"))
        #expect(guidance.contains("Advance"))
        #expect(guidance.contains(progress.questGoal))
    }

    @Test("Final encounter guidance includes critical warning")
    func testFinalEncounterGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dragon's Lair",
            adventureStory: "Confront dragon",
            questGoal: "Defeat the ancient dragon",
            currentEncounter: 6,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("⚠"), "Guidance should contain warning emoji")
        #expect(guidance.contains("FINAL ENC"), "Guidance should contain FINAL ENC, got: \(guidance)")
        #expect(guidance.contains(progress.questGoal), "Guidance should contain quest goal")
    }

    @Test("Extended finale guidance includes turn counter")
    func testExtendedFinaleGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Temple",
            adventureStory: "Find artifact",
            questGoal: "Retrieve the sacred gem",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("FINALE+1"), "Guidance should contain FINALE+1")
        #expect(guidance.contains("8/7"), "Guidance should contain encounter counter 8/7, got: \(guidance)")
    }

    @Test("Final chance guidance warns of quest failure")
    func testFinalChanceGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Castle",
            adventureStory: "Rescue princess",
            questGoal: "Rescue the princess",
            currentEncounter: 9,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("LAST CHANCE"))
        #expect(guidance.contains("FINAL chance"))
        #expect(guidance.contains("Fail if not done"))
    }

    @Test("Completed quest guidance includes completion message")
    func testCompletedQuestGuidance() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Castle",
            adventureStory: "Rescue princess",
            questGoal: "Rescue the princess",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: true,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("QUEST DONE"))
        #expect(guidance.contains(progress.questGoal))
        #expect(guidance.contains("achieved"))
    }

    @Test("Retrieval quest completion instructions mention artifact")
    func testRetrievalQuestCompletionInstructions() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Temple",
            adventureStory: "Find artifact",
            questGoal: "Find the ancient amulet",
            currentEncounter: 7,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("artifact"))
        #expect(guidance.contains("taken"))
    }

    @Test("Combat quest completion instructions mention boss fight")
    func testCombatQuestCompletionInstructions() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Lair",
            adventureStory: "Face dragon",
            questGoal: "Defeat the dragon lord",
            currentEncounter: 8,
            totalEncounters: 8,
            completed: false,
            encounterSummaries: []
        )

        let guidance = manager.buildQuestProgressionGuidance(for: progress)

        #expect(guidance.contains("Boss fight"))
        #expect(guidance.contains("combat"))
    }

    @Test("Failed quest summary has correct structure")
    func testFailedQuestSummary() {
        let manager = QuestProgressManager()
        let progress = AdventureProgress(
            locationName: "Dark Tower",
            adventureStory: "Storm the tower",
            questGoal: "Defeat the dark wizard",
            currentEncounter: 10,
            totalEncounters: 7,
            completed: false,
            encounterSummaries: []
        )

        let summary = manager.createFailedQuestSummary(
            adventure: progress,
            currentAdventureXP: 50,
            currentAdventureGold: 100,
            currentAdventureMonsters: 5,
            recentItems: ["Sword", "Shield"]
        )

        #expect(summary.locationName == "Dark Tower")
        #expect(summary.questGoal == "Defeat the dark wizard")
        #expect(summary.completionSummary.contains("failed"))
        #expect(summary.encountersCompleted == 10)
        #expect(summary.totalXPGained == 50)
        #expect(summary.totalGoldEarned == 100)
        #expect(summary.monstersDefeated == 5)
        #expect(summary.notableItems.count == 2)
    }
}
