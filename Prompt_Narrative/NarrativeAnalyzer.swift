//
//  NarrativeAnalyzer.swift
//  DunGen
//
//  Analyzes narrative consistency and coherence across quest encounters.
//  Provides 7-dimensional scoring system with issue detection.
//

import Foundation
import OSLog

// MARK: - Consistency Score

struct ConsistencyScore: Codable {
    let overall: Double  // 0.0-1.0
    let breakdown: ScoreBreakdown
    let issues: [ConsistencyIssue]
    let timestamp: Date
    
    struct ScoreBreakdown: Codable {
        let causalCoherence: Double      // 0.0-1.0
        let spatialConsistency: Double   // 0.0-1.0
        let threadResolution: Double     // 0.0-1.0
        let npcConsistency: Double       // 0.0-1.0
        let tensionArc: Double           // 0.0-1.0
        let repetitionScore: Double      // 0.0-1.0
        let questAlignment: Double       // 0.0-1.0
    }
}

// MARK: - Consistency Issue

struct ConsistencyIssue: Codable, Identifiable {
    let id: UUID
    let type: IssueType
    let severity: Severity
    let description: String
    let encounter: Int
    let context: String
    
    enum IssueType: String, Codable, CaseIterable {
        case causalViolation
        case spatialViolation
        case unresolvedThread
        case npcInconsistency
        case tensionInversion
        case repetition
        case questDrift
        case logicalGap
    }
    
    enum Severity: String, Codable, Comparable {
        case minor
        case moderate
        case major
        case critical
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.minor, .moderate, .major, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }
}

// MARK: - Narrative Analyzer

class NarrativeAnalyzer {
    private let logger = Logger(subsystem: "DunGen", category: "NarrativeAnalyzer")
    
    /// Analyze narrative consistency for a single encounter
    func analyzeConsistency(
        currentState: QuestNarrativeState,
        previousState: QuestNarrativeState?,
        newNarration: String,
        newEvent: CausalEvent?
    ) -> ConsistencyScore {
        
        var issues: [ConsistencyIssue] = []
        
        // Run all consistency checks
        let causalScore = analyzeCausalCoherence(
            currentState: currentState,
            newEvent: newEvent,
            issues: &issues
        )
        
        let spatialScore = analyzeSpatialConsistency(
            currentState: currentState,
            narration: newNarration,
            issues: &issues
        )
        
        let threadScore = analyzeThreadResolution(
            currentState: currentState,
            previousState: previousState,
            issues: &issues
        )
        
        let npcScore = analyzeNPCConsistency(
            currentState: currentState,
            narration: newNarration,
            issues: &issues
        )
        
        let tensionScore = analyzeTensionArc(
            currentState: currentState,
            previousState: previousState,
            issues: &issues
        )
        
        let repetitionScore = analyzeRepetition(
            currentState: currentState,
            narration: newNarration,
            issues: &issues
        )
        
        let questScore = analyzeQuestAlignment(
            currentState: currentState,
            narration: newNarration,
            issues: &issues
        )
        
        let breakdown = ConsistencyScore.ScoreBreakdown(
            causalCoherence: causalScore,
            spatialConsistency: spatialScore,
            threadResolution: threadScore,
            npcConsistency: npcScore,
            tensionArc: tensionScore,
            repetitionScore: repetitionScore,
            questAlignment: questScore
        )
        
        // Weighted overall score
        let overall = (
            causalScore * 0.20 +
            spatialScore * 0.15 +
            threadScore * 0.20 +
            npcScore * 0.10 +
            tensionScore * 0.10 +
            repetitionScore * 0.10 +
            questScore * 0.15
        )
        
        if !issues.isEmpty {
            logger.info("Consistency issues: \(issues.count) (\(issues.filter { $0.severity == .critical }.count) critical)")
        }
        
        return ConsistencyScore(
            overall: overall,
            breakdown: breakdown,
            issues: issues.sorted { $0.severity > $1.severity },
            timestamp: Date()
        )
    }
    
    // MARK: - Causal Coherence
    
    private func analyzeCausalCoherence(
        currentState: QuestNarrativeState,
        newEvent: CausalEvent?,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        guard let event = newEvent else { return 1.0 }
        
        var score = 1.0
        
        // Check if cause exists in chain
        if let cause = event.cause, !cause.isEmpty {
            let chainEvents = currentState.chain.map { $0.event }
            let chainConsequences = currentState.chain.compactMap { $0.consequence }
            
            if !chainEvents.contains(cause) && !chainConsequences.contains(cause) {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .causalViolation,
                    severity: .major,
                    description: "Event '\(event.event)' claims cause '\(cause)' but it's not in causal chain",
                    encounter: currentState.currentEncounter,
                    context: "Chain: \(chainEvents.joined(separator: "→"))"
                ))
                score -= 0.5
            }
        }
        
        // Check for logical gaps
        if currentState.chain.count >= 2 {
            let lastTwo = currentState.chain.suffix(2)
            if let prev = lastTwo.first, let curr = lastTwo.last {
                if let prevConseq = prev.consequence,
                   let currCause = curr.cause,
                   prevConseq != currCause {
                    issues.append(ConsistencyIssue(
                        id: UUID(),
                        type: .logicalGap,
                        severity: .moderate,
                        description: "Gap between '\(prevConseq)' and '\(currCause)'",
                        encounter: currentState.currentEncounter,
                        context: "Previous consequence doesn't match current cause"
                    ))
                    score -= 0.2
                }
            }
        }
        
        return max(0.0, score)
    }
    
    // MARK: - Spatial Consistency
    
    private func analyzeSpatialConsistency(
        currentState: QuestNarrativeState,
        narration: String,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        var score = 1.0
        let lower = narration.lowercased()
        
        // Check cleared areas not described as dangerous
        for clearedArea in currentState.locationState.cleared {
            let dangerWords = ["ambush", "guards", "enemies", "attack", "danger", "threat"]
            if dangerWords.contains(where: { lower.contains($0) }) &&
               lower.contains(clearedArea.lowercased()) {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .spatialViolation,
                    severity: .moderate,
                    description: "Danger in cleared area '\(clearedArea)'",
                    encounter: currentState.currentEncounter,
                    context: String(narration.prefix(100))
                ))
                score -= 0.3
            }
        }
        
        // Check locked areas not accessed
        for lockedArea in currentState.locationState.locked {
            let accessWords = ["enter", "inside", "walk into", "step into", "through the"]
            if accessWords.contains(where: { lower.contains($0) }) &&
               lower.contains(lockedArea.lowercased()) {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .spatialViolation,
                    severity: .major,
                    description: "Accessing locked area '\(lockedArea)'",
                    encounter: currentState.currentEncounter,
                    context: String(narration.prefix(100))
                ))
                score -= 0.5
            }
        }
        
        // Check destroyed locations referenced as intact
        for destroyed in currentState.locationState.destroyed {
            let intactIndicators = ["intact", "standing", "unscathed", "pristine"]
            if lower.contains(destroyed.lowercased()) &&
               intactIndicators.contains(where: { lower.contains($0) }) {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .spatialViolation,
                    severity: .moderate,
                    description: "Destroyed '\(destroyed)' described as intact",
                    encounter: currentState.currentEncounter,
                    context: String(narration.prefix(100))
                ))
                score -= 0.3
            }
        }
        
        return max(0.0, score)
    }
    
    // MARK: - Thread Resolution
    
    private func analyzeThreadResolution(
        currentState: QuestNarrativeState,
        previousState: QuestNarrativeState?,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        var score = 1.0
        
        let activeThreads = currentState.threads.filter { !$0.resolved }
        
        // Check aging high-priority threads
        for thread in activeThreads {
            let age = currentState.currentEncounter - thread.introduced
            
            if thread.priority >= 8 && age > 5 {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .unresolvedThread,
                    severity: .moderate,
                    description: "High priority thread unresolved for \(age) encounters",
                    encounter: currentState.currentEncounter,
                    context: "'\(thread.text)' (priority \(thread.priority))"
                ))
                score -= 0.15
            }
            
            // Promises should resolve before quest end
            if age > currentState.totalEncounters / 2 && thread.type == .promise {
                issues.append(ConsistencyIssue(
                    id: UUID(),
                    type: .unresolvedThread,
                    severity: .major,
                    description: "Promise unfulfilled past midpoint",
                    encounter: currentState.currentEncounter,
                    context: "'\(thread.text)'"
                ))
                score -= 0.3
            }
        }
        
        // Too many active threads dilutes focus
        if activeThreads.count > 5 {
            issues.append(ConsistencyIssue(
                id: UUID(),
                type: .unresolvedThread,
                severity: .minor,
                description: "\(activeThreads.count) active threads - narrative may feel scattered",
                encounter: currentState.currentEncounter,
                context: activeThreads.map { $0.text }.joined(separator: "; ")
            ))
            score -= 0.1
        }
        
        return max(0.0, score)
    }
    
    // MARK: - NPC Consistency
    
    private func analyzeNPCConsistency(
        currentState: QuestNarrativeState,
        narration: String,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        var score = 1.0
        let lower = narration.lowercased()
        
        for (npcName, relation) in currentState.npcRelations {
            guard lower.contains(npcName.lowercased()) else { continue }
            
            // Hostile NPC should not be friendly
            if relation.relationship < -5 {
                let friendlyWords = ["smiles", "greets warmly", "welcomes", "friendly", "kindly"]
                if friendlyWords.contains(where: { lower.contains($0) }) {
                    issues.append(ConsistencyIssue(
                        id: UUID(),
                        type: .npcInconsistency,
                        severity: .major,
                        description: "Hostile NPC '\(npcName)' (rel: \(relation.relationship)) acts friendly",
                        encounter: currentState.currentEncounter,
                        context: String(narration.prefix(100))
                    ))
                    score -= 0.4
                }
            } else if relation.relationship > 5 {
                // Friendly NPC should not be hostile
                let hostileWords = ["attacks", "threatens", "glares", "hostile", "snarls"]
                if hostileWords.contains(where: { lower.contains($0) }) {
                    issues.append(ConsistencyIssue(
                        id: UUID(),
                        type: .npcInconsistency,
                        severity: .major,
                        description: "Friendly NPC '\(npcName)' (rel: \(relation.relationship)) acts hostile",
                        encounter: currentState.currentEncounter,
                        context: String(narration.prefix(100))
                    ))
                    score -= 0.4
                }
            }
            
            // First meeting should not be reunion
            if relation.timesMet == 1 {
                let reunionWords = ["again", "once more", "returns", "back", "remember"]
                if reunionWords.contains(where: { lower.contains($0) && lower.contains(npcName.lowercased()) }) {
                    issues.append(ConsistencyIssue(
                        id: UUID(),
                        type: .npcInconsistency,
                        severity: .minor,
                        description: "First meeting with '\(npcName)' described as reunion",
                        encounter: currentState.currentEncounter,
                        context: "Times met: \(relation.timesMet)"
                    ))
                    score -= 0.2
                }
            }
        }
        
        return max(0.0, score)
    }
    
    // MARK: - Tension Arc
    
    private func analyzeTensionArc(
        currentState: QuestNarrativeState,
        previousState: QuestNarrativeState?,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        var score = 1.0
        
        guard let prev = previousState else { return score }
        
        let tensionChange = currentState.tension - prev.tension
        
        // Tension should increase toward climax
        if currentState.stage == .climax && tensionChange < 0 {
            issues.append(ConsistencyIssue(
                id: UUID(),
                type: .tensionInversion,
                severity: .moderate,
                description: "Tension dropped during climax (\(prev.tension)→\(currentState.tension))",
                encounter: currentState.currentEncounter,
                context: "Stage: climax"
            ))
            score -= 0.3
        }
        
        // Tension should not spike too quickly
        if tensionChange > 3 {
            issues.append(ConsistencyIssue(
                id: UUID(),
                type: .tensionInversion,
                severity: .minor,
                description: "Tension spiked too quickly (+\(tensionChange))",
                encounter: currentState.currentEncounter,
                context: "May feel jarring"
            ))
            score -= 0.1
        }
        
        // Check stage-tension alignment
        let expectedTension = getExpectedTensionRange(for: currentState.stage)
        if !expectedTension.contains(currentState.tension) {
            issues.append(ConsistencyIssue(
                id: UUID(),
                type: .tensionInversion,
                severity: .minor,
                description: "Tension \(currentState.tension) outside expected \(expectedTension)",
                encounter: currentState.currentEncounter,
                context: "Stage: \(currentState.stage.rawValue)"
            ))
            score -= 0.2
        }
        
        return max(0.0, score)
    }
    
    private func getExpectedTensionRange(for stage: QuestNarrativeState.QuestStage) -> ClosedRange<Int> {
        switch stage {
        case .intro: return 1...3
        case .rising: return 4...6
        case .climax: return 7...9
        case .resolution: return 2...4
        }
    }
    
    // MARK: - Repetition Analysis
    
    private func analyzeRepetition(
        currentState: QuestNarrativeState,
        narration: String,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        // Simplified for now - would need history of narrations
        return 1.0
    }
    
    // MARK: - Quest Alignment
    
    private func analyzeQuestAlignment(
        currentState: QuestNarrativeState,
        narration: String,
        issues: inout [ConsistencyIssue]
    ) -> Double {
        var score = 1.0
        let lower = narration.lowercased()
        let goalLower = currentState.goal.lowercased()
        
        // Extract key goal terms
        let goalTerms = extractKeyTerms(from: goalLower)
        
        // Check if narration references goal
        let referencesGoal = goalTerms.contains { lower.contains($0) }
        
        // At climax, should reference goal
        if currentState.stage == .climax && !referencesGoal {
            issues.append(ConsistencyIssue(
                id: UUID(),
                type: .questDrift,
                severity: .moderate,
                description: "Climax doesn't reference quest goal",
                encounter: currentState.currentEncounter,
                context: "Goal: \(currentState.goal)"
            ))
            score -= 0.3
        }
        
        return max(0.0, score)
    }
    
    private func extractKeyTerms(from text: String) -> [String] {
        let stopWords = Set(["the", "a", "an", "to", "from", "in", "at", "of", "and", "or"])
        return text.split(separator: " ")
            .map { String($0) }
            .filter { !stopWords.contains($0) && $0.count > 3 }
    }
}
