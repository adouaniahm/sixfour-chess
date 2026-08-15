# Game Flows Specification — SixFourChess

Date: 2026-08-15

This document describes the shipped gameplay behavior for the current branch.

## 1) Core In-Game Flow (Player vs AI)

1. User taps a board square.
2. `GameAction.selectSquare(position:)` is dispatched.
3. `GameLogicReduxMiddleware` computes legal moves for that piece.
4. Middleware dispatches `GameAction.setAvailableMoves`.
5. User taps a destination.
6. `GameAction.makeMove(move:)` is dispatched.
7. `GameReducer` applies the move synchronously.
8. Legal-game state is checked:
   - If checkmate/stalemate/threefold/50-move, the game ends and `GameAction.endGame` is set by reducer path.
   - Otherwise, the turn switches to the next player.
9. `EffectsReduxMiddleware` persists state and may trigger AI if needed.

## 2) AI Turn Flow

The AI turn is activated automatically when:
- current player is configured as AI color in `GameModeState`
- game is active
- app is not already in thinking state

1. `EffectsReduxMiddleware` dispatches `GameAction.triggerAIMove`.
2. `AIReduxMiddleware` selects provider:
   - Legacy `ChessAI` fallback (always available locally),
   - RAG `RAGChessAI` when optional assets are present,
   - `StockfishCloudAI` when `.master` requires remote analysis and network is available.
3. The result is dispatched as `.aiMoveCalculated(move:)`.
4. Game reducer applies the move and continues.

## 3) Hint Flow

1. User requests hint.
2. `GameAction.requestHint` is dispatched.
3. Middleware calculates a strong move using configured AI pipeline.
4. Response is dispatched as `.setHint(move:)`.
5. `hintsRemaining` is decremented per hint request.

## 4) Promotion Flow

1. User touches a pawn that reaches last rank.
2. Middleware shows promotion options through UI action.
3. User chooses piece.
4. `GameAction.promotePawn(to:)` is dispatched and move is completed.

## 5) Settings and Re-entry

- Mode/difficulty updates are handled through `GameAction.changeGameMode` and `GameAction.changeDifficulty`.
- Scene changes and app relaunch restore persisted snapshots when available.
- `SettingsReduxMiddleware` and `EffectsReduxMiddleware` keep persistence in sync.

## 6) Errors and Recovery

- Invalid move commands are ignored by rule engine logic (`makeMove` checks legality).
- AI/hints failures:
  - UI surfaces error state via `UIState.showCloudError`.
- Crash and async failures are logged through instrumentation paths behind consent.

## 7) Replay and History

- Move history is stored internally in LAN-like internal format and persisted with the game snapshot.
- Completed games are archived and can be replayed through the history UI.
- Move comment overlays are generated for completed board transitions when enabled.

## 8) Legacy note

This branch does not ship online matchmaking or Firebase multiplayer flows.
Any online documentation should be treated as historical reference only.

