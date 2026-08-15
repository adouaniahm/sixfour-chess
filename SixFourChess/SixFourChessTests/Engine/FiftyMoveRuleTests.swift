import Testing
@testable import SixFour

@MainActor
@Suite struct FiftyMoveRuleTests {

    @Test func fiftyMoveRuleNotTriggeredAtStart() throws {
        let board = try ChessBoard(fen: TestFEN.starting)
        #expect(!board.state.isFiftyMoveRule())
        #expect(board.state.halfMoveClock == 0)
    }

    @Test func fiftyMoveRuleTriggeredAtLimit() throws {
        let board = try ChessBoard(fen: TestFEN.fiftyMoveNearLimit)
        #expect(!board.state.isFiftyMoveRule())

        let moves = board.getAllLegalMoves(for: .white)
        let rookMove = findMove(from: pos("a1"), to: pos("a2"), in: moves)!
        board.makeMove(rookMove)

        #expect(board.state.isFiftyMoveRule(), "halfMoveClock should be 100 after rook move from 99")
    }

    @Test func fiftyMoveClockResetByPawnMove() throws {
        let board = try ChessBoard(fen: TestFEN.fiftyMoveWithPawn)
        #expect(board.state.halfMoveClock == 98)

        let moves = board.getAllLegalMoves(for: .white)
        let pawnMove = findMove(from: pos("e2"), to: pos("e4"), in: moves)!
        board.makeMove(pawnMove)

        #expect(board.state.halfMoveClock == 0, "Pawn move should reset halfMoveClock to 0")
    }

    @Test func fiftyMoveClockResetByCapture() throws {
        let board = try ChessBoard(fen: TestFEN.fiftyMoveWithCapture)
        #expect(board.state.halfMoveClock == 98)

        let moves = board.getAllLegalMoves(for: .white)
        let allCaptures = moves.filter { $0.capturedPiece != nil }
        #expect(!allCaptures.isEmpty, "Should have at least one capture move")

        if let capture = allCaptures.first {
            board.makeMove(capture)
            #expect(board.state.halfMoveClock == 0, "Capture should reset halfMoveClock to 0")
        }
    }

    @Test func fiftyMoveClockIncrementedByNonPawnNonCapture() throws {
        let board = try ChessBoard(fen: TestFEN.fiftyMoveForUndo)
        #expect(board.state.halfMoveClock == 50)

        let moves = board.getAllLegalMoves(for: .white)
        let rookMove = findMove(from: pos("a1"), to: pos("a2"), in: moves)!
        board.makeMove(rookMove)

        #expect(board.state.halfMoveClock == 51, "Non-pawn, non-capture move should increment clock")
    }

    @Test func fiftyMoveClockRestoredByUndo() throws {
        let board = try ChessBoard(fen: TestFEN.fiftyMoveForUndo)
        #expect(board.state.halfMoveClock == 50)

        let moves = board.getAllLegalMoves(for: .white)
        let rookMove = findMove(from: pos("a1"), to: pos("a2"), in: moves)!
        board.makeMove(rookMove)
        #expect(board.state.halfMoveClock == 51)

        board.undoLastMove()
        #expect(board.state.halfMoveClock == 50, "Undo should restore halfMoveClock to previous value")
    }
}
