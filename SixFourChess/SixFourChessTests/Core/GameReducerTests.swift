import Foundation
import Testing
@testable import SixFour

@MainActor
@Suite struct GameReducerTests {

    private func makeState() -> GameState {
        let aiConfig = AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: .medium)
        return GameState(
            board: ChessBoard(),
            mode: .ai(aiConfig),
            isActive: true,
            gameResult: nil,
            isThinking: false,
            isCalculatingHint: false,
            selectedPosition: nil,
            availableMoves: [],
            suggestedMove: nil,
            startedAt: Date(),
            isArchivedInHistory: false,
            hintsRemaining: 3
        )
    }

    @Test func makeMove() {
        var state = makeState()
        let move = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))

        gameActionReducer(&state, AppAction.game(.makeMove(move: move)))

        #expect(state.board.moveHistory.count == 1)
        #expect(state.board.piece(at: Position(row: 4, col: 4))?.type == .pawn)
        #expect(state.selectedPosition == nil)
        #expect(state.availableMoves.isEmpty)
    }

    @Test func resetGame() {
        var state = makeState()
        let move = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))

        gameActionReducer(&state, AppAction.game(.makeMove(move: move)))
        gameActionReducer(&state, AppAction.game(.resetGame))

        #expect(state.board.moveHistory.count == 0)
        #expect(state.board.piece(at: Position(row: 6, col: 4)) != nil)
    }

    @Test func newGame() {
        var state = makeState()
        let move = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))
        gameActionReducer(&state, AppAction.game(.makeMove(move: move)))

        gameActionReducer(&state, AppAction.game(.newGame(mode: .playerVsAI, difficulty: .easy)))

        #expect(state.board.moveHistory.count == 0)
        if case .ai(let config) = state.mode {
            #expect(!config.whiteEnabled)
            #expect(config.blackEnabled)
            #expect(config.difficulty == .easy)
        } else {
            Issue.record("Mode should be AI")
        }
    }

    @Test func restoreSnapshot() {
        var state = makeState()
        let board = ChessBoard()
        board.makeMove(Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white)))

        let snapshot = GameStateSnapshot(
            board: board.snapshot,
            mode: .ai(AIConfig(whiteEnabled: false, blackEnabled: false, difficulty: .medium)),
            isActive: true,
            gameResult: nil,
            suggestedMove: nil,
            startedAt: Date(),
            isArchivedInHistory: false,
            hintsRemaining: 3,
            savedAt: Date(),
            gameMode: nil,
            difficulty: nil,
            whiteAIEnabled: nil,
            blackAIEnabled: nil
        )

        gameActionReducer(&state, AppAction.game(.restoreSnapshot(snapshot: snapshot)))

        #expect(state.board.moveHistory.count == 1)
        if case .ai(let config) = state.mode {
            #expect(!config.whiteEnabled)
            #expect(!config.blackEnabled)
        }
    }

    @Test func setHintStoresMove() {
        var state = makeState()
        let hintMove = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))

        gameActionReducer(&state, AppAction.game(.setHint(move: hintMove)))

        #expect(state.suggestedMove != nil)
    }

    @Test func clearHintRemovesMove() {
        var state = makeState()
        state.suggestedMove = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))

        gameActionReducer(&state, AppAction.game(.clearHint))

        #expect(state.suggestedMove == nil)
    }

    @Test func setCalculatingHint() {
        var state = makeState()

        gameActionReducer(&state, AppAction.game(.setCalculatingHint(isCalculating: true)))

        #expect(state.isCalculatingHint == true)
    }

    @Test func newGameBlockedWhileThinking() {
        var state = makeState()
        let move = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))
        gameActionReducer(&state, AppAction.game(.makeMove(move: move)))
        state.isThinking = true

        gameActionReducer(&state, AppAction.game(.newGame(mode: .playerVsAI, difficulty: .easy)))

        #expect(state.board.moveHistory.count == 1)
    }

    @Test func resetGameBlockedWhileThinking() {
        var state = makeState()
        let move = Move(from: Position(row: 6, col: 4), to: Position(row: 4, col: 4), piece: Piece(type: .pawn, color: .white))
        gameActionReducer(&state, AppAction.game(.makeMove(move: move)))
        state.isThinking = true

        gameActionReducer(&state, AppAction.game(.resetGame))

        #expect(state.board.moveHistory.count == 1)
    }
}
