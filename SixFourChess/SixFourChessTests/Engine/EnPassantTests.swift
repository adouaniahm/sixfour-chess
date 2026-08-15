import Testing
@testable import SixFour

@MainActor
@Suite struct EnPassantTests {

    @Test func enPassantMoveIsGenerated() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let epMove = moves.first { $0.from == pos("e5") && $0.to == pos("d6") && $0.isEnPassant }
        #expect(epMove != nil, "En passant move e5xd6 should be generated")
    }

    @Test func enPassantCaptureRemovesPawn() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let epMove = moves.first { $0.isEnPassant }!
        board.makeMove(epMove)

        #expect(board.piece(at: pos("d6"))?.type == .pawn)
        #expect(board.piece(at: pos("d6"))?.color == .white)
        #expect(board.piece(at: pos("d5")) == nil)
        #expect(board.piece(at: pos("e5")) == nil)
        #expect(board.capturedPieces.contains { $0.type == .pawn && $0.color == .black })
    }

    @Test func enPassantUndoRestoresPawn() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let epMove = moves.first { $0.isEnPassant }!
        board.makeMove(epMove)
        board.undoLastMove()

        #expect(board.piece(at: pos("e5"))?.type == .pawn)
        #expect(board.piece(at: pos("e5"))?.color == .white)
        #expect(board.piece(at: pos("d5"))?.type == .pawn)
        #expect(board.piece(at: pos("d5"))?.color == .black)
        #expect(board.piece(at: pos("d6")) == nil)
        #expect(board.enPassantTarget == pos("d6"))
    }

    @Test func enPassantTargetSetAfterDoublePawnPush() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let moves = board.getAllLegalMoves(for: .white)
        let pawnPush = findMove(from: pos("e2"), to: pos("e4"), in: moves)!
        board.makeMove(pawnPush)

        #expect(board.enPassantTarget == pos("e3"))
    }

    @Test func enPassantTargetClearedAfterNonDoublePush() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        let moves1 = board.getAllLegalMoves(for: .white)
        let pawnPush = findMove(from: pos("e2"), to: pos("e4"), in: moves1)!
        board.makeMove(pawnPush)
        #expect(board.enPassantTarget != nil)

        let moves2 = board.getAllLegalMoves(for: .black)
        let singlePush = findMove(from: pos("d7"), to: pos("d6"), in: moves2)!
        board.makeMove(singlePush)
        #expect(board.enPassantTarget == nil)
    }

    @Test func enPassantFENRoundTrip() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantWhiteReady)
        let fen = board.toFEN()
        let parts = fen.split(separator: " ")
        #expect(String(parts[3]) == "d6")
    }

    @Test func enPassantBlackCapture() throws {
        let board = try ChessBoard(fen: TestFEN.enPassantBlackReady)
        let moves = board.getAllLegalMoves(for: .black)
        let epMove = moves.first { $0.from == pos("d4") && $0.to == pos("c3") && $0.isEnPassant }
        #expect(epMove != nil, "Black en passant d4xc3 should be generated")
    }

    @Test func enPassantNotAvailableNextTurn() throws {
        let board = try ChessBoard.fromMoveHistory(["e2e4", "d7d5", "Nb1c3", "Ng8f6"])
        #expect(board.enPassantTarget == nil)
        let moves = board.getAllLegalMoves(for: .white)
        let epMoves = moves.filter { $0.isEnPassant }
        #expect(epMoves.isEmpty)
    }

    @Test func enPassantNotationRoundTrip() throws {
        let board = try ChessBoard.fromMoveHistory(["e2e4", "a7a6", "e4e5", "d7d5"])
        #expect(board.enPassantTarget == pos("d6"))

        let moves = board.getAllLegalMoves(for: .white)
        let epMove = moves.first { $0.isEnPassant }
        #expect(epMove != nil)

        let notation = AlgebraicNotationParser.toAlgebraic(move: epMove!, board: board)
        #expect(notation == "exd6")

        let parsed = AlgebraicNotationParser.parseMove("exd6", on: board)
        #expect(parsed != nil)
        #expect(parsed?.from == epMove?.from)
        #expect(parsed?.to == epMove?.to)
        #expect(parsed?.isEnPassant == true)
    }
}
