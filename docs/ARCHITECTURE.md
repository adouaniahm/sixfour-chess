# Architecture Documentation for Docs

## Runtime Architecture (Current Release)

The app uses a compact Redux/MVI-style pipeline centered on `AppReduxStore`:

```
View -> Action -> Reducer -> Middleware -> Store -> State -> View
```

## State

- `AppState`
  - `gameState: GameState`
  - `uiState: UIState`

## Redux Flow

`AppReduxStore.swift` wires:
- `initialState`: `AppState.initial`
- `reducer`: `appMutationReducer()`
- `actionReducer`: `appActionReducer()`
- middlewares:
  - `AnalyticsReduxMiddleware`
  - `AccessibilityReduxMiddleware`
  - `AudioHapticReduxMiddleware`
  - `SettingsReduxMiddleware`
  - `AIReduxMiddleware`
  - `GameLogicReduxMiddleware`
  - `EffectsReduxMiddleware`

`appMutationReducer()` applies pure reducers and mutation reducers:
- `gameReducer` + `gameMutationReducer`
- `uiReducer` + `uiMutationReducer`

## Current Features in the Store

- **Local gameplay loop** (human vs AI).
- **AI difficulty and side selection** through game mode (`GameMode` / `GameModeState`).
- **Move validation and legal move calculation**.
- **Hint pipeline** and move comment generation.
- **Persistence + replay** for finished and active games.
- **Consent-aware analytics and crash reporting**.

## Services Used by the App

- `AnalyticsService` (consent gated).
- `AudioService`, `HapticService`, `AccessibilityService`.
- `StockfishCloudAI` for remote analysis on high difficulty.
- `GamePersistenceController` (SwiftData + `UserDefaults`).

## Why not online mode in the current codebase

The project no longer keeps the previous Firebase multiplayer service stack in active flow.
There are no online matchmaking APIs in the current store pipeline.
Online-related legacy files and documentation were removed or archived.

## Data Lifecycles

- Game state snapshots are restored at startup when available.
- Each meaningful mutation can trigger persistence.
- Finished games are archived for replay.
- Hint counters and UI flags are persisted as part of game state.

## Privacy and Consent

- `ConsentModule` runs at app launch.
- If consent is not decided yet, the app asks once before enabling optional services.
- Non-consented mode still keeps core gameplay fully functional.
