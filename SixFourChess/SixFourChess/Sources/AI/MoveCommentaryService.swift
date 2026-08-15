//
//  MoveCommentaryService.swift
//  SixFourChess
//
//  Analyzes a played move and returns a comment (quality + message).
//  Works only with `ChessState` (Sendable, nonisolated) - no network access,
//  no actors, fully synchronous.
//

import Foundation

struct MoveCommentaryService {

    // MARK: - Public API

    /// Analyzes the played move and returns a `MoveComment`.
    /// - Parameters:
    ///   - move: The move that was just played.
    ///   - stateAfter: `ChessState` **after** the move was applied.
    func analyze(move: Move, stateAfter: ChessState) -> MoveComment {
        let boardAfter = ChessBoard(state: stateAfter)
        let opponent = stateAfter.currentPlayer // opponent to move after the move

        // -- 1. Game end --
        if let result = boardAfter.checkGameEnd() {
            return endGameComment(for: result)
        }

        // -- 2. Check --
        if stateAfter.isInCheck(color: opponent) {
            let capture = move.capturedPiece != nil ? " (prise)" : ""
            return MoveComment(
                quality: .good,
                message: "moveComment.check".localized + capture,
                icon: "exclamationmark.triangle.fill",
                accentColor: "#FF9800"
            )
        }

        // -- 3. Castling --
        if move.isCastling {
            return MoveComment(
                quality: .good,
                message: "moveComment.castling".localized,
                icon: "arrow.left.arrow.right",
                accentColor: "#4CAF50"
            )
        }

        // -- 4. En passant --
        if move.isEnPassant {
            return MoveComment(
                quality: .good,
                message: "moveComment.enPassant".localized,
                icon: "figure.walk",
                accentColor: "#4CAF50"
            )
        }

        // -- 5. Promotion --
        if let promo = move.promotionType {
            return MoveComment(
                quality: .brilliant,
                message: "moveComment.promotion".localized(with: promo.symbol),
                icon: "crown",
                accentColor: "#FFD700"
            )
        }

        // -- 6. Capture: exchange evaluation --
        if let captured = move.capturedPiece {
            return evaluateCapture(attacker: move.piece, captured: captured)
        }

        // -- 7. Quiet move: positional heuristic --
        return quietMoveComment(move: move, state: stateAfter)
    }

    // MARK: - Private

    private func evaluateCapture(attacker: Piece, captured: Piece) -> MoveComment {
        let gain = captured.type.value - attacker.type.value
        if gain >= 200 {
            return MoveComment(
                quality: .brilliant,
                message: "moveComment.winningCapture".localized,
                icon: "star.fill",
                accentColor: "#FFD700"
            )
        } else if gain > 0 {
            return MoveComment(
                quality: .good,
                message: "moveComment.goodCapture".localized,
                icon: "hand.thumbsup.fill",
                accentColor: "#4CAF50"
            )
        } else if gain == 0 {
            return MoveComment(
                quality: .good,
                message: "moveComment.equalTrade".localized,
                icon: "equal.circle",
                accentColor: "#2196F3"
            )
        } else {
            return MoveComment(
                quality: .inaccuracy,
                message: "moveComment.badCapture".localized,
                icon: "exclamationmark.circle",
                accentColor: "#FF9800"
            )
        }
    }

    private func endGameComment(for result: GameResult) -> MoveComment {
        switch result {
        case .checkmate:
            return MoveComment(
                quality: .brilliant,
                message: "moveComment.checkmate".localized,
                icon: "crown.fill",
                accentColor: "#FFD700"
            )
        case .stalemate:
            return MoveComment(
                quality: .good,
                message: "moveComment.stalemate".localized,
                icon: "equal.circle.fill",
                accentColor: "#607D8B"
            )
        case .drawByRepetition:
            return MoveComment(
                quality: .good,
                message: "moveComment.drawRepetition".localized,
                icon: "repeat.circle.fill",
                accentColor: "#607D8B"
            )
        case .drawByFiftyMoves:
            return MoveComment(
                quality: .good,
                message: "moveComment.drawFiftyMoves".localized,
                icon: "clock.arrow.circlepath",
                accentColor: "#607D8B"
            )
        case .corruptedMatch:
            return MoveComment(
                quality: .inaccuracy,
                message: "moveComment.gameOver".localized,
                icon: "exclamationmark.circle",
                accentColor: "#FF9800"
            )
        }
    }

    private func quietMoveComment(move: Move, state: ChessState) -> MoveComment {
        let moveCount = state.moveHistoryDetailed.count
        if moveCount <= 12 {
            if isCentralPawnAdvance(move) {
                return MoveComment(
                    quality: .good,
                    message: "moveComment.center".localized,
                    icon: "scope",
                    accentColor: "#4CAF50"
                )
            }

            if isMinorPieceDevelopment(move) {
                return MoveComment(
                    quality: .good,
                    message: "moveComment.developsPiece".localized,
                    icon: "figure.chess.knight",
                    accentColor: "#4CAF50"
                )
            }

            if isPieceTowardCenter(move) {
                return MoveComment(
                    quality: .good,
                    message: "moveComment.activatesPiece".localized,
                    icon: "arrow.up.right.circle",
                    accentColor: "#2196F3"
                )
            }

            return MoveComment(
                quality: .good,
                message: "moveComment.usefulDevelopment".localized,
                icon: "arrow.forward.circle",
                accentColor: "#4CAF50"
            )
        }

        if moveCount <= 28 {
            if isPieceTowardCenter(move) {
                return MoveComment(
                    quality: .good,
                    message: "moveComment.improvesActivity".localized,
                    icon: "arrow.up.right.circle",
                    accentColor: "#2196F3"
                )
            }

            return MoveComment(
                quality: .good,
                message: "moveComment.solidPosition".localized,
                icon: "shield.lefthalf.filled",
                accentColor: "#2196F3"
            )
        }

        return MoveComment(
            quality: .good,
            message: "moveComment.looksForWeakness".localized,
            icon: "circle.hexagongrid.fill",
            accentColor: "#607D8B"
        )
    }

    private func isCentralPawnAdvance(_ move: Move) -> Bool {
        guard move.piece.type == .pawn else { return false }
        let centralFiles = Set([3, 4]) // d, e
        let centralRanks = Set([3, 4]) // 5th/4th from matrix perspective
        let startingRow = move.piece.color == .white ? 6 : 1

        return move.from.row == startingRow &&
            centralFiles.contains(move.from.col) &&
            centralFiles.contains(move.to.col) &&
            centralRanks.contains(move.to.row)
    }

    private func isMinorPieceDevelopment(_ move: Move) -> Bool {
        guard move.piece.type == .knight || move.piece.type == .bishop else { return false }
        return isStartingSquare(move.from, for: move.piece) && isPieceTowardCenter(move)
    }

    private func isPieceTowardCenter(_ move: Move) -> Bool {
        guard move.piece.type != .king else { return false }
        let fromDistance = centerDistance(for: move.from)
        let toDistance = centerDistance(for: move.to)
        return toDistance < fromDistance
    }

    private func isStartingSquare(_ position: Position, for piece: Piece) -> Bool {
        switch (piece.color, piece.type) {
        case (.white, .knight):
            return position == Position(row: 7, col: 1) || position == Position(row: 7, col: 6)
        case (.black, .knight):
            return position == Position(row: 0, col: 1) || position == Position(row: 0, col: 6)
        case (.white, .bishop):
            return position == Position(row: 7, col: 2) || position == Position(row: 7, col: 5)
        case (.black, .bishop):
            return position == Position(row: 0, col: 2) || position == Position(row: 0, col: 5)
        default:
            return false
        }
    }

    private func centerDistance(for position: Position) -> Int {
        let centerRows = [3, 4]
        let centerCols = [3, 4]
        let rowDistance = centerRows.map { abs(position.row - $0) }.min() ?? 0
        let colDistance = centerCols.map { abs(position.col - $0) }.min() ?? 0
        return rowDistance + colDistance
    }
}
