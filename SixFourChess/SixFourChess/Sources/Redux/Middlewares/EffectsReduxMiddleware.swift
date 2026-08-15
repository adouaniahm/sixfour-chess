//
//  EffectsReduxMiddleware.swift
//  SixFourChess
//
//  Post-action effects middleware (auto-trigger AI, undo, persistence)
//

import Foundation
import UIKit

// MARK: - EffectsReduxMiddleware
//
// ROLE: Handles post-action effects: auto-trigger AI, undo, persistence.
//        Runs last in the chain (position 10/10).
//
// ACTIONS INTERCEPTEES :
//   .game(.makeMove/.newGame/.resetGame/.restoreSnapshot) -> autoTriggerAIEffect()
//     If it is the AI's turn after the action, dispatch .triggerAIMove
// SIDE EFFECTS:
//   - Persistence: save game state after each significant action
//
// ACTIONS DISPATCHEES :
//   .game(.triggerAIMove)    -> triggers AI calculation

/// Middleware for post-action effects (auto-trigger AI, undo, persistence).
final class EffectsReduxMiddleware: ReduxMiddleware {
    
    @Dependency(\.persistence) var persistence
    
    private let dispatchContext: DispatchContext

    init(dispatchContext: DispatchContext) {
        self.dispatchContext = dispatchContext
    }

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction,
              case .game(let gameAction) = appAction else {
            return emptyFlow()
        }

        let gameState = state.gameState

        // Auto-trigger AI effect.
        autoTriggerAIEffect(gameAction: gameAction, gameState: gameState)

        // Persistence effect.
        persistenceEffect(gameAction: gameAction, gameState: gameState)

        // Played games history effect.
        playedGamesHistoryEffect(gameAction: gameAction, gameState: gameState)

        return emptyFlow()
    }

    // MARK: - Auto-trigger AI Effect

    private func autoTriggerAIEffect(gameAction: GameAction, gameState: GameState) {
        switch gameAction {
        case .makeMove, .newGame, .resetGame, .restoreSnapshot:
            guard gameState.isActive, gameState.isCurrentPlayerAI, !gameState.isThinking else { return }

            // Add a delay so VoiceOver can finish announcements.
            let delay: UInt64 = UIAccessibility.isVoiceOverRunning ? 2_000_000_000 : 0 // 2 seconds if VoiceOver

            Task { @MainActor in
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }
                dispatchContext.dispatch(AppAction.game(.triggerAIMove))
            }
        default:
            break
        }
    }

    // MARK: - Persistence Effect

    private func persistenceEffect(gameAction: GameAction, gameState: GameState) {
        let shouldPersist: Bool = {
            switch gameAction {
            case .makeMove,
                 .resetGame,
                 .newGame,
                 .changeGameMode,
                 .changeDifficulty,
                 .endGame,
                 .restoreSnapshot:
                return true
            default:
                return false
            }
        }()

        guard shouldPersist else { return }

        Task { @MainActor in
            persistence.save(gameState: gameState)
        }
    }

    private func playedGamesHistoryEffect(gameAction: GameAction, gameState: GameState) {
        guard !gameState.isArchivedInHistory else { return }

        let gameToArchive: GameState? = {
            switch gameAction {
            case .endGame:
                return gameState
            case .makeMove(let move):
                var archivedState = gameState
                archivedState.board.makeMove(move)
                guard let result = archivedState.board.checkGameEnd() else { return nil }
                archivedState.gameResult = result
                archivedState.isActive = false
                archivedState.selectedPosition = nil
                archivedState.availableMoves = []
                archivedState.suggestedMove = nil
                return archivedState
            default:
                return nil
            }
        }()

        guard let gameToArchive else { return }

        Task { @MainActor in
            persistence.archivePlayedGame(gameToArchive)
            dispatchContext.dispatch(AppAction.game(.setArchivedInHistory(true)))
        }
    }
}
