//
//  StateLogger.swift
//  DunGen
//
//  Logs narrative state transitions and generates quest reports.
//  Provides comprehensive telemetry for narrative quality analysis.
//

import Foundation
import OSLog

// MARK: - State Transition

struct StateTransition: Codable {
    let id: UUID
    let timestamp: Date
    let encounter: Int
    
    let previousState: QuestNarrativeState?
    let newState: QuestNarrativeState
    
    let llmContext: LLMContextSnapshot
    let llmResponse: LLMResponseSnapshot
    let consistencyScore: ConsistencyScore
    let metrics: PerformanceMetrics
    
    struct LLMContextSnapshot: Codable {
        let specialist: String
        let tokenCount: Int
        let tierUsed: String
        let includedFields: [String]
        let excludedFields: [String]
        let fullContext: String
    }
    
    struct LLMResponseSnapshot: Codable {
        let tokenCount: Int
        let generationTime: TimeInterval
        let narration: String
        let newThreads: [String]
        let resolvedThreads: [String]
        let causalEvent: CausalEvent?
    }
    
    struct PerformanceMetrics: Codable {
        let contextAssemblyTime: TimeInterval
        let llmGenerationTime: TimeInterval
        let validationTime: TimeInterval
        let totalTime: TimeInterval
        let tokenEfficiency: Double
    }
}

// MARK: - Quest Narrative Report

struct QuestNarrativeReport: Codable {
    let questId: String
    let totalEncounters: Int
    let averageConsistencyScore: Double
    let consistencyByEncounter: [Double]
    let issuesByType: [String: Int]
    let criticalIssues: [ConsistencyIssue]
    let averageTokenUsage: Int
    let averageGenerationTime: TimeInterval
    let finalThreadsUnresolved: Int
    let causalChainLength: Int
    let timestamp: Date
    
    var summary: String {
        """
        Quest Narrative Report
        =====================
        Quest ID: \(questId)
        Total Encounters: \(totalEncounters)
        
        Consistency Metrics:
        - Average Score: \(String(format: "%.2f", averageConsistencyScore))
        - Critical Issues: \(criticalIssues.count)
        - Unresolved Threads: \(finalThreadsUnresolved)
        
        Performance Metrics:
        - Avg Token Usage: \(averageTokenUsage)
        - Avg Generation Time: \(String(format: "%.2f", averageGenerationTime))s
        
        Issue Breakdown:
        \(issuesByType.map { "  \($0.key): \($0.value)" }.sorted().joined(separator: "\n"))
        """
    }
}

// MARK: - State Logger

class StateLogger {
    private let logger = Logger(subsystem: "DunGen", category: "StateLogger")
    private var transitions: [StateTransition] = []
    
    // File logging
    private let logDirectory: URL
    private var currentQuestLogFile: URL?
    
    init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        logDirectory = documentsURL.appendingPathComponent("NarrativeLogs")
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Logging
    
    func logTransition(_ transition: StateTransition) {
        transitions.append(transition)
        
        // Console logging
        logger.info("""
        [Enc \(transition.encounter)] Transition:
          Consistency: \(String(format: "%.2f", transition.consistencyScore.overall))
          Tokens: \(transition.llmContext.tokenCount)
          Generation: \(String(format: "%.2f", transition.metrics.llmGenerationTime))s
          Issues: \(transition.consistencyScore.issues.count)
        """)
        
        // Log issues
        for issue in transition.consistencyScore.issues where issue.severity == .major || issue.severity == .critical {
            logger.warning("[Consistency] \(issue.type.rawValue): \(issue.description)")
        }
        
        // File logging
        writeTransitionToFile(transition)
    }
    
    func startQuestLog(questId: String) {
        let filename = "quest_\(questId)_\(Date().ISO8601Format()).jsonl"
        currentQuestLogFile = logDirectory.appendingPathComponent(filename)
        
        logger.info("Started quest log: \(filename)")
    }
    
    func finalizeQuestLog() -> QuestNarrativeReport? {
        guard !transitions.isEmpty else { return nil }
        
        let report = generateQuestReport()
        
        // Write final report
        if let logFile = currentQuestLogFile {
            let reportFile = logFile.deletingPathExtension().appendingPathExtension("report.json")
            if let data = try? JSONEncoder().encode(report) {
                try? data.write(to: reportFile)
            }
        }
        
        // Clear for next quest
        transitions.removeAll()
        currentQuestLogFile = nil
        
        logger.info("Finalized quest log")
        
        return report
    }
    
    // MARK: - Analysis
    
    func generateQuestReport() -> QuestNarrativeReport {
        let avgConsistency = transitions.map { $0.consistencyScore.overall }.reduce(0, +) / Double(transitions.count)
        
        let allIssues = transitions.flatMap { $0.consistencyScore.issues }
        
        // Group issues by type
        var issuesByType: [String: Int] = [:]
        for issue in allIssues {
            issuesByType[issue.type.rawValue, default: 0] += 1
        }
        
        let avgTokens = transitions.map { $0.llmContext.tokenCount }.reduce(0, +) / transitions.count
        let avgGenerationTime = transitions.map { $0.metrics.llmGenerationTime }.reduce(0, +) / Double(transitions.count)
        
        return QuestNarrativeReport(
            questId: transitions.first?.newState.questId ?? "unknown",
            totalEncounters: transitions.count,
            averageConsistencyScore: avgConsistency,
            consistencyByEncounter: transitions.map { $0.consistencyScore.overall },
            issuesByType: issuesByType,
            criticalIssues: allIssues.filter { $0.severity == .critical },
            averageTokenUsage: avgTokens,
            averageGenerationTime: avgGenerationTime,
            finalThreadsUnresolved: transitions.last?.newState.threads.filter { !$0.resolved }.count ?? 0,
            causalChainLength: transitions.last?.newState.chain.count ?? 0,
            timestamp: Date()
        )
    }
    
    private func writeTransitionToFile(_ transition: StateTransition) {
        guard let logFile = currentQuestLogFile else { return }
        
        if let data = try? JSONEncoder().encode(transition),
           let json = String(data: data, encoding: .utf8) {
            
            let line = json + "\n"
            
            if let handle = try? FileHandle(forWritingTo: logFile) {
                handle.seekToEndOfFile()
                handle.write(line.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? line.write(to: logFile, atomically: true, encoding: .utf8)
            }
        }
    }
    
    // MARK: - Query
    
    func getTransitions(for encounter: Int) -> [StateTransition] {
        transitions.filter { $0.encounter == encounter }
    }
    
    func getTransitionsByConsistencyScore(below threshold: Double) -> [StateTransition] {
        transitions.filter { $0.consistencyScore.overall < threshold }
    }
    
    func getIssues(ofType type: ConsistencyIssue.IssueType) -> [ConsistencyIssue] {
        transitions.flatMap { $0.consistencyScore.issues }.filter { $0.type == type }
    }
    
    func getAverageConsistency() -> Double {
        guard !transitions.isEmpty else { return 0.0 }
        return transitions.map { $0.consistencyScore.overall }.reduce(0, +) / Double(transitions.count)
    }
    
    func getAllIssues() -> [ConsistencyIssue] {
        transitions.flatMap { $0.consistencyScore.issues }
    }
}
