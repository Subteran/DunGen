import Foundation
import FoundationModels
import OSLog

enum LLMSpecialist: String, CaseIterable {
    case world
    case encounter
    case adventure
    case character
    case equipment
    case progression
    case abilities
    case spells
    case prayers
    case monsters
    case npc

    var systemInstructions: String {
        switch self {
        case .world: return L10n.llmWorldInstructions
        case .encounter: return L10n.llmEncounterInstructions
        case .adventure: return L10n.llmAdventureInstructions
        case .character: return L10n.llmCharacterInstructions
        case .equipment: return L10n.llmEquipmentInstructions
        case .progression: return L10n.llmProgressionInstructions
        case .abilities: return L10n.llmAbilitiesInstructions
        case .spells: return L10n.llmSpellsInstructions
        case .prayers: return L10n.llmPrayersInstructions
        case .monsters: return L10n.llmMonstersInstructions
        case .npc: return L10n.llmNpcInstructions
        }
    }
}

@MainActor
final class SpecialistSessionManager {
    private var sessions: [LLMSpecialist: LanguageModelSession] = [:]
    private let logger = Logger(subsystem: "com.yourcompany.DunGen", category: "SpecialistSessionManager")

    private var turnCount = 0
    private let maxTurnsBeforeReset = 15
    private var sessionUsageCount: [LLMSpecialist: Int] = [:]

    func configureSessions() {
        for specialist in LLMSpecialist.allCases {
            sessions[specialist] = LanguageModelSession(instructions: specialist.systemInstructions)
            sessionUsageCount[specialist] = 0
        }
    }

    func getSession(for specialist: LLMSpecialist) -> LanguageModelSession? {
        sessionUsageCount[specialist, default: 0] += 1

        let usageLimit: Int
        switch specialist {
        case .adventure:
            usageLimit = 6
        case .encounter:
            usageLimit = 5
        case .equipment:
            usageLimit = 3
        default:
            usageLimit = 10
        }

        if sessionUsageCount[specialist, default: 0] >= usageLimit {
            logger.info("Resetting \(specialist.rawValue) session after \(self.sessionUsageCount[specialist] ?? 0) uses")
            sessions[specialist] = LanguageModelSession(instructions: specialist.systemInstructions)
            sessionUsageCount[specialist] = 0
        }

        return sessions[specialist]
    }

    func incrementTurnCount() {
        turnCount += 1
    }

    func shouldResetSessions() -> Bool {
        turnCount >= maxTurnsBeforeReset
    }

    func resetIfNeeded() {
        if shouldResetSessions() {
            logger.info("Resetting specialist sessions after \(self.turnCount) turns")
            configureSessions()
            turnCount = 0
        }
    }

    func resetAll() {
        logger.info("Resetting all specialist sessions (new game)")
        configureSessions()
        turnCount = 0
        sessionUsageCount.removeAll()
    }
}
