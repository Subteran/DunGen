//
//  ConsistencyValidator.swift
//  DunGen
//
//  Validates narrative state and LLM responses for consistency.
//  Performs pre-flight and post-flight checks to catch errors early.
//

import Foundation
import OSLog

// MARK: - Validation Result

struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    let consistencyScore: ConsistencyScore?
    
    init(isValid: Bool, errors: [ValidationError], warnings: [ValidationWarning], consistencyScore: ConsistencyScore? = nil) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.consistencyScore = consistencyScore
    }
}

struct ValidationError: Codable {
    let type: ErrorType
    let description: String
    let context: String
    
    enum ErrorType: String, Codable {
        case stateCorruption
        case missingContext
        case tokenOverflow
        case formatViolation
        case consistencyViolation
    }
}

struct ValidationWarning: Codable {
    let type: WarningType
    let description: String
    let context: String
    
    enum WarningType: String, Codable {
        case stateIntegrity
        case tokenBudget
        case formatIssue
        case narrativeQuality
        case consistencyIssue
    }
}

// MARK: - Consistency Validator

class ConsistencyValidator {
    private let analyzer = NarrativeAnalyzer()
    private let logger = Logger(subsystem: "DunGen", category: "ConsistencyValidator")
    
    // MARK: - Pre-Flight Validation
    
    func validateBeforeLLMCall(
        state: QuestNarrativeState,
        context: AssembledContext
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        validateStateIntegrity(state: state, errors: &errors, warnings: &warnings)
        validateContextCompleteness(context: context, errors: &errors, warnings: &warnings)
        validateTokenBudget(context: context, errors: &errors, warnings: &warnings)
        
        let isValid = errors.isEmpty
        
        if !isValid {
            logger.error("Pre-flight failed: \(errors.map { $0.description }.joined(separator: "; "))")
        }
        
        if !warnings.isEmpty {
            logger.warning("Pre-flight warnings: \(warnings.count)")
        }
        
        return ValidationResult(isValid: isValid, errors: errors, warnings: warnings)
    }
    
    // MARK: - Post-Flight Validation
    
    func validateAfterLLMResponse(
        previousState: QuestNarrativeState?,
        newState: QuestNarrativeState,
        narration: String,
        response: AdventureTurn
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        validateResponseFormat(response: response, errors: &errors, warnings: &warnings)
        validateNarrationQuality(narration: narration, errors: &errors, warnings: &warnings)
        
        // Run consistency analysis
        let consistencyScore = analyzer.analyzeConsistency(
            currentState: newState,
            previousState: previousState,
            newNarration: narration,
            newEvent: response.causalEvent
        )
        
        // Convert critical issues to errors
        for issue in consistencyScore.issues where issue.severity == .critical {
            errors.append(ValidationError(
                type: .consistencyViolation,
                description: issue.description,
                context: issue.context
            ))
        }
        
        // Convert major issues to warnings
        for issue in consistencyScore.issues where issue.severity == .major {
            warnings.append(ValidationWarning(
                type: .consistencyIssue,
                description: issue.description,
                context: issue.context
            ))
        }
        
        let isValid = errors.isEmpty
        
        if !isValid {
            logger.error("Post-flight failed: \(errors.count) errors")
        }
        
        return ValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            consistencyScore: consistencyScore
        )
    }
    
    // MARK: - State Integrity
    
    private func validateStateIntegrity(
        state: QuestNarrativeState,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        // Check causal chain integrity
        for i in 1..<state.chain.count {
            let prev = state.chain[i-1]
            let curr = state.chain[i]
            
            if let prevConseq = prev.consequence,
               let currCause = curr.cause,
               prevConseq != currCause {
                warnings.append(ValidationWarning(
                    type: .stateIntegrity,
                    description: "Causal chain gap: '\(prevConseq)' → '\(currCause)'",
                    context: "Chain index \(i)"
                ))
            }
        }
        
        // Check for duplicate thread IDs
        let threadIds = state.threads.map { $0.id }
        if Set(threadIds).count != threadIds.count {
            errors.append(ValidationError(
                type: .stateCorruption,
                description: "Duplicate thread IDs detected",
                context: "Threads: \(threadIds.joined(separator: ", "))"
            ))
        }
        
        // Check tension range
        if state.tension < 1 || state.tension > 10 {
            errors.append(ValidationError(
                type: .stateCorruption,
                description: "Tension \(state.tension) out of valid range [1-10]",
                context: "Stage: \(state.stage.rawValue)"
            ))
        }
        
        // Check stage-encounter alignment
        let progress = Double(state.currentEncounter) / Double(state.totalEncounters)
        let expectedStage = getExpectedStage(for: progress)
        
        if expectedStage != state.stage {
            warnings.append(ValidationWarning(
                type: .stateIntegrity,
                description: "Stage '\(state.stage.rawValue)' unusual for progress \(String(format: "%.0f", progress * 100))%",
                context: "Expected: \(expectedStage.rawValue)"
            ))
        }
    }
    
    private func getExpectedStage(for progress: Double) -> QuestNarrativeState.QuestStage {
        switch progress {
        case 0..<0.3: return .intro
        case 0.3..<0.7: return .rising
        case 0.7..<0.95: return .climax
        default: return .resolution
        }
    }
    
    // MARK: - Context Completeness
    
    private func validateContextCompleteness(
        context: AssembledContext,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        if context.stateJSON.isEmpty {
            errors.append(ValidationError(
                type: .missingContext,
                description: "Context JSON is empty",
                context: "Specialist: \(context.specialist)"
            ))
        }
    }
    
    // MARK: - Token Budget
    
    private func validateTokenBudget(
        context: AssembledContext,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        let total = context.tokenBreakdown.total
        let maxTokens = 4096
        
        if total > maxTokens {
            errors.append(ValidationError(
                type: .tokenOverflow,
                description: "Token budget exceeded: \(total)/\(maxTokens)",
                context: context.tokenBreakdown.description
            ))
        } else if total > Int(Double(maxTokens) * 0.9) {
            warnings.append(ValidationWarning(
                type: .tokenBudget,
                description: "Token usage high: \(total)/\(maxTokens) (\(String(format: "%.0f", Double(total)/Double(maxTokens) * 100))%)",
                context: "Consider reducing context"
            ))
        }
    }
    
    // MARK: - Response Format
    
    private func validateResponseFormat(
        response: AdventureTurn,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        // Check narration length
        if response.narration.count > 400 {
            errors.append(ValidationError(
                type: .formatViolation,
                description: "Narration too long: \(response.narration.count) chars (max 400)",
                context: String(response.narration.prefix(100))
            ))
        }
        
        if response.narration.count < 50 {
            warnings.append(ValidationWarning(
                type: .formatIssue,
                description: "Narration too short: \(response.narration.count) chars",
                context: response.narration
            ))
        }
        
        // Check for required fields
        if response.adventureProgress == nil {
            errors.append(ValidationError(
                type: .formatViolation,
                description: "Missing adventureProgress in response",
                context: "Required field"
            ))
        }
        
        // Check suggested actions
        if response.suggestedActions.isEmpty {
            warnings.append(ValidationWarning(
                type: .formatIssue,
                description: "No suggested actions provided",
                context: "May impact UX"
            ))
        }
    }
    
    // MARK: - Narration Quality
    
    private func validateNarrationQuality(
        narration: String,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        let lower = narration.lowercased()
        
        // Forbidden phrases
        let forbiddenPhrases = ["you could", "you can", "you may", "what do you"]
        for phrase in forbiddenPhrases {
            if lower.contains(phrase) {
                warnings.append(ValidationWarning(
                    type: .narrativeQuality,
                    description: "Contains suggestion phrase: '\(phrase)'",
                    context: String(narration.prefix(100))
                ))
            }
        }
        
        // Third-person narration
        let thirdPersonIndicators = ["the hero", "the warrior", "he ", "she "]
        for indicator in thirdPersonIndicators {
            if lower.contains(indicator) {
                errors.append(ValidationError(
                    type: .formatViolation,
                    description: "Third-person narration: '\(indicator)'",
                    context: String(narration.prefix(100))
                ))
            }
        }
        
        // Sentence count (2-4 expected)
        let sentenceCount = narration.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
        
        if sentenceCount < 2 {
            warnings.append(ValidationWarning(
                type: .narrativeQuality,
                description: "Too few sentences: \(sentenceCount) (expected 2-4)",
                context: narration
            ))
        } else if sentenceCount > 4 {
            warnings.append(ValidationWarning(
                type: .narrativeQuality,
                description: "Too many sentences: \(sentenceCount) (expected 2-4)",
                context: String(narration.prefix(100))
            ))
        }
    }
}

// MARK: - Placeholder Types (for compilation)

struct AssembledContext {
    let specialist: String
    let stateJSON: String
    let tokenBreakdown: TokenBreakdown
}

struct AdventureTurn {
    let narration: String
    let adventureProgress: String?
    let suggestedActions: [String]
    let causalEvent: CausalEvent?
}
