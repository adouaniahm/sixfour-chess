//
//  ReduxMiddleware.swift
//  SixFourChess
//
//  Redux Core - Middleware Protocol for Mutations
//

import Foundation

/// Base protocol for mutations.
/// All mutations must conform to it.
protocol Mutation {}

/// Protocol for Redux middlewares that emit mutation flows.
/// A middleware intercepts actions and can return mutations to apply.
protocol ReduxMiddleware {
    /// Processes an action and returns a flow of mutations.
    /// - Parameters:
    ///   - action: Dispatched action.
    ///   - state: Current application state, read-only.
    /// - Returns: Flow of mutations to apply to the state.
    func invoke(action: ReduxAction, state: AppState) -> ReduxFlow<Mutation>
}
