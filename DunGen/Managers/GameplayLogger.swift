import Foundation
import OSLog

struct GameplaySession: Codable {
    let sessionId: String
    let startTime: Date
    var endTime: Date?

    var characterName: String
    var characterClass: String
    var characterRace: String
    var finalLevel: Int
    var finalHP: Int

    var questType: String
    var questGoal: String
    var questCompleted: Bool
    var questDuration: TimeInterval

    var totalEncounters: Int
    var encounterBreakdown: [String: Int]
    var narrativeSamples: [NarrativeSample]

    var totalXPGained: Int
    var totalGoldEarned: Int
    var monstersDefeated: Int
    var itemsCollected: Int

    var deathOccurred: Bool
    var deathCause: String?
    var deathEncounter: Int?

    struct NarrativeSample: Codable {
        let encounterNumber: Int
        let encounterType: String
        let difficulty: String
        let playerAction: String
        let llmPrompt: String
        let llmResponse: String
        let responseLength: Int
        let hadCombatVerbs: Bool
        let questStage: String
    }
}

final class GameplayLogger {
    private let logger = Logger(subsystem: "com.logicchaos.DunGen", category: "GameplayLogger")
    private var currentSession: GameplaySession?

    private let fileManager = FileManager.default
    private var logDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("GameplayLogs", isDirectory: true)
    }

    init() {
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }

    func startSession(
        character: CharacterProfile,
        questType: String,
        questGoal: String
    ) {
        let sessionId = UUID().uuidString
        currentSession = GameplaySession(
            sessionId: sessionId,
            startTime: Date(),
            endTime: nil,
            characterName: character.name,
            characterClass: character.className,
            characterRace: character.race,
            finalLevel: 1,
            finalHP: character.hp,
            questType: questType,
            questGoal: questGoal,
            questCompleted: false,
            questDuration: 0,
            totalEncounters: 0,
            encounterBreakdown: [:],
            narrativeSamples: [],
            totalXPGained: 0,
            totalGoldEarned: 0,
            monstersDefeated: 0,
            itemsCollected: 0,
            deathOccurred: false,
            deathCause: nil,
            deathEncounter: nil
        )
        logger.info("[GameplayLogger] Started session: \(sessionId)")
    }

    func logEncounter(
        encounterNumber: Int,
        encounterType: String,
        difficulty: String,
        playerAction: String,
        llmPrompt: String,
        llmResponse: String,
        questStage: String
    ) {
        guard var session = currentSession else { return }

        session.totalEncounters += 1
        session.encounterBreakdown[encounterType, default: 0] += 1

        let combatVerbs = ["fight", "attack", "defeat", "kill", "slay", "strike", "hit", "slash", "stab"]
        let hadCombatVerbs = combatVerbs.contains { llmResponse.lowercased().contains($0) }

        let sample = GameplaySession.NarrativeSample(
            encounterNumber: encounterNumber,
            encounterType: encounterType,
            difficulty: difficulty,
            playerAction: playerAction,
            llmPrompt: llmPrompt,
            llmResponse: llmResponse,
            responseLength: llmResponse.count,
            hadCombatVerbs: hadCombatVerbs,
            questStage: questStage
        )
        session.narrativeSamples.append(sample)
        currentSession = session
    }

    func updateStats(
        level: Int,
        hp: Int,
        xpGained: Int,
        goldEarned: Int,
        monstersDefeated: Int,
        itemsCollected: Int
    ) {
        guard var session = currentSession else { return }
        session.finalLevel = level
        session.finalHP = hp
        session.totalXPGained = xpGained
        session.totalGoldEarned = goldEarned
        session.monstersDefeated = monstersDefeated
        session.itemsCollected = itemsCollected
        currentSession = session
    }

    func endSession(questCompleted: Bool, deathReport: CharacterDeathReport? = nil) {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.questCompleted = questCompleted
        session.questDuration = session.endTime!.timeIntervalSince(session.startTime)

        if let death = deathReport {
            session.deathOccurred = true
            session.deathCause = death.causeOfDeath
        }

        saveSession(session)
        currentSession = nil
        logger.info("[GameplayLogger] Ended session: \(session.sessionId)")
    }

    private func saveSession(_ session: GameplaySession) {
        let filename = "session_\(session.sessionId).json"
        let fileURL = logDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(session)
            try data.write(to: fileURL)
            logger.info("[GameplayLogger] Saved session to: \(fileURL.path)")
        } catch {
            logger.error("[GameplayLogger] Failed to save session: \(error.localizedDescription)")
        }
    }

    func getAllSessions() -> [GameplaySession] {
        do {
            let files = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> GameplaySession? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(GameplaySession.self, from: data)
                }
                .sorted { $0.startTime > $1.startTime }
        } catch {
            logger.error("[GameplayLogger] Failed to load sessions: \(error.localizedDescription)")
            return []
        }
    }

    func generateAnalyticsReport() -> String {
        let sessions = getAllSessions()
        guard !sessions.isEmpty else { return "No gameplay data available." }

        var report = "# Gameplay Analytics Report\n\n"
        report += "Total Sessions: \(sessions.count)\n"
        report += "Completed Quests: \(sessions.filter { $0.questCompleted }.count)\n"
        report += "Deaths: \(sessions.filter { $0.deathOccurred }.count)\n\n"

        report += "## Narrative Quality\n"
        let allSamples = sessions.flatMap { $0.narrativeSamples }
        let avgLength = allSamples.map { $0.responseLength }.reduce(0, +) / max(allSamples.count, 1)
        let combatVerbViolations = allSamples.filter { $0.hadCombatVerbs && $0.encounterType == "combat" }.count
        report += "Average Response Length: \(avgLength) chars\n"
        report += "Combat Verb Violations: \(combatVerbViolations) / \(allSamples.count)\n\n"

        report += "## Encounter Distribution\n"
        var encounterTotals: [String: Int] = [:]
        for session in sessions {
            for (type, count) in session.encounterBreakdown {
                encounterTotals[type, default: 0] += count
            }
        }
        for (type, count) in encounterTotals.sorted(by: { $0.value > $1.value }) {
            report += "  \(type): \(count)\n"
        }

        return report
    }
}
