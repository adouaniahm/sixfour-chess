//
//  ReduxStore.swift
//  SixFourChess
//
//  Redux Core - Store with Mutation Flow Orchestration
//

import Foundation
import Observation

/// Redux store with automatic mutation orchestration.
/// Architecture inspired by Kotlin Redux + MVI/Elm.
@Observable
class ReduxStore<State>: Dispatching {
    /// Current state, read-only from the outside.
    private(set) var state: State

    /// Reducer that applies mutations.
    private let mutationReducer: MutationReducer<State>

    /// Reducer that applies actions directly.
    private let actionReducer: ReduxReducer<State>?

    /// List of middlewares.
    private let middlewares: [ReduxMiddleware]

    /// Queue used to synchronize mutations.
    private let stateQueue = DispatchQueue(label: "com.sixfour.redux.mutation", qos: .userInitiated)

    /// Initializes the store.
    /// - Parameters:
    ///   - initialState: État initial
    ///   - reducer: Reducer combiné (créé avec `reducers()` et `onMutation()`)
    ///   - actionReducer: Reducer pour actions directes (optionnel)
    ///   - middlewares: Liste des middlewares
    // Explicit deinit to work around Swift 6.2 compiler crash
    // in EarlyPerfInliner on @Observable synthesized deinit (Release builds)
    @_optimize(none)
    deinit {}

    init(
        initialState: State,
        reducer: @escaping MutationReducer<State>,
        actionReducer: ReduxReducer<State>? = nil,
        middlewares: [ReduxMiddleware] = []
    ) {
        self.state = initialState
        self.mutationReducer = reducer
        self.actionReducer = actionReducer
        self.middlewares = middlewares
    }

    /// Dispatches an action.
    /// The store automatically:
    /// 1. Applies the action through the action reducer, if present.
    /// 2. Passes the action to the middlewares.
    /// 3. Collects the returned `ReduxFlow<Mutation>` values.
    /// 4. Applies each mutation through the mutation reducer.
    /// - Parameter action: Action to dispatch.
    func dispatch(_ action: ReduxAction) {
        // 1. Apply the action directly if an action reducer exists.
        if let actionReducer = actionReducer {
            stateQueue.sync {
                actionReducer(&self.state, action)
            }
        }

        // 2. Capture the current state for middlewares (read-only).
        let currentState = makeAppState(from: state)

        // 3-4. For each middleware, collect and apply mutations.
        for middleware in middlewares {
            // Call invoke(), which returns a `ReduxFlow<Mutation>`.
            let mutationFlow = middleware.invoke(action: action, state: currentState)

            // Collect mutations from the flow.
            mutationFlow.collect { [weak self] mutation in
                guard let self = self else { return }

                // Apply the mutation synchronously.
                self.stateQueue.sync {
                    self.mutationReducer(&self.state, mutation)
                }
            }
        }
    }

    /// Dispatches multiple actions sequentially.
    /// - Parameter actions: Actions to dispatch.
    func dispatch(_ actions: [ReduxAction]) {
        actions.forEach { dispatch($0) }
    }

    /// Dispatches an action asynchronously on the main actor.
    /// - Parameter action: Action to dispatch.
    func dispatchAsync(_ action: ReduxAction) async {
        await Task { @MainActor in
            dispatch(action)
        }.value
    }

    /// Creates an `AppState` from the generic state.
    /// Subclasses are expected to override this method.
    /// - Parameter state: Current state.
    /// - Returns: Corresponding `AppState`.
    func makeAppState(from state: State) -> AppState {
        // By default, assume `State` is `AppState`.
        // Subclasses can override this when needed.
        return state as! AppState
    }
}
