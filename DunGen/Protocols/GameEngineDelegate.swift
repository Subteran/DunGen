import Foundation

protocol GameEngineDelegate: AnyObject {
    func engineDidStartGenerating()
    func engineDidFinishGenerating()

    func engineNeedsLocationSelection(summary: AdventureSummary)
    func engineNeedsCustomCharacterName(partialCharacter: CharacterProfile)
    func engineNeedsInventoryManagement(pendingLoot: [ItemDefinition], currentInventory: [ItemDefinition])
    func engineNeedsWorldContinue()

    func engineDidUpdateSuggestedActions(_ actions: [String])
    func engineDidUpdateLog(_ log: [GameLogEntry])

    func engineDidDetectDeath(report: CharacterDeathReport)
}

extension GameEngineDelegate {
    func engineDidStartGenerating() {}
    func engineDidFinishGenerating() {}
    func engineNeedsLocationSelection(summary: AdventureSummary) {}
    func engineNeedsCustomCharacterName(partialCharacter: CharacterProfile) {}
    func engineNeedsInventoryManagement(pendingLoot: [ItemDefinition], currentInventory: [ItemDefinition]) {}
    func engineNeedsWorldContinue() {}
    func engineDidUpdateSuggestedActions(_ actions: [String]) {}
    func engineDidUpdateLog(_ log: [GameLogEntry]) {}
    func engineDidDetectDeath(report: CharacterDeathReport) {}
}
