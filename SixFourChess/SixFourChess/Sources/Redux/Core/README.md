# Redux Core

Reusable Redux primitives used by this app:

- `CoreTypes.swift`  
  Defines `ReduxAction`, reducer and middleware type aliases.
- `ReduxStore.swift`  
  Thread-safe base store with middleware and mutation support.
- `ReduxMiddleware.swift` and `ReduxFlow.swift`  
  Middleware contracts and execution helpers.
- `ReduxReducer.swift`, `ReducerHelpers.swift`, `AppMutationReducer.swift`  
  Reducer composition helpers.
- `DispatchContext.swift`  
  Dispatcher abstraction used by async middleware.

### Usage in this app

1. Root store:
   - `AppReduxStore.swift` initializes `AppState` and composes reducers/middleware.
2. Actions:
   - `AppAction` with `.game` and `.ui` branches.
3. Store injection:
   - `withAppReduxStore()` extension injects the shared store into SwiftUI environment.

