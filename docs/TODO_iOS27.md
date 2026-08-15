# TODO — iOS 27 readiness

This document tracks the work needed to keep the app polished and credible once iOS 27 becomes the target baseline.

## High priority

- Verify the app against the iOS 27 SDK and beta release notes.
- Keep Swift 6 strict concurrency clean: no new data-race warnings, no unchecked shared mutable state.
- Audit all `@MainActor` boundaries around UI, reducers, AI, and persistence.
- Re-test the full app flow after each Xcode / iOS beta update.
- Keep privacy, support, and source URLs aligned with the public open-source repo.

## Apple Intelligence / Foundation Models

- Evaluate whether the app should expose a “coach mode” powered by Foundation Models.
- Add optional move explanations in natural language.
- Consider board summaries, game recaps, or post-game analysis prompts.
- Keep a non-AI fallback path so the game remains usable without Apple Intelligence.

## App Intents and system integration

- Expose App Intents for the most useful actions:
  - new game
  - undo move
  - request hint
  - open history
  - change difficulty
- Review whether Siri / Shortcuts integration adds value for the app.
- Keep all intents simple, deterministic, and safe.

## UI and adaptability

- Test the layout on new screen sizes, dynamic type, and multitasking states.
- Re-check compact controls, sheets, and navigation on iPhone and iPad.
- Keep the interface resilient to future design changes.
- Avoid overly rigid spacing or fixed-size assumptions.

## AI and performance

- Revalidate Core ML, opening book, and cloud fallback behavior on the new SDK.
- Keep the NNUE and RAG pipeline isolated and easy to reason about.
- Measure startup time, move latency, and hint latency after OS updates.
- Ensure background work stays off the main thread.

## Privacy and publication

- Keep `privacy/v2.3` as the single public privacy policy version.
- Update linked URLs only if the public repo structure changes.
- Verify `SECURITY.md`, `NOTICE`, `THIRD_PARTY_NOTICES.md`, and `sbom.cdx.json` before each public release.
- Keep the open-source README focused and current.

## Nice to have

- Add a short “What’s new for iOS 27” section to the public README if the app adopts new APIs.
- Document any new App Intents or AI features in the architecture notes.
- Keep comments and docstrings in English only.

