## SwiftUI & Concurrency Footprint (Tech Watch)

### SwiftUI: Areas Used
- `NavigationStack`, `NavigationView`, sheets, alerts, toolbars, and `NavigationLink` for navigation and modal flows.
- State management primitives: `@State`, `@StateObject`, `@Environment`, `@Published`, custom environment keys, bindings to alerts/sheets, and conditional rendering with `@ViewBuilder`.
- Layout helpers: `GeometryReader`, `VStack`/`HStack`, `ScrollView`, `Form`, `Section`, `.toolbar`, `.task`, `.onReceive`, `.alert`, `.sheet`, custom components (`ChessBoardView`, `PlayerInfoView`), adaptive padding, and simple transitions (toast overlay).
- Styling: `buttonStyle`, `Label`, `ProgressView`, `.background(.thinMaterial)`, `.cornerRadius`, `monospaced` font, icons via SF Symbols.
- Accessibility: combined accessibility elements, labels/values/hints, hidden decorative views.

### SwiftUI: Gaps/Next Targets
- Modern navigation data APIs (`NavigationStack` with path binding, `NavigationSplitView`) and deep linking.
- Advanced layout (grids, `LazyVGrid`, `LazyHGrid`, `Layout` protocol) and animation (`withAnimation`, `matchedGeometryEffect`, custom transitions).
- Focus management and input modifiers (keyboard shortcuts beyond simple notifications, `@FocusState`).
- Preference keys/anchor geometry for cross-view communication.
- SwiftUI testing (snapshot/UI tests) and previews with mocked state.

### Concurrency: Areas Used
- Structured concurrency with `async/await`, `Task { @MainActor … }`, `Task { … }`, and `withCheckedThrowingContinuation` where callback-based APIs are needed.
- Main-actor isolation for UI-facing singletons and state updates.
- Async flows with `.task` on views and async button actions, plus simple debounce via `asyncAfter` for toasts.

### Concurrency: Gaps/Next Targets
- Cancellation handling and cooperative cancellation (propagating `Task` handles, checking `Task.isCancelled`).
- `TaskGroup`/`AsyncSequence`/`AsyncStream` for streaming DB events instead of callback bridges.
- Robust error handling (typed errors, retries/backoff) and unified async logging/metrics.
- Actor-based domain models to protect mutable state beyond `@MainActor` (e.g., game engine/AI workers).

### Swift 6 / Language Topics
- Used: `@Observable`, structured concurrency, `Sendable` on models; modern `ResultBuilder` usage via SwiftUI.
- Not covered yet: move-only types, macros, `observation` bindings beyond `@Observable`, noncopyable generics, `if #available` checks for Swift 6-only APIs, package plugins, and advanced safety features (strict concurrency warnings in all modules).

### Suggested Next Steps
1) Introduce navigation state with `NavigationStack` path + deep links; add previews/tests for key views.  
2) Add cancellation-aware async flows (e.g., wrap callback/event APIs in `AsyncStream`) and surface errors with retry UI.  
3) Explore SwiftUI animations/layout (`matchedGeometryEffect`, grids) for richer state changes (e.g., captured pieces).  
4) Pilot a Swift 6 feature: small macro or move-only type experiment, and enable stricter concurrency checks in one module.  
5) Add UI/preview tests for critical flows (offline gameplay and remote analysis fallbacks) using mocked stores.  

## Piece Icon Consistency (SwiftUI audit)
- **Main board (game view, history)**: uses `ChessPieceShape` for all pieces, filled black/white, with dual shadows in `ChessBoardView`. `GameViewerView` reuses the same `ChessBoardView`, so the icon set is identical.
- **Piece rendering**: visible board rendering stays on `ChessPieceShape` across main game views.
- **Unicode fallback symbol**: `Piece.symbol` is still available as a model value for logging or future alternate renderers, but it is not required by the current SwiftUI piece pipeline.
- **Conclusion**: All visible boards share the same vector shapes; there’s no mix of SF Symbols, bitmaps, or text glyphs for pieces. If you ever want a different visual style, you’d replace or theme `ChessPieceShape` and both the main/mini boards will update together.
