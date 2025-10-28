import Foundation

struct TokenEstimator {

    /// Estimates token count based on character count
    /// Apple's on-device LLM uses ~4 characters per token
    static func estimateTokens(from text: String) -> Int {
        return text.count / 4
    }

    /// Calculates remaining tokens in the 4096 context window
    /// - Parameters:
    ///   - instructionSize: Size of system instructions in characters
    ///   - promptSize: Size of prompt in characters
    ///   - conversationHistory: Total conversation history size in characters
    ///   - responseBuffer: Reserved space for response (default 800 chars = ~200 tokens)
    /// - Returns: Estimated remaining tokens available
    static func remainingTokens(
        instructionSize: Int,
        promptSize: Int,
        conversationHistory: Int,
        responseBuffer: Int = 800
    ) -> Int {
        let totalUsed = instructionSize + promptSize + conversationHistory + responseBuffer
        let tokensUsed = estimateTokens(from: String(repeating: "x", count: totalUsed))
        return max(0, 4096 - tokensUsed)
    }

    /// Calculates maximum safe prompt size given existing context
    /// - Parameters:
    ///   - instructionSize: Size of system instructions in characters
    ///   - conversationHistory: Total conversation history size in characters (all past prompts + responses)
    ///   - responseBuffer: Reserved space for upcoming response (default 800 chars = ~200 tokens)
    ///   - safetyMargin: Additional safety margin in tokens (default 50)
    /// - Returns: Maximum prompt size in characters for the CURRENT prompt
    ///
    /// Formula: available_for_current_prompt = 4096 - instructions - history - upcoming_response - margin
    static func maxPromptSize(
        instructionSize: Int,
        conversationHistory: Int,
        responseBuffer: Int = 800,
        safetyMargin: Int = 50
    ) -> Int {
        let reservedChars = instructionSize + conversationHistory + responseBuffer
        let reservedTokens = estimateTokens(from: String(repeating: "x", count: reservedChars))
        let availableTokens = max(0, 4096 - reservedTokens - safetyMargin)
        return availableTokens * 4
    }

    /// Analyzes context usage for a specialist session
    /// - Parameters:
    ///   - instructionSize: Size of system instructions in characters
    ///   - promptSize: Size of current/max prompt in characters
    ///   - conversationHistory: Total conversation history size in characters (all past prompts + responses)
    /// - Returns: Usage analysis with warnings
    ///
    /// Formula: total_tokens = instructions + current_prompt + history + response_buffer(800)
    static func analyzeUsage(
        instructionSize: Int,
        promptSize: Int,
        conversationHistory: Int
    ) -> ContextUsageAnalysis {
        let totalChars = instructionSize + promptSize + conversationHistory + 800 // response buffer
        let estimatedTokens = estimateTokens(from: String(repeating: "x", count: totalChars))
        let percentUsed = Double(estimatedTokens) / 4096.0

        var warnings: [String] = []

        if percentUsed > 0.95 {
            warnings.append("CRITICAL: Context usage at \(Int(percentUsed * 100))%")
        } else if percentUsed > 0.85 {
            warnings.append("WARNING: Context usage at \(Int(percentUsed * 100))%")
        } else if percentUsed > 0.75 {
            warnings.append("HIGH: Context usage at \(Int(percentUsed * 100))%")
        }

        if promptSize > 1200 {
            warnings.append("Prompt size (\(promptSize) chars) exceeds recommended 1200")
        }

        return ContextUsageAnalysis(
            totalTokens: estimatedTokens,
            percentUsed: percentUsed,
            remainingTokens: max(0, 4096 - estimatedTokens),
            warnings: warnings
        )
    }
}

struct ContextUsageAnalysis {
    let totalTokens: Int
    let percentUsed: Double
    let remainingTokens: Int
    let warnings: [String]

    var isHealthy: Bool {
        percentUsed < 0.85
    }

    var description: String {
        """
        Tokens: \(totalTokens)/4096 (\(Int(percentUsed * 100))%)
        Remaining: \(remainingTokens) tokens
        \(warnings.isEmpty ? "✓ Healthy" : "⚠️ \(warnings.joined(separator: ", "))")
        """
    }
}
