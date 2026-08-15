import Foundation

/// Marker protocol for Redux actions.
protocol ReduxAction {}

/// Reducer signature – mutates state in response to an action.
typealias ReduxReducer<State> = (inout State, ReduxAction) -> Void
