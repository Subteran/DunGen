import Foundation

public enum L10n {
    // MARK: - Helpers
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.current, arguments: args)
    }

    private static func trKey(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }

    // MARK: - Game
    public static let gameWelcome = trKey("game.welcome")
    public static let gameIntroFormat = trKey("game.intro.format")
    public static let startingAttributesFormat = trKey("game.starting.attributes.format")
    public static let errorStartGameFormat = trKey("game.error.start.format")
    public static let errorGenericFormat = trKey("game.error.generic.format")
    public static let statsLineFormat = trKey("game.stats.line.format")
    public static let playerPrefixFormat = trKey("game.player.prefix.format")
    public static let scenePromptFormat = trKey("game.scene.prompt.format")

    // MARK: - System Instructions for LLM
    public static let systemInstructions = trKey("llm.system.instructions")

    // MARK: - Specialist LLM Instructions
    public static let llmWorldInstructions = trKey("llm.world.instructions")
    public static let llmEncounterInstructions = trKey("llm.encounter.instructions")
    public static let llmAdventureInstructions = trKey("llm.adventure.instructions")
    public static let llmCharacterInstructions = trKey("llm.character.instructions")
    public static let llmEquipmentInstructions = trKey("llm.equipment.instructions")
    public static let llmProgressionInstructions = trKey("llm.progression.instructions")
    public static let llmAbilitiesInstructions = trKey("llm.abilities.instructions")
    public static let llmSpellsInstructions = trKey("llm.spells.instructions")
    public static let llmPrayersInstructions = trKey("llm.prayers.instructions")
    public static let llmMonstersInstructions = trKey("llm.monsters.instructions")
    public static let llmNpcInstructions = trKey("llm.npc.instructions")

    // MARK: - UI
    public static let tabGameTitle = trKey("ui.tab.game.title")
    public static let tabCharacterTitle = trKey("ui.tab.character.title")
    public static let tabDataTitle = trKey("ui.tab.data.title")
    public static let onDevice = trKey("ui.ondevice")
    public static let onDeviceUnavailableFormat = trKey("ui.ondevice.unavailable.format")
    public static let inputPlaceholder = trKey("ui.input.placeholder")
    public static let newGame = trKey("ui.newgame")
    public static let newGameConfirmTitle = trKey("ui.newgame.confirm.title")
    public static let newGameConfirmMessage = trKey("ui.newgame.confirm.message")
    public static let newGameConfirmDelete = trKey("ui.newgame.confirm.delete")
    public static let newGameConfirmCancel = trKey("ui.newgame.confirm.cancel")
    public static let actionCustom = trKey("ui.action.custom")
    public static let actionOr = trKey("ui.action.or")

    // MARK: - Character
    public static let characterNoCharacter = trKey("character.no.character")
    public static let characterSectionInfo = trKey("character.section.info")
    public static let characterSectionAttributes = trKey("character.section.attributes")
    public static let characterSectionStats = trKey("character.section.stats")
    public static let characterSectionAbilities = trKey("character.section.abilities")
    public static let characterSectionSpells = trKey("character.section.spells")
    public static let characterSectionInventory = trKey("character.section.inventory")
    public static let characterLabelName = trKey("character.label.name")
    public static let characterLabelRace = trKey("character.label.race")
    public static let characterLabelClass = trKey("character.label.class")
    public static let characterLabelLevel = trKey("character.label.level")
    public static let characterLabelHp = trKey("character.label.hp")
    public static let characterLabelXp = trKey("character.label.xp")
    public static let characterLabelGold = trKey("character.label.gold")
    public static let characterLabelStrength = trKey("character.label.strength")
    public static let characterLabelDexterity = trKey("character.label.dexterity")
    public static let characterLabelConstitution = trKey("character.label.constitution")
    public static let characterLabelIntelligence = trKey("character.label.intelligence")
    public static let characterLabelWisdom = trKey("character.label.wisdom")
    public static let characterLabelCharisma = trKey("character.label.charisma")
    public static let characterEmptyAbilities = trKey("character.empty.abilities")
    public static let characterEmptySpells = trKey("character.empty.spells")
    public static let characterEmptyInventory = trKey("character.empty.inventory")

    // MARK: - Leveling
    public static let levelUpLineFormat = trKey("level.up.line.format")
}
