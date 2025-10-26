import Foundation

@MainActor
@Observable
final class UIStateManager {
    var isGenerating: Bool = false

    var suggestedActions: [String] = []

    var awaitingLocationSelection: Bool = false

    var awaitingCustomCharacterName: Bool = false

    var awaitingWorldContinue: Bool = false

    var needsInventoryManagement: Bool = false

    func reset() {
        isGenerating = false
        suggestedActions = []
        awaitingLocationSelection = false
        awaitingCustomCharacterName = false
        awaitingWorldContinue = false
        needsInventoryManagement = false
    }

    func setGenerating(_ generating: Bool) {
        if isGenerating != generating {
            isGenerating = generating
        }
    }

    func updateSuggestedActions(_ actions: [String]) {
        suggestedActions = actions
    }
}
