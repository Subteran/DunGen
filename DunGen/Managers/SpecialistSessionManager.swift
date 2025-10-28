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

    func getTranscript(for specialist: LLMSpecialist) -> Transcript? {
        return sessions[specialist]?.transcript
    }

    func getSession(for specialist: LLMSpecialist) -> LanguageModelSession? {
        sessionUsageCount[specialist, default: 0] += 1

        // Token budget: 4096 total context window
        // Usage limits based on: (4096 - instruction_tokens - response_buffer) / exchange_tokens
        // Formula: ((4096 - instruction_tokens - 200_response) * 4_chars_per_token) / (prompt + response)
        let usageLimit: Int
        switch specialist {
        case .adventure:
            // Instructions: ~936 chars (~234 tokens)
            // Prompt: ~600 chars (~150 tokens)
            // Response: ~1000 chars (~250 tokens) - LLM often exceeds 200 despite instructions
            // Exchange: ~634 tokens
            // Available: 4096 - 234 - 250 = 3612 tokens
            // Max uses: 3612 / 634 = 5.69 ≈ 5 uses
            usageLimit = 5
        case .encounter:
            // ~253 tokens/exchange (1000 chars) = 15 uses max
            usageLimit = 15
        case .equipment:
            // ~380 tokens/exchange (1500 chars) = 10 uses max
            usageLimit = 10
        case .monsters, .npc:
            // ~253 tokens/exchange (1000 chars) = 15 uses max
            usageLimit = 15
        default:
            // ~190 tokens/exchange (750 chars) = 20 uses max
            usageLimit = 20
        }

        if sessionUsageCount[specialist, default: 0] >= usageLimit {
            logger.info("Resetting \(specialist.rawValue) session after \(self.sessionUsageCount[specialist] ?? 0) uses")
            sessions[specialist] = LanguageModelSession(instructions: specialist.systemInstructions)
            sessionUsageCount[specialist] = 0
        }

        // Log transcript metrics
        if let session = sessions[specialist] {
            let transcript = session.transcript
            let entryCount = Array(transcript).count
            logger.debug("[\(specialist.rawValue)] Transcript entries: \(entryCount)")

            if entryCount > 10 {
                logger.warning("[\(specialist.rawValue)] Transcript growing large: \(entryCount) entries")
            }
        }

        return sessions[specialist]
    }

    func recordUse(for specialist: LLMSpecialist) {
        // Log last exchange for debugging with token estimation
        guard let session = sessions[specialist] else { return }
        let transcript = session.transcript

        // Get last prompt and response
        let entries = Array(transcript)
        if entries.count >= 2 {
            let lastTwo = entries.suffix(2)

            if case .prompt(let prompt) = lastTwo.first {
                let promptSize = String(describing: prompt).count
                let estimatedTokens = TokenEstimator.estimateTokens(from: String(describing: prompt))
                logger.debug("[\(specialist.rawValue)] Last prompt: \(promptSize) chars (~\(estimatedTokens) tokens)")
            }

            if case .response(let response) = lastTwo.last {
                let responseSize = String(describing: response).count
                let estimatedTokens = TokenEstimator.estimateTokens(from: String(describing: response))
                logger.debug("[\(specialist.rawValue)] Last response: \(responseSize) chars (~\(estimatedTokens) tokens)")
            }
        }
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

    // MARK: - Transcript Metrics

    func logTranscriptMetrics(for specialist: LLMSpecialist) {
        guard let session = sessions[specialist] else { return }
        let transcript = session.transcript

        let metrics = analyzeTranscript(transcript)
        let instructionSize = specialist.systemInstructions.count
        let usage = TokenEstimator.analyzeUsage(
            instructionSize: instructionSize,
            promptSize: metrics.maxPromptSize,
            conversationHistory: metrics.totalPromptChars + metrics.totalResponseChars
        )

        logger.info("""
        [\(specialist.rawValue)] Transcript Metrics:
          Entries: \(metrics.entryCount)
          Prompts: \(metrics.promptCount)
          Avg Prompt: \(metrics.avgPromptSize) chars (~\(TokenEstimator.estimateTokens(from: String(repeating: "x", count: metrics.avgPromptSize))) tokens)
          Max Prompt: \(metrics.maxPromptSize) chars (~\(TokenEstimator.estimateTokens(from: String(repeating: "x", count: metrics.maxPromptSize))) tokens)
          Token Usage: \(usage.totalTokens)/4096 (\(Int(usage.percentUsed * 100))%)
          Over 600 chars: \(metrics.over600Count)
        """)

        if !usage.isHealthy {
            logger.warning("[\(specialist.rawValue)] ⚠️ Context usage: \(usage.warnings.joined(separator: ", "))")
        }
    }

    func logAllTranscriptMetrics() {
        logger.info("=== Transcript Metrics Summary ===")
        for specialist in LLMSpecialist.allCases {
            logTranscriptMetrics(for: specialist)
        }
    }

    private func analyzeTranscript(_ transcript: Transcript) -> TranscriptMetrics {
        var metrics = TranscriptMetrics()

        for entry in transcript {
            metrics.entryCount += 1

            if case .prompt(let prompt) = entry {
                metrics.promptCount += 1
                let promptText = String(describing: prompt)
                metrics.totalPromptChars += promptText.count
                metrics.maxPromptSize = max(metrics.maxPromptSize, promptText.count)

                if promptText.count > 500 {
                    metrics.over500Count += 1
                }
                if promptText.count > 600 {
                    metrics.over600Count += 1
                }
            } else if case .response(let response) = entry {
                let responseText = String(describing: response)
                metrics.totalResponseChars += responseText.count
            }
        }

        if metrics.promptCount > 0 {
            metrics.avgPromptSize = metrics.totalPromptChars / metrics.promptCount
        }

        return metrics
    }

    struct TranscriptMetrics {
        var entryCount: Int = 0
        var promptCount: Int = 0
        var totalPromptChars: Int = 0
        var totalResponseChars: Int = 0
        var avgPromptSize: Int = 0
        var maxPromptSize: Int = 0
        var over500Count: Int = 0
        var over600Count: Int = 0
    }
}
