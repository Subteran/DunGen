import Testing
import Foundation
@testable import DunGen

@Suite("Game State Persistence Tests")
struct GameStatePersistenceTests {

    @Test("Save and load game state successfully")
    func saveAndLoadState() async throws {
        let persistence = GameStatePersistence(fileName: "test_save.json")

        let character = CharacterProfile(
            name: "Test Hero",
            race: "Human",
            className: "Warrior",
            backstory: "A brave warrior.",
            attributes: .init(strength: 16, dexterity: 14, constitution: 15, intelligence: 10, wisdom: 12, charisma: 11),
            hp: 20,
            maxHP: 20,
            xp: 150,
            gold: 50,
            inventory: ["Sword", "Shield"],
            abilities: ["Power Strike"],
            spells: []
        )

        let logEntries = [
            GameState.SavedLogEntry(id: UUID(), content: "Welcome!", isFromModel: true),
            GameState.SavedLogEntry(id: UUID(), content: "You enter the dungeon.", isFromModel: true)
        ]

        let state = GameState(
            character: character,
            currentLocation: .dungeon,
            log: logEntries
        )

        try persistence.save(state)

        let loadedState = try persistence.load()
        #expect(loadedState != nil)
        #expect(loadedState?.character?.name == "Test Hero")
        #expect(loadedState?.character?.xp == 150)
        #expect(loadedState?.currentLocation == .dungeon)
        #expect(loadedState?.log.count == 2)

        try persistence.delete()
    }

    @Test("Load returns nil when no save file exists")
    func loadNonExistentFile() async throws {
        let persistence = GameStatePersistence(fileName: "nonexistent.json")

        let state = try persistence.load()
        #expect(state == nil)
    }

    @Test("Delete removes save file")
    func deleteStateFile() async throws {
        let persistence = GameStatePersistence(fileName: "test_delete.json")

        let state = GameState(
            character: nil,
            currentLocation: .outdoor,
            log: []
        )

        try persistence.save(state)

        let loadedBefore = try persistence.load()
        #expect(loadedBefore != nil)

        try persistence.delete()

        let loadedAfter = try persistence.load()
        #expect(loadedAfter == nil)
    }

    @Test("Save preserves all character data")
    func savePreservesCharacterData() async throws {
        let persistence = GameStatePersistence(fileName: "test_character.json")

        let character = CharacterProfile(
            name: "Gandalf",
            race: "Wizard",
            className: "Mage",
            backstory: "A wise wizard.",
            attributes: .init(strength: 8, dexterity: 12, constitution: 10, intelligence: 20, wisdom: 18, charisma: 14),
            hp: 15,
            maxHP: 15,
            xp: 500,
            gold: 100,
            inventory: ["Staff of Power", "Robe", "Spell Book"],
            abilities: ["Arcane Knowledge"],
            spells: ["Fireball", "Lightning Bolt", "Shield"]
        )

        let state = GameState(
            character: character,
            currentLocation: .city,
            log: []
        )

        try persistence.save(state)

        let loaded = try persistence.load()
        #expect(loaded?.character?.name == "Gandalf")
        #expect(loaded?.character?.className == "Mage")
        #expect(loaded?.character?.attributes.intelligence == 20)
        #expect(loaded?.character?.inventory.count == 3)
        #expect(loaded?.character?.abilities.count == 1)
        #expect(loaded?.character?.spells.count == 3)

        try persistence.delete()
    }
}
