import Testing
@testable import DunGen

@Suite("Leveling Tests")
struct LevelingTests {

    // Helper to construct a baseline character
    private func makeCharacter(xp: Int, hp: Int, con: Int) -> CharacterProfile {
        CharacterProfile(
            name: "Test Hero",
            race: "Elf",
            className: "Ranger",
            backstory: "A swift scout from the greenwood.",
            attributes: .init(
                strength: 10,
                dexterity: 14,
                constitution: con,
                intelligence: 12,
                wisdom: 13,
                charisma: 9
            ),
            hp: hp,
            maxHP: hp,
            xp: xp,
            gold: 10,
            inventory: ["Shortbow", "Cloak", "Rations"],
            abilities: ["Track", "Favored Enemy"],
            spells: []
        )
    }

    @Test("Crossing threshold levels up and increases HP")
    func crossingThresholdLevelsUpAndIncreasesHP() async throws {
        // GIVEN a character near the threshold for level 2
        var character = makeCharacter(xp: 90, hp: 11, con: 12)
        let service: LevelingServiceProtocol = DefaultLevelingService()

        // WHEN they gain enough XP to cross the threshold
        let outcome = service.applyXPGain(15, to: &character)

        // THEN XP increases
        #expect(character.xp == 105)
        // AND a level up occurs
        #expect(outcome.didLevelUp == true)
        // AND the new level is 2
        #expect(outcome.newLevel == 2)
        // AND HP increases by at least 1 due to leveling
        #expect(character.maxHP > 11)
        #expect(character.hp == character.maxHP)
        // AND a user-facing log line is provided (content will be localized by the service)
        #expect(!outcome.logLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("XP gain within same level does not level up and does not change HP")
    func noLevelUpWithinSameLevel() async throws {
        var character = makeCharacter(xp: 10, hp: 12, con: 10)
        let service: LevelingServiceProtocol = DefaultLevelingService()

        let outcome = service.applyXPGain(5, to: &character)

        #expect(character.xp == 15)
        #expect(outcome.didLevelUp == false)
        #expect(outcome.newLevel == nil)
        #expect(character.hp == 12)
    }

    @Test("Level computation from XP follows thresholds")
    func levelComputation() async throws {
        let service: LevelingServiceProtocol = DefaultLevelingService()
        // Expected mapping (subject to implementation):
        // Level 1: 0-99, Level 2: 100-299, Level 3: 300-599, etc.
        #expect(service.level(forXP: 0) == 1)
        #expect(service.level(forXP: 99) == 1)
        #expect(service.level(forXP: 100) == 2)
        #expect(service.level(forXP: 250) == 2)
        #expect(service.level(forXP: 300) == 3)
    }

    @Test("Leveling up awards stat points between 1 and 3")
    func levelUpAwardsStatPoints() async throws {
        // GIVEN a character at level 1
        var character = makeCharacter(xp: 90, hp: 11, con: 12)
        let service: LevelingServiceProtocol = DefaultLevelingService()
        let initialStatTotal = character.attributes.strength + character.attributes.dexterity +
                               character.attributes.constitution + character.attributes.intelligence +
                               character.attributes.wisdom + character.attributes.charisma

        // WHEN they level up
        let outcome = service.applyXPGain(15, to: &character)

        // THEN stat points are awarded
        let finalStatTotal = character.attributes.strength + character.attributes.dexterity +
                            character.attributes.constitution + character.attributes.intelligence +
                            character.attributes.wisdom + character.attributes.charisma
        let statPointsGained = finalStatTotal - initialStatTotal

        #expect(outcome.didLevelUp == true)
        #expect(statPointsGained >= 1)
        #expect(statPointsGained <= 3)
    }

    @Test("Stats can grow beyond 20 after leveling up")
    func statsCanGrowBeyond20() async throws {
        // GIVEN a character with high stats near 20
        var character = CharacterProfile(
            name: "Legendary Hero",
            race: "Human",
            className: "Fighter",
            backstory: "Testing stat growth.",
            attributes: .init(
                strength: 19,
                dexterity: 19,
                constitution: 18,
                intelligence: 18,
                wisdom: 19,
                charisma: 20
            ),
            hp: 15,
            maxHP: 15,
            xp: 90,
            gold: 10,
            inventory: [],
            abilities: ["Second Wind", "Action Surge"],
            spells: []
        )
        let service: LevelingServiceProtocol = DefaultLevelingService()

        // WHEN they level up multiple times
        for _ in 0..<10 {
            _ = service.applyXPGain(300, to: &character)
        }

        // THEN at least one stat should exceed 20
        let maxStat = max(
            character.attributes.strength,
            character.attributes.dexterity,
            character.attributes.constitution,
            character.attributes.intelligence,
            character.attributes.wisdom,
            character.attributes.charisma
        )
        #expect(maxStat > 20)
    }
}
