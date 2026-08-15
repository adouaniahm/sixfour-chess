//
//  AudioHapticReduxMiddleware.swift
//  SixFourChess
//
//  Middleware for audio and haptic feedback based on game actions
//

import Foundation

// MARK: - AudioHapticReduxMiddleware
//
// ROLE : Retour sonore et haptique. Middleware PASSIF (ne mute pas l'etat).
//
// ACTIONS INTERCEPTEES :
//   .game(.makeMove)       -> son de coup + vibration
//   .game(.endGame)        -> son de fin de partie
//   .game(.selectSquare)   -> vibration legere
//   .ui(.setSettingsVisible) -> vibration de navigation
//
// EFFETS DE BORD :
//   - AudioService : lecture de sons
//   - HapticService : vibrations UIFeedbackGenerator
//
// ACTIONS DISPATCHEES : aucune (middleware passif)

/// Middleware passif de retour sonore et haptique.
final class AudioHapticReduxMiddleware: ReduxMiddleware {

    @Dependency(\.audioService) var audio
    @Dependency(\.hapticService) var haptic

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction else {
            return emptyFlow()
        }

        switch appAction {
        case .game(let gameAction):
            handleGameAction(gameAction, state: state.gameState)

        case .ui(let uiAction):
            handleUIAction(uiAction, state: state.gameState)
        }

        // Passive middleware - only side effects
        return emptyFlow()
    }

    // MARK: - Game Actions

    private func handleGameAction(_ action: GameAction, state: GameState) {
        switch action {
        case .selectSquare:
            Logger.debug("Audio: piece selected", subsystem: .game)
            haptic.pieceSelected()
            audio.playMoveSound()

        case .makeMove(let move):
            if move.capturedPiece != nil {
                Logger.debug("Audio: capture sound", subsystem: .game)
                haptic.pieceCaptured()
                audio.playCaptureSound()
            } else {
                Logger.debug("Audio: move sound", subsystem: .game)
                haptic.moveMade()
                audio.playMoveSound()
            }

        case .endGame:
            // Game end is handled in completeAnimatedMove since the reducer
            // sets gameResult directly in .makeMove without dispatching .endGame
            break

        default:
            break
        }
    }

    // MARK: - UI Actions

    private func handleUIAction(_ action: UIAction, state: GameState) {
        switch action {
        case .animateMove:
            // Check is detected after animation completes via completeAnimatedMove
            break

        case .completeAnimatedMove:
            // Check for game end first (checkmate, stalemate, etc.)
            if let result = state.gameResult {
                switch result {
                case .checkmate(let winner):
                    Logger.success("Game ended: Checkmate! \(winner) wins", subsystem: .game)
                    haptic.checkmate()
                    audio.playVictorySound()

                case .stalemate:
                    Logger.info("Game ended: Stalemate", subsystem: .game)
                    haptic.stalemate()

                case .drawByRepetition:
                    Logger.info("Game ended: Draw by repetition", subsystem: .game)
                    haptic.stalemate()

                case .drawByFiftyMoves:
                    Logger.info("Game ended: Draw by 50 moves rule", subsystem: .game)
                    haptic.stalemate()

                case .corruptedMatch:
                    Logger.error("Game ended: Corrupted match", subsystem: .game)
                    break
                }
            } else if state.board.isInCheck(color: state.board.currentPlayer) {
                Logger.info("Check! \(state.board.currentPlayer) king is in check", subsystem: .game)
                haptic.check()
                audio.playCheckSound()
            }

        default:
            break
        }
    }
}
