//
//  UIFeature.swift
//  SixFourChess
//

import Foundation

enum GameAlert: Equatable, Identifiable {
    case gameResult
    case promotion
    case aiPromotion
    case error
    case newGameConfirmation

    var id: String {
        switch self {
        case .gameResult: return "gameResult"
        case .promotion: return "promotion"
        case .aiPromotion: return "aiPromotion"
        case .error: return "error"
        case .newGameConfirmation: return "newGameConfirmation"
        }
    }
}

enum ActiveSheet: Equatable, Identifiable {
    case hint
    case history

    var id: String {
        switch self {
        case .hint: return "hint"
        case .history: return "history"
        }
    }
}

struct UIState: Equatable {
    enum CurrentScreen {
        case game
    }

    var currentScreen: CurrentScreen
    var activeAlert: GameAlert?
    var activeSheet: ActiveSheet?
    var showSettings: Bool
    var promotionMoves: [Move]
    var aiPromotionPieceType: PieceType?
    var aiPromotionMove: Move?
    var currentHint: String
    var errorAlertTitle: String
    var errorAlertMessage: String
    var showCloudError: Bool
    var cloudErrorIsNetwork: Bool
    var currentMoveComment: MoveComment?
    var animatingMove: Move?

    static let initial = UIState(
        currentScreen: .game,
        activeAlert: nil,
        activeSheet: nil,
        showSettings: false,
        promotionMoves: [],
        aiPromotionPieceType: nil,
        aiPromotionMove: nil,
        currentHint: "",
        errorAlertTitle: "",
        errorAlertMessage: "",
        showCloudError: false,
        cloudErrorIsNetwork: false,
        currentMoveComment: nil,
        animatingMove: nil
    )

    var showPromotionAlert: Bool { activeAlert == .promotion }
    var showAIPromotionAlert: Bool { activeAlert == .aiPromotion }
    var showAITurnAlert: Bool { false }
    var showHintAlert: Bool { activeSheet == .hint }
    var showErrorAlert: Bool { activeAlert == .error }
}

enum UIAction: ReduxAction {
    case showGame
    case setSettingsVisible(Bool)
    case setPromotionAlert(moves: [Move])
    case setAIPromotionAlert(pieceType: PieceType?, move: Move?)
    case setAITurnAlertVisible(Bool)
    case setHintAlert(hint: String)
    case setErrorAlert(title: String, message: String)
    case animateMove(move: Move)
    case completeAnimatedMove
    case showAlert(GameAlert)
    case dismissAlert
    case showSheet(ActiveSheet)
    case dismissSheet
    case setCloudError(show: Bool, isNetwork: Bool)
    case showMoveComment(MoveComment)
    case clearMoveComment
}

let uiReducer: ReduxReducer<UIState> = { state, action in
    guard let uiAction = (action as? AppAction)?.uiAction else { return }

    switch uiAction {
    case .showGame:
        state.currentScreen = .game

    case .setSettingsVisible(let visible):
        state.showSettings = visible

    case .setPromotionAlert(let moves):
        state.promotionMoves = moves
        if !moves.isEmpty {
            state.activeAlert = .promotion
        } else if state.activeAlert == .promotion {
            state.activeAlert = nil
        }

    case .setAIPromotionAlert(let pieceType, let move):
        state.aiPromotionPieceType = pieceType
        state.aiPromotionMove = move
        if pieceType != nil {
            state.activeAlert = .aiPromotion
        } else if state.activeAlert == .aiPromotion {
            state.activeAlert = nil
        }

    case .setAITurnAlertVisible:
        break

    case .setHintAlert(let hint):
        state.currentHint = hint
        if !hint.isEmpty {
            state.activeSheet = .hint
        } else if state.activeSheet == .hint {
            state.activeSheet = nil
        }

    case .setErrorAlert(let title, let message):
        state.errorAlertTitle = title
        state.errorAlertMessage = message
        if !title.isEmpty {
            state.activeAlert = .error
        } else if state.activeAlert == .error {
            state.activeAlert = nil
        }

    case .animateMove(let move):
        state.animatingMove = move

    case .completeAnimatedMove:
        state.animatingMove = nil

    case .showAlert(let alert):
        state.activeAlert = alert

    case .dismissAlert:
        state.activeAlert = nil

    case .showSheet(let sheet):
        state.activeSheet = sheet

    case .dismissSheet:
        state.activeSheet = nil

    case .setCloudError(let show, let isNetwork):
        state.showCloudError = show
        state.cloudErrorIsNetwork = isNetwork

    case .showMoveComment(let comment):
        state.currentMoveComment = comment

    case .clearMoveComment:
        state.currentMoveComment = nil
    }
}

extension AppAction {
    var uiAction: UIAction? {
        if case .ui(let action) = self {
            return action
        }
        return nil
    }
}
