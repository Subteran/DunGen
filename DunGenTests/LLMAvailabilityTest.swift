import Testing
import FoundationModels
@testable import DunGen

@MainActor
@Suite("LLM Availability Diagnostic")
struct LLMAvailabilityTest {

    @Test("Check SystemLanguageModel availability")
    func checkLLMAvailability() {
        let availability = SystemLanguageModel.default.availability

        print("=== LLM AVAILABILITY DIAGNOSTIC ===")
        print("SystemLanguageModel.default.availability: \(availability)")

        switch availability {
        case .available:
            print("✅ LLM IS AVAILABLE")
        case .unavailable(let reason):
            print("❌ LLM IS UNAVAILABLE")
            print("Reason: \(reason)")
        }

        print("===================================")

        #expect(true, "This test always passes - just printing availability")
    }
}
