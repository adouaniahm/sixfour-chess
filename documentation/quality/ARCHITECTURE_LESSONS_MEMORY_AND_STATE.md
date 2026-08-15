# Architecture Retrospective: Memory Safety & State Management
**Date:** November 30, 2025
**Context:** Swift, SwiftUI, Redux, Chess Engine

This document outlines critical architectural lessons learned from resolving `SIGABRT` crashes and `malloc` errors during the development of the Chess Engine and Redux State management.

---

## 1. The Simulation Crash (Heap Corruption)

### The Scenario
The crash occurred inside `MoveGenerator.generateLegalMoves`. To validate if a move is legal (i.e., does not leave the King in check), the engine needs to:
1. Take the current board.
2. Create a temporary copy.
3. Apply the move on the copy.
4. Check for threats.

### The Error
```text
malloc: *** error for object 0x...: pointer being freed was not allocated
SIGABRT
```

### The Root Cause
**Manual Class Copying.**
The `ChessBoard` was a `class` (Reference Type). To simulate moves, we used a manual `.copy()` method to deep-copy the arrays and internal objects.
- **Complexity:** Copying a complex object graph manually is error-prone.
- **Performance:** Allocating new Heap objects (classes) for thousands of simulated moves creates immense pressure on the memory allocator.
- **Safety:** A flaw in the manual copy logic or a race condition resulted in "Double Free" errors (trying to free memory that was already freed).

### The Solution: Value Semantics (Structs)
We introduced `ChessState`, a `struct` (Value Type), to hold the raw data.
- **Mechanism:** In Swift, assigning a struct to a new variable (`var testState = state`) automatically creates a copy.
- **Copy-on-Write (COW):** Swift optimizes this. The data isn't actually copied until it is modified.
- **Outcome:** We removed the manual `.copy()` method entirely. The `MoveGenerator` now operates on `ChessState` structs. This moved the heavy lifting from the Heap to the Stack (mostly), eliminating the memory corruption bugs.

---

## 2. The Lifecycle Crash (Observable Identity)

### The Scenario
The crash occurred during `resetGame`, `newGame`, or when receiving an update from the Online Middleware.
```swift
// Old Redux Reducer Logic
case .resetGame:
    state.board = ChessBoard() // Replaces the instance
```

### The Error
```text
ChessBoard.__deallocating_deinit
SIGABRT
```

### The Root Cause
**Destabilizing Observable Identity.**
`ChessBoard` is an `@Observable` class observed by SwiftUI views.
1. The Redux reducer replaced the `state.board` instance with a new one.
2. The old instance was immediately deallocated.
3. However, SwiftUI (or an async test/process) might still have held a weak reference to the old instance to complete a render frame or calculation.
4. Accessing the deallocated instance caused a crash.

### The Solution: Stable Identity
We stopped replacing the `ChessBoard` instance. Instead, we mutate its internal state.
```swift
// New Redux Reducer Logic
case .resetGame:
    state.board.state = ChessState() // Updates data, keeps instance alive
```
- **Stability:** The `ChessBoard` instance wrapper remains in memory throughout the game's lifecycle.
- **Reactivity:** SwiftUI detects the change in the `.state` property and updates the UI smoothly without losing the observation subscription.

---

## Summary of Lessons

### 1. Use Structs for High-Frequency Simulation
For game engines or heavy logic requiring temporary states (like "what if" scenarios), always use **Structs**. Do not use Classes with manual clone methods.
- **Rule:** If you need to copy it 1000 times a second, it must be a Struct.

### 2. Preserve Identity in SwiftUI/Redux
When integrating Redux with SwiftUI's `@Observable`:
- **Rule:** Avoid `state.object = NewObject()`.
- **Preferred:** `state.object.properties = newValues`.
Keeping the reference stable prevents race conditions between the Logic Layer (Redux) and the Presentation Layer (SwiftUI).

### 3. Isolate Data from Behavior
Separating `ChessState` (Pure Data, Struct) from `ChessBoard` (Observable Wrapper, Class) provided the best of both worlds:
- **ChessState:** Safe, fast, value-type logic for the Engine.
- **ChessBoard:** Stable, observable reference for the UI.
