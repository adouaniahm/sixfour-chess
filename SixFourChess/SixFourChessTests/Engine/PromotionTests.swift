import Testing
@testable import SixFour

@MainActor
@Suite struct PromotionTests {

    @Test func fourPromotionMovesGenerated() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let promoMoves = moves.filter { $0.from == pos("e7") && $0.promotionType != nil }
        #expect(promoMoves.count == 4, "Should generate 4 promotion moves (Q, R, B, N)")

        let types = Set(promoMoves.compactMap { $0.promotionType })
        #expect(types.contains(.queen))
        #expect(types.contains(.rook))
        #expect(types.contains(.bishop))
        #expect(types.contains(.knight))
    }

    @Test func promotionToQueen() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let queenPromo = findPromotionMove(from: pos("e7"), to: pos("e8"), promotion: .queen, in: moves)!
        board.makeMove(queenPromo)

        #expect(board.piece(at: pos("e8"))?.type == .queen)
        #expect(board.piece(at: pos("e8"))?.color == .white)
        #expect(board.piece(at: pos("e7")) == nil)
    }

    @Test func promotionToKnight() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let knightPromo = findPromotionMove(from: pos("e7"), to: pos("e8"), promotion: .knight, in: moves)!
        board.makeMove(knightPromo)

        #expect(board.piece(at: pos("e8"))?.type == .knight)
        #expect(board.piece(at: pos("e8"))?.color == .white)
    }

    @Test func promotionWithCapture() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWithCapture)
        let moves = board.getAllLegalMoves(for: .white)
        let capturePromo = findPromotionMove(from: pos("e7"), to: pos("d8"), promotion: .queen, in: moves)
        #expect(capturePromo != nil, "Capture-promotion exd8=Q should be generated")

        board.makeMove(capturePromo!)
        #expect(board.piece(at: pos("d8"))?.type == .queen)
        #expect(board.piece(at: pos("d8"))?.color == .white)
        #expect(board.capturedPieces.contains { $0.type == .rook && $0.color == .black })
    }

    @Test func promotionUndoRestoresPawn() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let queenPromo = findPromotionMove(from: pos("e7"), to: pos("e8"), promotion: .queen, in: moves)!
        board.makeMove(queenPromo)
        board.undoLastMove()

        #expect(board.piece(at: pos("e7"))?.type == .pawn)
        #expect(board.piece(at: pos("e7"))?.color == .white)
        #expect(board.piece(at: pos("e8")) == nil)
        #expect(board.currentPlayer == .white)
    }

    @Test func blackPromotion() throws {
        let board = try ChessBoard(fen: TestFEN.promotionBlackReady)
        let moves = board.getAllLegalMoves(for: .black)
        let promoMoves = moves.filter { $0.from == pos("e2") && $0.promotionType != nil }
        #expect(promoMoves.count == 4, "Black should have 4 promotion moves")

        let queenPromo = findPromotionMove(from: pos("e2"), to: pos("e1"), promotion: .queen, in: moves)!
        board.makeMove(queenPromo)
        #expect(board.piece(at: pos("e1"))?.type == .queen)
        #expect(board.piece(at: pos("e1"))?.color == .black)
    }

    @Test func promotionNotationRoundTrip() throws {
        let board = try ChessBoard(fen: TestFEN.promotionWhiteReady)
        let moves = board.getAllLegalMoves(for: .white)
        let queenPromo = findPromotionMove(from: pos("e7"), to: pos("e8"), promotion: .queen, in: moves)!

        let notation = AlgebraicNotationParser.toAlgebraic(move: queenPromo, board: board)
        #expect(notation.contains("=Q"), "Notation should contain '=Q', got: \(notation)")

        let parsed = AlgebraicNotationParser.parseMove(notation, on: board)
        #expect(parsed != nil)
        #expect(parsed?.from == queenPromo.from)
        #expect(parsed?.to == queenPromo.to)
        #expect(parsed?.promotionType == .queen)
    }
}
