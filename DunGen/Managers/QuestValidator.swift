import Foundation

@MainActor
final class QuestValidator {

    func isCombatQuest(questGoal: String) -> Bool {
        let questLower = questGoal.lowercased()
        return questLower.contains("defeat") || questLower.contains("kill") ||
               questLower.contains("destroy") || questLower.contains("stop") ||
               questLower.contains("slay")
    }

    func isRetrievalQuest(questGoal: String) -> Bool {
        let questLower = questGoal.lowercased()
        return (questLower.contains("find") || questLower.contains("retrieve") ||
                questLower.contains("locate") || questLower.contains("discover") ||
                questLower.contains("stolen") || questLower.contains("artifact")) &&
               !isCombatQuest(questGoal: questGoal)
    }

    func isEscortQuest(questGoal: String) -> Bool {
        let questLower = questGoal.lowercased()
        return questLower.contains("escort") || questLower.contains("protect") ||
               questLower.contains("guide") || questLower.contains("caravan")
    }

    func validateQuestCompletion(
        progress: AdventureProgress,
        itemsAcquired: [String]?
    ) -> QuestCompletionResult? {
        guard !progress.completed else { return nil }
        guard let items = itemsAcquired, !items.isEmpty else { return nil }

        if isRetrievalQuest(questGoal: progress.questGoal) {
            let questLower = progress.questGoal.lowercased()
            for item in items {
                let itemLower = item.lowercased()
                if (questLower.contains("artifact") && itemLower.contains("artifact")) ||
                   (questLower.contains("stolen") && itemLower.contains("stolen")) ||
                   (questLower.contains(itemLower) && itemLower.count > 5) {
                    return QuestCompletionResult(
                        questGoal: progress.questGoal,
                        locationName: progress.locationName,
                        completingItem: item
                    )
                }
            }
        }
        return nil
    }
}

struct QuestCompletionResult {
    let questGoal: String
    let locationName: String
    let completingItem: String
}
