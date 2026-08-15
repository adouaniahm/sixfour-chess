//
//  AccessibilityReduxMiddleware.swift
//  SixFourChess
//

import Foundation
import UIKit

final class AccessibilityReduxMiddleware: ReduxMiddleware {
    @Dependency(\.accessibilityService) private var accessibility

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard UIAccessibility.isVoiceOverRunning else { return emptyFlow() }
        guard let appAction = action as? AppAction else { return emptyFlow() }

        switch appAction {
        case .game(let gameAction):
            handleGameAction(gameAction, state: state)
        case .ui:
            break
        }

        return emptyFlow()
    }

    private func handleGameAction(_ action: GameAction, state: AppState) {
        let gameState = state.gameState
        let mode = gameState.mode

        switch action {
        case .makeMove(let move):
            let boardAfterMove = gameState.board
            let moveApplied = boardAfterMove.makeMove(move)

            if move.isCastling {
                accessibility.announceCastling(move: move, isPlayerMove: true, mode: mode)
            } else if let capturedPiece = move.capturedPiece {
                accessibility.announceCapture(move: move, capturedPiece: capturedPiece, mode: mode)
            } else {
                accessibility.announceMove(move: move, isPlayerMove: true, mode: mode)
            }

            guard moveApplied else { return }

            if let result = boardAfterMove.checkGameEnd() {
                switch result {
                case .checkmate(let winner):
                    accessibility.announceCheckmate(winner: winner, mode: mode)
                case .stalemate:
                    accessibility.announceDraw(reason: .stalemate)
                case .drawByRepetition:
                    accessibility.announceDraw(reason: .repetition)
                case .drawByFiftyMoves:
                    accessibility.announceDraw(reason: .fiftyMoves)
                case .corruptedMatch:
                    accessibility.announceDraw(reason: .corrupted)
                }
                return
            }

            if boardAfterMove.isInCheck(color: boardAfterMove.currentPlayer) {
                accessibility.announceCheck(threateningPieces: [])
            }
            accessibility.announceTurn(for: boardAfterMove.currentPlayer, mode: mode)

        case .endGame(let result):
            switch result {
            case .checkmate(let winner):
                accessibility.announceCheckmate(winner: winner, mode: mode)
            case .stalemate:
                accessibility.announceDraw(reason: .stalemate)
            case .drawByRepetition:
                accessibility.announceDraw(reason: .repetition)
            case .drawByFiftyMoves:
                accessibility.announceDraw(reason: .fiftyMoves)
            case .corruptedMatch:
                accessibility.announceDraw(reason: .corrupted)
            }

        case .promotePawn(let pieceType):
            accessibility.announcePromotion(to: pieceType.localizedName)

        default:
            break
        }
    }
}
