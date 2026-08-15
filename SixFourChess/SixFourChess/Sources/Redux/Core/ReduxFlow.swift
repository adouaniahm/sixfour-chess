//
//  Flow.swift
//  SixFourChess
//
//  Redux Core - Flow (inspired by Kotlin Flow)
//

import Foundation

/// Asynchronous value stream, equivalent to Kotlin Flow.
/// Used to emit a sequence of values asynchronously.
struct ReduxFlow<T> {
    private let producer: (@escaping (T) -> Void) -> Void

    /// Initializes a flow with a producer.
    /// - Parameter producer: Function that emits values through the callback.
    init(producer: @escaping (@escaping (T) -> Void) -> Void) {
        self.producer = producer
    }

    /// Collects the values emitted by the flow.
    /// - Parameter collector: Callback invoked for each emitted value.
    func collect(_ collector: @escaping (T) -> Void) {
        producer(collector)
    }
}

// MARK: - Flow Builders

/// Creates a flow from an array of values.
/// - Parameter builder: Closure returning an array of values.
/// - Returns: Flow that emits each value from the array.
func flow<T>(_ builder: @escaping () -> [T]) -> ReduxFlow<T> {
    return ReduxFlow { emit in
        for value in builder() {
            emit(value)
        }
    }
}

/// Creates an empty flow that emits no values.
/// - Returns: Empty flow.
func emptyFlow<T>() -> ReduxFlow<T> {
    return ReduxFlow { _ in
        // Intentionally emits nothing.
    }
}

/// Creates a flow that emits a single value.
/// - Parameter value: Value to emit.
/// - Returns: Flow that emits the single value.
func flowOf<T>(_ value: T) -> ReduxFlow<T> {
    return ReduxFlow { emit in
        emit(value)
    }
}

/// Creates a flow from multiple values.
/// - Parameter values: Values to emit.
/// - Returns: Flow that emits each value.
func flowOf<T>(_ values: T...) -> ReduxFlow<T> {
    return ReduxFlow { emit in
        for value in values {
            emit(value)
        }
    }
}

// MARK: - Flow Operators

extension ReduxFlow {
    /// Transforms the values emitted by the flow.
    /// - Parameter transform: Transformation function.
    /// - Returns: New flow with transformed values.
    func map<R>(_ transform: @escaping (T) -> R) -> ReduxFlow<R> {
        return ReduxFlow<R> { emit in
            self.collect { value in
                emit(transform(value))
            }
        }
    }

    /// Filters the values emitted by the flow.
    /// - Parameter predicate: Filtering predicate.
    /// - Returns: New flow with filtered values.
    func filter(_ predicate: @escaping (T) -> Bool) -> ReduxFlow<T> {
        return ReduxFlow { emit in
            self.collect { value in
                if predicate(value) {
                    emit(value)
                }
            }
        }
    }
}
