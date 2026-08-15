import Testing
@testable import SixFour

@MainActor
@Suite struct MoveNotationTests {

    // MARK: - LAN Generation Tests

    @Test func pawnMoveLAN() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let moves = board.getAllLegalMoves(for: .white)
        let e4 = findMove(from: pos("e2"), to: pos("e4"), in: moves)!
        let notation = AlgebraicNotationParser.toAlgebraic(move: e4, board: board)
        #expect(!notation.isEmpty, "Notation should not be empty")
        #expect(notation.hasSuffix("4"), "Pawn move to rank 4")
    }

    @Test func knightMoveLAN() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let moves = board.getAllLegalMoves(for: .white)
        let nf3 = findMove(from: pos("g1"), to: pos("f3"), in: moves)!
        let notation = AlgebraicNotationParser.toAlgebraic(move: nf3, board: board)
        #expect(notation == "Ng1f3", "Knight LAN should include full from-square: Ng1f3")
    }

    @Test func pawnCaptureNotation() throws {
        let board = try ChessBoard.fromMoveHistory(["e2e4", "d7d5"])
        let moves = board.getAllLegalMoves(for: .white)
        let exd5 = moves.first { $0.from == pos("e4") && $0.to == pos("d5") && $0.capturedPiece != nil }
        #expect(exd5 != nil, "exd5 capture should be available")

        let notation = AlgebraicNotationParser.toAlgebraic(move: exd5!, board: board)
        #expect(notation == "exd5", "Pawn capture should be 'exd5'")
    }

    @Test func castlingNotation() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)

        let kingSide = moves.first { $0.isCastling && $0.to.col == 6 }
        #expect(kingSide != nil)
        let ksNotation = AlgebraicNotationParser.toAlgebraic(move: kingSide!, board: board)
        #expect(ksNotation == "O-O")

        let queenSide = moves.first { $0.isCastling && $0.to.col == 2 }
        #expect(queenSide != nil)
        let qsNotation = AlgebraicNotationParser.toAlgebraic(move: queenSide!, board: board)
        #expect(qsNotation == "O-O-O")
    }

    @Test func promotionNotation() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let queenPromo = findPromotionMove(from: pos("e7"), to: pos("e8"), promotion: .queen, in: moves)!
        let notation = AlgebraicNotationParser.toAlgebraic(move: queenPromo, board: board)
        #expect(notation.contains("=Q"), "Promotion notation should contain '=Q', got: \(notation)")
    }

    // MARK: - Parsing Tests

    @Test func parseSANPawnMove() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let move = AlgebraicNotationParser.parseMove("e4", on: board)
        #expect(move != nil)
        #expect(move?.from == pos("e2"))
        #expect(move?.to == pos("e4"))
        #expect(move?.piece.type == .pawn)
    }

    @Test func parseSANKnightMove() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let move = AlgebraicNotationParser.parseMove("Nf3", on: board)
        #expect(move != nil)
        #expect(move?.from == pos("g1"))
        #expect(move?.to == pos("f3"))
        #expect(move?.piece.type == .knight)
    }

    @Test func parseLANKnightMove() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let move = AlgebraicNotationParser.parseMove("Ng1f3", on: board)
        #expect(move != nil)
        #expect(move?.from == pos("g1"))
        #expect(move?.to == pos("f3"))
    }

    @Test func parseCastling() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let kingside = AlgebraicNotationParser.parseMove("O-O", on: board)
        #expect(kingside != nil)
        #expect(kingside?.isCastling == true)
        #expect(kingside?.to.col == 6)

        let queenside = AlgebraicNotationParser.parseMove("O-O-O", on: board)
        #expect(queenside != nil)
        #expect(queenside?.isCastling == true)
        #expect(queenside?.to.col == 2)
    }

    @Test func parseWithCheckSymbols() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let move1 = AlgebraicNotationParser.parseMove("e4+", on: board)
        #expect(move1 != nil, "Should parse move with '+' symbol")

        let move2 = AlgebraicNotationParser.parseMove("Nf3#", on: board)
        #expect(move2 != nil, "Should parse move with '#' symbol")
    }

    @Test func fullGameNotationRoundTrip() throws {
        let moveStrings = ["e2e4", "e7e5", "Ng1f3", "Nb8c6", "Bf1c4", "Ng8f6"]
        let board1 = try ChessBoard.fromMoveHistory(moveStrings)
        let fen1 = board1.toFEN()

        let board2 = ChessBoard()
        let parsedMoves = AlgebraicNotationParser.parseMoves(board1.moveHistory, on: board2)
        for move in parsedMoves {
            board2.makeMove(move)
        }
        let fen2 = board2.toFEN()

        #expect(fen1 == fen2, "FEN should match after notation round-trip")
    }
}
