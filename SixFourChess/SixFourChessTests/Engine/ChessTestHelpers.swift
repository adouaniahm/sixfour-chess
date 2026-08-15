import Testing
@testable import SixFour

// MARK: - FEN Position Library

enum TestFEN {
    /// Standard starting position
    static let starting = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    // MARK: En Passant
    /// White pawn on e5, black just played d7-d5, en passant target d6
    static let enPassantWhiteReady = "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3"
    /// Black pawn on d4, white just played c2-c4, en passant target c3
    static let enPassantBlackReady = "rnbqkbnr/pppppppp/8/8/2Pp4/8/PP1PPPPP/RNBQKBNR b KQkq c3 0 3"

    // MARK: Castling
    /// Both sides can castle (cleared paths)
    static let castlingBothSides = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1"
    /// Black to move, both sides can castle
    static let castlingBothSidesBlack = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1"
    /// White has no castling rights (king moved)
    static let castlingNone = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w kq - 0 1"
    /// Kingside blocked by knight on f1
    static let castlingBlockedByPiece = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3KN1R w KQkq - 0 1"
    /// Kingside through check: black rook on f8, f-file open
    static let castlingThroughCheck = "r3kr2/ppppp1pp/8/8/8/8/PPPPP1PP/R3K2R w KQkq - 0 1"
    /// King in check from black queen on e3 (e2 pawn removed)
    static let castlingWhileInCheck = "r3k2r/pppppppp/8/8/8/4q3/PPPP1PPP/R3K2R w KQkq - 0 1"

    // MARK: Promotion
    /// White pawn on e7, ready to promote (kings out of the way)
    static let promotionWhiteReady = "2k5/4P3/8/8/8/8/8/4K3 w - - 0 1"
    /// Black pawn on e2, ready to promote (kings out of the way)
    static let promotionBlackReady = "4k3/8/8/8/8/8/4p3/2K5 b - - 0 1"
    /// White pawn on e7, black rook on d8 (capture-promotion)
    static let promotionWithCapture = "3rk3/4P3/8/8/8/8/8/2K5 w - - 0 1"

    // MARK: Checkmate & Stalemate
    /// Back rank: white rook a1 can deliver mate on a8
    static let backRankMate = "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1"
    /// Stalemate: black king a8, white queen b6, white king c5
    static let stalemate = "k7/8/1Q6/2K5/8/8/8/8 b - - 0 1"
    /// Stalemate by pawn: black king a8, white king b6, white pawn c7
    static let stalematePawn = "k7/2P5/1K6/8/8/8/8/8 b - - 0 1"
    /// Check can be blocked: black bishop a5 checks e1, white rook d1 can block d2
    static let checkCanBeBlocked = "4k3/8/8/b7/8/8/8/3RK3 w - - 0 1"

    // MARK: Fifty-Move Rule
    /// halfMoveClock = 99, one more non-pawn non-capture move triggers it
    static let fiftyMoveNearLimit = "4k3/8/8/8/8/8/8/R3K3 w - - 99 50"
    /// halfMoveClock = 98, white pawn on e2 can reset it
    static let fiftyMoveWithPawn = "4k3/8/8/8/8/8/4P3/4K3 w - - 98 50"
    /// halfMoveClock = 98, white rook can capture black knight on e2
    static let fiftyMoveWithCapture = "4k3/8/8/8/8/8/4n3/R3K3 w - - 98 50"
    /// halfMoveClock = 50, for undo test
    static let fiftyMoveForUndo = "4k3/8/8/8/8/8/8/R3K3 w - - 50 25"
}

// MARK: - Convenience Helpers

/// Create a Position from algebraic notation (e.g. "e4")
func pos(_ notation: String) -> Position {
    guard let p = Position(notation: notation) else {
        fatalError("Invalid position notation: \(notation)")
    }
    return p
}

/// Find a specific legal move from a source to a destination
func findMove(from: Position, to: Position, in moves: [Move]) -> Move? {
    moves.first { $0.from == from && $0.to == to }
}

/// Find a move with a specific promotion type
func findPromotionMove(from: Position, to: Position, promotion: PieceType, in moves: [Move]) -> Move? {
    moves.first { $0.from == from && $0.to == to && $0.promotionType == promotion }
}
