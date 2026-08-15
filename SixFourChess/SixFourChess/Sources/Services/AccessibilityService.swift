//
//  AccessibilityService.swift
//  SixFourChess
//

import Foundation
import UIKit

enum DrawReason {
    case stalemate
    case repetition
    case fiftyMoves
    case corrupted

    var localizedMessage: String {
        switch self {
        case .stalemate: return "a11y.announce.stalemate".localized
        case .repetition: return "a11y.announce.draw.repetition".localized
        case .fiftyMoves: return "a11y.announce.draw.fiftyMoves".localized
        case .corrupted: return "a11y.announce.draw".localized
        }
    }
}

protocol AccessibilityServiceProtocol {
    func enqueue(_ message: String)
    func cancelAll()
    func announceMove(move: Move, isPlayerMove: Bool, mode: GameModeState)
    func announceTurn(for color: PieceColor, mode: GameModeState)
    func announceCheck(threateningPieces: [Piece])
    func announceCheckmate(winner: PieceColor, mode: GameModeState)
    func announceDraw(reason: DrawReason)
    func announceCapture(move: Move, capturedPiece: Piece, mode: GameModeState)
    func announceCastling(move: Move, isPlayerMove: Bool, mode: GameModeState)
    func announcePromotion(to pieceType: String)
    func announceAvailableMoves(piece: String, from: String, moves: [String])
    func announceUndo(movesUndone: Int, mode: GameModeState)
    func announceGameSummary(gameState: GameState)
}

final class AccessibilityService: AccessibilityServiceProtocol {
    static let shared = AccessibilityService()

    private var queue: [String] = []
    private var isSpeaking = false

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(announcementDidFinish(_:)),
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func enqueue(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.append(message)
            if !self.isSpeaking {
                self.speakNext()
            }
        }
    }

    func cancelAll() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.queue.removeAll()
            self.isSpeaking = false
        }
    }

    private func speakNext() {
        guard !queue.isEmpty else {
            isSpeaking = false
            return
        }

        isSpeaking = true
        UIAccessibility.post(notification: .announcement, argument: queue.removeFirst())
    }

    @objc private func announcementDidFinish(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.speakNext()
        }
    }

    func announceMove(move: Move, isPlayerMove: Bool, mode: GameModeState) {
        _ = mode
        let pieceName = move.piece.type.localizedName
        let message = isPlayerMove
            ? "a11y.announce.yourMove".localized(with: pieceName, move.from.notation, move.to.notation)
            : "a11y.announce.botMove".localized(with: pieceName, move.from.notation, move.to.notation)
        enqueue(message)
    }

    func announceTurn(for color: PieceColor, mode: GameModeState) {
        let isPlayerTurn = !(mode.aiConfig?.isAIEnabled(for: color) ?? false)
        enqueue(isPlayerTurn ? "a11y.announce.yourTurnNow".localized : "a11y.announce.botTurnNow".localized)
    }

    func announceCheck(threateningPieces: [Piece]) {
        let message: String
        if threateningPieces.count == 1, let piece = threateningPieces.first {
            message = "a11y.announce.check.single".localized(with: piece.type.localizedName)
        } else if threateningPieces.count > 1 {
            message = "a11y.announce.check.double".localized(
                with: threateningPieces[0].type.localizedName,
                threateningPieces[1].type.localizedName
            )
        } else {
            message = "a11y.announce.check".localized
        }
        enqueue(message)
    }

    func announceCheckmate(winner: PieceColor, mode: GameModeState) {
        let playerWon = !(mode.aiConfig?.isAIEnabled(for: winner) ?? false)
        enqueue(playerWon ? "a11y.announce.checkmate.win".localized : "a11y.announce.checkmate.lose".localized)
    }

    func announceDraw(reason: DrawReason) {
        enqueue(reason.localizedMessage)
    }

    func announceCapture(move: Move, capturedPiece: Piece, mode: GameModeState) {
        let isPlayerMove = !(mode.aiConfig?.isAIEnabled(for: move.piece.color) ?? false)
        let capturedName = capturedPiece.type.localizedName
        let position = move.to.notation

        if move.isEnPassant {
            enqueue(
                isPlayerMove
                    ? "a11y.announce.capturedEnPassant".localized(with: capturedName, position)
                    : "a11y.announce.botCapturedEnPassant".localized(with: capturedName, position)
            )
        } else {
            enqueue(
                isPlayerMove
                    ? "a11y.announce.capturedAt".localized(with: capturedName, position)
                    : "a11y.announce.botCapturedAt".localized(with: capturedName, position)
            )
        }
    }

    func announceCastling(move: Move, isPlayerMove: Bool, mode: GameModeState) {
        _ = mode
        let isKingside = move.to.col > move.from.col
        let message: String
        if isKingside {
            message = isPlayerMove ? "a11y.announce.yourCastleKingside".localized : "a11y.announce.botCastleKingside".localized
        } else {
            message = isPlayerMove ? "a11y.announce.yourCastleQueenside".localized : "a11y.announce.botCastleQueenside".localized
        }
        enqueue(message)
    }

    func announcePromotion(to pieceType: String) {
        enqueue("a11y.announce.promotion".localized(with: pieceType))
    }

    func announceAvailableMoves(piece: String, from: String, moves: [String]) {
        _ = from
        let message: String
        switch moves.count {
        case 0:
            message = "a11y.announce.noMoves".localized(with: piece)
        case 1:
            message = "a11y.announce.oneMove".localized(with: piece, moves[0])
        default:
            message = "a11y.announce.multipleMoves".localized(with: piece, String(moves.count), moves.joined(separator: ", "))
        }
        enqueue(message)
    }

    func announceUndo(movesUndone: Int, mode: GameModeState) {
        _ = mode
        enqueue(movesUndone == 2 ? "a11y.announce.undoVsAI".localized : "a11y.announce.undo".localized)
    }

    func announceGameSummary(gameState: GameState) {
        var parts = ["a11y.announce.gameSummary.modeAI".localized(with: gameState.difficulty.localizedName)]

        let moveCount = gameState.board.moveHistory.count
        if moveCount > 0 {
            parts.append("a11y.announce.gameSummary.moveCount".localized(with: moveCount))
        }

        let isPlayerTurn = !(gameState.mode.aiConfig?.isAIEnabled(for: gameState.board.currentPlayer) ?? false)
        parts.append(isPlayerTurn ? "a11y.announce.gameSummary.yourTurn".localized : "a11y.announce.gameSummary.opponentTurn".localized)

        if gameState.board.isInCheck(color: gameState.board.currentPlayer) {
            parts.append("a11y.announce.gameSummary.inCheck".localized)
        }

        enqueue(parts.joined(separator: ". "))
    }
}
