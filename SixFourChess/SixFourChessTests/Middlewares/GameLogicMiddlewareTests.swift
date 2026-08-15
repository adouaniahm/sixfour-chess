import Testing
import Foundation
@testable import SixFour

@MainActor
@Suite(.serialized) struct GameLogicMiddlewareTests {

    private func makeMiddleware() -> (middleware: GameLogicReduxMiddleware, mockStore: MockStore) {
        let mockStore = MockStore()
        let dispatchContext = SynchronousDispatchContext(dispatcher: mockStore)
        let middleware = GameLogicReduxMiddleware(dispatchContext: dispatchContext)
        return (middleware, mockStore)
    }

    /// Crée un AppState avec un board initialisé depuis un FEN
    private func makeState(fen: String = TestFEN.starting) throws -> AppState {
        var state = AppState.initial
        state.gameState.board = try ChessBoard(fen: fen)
        return state
    }

    // MARK: - selectSquare: Promotion Deduplication

    @Test func selectSquareDeduplicatesPromotionMoves() throws {
        let (middleware, mockStore) = makeMiddleware()
        // White pawn on e7 can promote to e8 (4 piece types) — only 1 dot should appear
        let state = try makeState(fen: TestFEN.promotionWhiteReady)

        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: pos("e7"))), state: state)

        let setMoves = mockStore.actions.compactMap { action -> [Move]? in
            if case .game(.setAvailableMoves(let moves)) = (action as? AppAction) { return moves }
            return nil
        }.first

        #expect(setMoves != nil, "Should dispatch setAvailableMoves")
        #expect(setMoves?.count == 1, "Should deduplicate 4 promotion moves to 1 destination (e8)")
    }

    @Test func selectSquareDeduplicatesPromotionWithCapture() throws {
        let (middleware, mockStore) = makeMiddleware()
        // Custom FEN: white pawn on e7, black rook on d8, e8 is EMPTY
        // So pawn can advance to e8 (4 promotion types) AND capture on d8 (4 promotion types)
        // Deduped = 2 destinations
        let fen = "3r4/4P3/8/8/8/8/8/2K1k3 w - - 0 1"
        let state = try makeState(fen: fen)

        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: pos("e7"))), state: state)

        let moves = mockStore.actions.compactMap { action -> [Move]? in
            if case .game(.setAvailableMoves(let m)) = (action as? AppAction) { return m }
            return nil
        }.first

        #expect(moves != nil)
        // 2 destinations: e8 (advance) and d8 (capture) — each deduped from 4 to 1
        #expect(moves?.count == 2, "Should show 2 destinations: e8 and d8 capture")
    }

    @Test func selectSquareNormalPieceShowsAllMoves() throws {
        let (middleware, mockStore) = makeMiddleware()
        let state = try makeState(fen: TestFEN.starting)

        // Select knight at b1 (row 7, col 1) — should have 2 moves (a3, c3)
        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: Position(row: 7, col: 1))), state: state)

        let moves = mockStore.actions.compactMap { action -> [Move]? in
            if case .game(.setAvailableMoves(let m)) = (action as? AppAction) { return m }
            return nil
        }.first

        #expect(moves != nil)
        #expect(moves?.count == 2, "Knight at b1 should have 2 legal moves")
    }

    @Test func selectSquareEmptySquareDoesNotDispatch() throws {
        let (middleware, mockStore) = makeMiddleware()
        let state = try makeState(fen: TestFEN.starting)

        // Select empty square e4
        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: pos("e4"))), state: state)

        #expect(mockStore.actions.isEmpty, "Selecting empty square should not dispatch")
    }

    @Test func selectSquareOpponentPieceDoesNotDispatch() throws {
        let (middleware, mockStore) = makeMiddleware()
        let state = try makeState(fen: TestFEN.starting)

        // It's white's turn — select black pawn at e7
        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: pos("e7"))), state: state)

        #expect(mockStore.actions.isEmpty, "Selecting opponent piece should not dispatch")
    }

    // MARK: - makeMove: No Re-trigger

    @Test func makeMoveDoesNotRetriggerPromotion() throws {
        let (middleware, mockStore) = makeMiddleware()
        let state = try makeState(fen: TestFEN.promotionWhiteReady)
        let move = Move(from: pos("e7"), to: pos("e8"), piece: Piece(type: .pawn, color: .white), promotionType: .queen)

        _ = middleware.invoke(action: AppAction.game(.makeMove(move: move)), state: state)

        // A move comment may be emitted, but a promotion must never re-trigger itself.
        let retriggeredPromotion = mockStore.actions.contains { action in
            guard let appAction = action as? AppAction else { return false }
            switch appAction {
            case .game(.makeMove(_)), .game(.promotePawn(_)), .ui(.setPromotionAlert(_)):
                return true
            default:
                return false
            }
        }
        #expect(!retriggeredPromotion, "makeMove should not re-trigger a promotion")
    }

    // MARK: - promotePawn

    @Test func promotePawnToQueenDispatchesMoveAndClearsAlert() throws {
        let (middleware, mockStore) = makeMiddleware()
        var state = try makeState(fen: TestFEN.promotionWhiteReady)

        // Set up promotion moves in UI state (simulating the picker being shown)
        let promotionMoves = [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(from: pos("e7"), to: pos("e8"), piece: Piece(type: .pawn, color: .white), promotionType: type)
        }
        state.uiState.promotionMoves = promotionMoves

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .queen)), state: state)

        let actions = mockStore.actions.compactMap { $0 as? AppAction }

        // Should clear promotion alert
        let clearAlert = actions.contains {
            if case .ui(.setPromotionAlert(let moves)) = $0 { return moves.isEmpty }
            return false
        }
        #expect(clearAlert, "Should clear promotion alert")

        // Should dispatch makeMove with queen promotion
        let makeMove = actions.contains {
            if case .game(.makeMove(let move)) = $0 { return move.promotionType == .queen }
            return false
        }
        #expect(makeMove, "Should dispatch makeMove with queen promotion")
    }

    @Test func promotePawnToKnight() throws {
        let (middleware, mockStore) = makeMiddleware()
        var state = try makeState(fen: TestFEN.promotionWhiteReady)

        let promotionMoves = [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(from: pos("e7"), to: pos("e8"), piece: Piece(type: .pawn, color: .white), promotionType: type)
        }
        state.uiState.promotionMoves = promotionMoves

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .knight)), state: state)

        let makeMove = mockStore.actions.compactMap { $0 as? AppAction }.contains {
            if case .game(.makeMove(let move)) = $0 { return move.promotionType == .knight }
            return false
        }
        #expect(makeMove, "Should dispatch makeMove with knight promotion")
    }

    @Test func promotePawnToRook() throws {
        let (middleware, mockStore) = makeMiddleware()
        var state = try makeState(fen: TestFEN.promotionWhiteReady)

        let promotionMoves = [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(from: pos("e7"), to: pos("e8"), piece: Piece(type: .pawn, color: .white), promotionType: type)
        }
        state.uiState.promotionMoves = promotionMoves

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .rook)), state: state)

        let makeMove = mockStore.actions.compactMap { $0 as? AppAction }.contains {
            if case .game(.makeMove(let move)) = $0 { return move.promotionType == .rook }
            return false
        }
        #expect(makeMove, "Should dispatch makeMove with rook promotion")
    }

    @Test func promotePawnToBishop() throws {
        let (middleware, mockStore) = makeMiddleware()
        var state = try makeState(fen: TestFEN.promotionWhiteReady)

        let promotionMoves = [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(from: pos("e7"), to: pos("e8"), piece: Piece(type: .pawn, color: .white), promotionType: type)
        }
        state.uiState.promotionMoves = promotionMoves

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .bishop)), state: state)

        let makeMove = mockStore.actions.compactMap { $0 as? AppAction }.contains {
            if case .game(.makeMove(let move)) = $0 { return move.promotionType == .bishop }
            return false
        }
        #expect(makeMove, "Should dispatch makeMove with bishop promotion")
    }

    @Test func promotePawnWithEmptyMovesDoesNothing() throws {
        let (middleware, mockStore) = makeMiddleware()
        let state = try makeState(fen: TestFEN.promotionWhiteReady)
        // promotionMoves is empty (default)

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .queen)), state: state)

        #expect(mockStore.actions.isEmpty, "Should not dispatch when no promotion moves available")
    }

    @Test func promotePawnWithCapturePromotion() throws {
        let (middleware, mockStore) = makeMiddleware()
        var state = try makeState(fen: TestFEN.promotionWithCapture)

        // Capture-promotion: e7xd8=Q
        let capturedPiece = Piece(type: .rook, color: .black)
        let promotionMoves = [PieceType.queen, .rook, .bishop, .knight].map { type in
            Move(from: pos("e7"), to: pos("d8"), piece: Piece(type: .pawn, color: .white),
                 capturedPiece: capturedPiece, promotionType: type)
        }
        state.uiState.promotionMoves = promotionMoves

        _ = middleware.invoke(action: AppAction.game(.promotePawn(to: .queen)), state: state)

        let actions = mockStore.actions.compactMap { $0 as? AppAction }
        let makeMove = actions.contains {
            if case .game(.makeMove(let move)) = $0 {
                return move.promotionType == .queen && move.to == pos("d8")
            }
            return false
        }
        #expect(makeMove, "Should dispatch makeMove with capture-promotion to d8")
    }

    // MARK: - Black promotion

    @Test func selectSquareBlackPromotionDeduplicates() throws {
        let (middleware, mockStore) = makeMiddleware()
        // Black pawn on e2 ready to promote
        let state = try makeState(fen: TestFEN.promotionBlackReady)

        _ = middleware.invoke(action: AppAction.game(.selectSquare(position: pos("e2"))), state: state)

        let moves = mockStore.actions.compactMap { action -> [Move]? in
            if case .game(.setAvailableMoves(let m)) = (action as? AppAction) { return m }
            return nil
        }.first

        #expect(moves != nil)
        // Only 1 destination (e1), deduped from 4 promotion types
        #expect(moves?.count == 1, "Black promotion should also deduplicate to 1 destination")
    }

    // MARK: - Non-game actions are ignored

    @Test func nonGameActionReturnsEmpty() {
        let (middleware, mockStore) = makeMiddleware()

        _ = middleware.invoke(action: AppAction.ui(.showGame), state: AppState.initial)

        #expect(mockStore.actions.isEmpty, "Non-game actions should be ignored")
    }
}
