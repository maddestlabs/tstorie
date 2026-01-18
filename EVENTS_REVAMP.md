# Event Handling Revamp & SDL3 Integration Plan

**Status:** Proposal  
**Date:** January 18, 2026  
**Goal:** Design event system that works for both tstorie (terminal) and Storie (SDL3 graphical)

---

## Executive Summary

TStorie's current event system uses raw keyCodes and string-based button names, requiring manual translation in every demo. This document proposes a unified event API inspired by SDL3 that works seamlessly across terminal and graphical implementations.

**Key Recommendations:**
1. ✅ Add named key constants matching SDL3's scancode/keycode system
2. ✅ Provide both low-level (keyCode) and high-level (key name) APIs
3. ✅ Create abstract event layer that SDL3 can directly plug into
4. ✅ Keep terminal-specific features but design for future expansion

---

## Current State Analysis

### What We Have (Terminal/Web)

```nim
# In demos - manual translation required
if event.type == "key":
  if event.keyCode == 1000:  # Magic number
    keyStr = "Up"
  elif event.keyCode == 27:  # What key is this?
    keyStr = "Escape"

if event.type == "mouse":
  if event.button == "left":  # String comparison
    buttonInt = 1  # Convert to int
```

### Problems

1. **Magic Numbers** - `1000` for Up arrow, `27` for Escape - unreadable
2. **Inconsistent Types** - Mouse uses strings ("left"), keys use ints (1000)
3. **Manual Translation** - Every demo converts keyCodes to names
4. **No Key Constants** - Can't use `KEY_ESCAPE` or `KEY_UP`
5. **Terminal-Specific** - Custom keyCode scheme doesn't match any standard

---

## SDL3 Event System Overview

SDL3 (the future graphical backend) has a robust, battle-tested event system:

### SDL3 Key Events

```c
// SDL3 provides TWO key representations:

// 1. Scancode - Physical key position (hardware)
//    Platform-independent, based on USB HID spec
SDL_Scancode scancode = event.key.scancode;
if (scancode == SDL_SCANCODE_ESCAPE) { ... }

// 2. Keycode - Logical key meaning (software)
//    Respects keyboard layout (QWERTY vs AZERTY)
SDL_Keycode keycode = event.key.key;
if (keycode == SDLK_ESCAPE) { ... }

// SDL3 also provides modifiers
if (event.key.mod & SDL_KMOD_SHIFT) { ... }
```

### SDL3 Mouse Events

```c
// Mouse buttons as enum/constants
if (event.button.button == SDL_BUTTON_LEFT) { ... }
if (event.button.button == SDL_BUTTON_MIDDLE) { ... }
if (event.button.button == SDL_BUTTON_RIGHT) { ... }

// Mouse position
int x = event.motion.x;
int y = event.motion.y;

// Mouse state queries
Uint32 buttons = SDL_GetMouseState(&x, &y);
if (buttons & SDL_BUTTON_LMASK) { ... }
```

### SDL3 Multi-Touch (for Storie's future)

```c
// Touch events for mobile/tablets
SDL_TouchFingerEvent finger = event.tfinger;
float x = finger.x;  // Normalized 0.0-1.0
float y = finger.y;
float pressure = finger.pressure;

// Gesture events
SDL_MultiGestureEvent gesture = event.mgesture;
float rotation = gesture.dTheta;
float pinch = gesture.dDist;
```

---

## Proposed Solution: Unified Event API

### Design Goals

1. **Source Compatibility** - Existing demos work with minimal changes
2. **SDL3 Ready** - Event structure maps directly to SDL3 events
3. **Human Readable** - Named constants, not magic numbers
4. **Type Safe** - Enums/constants instead of strings
5. **Progressive** - Can use low-level or high-level APIs

### Event Structure (Nim)

```nim
type
  KeyCode* = distinct int
    ## Logical key (respects keyboard layout)
  
  ScanCode* = distinct int
    ## Physical key position (layout-independent)
  
  MouseButton* = enum
    mbNone = 0
    mbLeft = 1
    mbMiddle = 2
    mbRight = 3
    mbX1 = 4  # Extra mouse buttons
    mbX2 = 5
  
  KeyMod* = enum
    kmShift = 1 shl 0
    kmCtrl = 1 shl 1
    kmAlt = 1 shl 2
    kmSuper = 1 shl 3
    kmCapsLock = 1 shl 8
    kmNumLock = 1 shl 9
  
  EventType* = enum
    etNone
    etKeyDown
    etKeyUp
    etTextInput      # Separate from key events (important!)
    etMouseMotion
    etMouseButtonDown
    etMouseButtonUp
    etMouseWheel
    etTouchFingerDown    # Future: for Storie
    etTouchFingerUp
    etTouchFingerMotion
    etMultiGesture       # Future: pinch, rotate
  
  Event* = object
    timestamp*: float  # Time since app start
    case kind*: EventType
    of etKeyDown, etKeyUp:
      keyCode*: KeyCode
      scanCode*: ScanCode
      keyMod*: set[KeyMod]
      repeat*: bool  # Key repeat?
    of etTextInput:
      text*: string  # UTF-8 text
    of etMouseMotion:
      mouseX*, mouseY*: int
      mouseDX*, mouseDY*: int  # Delta from last position
      mouseState*: set[MouseButton]
    of etMouseButtonDown, etMouseButtonUp:
      button*: MouseButton
      buttonX*, buttonY*: int
      clicks*: int  # 1=single, 2=double, etc.
    of etMouseWheel:
      wheelX*, wheelY*: float
      wheelDirection*: int  # 1=normal, -1=flipped
    of etTouchFingerDown, etTouchFingerUp, etTouchFingerMotion:
      touchId*: int64
      fingerId*: int64
      fingerX*, fingerY*: float  # Normalized 0.0-1.0
      fingerDX*, fingerDY*: float
      pressure*: float
    of etMultiGesture:
      gestureX*, gestureY*: float
      gestureDTheta*: float  # Rotation
      gestureDDist*: float   # Pinch
      gestureNumFingers*: int
    else:
      discard
```

### Key Constants (SDL3-Compatible)

```nim
# Based on USB HID Usage Tables and SDL3 scancodes
const
  # Special keys
  SC_ESCAPE* = ScanCode(41)
  SC_RETURN* = ScanCode(40)
  SC_BACKSPACE* = ScanCode(42)
  SC_TAB* = ScanCode(43)
  SC_SPACE* = ScanCode(44)
  
  # Arrow keys (match SDL3)
  SC_RIGHT* = ScanCode(79)
  SC_LEFT* = ScanCode(80)
  SC_DOWN* = ScanCode(81)
  SC_UP* = ScanCode(82)
  
  # Function keys
  SC_F1* = ScanCode(58)
  SC_F2* = ScanCode(59)
  # ... F3-F12
  
  # Letters (physical position)
  SC_A* = ScanCode(4)
  SC_B* = ScanCode(5)
  # ... rest of alphabet

# Logical keycodes (respects layout)
const
  KEY_ESCAPE* = KeyCode(27)
  KEY_RETURN* = KeyCode(13)
  KEY_BACKSPACE* = KeyCode(8)
  KEY_TAB* = KeyCode(9)
  KEY_SPACE* = KeyCode(32)
  
  # Arrow keys (terminal custom range, maps to SDL3 at runtime)
  KEY_UP* = KeyCode(1000)
  KEY_DOWN* = KeyCode(1001)
  KEY_LEFT* = KeyCode(1002)
  KEY_RIGHT* = KeyCode(1003)
  
  # Function keys
  KEY_F1* = KeyCode(1100)
  KEY_F2* = KeyCode(1101)
  # ... F3-F12
  
  # Printable ASCII
  KEY_A* = KeyCode(ord('A'))
  KEY_a* = KeyCode(ord('a'))
  # etc.
```

---

## Usage Examples

### Before (Current System)

```nim
# Ugly, error-prone
if event.type == "key":
  if event.keyCode == 1000:  # What key?
    echo "Up pressed"
  elif event.keyCode == 27:  # What key?
    echo "Escape pressed"

if event.type == "mouse":
  if event.button == "left":  # String comparison
    echo "Left clicked"
```

### After (Proposed System)

```nim
# Clean, readable
if event.kind == etKeyDown:
  if event.keyCode == KEY_UP:
    echo "Up pressed"
  elif event.keyCode == KEY_ESCAPE:
    echo "Escape pressed"
  
  # Can also check scancode for physical position
  if event.scanCode == SC_W:
    echo "W key (physical position) pressed"

if event.kind == etMouseButtonDown:
  if event.button == mbLeft:
    echo "Left clicked at ", event.buttonX, ", ", event.buttonY
  
  # Multi-click detection
  if event.clicks == 2:
    echo "Double-click!"
```

### Backward Compatibility Layer

```nim
# For existing demos - provide helper that converts new to old format
proc toLegacyEvent(event: Event): LegacyEvent =
  result = LegacyEvent()
  case event.kind
  of etKeyDown:
    result.type = "key"
    result.action = "press"
    result.keyCode = event.keyCode.int
  of etMouseButtonDown:
    result.type = "mouse"
    result.action = "press"
    result.button = case event.button
      of mbLeft: "left"
      of mbMiddle: "middle"
      of mbRight: "right"
      else: "unknown"
    result.x = event.buttonX
    result.y = event.buttonY
  # etc.
```

---

## SDL3 Integration Strategy

### Terminal Implementation (Current - tstorie)

```nim
# In JavaScript terminal emulator (tstorie.js)
document.addEventListener('keydown', (e) => {
  const event = {
    kind: 'etKeyDown',
    keyCode: mapWebKeyToKeyCode(e.key, e.keyCode),
    scanCode: mapWebKeyToScanCode(e.code),
    keyMod: getModifiers(e),
    repeat: e.repeat,
    timestamp: performance.now() / 1000.0
  };
  sendEventToWasm(event);
});
```

### SDL3 Implementation (Future - Storie)

```nim
# In SDL3 backend - nearly 1:1 mapping!
proc pollSDL3Event(): Option[Event] =
  var sdlEvent: SDL_Event
  if SDL_PollEvent(addr sdlEvent) == 0:
    return none(Event)
  
  var event: Event
  case sdlEvent.type
  of SDL_EVENT_KEY_DOWN:
    event = Event(
      kind: etKeyDown,
      keyCode: KeyCode(sdlEvent.key.key),  # Direct cast
      scanCode: ScanCode(sdlEvent.key.scancode),
      keyMod: convertSDLMods(sdlEvent.key.mod),
      repeat: sdlEvent.key.repeat,
      timestamp: sdlEvent.common.timestamp / 1000.0
    )
  of SDL_EVENT_MOUSE_BUTTON_DOWN:
    event = Event(
      kind: etMouseButtonDown,
      button: MouseButton(sdlEvent.button.button),  # Direct cast
      buttonX: sdlEvent.button.x,
      buttonY: sdlEvent.button.y,
      clicks: sdlEvent.button.clicks,
      timestamp: sdlEvent.common.timestamp / 1000.0
    )
  # etc. - minimal glue needed!
  
  return some(event)
```

**Key Insight:** With proper event design, SDL3 integration is trivial - just cast enums and copy values. No complex translation needed!

---

## Multi-Touch Considerations

### Terminal (tstorie) - Limited Support

- **Mouse only** - Terminal emulators don't expose touch events
- **Can simulate** - Map touch to mouse for basic interaction
- **Long-press** - Implemented via time-based detection (works!)

### SDL3 (Storie) - Full Support

```nim
# Future: Native multi-touch in Storie
if event.kind == etTouchFingerDown:
  # Pinch to zoom
  if event.gestureNumFingers == 2:
    zoom += event.gestureDDist
  
  # Rotate gesture
  if event.gestureNumFingers == 2:
    rotation += event.gestureDTheta

# Two-finger pan vs one-finger select
proc handleTouch(event: Event, editor: NodeEditor) =
  case touchFingers.len
  of 1:  # Single finger - select/drag
    editor.handleTouchDrag(event.fingerX, event.fingerY)
  of 2:  # Two fingers - pan canvas
    editor.handleTouchPan(event.gestureDDist)
```

**Architecture Decision:** Design the Event type with touch fields now, but only implement for SDL3. Terminal ignores them gracefully.

---

## Implementation Phases

### Phase 1: Add Constants (Non-Breaking)
**Timeline:** Now  
**Changes:**
- Add `KeyCode`, `ScanCode`, `MouseButton` types
- Define all key constants (`KEY_ESCAPE`, `KEY_UP`, etc.)
- Export constants for use in demos
- Update canvased.nim to use constants internally

```nim
# Old way still works
if event.keyCode == 1000:
  # ...

# New way also works
if event.keyCode == KEY_UP:  # Much clearer!
  # ...
```

### Phase 2: New Event Type (Parallel)
**Timeline:** 1-2 weeks  
**Changes:**
- Implement full `Event` type with all fields
- Create conversion functions: old ↔ new
- Offer both APIs during transition
- Update 2-3 example demos to new system

### Phase 3: Terminal Migration
**Timeline:** 1 month  
**Changes:**
- Update JavaScript bridge to emit new events
- Migrate all demos to new event API
- Deprecate (but keep) old `event.type` string API
- Update documentation

### Phase 4: SDL3 Backend
**Timeline:** 3-6 months (separate project)  
**Changes:**
- Create "Storie" - SDL3-based graphical application
- Implement SDL3 event polling with new Event type
- Add touch event support
- Shared codebase: tstorie and Storie use same Event API!

---

## Recommended Action Items

### Immediate (Do Now)

1. ✅ **Add key constants to tstorie** - Non-breaking, immediate value
   ```nim
   # In lib/event_constants.nim (new file)
   const
     KEY_ESCAPE* = 27
     KEY_UP* = 1000
     KEY_DOWN* = 1001
     # etc.
   ```

2. ✅ **Update canvased.nim** - Use constants instead of strings
   ```nim
   proc handleKeyPress*(editor: NodeEditor, keyCode: int): bool =
     case keyCode
     of KEY_UP: editor.panCamera(0, -editor.arrowKeyPanSpeed)
     of KEY_ESCAPE: editor.deselectAll()
     # etc.
   ```

3. ✅ **Update one demo** - Show best practices
   ```nim
   # In canvased.md
   if event.keyCode == KEY_UP:
     # Much clearer than: if event.keyCode == 1000:
   ```

### Near Term (Next Sprint)

4. **Design Event type** - Full structure with SDL3 compatibility
5. **Prototype conversion** - Old event format → new Event type
6. **Test backward compat** - Ensure existing demos don't break

### Long Term (SDL3 Integration)

7. **SDL3 Backend** - Start "Storie" project with SDL3
8. **Share event logic** - Both tstorie and Storie use same Event type
9. **Touch support** - Implement multi-touch for tablets/mobile

---

## Benefits Summary

### For tstorie (Now)
- ✅ Clearer code - Named constants instead of magic numbers
- ✅ Better autocomplete - IDE shows available keys
- ✅ Fewer bugs - Type safety catches errors
- ✅ Easier demos - Less boilerplate conversion code

### For Storie (Future)
- ✅ Trivial SDL3 integration - Event types map directly
- ✅ Code reuse - Same event handling logic for terminal and graphics
- ✅ Multi-touch ready - Touch events designed into API
- ✅ Industry standard - SDL3 patterns are proven and documented

### For Both
- ✅ Unified codebase - Write once, run on terminal or graphical
- ✅ Progressive enhancement - Terminal gets basic events, SDL3 gets full
- ✅ Future proof - Easy to add new event types (gamepad, VR, etc.)
- ✅ Professional - Matches game engine best practices

---

## Conclusion

**Recommendation:** Start with Phase 1 (add constants) immediately. It's non-breaking, provides immediate value, and sets up the foundation for SDL3 integration.

The key insight: **Design for SDL3 now, even in terminal mode.** The event structure we choose today determines how easy the graphical transition will be tomorrow. SDL3's event system is mature and well-designed - we should follow its patterns.

**Next Steps:**
1. Create `lib/event_constants.nim` with key/button constants
2. Update canvased.nim to use constants
3. Update canvased.md demo as example
4. Document in README.md
5. Plan Phase 2 when ready for breaking changes

**Questions for Discussion:**
- Should we break compatibility now or provide gradual migration?
- Which demos should be updated first as examples?
- What's the timeline for starting the SDL3 "Storie" project?

---

## Time Handling & Callbacks

### Current State: Inconsistent Time Tracking

Looking at the codebase, time handling is fragmented:

**What Works:**
```nim
# In on:update blocks - deltaTime is injected
var deltaTime = 0.016  # Automatically set by executeCodeBlock

# Global time accessors
getTotalTime()   # Total elapsed seconds since app start
getDeltaTime()   # Returns 1.0 / targetFps (not accurate!)
getFrameCount()  # Total frames rendered
```

**What's Broken:**
```nim
# From canvased.md demo - manual time tracking!
var currentTime = 0.0
# In on:update:
currentTime = currentTime + (1.0 / 60.0)  # Assumes 60fps - WRONG!

# getDeltaTime() is misleading - it's not the real delta
getDeltaTime()  # Returns 1.0/60.0, not actual frame time
```

**Problems:**
1. ❌ `getDeltaTime()` returns `1.0 / targetFps`, not actual delta
2. ❌ Demos manually track time with hardcoded 1/60
3. ❌ No monotonic clock for accurate timing
4. ❌ No time-based callbacks (setTimeout, setInterval)
5. ❌ Long-press detection needs manual time tracking

### SDL3 Time System

SDL3 provides robust timing that we should emulate:

```c
// SDL3 time API
Uint64 SDL_GetTicks();           // Milliseconds since init
Uint64 SDL_GetPerformanceCounter();  // High-resolution counter
Uint64 SDL_GetPerformanceFrequency(); // Counter frequency

// Timer callbacks
SDL_TimerID SDL_AddTimer(Uint32 interval, SDL_TimerCallback callback, void* param);
SDL_bool SDL_RemoveTimer(SDL_TimerID id);
```

**Key Features:**
- Monotonic time (never goes backward)
- High precision (nanosecond on most platforms)
- Timer system for callbacks
- Frame-independent timing

### Proposed Solution: Unified Time API

```nim
# ================================================================
# TIME API - Inspired by SDL3 and game engines
# ================================================================

type
  TimerCallback* = proc(userdata: pointer): bool
    ## Return true to repeat, false to stop
  
  Timer* = object
    id*: int
    interval*: float  # Seconds
    callback*: TimerCallback
    userdata*: pointer
    repeat*: bool
    lastTrigger*: float
    active*: bool

# Time queries (matches SDL3 patterns)
proc getTime*(): float
  ## Get monotonic time in seconds since app start
  ## Equivalent to SDL_GetTicks() / 1000.0
  ## This NEVER goes backward (monotonic clock)

proc getTimeMs*(): int64
  ## Get monotonic time in milliseconds
  ## Equivalent to SDL_GetTicks()

proc getPerformanceTime*(): float
  ## High-precision time for benchmarking
  ## Equivalent to SDL_GetPerformanceCounter()

# Frame timing (automatically updated)
proc getDeltaTime*(): float
  ## Get ACTUAL time since last frame (not 1.0/fps!)
  ## This is the real deltaTime, varies frame-to-frame

proc getTotalTime*(): float
  ## Total elapsed time since app start
  ## Same as getTime(), provided for compatibility

proc getFrameCount*(): int
  ## Total frames rendered

# Timer system (like JavaScript/SDL3)
proc setTimeout*(callback: proc(), delay: float): int
  ## Call callback once after delay seconds
  ## Returns timer ID for cancellation
  ## Example: setTimeout(proc() = echo "Hi", 1.0)

proc setInterval*(callback: proc(), interval: float): int
  ## Call callback repeatedly every interval seconds
  ## Returns timer ID for cancellation
  ## Example: setInterval(proc() = echo "Tick", 0.5)

proc clearTimeout*(id: int)
  ## Cancel a setTimeout or setInterval timer
  ## Example: clearTimeout(timerId)

proc clearInterval*(id: int)
  ## Alias for clearTimeout (same implementation)

# Advanced timing
proc requestAnimationFrame*(callback: proc()): int
  ## Call callback on next frame (like web API)
  ## Useful for one-off next-frame actions

proc delay*(seconds: float)
  ## Sleep for specified duration (blocks!)
  ## Use timers instead for non-blocking delays
```

### Implementation Architecture

**1. Monotonic Clock Source**

```nim
# In src/timing.nim (new file)
import std/monotimes

var gAppStartTime: MonoTime
var gLastFrameTime: MonoTime
var gCurrentFrameTime: MonoTime
var gDeltaTime: float = 0.016  # Actual measured delta

proc initTiming*() =
  gAppStartTime = getMonoTime()
  gLastFrameTime = gAppStartTime
  gCurrentFrameTime = gAppStartTime
  gDeltaTime = 0.016

proc updateTiming*() =
  ## Call at start of each frame
  gLastFrameTime = gCurrentFrameTime
  gCurrentFrameTime = getMonoTime()
  
  let nanos = inNanoseconds(gCurrentFrameTime - gLastFrameTime)
  gDeltaTime = float(nanos) / 1_000_000_000.0
  
  # Clamp to prevent extreme values (0-100ms)
  gDeltaTime = clamp(gDeltaTime, 0.0, 0.1)

proc getTime*(): float =
  ## Monotonic time in seconds
  let elapsed = gCurrentFrameTime - gAppStartTime
  float(inNanoseconds(elapsed)) / 1_000_000_000.0

proc getDeltaTime*(): float =
  ## ACTUAL frame delta, not 1.0/fps
  gDeltaTime
```

**2. Timer System**

```nim
# In src/timing.nim continued
type
  TimerManager* = object
    timers: seq[Timer]
    nextId: int

var gTimerMgr: TimerManager

proc addTimer*(interval: float, callback: proc(), repeat: bool): int =
  result = gTimerMgr.nextId
  inc gTimerMgr.nextId
  
  gTimerMgr.timers.add(Timer(
    id: result,
    interval: interval,
    callback: cast[TimerCallback](callback),
    repeat: repeat,
    lastTrigger: getTime(),
    active: true
  ))

proc setTimeout*(callback: proc(), delay: float): int =
  addTimer(delay, callback, repeat = false)

proc setInterval*(callback: proc(), interval: float): int =
  addTimer(interval, callback, repeat = true)

proc clearTimer*(id: int) =
  for i, timer in gTimerMgr.timers:
    if timer.id == id:
      gTimerMgr.timers[i].active = false
      break

proc updateTimers*() =
  ## Call each frame to process timers
  let now = getTime()
  
  var i = 0
  while i < gTimerMgr.timers.len:
    var timer = addr gTimerMgr.timers[i]
    
    if not timer.active:
      gTimerMgr.timers.delete(i)
      continue
    
    if now - timer.lastTrigger >= timer.interval:
      # Trigger callback
      let shouldContinue = timer.callback(timer.userdata)
      timer.lastTrigger = now
      
      if not shouldContinue or not timer.repeat:
        timer.active = false
    
    inc i
```

**3. Integration in Main Loop**

```nim
# In tstorie.nim main loop
proc emUpdate(deltaMs: float) {.exportc.} =
  # Update timing FIRST
  updateTiming()
  
  # Now getDeltaTime() returns REAL delta, not 1.0/fps
  let dt = getDeltaTime()
  
  # Update timers
  updateTimers()
  
  # Update app state
  globalState.totalTime += dt
  globalState.frameCount += 1
  
  # Execute on:update blocks with REAL deltaTime
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "update":
      discard executeCodeBlock(storieCtx.niminiContext, codeBlock, 
                              globalState, deltaTime = dt)  # Real delta!
```

### Usage Examples

**Before (Manual Time Tracking)**

```nim
# on:init
var currentTime = 0.0
var showMenu = false

# on:update
currentTime = currentTime + (1.0 / 60.0)  # WRONG - assumes 60fps

# on:input
if event.type == "mouse" and event.action == "press":
  # Can't use time here - not available!
  
# Long press detection - manual and fragile
if editorCheckLongPress(editor, currentTime):
  showMenu = true
```

**After (Proper Time API)**

```nim
# on:init
var showMenu = false

# Use setTimeout instead of manual timing
var menuTimer = 0

# on:input  
if event.type == "mouse" and event.action == "press":
  # Start timer for long press (500ms)
  menuTimer = setTimeout(proc() =
    showMenu = true
  , 0.5)

if event.type == "mouse" and event.action == "release":
  # Cancel timer if released early
  clearTimeout(menuTimer)

# Animation example - smooth regardless of framerate
# on:update (deltaTime injected automatically)
position.x += velocity * deltaTime  # Frame-independent!

# Periodic events
# on:init
setInterval(proc() =
  echo "Autosave..."
, 60.0)  # Every 60 seconds

# Next-frame action
# on:input
if event.key == "Space":
  requestAnimationFrame(proc() =
    # This runs next frame, after current input is processed
    resetScene()
  )
```

### Benefits

**For Developers:**
- ✅ No manual time tracking needed
- ✅ Proper deltaTime for smooth animations
- ✅ setTimeout/setInterval like JavaScript
- ✅ Frame-independent physics and movement
- ✅ Accurate long-press detection

**For Performance:**
- ✅ Monotonic clock prevents time glitches
- ✅ Clamped deltaTime prevents physics explosions
- ✅ Efficient timer management
- ✅ No allocation overhead

**For SDL3:**
- ✅ Direct mapping to SDL_GetTicks()
- ✅ Timer API maps to SDL_AddTimer()
- ✅ Same patterns as desktop games
- ✅ Easy to port existing SDL code

### Migration Path

**Phase 1: Add Timing Module (Non-Breaking)**
```nim
# Add src/timing.nim with new API
# Export getTime(), getDeltaTime(), setTimeout(), etc.
# Update nimini_bridge.nim to expose new functions
# Old getDeltaTime() marked deprecated
```

**Phase 2: Update Main Loop**
```nim
# Change emUpdate to use real deltaTime
# Update executeCodeBlock to inject real delta
# Add updateTimers() call
```

**Phase 3: Update Demos**
```nim
# Remove manual currentTime tracking
# Use setTimeout for long-press
# Use setInterval for periodic tasks
# Update physics to use deltaTime
```

**Phase 4: SDL3 Backend**
```nim
# In SDL3 implementation
proc getTime*(): float =
  float(SDL_GetTicks()) / 1000.0

proc setTimeout*(callback: proc(), delay: float): int =
  SDL_AddTimer(uint32(delay * 1000), wrapCallback(callback), nil)
```

### Backward Compatibility

```nim
# Keep old API working during transition
proc getDeltaTime*(): float =
  when defined(deprecatedTimeApi):
    # Old behavior - return 1.0/fps
    return 1.0 / gAppState.targetFps
  else:
    # New behavior - return real delta
    return gDeltaTime

# Provide migration helper
proc getTimeMs*(): int64 =
  ## New: millisecond precision time
  ## Replaces manual currentTime tracking
  int64(getTime() * 1000.0)
```

### Documentation Update

Add to README.md:

```markdown
## Time and Animation

TStorie provides precise timing for animations and events:

### Frame Timing
- `getDeltaTime()` - Actual seconds since last frame (varies!)
- `getTotalTime()` - Total seconds since app start
- `getFrameCount()` - Total frames rendered

### Time-Based Callbacks
- `setTimeout(callback, seconds)` - Call once after delay
- `setInterval(callback, seconds)` - Call repeatedly
- `clearTimeout(id)` - Cancel a timer
- `requestAnimationFrame(callback)` - Call on next frame

### Best Practices
```nim
# ✅ GOOD - Frame-independent
position += velocity * deltaTime

# ❌ BAD - Framerate dependent
position += velocity  # Too fast at high FPS!

# ✅ GOOD - Use timers
setTimeout(proc() = showMenu = true, 0.5)

# ❌ BAD - Manual timing
currentTime += 1.0/60.0  # Wrong if not 60fps!
```
```

---

## Combined Recommendation: Events + Timing

**Phase 1 (Immediate):**
1. Add key constants (KEY_ESCAPE, etc.)
2. Add timing module (getTime, setTimeout)
3. Update canvased demo to use new timing
4. Document in README

**Phase 2 (1-2 weeks):**
5. New Event type with SDL3 compatibility
6. Update main loop for real deltaTime
7. Add timer system integration
8. Migrate 2-3 demos

**Phase 3 (1 month):**
9. Full migration to new event system
10. Remove deprecated time APIs
11. Complete demo updates

**Phase 4 (3-6 months):**
12. SDL3 backend for "Storie"
13. Multi-touch support
14. Shared event+timing layer

---

*This document is a living proposal. Update as architecture evolves.*
