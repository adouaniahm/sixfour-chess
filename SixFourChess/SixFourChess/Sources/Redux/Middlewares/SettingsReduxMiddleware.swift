//
//  SettingsReduxMiddleware.swift
//  SixFourChess
//
//  Settings Middleware using ReduxMiddleware pattern - Persists to UserDefaults
//

import Foundation

// MARK: - SettingsReduxMiddleware
//
// ROLE: Persists user preferences in UserDefaults.
//        Middleware leger (39 lignes).
//
// INTERCEPTED ACTIONS:
//   .game(.changeGameMode(mode))        -> saves the game mode
//   .game(.changeDifficulty(difficulty)) -> saves the AI difficulty
//   .game(.newGame(mode, difficulty))    -> saves mode + difficulty
//
// SIDE EFFECTS:
//   - UserDefaults writes via `UserSettingsStorage`
//
// DISPATCHED ACTIONS: none

/// User-preference persistence middleware (`UserDefaults`).
final class SettingsReduxMiddleware: ReduxMiddleware {
    
    @Dependency(\.userSettings) var storage

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction,
              case .game(let gameAction) = appAction else {
            return emptyFlow()
        }

        let gameState = state.gameState

        switch gameAction {
        case .changeGameMode(let mode):
            storage.save(gameMode: mode, difficulty: gameState.difficulty)
            return emptyFlow()

        case .changeDifficulty(let difficulty):
            storage.save(gameMode: gameState.gameMode, difficulty: difficulty)
            return emptyFlow()

        case .newGame(let mode, let difficulty):
            storage.save(gameMode: mode, difficulty: difficulty)
            return emptyFlow()

        default:
            return emptyFlow()
        }
    }
}
