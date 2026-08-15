//
//  Action.swift
//  SixFourChess
//
//  Application-specific action namespace
//

import Foundation

/// Base action types for the application
enum AppAction: ReduxAction {
    case game(GameAction)
    case ui(UIAction)
}
