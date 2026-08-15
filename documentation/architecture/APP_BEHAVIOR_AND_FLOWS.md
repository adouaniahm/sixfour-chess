# App Behavior and Key Flows

This document reflects runtime behavior of the current branch.

## 1. App entry and consent

- App launches with splash.
- If CMP choice is missing, consent banner is shown.
- Without consent, analytics/crash uploads are blocked.
- With consent, consented services run behind normal App lifecycle.

## 2. Gameplay loop

The app runs a local AI loop:
- board setup
- legal move selection
- move execution
- game status checks (checkmate/stalemate/threefold/50-move)
- optional AI continuation

`AppReduxStore` is the single source of runtime truth.

## 3. Data and persistence

- `GamePersistenceController` restores snapshots on startup.
- Every meaningful game action is persisted through `EffectsReduxMiddleware`.
- Finished games are archived for replay.
- No online lobby, no match invitations, no match join/reconnect logic in active flow.

## 4. AI behavior

- AI is configured through `GameModeState.aiConfig`.
- `AIReduxMiddleware` orchestrates:
  - local fallback (`ChessAI`)
  - optional RAG pipeline (board encoder, opening book, optional NNUE/vector)
  - optional remote provider (`StockfishCloudAI`) in high-difficulty flow
- Fallback chain is safe: local options remain usable even if optional assets are unavailable.

## 5. Feedback and accessibility

- Moves update move comments in-app.
- VoiceOver announcements are generated when enabled.
- Audio/haptic cues run through dedicated middleware.

## 6. Error and resiliency

- Invalid actions are filtered by engine legality.
- Async AI failures are surfaced through UI state (`showCloudError`) and do not block local play.
- App remains usable offline.

## 7. Scope and deprecations

Any online/multiplayer flows in older docs (matchmaking, Firebase sync, deep-link match joins) are historical and no longer represent this branch.

