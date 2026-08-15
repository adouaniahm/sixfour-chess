//
//  AppMutationReducer.swift
//  SixFourChess
//
//  Combined Mutation Reducer for AppState
//

import Foundation

/// Combined reducer for `AppState` that applies mutations.
func appMutationReducer() -> MutationReducer<AppState> {
    return { state, mutation in
        if let gameMutation = mutation as? GameMutation {
            gameMutationReducer()(&state.gameState, gameMutation)
        }
    }
}
