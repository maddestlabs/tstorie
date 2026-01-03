# The Rebuild Pattern: Script-to-Native Library Development

## Overview

The **Rebuild Pattern** is a development workflow where complex functionality is prototyped in a dynamic scripting environment, then "rebuilt" (exported) as compiled native code that integrates seamlessly back into the library it was built upon.

This creates a **virtuous cycle**: flexible development → optimized production → expanded library → new possibilities.

## Core Concept

```
┌─────────────────────────────────────────────────────────────┐
│                    REBUILD CYCLE                            │
│                                                             │
│  1. SCRIPT                                                  │
│     ↓                                                       │
│     User develops new widget/effect/system using           │
│     library primitives in live scripting environment       │
│     ↓                                                       │
│  2. PERFECT                                                 │
│     ↓                                                       │
│     Iterate rapidly with instant feedback until            │
│     behavior is exactly right                              │
│     ↓                                                       │
│  3. EXPORT                                                  │
│     ↓                                                       │
│     Generate native compiled code from script,             │
│     auto-creates library module with bindings              │
│     ↓                                                       │
│  4. INTEGRATE                                               │
│     ↓                                                       │
│     New compiled module becomes part of library,           │
│     exposed back to scripting via auto-generated wrapper   │
│     ↓                                                       │
│  5. EXPAND                                                  │
│     ↓                                                       │
│     Library grows, enabling even more complex creations    │
│     │                                                       │
│     └──────► Back to step 1 with expanded capabilities     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Why This Pattern Works

### Traditional Approach Problems
- **Compiled-only**: Slow iteration, must recompile to test changes
- **Script-only**: Good for prototyping, but too slow for production
- **Separate implementations**: Maintain two versions (script + compiled)

### Rebuild Pattern Benefits
- ✅ **Rapid prototyping** with scripting
- ✅ **Production performance** from compilation
- ✅ **Single source of truth** - export generates compiled version
- ✅ **Seamless integration** - exported code plugs right back into library
- ✅ **Progressive optimization** - profile, optimize hot paths, re-export
- ✅ **Library evolution** - community contributions compiled and shared

## Ideal Use Cases

The Rebuild Pattern excels when work is:

| Characteristic | Why It Matters |
|----------------|----------------|
| **Iteration-heavy** | Need instant visual feedback to tune behavior |
| **Performance-sensitive** | Want scripting flexibility but need compiled speed |
| **Algorithmically complex** | More than simple glue code |
| **Reusable** | Will be used many times, worth optimizing |
| **Visual/interactive** | Benefit from live development environment |
| **Composable** | Built from primitives, creates new primitives |

### Perfect Fits for tStorie

#### 1. **TUI Widgets** ⭐⭐⭐⭐⭐
**Example:** Slider, TextBox, CheckBox, DatePicker

**Workflow:**
```nim
# 1. SCRIPT (in tui_prototype.md)
var sliderValue = 50.0
var dragging = false

proc drawSlider():
  # Draw slider bar
  var x = 10
  while x < 40:
    draw(0, x, 5, "─", getStyle("border"))
    x = x + 1
  
  # Draw handle
  let handleX = 10 + int(sliderValue / 100.0 * 30.0)
  draw(0, handleX, 5, "O", getStyle("warning"))

proc handleSliderInput():
  if event.type == "mouse" and event.action == "press":
    # Handle mouse interaction...
```

**Exported:** `lib/tui_widgets/slider.nim`
```nim
type Slider* = ref object of Widget
  value*: float
  min*, max*: float
  dragging*: bool

proc render*(w: Slider, layer: int) =
  # Compiled rendering...

proc handleMouse*(w: Slider, event: MouseEvent): bool =
  # Compiled input handling...

# Auto-generated nimini bindings
proc nimini_newSlider*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  let x = args[0].i
  let y = args[1].i
  result = valPointer(cast[pointer](newSlider(x, y)))

registerNative("newSlider", nimini_newSlider,
  storieLibs = @["tui", "tui_widgets"],
  description = "Create new slider widget (compiled)")
```

**Usage after export:**
```nim
# Now 10-100x faster!
let slider = newSlider(10, 5)  # Calls compiled code
```

#### 2. **Terminal Transitions** ⭐⭐⭐⭐⭐
**Example:** Fade, Slide, Wipe, Dissolve (like Python's TerminalTextEffects)

**Workflow:**
```nim
# 1. SCRIPT - Experiment with effect
var progress = 0.0

proc renderMatrixRain(buffer: Buffer, t: float):
  # Tweak characters, colors, timings
  var trails = @[...]
  for trail in trails:
    let alpha = easeOutCubic(t) * (1.0 - trail.age)
    let brightness = int(255.0 * alpha)
    # Draw glowing trail...

# Test with different easing, speeds, colors
# Iterate until it looks perfect
```

**Exported:** `lib/transitions/matrix_rain.nim`
```nim
type MatrixRainTransition* = ref object of Transition
  trails: seq[RainTrail]
  duration: float
  easing: EasingFunc

proc apply*(t: MatrixRainTransition, before, after: BufferSnapshot, 
            progress: float): BufferSnapshot =
  # Compiled, optimized rendering...
```

**Usage:**
```nim
transitionWith(matrixRainEffect(1.5))  # Blazing fast!
```

#### 3. **Particle Systems** ⭐⭐⭐⭐⭐
**Example:** Fire, smoke, rain, snow, explosions, sparkles

**Workflow:**
```nim
# 1. SCRIPT - Design particle behavior
var particles = @[]

proc emitFire():
  var i = 0
  while i < 5:
    particles.add(Particle(
      x: float(emitterX),
      y: float(emitterY),
      vx: randFloat(-2.0, 2.0),
      vy: randFloat(-8.0, -4.0),
      life: randFloat(0.5, 1.5),
      char: pickRandom(["▪", "▫", "·", "˙"])
    ))
    i = i + 1

proc updateParticles(dt: float):
  var i = 0
  while i < len(particles):
    var p = particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + (p.vy + 9.8 * dt) * dt  # Gravity
    p.life = p.life - dt
    
    if p.life <= 0.0:
      delete(particles, i)
    else:
      particles[i] = p
      i = i + 1
```

**Exported:** `lib/particles/fire_emitter.nim`
```nim
type FireEmitter* = ref object of ParticleEmitter
  particles: seq[Particle]
  emitRate: float
  
proc update*(e: FireEmitter, dt: float) =
  # Compiled particle physics - 50-100x faster
  # Can handle 1000+ particles smoothly
```

#### 4. **Audio Synthesizers** ⭐⭐⭐⭐
**Example:** Instrument patches, audio effects chains

**Workflow:**
```nim
# 1. SCRIPT - Design synth interactively
proc synthPatch(freq: float, t: float): float =
  var osc1 = sin(2.0 * PI * freq * t)
  var osc2 = sin(2.0 * PI * freq * 2.01 * t)  # Slight detune
  var mix = osc1 * 0.7 + osc2 * 0.3
  
  # Apply envelope
  var env = 1.0
  if t < 0.1:
    env = t / 0.1  # Attack
  elif t > 0.8:
    env = (1.0 - t) / 0.2  # Release
  
  return mix * env * 0.5
```

**Exported:** `lib/audio/synth_patches/warm_pad.nim`
```nim
proc warmPadPatch*(freq: float, t: float): float {.inline.} =
  # Compiled DSP - real-time audio processing
```

#### 5. **Text Layout Engines** ⭐⭐⭐⭐
**Example:** Justified text, column layout, word wrapping algorithms

**Workflow:**
```nim
# 1. SCRIPT - Experiment with layout algorithm
proc justifyText(text: string, width: int): seq[string] =
  var lines = @[]
  var words = split(text, " ")
  var currentLine = ""
  
  for word in words:
    if len(currentLine) + len(word) + 1 <= width:
      # Add to current line...
    else:
      # Justify current line...
      lines.add(justifyLine(currentLine, width))
      currentLine = word
  
  return lines

proc justifyLine(line: string, width: int): string =
  # Try different justification strategies
  # Experiment with hyphenation, spacing...
```

**Exported:** `lib/layout/justified_text.nim`
```nim
proc justifyText*(text: string, width: int, 
                  hyphenate: bool = true): seq[string] =
  # Compiled text layout - perfect algorithm
```

#### 6. **Procedural Generation** ⭐⭐⭐⭐
**Example:** Dungeon generators, noise functions, L-systems

**Workflow:**
```nim
# 1. SCRIPT - Tune generation parameters live
proc generateDungeon(width: int, height: int, roomCount: int): Grid =
  var rooms = @[]
  var attempts = 0
  
  # Try placing rooms...
  while len(rooms) < roomCount and attempts < 100:
    var room = randomRoom()
    if canPlace(room, rooms):
      rooms.add(room)
    attempts = attempts + 1
  
  # Connect rooms with corridors...
  connectRooms(rooms)
  
  return createGrid(rooms)
```

**Exported:** `lib/procgen/dungeon_generator.nim`
```nim
type DungeonGenerator* = ref object
  config: GeneratorConfig
  
proc generate*(g: DungeonGenerator, seed: int): Grid =
  # Compiled generation - instant results
```

#### 7. **Terminal Shaders** ⭐⭐⭐⭐
**Example:** CRT effects, color grading, bloom, scanlines

**Workflow:**
```nim
# 1. SCRIPT - Design post-processing effect
proc crtEffect(buffer: Buffer, intensity: float):
  var y = 0
  while y < buffer.height:
    var scanlineDim = 1.0
    if y mod 2 == 0:
      scanlineDim = 1.0 - (intensity * 0.3)
    
    var x = 0
    while x < buffer.width:
      var cell = buffer.getCell(x, y)
      var color = cell.style.fg
      
      # Darken for scanline effect
      color.r = int(float(color.r) * scanlineDim)
      color.g = int(float(color.g) * scanlineDim)
      color.b = int(float(color.b) * scanlineDim)
      
      # Add slight RGB shift...
      buffer.setCell(x, y, cell.char, Style(fg: color))
      x = x + 1
    y = y + 1
```

**Exported:** `lib/shaders/crt_effect.nim`
```nim
proc applyCRTEffect*(buffer: var TermBuffer, 
                     intensity: float = 0.5) {.inline.} =
  # Compiled post-processing - 60 FPS on full screen
```

#### 8. **State Machines** ⭐⭐⭐
**Example:** Game AI, UI navigation, menu systems

**Workflow:**
```nim
# 1. SCRIPT - Design state machine
var currentState = "idle"
var states = initTable[string, State]()

states["idle"] = State(
  onEnter: proc(): 
    print("Entering idle state"),
  onUpdate: proc(dt: float):
    if isKeyPressed(32):  # Space
      changeState("jumping"),
  onExit: proc():
    print("Leaving idle state")
)

states["jumping"] = State(
  onEnter: proc():
    velocity = -10.0,
  onUpdate: proc(dt: float):
    velocity = velocity + gravity * dt
    if onGround():
      changeState("idle")
)
```

**Exported:** `lib/fsm/player_controller.nim`
```nim
type PlayerFSM* = ref object of StateMachine
  velocity: float
  
proc update*(fsm: PlayerFSM, dt: float) =
  # Compiled state machine - zero overhead
```

## Implementation Architecture

### Phase 1: Pattern Recognition

Analyze nimini AST to identify exportable patterns:

```nim
proc analyzeForExport*(ast: Program): ExportableModule =
  var module: ExportableModule
  
  # Detect state variables → object fields
  for stmt in ast.stmts:
    if isStateDeclaration(stmt):
      module.fields.add(extractField(stmt))
  
  # Detect render logic → render() method
  for stmt in ast.stmts:
    if isRenderLogic(stmt):
      module.renderCode.add(stmt)
  
  # Detect input handlers → handleKey/handleMouse
  for stmt in ast.stmts:
    if isInputHandler(stmt):
      module.inputHandlers.add(stmt)
  
  return module
```

### Phase 2: Code Generation

Generate native Nim code from analyzed patterns:

```nim
proc generateNativeModule*(module: ExportableModule, 
                           name: string,
                           baseType: string): string =
  result = generateHeader(name)
  result &= generateTypeDecl(name, baseType, module.fields)
  result &= generateConstructor(name, module.fields)
  result &= generateMethods(name, module)
  result &= generateNiminiBindings(name)
```

### Phase 3: Bridge Generation

Auto-create scripting bindings for compiled code:

```nim
proc generateNiminiBindings*(typeName: string): string =
  result = &"""
# Auto-generated nimini bindings for {typeName}

proc nimini_new{typeName}*(env: ref Env; args: seq[Value]): Value {{.nimini.}} =
  let instance = new{typeName}(extractArgs(args))
  return valPointer(cast[pointer](instance))

proc nimini_{typeName}_update*(env: ref Env; args: seq[Value]): Value {{.nimini.}} =
  let instance = cast[ptr {typeName}](args[0].p)
  instance.update(args[1].f)  # dt
  return valNil()

registerNative("new{typeName}", nimini_new{typeName},
  storieLibs = @["exported_modules"],
  description = "Create {typeName} instance (compiled)")
registerNative("{typeName}_update", nimini_{typeName}_update,
  storieLibs = @["exported_modules"],
  description = "Update {typeName} (compiled)")
"""
```

### Phase 4: Library Integration

Exported modules integrate seamlessly:

```
lib/
  exported/               # User-exported modules
    ├── _registry.nim     # Auto-generated index
    ├── slider.nim        # Exported widget
    ├── matrix_rain.nim   # Exported transition
    └── fire_emitter.nim  # Exported particle system
```

Auto-generated registry:

```nim
# lib/exported/_registry.nim (auto-generated)
import slider
import matrix_rain
import fire_emitter

proc registerExportedModules*() =
  # Registers all nimini bindings
  registerSliderBindings()
  registerMatrixRainBindings()
  registerFireEmitterBindings()
```

## CLI Workflow

### Export Command

```bash
# Export a widget from prototype
./ts export-widget tui_prototype.md \
  --name=Slider \
  --base-type=Widget \
  --output=lib/exported/

# Export a transition effect
./ts export-transition matrix_effect.md \
  --name=MatrixRain \
  --output=lib/exported/

# Export a particle system
./ts export-particles fire.md \
  --name=FireEmitter \
  --output=lib/exported/

# Generic export (auto-detects type)
./ts export demo.md --name=MyModule --output=lib/exported/
```

### Export Metadata

Add metadata to markdown for export hints:

```markdown
---
title: "Fire Particle System"
export:
  name: "FireEmitter"
  type: "particle-system"
  base: "ParticleEmitter"
  namespace: "particles"
---

```nim on:init
# This code will be analyzed for export
var particles = @[]
var emitRate = 10.0
```

## Performance Comparison

### Interpreted (Scripting)

```nim
# Running in nimini - ~100,000 ops/sec
proc updateParticles(dt: float):
  var i = 0
  while i < len(particles):
    particles[i].x += particles[i].vx * dt
    particles[i].y += particles[i].vy * dt
    i += 1
```

### Compiled (After Export)

```nim
# Native Nim - ~10,000,000 ops/sec (100x faster)
proc update*(e: FireEmitter, dt: float) =
  for i in 0 ..< e.particles.len:
    e.particles[i].x += e.particles[i].vx * dt
    e.particles[i].y += e.particles[i].vy * dt
```

**Real-world impact:**
- **Interpreted:** 20 particles at 60 FPS
- **Compiled:** 2000 particles at 60 FPS

## Best Practices

### 1. Provide Rich Primitives

Give users powerful building blocks:

```nim
# Compiled primitives (fast foundation)
- draw(layer, x, y, char, style)
- fillRect(layer, x, y, w, h, char, style)
- easeInOutCubic(t: float): float
- lerpColor(c1, c2, t): Color
- Vec2, Vec3 math operations
```

### 2. Design for Export

Structure code with export in mind:

```nim
# ✅ GOOD - Clear state and behavior separation
var position = Vec2(x: 0.0, y: 0.0)
var velocity = Vec2(x: 0.0, y: 0.0)

proc update(dt: float):
  position.x += velocity.x * dt
  position.y += velocity.y * dt

proc render():
  draw(0, int(position.x), int(position.y), "@", defaultStyle())

# ❌ BAD - Mixed concerns, hard to export
var x = 0.0
var vx = 0.0
draw(0, int(x), 0, "@", defaultStyle())
x += vx * deltaTime
```

### 3. Use Type Hints (Future)

Help the exporter understand intent:

```nim
# Type hints for better export quality
var particles: seq[Particle] = @[]  # Knows it's Particle sequence
var count: int = 0                  # Knows it's integer
var speed: float = 5.0              # Knows it's float
```

### 4. Document Exported APIs

Auto-generate docs from exports:

```nim
# Generated from export metadata
## FireEmitter
##
## A compiled particle emitter that creates realistic fire effects.
## 
## **Performance:** Can handle 1000+ particles at 60 FPS
## 
## **Usage:**
## ```nim
## let fire = newFireEmitter(x, y)
## fire.emitRate = 20.0
## fire.update(deltaTime)
## ```
```

## Ecosystem Benefits

### Community Contributions

Users can share compiled modules:

```nim
# User develops amazing transition effect
# Exports and shares on GitHub

# Others can install it:
git clone https://github.com/user/awesome-transition
cp awesome-transition.nim lib/exported/

# Now available to everyone:
let trans = awesomeTransition(duration = 1.0)
```

### Progressive Enhancement

Library grows organically:

```
Year 1: Core primitives + 5 built-in effects
Year 2: + 20 community-contributed effects (all compiled)
Year 3: + 50 effects, widgets, systems
Year 4: Robust ecosystem of reusable components
```

### Version Evolution

Track performance improvements:

```
v1.0 - Interpreted only
v1.1 - Export system added
v2.0 - 10 compiled effects (100x faster)
v3.0 - 50 compiled modules
v4.0 - Full ecosystem of optimized components
```

## Related Patterns

### Shader Development (Graphics)
GLSL editors → compiled GPU shaders (exact same workflow!)

### JIT Compilation
Hot paths detected and compiled (automated version of this)

### Partial Evaluation
Specializing general code with known parameters

### Meta-Circular Evaluation
Interpreters written in themselves, compiled for performance

### Gradual Typing
TypeScript/Python: start dynamic, add types for optimization

## Future Enhancements

### Auto-Optimization

Detect hot paths automatically:

```nim
# Runtime profiler notices updateParticles is slow
# Suggests: "This function is called 1000x/frame. Export for 100x speedup?"
./ts export --auto-optimize demo.md
```

### Type Inference

Infer types from usage:

```nim
var count = 0           # Inferred: int
var speed = 5.0         # Inferred: float
var particles = @[]     # Inferred: seq[???]
particles.add(particle) # Ah! seq[Particle]
```

### Hybrid Execution

Mix interpreted and compiled:

```nim
# Critical path compiled
let compiled = newSliderCompiled(x, y)

# Custom logic still scripted
proc onSliderChange(value: float):
  # User-defined callback (interpreted)
  print("Value: " & str(value))

compiled.onChange = onSliderChange
```

### Web Export

Export to JavaScript for web builds:

```bash
./ts export widget.md --target=javascript --output=web/
```

## Conclusion

The **Rebuild Pattern** creates a powerful development experience:

1. **Prototype** with flexible scripting and instant feedback
2. **Perfect** the behavior through rapid iteration
3. **Export** to compiled code with one command
4. **Integrate** seamlessly back into the library
5. **Share** with the community as optimized modules

This workflow enables:
- 🚀 **Fast development** (scripting)
- ⚡ **Fast execution** (compiled)
- 🔄 **Continuous improvement** (re-export as needed)
- 🌍 **Community growth** (share compiled modules)
- 📈 **Progressive performance** (optimize incrementally)

The result is a **living library** that grows stronger with every contribution, maintaining the flexibility of scripting while achieving the performance of compiled code.

**The best of both worlds: script to create, compile to deliver.**
