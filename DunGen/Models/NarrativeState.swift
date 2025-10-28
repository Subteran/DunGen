import Foundation

struct NarrativeState: Codable, Equatable {
    var activeThreads: [NarrativeThread]
    var clearedAreas: Set<String>
    var lockedAreas: Set<String>
    var npcRelations: [String: NPCRelation]

    init() {
        self.activeThreads = []
        self.clearedAreas = []
        self.lockedAreas = []
        self.npcRelations = [:]
    }

    mutating func addThread(_ text: String, priority: Int = 5) {
        let thread = NarrativeThread(
            text: text,
            priority: priority,
            introducedAt: Date()
        )
        activeThreads.append(thread)

        if activeThreads.count > 5 {
            activeThreads.sort { $0.priority > $1.priority }
            activeThreads = Array(activeThreads.prefix(5))
        }
    }

    mutating func resolveThread(matching text: String) {
        activeThreads.removeAll { $0.text.lowercased().contains(text.lowercased()) }
    }

    mutating func markAreaCleared(_ area: String) {
        clearedAreas.insert(area)
        lockedAreas.remove(area)
    }

    mutating func markAreaLocked(_ area: String) {
        lockedAreas.insert(area)
    }

    mutating func updateNPCRelation(name: String, delta: Int, interaction: String? = nil) {
        if var relation = npcRelations[name] {
            relation.relationshipValue = max(-10, min(10, relation.relationshipValue + delta))
            relation.timesMet += 1
            if let interaction = interaction {
                relation.lastInteraction = interaction
            }
            npcRelations[name] = relation
        } else {
            npcRelations[name] = NPCRelation(
                name: name,
                relationshipValue: delta,
                timesMet: 1,
                lastInteraction: interaction ?? "First meeting"
            )
        }
    }

    func getContextSummary() -> String {
        var parts: [String] = []

        if !activeThreads.isEmpty {
            let threads = activeThreads
                .sorted { $0.priority > $1.priority }
                .prefix(3)
                .map { $0.text }
                .joined(separator: "; ")
            parts.append("Active Clues: \(threads)")
        }

        if !clearedAreas.isEmpty {
            parts.append("Safe Areas: \(clearedAreas.joined(separator: ", "))")
        }

        if !lockedAreas.isEmpty {
            parts.append("Locked Areas: \(lockedAreas.joined(separator: ", "))")
        }

        if !npcRelations.isEmpty {
            let npcs = npcRelations.values
                .sorted { $0.relationshipValue > $1.relationshipValue }
                .prefix(3)
                .map { "\($0.name) (\($0.relationDescription))" }
                .joined(separator: "; ")
            parts.append("NPCs: \(npcs)")
        }

        return parts.joined(separator: "\n")
    }
}

struct NarrativeThread: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    var priority: Int
    let introducedAt: Date

    init(text: String, priority: Int, introducedAt: Date) {
        self.id = UUID()
        self.text = text
        self.priority = priority
        self.introducedAt = introducedAt
    }

    var ageInEncounters: Int {
        Int(-introducedAt.timeIntervalSinceNow / 60)
    }
}

struct NPCRelation: Codable, Equatable {
    let name: String
    var relationshipValue: Int
    var timesMet: Int
    var lastInteraction: String

    var relationDescription: String {
        switch relationshipValue {
        case 7...: return "ally"
        case 3...6: return "friendly"
        case -2...2: return "neutral"
        case -6...(-3): return "unfriendly"
        default: return "hostile"
        }
    }
}
