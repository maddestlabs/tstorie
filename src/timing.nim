## Timing Module - High-Precision Time Tracking and Timer Callbacks
##
## Provides accurate frame timing and timer callbacks, designed to be
## compatible with SDL3's timing system while working in terminal mode.
##
## Key Features:
## - Monotonic time tracking (never goes backward)
## - Real deltaTime measurement (not hardcoded 1/60)
## - setTimeout/setInterval callbacks (like JavaScript)
## - Frame-independent animation support
## - SDL3-compatible API for future graphical backend
##
## Design Philosophy:
## - Accurate time measurement for smooth animations
## - Non-blocking timers for periodic tasks
## - Cross-platform monotonic clock
## - Drop-in replacement for manual time tracking

import std/monotimes
import std/times
import std/os  # For sleep function
import std/strformat  # For formatFloat
import ../nimini/auto_bindings

# ================================================================
# GLOBAL TIMING STATE
# ================================================================

type
  TimerCallback* = proc() {.closure.}
    ## Timer callback function type
  
  Timer = object
    id: int
    interval: float         # Seconds between triggers
    callback: TimerCallback
    repeat: bool           # true = setInterval, false = setTimeout
    lastTrigger: float     # Time of last trigger
    active: bool
  
  TimerManager = object
    timers: seq[Timer]
    nextId: int

var
  gAppStartTime: MonoTime      # App initialization time
  gLastFrameTime: MonoTime     # Previous frame time
  gCurrentFrameTime: MonoTime  # Current frame time
  gDeltaTime: float = 0.016    # Actual measured frame delta (seconds)
  gTotalTime: float = 0.0      # Total elapsed time since init
  gFrameCount: int = 0         # Total frames rendered
  gTimerMgr: TimerManager      # Timer management

# ================================================================
# INITIALIZATION
# ================================================================

proc initTiming*() =
  ## Initialize the timing system
  ## Should be called once at app startup
  gAppStartTime = getMonoTime()
  gLastFrameTime = gAppStartTime
  gCurrentFrameTime = gAppStartTime
  gDeltaTime = 0.016  # Start with 60fps assumption
  gTotalTime = 0.0
  gFrameCount = 0
  gTimerMgr = TimerManager(timers: @[], nextId: 1)

proc isInitialized(): bool =
  ## Check if timing system is initialized
  gTimerMgr.nextId > 0

# ================================================================
# FRAME TIMING
# ================================================================

proc updateTiming*() =
  ## Update timing for current frame
  ## Call this once at the start of each frame, before any other updates
  if not isInitialized():
    initTiming()
  
  gLastFrameTime = gCurrentFrameTime
  gCurrentFrameTime = getMonoTime()
  
  # Calculate actual delta time in seconds
  let nanos = inNanoseconds(gCurrentFrameTime - gLastFrameTime)
  gDeltaTime = float(nanos) / 1_000_000_000.0
  
  # Clamp to prevent extreme values (min 1ms, max 100ms)
  # Prevents physics explosions on lag spikes or debugger pauses
  if gDeltaTime < 0.001:
    gDeltaTime = 0.001
  elif gDeltaTime > 0.1:
    gDeltaTime = 0.1
  
  # Update total time and frame count
  gTotalTime += gDeltaTime
  gFrameCount += 1

# ================================================================
# TIME QUERIES
# ================================================================

proc getTime*(): float {.autoExpose: "timing".} =
  ## Get monotonic time in seconds since app start
  ## This NEVER goes backward (monotonic clock)
  ## Equivalent to SDL_GetTicks() / 1000.0
  if not isInitialized():
    initTiming()
  
  let elapsed = gCurrentFrameTime - gAppStartTime
  result = float(inNanoseconds(elapsed)) / 1_000_000_000.0

proc getTimeMs*(): int {.autoExpose: "timing".} =
  ## Get monotonic time in milliseconds since app start
  ## Equivalent to SDL_GetTicks()
  int(getTime() * 1000.0)

proc getPerformanceTime*(): float {.autoExpose: "timing".} =
  ## High-precision time for benchmarking
  ## Returns raw monotonic time in seconds
  ## Equivalent to SDL_GetPerformanceCounter() / SDL_GetPerformanceFrequency()
  let now = getMonoTime()
  let elapsed = now - gAppStartTime
  float(inNanoseconds(elapsed)) / 1_000_000_000.0

proc getDeltaTime*(): float {.autoExpose: "timing".} =
  ## Get ACTUAL time since last frame in seconds
  ## This is the real measured deltaTime, varies frame-to-frame
  ## Use this for frame-independent movement: position += velocity * deltaTime
  if not isInitialized():
    return 0.016  # Default to 60fps if not initialized
  gDeltaTime

proc getTotalTime*(): float {.autoExpose: "timing".} =
  ## Total elapsed time since app start in seconds
  ## Same as getTime(), provided for API compatibility
  if not isInitialized():
    return 0.0
  gTotalTime

proc getFrameCount*(): int {.autoExpose: "timing".} =
  ## Total frames rendered since app start
  gFrameCount

# ================================================================
# TIMER SYSTEM
# ================================================================

proc addTimer(interval: float, callback: TimerCallback, repeat: bool): int =
  ## Internal: Add a timer to the manager
  if not isInitialized():
    initTiming()
  
  result = gTimerMgr.nextId
  inc gTimerMgr.nextId
  
  gTimerMgr.timers.add(Timer(
    id: result,
    interval: interval,
    callback: callback,
    repeat: repeat,
    lastTrigger: getTotalTime(),
    active: true
  ))

proc setTimeout*(callback: TimerCallback, delay: float): int =
  ## Call callback once after delay seconds
  ## Returns timer ID for cancellation
  ## 
  ## Example:
  ##   let timerId = setTimeout(proc() = echo "Hello!", 1.0)
  ##   # Cancel if needed: clearTimeout(timerId)
  addTimer(delay, callback, repeat = false)

proc setInterval*(callback: TimerCallback, interval: float): int =
  ## Call callback repeatedly every interval seconds
  ## Returns timer ID for cancellation
  ## 
  ## Example:
  ##   let timerId = setInterval(proc() = echo "Tick", 0.5)
  ##   # Cancel when done: clearInterval(timerId)
  addTimer(interval, callback, repeat = true)

proc clearTimeout*(id: int) =
  ## Cancel a setTimeout or setInterval timer
  ## Safe to call multiple times or with invalid IDs
  for i in 0..<gTimerMgr.timers.len:
    if gTimerMgr.timers[i].id == id:
      gTimerMgr.timers[i].active = false
      break

proc clearInterval*(id: int) =
  ## Cancel a setInterval timer
  ## Alias for clearTimeout (same implementation)
  clearTimeout(id)

proc updateTimers*() =
  ## Process all active timers
  ## Call this once per frame, after updateTiming()
  if not isInitialized():
    return
  
  let now = getTotalTime()
  
  # Remove inactive timers and trigger active ones
  var i = 0
  while i < gTimerMgr.timers.len:
    let timer = addr gTimerMgr.timers[i]
    
    # Remove inactive timers
    if not timer.active:
      gTimerMgr.timers.delete(i)
      continue
    
    # Check if timer should trigger
    if now - timer.lastTrigger >= timer.interval:
      # Call the callback
      try:
        timer.callback()
      except:
        # Don't let callback exceptions crash the app
        discard
      
      timer.lastTrigger = now
      
      # Deactivate one-shot timers
      if not timer.repeat:
        timer.active = false
    
    inc i

# ================================================================
# ADVANCED TIMING
# ================================================================

var gNextFrameCallbacks: seq[TimerCallback] = @[]

proc requestAnimationFrame*(callback: TimerCallback) =
  ## Call callback on next frame (like web API)
  ## Useful for one-off next-frame actions
  ## 
  ## Example:
  ##   requestAnimationFrame(proc() = resetScene())
  gNextFrameCallbacks.add(callback)

proc processNextFrameCallbacks*() =
  ## Internal: Process callbacks scheduled for next frame
  ## Call this once per frame, typically at the start
  if gNextFrameCallbacks.len == 0:
    return
  
  # Process all callbacks, clearing the list
  let callbacks = gNextFrameCallbacks
  gNextFrameCallbacks = @[]
  
  for callback in callbacks:
    try:
      callback()
    except:
      discard

proc delay*(seconds: float) =
  ## Sleep for specified duration (BLOCKS!)
  ## Only use for initialization or testing
  ## Use setTimeout() for non-blocking delays in game code
  sleep(int(seconds * 1000.0))



# ================================================================
# DEBUG HELPERS
# ================================================================

proc formatTime*(seconds: float): string =
  ## Format time as MM:SS.mmm
  let mins = int(seconds / 60.0)
  let secs = seconds - float(mins * 60)
  result = $mins & ":" & $secs

proc getTimingStats*(): string =
  ## Get timing statistics as a debug string
  result = "Frame " & $gFrameCount
  result &= " | Time: " & formatTime(gTotalTime)
  result &= " | Delta: " & $gDeltaTime & "s"
  result &= " | FPS: " & $(1.0 / gDeltaTime)
  result &= " | Timers: " & $gTimerMgr.timers.len

# ================================================================
# MODULE INITIALIZATION (for auto-binding system)
# ================================================================

proc initTimingModule*() =
  ## Ensures auto-exposed timing functions are registered
  ## Called explicitly to ensure module initialization in WASM builds
  queuePluginRegistration(register_getTime)
  queuePluginRegistration(register_getTimeMs)
  queuePluginRegistration(register_getPerformanceTime)
  queuePluginRegistration(register_getDeltaTime)
  queuePluginRegistration(register_getTotalTime)
  queuePluginRegistration(register_getFrameCount)
