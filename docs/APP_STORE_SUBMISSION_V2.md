# SixFour — App Store Submission Checklist v2

Date: 2026-08-15

## Checklist before submission

- [ ] Build with release configuration.
- [ ] Swift version and deployment target match project settings.
- [ ] Confirm privacy policy and support URLs are current.
- [ ] Verify App Store privacy declarations are up to date.

## Runtime privacy boundaries

Current branch behavior is local-first.

- Core gameplay and game state: local.
- Analytics/diagnostics: optional and consent-gated via `ConsentModule`.
- Optional cloud analysis (Master mode): `stockfish.online` only, when enabled by user.

No online multiplayer accounts, no Firebase auth/sign-in, and no online game synchronization.

## Data types to declare in App Store Privacy details

Recommended declaration:

- `User ID` (if used), for App Functionality.
- `Product Interaction` usage events, optional and consent-gated.
- `Diagnostics` / `Performance` for optional telemetry.

Tracking: `No`.

## SDK list for this release

- Remote network calls are only made for optional analysis.
- No Firebase Auth/Realtime Database dependency for gameplay.

## Submission notes

- Explicit consent at first launch, no forced close.
- No ads, no IDFA.
- No multiplayer account system.

Review note draft:

SixFour is a local-first chess app with offline gameplay against AI.

- Offline mode is fully usable without network.
- Optional cloud analysis in Master mode only.
- Optional telemetry is collected only with explicit user consent.
