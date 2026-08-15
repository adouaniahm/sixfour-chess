import Testing
import Foundation
@testable import SixFour

/// Tests du contrat GamePersistenceProtocol via MockPersistence.
/// Vérifie la logique save/load/clear sans dépendance SwiftData.
@MainActor
@Suite struct PersistenceTests {

    private let aiMode = GameModeState.ai(AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: .medium))

    @Test func saveAndLoad() {
        let persistence = MockPersistence()
        var state = GameState.initial
        state.mode = aiMode
        state.isActive = true

        persistence.save(gameState: state)
        let loaded = persistence.loadSnapshot(for: aiMode)

        #expect(loaded != nil)
        #expect(loaded?.isActive == true)
    }

    @Test func loadWithoutSaveReturnsNil() {
        let persistence = MockPersistence()

        let loaded = persistence.loadSnapshot(for: aiMode)

        #expect(loaded == nil)
    }

    @Test func clearThenLoadReturnsNil() {
        let persistence = MockPersistence()
        persistence.save(gameState: GameState.initial)

        persistence.clearSnapshot(for: aiMode)
        let loaded = persistence.loadSnapshot(for: aiMode)

        #expect(loaded == nil)
    }

    @Test func saveOverwritesPrevious() {
        let persistence = MockPersistence()

        var state1 = GameState.initial
        state1.isActive = true
        persistence.save(gameState: state1)

        var state2 = GameState.initial
        state2.isActive = false
        persistence.save(gameState: state2)

        let loaded = persistence.loadSnapshot(for: aiMode)
        #expect(loaded?.isActive == false)
    }
}
