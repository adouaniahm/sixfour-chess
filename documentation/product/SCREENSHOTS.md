# App Store Screenshots

Steps to generate localizable screenshots for submission.

## Quick Start

```bash
./generate_screenshots.sh
```

The script exports 15 raw PNGs into `screenshots_export/`.

To generate store-ready compositions:

```bash
./compose_store_screenshots.sh
```

Outputs are written to `screenshots_store_ready/`.

## Captured Screens

1. `01_GameBoard` — active game against AI  
2. `02_HintSystem` — hint sheet with preconfigured comment  
3. `03_Settings` — settings screen  
4. `04_PlayedGames` — completed games list  
5. `05_Replay` — move-by-move replay view

Each screen is captured in 3 locales:
- `en` — English (`en_US`)
- `fr` — French (`fr_FR`)
- `it` — Italian (`it_IT`)

## Simulator and Output

- iPhone 16 Pro Max (`iOS 18.5`) is used by default.
- 6.9-inch App Store format.
- PNG files are grouped by locale and scenario.

## Test hooks

- Uses `SixFourChessAppUITests/ScreenshotTests.swift`.
- `--uitesting` skips splash and consent.
- `--screenshot-scenario <name>` injects a deterministic game state.

## Manual run

```bash
xcodebuild test \
  -project SixFourChessApp.xcodeproj \
  -scheme "SixFourChessApp Dev" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.5" \
  -only-testing:SixFourChessAppUITests/ScreenshotTests \
  -resultBundlePath ./screenshots.xcresult

xcrun xcresulttool export attachments \
  --path screenshots.xcresult \
  --output-path screenshots_export
```

