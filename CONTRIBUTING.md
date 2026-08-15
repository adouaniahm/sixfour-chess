# Contributing to SixFour

Thank you for your interest in this project.

## Prerequisites

- Xcode (iOS target)
- Swift 6 (or compatible with your SDK targets)
- SwiftLint (optional)

## Getting started

```bash
git clone https://github.com/adouaniahm/sixfour-chess.git
cd sixfour-chess
```

Then open `SixFourChess/SixFourChess.xcodeproj` in Xcode.

### Signing for a physical device or archive

Copy `SixFourChess/Configurations/Signing.local.xcconfig.example` to `Signing.local.xcconfig`, then replace the placeholders with your own Apple team and (when needed) provisioning profile. The local file is ignored by Git; never commit signing identifiers or profile names.

## Development

- Keep changes small and scoped.
- Add tests when user-visible behavior changes.
- Follow existing patterns: Swift Concurrency, Redux/MVI architecture, Swift naming conventions.
- Update documentation when behavior changes.

## Build / tests

- Main scheme: `SixFourChess Dev`
- Run the iOS build and the tests related to your change.

## Commits

- Use clear and informative commit messages (for example: `feat: add handcrafted piece icon variants`).
- Keep each commit focused on a single logical change when possible.

## Pull requests

- Provide a clear description: what changed, why, and how to verify.
- Add screenshots when UI is impacted.
- List constraints, risks, and recommended follow-ups.
