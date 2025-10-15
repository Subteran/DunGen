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

    func enterCombat(with monster: MonsterDefinition) {
        inCombat = true
        currentMonster = monster
        currentMonsterHP = monster.hp
        pendingMonster = nil
        gameEngine?.appendModel("\n⚔️ Combat initiated with \(monster.fullName)!")
    }

    func performCombatAction(_ action: String) {
        guard let monster = currentMonster, var char = gameEngine?.character else { return }

        let damageToMonster = Int.random(in: 5...15)
        currentMonsterHP -= damageToMonster
        gameEngine?.appendModel("You dealt \(damageToMonster) damage to \(monster.fullName)!")

        if currentMonsterHP <= 0 {
            gameEngine?.appendModel("✅ \(monster.fullName) defeated!")
            monstersDefeated += 1
            inCombat = false
            currentMonster = nil
            return
        }

        let damageToPlayer = Int.random(in: 3...12)
        char.hp -= damageToPlayer
        gameEngine?.character = char
        gameEngine?.appendModel("💔 \(monster.fullName) dealt \(damageToPlayer) damage to you!")

        gameEngine?.checkDeath()
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
