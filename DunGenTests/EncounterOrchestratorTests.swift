import Testing
import Foundation
@testable import DunGen

@MainActor
struct EncounterOrchestratorTests {

    @Test("Should continue NPC conversation when NPC referenced by name")
    func testShouldContinueConversationWithNPCName() {
        let orchestrator = EncounterOrchestrator()
        let npc = NPCDefinition(
            name: "Gandalf",
            occupation: "Wizard",
            appearance: "Tall with grey beard",
            personality: "Wise",
            location: "Village",
            backstory: "Ancient wizard",
            relationshipStatus: "neutral",
            interactionCount: 0
        )

        let shouldContinue = orchestrator.shouldContinueNPCConversation(
            activeNPC: npc,
            activeNPCTurns: 1,
            playerAction: "ask Gandalf about the quest"
        )

        #expect(shouldContinue == true)
    }

    @Test("Should continue NPC conversation with speech verbs")
    func testShouldContinueConversationWithSpeechVerbs() {
        let orchestrator = EncounterOrchestrator()
        let npc = NPCDefinition(
            name: "Merchant",
            occupation: "Trader",
            appearance: "Well dressed",
            personality: "Friendly",
            location: "Market",
            backstory: "Sells items",
            relationshipStatus: "neutral",
            interactionCount: 0
        )

        let testCases = [
            "speak to the merchant",
            "talk to the merchant",
            "ask the merchant",
            "tell the merchant about my journey"
        ]

        for playerAction in testCases {
            let shouldContinue = orchestrator.shouldContinueNPCConversation(
                activeNPC: npc,
                activeNPCTurns: 1,
                playerAction: playerAction
            )
            #expect(shouldContinue == true, "Should continue with: \(playerAction)")
        }
    }

    @Test("Should not continue NPC conversation after 2 turns")
    func testShouldNotContinueAfterTwoTurns() {
        let orchestrator = EncounterOrchestrator()
        let npc = NPCDefinition(
            name: "Guard",
            occupation: "Soldier",
            appearance: "Armored",
            personality: "Stern",
            location: "Gate",
            backstory: "Guards gate",
            relationshipStatus: "neutral",
            interactionCount: 0
        )

        let shouldContinue = orchestrator.shouldContinueNPCConversation(
            activeNPC: npc,
            activeNPCTurns: 2,
            playerAction: "speak to Guard"
        )

        #expect(shouldContinue == false)
    }

    @Test("Should not continue NPC conversation when not referenced")
    func testShouldNotContinueWhenNotReferenced() {
        let orchestrator = EncounterOrchestrator()
        let npc = NPCDefinition(
            name: "Innkeeper",
            occupation: "Barkeep",
            appearance: "Rotund",
            personality: "Jovial",
            location: "Inn",
            backstory: "Runs inn",
            relationshipStatus: "friendly",
            interactionCount: 0
        )

        let shouldContinue = orchestrator.shouldContinueNPCConversation(
            activeNPC: npc,
            activeNPCTurns: 1,
            playerAction: "explore the dungeon"
        )

        #expect(shouldContinue == false)
    }

    @Test("Should not continue with no active NPC")
    func testShouldNotContinueWithNoActiveNPC() {
        let orchestrator = EncounterOrchestrator()

        let shouldContinue = orchestrator.shouldContinueNPCConversation(
            activeNPC: nil,
            activeNPCTurns: 0,
            playerAction: "speak to someone"
        )

        #expect(shouldContinue == false)
    }

    @Test("NPC name matching is case insensitive")
    func testNPCNameMatchingCaseInsensitive() {
        let orchestrator = EncounterOrchestrator()
        let npc = NPCDefinition(
            name: "Merlin",
            occupation: "Wizard",
            appearance: "Mysterious robes",
            personality: "Mysterious",
            location: "Tower",
            backstory: "Ancient knowledge",
            relationshipStatus: "neutral",
            interactionCount: 0
        )

        let testCases = [
            "ask MERLIN about magic",
            "talk to merlin",
            "tell Merlin my story"
        ]

        for playerAction in testCases {
            let shouldContinue = orchestrator.shouldContinueNPCConversation(
                activeNPC: npc,
                activeNPCTurns: 1,
                playerAction: playerAction
            )
            #expect(shouldContinue == true, "Should match case-insensitively: \(playerAction)")
        }
    }
}
