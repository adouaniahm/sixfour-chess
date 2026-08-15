//
//  AppActionReducer.swift
//  SixFourChess
//
//  Combined Action Reducer for AppState (handles all actions)
//

import Foundation

/// Reducer for actions that modify state directly (not via mutations)
func appActionReducer() -> ReduxReducer<AppState> {
    return { state, action in
        // Apply Game reducer (handles GameAction)
        gameActionReducer(&state.gameState, action)

        // Apply UI reducer
        uiReducer(&state.uiState, action)
    }
}
