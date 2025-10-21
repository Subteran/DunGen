import Foundation

public enum L10n {
    // MARK: - Helpers
    private static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }()

    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.current, arguments: args)
    }

    private static func trKey(_ key: String) -> String {
        return NSLocalizedString(key, comment: "")
    }

    private static func loadInstructionFile(_ filename: String) -> String {
        let bundle = resourceBundle
        let subdirectory = "LLMInstructions"

        // Try subdirectory first, then fall back to bundle root
        let urlInSubdir = bundle.url(forResource: filename, withExtension: "txt", subdirectory: subdirectory)
        let url = urlInSubdir ?? bundle.url(forResource: filename, withExtension: "txt")

        guard let url, let content = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            var diagnostics = "Searched bundle: \(bundle.bundlePath)\n"
            diagnostics += "Tried: \(subdirectory)/\(filename).txt and \(filename).txt\n"

            if let subdirURLs = bundle.urls(forResourcesWithExtension: "txt", subdirectory: subdirectory) {
                diagnostics += "Found in \(subdirectory): " + subdirURLs.map { $0.lastPathComponent }.joined(separator: ", ") + "\n"
            } else {
                diagnostics += "No \(subdirectory) subdirectory found in bundle.\n"
            }

            if let rootURLs = bundle.urls(forResourcesWithExtension: "txt", subdirectory: nil) {
                diagnostics += "Found in bundle root: " + rootURLs.map { $0.lastPathComponent }.joined(separator: ", ") + "\n"
            }

            fatalError("Failed to load LLM instruction file: \(filename).txt\n" + diagnostics)
            #else
            fatalError("Failed to load LLM instruction file: \(filename).txt")
            #endif
        }

        return content
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

    // MARK: - Specialist LLM Instructions (loaded from files)
    public static let llmWorldInstructions = loadInstructionFile("world")
    public static let llmEncounterInstructions = loadInstructionFile("encounter")
    public static let llmAdventureInstructions = loadInstructionFile("adventure")
    public static let llmCharacterInstructions = loadInstructionFile("character")
    public static let llmEquipmentInstructions = loadInstructionFile("equipment")
    public static let llmProgressionInstructions = loadInstructionFile("progression")
    public static let llmAbilitiesInstructions = loadInstructionFile("abilities")
    public static let llmSpellsInstructions = loadInstructionFile("spells")
    public static let llmPrayersInstructions = loadInstructionFile("prayers")
    public static let llmMonstersInstructions = loadInstructionFile("monsters")
    public static let llmNpcInstructions = loadInstructionFile("npc")

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
