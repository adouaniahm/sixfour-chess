import Testing
@testable import SixFour

@MainActor
@Suite struct FENTests {

    @Test func startingPositionFENRoundTrip() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        #expect(board.toFEN() == TestFEN.starting)
    }

    @Test func enPassantFENRoundTrip() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        #expect(board.toFEN() == TestFEN.enPassantWhiteReady)
    }

    @Test func castlingRightsFENRoundTrip() throws {
        let fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Kq - 0 1"
        let board = try ChessBoard(fen: fen)
        let result = board.toFEN()
        let castling = result.split(separator: " ")[2]
        #expect(String(castling) == "Kq")
    }

    @Test func noCastlingRightsFEN() throws {
        let fen = "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w - - 0 1"
        let board = try ChessBoard(fen: fen)
        let result = board.toFEN()
        let castling = result.split(separator: " ")[2]
        #expect(String(castling) == "-")
    }

    @Test func fenWithBlackToMove() throws {
        let fen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
        let board = try ChessBoard(fen: fen)
        #expect(board.currentPlayer == .black)
        let result = board.toFEN()
        let turn = result.split(separator: " ")[1]
        #expect(String(turn) == "b")
    }

    @Test func fenMoveCounters() throws {
        let fen = "4k3/8/8/8/8/8/8/4K3 w - - 42 87"
        let board = try ChessBoard(fen: fen)
        #expect(board.halfMoveClock == 42)
        #expect(board.fullMoveNumber == 87)
        let result = board.toFEN()
        let parts = result.split(separator: " ")
        #expect(String(parts[4]) == "42")
        #expect(String(parts[5]) == "87")
    }

    @Test func invalidFENThrows() {
        #expect(throws: (any Error).self) { try ChessBoard(fen: "invalid") }
        #expect(throws: (any Error).self) { try ChessBoard(fen: "8/8/8/8/8/8/8/8 x KQkq - 0 1") }
    }

    @Test func fenBoardPiecePlacement() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        #expect(board.piece(at: pos("a8"))?.type == .rook)
        #expect(board.piece(at: pos("a8"))?.color == .black)
        #expect(board.piece(at: pos("e8"))?.type == .king)
        #expect(board.piece(at: pos("e8"))?.color == .black)
        #expect(board.piece(at: pos("e1"))?.type == .king)
        #expect(board.piece(at: pos("e1"))?.color == .white)
        #expect(board.piece(at: pos("d2"))?.type == .pawn)
        #expect(board.piece(at: pos("d2"))?.color == .white)
        #expect(board.piece(at: pos("e4")) == nil)
    }

    @Test func fenLoadClearsHistory() throws {
        let board = ChessBoard()
        let pawn = board.piece(at: pos("e2"))!
        let move = Move(from: pos("e2"), to: pos("e4"), piece: pawn)
        board.makeMove(move)
        #expect(!board.moveHistory.isEmpty)

        try board.loadFEN(TestFEN.starting)
        #expect(board.moveHistory.isEmpty)
    }

    @Test func fenCastlingFlagsApplied() throws {
        let board1 = try ChessBoard(fen: "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
        #expect(!board1.state.isWhiteKingMoved)
        #expect(!board1.state.isWhiteRookLeftMoved)
        #expect(!board1.state.isWhiteRookRightMoved)

        let board2 = try ChessBoard(fen: "r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Kkq - 0 1")
        #expect(!board2.state.isWhiteKingMoved)
        #expect(board2.state.isWhiteRookLeftMoved)
        #expect(!board2.state.isWhiteRookRightMoved)
    }
}
