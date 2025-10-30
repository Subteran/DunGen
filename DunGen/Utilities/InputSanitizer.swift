import Foundation

/// Handles sanitization and validation of user input to prevent prompt injection attacks
struct InputSanitizer {

    /// Result of input sanitization
    enum SanitizationResult {
        case valid(String)
        case rejected(reason: String)
    }

    // MARK: - Character Name Sanitization

    /// Sanitizes character names - strict validation
    static func sanitizeCharacterName(_ input: String) -> SanitizationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Length validation
        guard trimmed.count >= 2 else {
            return .rejected(reason: "Character name must be at least 2 characters long.")
        }
        guard trimmed.count <= 30 else {
            return .rejected(reason: "Character name must be 30 characters or less.")
        }

        // Only allow letters, spaces, hyphens, and apostrophes (typical fantasy names)
        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))

        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return .rejected(reason: "Character name can only contain letters, spaces, hyphens, and apostrophes.")
        }

        // Prevent common injection patterns
        if let reason = checkForInjectionPatterns(in: trimmed, context: "character name") {
            return .rejected(reason: reason)
        }

        return .valid(trimmed)
    }

    // MARK: - Player Action Sanitization

    /// Sanitizes custom player actions - more permissive but still safe
    static func sanitizePlayerAction(_ input: String) -> SanitizationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Length validation
        guard trimmed.count >= 3 else {
            return .rejected(reason: "Action must be at least 3 characters long.")
        }
        guard trimmed.count <= 500 else {
            return .rejected(reason: "Action must be 500 characters or less.")
        }

        // More permissive character set (alphanumeric + common punctuation)
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)

        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return .rejected(reason: "Action contains invalid characters. Use only letters, numbers, and common punctuation.")
        }

        // Detect injection attempts
        if let reason = checkForInjectionPatterns(in: trimmed, context: "action") {
            return .rejected(reason: reason)
        }

        // Remove any attempt to break out of context with quotes/backticks
        let sanitized = trimmed
            .replacingOccurrences(of: "\"\"\"", with: "")
            .replacingOccurrences(of: "```", with: "")

        return .valid(sanitized)
    }

    // MARK: - Injection Detection

    /// Checks for common prompt injection patterns
    private static func checkForInjectionPatterns(in input: String, context: String) -> String? {
        let lowercased = input.lowercased()

        // Comprehensive list of dangerous patterns
        let dangerousPatterns: [(pattern: String, hint: String)] = [
            ("ignore previous", "instructional language"),
            ("ignore all", "instructional language"),
            ("ignore instructions", "instructional language"),
            ("disregard", "instructional language"),
            ("new instruction", "instructional language"),
            ("system:", "system commands"),
            ("assistant:", "role manipulation"),
            ("you are now", "role manipulation"),
            ("act as if", "role manipulation"),
            ("act as a", "role manipulation"),
            ("pretend to be", "role manipulation"),
            ("pretend you", "role manipulation"),
            ("your role is", "role manipulation"),
            ("forget everything", "memory manipulation"),
            ("override", "command injection"),
            ("execute", "command injection"),
            ("run command", "command injection"),
            ("{{", "template injection"),
            ("}}", "template injection"),
            ("<|", "special token"),
            ("|>", "special token"),
            ("###", "markdown injection"),
            ("---", "delimiter injection")
        ]

        for (pattern, hint) in dangerousPatterns {
            if lowercased.contains(pattern) {
                return "The \(context) contains suspicious \(hint). Please describe your action naturally."
            }
        }

        // Check for excessive repetition (common in injection attempts)
        if detectExcessiveRepetition(in: lowercased) {
            return "The \(context) contains unusual repetition. Please write naturally."
        }

        return nil
    }

    /// Detects suspicious repetition patterns
    private static func detectExcessiveRepetition(in text: String) -> Bool {
        let words = text.split(separator: " ")
        guard words.count >= 5 else { return false }

        // Check for same word repeated 4+ times consecutively
        for i in 0..<(words.count - 3) {
            if words[i] == words[i+1] && words[i+1] == words[i+2] && words[i+2] == words[i+3] {
                return true
            }
        }

        return false
    }

    // MARK: - Input Wrapping

    /// Wraps user input with clear delimiters for the LLM
    /// This helps the model distinguish user data from instructions
    static func wrapUserInput(_ input: String, context: String) -> String {
        """
        [User Input - \(context)]
        \(input)
        [End User Input]
        """
    }
}
