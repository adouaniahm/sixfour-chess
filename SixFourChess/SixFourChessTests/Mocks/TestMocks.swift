//
//  TestMocks.swift
//  SixFourChessAppTests
//

import Foundation
@testable import SixFour

class MockAnalyticsService: AnalyticsServiceProtocol {
    var events: [String] = []
    var screens: [String] = []

    func logEvent(_ name: String, parameters: [String : Any]?) {
        events.append(name)
    }

    func logScreen(name: String, class className: String) {
        screens.append(name)
    }

    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserId(_ userId: String?) {}
}

@MainActor
class MockPersistence: GamePersistenceProtocol {
    var savedSnapshot: GameStateSnapshot?
    var archivedGames: [PlayedGameRecord] = []

    func save(gameState: GameState) {
        savedSnapshot = gameState.snapshot()
    }

    func loadSnapshot(for mode: GameModeState) -> GameStateSnapshot? {
        _ = mode
        return savedSnapshot
    }

    func clearSnapshot(for mode: GameModeState?) {
        _ = mode
        savedSnapshot = nil
    }

    func archivePlayedGame(_ gameState: GameState) {
        let record = PlayedGameRecord(
            id: UUID().uuidString,
            startedAt: gameState.startedAt,
            finishedAt: Date(),
            result: gameState.gameResult,
            moveHistory: gameState.board.moveHistory,
            moveHistoryDetailed: gameState.board.moveHistoryDetailed,
            mode: gameState.mode,
            difficulty: gameState.difficulty
        )
        archivedGames.append(record)
    }

    func loadPlayedGames() -> [PlayedGameRecord] {
        archivedGames
    }

    func clearPlayedGames() {
        archivedGames.removeAll()
    }
}

class MockConsentManager: ConsentManagerProtocol {
    var consents: [ConsentPermission: Bool] = [:]

    func hasConsent(for permission: ConsentPermission) -> Bool {
        consents[permission] ?? false
    }

    func grantConsent(for permissions: Set<ConsentPermission>) {
        for permission in permissions {
            consents[permission] = true
        }
    }

    func revokeConsent(for permissions: Set<ConsentPermission>) {
        for permission in permissions {
            consents[permission] = false
        }
    }

    func getAllConsents() -> [ConsentPermission : ConsentStatus] {
        [:]
    }
}

class MockStore: Dispatching {
    var actions: [ReduxAction] = []

    func dispatch(_ action: ReduxAction) {
        actions.append(action)
    }
}
