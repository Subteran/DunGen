import Foundation
import OSLog

@MainActor
final class PlayerInputHandler {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "PlayerInputHandler")

    weak var gameEngine: LLMGameEngine?

    enum InputResult {
        case handled
        case continueToAdvanceScene(String)
    }

    func handleCharacterNameInput(_ input: String, partialCharacter: CharacterProfile?) async -> Bool {
        guard let engine = gameEngine else { return false }
        guard var partial = partialCharacter else { return false }

        let trimmedName = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            engine.appendModel("Please enter a valid name.")
            return false
        }

        partial.name = trimmedName

        let modifiers = RaceModifiers.modifiers(for: partial.race)
        partial.attributes = modifiers.apply(to: partial.attributes)

        engine.character = partial
        engine.partialCharacter = nil
        engine.awaitingCustomCharacterName = false

        engine.appendModel(L10n.gameWelcome)
        engine.appendCharacterSprite()
        engine.appendModel(String(format: L10n.gameIntroFormat, partial.name, partial.race, partial.className, partial.backstory))
        engine.appendModel(String(format: L10n.startingAttributesFormat,
                           partial.attributes.strength,
                           partial.attributes.dexterity,
                           partial.attributes.constitution,
                           partial.attributes.intelligence,
                           partial.attributes.wisdom,
                           partial.attributes.charisma))

        if let world = engine.worldState {
            engine.appendModel("\nWhere would you like to begin your adventure?")
            engine.updateSuggestedActions(world.locations.map { $0.name })
            engine.awaitingLocationSelection = true
        }

        engine.saveState()
        return true
    }

    func handleFleeFromPendingMonster(_ input: String, pendingMonster: MonsterDefinition) async -> InputResult? {
        guard let engine = gameEngine else { return nil }
        guard !engine.combatManager.inCombat else { return nil }
        guard input.lowercased().contains("flee") else { return nil }

        engine.combatManager.pendingMonster = nil
        engine.appendModel("You attempt to flee from the \(pendingMonster.fullName)!")

        let isAttacked = Bool.random()
        if isAttacked, var character = engine.character {
            let damage = Int.random(in: 2...8)
            character.hp -= damage
            engine.character = character
            engine.appendModel("💔 The \(pendingMonster.fullName) strikes as you flee, dealing \(damage) damage!")

            if character.hp <= 0 {
                engine.handleCharacterDeath(monster: pendingMonster)
                return .handled
            }
        } else {
            engine.appendModel("You successfully escape!")
        }

        return .continueToAdvanceScene("flee from danger")
    }

    func handlePendingTransaction(_ input: String, transaction: PendingTransaction) async -> InputResult? {
        guard let engine = gameEngine else { return nil }

        let inputLower = input.lowercased()

        if inputLower.contains("buy") || inputLower.contains("purchase") || inputLower.contains("yes") || inputLower.contains("accept") {
            guard var char = engine.character else { return nil }

            if char.gold >= transaction.cost {
                char.gold -= transaction.cost
                for item in transaction.items {
                    char.inventory.append(item)
                }
                engine.character = char
                engine.appendModel("💸 Paid \(transaction.cost) gold")
                for item in transaction.items {
                    engine.appendModel("📦 Acquired: \(item)")
                }
                engine.pendingTransaction = nil
                return .handled
            } else {
                engine.appendModel("⚠️ Not enough gold! Need \(transaction.cost) but only have \(char.gold)")
                engine.appendModel("You move on...")
                engine.pendingTransaction = nil
                return .continueToAdvanceScene("continue exploring")
            }
        } else if inputLower.contains("decline") || inputLower.contains("no") || inputLower.contains("refuse") || inputLower.contains("pass") {
            engine.appendModel("You decline the offer.")
            engine.pendingTransaction = nil
            return .continueToAdvanceScene("continue exploring")
        }

        engine.pendingTransaction = nil
        return nil
    }

    func handlePendingMonsterCombat(_ input: String, pendingMonster: MonsterDefinition) async -> InputResult? {
        guard let engine = gameEngine else { return nil }
        guard !engine.combatManager.inCombat else { return nil }

        let inputLower = input.lowercased()

        if inputLower.contains("attack") || inputLower.contains("fight") || inputLower.contains("engage") {
            engine.combatManager.enterCombat(with: pendingMonster)
            return .handled
        }

        let monsterAttacks = await engine.shouldMonsterAttack(monster: pendingMonster, playerAction: input)

        if monsterAttacks, var character = engine.character {
            let damage = Int.random(in: 3...10)
            character.hp -= damage
            engine.character = character
            engine.appendModel("💔 The \(pendingMonster.fullName) attacks while you're distracted, dealing \(damage) damage!")

            if character.hp <= 0 {
                engine.handleCharacterDeath(monster: pendingMonster)
                engine.combatManager.pendingMonster = nil
                return .handled
            }
        } else {
            engine.combatManager.pendingMonster = nil
            engine.appendModel("Your action successfully prevents the \(pendingMonster.fullName) from attacking!")
        }

        return nil
    }

    func handlePendingTrap(_ input: String, trap: EncounterStateManager.PendingTrap) async -> InputResult? {
        guard let engine = gameEngine else { return nil }

        let inputLower = input.lowercased()
        let avoidanceKeywords = ["disarm", "avoid", "careful", "dodge", "jump", "step", "roll", "evade"]
        let attemptedAvoidance = avoidanceKeywords.contains { inputLower.contains($0) }

        if attemptedAvoidance {
            let avoided = Bool.random()
            if avoided {
                engine.appendModel("✅ You successfully avoided the trap!")
                engine.pendingTrap = nil
            } else {
                let reducedDamage = max(1, trap.damage / 2)
                if var character = engine.character {
                    character.hp -= reducedDamage
                    engine.character = character
                    engine.appendModel("💔 You partially avoided the trap, taking \(reducedDamage) damage!")
                    engine.checkDeath()
                    engine.pendingTrap = nil

                    if engine.characterDied {
                        return .handled
                    }
                }
            }
        } else {
            if var character = engine.character {
                character.hp -= trap.damage
                engine.character = character
                engine.appendModel("💔 Took \(trap.damage) damage from the trap!")
                engine.checkDeath()
                engine.pendingTrap = nil

                if engine.characterDied {
                    return .handled
                }
            }
        }

        return .continueToAdvanceScene(input)
    }

    func handleActiveCombat(_ input: String) async -> InputResult? {
        guard let engine = gameEngine else { return nil }
        guard engine.combatManager.inCombat else { return nil }

        if let monster = engine.combatManager.currentMonster, let char = engine.character {
            engine.lastPrompt = "Combat State: \(char.name) (HP: \(char.hp)/\(char.maxHP)) vs \(monster.fullName) (HP: \(engine.combatManager.currentMonsterHP)/\(monster.hp))\nPlayer action: \(input)"
        }

        let inputLower = input.lowercased()

        if inputLower.contains("flee") || inputLower.contains("run") || inputLower.contains("escape") {
            let success = engine.combatManager.fleeCombat()
            if success {
                return .continueToAdvanceScene("fled from combat")
            }
            return .handled
        } else if inputLower.contains("surrender") || inputLower.contains("give up") {
            engine.combatManager.surrenderCombat()
            return .handled
        } else {
            engine.combatManager.performCombatAction(input)
            return .handled
        }
    }

    func handleLocationSelection(_ input: String) async -> InputResult? {
        guard let engine = gameEngine else { return nil }
        guard engine.awaitingLocationSelection else { return nil }
        guard let world = engine.worldState else { return nil }

        guard let selectedLocation = world.locations.first(where: { $0.name.lowercased() == input.lowercased() || input.lowercased().contains($0.name.lowercased()) }) else {
            engine.appendModel("Please choose one of the available locations.")
            engine.updateSuggestedActions(world.locations.map { $0.name })
            return .handled
        }

        // Reset all adventure state for new adventure
        engine.resetAdventureState()

        // Set new location
        engine.currentLocation = selectedLocation.locationType
        engine.currentEnvironment = selectedLocation.name
        engine.awaitingLocationSelection = false

        if var world = engine.worldState {
            if let index = world.locations.firstIndex(where: { $0.name == selectedLocation.name }) {
                world.locations[index].visited = true
            }
            engine.worldState = world
        }

        return .continueToAdvanceScene("")
    }
}
