import Foundation

/// Represents a chess move with the full state before the move.
nonisolated struct Move: Codable, Equatable, Sendable, Hashable {
    let from: Position
    let to: Position
    let piece: Piece
    let capturedPiece: Piece?
    let isEnPassant: Bool
    let isCastling: Bool
    let promotionType: PieceType?
    let promotionUsedCapturedPiece: Bool // Indicates whether promotion consumed a captured piece.
    let timestamp: TimeInterval
    let positionHash: String // Hash de la position APRES le coup

    // Saved states for undo.
    let previousEnPassantTarget: Position?
    let previousHalfMoveClock: Int
    let previousWhiteKingMoved: Bool
    let previousBlackKingMoved: Bool
    let previousWhiteRookLeftMoved: Bool
    let previousWhiteRookRightMoved: Bool
    let previousBlackRookLeftMoved: Bool
    let previousBlackRookRightMoved: Bool

    nonisolated init(
        from: Position,
        to: Position,
        piece: Piece,
        capturedPiece: Piece? = nil,
        isEnPassant: Bool = false,
        isCastling: Bool = false,
        promotionType: PieceType? = nil,
        promotionUsedCapturedPiece: Bool = false,
        positionHash: String = "",
        previousEnPassantTarget: Position? = nil,
        previousHalfMoveClock: Int = 0,
        previousWhiteKingMoved: Bool = false,
        previousBlackKingMoved: Bool = false,
        previousWhiteRookLeftMoved: Bool = false,
        previousWhiteRookRightMoved: Bool = false,
        previousBlackRookLeftMoved: Bool = false,
        previousBlackRookRightMoved: Bool = false
    ) {
        self.from = from
        self.to = to
        self.piece = piece
        self.capturedPiece = capturedPiece
        self.isEnPassant = isEnPassant
        self.isCastling = isCastling
        self.promotionType = promotionType
        self.promotionUsedCapturedPiece = promotionUsedCapturedPiece
        self.timestamp = Date().timeIntervalSince1970
        self.positionHash = positionHash
        self.previousEnPassantTarget = previousEnPassantTarget
        self.previousHalfMoveClock = previousHalfMoveClock
        self.previousWhiteKingMoved = previousWhiteKingMoved
        self.previousBlackKingMoved = previousBlackKingMoved
        self.previousWhiteRookLeftMoved = previousWhiteRookLeftMoved
        self.previousWhiteRookRightMoved = previousWhiteRookRightMoved
        self.previousBlackRookLeftMoved = previousBlackRookLeftMoved
        self.previousBlackRookRightMoved = previousBlackRookRightMoved
    }

    // Computed identifier for SwiftUI.
    nonisolated var id: String {
        "\(from.row)\(from.col)-\(to.row)\(to.col)-\(timestamp)"
    }

    nonisolated var notation: String {
        var result = ""

        if piece.type != .pawn {
            result += piece.type.rawValue
        }

        result += from.notation

        if capturedPiece != nil {
            result += "x"
        } else {
            result += "-"
        }

        result += to.notation

        if let promotion = promotionType {
            result += "=\(promotion.rawValue)"
        }

        if isCastling {
            result = to.col > from.col ? "O-O" : "O-O-O"
        }

        return result
    }
}
