import Foundation

@MainActor
@Observable
final class CombatManager {
    var inCombat: Bool = false
    var currentMonster: MonsterDefinition?
    var currentMonsterHP: Int = 0
    var pendingMonster: MonsterDefinition?

    var monstersDefeated: Int = 0

    private weak var gameEngine: LLMGameEngine?

    init() {}

    func setGameEngine(_ engine: LLMGameEngine) {
        self.gameEngine = engine
    }

    var isFirstCombatAction = false

    func enterCombat(with monster: MonsterDefinition) {
        inCombat = true
        currentMonster = monster
        currentMonsterHP = monster.hp
        pendingMonster = nil
        isFirstCombatAction = true
        gameEngine?.appendModel("\n⚔️ Combat initiated with \(monster.fullName)!")
    }

    func performCombatAction(_ action: String) {
        guard let monster = currentMonster, var char = gameEngine?.character else { return }

        var monsterAlreadyAttacked = false

        // Handle initiative on first combat action
        if isFirstCombatAction {
            isFirstCombatAction = false

            // Initiative roll: 70% chance player attacks first
            let playerWinsInitiative = Int.random(in: 1...10) <= 7

            if playerWinsInitiative {
                gameEngine?.appendModel("⚡ You strike first!")
            } else {
                gameEngine?.appendModel("⚠️ The \(monster.fullName) strikes first!")
                let damage = Int.random(in: 2...8)
                char.hp -= damage
                gameEngine?.character = char
                gameEngine?.appendModel("💔 \(monster.fullName) dealt \(damage) damage to you!")

                if char.hp <= 0 {
                    gameEngine?.checkDeath()
                    inCombat = false
                    currentMonster = nil
                    return
                }

                monsterAlreadyAttacked = true
            }
        }

        // Player attacks
        let damageToMonster = Int.random(in: 5...15)
        currentMonsterHP -= damageToMonster
        gameEngine?.appendModel("You dealt \(damageToMonster) damage to \(monster.fullName)!")

        if currentMonsterHP <= 0 {
            gameEngine?.appendModel("✅ \(monster.fullName) defeated!")
            monstersDefeated += 1

            // Check if player also died from earlier damage
            if char.hp <= 0 {
                gameEngine?.checkDeath()
            } else {
                gameEngine?.applyMonsterDefeatRewards(monster: monster)
            }

            inCombat = false
            currentMonster = nil
            return
        }

        // Monster counter-attacks (if it hasn't already)
        if !monsterAlreadyAttacked {
            let damageToPlayer = Int.random(in: 2...8)
            char.hp -= damageToPlayer
            gameEngine?.character = char
            gameEngine?.appendModel("💔 \(monster.fullName) dealt \(damageToPlayer) damage to you!")

            gameEngine?.checkDeath()
        }
    }

    func fleeCombat() -> Bool {
        let fleeChance = Int.random(in: 1...100)
        if fleeChance > 40 {
            gameEngine?.appendModel("🏃 You successfully fled from combat!")
            inCombat = false
            currentMonster = nil
            return true
        } else {
            gameEngine?.appendModel("❌ Failed to flee!")

            if let monster = currentMonster, var char = gameEngine?.character {
                let damageToPlayer = Int.random(in: 2...8)
                char.hp -= damageToPlayer
                gameEngine?.character = char
                gameEngine?.appendModel("💔 \(monster.fullName) dealt \(damageToPlayer) damage as you tried to escape!")
                gameEngine?.checkDeath()
            }
            return false
        }
    }

    func surrenderCombat() {
        guard var char = gameEngine?.character else { return }
        gameEngine?.appendModel("🏳️ You surrender to your fate...")
        char.hp = 0
        gameEngine?.character = char
        inCombat = false
        currentMonster = nil
        gameEngine?.checkDeath()
    }

    func reset() {
        inCombat = false
        currentMonster = nil
        currentMonsterHP = 0
        pendingMonster = nil
    }
}
