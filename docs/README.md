# Privacy Policy v2.3

This folder contains the privacy policy pages used by the app.

## 🧱 Project architecture

The app is organized around a few clear layers:

- `Sources/Views`: SwiftUI screens and reusable UI components.
- `Sources/Redux`: application state, actions, reducers, and middleware.
- `Sources/Engine`: chess rules, move generation, and board state.
- `Sources/AI`: local and remote chess evaluation logic.
- `Sources/Storage`: persistence for game history, snapshots, and user settings.
- `Sources/ConsentModule`: privacy and consent flows.

This structure keeps UI, game logic, AI, and persistence separated so the codebase stays maintainable and easier to review.
