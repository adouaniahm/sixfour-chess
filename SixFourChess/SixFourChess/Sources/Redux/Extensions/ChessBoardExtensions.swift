//
//  ChessBoardExtensions.swift
//  SixFourChess
//
//  Redux extensions for ChessBoard
//

import Foundation

extension ChessBoard {
    /// Check if the game has ended and return the result
    func checkGameEnd() -> GameResult? {
        if isCheckmate(for: currentPlayer) {
            return .checkmate(winner: currentPlayer.opposite)
        }
        if isStalemate(for: currentPlayer) {
            return .stalemate
        }
        if isThreefoldRepetition() {
            return .drawByRepetition
        }
        if isFiftyMoveRule() {
            return .drawByFiftyMoves
        }
        return nil
    }

    /// Check if king is in check
    func isKingInCheck(_ color: PieceColor) -> Bool {
        return isInCheck(color: color)
    }
}
