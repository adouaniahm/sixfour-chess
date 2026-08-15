//
//  GameLogicReduxMiddleware.swift
//  SixFourChess
//
//  Game Logic Middleware using ReduxMiddleware pattern
//

import Foundation
import UIKit

// MARK: - GameLogicReduxMiddleware
//
// ROLE: Legal move validation and pawn promotion handling.
//
// ACTIONS INTERCEPTEES :
//   .game(.selectSquare(position)) -> computes legal moves for the selected piece
//   .game(.makeMove(move))         -> validates the move and detects check/checkmate/stalemate
//   .game(.promotePawn(pieceType)) -> finalizes promotion with the chosen piece
//
// EFFETS DE BORD :
//   - Haptic feedback via AccessibilityService on selection
//
// ACTIONS DISPATCHEES :
//   .game(.setAvailableMoves)     -> legal moves for the selected piece
//   .game(.clearAvailableMoves)   -> when the selection is cleared
//   .game(.deselectSquare)        -> when the user taps an empty square
//   .ui(.setPromotionAlert)       -> when a pawn reaches the last rank
//   .ui(.setAIPromotionAlert)     -> when the AI promotes a pawn, for player feedback
//   .game(.endGame(result))       -> when the move ends the game

/// Middleware for move validation and promotion.
final class GameLogicReduxMiddleware: ReduxMiddleware {
    private let dispatchContext: DispatchContext
    @Dependency(\.accessibilityService) private var accessibility

    init(dispatchContext: DispatchContext) {
        self.dispatchContext = dispatchContext
    }

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction,
              case .game(let gameAction) = appAction else {
            return emptyFlow()
        }

        let gameState = state.gameState

        switch gameAction {
        case .selectSquare(let position):
            // When a square is selected, calculate available moves
            if let piece = gameState.board.piece(at: position),
               piece.color == gameState.board.currentPlayer {
                let allMoves = gameState.board.getAllLegalMoves(for: piece.color)
                let movesForPiece = allMoves.filter { $0.from == position }
                Logger.debug("Selected \(piece.type) at \(position.notation) - \(movesForPiece.count) moves available", subsystem: .game)

                // Always show available move dots on the board.
                // For promotion moves, deduplicate by destination (engine generates 4 per square).
                var seenDestinations = Set<Position>()
                let dedupedMoves = movesForPiece.filter { seenDestinations.insert($0.to).inserted }
                dispatchContext.dispatch(AppAction.game(.setAvailableMoves(moves: dedupedMoves)))

                // VoiceOver: Announce available moves
                if UIAccessibility.isVoiceOverRunning {
                    let pieceName = piece.type.localizedName
                    let destinations = dedupedMoves.map { $0.to.notation }
                    accessibility.announceAvailableMoves(
                        piece: pieceName,
                        from: position.notation,
                        moves: destinations
                    )
                }
            }
            return emptyFlow()

        case .makeMove(let move):
            // Promotion is handled by selectSquare (show dots) + handleSquareTapped (show picker).
            // No re-trigger is needed here: promotePawn dispatches makeMove with the chosen type.

            // The middleware sees state before reduction, so we simulate the move locally
            // to inspect the real board after the move.
            var stateAfter = gameState.board.state
            let comment = if stateAfter.makeMove(move) {
                MoveCommentaryService().analyze(move: move, stateAfter: stateAfter)
            } else {
                MoveComment(
                    quality: .good,
                    message: "Move played",
                    icon: "checkmark.circle",
                    accentColor: "#2196F3"
                )
            }

            if UserSettingsStorage.shared.loadMoveCommentsEnabled() {
                self.dispatchContext.dispatch(AppAction.ui(.showMoveComment(comment)))
            }

            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self.dispatchContext.dispatch(AppAction.ui(.clearMoveComment))
            }
            return emptyFlow()

        case .promotePawn(let pieceType):
            // Find the promotion move with the selected piece type.
            if let moves = state.uiState.promotionMoves.first(where: { move in
                move.promotionType == pieceType
            }) {
                Logger.info("Pawn promoted to \(pieceType)", subsystem: .game)
                dispatchContext.dispatch(AppAction.ui(.setPromotionAlert(moves: [])))
                dispatchContext.dispatch(AppAction.game(.makeMove(move: moves)))
            }
            return emptyFlow()

        default:
            return emptyFlow()
        }
    }

}
