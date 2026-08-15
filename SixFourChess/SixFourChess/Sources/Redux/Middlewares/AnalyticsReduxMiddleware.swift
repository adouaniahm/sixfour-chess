//
//  AnalyticsReduxMiddleware.swift
//  SixFourChess
//

import Foundation

final class AnalyticsReduxMiddleware: ReduxMiddleware {
    private let analytics: AnalyticsServiceProtocol

    init(analytics: AnalyticsServiceProtocol = AnalyticsService.shared) {
        self.analytics = analytics
    }

    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation> {
        guard let appAction = action as? AppAction else { return emptyFlow() }

        switch appAction {
        case .game(let gameAction):
            handleGameAction(gameAction, state: state.gameState)
        case .ui(let uiAction):
            handleUIAction(uiAction)
        }

        return emptyFlow()
    }

    private func handleGameAction(_ action: GameAction, state: GameState) {
        switch action {
        case .newGame(let mode, let difficulty):
            analytics.logEvent(AnalyticsService.Event.gameStarted, parameters: [
                AnalyticsService.Param.gameMode: mode.rawValue,
                AnalyticsService.Param.difficulty: difficulty.rawValue
            ])

        case .endGame(let result):
            analytics.logEvent(AnalyticsService.Event.gameFinished, parameters: [
                AnalyticsService.Param.result: result.description,
                AnalyticsService.Param.moveCount: state.board.moveHistory.count,
                AnalyticsService.Param.gameMode: "ai"
            ])

        case .requestHint:
            analytics.logEvent("game_hint_requested", parameters: nil)

        case .promotePawn(let pieceType):
            analytics.logEvent("game_promotion", parameters: ["piece": pieceType.rawValue])

        case .changeDifficulty(let difficulty):
            analytics.logEvent("settings_change_difficulty", parameters: ["difficulty": difficulty.rawValue])

        case .changeGameMode(let mode):
            analytics.logEvent("settings_change_mode", parameters: ["mode": mode.rawValue])

        default:
            break
        }
    }

    private func handleUIAction(_ action: UIAction) {
        switch action {
        case .showGame:
            analytics.logScreen(name: "Game", class: "ReduxGameView")
        case .setSettingsVisible(true):
            analytics.logScreen(name: "Settings", class: "ReduxSettingsView")
        default:
            break
        }
    }
}
