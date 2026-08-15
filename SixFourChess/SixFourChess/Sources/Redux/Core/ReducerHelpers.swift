//
//  ReducerHelpers.swift
//  SixFourChess
//
//  Redux Core - Reducer Helpers (onMutation pattern)
//

import Foundation

/// Type alias for a reducer function.
/// A reducer takes a mutable state and a mutation, then applies the transformation.
typealias MutationReducer<State> = (inout State, Mutation) -> Void

// MARK: - Reducer Combiners

/// Combines multiple reducers into a single one.
/// Reducers are applied in order.
/// - Parameter reducers: List of reducers to combine.
/// - Returns: Combined reducer.
func reducers<State>(_ reducers: MutationReducer<State>...) -> MutationReducer<State> {
    return { state, mutation in
        for reducer in reducers {
            reducer(&state, mutation)
        }
    }
}

// MARK: - onMutation Helpers

/// Creates a reducer for a specific mutation type with payload.
/// - Parameters:
///   - mutationType: Mutation type to handle, used for type inference.
///   - handler: Handler that receives the mutable state and typed mutation.
/// - Returns: Reducer that applies the handler only for the specified mutation type.
func onMutation<State, M: Mutation>(
    _ mutationType: M.Type,
    handler: @escaping (inout State, M) -> Void
) -> MutationReducer<State> {
    return { state, mutation in
        if let specificMutation = mutation as? M {
            handler(&state, specificMutation)
        }
    }
}

/// Creates a reducer for a specific mutation type without payload.
/// - Parameters:
///   - mutationType: Mutation type to handle, used for type inference.
///   - handler: Handler that receives the mutable state.
/// - Returns: Reducer that applies the handler only for the specified mutation type.
func onMutation<State, M: Mutation>(
    _ mutationType: M.Type,
    handler: @escaping (inout State) -> Void
) -> MutationReducer<State> {
    return { state, mutation in
        if mutation is M {
            handler(&state)
        }
    }
}

// MARK: - Enum Case Matching Helpers

/// Helper for matching specific enum cases.
/// Example: `onMutation(GameMutation.self, case: \.clearBoard) { state in ... }`
func onMutation<State, M: Mutation, Case>(
    _ mutationType: M.Type,
    case casePath: @escaping (M) -> Case?,
    handler: @escaping (inout State, Case) -> Void
) -> MutationReducer<State> {
    return { state, mutation in
        if let specificMutation = mutation as? M,
           let caseValue = casePath(specificMutation) {
            handler(&state, caseValue)
        }
    }
}
