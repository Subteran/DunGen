import Testing
import Foundation
@testable import DunGen

@MainActor
struct MockGameEngineTests {

    @Test("MockGameEngine starts with mock data")
    func testMockMode() async throws {
        let engine = MockGameEngine()

        #expect(engine.character != nil)
        #expect(engine.character?.name == "Test Hero")
        #expect(engine.worldState != nil)
        #expect(engine.worldState?.locations.count == 3)
        #expect(engine.log.count == 1)
        #expect(engine.log.first?.content.contains("mock") == true)
    }

    @Test("MockGameEngine can submit player actions")
    func testMockModeSubmitPlayer() async throws {
        let engine = MockGameEngine()

        let initialLogCount = engine.log.count
        await engine.submitPlayer(input: "explore the village")

        #expect(engine.log.count > initialLogCount)
        #expect(engine.submitPlayerCallCount == 1)
        #expect(engine.lastSubmittedInput == "explore the village")
    }

    @Test("MockGameEngine tracks call counts")
    func testCallCounting() async throws {
        let mockEngine = MockGameEngine()
        await mockEngine.startNewGame(preferredType: .village, usedNames: [])
        await mockEngine.submitPlayer(input: "test")

        #expect(mockEngine.startNewGameCallCount == 1)
        #expect(mockEngine.submitPlayerCallCount == 1)
    }
}

