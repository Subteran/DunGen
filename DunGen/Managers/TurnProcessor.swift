import Foundation
import OSLog

@MainActor
final class TurnProcessor {
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "TurnProcessor")

    weak var gameEngine: LLMGameEngine?

    func processAdventureProgress(turn: AdventureTurn) {
        guard let engine = gameEngine else { return }
        guard let progress = turn.adventureProgress else { return }

        if var currentProgress = engine.adventureProgress {
            // Check if this is a new adventure (different location or quest)
            let isNewAdventure = currentProgress.locationName != progress.locationName ||
                                currentProgress.questGoal.isEmpty ||
                                (currentProgress.completed && !progress.completed)

            if isNewAdventure {
                // Replace with new adventure progress entirely
                var initialProgress = progress
                initialProgress.encounterSummaries = []
                engine.adventureProgress = initialProgress

                engine.appendModel("\n🎯 Quest: \(progress.questGoal)")
                engine.appendModel("📍 Location: \(progress.locationName)")
                engine.appendModel("")
            } else {
                // Update existing adventure progress
                if !progress.questGoal.isEmpty && currentProgress.questGoal.isEmpty {
                    currentProgress.questGoal = progress.questGoal
                }
                currentProgress.adventureStory = progress.adventureStory

                // For combat quests, only allow code to mark as complete (via boss defeat)
                // For other quest types, allow LLM to mark as complete
                let questValidator = QuestValidator()
                if questValidator.isCombatQuest(questGoal: currentProgress.questGoal) {
                    // Keep current completed status (don't let LLM override)
                    // Combat quest completion is handled by applyMonsterDefeatRewards
                } else {
                    currentProgress.completed = progress.completed
                }

                engine.adventureProgress = currentProgress
            }
        } else {
            var initialProgress = progress
            initialProgress.encounterSummaries = []
            engine.adventureProgress = initialProgress

            engine.appendModel("\n🎯 Quest: \(progress.questGoal)")
            engine.appendModel("📍 Location: \(progress.locationName)")
            engine.appendModel("")
        }
    }

    func handleQuestCompletion(playerAction: String?, turn: AdventureTurn, questValidator: QuestValidator) async {
        guard let engine = gameEngine else { return }
        guard var currentProgress = engine.adventureProgress else { return }
        guard !currentProgress.completed && currentProgress.isFinalEncounter else { return }
        guard let action = playerAction else { return }
        guard questValidator.isRetrievalQuest(questGoal: currentProgress.questGoal) else { return }

        let actionLower = action.lowercased()
        let narrativeLower = turn.narration.lowercased()
        let completionKeywords = ["claim", "take", "grab", "pick up", "retrieve", "acquire", "collect", "get", "seize", "obtain"]
        let artifactKeywords = ["artifact", "item", "treasure", "relic", "stolen", "amulet", "crown", "scroll", "gem", "orb"]

        let hasCompletionVerb = completionKeywords.contains(where: { actionLower.contains($0) })
        let hasArtifactInAction = artifactKeywords.contains(where: { actionLower.contains($0) })
        let narrativeMentionsAcquisition = narrativeLower.contains("acquired:") ||
                                           narrativeLower.contains("📦 acquired") ||
                                           narrativeLower.contains("obtained:") ||
                                           narrativeLower.contains("you take the") ||
                                           narrativeLower.contains("you claim the") ||
                                           narrativeLower.contains("you grab the")

        if (hasCompletionVerb && hasArtifactInAction) || narrativeMentionsAcquisition {
            logger.info("[Quest] Auto-completing retrieval quest based on player action: '\(action)'")
            currentProgress.completed = true
            engine.adventureProgress = currentProgress
        }
    }

    func handleFinalEncounterCompletion(encounterSummaryGenerator: @escaping (String, String, MonsterDefinition?, NPCDefinition?) -> String) async {
        guard let engine = gameEngine else { return }
        guard let finalProgress = engine.adventureProgress else { return }
        guard finalProgress.isFinalEncounter && finalProgress.completed else { return }

        guard let char = engine.character, char.hp > 0 else {
            logger.warning("[Quest] Character died during final encounter - quest completion denied")
            var failedProgress = finalProgress
            failedProgress.completed = false
            engine.adventureProgress = failedProgress
            return
        }

        engine.appendModel("\n✅ Adventure Complete: \(finalProgress.locationName)")
        engine.adventuresCompleted += 1

        // Update lifetime stats
        engine.totalXPEarned += engine.currentAdventureXP
        engine.totalGoldEarned += engine.currentAdventureGold
        engine.totalMonstersDefeated += engine.currentAdventureMonsters

        if var world = engine.worldState {
            world.locations.removeAll(where: { $0.name == finalProgress.locationName })
            engine.worldState = world
        }

        engine.combatManager.pendingMonster = nil
        engine.activeNPC = nil
        engine.activeNPCTurns = 0

        await engine.generateAdventureSummary(progress: finalProgress)
    }

    func setupMonsterEncounter(monster: MonsterDefinition, turn: AdventureTurn) {
        guard let engine = gameEngine else { return }

        engine.combatManager.pendingMonster = monster
        engine.appendMonsterSprite(monster)
        engine.appendModel("HP: \(monster.hp) | Defense: \(monster.defense)")
        if !monster.abilities.isEmpty {
            engine.appendModel("Abilities: \(monster.abilities.prefix(3).joined(separator: ", "))")
        }

        var combatActions = ["Attack the \(monster.fullName)", "Flee"]
        let nonCombatActions = turn.suggestedActions.filter { action in
            let lowercased = action.lowercased()
            return !lowercased.contains("attack") &&
                   !lowercased.contains("fight") &&
                   !lowercased.contains("engage") &&
                   !lowercased.contains("strike") &&
                   !lowercased.contains("hit")
        }
        if let firstNonCombatAction = nonCombatActions.first {
            combatActions.insert(firstNonCombatAction, at: 1)
        }
        engine.updateSuggestedActions(combatActions)
    }

    func setupTrapEncounter(rewards: ProgressionRewards, turn: AdventureTurn) {
        guard let engine = gameEngine else { return }
        guard rewards.hpDelta < 0 else { return }

        engine.pendingTrap = EncounterStateManager.PendingTrap(damage: abs(rewards.hpDelta), narrative: turn.narration)

        var trapActions = ["Attempt to disarm", "Carefully proceed", "Try to avoid"]
        if let firstAction = turn.suggestedActions.first {
            trapActions.append(firstAction)
        }
        engine.updateSuggestedActions(trapActions)
    }

    func applyXPRewards(rewards: ProgressionRewards, isSocialEncounter: Bool, levelingService: LevelingServiceProtocol) async -> Bool {
        guard let engine = gameEngine else { return false }
        guard var character = engine.character else { return false }

        var justLeveledUp = false

        if isSocialEncounter {
            let clampedXP = min(5, max(2, rewards.xpGain))
            if clampedXP > 0 {
                engine.currentAdventureXP += clampedXP
                let outcome = levelingService.applyXPGain(clampedXP, to: &character)
                engine.character = character
                if outcome.didLevelUp {
                    justLeveledUp = true
                    engine.appendModel(outcome.logLine)
                    if outcome.needsNewAbility {
                        await engine.generateLevelReward(for: character.className, level: outcome.newLevel ?? 1)
                    }
                } else {
                    engine.appendModel("✨ Gained \(clampedXP) XP!")
                }
            }
        } else if rewards.xpGain > 0 {
            engine.currentAdventureXP += rewards.xpGain
            let outcome = levelingService.applyXPGain(rewards.xpGain, to: &character)
            engine.character = character
            if outcome.didLevelUp {
                justLeveledUp = true
                engine.appendModel(outcome.logLine)
                if outcome.needsNewAbility {
                    await engine.generateLevelReward(for: character.className, level: outcome.newLevel ?? 1)
                }
            }
        }

        return justLeveledUp
    }

    func applyHPRewards(rewards: ProgressionRewards, isSocialEncounter: Bool, justLeveledUp: Bool) -> Bool {
        guard let engine = gameEngine else { return false }
        guard var character = engine.character else { return false }

        if !isSocialEncounter && !justLeveledUp && rewards.hpDelta != 0 {
            let hpDelta = rewards.hpDelta
            character.hp += hpDelta
            character.hp = min(character.hp, character.maxHP)
            engine.character = character

            if hpDelta < 0 {
                engine.appendModel("💔 Took \(abs(hpDelta)) damage!")
                engine.checkDeath()
                if engine.characterDied {
                    return true
                }
            } else if hpDelta > 0 {
                engine.appendModel("❤️ Healed \(hpDelta) HP!")
            }
        } else {
            if character.hp < character.maxHP && rewards.hpDelta == 0 {
                character.hp += 1
                character.hp = min(character.hp, character.maxHP)
                engine.character = character
                engine.appendModel("❤️‍🩹 Regenerated 1 HP")
            }
        }

        return false
    }

    func applyGoldRewards(rewards: ProgressionRewards, isSocialEncounter: Bool) {
        guard let engine = gameEngine else { return }
        guard !isSocialEncounter else { return }
        guard rewards.goldGain > 0 else { return }

        let gold = rewards.goldGain
        engine.currentAdventureGold += gold
        engine.character?.gold += gold
        engine.appendModel("💰 Found \(gold) gold!")
    }

    func handleItemAcquisition(turn: AdventureTurn, npc: NPCDefinition?) async {
        guard let engine = gameEngine else { return }
        guard let items = turn.itemsAcquired, !items.isEmpty else { return }

        if let goldCost = turn.goldSpent, goldCost > 0 {
            engine.pendingTransaction = PendingTransaction(items: items, cost: goldCost, npc: npc)
            engine.appendModel("\n💰 Offer: \(items.joined(separator: ", ")) for \(goldCost) gold")

            var transactionActions = ["Buy the items", "Decline the offer"]
            if let firstOther = turn.suggestedActions.first {
                transactionActions.insert(firstOther, at: 1)
            }
            engine.updateSuggestedActions(transactionActions)
        } else {
            for item in items {
                engine.character?.inventory.append(item)
                engine.appendModel("📦 Acquired: \(item)")
            }
            await engine.checkQuestCompletion(itemsAcquired: items)
        }
    }

    func handleLootDistribution(loot: [ItemDefinition], maxInventorySlots: Int) {
        guard let engine = gameEngine else { return }
        guard !loot.isEmpty else { return }

        let totalItems = engine.detailedInventory.count + loot.count
        if totalItems > maxInventorySlots {
            engine.pendingLoot = loot
            engine.needsInventoryManagement = true
            engine.delegate?.engineNeedsInventoryManagement(pendingLoot: loot, currentInventory: engine.detailedInventory)
            engine.appendModel("⚠️ Inventory full! You need to make room for new items.")
        } else {
            for item in loot {
                engine.detailedInventory.append(item)
                engine.character?.inventory.append(item.fullName)
                engine.appendModel("✨ Obtained: \(item.fullName) (\(item.rarity))")
                engine.itemsCollected += 1
            }
        }
    }

    func updateEnvironment(from turn: AdventureTurn, encounterType: String?) {
        guard let engine = gameEngine else { return }
        guard let environment = turn.currentEnvironment else { return }

        let envLower = environment.lowercased()
        let shouldUpdate = envLower.contains("arrive") || envLower.contains("enter") ||
                          envLower.contains("reach") || envLower.contains("village") ||
                          envLower.contains("town") || envLower.contains("city") ||
                          envLower.contains("dungeon") || envLower.contains("castle") ||
                          envLower.contains("cave") || envLower.contains("temple") ||
                          encounterType == "combat" ||
                          encounterType == "social" ||
                          engine.currentEnvironment.isEmpty

        if shouldUpdate {
            engine.currentEnvironment = environment
        }
    }
}
