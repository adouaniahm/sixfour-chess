import Testing
@testable import SixFour

@MainActor
@Suite struct StalemateTests {

    @Test func basicStalemate() throws {
        let board = try ChessBoard(fen: TestFEN.stalemate)
        #expect(board.isStalemate(for: .black))
        #expect(!board.isInCheck(color: .black))
        #expect(board.getAllLegalMoves(for: .black).isEmpty)
    }

    @Test func isNotStalemateWhenMovesAvailable() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        #expect(!board.isStalemate(for: .white))
        #expect(!board.isStalemate(for: .black))
    }

    @Test func isNotStalemateWhenInCheck() throws {
        let board = try ChessBoard(fen: "k7/1Q6/1K6/8/8/8/8/8 b - - 0 1")
        #expect(!board.isStalemate(for: .black))
        #expect(board.isCheckmate(for: .black))
    }

    @Test func stalemateKingTrappedByPawns() throws {
        let board = try ChessBoard(fen: TestFEN.stalematePawn)
        #expect(board.isStalemate(for: .black))
        #expect(!board.isInCheck(color: .black))
    }
}
