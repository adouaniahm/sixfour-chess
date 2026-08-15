# SixFourChess Architecture (Current Release)

Last updated: 2026-08-15

## Overview

SixFourChess is a local-first SwiftUI chess app on iOS with a Redux-style state machine.

Current shipped behavior:
- Single gameplay loop: player vs AI.
- AI opponent can be configured by difficulty and color.
- Optional cloud AI execution for Master mode via `stockfish.online`.
- Move history, replay, and board persistence are local-first (SwiftData + `UserDefaults`).
- Analytics and crash reporting are enabled only with user consent through CMP.

## Core Architecture

The app follows a unidirectional data flow:

`View -> Action -> Reducer -> Middleware -> State -> View`

- `View`: SwiftUI screens in `Sources/Views`.
- `Action`: `AppAction` with two namespaces (`game`, `ui`) and `AppReducer` composition in `Sources/Redux`.
- `Reducer`: pure game state updates (`GameState` / `UIState`) in `Sources/Redux/Features`.
- `Middleware`: async effects and side effects, then optional `Mutation` updates.
- `State`: root `AppState` with:
  - `gameState: GameState`
  - `uiState: UIState`

## Folder Structure

```
SixFourChess/SixFourChess/Sources/
  AI/                AI stack: Stockfish, RAG, NNUE, opening book, cloud fallback
  ConsentModule/     CMP and privacy preferences
  Engine/            Core chess engine and move validation
  Models/            Domain types (moves, pieces, results, board positions)
  Redux/
    Core/           Store, middleware protocol, reducers
    Features/       Game and UI state/reducers
    Middlewares/    AI orchestration, persistence, analytics, accessibility, audio/haptics
    Selectors/      Derived read models
  Services/         Analytics, accessibility, audio, haptics
  Storage/          SwiftData models and persistence controllers
  Theme/            Design tokens and reusable UI styles
  Views/            SwiftUI screens and reusable components
```

## State Pipeline

`AppReduxStore.swift` wires:
- initial state: `AppState.initial`
- reducer: `appMutationReducer()`
- action reducer: `appActionReducer()`
- middleware chain (in execution order):
  1. `AnalyticsReduxMiddleware`
  2. `AccessibilityReduxMiddleware`
  3. `AudioHapticReduxMiddleware`
  4. `SettingsReduxMiddleware`
  5. `AIReduxMiddleware`
  6. `GameLogicReduxMiddleware`
  7. `EffectsReduxMiddleware`

Middleware executes side effects (move generation, async AI, persistence, analytics logging, vibration/audio announcements), then updates state where needed through mutations.

## Gameplay Flow (Current)

- `selectSquare(position:)`
  - Middleware computes legal moves and updates `availableMoves`.
- `makeMove(move:)`
  - Reducer applies the move.
  - Middleware computes commentary and optional move hint side effects.
  - `EffectsReduxMiddleware` persists state and archives finished games.
- Game end detection is performed in game reducer after each legal move.
- If next turn is AI, `EffectsReduxMiddleware` dispatches `.triggerAIMove`.
- AI middleware calculates a move and dispatches `.aiMoveCalculated(move:)`.

## AI Stack

- `AIReduxMiddleware` owns AI providers by color:
  - Legacy `ChessAI` (Negamax + evaluation) as fallback.
  - RAG stack when available (`RAGChessAI`, board encoder, opening book, optional NNUE).
  - Cloud AI (`StockfishCloudAI`) for `.master` when remote analysis is needed.
- Provider selection logic is dynamic and degrades safely if optional assets are missing.

## Persistence

- `GamePersistenceController` persists board state and active game snapshots using SwiftData.
- Finished games are archived for replay.
- `EffectsReduxMiddleware` triggers persistence after meaningful game mutations (move, new game, mode changes, end game).

## Accessibility and Observability

- `AccessibilityReduxMiddleware` and `AudioHapticReduxMiddleware` provide:
  - VoiceOver announcements
  - Haptic and sound feedback
- Consent controls are centralized in `ConsentModule`; analytics and crash capture are consent-gated.

## Security and Privacy Boundaries

What is still remote:
- Cloud AI requests in Master mode (stockfish.online).
- App lifecycle analytics and crash telemetry (only after consent).

What is local:
- Chess engine and game state transitions.
- Match history and replay data.
- UI state and user settings.

## Notes for Open Source Review

This architecture is intentionally kept compact and practical:
- single gameplay entry path (no shipped online multiplayer service layer),
- explicit action boundaries in Redux,
- deterministic local state transition logic,
- modular AI infrastructure with safe fallback behavior.
