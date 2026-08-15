//
//  AppReduxStore.swift
//  SixFourChess
//
//  Global Redux Store with Mutation Flow Architecture
//

import Foundation
import SwiftUI
import Combine

/// Global application store with MVI/Elm architecture
@MainActor
final class AppReduxStore: ReduxStore<AppState> {
    /// Shared store instance
    static let shared = AppReduxStore()

    private init() {
        // Create dispatch context with weak reference to store (set after init)
        let dispatchContext = DispatchContext(dispatcher: nil)
        
        // Configure Analytics Service with dependency injection
        AnalyticsService.shared.configure(consentManager: ConsentModule.manager)

        // Create Redux middleware chain
        let middlewares: [ReduxMiddleware] = [
            AnalyticsReduxMiddleware(), // Tracking first
            AccessibilityReduxMiddleware(), // VoiceOver announcements (passive)
            AudioHapticReduxMiddleware(), // Audio and haptic feedback (passive)
            SettingsReduxMiddleware(),
            AIReduxMiddleware(dispatchContext: dispatchContext),
            GameLogicReduxMiddleware(dispatchContext: dispatchContext),
            EffectsReduxMiddleware(dispatchContext: dispatchContext)
        ]

        // Initialize with ReduxStore
        super.init(
            initialState: .initial,
            reducer: appMutationReducer(),
            actionReducer: appActionReducer(),
            middlewares: middlewares
        )

        // Set weak reference to self in dispatch context (breaks circular dependency)
        dispatchContext.dispatcher = self

        // Restore previously saved game for current mode if available
        let currentMode = state.gameState.mode
        if let snapshot = GamePersistenceController.shared.loadSnapshot(for: currentMode) {
            dispatch(AppAction.game(.restoreSnapshot(snapshot: snapshot)))
        }

        applyUITestingLaunchConfiguration()

        GamePersistenceController.shared.save(gameState: state.gameState)
        Logger.success("Redux Store initialized", subsystem: .redux)
    }

    /// Override makeAppState since State is already AppState
    override func makeAppState(from state: AppState) -> AppState {
        return state
    }

    private func applyUITestingLaunchConfiguration() {
        guard ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }

        let persistence = GamePersistenceController.shared
        persistence.clearSnapshot(for: nil)
        persistence.clearPlayedGames()

        let scenario = ScreenshotScenario.current

        if let snapshot = scenario.currentGameSnapshot {
            dispatch(AppAction.game(.restoreSnapshot(snapshot: snapshot)))
        } else {
            dispatch(AppAction.game(.resetGame))
        }

        for finishedGame in scenario.playedGames {
            persistence.archivePlayedGame(finishedGame)
        }

        if let hintMove = scenario.hintMove {
            dispatch(AppAction.game(.setHint(move: hintMove)))
        }

        if let hintText = scenario.hintText {
            dispatch(AppAction.ui(.setHintAlert(hint: hintText)))
        }
    }
}

@MainActor
private enum ScreenshotScenario: String {
    case board
    case hint
    case settings
    case history
    case replay

    static var current: ScreenshotScenario {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--screenshot-scenario"),
              args.indices.contains(index + 1),
              let scenario = ScreenshotScenario(rawValue: args[index + 1]) else {
            return .board
        }
        return scenario
    }

    var currentGameSnapshot: GameStateSnapshot? {
        switch self {
        case .board, .settings, .history, .replay:
            return makeOngoingGameSnapshot()
        case .hint:
            return makeHintGameSnapshot()
        }
    }

    var playedGames: [GameState] {
        switch self {
        case .history, .replay:
            return [
                makeFinishedGame(
                    moves: ["e4", "e5", "Nf3", "Nc6", "Bc4", "Nd4", "Nxe5", "Qg5", "Bxf7+", "Ke7", "O-O", "Qxe5", "Bxg8", "Rxg8", "c3", "Ne6", "d4", "Qxe4", "Re1", "Qh4", "d5"],
                    difficulty: .expert
                ),
                makeFinishedGame(
                    moves: ["f3", "e5", "g4", "Qh4#"],
                    difficulty: .hard
                ),
                makeFinishedGame(
                    moves: ["d4", "Nf6", "c4", "e6", "Nc3", "Bb4", "e3", "O-O", "Bd3", "d5", "Nf3", "c5", "O-O", "Nc6", "a3", "Bxc3", "bxc3", "dxc4", "Bxc4", "Qc7", "Bb2", "e5", "d5", "Na5", "Ba2", "c4", "e4", "Nb3", "Bxb3", "cxb3"],
                    difficulty: .medium
                )
            ]
        case .board, .hint, .settings:
            return []
        }
    }

    var hintMove: Move? {
        guard self == .hint else { return nil }
        let board = makeBoard(from: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6"])
        return board
            .getAllLegalMoves(for: board.currentPlayer)
            .first { $0.from == Position(row: 7, col: 4) && $0.to == Position(row: 7, col: 6) } // O-O
            ?? board.getAllLegalMoves(for: board.currentPlayer).first
    }

    var hintText: String? {
        guard self == .hint else { return nil }
        return [
            "King Safety",
            "Castle to bring your king to safety and connect your rook.",
            "",
            "Suggested Move",
            "O-O secures your king and improves coordination."
        ].joined(separator: "\n")
    }

    private func makeOngoingGameSnapshot() -> GameStateSnapshot {
        snapshot(
            from: makeBoard(from: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6", "O-O", "Be7"]),
            difficulty: .expert
        )
    }

    private func makeHintGameSnapshot() -> GameStateSnapshot {
        snapshot(
            from: makeBoard(from: ["e4", "e5", "Nf3", "Nc6", "Bb5", "a6", "Ba4", "Nf6"]),
            difficulty: .expert
        )
    }

    private func snapshot(from board: ChessBoard, difficulty: AIDifficulty) -> GameStateSnapshot {
        GameStateSnapshot(
            board: board.snapshot,
            mode: .ai(AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: difficulty)),
            isActive: true,
            gameResult: nil,
            suggestedMove: nil,
            startedAt: Date().addingTimeInterval(-900),
            isArchivedInHistory: false,
            hintsRemaining: 3,
            savedAt: Date(),
            gameMode: nil,
            difficulty: nil,
            whiteAIEnabled: nil,
            blackAIEnabled: nil
        )
    }

    private func makeFinishedGame(moves: [String], difficulty: AIDifficulty) -> GameState {
        let board = makeBoard(from: moves)
        return GameState(
            board: board,
            mode: .ai(AIConfig(whiteEnabled: false, blackEnabled: true, difficulty: difficulty)),
            isActive: false,
            gameResult: board.checkGameEnd(),
            isThinking: false,
            isCalculatingHint: false,
            selectedPosition: nil,
            availableMoves: [],
            suggestedMove: nil,
            startedAt: Date().addingTimeInterval(-7200),
            isArchivedInHistory: false,
            hintsRemaining: 3
        )
    }

    private func makeBoard(from moves: [String]) -> ChessBoard {
        (try? ChessBoard.fromMoveHistory(moves)) ?? ChessBoard()
    }
}

// MARK: - SwiftUI Environment Key

private struct AppReduxStoreKey: EnvironmentKey {
    static let defaultValue = AppReduxStore.shared
}

extension EnvironmentValues {
    var appReduxStore: AppReduxStore {
        get { self[AppReduxStoreKey.self] }
        set { self[AppReduxStoreKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Inject the mutation store into the environment
    func withAppReduxStore() -> some View {
        self.environment(\.appReduxStore, AppReduxStore.shared)
    }
}
