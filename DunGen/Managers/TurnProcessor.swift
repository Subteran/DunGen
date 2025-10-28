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

                // Extract quest objective from quest goal
                if let location = engine.worldState?.locations.first(where: { $0.name == progress.locationName }) {
                    initialProgress.questObjective = QuestObjectiveExtractor.extractObjective(
                        from: progress.questGoal,
                        questType: location.questType
                    )
                }

                engine.adventureProgress = initialProgress

                engine.appendModel("\n🎯 Quest: \(progress.questGoal)")
                engine.appendModel("📍 Location: \(progress.locationName)")
                engine.appendModel("")
            } else {
                // Update existing adventure progress
                if !progress.questGoal.isEmpty && currentProgress.questGoal.isEmpty {
                    currentProgress.questGoal = progress.questGoal

                    // Extract quest objective if not already set
                    if currentProgress.questObjective == nil,
                       let location = engine.worldState?.locations.first(where: { $0.name == currentProgress.locationName }) {
                        currentProgress.questObjective = QuestObjectiveExtractor.extractObjective(
                            from: progress.questGoal,
                            questType: location.questType
                        )
                    }
                }
                currentProgress.adventureStory = progress.adventureStory

                // For combat and retrieval quests, only allow code to mark as complete
                // For other quest types, allow LLM to mark as complete
                let questValidator = QuestValidator()
                if questValidator.isCombatQuest(questGoal: currentProgress.questGoal) {
                    // Keep current completed status (don't let LLM override)
                    // Combat quest completion is handled by applyMonsterDefeatRewards
                } else if questValidator.isRetrievalQuest(questGoal: currentProgress.questGoal) {
                    // Keep current completed status (don't let LLM override)
                    // Retrieval quest completion is handled by handleQuestCompletion
                } else {
                    currentProgress.completed = progress.completed
                }

                engine.adventureProgress = currentProgress
            }
        } else {
            var initialProgress = progress
            initialProgress.encounterSummaries = []

            // Extract quest objective from quest goal
            if let location = engine.worldState?.locations.first(where: { $0.name == progress.locationName }) {
                initialProgress.questObjective = QuestObjectiveExtractor.extractObjective(
                    from: progress.questGoal,
                    questType: location.questType
                )
            }

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

        let actionLower = action.lowercased()
        let narrativeLower = turn.narration.lowercased()

        // Handle retrieval quest completion
        if questValidator.isRetrievalQuest(questGoal: currentProgress.questGoal) {
            let completionKeywords = ["claim", "take", "grab", "pick up", "retrieve", "acquire", "collect", "get", "seize", "obtain"]
            let hasCompletionVerb = completionKeywords.contains(where: { actionLower.contains($0) })

            // Check if the specific quest objective is mentioned in the action or narrative
            var mentionsObjective = false
            if let objective = currentProgress.questObjective {
                let objectiveLower = objective.lowercased()
                mentionsObjective = actionLower.contains(objectiveLower) || narrativeLower.contains(objectiveLower)
            }

            let narrativeMentionsAcquisition = narrativeLower.contains("acquired:") ||
                                               narrativeLower.contains("📦 acquired") ||
                                               narrativeLower.contains("obtained:") ||
                                               narrativeLower.contains("you take the") ||
                                               narrativeLower.contains("you claim the") ||
                                               narrativeLower.contains("you grab the")

            // Complete quest if:
            // 1. Player uses completion verb AND mentions the specific quest objective, OR
            // 2. Narrative explicitly mentions acquisition of the objective
            if (hasCompletionVerb && mentionsObjective) || (narrativeMentionsAcquisition && mentionsObjective) {
                logger.info("[Quest] Auto-completing retrieval quest based on objective '\(currentProgress.questObjective ?? "unknown")' mentioned in action: '\(action)'")
                currentProgress.completed = true
                engine.adventureProgress = currentProgress
            }
        }

        // Handle escort quest completion
        if questValidator.isEscortQuest(questGoal: currentProgress.questGoal) {
            // Extract destination from quest objective (e.g., "merchant caravan" -> destination implied in narrative)
            let destinationKeywords = ["arrive", "reach", "made it", "safely", "destination", "delivered", "escorted"]
            let hasArrival = destinationKeywords.contains(where: { narrativeLower.contains($0) })

            // Check for failure conditions
            let failureKeywords = ["died", "dead", "killed", "lost", "fallen", "perished", "slain"]
            let hasCasualty = failureKeywords.contains(where: { narrativeLower.contains($0) })

            // Check if quest objective is mentioned positively
            var mentionsObjectiveSafely = false
            if let objective = currentProgress.questObjective {
                let objectiveLower = objective.lowercased()
                if narrativeLower.contains(objectiveLower) {
                    // Check if mentioned in context of success (not death/failure)
                    mentionsObjectiveSafely = !hasCasualty
                }
            }

            // Complete quest if: arrived at destination AND no casualties AND objective mentioned
            if hasArrival && !hasCasualty && mentionsObjectiveSafely {
                logger.info("[Quest] Auto-completing escort quest - destination reached safely")
                currentProgress.completed = true
                engine.adventureProgress = currentProgress
            } else if hasCasualty {
                logger.info("[Quest] Escort quest failed - casualties detected")
                // Don't mark as complete - will be handled as failure
            }
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

        // Log transcript metrics for this adventure
        engine.sessionManager.logTranscriptMetrics(for: .adventure)
        engine.sessionManager.logTranscriptMetrics(for: .encounter)

        // Track quest type for variety (use location's questType if available)
        let questType: String
        if let location = engine.worldState?.locations.first(where: { $0.name == finalProgress.locationName }) {
            questType = location.questType
        } else {
            // Fallback: infer from quest goal
            let questValidator = QuestValidator()
            if questValidator.isCombatQuest(questGoal: finalProgress.questGoal) {
                questType = "combat"
            } else if questValidator.isRetrievalQuest(questGoal: finalProgress.questGoal) {
                questType = "retrieval"
            } else if finalProgress.questGoal.lowercased().contains("escort") || finalProgress.questGoal.lowercased().contains("protect") {
                questType = "escort"
            } else if finalProgress.questGoal.lowercased().contains("investigate") || finalProgress.questGoal.lowercased().contains("solve") {
                questType = "investigation"
            } else if finalProgress.questGoal.lowercased().contains("rescue") || finalProgress.questGoal.lowercased().contains("save") {
                questType = "rescue"
            } else if finalProgress.questGoal.lowercased().contains("negotiate") || finalProgress.questGoal.lowercased().contains("diplomacy") {
                questType = "diplomatic"
            } else {
                questType = "other"
            }
        }

        engine.recentQuestTypes.append(questType)
        if engine.recentQuestTypes.count > 5 {
            engine.recentQuestTypes.removeFirst()
        }
        logger.info("[Quest] Completed quest type: \(questType). Recent types: \(engine.recentQuestTypes.joined(separator: ", "))")

        // Update lifetime stats
        engine.totalXPEarned += engine.currentAdventureXP
        engine.totalGoldEarned += engine.currentAdventureGold
        engine.totalMonstersDefeated += engine.currentAdventureMonsters

        // Mark location as completed (don't remove it)
        if var world = engine.worldState {
            if let index = world.locations.firstIndex(where: { $0.name == finalProgress.locationName }) {
                world.locations[index].completed = true
                engine.worldState = world
                logger.info("[Quest] Marked location '\(finalProgress.locationName)' as completed")
            }
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
