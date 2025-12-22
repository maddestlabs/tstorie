# Transitions System

The transitions module provides smooth visual transitions between terminal buffer states. It's a standalone system that works with raw `TermBuffer` objects and requires no dependencies on section_manager or canvas modules.

## Core Concepts

### BufferSnapshot
A captured snapshot of a terminal buffer state. Contains all cells (characters + styles) at a specific moment in time.

### TransitionEffect
Defines how a transition should occur:
- **Effect type** (fade, slide, wipe, dissolve, push)
- **Duration** (in seconds)
- **Easing function** (timing curve)
- **Direction** (for directional effects)
- **Region** (optional: transition only part of screen)

### TransitionEngine
Manages multiple concurrent transitions and handles updating them over time.

## Basic Usage

```nim
import lib/transitions

# Create engine
var transEngine = newTransitionEngine()

# Capture before state
let beforeBuffer = captureCurrentState()

# Make changes (render new content)
renderNewContent()

# Capture after state
let afterBuffer = captureCurrentState()

# Start transition
transEngine.startTransition(
  beforeBuffer, 
  afterBuffer, 
  fadeEffect(0.5)  # 0.5 second fade
)

# In main loop
transEngine.update(deltaTime)
if transEngine.hasActiveTransitions():
  let transBuffer = transEngine.getTransitionBuffer()
  renderBuffer(transBuffer)
```

## Available Effects

### Fade
Smoothly blends colors between states, switches characters at midpoint.

```nim
fadeEffect(duration = 0.5, easing = easeInOutQuad)
```

### Slide
Old content slides out while new content slides in.

```nim
slideEffect(
  duration = 0.8,
  direction = tdLeft,  # tdLeft, tdRight, tdUp, tdDown
  easing = easeInOutCubic
)
```

### Wipe
New content progressively reveals, replacing old content.

```nim
wipeEffect(
  duration = 0.7,
  direction = tdLeft,  # tdLeft, tdRight, tdUp, tdDown, tdCenter
  easing = easeLinear
)
```

### Dissolve
Pixelated/random dissolve between states.

```nim
dissolveEffect(
  duration = 0.8,
  blockSize = 2,
  easing = easeInOutQuad
)
```

### Push
Both buffers move together (old pushes out, new pushes in).

```nim
pushEffect(
  duration = 0.8,
  direction = tdLeft,
  easing = easeInOutCubic
)
```

## Regional Transitions

Transition only a specific area of the screen:

```nim
let effect = regionalEffect(
  fadeEffect(0.5),
  x = 10, y = 5,
  width = 40, height = 15
)

transEngine.startTransition(before, after, effect)
```

Use cases:
- Update a panel while keeping rest of screen static
- Transition individual UI components
- Create split-screen effects

## Event System

Register callbacks for transition lifecycle events:

```nim
# Per-transition callback
let trans = transEngine.startTransition(before, after, fadeEffect(0.5))
trans.registerCallback(teStart) do (t: Transition, progress: float):
  echo "Transition started!"

trans.registerCallback(teComplete) do (t: Transition, progress: float):
  echo "Transition complete!"

# Global callbacks (all transitions)
transEngine.registerGlobalCallback(teProgress) do (t: Transition, progress: float):
  updateProgressBar(progress)
```

### Available Events
- `teBeforeStart` - Before transition begins
- `teStart` - Transition starts
- `teProgress` - Each frame during transition (most common)
- `teComplete` - Transition finished
- `teCanceled` - Transition interrupted

## Easing Functions

Control the timing/feel of transitions:

- `easeLinear` - Constant speed
- `easeInQuad`, `easeOutQuad`, `easeInOutQuad` - Quadratic curves
- `easeInCubic`, `easeOutCubic`, `easeInOutCubic` - Cubic curves
- `easeInSine`, `easeOutSine`, `easeInOutSine` - Sinusoidal curves

**Tip**: Use `easeInOutCubic` for smooth, professional-feeling transitions.

## Advanced: Creating Custom Effects

Extend the system with your own effects:

```nim
proc myCustomEffect(duration: float): TransitionEffect =
  TransitionEffect(
    name: "custom",
    duration: duration,
    easing: easeLinear,
    direction: tdNone,
    region: TransitionRegion(x: 0, y: 0, width: 0, height: 0),
    params: initTable[string, float]()
  )

# Implement effect in applyTransition:
# case trans.effect.name
# of "custom": return applyMyCustomEffect(trans)
```

## Integration Examples

### With Section Navigation

```nim
# Transition between markdown sections
proc navigateToSectionWithTransition(targetIdx: int) =
  let beforeBuf = captureCurrentSection()
  currentSectionIdx = targetIdx
  renderCurrentSection()
  let afterBuf = captureCurrentSection()
  
  transEngine.startTransition(beforeBuf, afterBuf, slideEffect(0.5, tdLeft))
```

### With Canvas Panning

```nim
# Smooth camera transition
proc panCameraWithTransition(newX, newY: float) =
  let beforeBuf = captureCanvasView()
  camera.x = newX
  camera.y = newY
  renderCanvasView()
  let afterBuf = captureCanvasView()
  
  transEngine.startTransition(beforeBuf, afterBuf, fadeEffect(0.3))
```

### With TUI Widgets (Coming Soon)

```nim
# Panel slide-in
proc showPanel(panel: Widget) =
  let beforeBuf = captureWidgetArea(panel)
  panel.visible = true
  renderWidget(panel)
  let afterBuf = captureWidgetArea(panel)
  
  transEngine.startTransition(
    beforeBuf, 
    afterBuf, 
    regionalEffect(
      slideEffect(0.4, tdRight),
      panel.x, panel.y, panel.width, panel.height
    )
  )
```

## Performance Tips

1. **Pre-render offscreen**: Render next state to offscreen buffer before starting transition
2. **Limit regions**: Use regional transitions for partial updates
3. **Choose appropriate durations**: 0.3-0.5s feels snappy, 0.8-1.2s feels smooth
4. **Avoid overlapping transitions**: Complete one before starting another in same region
5. **Profile effects**: Dissolve is more expensive than fade/slide

## Architecture Notes

The transitions system is **completely decoupled** from other TStorie systems:

- ✅ No dependency on section_manager
- ✅ No dependency on canvas
- ✅ Works with raw buffers only
- ✅ Optional integration layers can be added separately

This means you can:
- Use transitions without sections
- Use sections without transitions  
- Mix and match as needed
- Build custom integrations

## Next Steps

The transitions system is designed as a foundation for:
- TUI widget library (with built-in transition support)
- Section transition integration layer
- Canvas transition effects
- Custom animation systems

See `examples/transitions_demo.md` for a working demonstration.
