# Transitions Quick Reference

## Setup

```nim
import lib/transitions

var transEngine = newTransitionEngine()
```

## Basic Transition

```nim
let before = captureBuffer()
# ... make changes ...
let after = captureBuffer()

transEngine.startTransition(before, after, fadeEffect(0.5))

# In loop:
transEngine.update(deltaTime)
if transEngine.hasActiveTransitions():
  let buf = transEngine.getTransitionBuffer()
  renderBuffer(buf)
```

## Effect Quick List

| Effect | Code | Best For |
|--------|------|----------|
| **Fade** | `fadeEffect(0.5)` | Subtle transitions, color changes |
| **Slide Left** | `slideEffect(0.8, tdLeft)` | Page navigation, moving forward |
| **Slide Right** | `slideEffect(0.8, tdRight)` | Going back, undo |
| **Slide Up** | `slideEffect(0.8, tdUp)` | Scrolling, dropdown menus |
| **Slide Down** | `slideEffect(0.8, tdDown)` | Expansion, reveals |
| **Wipe** | `wipeEffect(0.7, tdLeft)` | Clean reveal, presentations |
| **Wipe Center** | `wipeEffect(1.0, tdCenter)` | Focus attention, dramatic |
| **Dissolve** | `dissolveEffect(1.0)` | Scramble, digital effect |
| **Push** | `pushEffect(0.8, tdLeft)` | Screen replacement |

## Regional Transitions

```nim
# Transition only a specific area
let effect = regionalEffect(
  fadeEffect(0.5),
  x = 10, y = 5,
  width = 40, height = 15
)
```

## Event Callbacks

```nim
# On completion
trans.registerCallback(teComplete) do (t: Transition, p: float):
  onTransitionDone()

# Track progress
trans.registerCallback(teProgress) do (t: Transition, p: float):
  updateProgressBar(p)
```

## Common Patterns

### Section Navigation
```nim
proc gotoSectionWithTrans(idx: int) =
  let before = captureSection(currentIdx)
  currentIdx = idx
  let after = captureSection(currentIdx)
  transEngine.startTransition(before, after, slideEffect(0.5, tdLeft))
```

### Panel Toggle
```nim
proc togglePanel(panel: Panel) =
  let before = captureRegion(panel.region)
  panel.visible = not panel.visible
  let after = captureRegion(panel.region)
  let effect = regionalEffect(
    fadeEffect(0.3),
    panel.x, panel.y, panel.width, panel.height
  )
  transEngine.startTransition(before, after, effect)
```

### Canvas Pan
```nim
proc panTo(newX, newY: float) =
  let before = captureCanvas()
  camera.x = newX
  camera.y = newY
  let after = captureCanvas()
  transEngine.startTransition(before, after, fadeEffect(0.3))
```

## Timing Guidelines

| Duration | Feel | Use For |
|----------|------|---------|
| 0.2-0.3s | Snappy | Button clicks, toggles |
| 0.4-0.5s | Responsive | Navigation, menus |
| 0.6-0.8s | Smooth | Content transitions |
| 1.0-1.5s | Dramatic | Full screen changes |

## Easing Quick Pick

- **easeInOutCubic** - Default choice, smooth and professional
- **easeOutQuad** - Quick start, gentle finish (good for appearing)
- **easeInQuad** - Gentle start, quick finish (good for disappearing)
- **easeLinear** - Constant speed (wipes, scrolling)
- **easeInOutSine** - Very smooth, organic feel

## Direction Constants

```nim
tdNone     # No direction
tdLeft     # Move/wipe left ←
tdRight    # Move/wipe right →
tdUp       # Move/wipe up ↑
tdDown     # Move/wipe down ↓
tdCenter   # From/to center ●
tdRandom   # Random/dissolve
```

## Event Types

```nim
teBeforeStart  # Before transition begins
teStart        # Transition starts
teProgress     # Each frame (use for progress bars)
teComplete     # Transition finished
teCanceled     # Transition interrupted
```

## Cancel Transition

```nim
transEngine.cancelTransition(trans)
```

## Check Status

```nim
if transEngine.hasActiveTransitions():
  # Still transitioning
else:
  # Can start new transition
```

## Custom Effect Template

```nim
proc myEffect(duration: float): TransitionEffect =
  TransitionEffect(
    name: "myeffect",
    duration: duration,
    easing: easeInOutQuad,
    direction: tdNone,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: {"speed": 1.0}.toTable
  )
```
