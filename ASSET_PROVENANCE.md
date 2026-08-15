# Asset provenance

This register documents assets distributed in the repository and their licensing basis.

| Asset | Location | Provenance | License |
| --- | --- | --- | --- |
| NNUE Core ML model | `SixFourChess/SixFourChess/Resources/nnue.mlmodelc` | Generated artifact. Its training/export pipeline is versioned in `SixFourChess/scripts/prepare_nnue.py`; that pipeline generates synthetic positions and heuristic labels locally and does not download weights or a dataset. | MIT (repository license) |
| Opening book | `SixFourChess/SixFourChess/Resources/opening_book.bin` | Generated from the in-repository `OPENING_TREE` in `SixFourChess/scripts/generate_opening_book.py`. | MIT (repository license) |
| App icons and SixFour logo | `SixFourChess/SixFourChess/Assets.xcassets` | Project artwork committed directly to this repository; no external upstream source is recorded in the asset metadata. | MIT (repository license) |

Before adding or replacing an asset, contributors must record its source, copyright holder, and license in this file. Do not add assets whose redistribution terms are unknown or incompatible with the repository license.
