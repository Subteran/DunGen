import Testing
import Foundation
@testable import DunGen

struct RewardCalculatorTests {

    @Test("Combat rewards - easy difficulty has lower XP multiplier")
    func testCombatRewardsEasy() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "combat",
            difficulty: "easy",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 20,
            isFinalEncounter: false
        )

        let expectedBaseXP = 10 + (5 * 2)
        let expectedXP = Int(Double(expectedBaseXP) * 0.5)

        #expect(rewards.xpGain == expectedXP)
        #expect(rewards.goldGain >= 5 && rewards.goldGain <= 15)
        #expect(rewards.hpDelta >= -3 && rewards.hpDelta <= -1)
    }

    @Test("Combat rewards - normal difficulty")
    func testCombatRewardsNormal() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "combat",
            difficulty: "normal",
            characterLevel: 3,
            currentHP: 15,
            maxHP: 20,
            isFinalEncounter: false
        )

        let expectedBaseXP = 10 + (3 * 2)
        let expectedXP = expectedBaseXP

        #expect(rewards.xpGain == expectedXP)
        #expect(rewards.goldGain >= 10 && rewards.goldGain <= 30)
        #expect(rewards.hpDelta >= -8 && rewards.hpDelta <= -3)
    }

    @Test("Combat rewards - hard difficulty has higher rewards")
    func testCombatRewardsHard() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "combat",
            difficulty: "hard",
            characterLevel: 7,
            currentHP: 25,
            maxHP: 30,
            isFinalEncounter: false
        )

        let expectedBaseXP = 10 + (7 * 2)
        let expectedXP = Int(Double(expectedBaseXP) * 1.5)

        #expect(rewards.xpGain == expectedXP)
        #expect(rewards.goldGain >= 20 && rewards.goldGain <= 50)
        #expect(rewards.hpDelta >= -10 && rewards.hpDelta <= -5)
    }

    @Test("Combat rewards - boss difficulty has highest rewards")
    func testCombatRewardsBoss() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "combat",
            difficulty: "boss",
            characterLevel: 10,
            currentHP: 30,
            maxHP: 40,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain >= 40)
        #expect(rewards.goldGain >= 50 && rewards.goldGain <= 200)
        #expect(rewards.hpDelta >= -20 && rewards.hpDelta <= -8)
        #expect(rewards.shouldDropLoot == true)
    }

    @Test("Social encounter rewards XP only (2-5)")
    func testSocialRewards() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "social",
            difficulty: "normal",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 20,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain >= 2 && rewards.xpGain <= 5)
        #expect(rewards.hpDelta == 0)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Trap rewards scale with character level")
    func testTrapRewardsLevel1() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "trap",
            difficulty: "normal",
            characterLevel: 1,
            currentHP: 10,
            maxHP: 15,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta >= -2 && rewards.hpDelta <= -1)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Trap rewards higher damage at high level")
    func testTrapRewardsLevel10() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "trap",
            difficulty: "normal",
            characterLevel: 10,
            currentHP: 30,
            maxHP: 40,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta >= -10 && rewards.hpDelta <= -5)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Exploration encounter regenerates 1 HP when wounded")
    func testExplorationRewardsWithRegen() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "exploration",
            difficulty: "normal",
            characterLevel: 5,
            currentHP: 15,
            maxHP: 20,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 1)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Exploration encounter no regen at full HP")
    func testExplorationRewardsAtFullHP() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "exploration",
            difficulty: "normal",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 20,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 0)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Puzzle encounter regenerates 1 HP when wounded")
    func testPuzzleRewardsWithRegen() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "puzzle",
            difficulty: "normal",
            characterLevel: 3,
            currentHP: 10,
            maxHP: 15,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 1)
        #expect(rewards.goldGain == 0)
    }

    @Test("Final encounter has high XP and gold rewards")
    func testFinalEncounterRewards() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "final",
            difficulty: "normal",
            characterLevel: 8,
            currentHP: 25,
            maxHP: 30,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain >= 50 && rewards.xpGain <= 100)
        #expect(rewards.hpDelta == 0)
        #expect(rewards.goldGain >= 20 && rewards.goldGain <= 80)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Quest completed on final encounter gives completion rewards")
    func testFinalEncounterFlagOverride() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "combat",
            difficulty: "boss",
            characterLevel: 10,
            currentHP: 30,
            maxHP: 40,
            isFinalEncounter: true,
            currentEncounter: 7,
            totalEncounters: 7,
            questCompleted: true
        )

        #expect(rewards.xpGain >= 50 && rewards.xpGain <= 100)
        #expect(rewards.hpDelta == 0)
        #expect(rewards.goldGain >= 20 && rewards.goldGain <= 80)
        #expect(rewards.shouldDropLoot == false)
    }

    @Test("Unknown encounter type returns zero rewards")
    func testUnknownEncounterType() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "unknown",
            difficulty: "normal",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 20,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 0)
        #expect(rewards.goldGain == 0)
        #expect(rewards.shouldDropLoot == false)
        #expect(rewards.itemDropCount == 0)
    }

    @Test("Stealth encounter regenerates 1 HP when wounded")
    func testStealthRewardsWithRegen() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "stealth",
            difficulty: "normal",
            characterLevel: 4,
            currentHP: 12,
            maxHP: 18,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 1)
        #expect(rewards.goldGain == 0)
    }

    @Test("Chase encounter regenerates 1 HP when wounded")
    func testChaseRewardsWithRegen() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "chase",
            difficulty: "normal",
            characterLevel: 6,
            currentHP: 18,
            maxHP: 25,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain == 0)
        #expect(rewards.hpDelta == 1)
        #expect(rewards.goldGain == 0)
    }

    @Test("Trap damage scales correctly at mid level")
    func testTrapRewardsMidLevel() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "trap",
            difficulty: "normal",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 25,
            isFinalEncounter: false
        )

        #expect(rewards.hpDelta >= -4 && rewards.hpDelta <= -2)
    }

    @Test("Combat encounter type is case insensitive")
    func testCombatCaseInsensitive() {
        let rewards = RewardCalculator.calculateRewards(
            encounterType: "COMBAT",
            difficulty: "NORMAL",
            characterLevel: 5,
            currentHP: 20,
            maxHP: 20,
            isFinalEncounter: false
        )

        #expect(rewards.xpGain > 0)
        #expect(rewards.goldGain > 0)
    }
}
