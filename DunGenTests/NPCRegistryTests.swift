import Testing
import Foundation
@testable import DunGen

@MainActor
struct NPCRegistryTests {

    @Test("Register and retrieve NPC by ID")
    func testRegisterAndGetNPCByID() {
        let registry = NPCRegistry()
        let npc = NPCDefinition(
            name: "Blacksmith",
            occupation: "Smith",
            appearance: "Muscular",
            personality: "Gruff",
            location: "Forge",
            backstory: "Sells weapons",
            relationshipStatus: "neutral",
            interactionCount: 0
        )

        registry.registerNPC(npc, location: "Village")
        let retrieved = registry.getNPC(byID: npc.id)

        #expect(retrieved != nil)
        #expect(retrieved?.name == "Blacksmith")
        #expect(retrieved?.occupation == "Smith")
    }

    @Test("Get non-existent NPC returns nil")
    func testGetNonExistentNPC() {
        let registry = NPCRegistry()
        let retrieved = registry.getNPC(byID: "non-existent-id")

        #expect(retrieved == nil)
    }

    @Test("Register multiple NPCs at same location")
    func testRegisterMultipleNPCsAtLocation() {
        let registry = NPCRegistry()
        let npc1 = NPCDefinition(name: "Guard", occupation: "Soldier", appearance: "Armored", personality: "Stern", location: "Gate", backstory: "Guards gate", relationshipStatus: "neutral", interactionCount: 0)
        let npc2 = NPCDefinition(name: "Merchant", occupation: "Trader", appearance: "Well dressed", personality: "Friendly", location: "Market", backstory: "Sells items", relationshipStatus: "friendly", interactionCount: 0)

        registry.registerNPC(npc1, location: "Town")
        registry.registerNPC(npc2, location: "Town")

        let npcs = registry.getNPCs(atLocation: "Town")
        #expect(npcs.count == 2)
    }

    @Test("Get NPCs at location with no NPCs returns empty array")
    func testGetNPCsAtEmptyLocation() {
        let registry = NPCRegistry()
        let npcs = registry.getNPCs(atLocation: "Empty Village")

        #expect(npcs.isEmpty)
    }

    @Test("Register NPC at multiple locations")
    func testRegisterNPCAtMultipleLocations() {
        let registry = NPCRegistry()
        let npc = NPCDefinition(name: "Wanderer", occupation: "Traveler", appearance: "Cloaked", personality: "Mysterious", location: "Road", backstory: "Travels", relationshipStatus: "neutral", interactionCount: 0)

        registry.registerNPC(npc, location: "Forest")
        registry.registerNPC(npc, location: "Mountain")

        let forestNPCs = registry.getNPCs(atLocation: "Forest")
        let mountainNPCs = registry.getNPCs(atLocation: "Mountain")

        #expect(forestNPCs.count == 1)
        #expect(mountainNPCs.count == 1)
        #expect(forestNPCs.first?.name == "Wanderer")
        #expect(mountainNPCs.first?.name == "Wanderer")
    }

    @Test("Register same NPC at same location twice doesn't duplicate")
    func testRegisterSameNPCTwiceNoDuplicate() {
        let registry = NPCRegistry()
        let npc = NPCDefinition(name: "Innkeeper", occupation: "Barkeep", appearance: "Rotund", personality: "Jovial", location: "Inn", backstory: "Runs inn", relationshipStatus: "friendly", interactionCount: 0)

        registry.registerNPC(npc, location: "Village")
        registry.registerNPC(npc, location: "Village")

        let npcs = registry.getNPCs(atLocation: "Village")
        #expect(npcs.count == 1)
    }

    @Test("Get random NPC from location")
    func testGetRandomNPCFromLocation() {
        let registry = NPCRegistry()
        let npc1 = NPCDefinition(name: "NPC1", occupation: "Job1", appearance: "Appearance1", personality: "Trait1", location: "City", backstory: "Info1", relationshipStatus: "neutral", interactionCount: 0)
        let npc2 = NPCDefinition(name: "NPC2", occupation: "Job2", appearance: "Appearance2", personality: "Trait2", location: "City", backstory: "Info2", relationshipStatus: "neutral", interactionCount: 0)

        registry.registerNPC(npc1, location: "City")
        registry.registerNPC(npc2, location: "City")

        let randomNPC = registry.getRandomNPC(atLocation: "City")

        #expect(randomNPC != nil)
        #expect(randomNPC?.name == "NPC1" || randomNPC?.name == "NPC2")
    }

    @Test("Get random NPC from empty location returns nil")
    func testGetRandomNPCFromEmptyLocation() {
        let registry = NPCRegistry()
        let randomNPC = registry.getRandomNPC(atLocation: "Empty Town")

        #expect(randomNPC == nil)
    }

    @Test("Reset clears all NPCs")
    func testResetClearsAllNPCs() {
        let registry = NPCRegistry()
        let npc = NPCDefinition(name: "Test", occupation: "Tester", appearance: "Test", personality: "Test", location: "TestLocation", backstory: "Test", relationshipStatus: "neutral", interactionCount: 0)

        registry.registerNPC(npc, location: "TestLocation")

        #expect(registry.getNPC(byID: npc.id) != nil)
        #expect(registry.getNPCs(atLocation: "TestLocation").count == 1)

        registry.reset()

        #expect(registry.getNPC(byID: npc.id) == nil)
        #expect(registry.getNPCs(atLocation: "TestLocation").isEmpty)
    }

    @Test("Register NPCs at different locations")
    func testRegisterNPCsAtDifferentLocations() {
        let registry = NPCRegistry()
        let npc1 = NPCDefinition(name: "Villager", occupation: "Farmer", appearance: "Simple clothes", personality: "Simple", location: "Village", backstory: "Farms", relationshipStatus: "friendly", interactionCount: 0)
        let npc2 = NPCDefinition(name: "Wizard", occupation: "Mage", appearance: "Robed", personality: "Wise", location: "Tower", backstory: "Magic", relationshipStatus: "neutral", interactionCount: 0)

        registry.registerNPC(npc1, location: "Village")
        registry.registerNPC(npc2, location: "Tower")

        let villageNPCs = registry.getNPCs(atLocation: "Village")
        let towerNPCs = registry.getNPCs(atLocation: "Tower")

        #expect(villageNPCs.count == 1)
        #expect(towerNPCs.count == 1)
        #expect(villageNPCs.first?.name == "Villager")
        #expect(towerNPCs.first?.name == "Wizard")
    }

    @Test("Updating NPC updates registry entry")
    func testUpdatingNPCUpdatesRegistry() {
        let registry = NPCRegistry()
        var npc = NPCDefinition(name: "Merchant", occupation: "Trader", appearance: "Well dressed", personality: "Friendly", location: "Market", backstory: "Sells goods", relationshipStatus: "friendly", interactionCount: 0)

        registry.registerNPC(npc, location: "Market")

        npc.interactionCount = 5
        registry.registerNPC(npc, location: "Market")

        let retrieved = registry.getNPC(byID: npc.id)
        #expect(retrieved?.interactionCount == 5)
    }

    @Test("Get random NPC from location with single NPC returns that NPC")
    func testGetRandomNPCFromLocationWithSingleNPC() {
        let registry = NPCRegistry()
        let npc = NPCDefinition(name: "Hermit", occupation: "Recluse", appearance: "Disheveled", personality: "Grumpy", location: "Cave", backstory: "Lives alone", relationshipStatus: "hostile", interactionCount: 0)

        registry.registerNPC(npc, location: "Cave")

        let randomNPC = registry.getRandomNPC(atLocation: "Cave")

        #expect(randomNPC?.name == "Hermit")
    }
}
