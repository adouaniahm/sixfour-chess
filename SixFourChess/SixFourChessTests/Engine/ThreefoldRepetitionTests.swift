import Testing
@testable import SixFour

@MainActor
@Suite struct ThreefoldRepetitionTests {

    @Test func threefoldRepetitionBasic() throws {
        let board = try ChessBoard.fromMoveHistory([
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8",
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8"
        ])
        #expect(board.state.isThreefoldRepetition(), "Should detect threefold repetition")
    }

    @Test func noRepetitionAfterTwoOccurrences() throws {
        let board = try ChessBoard.fromMoveHistory([
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8"
        ])
        #expect(!board.state.isThreefoldRepetition(), "Two occurrences should NOT trigger threefold")
    }

    @Test func initialPositionCounted() throws {
        let board = try ChessBoard.fromMoveHistory([
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8",
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8"
        ])
        #expect(board.state.isThreefoldRepetition())
        #expect(!board.state.initialPositionHash.isEmpty, "initialPositionHash should be set")
    }

    @Test func repetitionBrokenByCapture() throws {
        let board = try ChessBoard.fromMoveHistory([
            "e2e4", "d7d5",
            "e4xd5"
        ])
        #expect(!board.state.isThreefoldRepetition())
    }

    @Test func repetitionBrokenByPawnMove() throws {
        let board = try ChessBoard.fromMoveHistory([
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8",
            "e2e4",
            "e7e5",
            "Ng1f3", "Ng8f6",
            "Nf3g1", "Nf6g8"
        ])
        #expect(!board.state.isThreefoldRepetition(),
               "Pawn move changes position irreversibly, no threefold")
    }

    @Test func hashDistinguishesEnPassantAvailability() throws {
        let boardWithEP = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        let hashWithEP = boardWithEP.state.getBoardHashForTest()

        let boardNoEP = try ChessBoard(fen: "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3")
        let hashNoEP = boardNoEP.state.getBoardHashForTest()

        #expect(hashWithEP != hashNoEP,
               "Hash should differ when en passant is available vs not")
    }

    @Test func hashDistinguishesCastlingRights() throws {
        let boardWithCastling = try ChessBoard(fen: TestFEN.castlingBothSides)
        let hashWithCastling = boardWithCastling.state.getBoardHashForTest()

        let boardNoCastling = try ChessBoard(fen: TestFEN.castlingNone)
        let hashNoCastling = boardNoCastling.state.getBoardHashForTest()

        #expect(hashWithCastling != hashNoCastling,
               "Hash should differ when castling rights differ")
    }
}
