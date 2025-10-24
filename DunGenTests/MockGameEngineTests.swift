import Testing
import Foundation
@testable import DunGen

@MainActor
struct MockGameEngineTests {

    @Test("MockGameEngine starts with mock data")
    func testMockMode() async throws {
        let engine = MockGameEngine(mode: .mock)

        #expect(engine.character != nil)
        #expect(engine.character?.name == "Test Hero")
        #expect(engine.worldState != nil)
        #expect(engine.worldState?.locations.count == 3)
        #expect(engine.log.count == 1)
        #expect(engine.log.first?.content.contains("mock") == true)
    }

    @Test("MockGameEngine can submit player actions in mock mode")
    func testMockModeSubmitPlayer() async throws {
        let engine = MockGameEngine(mode: .mock)

        let initialLogCount = engine.log.count
        await engine.submitPlayer(input: "explore the village")

        #expect(engine.log.count > initialLogCount)
        #expect(engine.submitPlayerCallCount == 1)
        #expect(engine.lastSubmittedInput == "explore the village")
    }

    @Test("MockGameEngine can use LLM mode", .enabled(if: isLLMAvailable()))
    func testLLMMode() async throws {
        let engine = MockGameEngine(mode: .llm)

        await engine.startNewGame(preferredType: .outdoor, usedNames: [])

        #expect(engine.character != nil)
        #expect(engine.worldState != nil)
        #expect(engine.log.count > 0)
    }

    @Test("MockGameEngine can submit player actions in LLM mode", .enabled(if: isLLMAvailable()))
    func testLLMModeSubmitPlayer() async throws {
        let engine = MockGameEngine(mode: .llm)

        await engine.startNewGame(preferredType: .outdoor, usedNames: [])

        let initialLogCount = engine.log.count
        await engine.submitPlayer(input: "look around")

        #expect(engine.log.count > initialLogCount)
        #expect(engine.submitPlayerCallCount == 1)
    }

    @Test("MockGameEngine tracks call counts in both modes")
    func testCallCounting() async throws {
        let mockEngine = MockGameEngine(mode: .mock)
        await mockEngine.startNewGame(preferredType: .village, usedNames: [])
        await mockEngine.submitPlayer(input: "test")

        #expect(mockEngine.startNewGameCallCount == 1)
        #expect(mockEngine.submitPlayerCallCount == 1)
    }
}

private func isLLMAvailable() -> Bool {
    #if targetEnvironment(simulator)
    return false
    #else
    return true
    #endif
}
