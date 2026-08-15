//
//  AppState.swift
//  SixFourChess
//
//  Redux Application State
//

import Foundation

/// The root state of the entire application
struct AppState {
    var gameState: GameState
    var uiState: UIState

    /// Initial state for the application
    static let initial = AppState(
        gameState: .initial,
        uiState: .initial
    )
}
