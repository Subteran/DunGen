import Foundation
import FoundationModels
import Testing
@testable import DunGen

struct TranscriptTestHelpers {

    /// Verify that at least one prompt in the transcript contains the specified keyword
    static func verifyPromptContains(
        transcript: Transcript?,
        keyword: String,
        message: String = ""
    ) -> Bool {
        guard let transcript = transcript else { return false }

        return Array(transcript).contains { entry in
            if case .prompt(let text) = entry {
                let promptText = String(describing: text)
                return promptText.lowercased().contains(keyword.lowercased())
            }
            return false
        }
    }

    /// Get the most recent prompt from the transcript
    static func getLastPrompt(from transcript: Transcript?) -> String? {
        guard let transcript = transcript else { return nil }

        for entry in Array(transcript).reversed() {
            if case .prompt(let text) = entry {
                return String(describing: text)
            }
        }
        return nil
    }

    /// Get all prompts from the transcript in chronological order
    static func getPromptHistory(from transcript: Transcript?) -> [String] {
        guard let transcript = transcript else { return [] }

        return Array(transcript).compactMap { entry in
            if case .prompt(let text) = entry {
                return String(describing: text)
            }
            return nil
        }
    }

    /// Get the most recent response from the transcript
    static func getLastResponse(from transcript: Transcript?) -> String? {
        guard let transcript = transcript else { return nil }

        for entry in Array(transcript).reversed() {
            if case .response(let content) = entry {
                return String(describing: content)
            }
        }
        return nil
    }

    /// Count total entries in the transcript
    static func entryCount(from transcript: Transcript?) -> Int {
        guard let transcript = transcript else { return 0 }
        return Array(transcript).count
    }

    /// Count prompts in the transcript
    static func promptCount(from transcript: Transcript?) -> Int {
        guard let transcript = transcript else { return 0 }

        return Array(transcript).filter { entry in
            if case .prompt = entry { return true }
            return false
        }.count
    }

    /// Calculate average prompt size in characters
    static func averagePromptSize(from transcript: Transcript?) -> Int {
        let prompts = getPromptHistory(from: transcript)
        guard !prompts.isEmpty else { return 0 }

        let totalChars = prompts.reduce(0) { $0 + $1.count }
        return totalChars / prompts.count
    }

    /// Get maximum prompt size in characters
    static func maxPromptSize(from transcript: Transcript?) -> Int {
        let prompts = getPromptHistory(from: transcript)
        guard !prompts.isEmpty else { return 0 }

        return prompts.map { $0.count }.max() ?? 0
    }

    /// Verify that ALL prompts contain a specific keyword
    static func verifyAllPromptsContain(
        transcript: Transcript?,
        keyword: String
    ) -> Bool {
        let prompts = getPromptHistory(from: transcript)
        guard !prompts.isEmpty else { return false }

        return prompts.allSatisfy { prompt in
            prompt.lowercased().contains(keyword.lowercased())
        }
    }

    /// Get prompts that DON'T contain a specific keyword (for detecting when context is lost)
    static func getPromptsMissing(
        transcript: Transcript?,
        keyword: String
    ) -> [String] {
        let prompts = getPromptHistory(from: transcript)

        return prompts.filter { prompt in
            !prompt.lowercased().contains(keyword.lowercased())
        }
    }

    /// Analyze transcript for context window issues
    static func analyzeContextUsage(from transcript: Transcript?) -> ContextAnalysis {
        let prompts = getPromptHistory(from: transcript)

        return ContextAnalysis(
            totalPrompts: prompts.count,
            averageSize: averagePromptSize(from: transcript),
            maxSize: maxPromptSize(from: transcript),
            over500Chars: prompts.filter { $0.count > 500 }.count,
            over600Chars: prompts.filter { $0.count > 600 }.count
        )
    }

    struct ContextAnalysis {
        let totalPrompts: Int
        let averageSize: Int
        let maxSize: Int
        let over500Chars: Int
        let over600Chars: Int

        var hasContextIssues: Bool {
            return over600Chars > 0
        }
    }

    /// Estimate token count (rough approximation: 1 token ≈ 4 characters)
    static func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Estimate total token usage from transcript
    static func estimateTotalTokens(from transcript: Transcript?) -> Int {
        guard let transcript = transcript else { return 0 }

        var totalTokens = 0
        for entry in transcript {
            if case .prompt(let text) = entry {
                let promptText = String(describing: text)
                totalTokens += estimateTokens(promptText)
            } else if case .response(let content) = entry {
                let responseText = String(describing: content)
                totalTokens += estimateTokens(responseText)
            }
        }
        return totalTokens
    }

    /// Analyze token usage with budget warnings
    static func analyzeTokenUsage(from transcript: Transcript?) -> TokenAnalysis {
        guard let transcript = transcript else {
            return TokenAnalysis(totalTokens: 0, promptTokens: 0, responseTokens: 0, entryCount: 0)
        }

        var promptTokens = 0
        var responseTokens = 0
        var entryCount = 0

        for entry in transcript {
            entryCount += 1
            if case .prompt(let text) = entry {
                let promptText = String(describing: text)
                promptTokens += estimateTokens(promptText)
            } else if case .response(let content) = entry {
                let responseText = String(describing: content)
                responseTokens += estimateTokens(responseText)
            }
        }

        return TokenAnalysis(
            totalTokens: promptTokens + responseTokens,
            promptTokens: promptTokens,
            responseTokens: responseTokens,
            entryCount: entryCount
        )
    }

    struct TokenAnalysis {
        let totalTokens: Int
        let promptTokens: Int
        let responseTokens: Int
        let entryCount: Int

        /// Apple's on-device LLM context window limit
        static let contextWindowLimit = 4096

        var percentUsed: Double {
            return Double(totalTokens) / Double(Self.contextWindowLimit) * 100.0
        }

        var isNearLimit: Bool {
            return totalTokens > 3500  // Warning at 85%
        }

        var exceedsLimit: Bool {
            return totalTokens > Self.contextWindowLimit
        }

        var summary: String {
            return """
            Token Usage: \(totalTokens)/\(Self.contextWindowLimit) (\(String(format: "%.1f", percentUsed))%)
            Prompts: \(promptTokens) | Responses: \(responseTokens)
            Entries: \(entryCount)
            Status: \(exceedsLimit ? "⚠️ EXCEEDS LIMIT" : isNearLimit ? "⚠️ Near Limit" : "✓ OK")
            """
        }
    }
}

// MARK: - Transcript Entry Extensions for easier testing
extension Transcript.Entry {
    var promptText: String? {
        if case .prompt(let text) = self {
            return String(describing: text)
        }
        return nil
    }

    var responseText: String? {
        if case .response(let content) = self {
            return String(describing: content)
        }
        return nil
    }
}
