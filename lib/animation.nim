## Animation Helpers Module
## Reusable animation utilities for real-time UI and visual effects
## 
## NOTE: This module is for FLOAT-BASED VISUAL ANIMATIONS.
## For DETERMINISTIC PROCEDURAL GENERATION (seed-based systems),
## use lib/primitives.nim instead, which provides INTEGER-BASED
## easing functions that guarantee identical results across implementations.
##
## See ANIMATION_VS_PROCGEN_EASING.md for detailed comparison.
## 
## This module contains only pure math functions and has no dependencies
## on tstorie core types. Color/Style/Buffer operations have been moved
## to src/types.nim and src/layers.nim respectively.

import math

# ================================================================
# EASING FUNCTIONS (Float-based for smooth visual animations)
# For deterministic procedural generation, use lib/primitives.nim
# ================================================================

proc easeLinear*(t: float): float = t

proc easeInQuad*(t: float): float = t * t

proc easeOutQuad*(t: float): float = t * (2.0 - t)

proc easeInOutQuad*(t: float): float =
  if t < 0.5: 2.0 * t * t
  else: -1.0 + (4.0 - 2.0 * t) * t

proc easeInCubic*(t: float): float = t * t * t

proc easeOutCubic*(t: float): float =
  let t1 = t - 1.0
  t1 * t1 * t1 + 1.0

proc easeInOutCubic*(t: float): float =
  if t < 0.5: 4.0 * t * t * t
  else:
    let t1 = 2.0 * t - 2.0
    (t1 * t1 * t1 + 2.0) / 2.0

proc easeInSine*(t: float): float =
  1.0 - cos(t * PI / 2.0)

proc easeOutSine*(t: float): float =
  sin(t * PI / 2.0)

proc easeInOutSine*(t: float): float =
  -(cos(PI * t) - 1.0) / 2.0

# ================================================================
# INTERPOLATION
# (Core lerp functions moved to src/types.nim)
# ================================================================

proc lerp*(a, b, t: float): float =
  ## Linear interpolation
  a + (b - a) * t

# ================================================================
# ANIMATION STATE
# ================================================================

type
  Animation* = object
    duration*: float
    elapsed*: float
    loop*: bool
    pingpong*: bool
    reversed: bool

proc newAnimation*(duration: float, loop: bool = false, pingpong: bool = false): Animation =
  Animation(duration: duration, elapsed: 0.0, loop: loop, pingpong: pingpong, reversed: false)

proc update*(anim: var Animation, dt: float) =
  ## Update animation time
  anim.elapsed += dt
  
  if anim.elapsed >= anim.duration:
    if anim.loop:
      if anim.pingpong:
        anim.reversed = not anim.reversed
        anim.elapsed = 0.0
      else:
        anim.elapsed = anim.elapsed mod anim.duration
    else:
      anim.elapsed = anim.duration

proc progress*(anim: Animation): float =
  ## Get current animation progress (0.0 to 1.0)
  let t = anim.elapsed / anim.duration
  if anim.reversed:
    return 1.0 - t
  return t

proc isDone*(anim: Animation): bool =
  ## Check if animation has finished (for non-looping animations)
  not anim.loop and anim.elapsed >= anim.duration

# ================================================================
# PARTICLE SYSTEM
# ================================================================
# 
# NOTE: Basic particle primitives have been moved to lib/particles.nim
# which provides a full-featured native particle system with:
# - Bulk update/render for 1000+ particles at 60 FPS
# - Environmental parameters (gravity, wind, turbulence, damping)
# - Collision detection with configurable responses
# - Built-in emitter behaviors (rain, snow, fire, etc.)
# 
# For simple single-particle helpers, use the particles module instead.

# ================================================================
# ADDITIONAL INTERPOLATION HELPERS
# (lerpRGB moved to src/types.nim)
# ================================================================

proc lerpInt*(a, b: int, t: float): int =
  ## Linear interpolation for integers
  int(float(a) + (float(b) - float(a)) * t)

proc smoothstep*(t: float): float =
  ## Smooth interpolation (smoother than linear, less aggressive than ease functions)
  let t2 = clamp(t, 0.0, 1.0)
  t2 * t2 * (3.0 - 2.0 * t2)

proc clamp01*(t: float): float =
  ## Clamp value to 0.0-1.0 range
  clamp(t, 0.0, 1.0)

proc inverseLerp*(a, b, value: float): float =
  ## Get the interpolation factor that produces 'value' between a and b
  if abs(b - a) < 0.0001:
    return 0.0
  clamp01((value - a) / (b - a))

# ================================================================
# BUFFER SNAPSHOT SYSTEM
# (Moved to src/layers.nim - these functions work with core TermBuffer type)
# ================================================================
