## Animation Helpers Module
## Reusable animation utilities
## 
## Note: This module expects Color, Style, AppState, Layer, and black() 
## to be available from the importing/including context.

import math

# ================================================================
# EASING FUNCTIONS
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
# ================================================================

proc lerp*(a, b, t: float): float =
  ## Linear interpolation
  a + (b - a) * t

proc lerpColor*(a, b: Color, t: float): Color =
  ## Interpolate between two colors
  Color(
    r: uint8(lerp(float(a.r), float(b.r), t)),
    g: uint8(lerp(float(a.g), float(b.g), t)),
    b: uint8(lerp(float(a.b), float(b.b), t))
  )

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

type
  Particle* = object
    x*, y*: float
    vx*, vy*: float
    life*: float
    maxLife*: float
    char*: string
    color*: Color

proc newParticle*(x, y, vx, vy, life: float, char: string, color: Color): Particle =
  Particle(x: x, y: y, vx: vx, vy: vy, life: life, maxLife: life, char: char, color: color)

proc update*(p: var Particle, dt: float, gravity: float = 0.0) =
  p.x += p.vx * dt
  p.y += p.vy * dt
  p.vy += gravity * dt
  p.life -= dt

proc isAlive*(p: Particle): bool =
  p.life > 0.0

proc render*(p: Particle, state: AppState) =
  if p.isAlive():
    let alpha = p.life / p.maxLife
    var color = p.color
    # Fade out based on life
    color.r = uint8(float(color.r) * alpha)
    color.g = uint8(float(color.g) * alpha)
    color.b = uint8(float(color.b) * alpha)
    
    let style = Style(fg: color, bg: black())
    let ix = int(p.x)
    let iy = int(p.y)
    if ix >= 0 and ix < state.termWidth and iy >= 0 and iy < state.termHeight:
      state.currentBuffer.write(ix, iy, p.char, style)

proc renderToLayer*(p: Particle, layer: Layer) =
  if p.isAlive():
    let alpha = p.life / p.maxLife
    var color = p.color
    color.r = uint8(float(color.r) * alpha)
    color.g = uint8(float(color.g) * alpha)
    color.b = uint8(float(color.b) * alpha)
    
    let style = Style(fg: color, bg: black())
    let ix = int(p.x)
    let iy = int(p.y)
    if ix >= 0 and ix < layer.buffer.width and iy >= 0 and iy < layer.buffer.height:
      layer.buffer.write(ix, iy, p.char, style)

# ================================================================
# TRANSITION STATE MANAGERS
# ================================================================

type
  TransitionState* = object
    duration*: float
    elapsed*: float
    active*: bool
    easingFunc*: proc(t: float): float

proc newTransition*(duration: float, easing: proc(t: float): float = easeLinear): TransitionState =
  ## Create a new transition state tracker
  TransitionState(duration: duration, elapsed: 0.0, active: true, easingFunc: easing)

proc update*(trans: var TransitionState, dt: float) =
  ## Update transition progress
  if not trans.active:
    return
  
  trans.elapsed += dt
  if trans.elapsed >= trans.duration:
    trans.elapsed = trans.duration
    trans.active = false

proc progress*(trans: TransitionState): float =
  ## Get raw linear progress (0.0 to 1.0)
  if trans.duration == 0.0:
    return 1.0
  return min(trans.elapsed / trans.duration, 1.0)

proc easedProgress*(trans: TransitionState): float =
  ## Get eased progress (0.0 to 1.0) using the transition's easing function
  trans.easingFunc(trans.progress())

proc isActive*(trans: TransitionState): bool =
  ## Check if transition is still running
  trans.active

proc reset*(trans: var TransitionState) =
  ## Reset transition to beginning
  trans.elapsed = 0.0
  trans.active = true

# ================================================================
# ADDITIONAL INTERPOLATION HELPERS
# ================================================================

proc lerpInt*(a, b: int, t: float): int =
  ## Linear interpolation for integers
  int(float(a) + (float(b) - float(a)) * t)

proc lerpRGB*(r1, g1, b1, r2, g2, b2: int, t: float): Color =
  ## Interpolate between two RGB values
  Color(
    r: uint8(lerpInt(r1, r2, t)),
    g: uint8(lerpInt(g1, g2, t)),
    b: uint8(lerpInt(b1, b2, t))
  )

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

