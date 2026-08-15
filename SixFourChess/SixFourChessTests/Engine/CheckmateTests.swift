import Testing
@testable import SixFour

@MainActor
@Suite struct CheckmateTests {

    @Test func scholarsMateViaHistory() throws {
        let board = try ChessBoard.fromMoveHistory([
            "e2e4", "e7e5", "Bf1c4", "Nb8c6", "Qd1h5", "Ng8f6", "Qh5xf7"
        ])
        #expect(board.isCheckmate(for: .black))
        #expect(board.isInCheck(color: .black))
        #expect(board.getAllLegalMoves(for: .black).isEmpty)
    }

    @Test func backRankMate() throws {
        let board = try ChessBoard(fen: TestFEN.backRankMate)
        let moves = board.getAllLegalMoves(for: .white)
        let mate = findMove(from: pos("a1"), to: pos("a8"), in: moves)
        #expect(mate != nil)
        board.makeMove(mate!)
        #expect(board.isCheckmate(for: .black))
    }

    @Test func isNotCheckmateWhenNotInCheck() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        #expect(!board.isCheckmate(for: .white))
        #expect(!board.isCheckmate(for: .black))
    }

    @Test func isNotCheckmateWhenCanBlock() throws {
        let board = try ChessBoard(fen: TestFEN.checkCanBeBlocked)
        #expect(board.isInCheck(color: .white))
        #expect(!board.isCheckmate(for: .white))
        let moves = board.getAllLegalMoves(for: .white)
        #expect(!moves.isEmpty)
    }

    @Test func foolsMateViaHistory() throws {
        let board = try ChessBoard.fromMoveHistory([
            "f2f3", "e7e5", "g2g4", "Qd8h4"
        ])
        #expect(board.isCheckmate(for: .white))
        #expect(board.isInCheck(color: .white))
        #expect(board.getAllLegalMoves(for: .white).isEmpty)
    }
}
