//
//  Reducer.swift
//  SixFourChess
//
//  Redux Reducer Protocol
//

import Foundation

/// Combines multiple reducers into a single reducer
func combineReducers<State>(_ reducers: ReduxReducer<State>...) -> ReduxReducer<State> {
    return { state, action in
        for reducer in reducers {
            reducer(&state, action)
        }
    }
}
