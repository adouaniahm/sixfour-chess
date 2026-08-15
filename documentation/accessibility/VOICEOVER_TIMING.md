# VoiceOver Timing Guide

VoiceOver delays are required so announcements remain understandable and do not overlap.

## Recommended delays

| Situation | Delay | Why |
|---|---:|---|
| State readout after action | `0.05s` | Wait for state updates from reducers |
| Move announcements | `0.30s` | Let VoiceOver queue the baseline announcement |
| Undo announcements | `0.30s` | After state update |
| Available moves after selection | `0.50s` | Wait for board-cell label to be spoken |
| End-of-game summary | `0.70s` | Allow UI to stabilize |
| End-of-game result | `0.50s` | Result label needs a stable render |
| AI announcement delay when VoiceOver is running | `2.0s` | Ensure existing announcements are finished |

## Implementation patterns

### Standard 300 ms delay

```swift
Task {
    await Task.sleep(for: .milliseconds(300))
    AccessibilityService.shared.announce(message: "Best move found")
}
```

### State update delay (50 ms)

```swift
store.dispatch(.didSelectSquare(position))
Task {
    await Task.sleep(for: .milliseconds(50))
    let newState = store.state
    AccessibilityService.shared.announce(message: newState.board.summary)
}
```

### AI delay

```swift
if AccessibilityService.shared.isEnabled {
    Task {
        await Task.sleep(for: .seconds(2))
        announceAIResult()
    }
} else {
    announceAIResult()
}
```

## Why these delays

Without a short delay, announcements can interrupt each other.
Common timeline:

1. User action.
2. Reducer updates state synchronously.
3. App sends one or more announcements quickly.
4. VoiceOver is still finishing prior speech.
5. Overlapping speech becomes unreadable.

Delays separate these stages so each announcement is coherent.

## Common mistakes

- No delay at all between reducer update and announcement.
- Very short delay with fast successive announcements.
- Emitting multiple announcements for one event.

Preferred pattern: one concise announcement per event.

## Runtime check

```swift
let isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
```

If VoiceOver is enabled, prefer longer grouped announcements and small delays between dependent UI updates.

## Summary

1. Use short delays for state reads after dispatch.
2. Use a 300 ms delay for general game announcements.
3. Use 500 ms after piece selection before listing moves.
4. Use 2 seconds for AI speech coordination when VoiceOver is active.
5. Avoid multiple overlapping announcements.
