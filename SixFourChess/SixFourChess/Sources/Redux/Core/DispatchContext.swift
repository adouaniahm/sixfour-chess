//
//  DispatchContext.swift
//  SixFourChess
//
//  Provides a way to dispatch actions without directly referencing the store
//

import Foundation

/// Protocol for any object that can dispatch actions
protocol Dispatching: AnyObject {
    func dispatch(_ action: ReduxAction)
}

/// Context that lets middlewares dispatch actions without a strong store reference.
@MainActor
class DispatchContext {
    weak var dispatcher: Dispatching?

    init(dispatcher: Dispatching?) {
        self.dispatcher = dispatcher
    }

    /// Dispatches an action through the dispatcher.
    nonisolated func dispatch(_ action: sending ReduxAction) {
        Task { @MainActor in
            dispatcher?.dispatch(action)
        }
    }
}

/// Synchronous DispatchContext for tests - dispatches immediately on the MainActor
/// instead of creating a fire-and-forget Task.
@MainActor
final class SynchronousDispatchContext: DispatchContext {
    nonisolated override func dispatch(_ action: sending ReduxAction) {
        MainActor.assumeIsolated {
            dispatcher?.dispatch(action)
        }
    }
}
