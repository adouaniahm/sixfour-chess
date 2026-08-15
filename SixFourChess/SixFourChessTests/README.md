# Unit Test Documentation

This target uses **Swift Testing** (not XCTest).

## Why Swift Testing

- Modern syntax (`@Test`, `#expect`)
- Native async support
- Better compiler/runtime diagnostics in modern Xcode

## Test Organization

```
SixFourChessAppTests/
├── Engine/          Chess rules and move validation
├── AI/              AI stack and evaluation tests
├── Core/            Reducer and persistence tests
├── Middlewares/     Redux middleware behavior tests
└── Mocks/           Shared test fakes
```

## Async and MainActor Notes

Some Redux flows use `Task`, so tests use:
- `MainActor` assertions where required,
- `Task` suspension where needed,
- explicit synchronous dispatch context for deterministic middleware tests.

The project includes test helpers for deterministic action capture and timing-sensitive cases.

## Running tests

From Xcode:
- Use scheme `SixFourChessApp Dev` or `SixFourChessAppTests`
- Press **Cmd+U**

From terminal:

```bash
xcodebuild -project SixFourChessApp.xcodeproj \
  -scheme "SixFourChessApp Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=26.0' \
  test
```

## Notes

- Keep tests independent from network and UI flow assumptions.
- Keep deterministic fixtures close to the tested area.
- Prefer async-safe assertions when middleware emits actions through callbacks.

