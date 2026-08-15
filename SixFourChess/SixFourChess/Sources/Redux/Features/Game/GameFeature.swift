//
//  GameFeature.swift
//  SixFourChess
//

import Foundation

struct GameState {
    var board: ChessBoard
    var mode: GameModeState
    var isActive: Bool
    var gameResult: GameResult?
    var isThinking: Bool
    var isCalculatingHint: Bool
    var selectedPosition: Position?
    var availableMoves: [Move]
    var suggestedMove: Move?
    var startedAt: Date
    var isArchivedInHistory: Bool
    var hintsRemaining: Int

    static var initial: GameState {
        let savedSettings = UserSettingsStorage.shared.load()
        let legacyMode = (savedSettings?.gameMode ?? .playerVsAI).normalizedForCurrentRelease
        let difficulty = savedSettings?.difficulty ?? .medium

        return GameState(
            board: ChessBoard(),
            mode: GameModeState.from(legacyMode: legacyMode, difficulty: difficulty),
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

    var isCurrentPlayerAI: Bool {
        guard let aiConfig = mode.aiConfig else { return false }
        return aiConfig.isAIEnabled(for: board.currentPlayer)
    }

    var canCurrentPlayerMove: Bool {
        !isCurrentPlayerAI
    }

    var gameMode: GameMode { mode.legacyGameMode }
    var difficulty: AIDifficulty { mode.aiConfig?.difficulty ?? .medium }
    var whiteAIEnabled: Bool { mode.aiConfig?.whiteEnabled ?? false }
    var blackAIEnabled: Bool { mode.aiConfig?.blackEnabled ?? false }
}

enum GameAction: ReduxAction {
    case newGame(mode: GameMode, difficulty: AIDifficulty)
    case endGame(result: GameResult)
    case resetGame
    case restoreSnapshot(snapshot: GameStateSnapshot)
    case selectSquare(position: Position)
    case deselectSquare
    case makeMove(move: Move)
    case setAvailableMoves(moves: [Move])
    case clearAvailableMoves
    case setAIThinking(isThinking: Bool)
    case triggerAIMove
    case retryCloudAI
    case aiMoveCalculated(move: Move)
    case requestHint
    case setHint(move: Move)
    case clearHint
    case setCalculatingHint(isCalculating: Bool)
    case setArchivedInHistory(Bool)
    case setHintsRemaining(Int)
    case promotePawn(to: PieceType)
    case changeGameMode(mode: GameMode)
    case changeDifficulty(difficulty: AIDifficulty)
}

enum GameMutation: Mutation {
    case clearBoard
    case setBoard(ChessBoard)
    case setSelectedPosition(Position?)
    case setAvailableMoves([Move])
    case clearSelection
    case setGameResult(GameResult?)
    case setIsActive(Bool)
    case setMode(GameModeState)
    case setIsThinking(Bool)
    case setSuggestedMove(Move?)
    case clearHint
}

let gameActionReducer: ReduxReducer<GameState> = { state, action in
    guard let gameAction = (action as? AppAction)?.gameAction else { return }

    if state.isThinking {
        switch gameAction {
        case .newGame, .requestHint, .resetGame:
            return
        default:
            break
        }
    }

    switch gameAction {
    case .newGame(let legacyMode, let difficulty):
        state.board.state = ChessState()
        state.mode = GameModeState.from(legacyMode: legacyMode.normalizedForCurrentRelease, difficulty: difficulty)
        state.isActive = true
        state.gameResult = nil
        state.selectedPosition = nil
        state.availableMoves = []
        state.suggestedMove = nil
        state.isThinking = false
        state.startedAt = Date()
        state.isArchivedInHistory = false
        state.hintsRemaining = 3

    case .endGame(let result):
        state.gameResult = result
        state.isActive = false
        state.selectedPosition = nil
        state.availableMoves = []
        state.isThinking = false

    case .resetGame:
        state.board.state = ChessState()
        state.isActive = true
        state.gameResult = nil
        state.selectedPosition = nil
        state.availableMoves = []
        state.suggestedMove = nil
        state.isThinking = false
        state.startedAt = Date()
        state.isArchivedInHistory = false
        state.hintsRemaining = 3

    case .restoreSnapshot(let snapshot):
        state.applySnapshot(snapshot)

    case .selectSquare(let position):
        state.selectedPosition = position

    case .deselectSquare:
        state.selectedPosition = nil
        state.availableMoves = []

    case .makeMove(let move):
        state.board.makeMove(move)
        state.selectedPosition = nil
        state.availableMoves = []
        state.suggestedMove = nil

        if let result = state.board.checkGameEnd() {
            state.gameResult = result
            state.isActive = false
        }

    case .triggerAIMove, .retryCloudAI, .aiMoveCalculated, .promotePawn:
        break

    case .requestHint:
        break

    case .setAvailableMoves(let moves):
        state.availableMoves = moves

    case .clearAvailableMoves:
        state.availableMoves = []

    case .setAIThinking(let isThinking):
        state.isThinking = isThinking

    case .setHint(let move):
        state.hintsRemaining = max(state.hintsRemaining - 1, 0)
        state.suggestedMove = move

    case .clearHint:
        state.suggestedMove = nil

    case .setCalculatingHint(let isCalculating):
        state.isCalculatingHint = isCalculating

    case .setArchivedInHistory(let archived):
        state.isArchivedInHistory = archived

    case .setHintsRemaining(let remaining):
        state.hintsRemaining = max(remaining, 0)

    case .changeGameMode(let legacyMode):
        state.mode = GameModeState.from(
            legacyMode: legacyMode.normalizedForCurrentRelease,
            difficulty: state.difficulty
        )

    case .changeDifficulty(let difficulty):
        if case .ai(let config) = state.mode {
            state.mode = .ai(AIConfig(
                whiteEnabled: config.whiteEnabled,
                blackEnabled: config.blackEnabled,
                difficulty: difficulty
            ))
        }
    }
}

func gameMutationReducer() -> MutationReducer<GameState> {
    reducers(
        onMutation(GameMutation.self) { state, mutation in
            switch mutation {
            case .clearBoard:
                state.board.state = ChessState()
            case .setBoard(let board):
                state.board.state = board.state
            case .setSelectedPosition(let position):
                state.selectedPosition = position
            case .setAvailableMoves(let moves):
                state.availableMoves = moves
            case .clearSelection:
                state.selectedPosition = nil
                state.availableMoves = []
            case .setGameResult(let result):
                state.gameResult = result
            case .setIsActive(let active):
                state.isActive = active
            case .setMode(let mode):
                state.mode = mode
            case .setIsThinking(let thinking):
                state.isThinking = thinking
            case .setSuggestedMove(let move):
                state.suggestedMove = move
            case .clearHint:
                state.suggestedMove = nil
            }
        }
    )
}

extension AppAction {
    var gameAction: GameAction? {
        if case .game(let action) = self {
            return action
        }
        return nil
    }
}
