import Testing
import Foundation
@testable import DunGen

@MainActor
struct InventoryStackingTests {

    @Test("Consumables stack when added to inventory")
    func testConsumablesStack() {
        let inventoryManager = InventoryStateManager()

        let potion1 = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )

        var potion2 = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion2.quantity = 2

        inventoryManager.addItem(potion1)
        #expect(inventoryManager.detailedInventory.count == 1)
        #expect(inventoryManager.detailedInventory[0].quantity == 1)

        inventoryManager.addItem(potion2)
        #expect(inventoryManager.detailedInventory.count == 1)
        #expect(inventoryManager.detailedInventory[0].quantity == 3)
    }

    @Test("Non-consumables do not stack")
    func testNonConsumablesDoNotStack() {
        let inventoryManager = InventoryStateManager()

        let sword1 = ItemDefinition(
            baseName: "Sword",
            prefix: nil,
            suffix: nil,
            itemType: "weapon",
            description: "A sharp blade",
            rarity: "common",
            consumableEffect: nil,
            consumableMinValue: nil,
            consumableMaxValue: nil
        )

        let sword2 = ItemDefinition(
            baseName: "Sword",
            prefix: nil,
            suffix: nil,
            itemType: "weapon",
            description: "A sharp blade",
            rarity: "common",
            consumableEffect: nil,
            consumableMinValue: nil,
            consumableMaxValue: nil
        )

        inventoryManager.addItem(sword1)
        inventoryManager.addItem(sword2)

        #expect(inventoryManager.detailedInventory.count == 2)
    }

    @Test("Different consumables do not stack")
    func testDifferentConsumablesDoNotStack() {
        let inventoryManager = InventoryStateManager()

        let potion = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )

        let bandage = ItemDefinition(
            baseName: "Bandage",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Heals wounds",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 1,
            consumableMaxValue: 3
        )

        inventoryManager.addItem(potion)
        inventoryManager.addItem(bandage)

        #expect(inventoryManager.detailedInventory.count == 2)
    }

    @Test("Display name shows quantity for multiple items")
    func testDisplayNameShowsQuantity() {
        var item = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )

        #expect(item.displayName == "Healing Potion")

        item.quantity = 3
        #expect(item.displayName == "Healing Potion (x3)")

        item.quantity = 10
        #expect(item.displayName == "Healing Potion (x10)")
    }

    @Test("Using consumable decrements quantity")
    func testUsingConsumableDecrementsQuantity() {
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        var character = CharacterProfile(
            name: "Test Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A brave warrior",
            attributes: CharacterProfile.Attributes(
                strength: 15,
                dexterity: 12,
                constitution: 14,
                intelligence: 10,
                wisdom: 10,
                charisma: 10
            ),
            hp: 10,
            maxHP: 15,
            xp: 0,
            gold: 50,
            inventory: ["Healing Potion"],
            abilities: ["Attack"],
            spells: []
        )

        var potion = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion.quantity = 3

        engine.character = character
        engine.detailedInventory = [potion]

        #expect(engine.detailedInventory.count == 1)
        #expect(engine.detailedInventory[0].quantity == 3)

        let success = engine.useItem(itemName: "Healing Potion")
        #expect(success == true)
        #expect(engine.detailedInventory.count == 1)
        #expect(engine.detailedInventory[0].quantity == 2)
    }

    @Test("Using last consumable removes item from inventory")
    func testUsingLastConsumableRemovesItem() {
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        var character = CharacterProfile(
            name: "Test Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A brave warrior",
            attributes: CharacterProfile.Attributes(
                strength: 15,
                dexterity: 12,
                constitution: 14,
                intelligence: 10,
                wisdom: 10,
                charisma: 10
            ),
            hp: 10,
            maxHP: 15,
            xp: 0,
            gold: 50,
            inventory: ["Healing Potion"],
            abilities: ["Attack"],
            spells: []
        )

        var potion = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion.quantity = 1

        engine.character = character
        engine.detailedInventory = [potion]

        #expect(engine.detailedInventory.count == 1)

        let success = engine.useItem(itemName: "Healing Potion")
        #expect(success == true)
        #expect(engine.detailedInventory.count == 0)
        #expect(engine.character?.inventory.count == 0)
    }

    @Test("Starting inventory creates stacked items directly")
    func testStartingInventoryCreatesStackedItems() {
        var healingPotion = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "A small vial of red liquid that restores health when consumed.",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        healingPotion.quantity = 3

        var bandage = ItemDefinition(
            baseName: "Bandage",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "A clean cloth bandage that restores a small amount of health.",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 1,
            consumableMaxValue: 3
        )
        bandage.quantity = 3

        #expect(healingPotion.quantity == 3)
        #expect(bandage.quantity == 3)
        #expect(healingPotion.displayName == "Healing Potion (x3)")
        #expect(bandage.displayName == "Bandage (x3)")
    }

    @Test("Multiple consumable uses correctly decrement")
    func testMultipleUsesDecrementCorrectly() {
        let engine = LLMGameEngine(levelingService: DefaultLevelingService())
        engine.setupManagers()

        var character = CharacterProfile(
            name: "Test Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A brave warrior",
            attributes: CharacterProfile.Attributes(
                strength: 15,
                dexterity: 12,
                constitution: 14,
                intelligence: 10,
                wisdom: 10,
                charisma: 10
            ),
            hp: 5,
            maxHP: 15,
            xp: 0,
            gold: 50,
            inventory: ["Healing Potion"],
            abilities: ["Attack"],
            spells: []
        )

        var potion = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion.quantity = 5

        engine.character = character
        engine.detailedInventory = [potion]

        _ = engine.useItem(itemName: "Healing Potion")
        #expect(engine.detailedInventory[0].quantity == 4)

        _ = engine.useItem(itemName: "Healing Potion")
        #expect(engine.detailedInventory[0].quantity == 3)

        _ = engine.useItem(itemName: "Healing Potion")
        #expect(engine.detailedInventory[0].quantity == 2)

        _ = engine.useItem(itemName: "Healing Potion")
        #expect(engine.detailedInventory[0].quantity == 1)

        _ = engine.useItem(itemName: "Healing Potion")
        #expect(engine.detailedInventory.count == 0, "All potions should be consumed")
    }

    @Test("Adding items with different quantities stacks correctly")
    func testAddingItemsWithDifferentQuantities() {
        let inventoryManager = InventoryStateManager()

        var potion1 = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion1.quantity = 2

        var potion2 = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion2.quantity = 3

        var potion3 = ItemDefinition(
            baseName: "Healing Potion",
            prefix: nil,
            suffix: nil,
            itemType: "consumable",
            description: "Restores health",
            rarity: "common",
            consumableEffect: "hp",
            consumableMinValue: 2,
            consumableMaxValue: 5
        )
        potion3.quantity = 1

        inventoryManager.addItem(potion1)
        #expect(inventoryManager.detailedInventory[0].quantity == 2)

        inventoryManager.addItem(potion2)
        #expect(inventoryManager.detailedInventory[0].quantity == 5)

        inventoryManager.addItem(potion3)
        #expect(inventoryManager.detailedInventory[0].quantity == 6)
        #expect(inventoryManager.detailedInventory.count == 1)
    }
}
