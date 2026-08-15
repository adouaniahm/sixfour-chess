# Chess Bot Architecture

This document describes the chess AI architecture, its evolution, and future improvement paths.

## Version 1.0 & 1.1 (Initial Implementation)

The first implementation was based on a **Negamax** search algorithm, a variant of Minimax.

### Characteristics
- **Algorithm**: Negamax search with Alpha-Beta pruning.
- **Depth**: Difficulty was directly tied to search depth (`maxDepth`).
- **Evaluation**: The evaluation function was basic, based on material value and Piece-Square Tables for pawns, knights, and king.
- **Cache**: A cache (`evaluationCache`) existed but was cleared on every move, making it ineffective for reuse between turns.

### Limitations
1.  **Severe deep-search slowness**: Without an effective transposition table, the engine re-evaluated millions of identical positions, making high difficulties very slow.
2.  **Repetitiveness**: Missing memoization and a simple search strategy could lead to repetitive play patterns.
3.  **High memory usage**: The engine created a full board copy (`board.copy()`) for each explored node, which was expensive.

---

## Version 2.0 (Search Optimizations)

Version 2.0 introduced two major optimizations inspired by production engines.

### 1. Transposition Table (Effective Cache)
`evaluationCache` is now used as a true **transposition table**.

- **Change**: The cache is no longer cleared after each move. Position evaluations are kept for the entire game.
- **Behavior**: Before evaluating a node in `negamax`, the engine checks cache first. If a result exists, it reuses that score. Each position gets a unique key from its FEN (`toFEN()`).
- **Benefit**: Huge reduction in repeated computation; whole branches are skipped when already fully evaluated.

### 2. Iterative Deepening Search
The search loop now uses **iterative deepening**.

- **Change**: Instead of jumping directly to max depth (for example 5), the engine searches depth 1, then 2, then 3, etc.
- **Behavior**: The best move found at depth `N` is used to order moves at `N+1`, which strengthens Alpha-Beta pruning.
- **Benefit**: Major performance gains in expert mode; it still finds strong moves faster.

### Result of v2.0
The engine is now faster and less repetitive at high levels while preserving expected strength per difficulty.

---

## Later Versions (Future Improvements)

Multiple improvement areas are planned.

### 1. NNUE Model Evolution
The engine already integrates the bundled Core ML model through `NNUEEvaluator`.

- **Concept**: Improve and retrain the NNUE model used to score position quality.
- **Architecture**: Keep `negamax` as the controller and continue evaluating leaf positions locally through Core ML.
- **Benefits**:
    - Better strategic understanding (king safety, position, initiative).
    - Less mechanical style, more human-like flow.
    - Potential Elo gains beyond hand-tuned evaluation.

### 2. Cloud AI Evaluation
For stronger AI, evaluation can be moved to a backend service.

- **Concept**: Instead of an on-device Core ML model, send the current FEN to an HTTP service. The server runs a heavier model (TensorFlow, PyTorch) and returns a score.
- **Advantages**:
    - Access to larger and more accurate models.
    - AI updates happen server-side without shipping a full app update.
- **Trade-offs**:
    - Requires network.
    - Adds inference latency.
    - Adds hosting and compute cost.

### 3. Fine Search Optimizations
- **Make/Unmake Move**: Replace full-board copying with `makeMove()` / `unmakeMove()` transitions. This is the largest raw-speed improvement.
- **Pruning enhancements**: Add techniques such as *Late Move Reductions (LMR)* for quiet moves.
- **Pondering**: Let AI think during the opponent's turn to reduce perceived latency when the engine replies.
