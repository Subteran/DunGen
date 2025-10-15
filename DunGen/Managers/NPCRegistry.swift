import Foundation

@MainActor
@Observable
final class NPCRegistry {
    private var knownNPCs: [String: NPCDefinition] = [:]
    private var npcsByLocation: [String: [String]] = [:]

    func registerNPC(_ npc: NPCDefinition, location: String) {
        knownNPCs[npc.id] = npc
        if npcsByLocation[location] == nil {
            npcsByLocation[location] = []
        }
        if !npcsByLocation[location]!.contains(npc.id) {
            npcsByLocation[location]!.append(npc.id)
        }
    }

    func getNPC(byID id: String) -> NPCDefinition? {
        knownNPCs[id]
    }

    func getNPCs(atLocation location: String) -> [NPCDefinition] {
        guard let npcIDs = npcsByLocation[location] else { return [] }
        return npcIDs.compactMap { knownNPCs[$0] }
    }

    func getRandomNPC(atLocation location: String) -> NPCDefinition? {
        let npcs = getNPCs(atLocation: location)
        return npcs.randomElement()
    }

    func reset() {
        knownNPCs.removeAll()
        npcsByLocation.removeAll()
    }
}
