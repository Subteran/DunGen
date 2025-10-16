import Foundation

struct GameState: Codable, Equatable {
    var character: CharacterProfile?
    var currentLocation: AdventureType
    var currentEnvironment: String
    var log: [SavedLogEntry]
    var suggestedActions: [String]
    var adventureProgress: AdventureProgress?
    var detailedInventory: [ItemDefinition]
    var worldState: WorldState?

    struct SavedLogEntry: Codable, Equatable, Identifiable {
        let id: UUID
        let content: String
        let isFromModel: Bool
    }
}

protocol GameStatePersistenceProtocol {
    func save(_ state: GameState) throws
    func load() throws -> GameState?
    func delete() throws
}

final class GameStatePersistence: GameStatePersistenceProtocol {
    private let fileURL: URL

    init(fileName: String = "gameState.json") {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documentsDirectory.appendingPathComponent(fileName)
    }

    func save(_ state: GameState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: [.atomic])
    }

    func load() throws -> GameState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        return try decoder.decode(GameState.self, from: data)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

extension LLMGameEngine {
    func saveState() {
        let persistence = GameStatePersistence()
        let logEntries = log.map { entry in
            GameState.SavedLogEntry(
                id: entry.id,
                content: entry.content,
                isFromModel: entry.isFromModel
            )
        }

        let state = GameState(
            character: character,
            currentLocation: currentLocation,
            currentEnvironment: currentEnvironment,
            log: logEntries,
            suggestedActions: suggestedActions,
            adventureProgress: adventureProgress,
            detailedInventory: detailedInventory,
            worldState: worldState
        )

        do {
            try persistence.save(state)
        } catch {
            print("Failed to save game state: \(error)")
        }
    }

    func loadState() {
        let persistence = GameStatePersistence()

        do {
            if let state = try persistence.load() {
                self.character = state.character
                self.currentLocation = state.currentLocation
                self.currentEnvironment = state.currentEnvironment
                self.log = state.log.map { savedEntry in
                    LLMGameEngine.LogEntry(
                        id: savedEntry.id,
                        content: savedEntry.content,
                        isFromModel: savedEntry.isFromModel
                    )
                }
                self.suggestedActions = state.suggestedActions
                self.adventureProgress = state.adventureProgress
                self.detailedInventory = state.detailedInventory
                self.worldState = state.worldState
            }
        } catch {
            print("Failed to load game state: \(error)")
        }
    }

    func deleteState() {
        let persistence = GameStatePersistence()

        do {
            try persistence.delete()
        } catch {
            print("Failed to delete game state: \(error)")
        }
    }
}
