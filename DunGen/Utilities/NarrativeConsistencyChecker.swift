import Foundation
import OSLog

struct ConsistencyIssue {
    let severity: Severity
    let description: String
    let context: String

    enum Severity {
        case minor
        case moderate
        case major
    }

    var emoji: String {
        switch severity {
        case .minor: return "ℹ️"
        case .moderate: return "⚠️"
        case .major: return "❌"
        }
    }
}

struct NarrativeConsistencyChecker {
    private static let logger = Logger(subsystem: "DunGen", category: "ConsistencyChecker")

    static func checkConsistency(
        narration: String,
        state: NarrativeState,
        encounterType: String
    ) -> [ConsistencyIssue] {
        var issues: [ConsistencyIssue] = []

        checkClearedAreas(narration: narration, state: state, issues: &issues)
        checkLockedAreas(narration: narration, state: state, issues: &issues)
        checkNPCConsistency(narration: narration, state: state, issues: &issues)

        if !issues.isEmpty {
            logger.info("Found \(issues.count) consistency issues")
            for issue in issues {
                logger.info("\(issue.emoji) [\(String(describing: issue.severity))] \(issue.description)")
            }
        }

        return issues
    }

    private static func checkClearedAreas(
        narration: String,
        state: NarrativeState,
        issues: inout [ConsistencyIssue]
    ) {
        let lower = narration.lowercased()
        let dangerWords = ["ambush", "guards", "enemies", "attack", "danger", "threat", "monsters"]

        for area in state.clearedAreas {
            if lower.contains(area.lowercased()) {
                for word in dangerWords {
                    if lower.contains(word) {
                        issues.append(ConsistencyIssue(
                            severity: .moderate,
                            description: "Danger ('\(word)') mentioned in cleared area '\(area)'",
                            context: String(narration.prefix(100))
                        ))
                        break
                    }
                }
            }
        }
    }

    private static func checkLockedAreas(
        narration: String,
        state: NarrativeState,
        issues: inout [ConsistencyIssue]
    ) {
        let lower = narration.lowercased()
        let accessWords = ["enter", "inside", "walk into", "step into", "through the"]

        for area in state.lockedAreas {
            if lower.contains(area.lowercased()) {
                for phrase in accessWords {
                    if lower.contains(phrase) {
                        issues.append(ConsistencyIssue(
                            severity: .major,
                            description: "Accessing locked area '\(area)'",
                            context: String(narration.prefix(100))
                        ))
                        break
                    }
                }
            }
        }
    }

    private static func checkNPCConsistency(
        narration: String,
        state: NarrativeState,
        issues: inout [ConsistencyIssue]
    ) {
        let lower = narration.lowercased()

        for (npcName, relation) in state.npcRelations {
            guard lower.contains(npcName.lowercased()) else { continue }

            if relation.relationshipValue < -5 {
                let friendlyWords = ["smiles", "greets warmly", "welcomes", "friendly", "kindly", "helps"]
                for word in friendlyWords {
                    if lower.contains(word) {
                        issues.append(ConsistencyIssue(
                            severity: .major,
                            description: "Hostile NPC '\(npcName)' (rel: \(relation.relationshipValue)) acts friendly ('\(word)')",
                            context: relation.relationDescription
                        ))
                        break
                    }
                }
            } else if relation.relationshipValue > 5 {
                let hostileWords = ["attacks", "threatens", "glares", "hostile", "snarls", "sneers"]
                for word in hostileWords {
                    if lower.contains(word) {
                        issues.append(ConsistencyIssue(
                            severity: .major,
                            description: "Friendly NPC '\(npcName)' (rel: \(relation.relationshipValue)) acts hostile ('\(word)')",
                            context: relation.relationDescription
                        ))
                        break
                    }
                }
            }

            if relation.timesMet == 1 {
                let reunionWords = ["again", "once more", "returns", "back", "remember"]
                for word in reunionWords {
                    if lower.contains(word) {
                        issues.append(ConsistencyIssue(
                            severity: .minor,
                            description: "First meeting with '\(npcName)' uses reunion language ('\(word)')",
                            context: "Times met: \(relation.timesMet)"
                        ))
                        break
                    }
                }
            }
        }
    }
}
