//
//  GameSelectors.swift
//  SixFourChess
//
//  Redux Game Selectors - Computed properties from state
//

import Foundation

/// Selectors for game state
struct GameSelectors {
    /// Get captured pieces for a specific color
    static func capturedPieces(for color: PieceColor, state: GameState) -> [Piece] {
        return state.board.capturedPieces.filter { $0.color != color }
    }

    /// Check if it's the current player's turn
    static func isCurrentPlayer(_ color: PieceColor, state: GameState) -> Bool {
        return state.board.currentPlayer == color
    }

    /// Check if a position is selected
    static func isSelected(_ position: Position, state: GameState) -> Bool {
        return state.selectedPosition == position
    }

    /// Check if a move is available from selected position
    static func isAvailableMove(to position: Position, state: GameState) -> Bool {
        return state.availableMoves.contains { $0.to == position }
    }

    /// Get the move to a specific position (if available)
    static func move(to position: Position, state: GameState) -> Move? {
        return state.availableMoves.first { $0.to == position }
    }

    /// Check if current player is AI
    static func isCurrentPlayerAI(state: GameState) -> Bool {
        return state.isCurrentPlayerAI
    }

    /// Check if a specific player is AI
    static func isAI(_ color: PieceColor, state: GameState) -> Bool {
        switch color {
        case .white:
            return state.whiteAIEnabled
        case .black:
            return state.blackAIEnabled
        }
    }

    /// Get the last move played
    static func lastMove(state: GameState) -> Move? {
        return state.board.lastMove
    }

    /// Check if a position was part of the last move
    static func isLastMovePosition(_ position: Position, state: GameState) -> Bool {
        guard let lastMove = state.board.lastMove else {
            return false
        }
        return lastMove.from == position || lastMove.to == position
    }

    /// Check if the game can be undone
    static func canUndo(state: GameState) -> Bool {
        return !state.board.moveHistory.isEmpty
    }

    /// Get the current game status as a localized string
    static func gameStatusText(state: GameState) -> String? {
        if let result = state.gameResult {
            switch result {
            case .checkmate(let winner):
                return "game.status.checkmate.\(winner)".localized
            case .stalemate:
                return "game.status.stalemate".localized
            case .drawByRepetition:
                return "game.status.drawByRepetition".localized
            case .drawByFiftyMoves:
                return "game.status.drawByFiftyMoves".localized
            case .corruptedMatch:
                return "game.status.corruptedMatch".localized
            }
        }
        return nil
    }

    /// Check if a position is under attack
    static func isUnderAttack(_ position: Position, by color: PieceColor, state: GameState) -> Bool {
        // This is a complex calculation, simplified for now
        return false
    }

    /// Check if king is in check
    static func isKingInCheck(state: GameState) -> Bool {
        return state.board.isKingInCheck(state.board.currentPlayer)
    }

    /// Get move count
    static func moveCount(state: GameState) -> Int {
        return state.board.moveHistory.count
    }

    /// Get current turn number
    static func turnNumber(state: GameState) -> Int {
        return state.board.fullMoveNumber
    }
}
