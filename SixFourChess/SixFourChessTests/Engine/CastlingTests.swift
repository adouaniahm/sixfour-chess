import Testing
@testable import SixFour

@MainActor
@Suite struct CastlingTests {

    @Test func kingsideCastlingGenerated() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)
        let castling = findMove(from: pos("e1"), to: pos("g1"), in: moves)
        #expect(castling != nil)
        #expect(castling!.isCastling)
    }

    @Test func queensideCastlingGenerated() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)
        let castling = findMove(from: pos("e1"), to: pos("c1"), in: moves)
        #expect(castling != nil)
        #expect(castling!.isCastling)
    }

    @Test func kingsideCastlingExecution() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)
        let castling = findMove(from: pos("e1"), to: pos("g1"), in: moves)!
        board.makeMove(castling)

        #expect(board.piece(at: pos("g1"))?.type == .king)
        #expect(board.piece(at: pos("f1"))?.type == .rook)
        #expect(board.piece(at: pos("e1")) == nil)
        #expect(board.piece(at: pos("h1")) == nil)
    }

    @Test func queensideCastlingExecution() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)
        let castling = findMove(from: pos("e1"), to: pos("c1"), in: moves)!
        board.makeMove(castling)

        #expect(board.piece(at: pos("c1"))?.type == .king)
        #expect(board.piece(at: pos("d1"))?.type == .rook)
        #expect(board.piece(at: pos("e1")) == nil)
        #expect(board.piece(at: pos("a1")) == nil)
    }

    @Test func castlingUndoRestoresKingAndRook() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSides)
        let moves = board.getAllLegalMoves(for: .white)
        let castling = findMove(from: pos("e1"), to: pos("g1"), in: moves)!
        board.makeMove(castling)
        board.undoLastMove()

        #expect(board.piece(at: pos("e1"))?.type == .king)
        #expect(board.piece(at: pos("h1"))?.type == .rook)
        #expect(board.piece(at: pos("g1")) == nil)
        #expect(board.piece(at: pos("f1")) == nil)
        #expect(!board.state.isWhiteKingMoved)
        #expect(!board.state.isWhiteRookRightMoved)
    }

    @Test func castlingBlockedByKingMoved() throws {
        let board = try ChessBoard(fen: TestFEN.castlingNone)
        let moves = board.getAllLegalMoves(for: .white)
        let castlingMoves = moves.filter { $0.isCastling }
        #expect(castlingMoves.isEmpty)
    }

    @Test func castlingBlockedByPieceInWay() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBlockedByPiece)
        let moves = board.getAllLegalMoves(for: .white)
        let kingsideCastling = findMove(from: pos("e1"), to: pos("g1"), in: moves)
        #expect(kingsideCastling == nil)
    }

    @Test func castlingBlockedThroughCheck() throws {
        let board = try ChessBoard(fen: TestFEN.castlingThroughCheck)
        let moves = board.getAllLegalMoves(for: .white)
        let kingsideCastling = findMove(from: pos("e1"), to: pos("g1"), in: moves)
        #expect(kingsideCastling == nil)
    }

    @Test func castlingBlockedWhileInCheck() throws {
        let board = try ChessBoard(fen: TestFEN.castlingWhileInCheck)
        #expect(board.isInCheck(color: .white))
        let moves = board.getAllLegalMoves(for: .white)
        let castlingMoves = moves.filter { $0.isCastling }
        #expect(castlingMoves.isEmpty)
    }

    @Test func blackKingsideCastling() throws {
        let board = try ChessBoard(fen: TestFEN.castlingBothSidesBlack)
        let moves = board.getAllLegalMoves(for: .black)
        let castling = findMove(from: pos("e8"), to: pos("g8"), in: moves)
        #expect(castling != nil)
        #expect(castling!.isCastling)
    }
}
