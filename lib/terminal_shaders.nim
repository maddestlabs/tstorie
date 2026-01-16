## Terminal Shaders - Procedural Visual Effects for Character Terminals
##
## This module brings shader-like aesthetics to the terminal by treating each
## character cell as a "pixel" with both a density (character choice) and color.
##
## Core concepts:
## - Character ramps provide density/brightness information
## - Colors provide hue/saturation information
## - Procedural math generates patterns (noise, distance fields, waves)
## - Time-based animation creates motion
##
## Usage from nimini:
##   on:init -> initShader(effectId, layerId, x, y, width, height)
##   on:update -> updateShader()
##   on:render -> drawShader()

import std/[math]
import primitives

when not declared(Color):
  import ../src/types
  import ../src/layers

# ================================================================
# PARTICLE SHADER TYPES
# ================================================================

type
  ParticleData* = object
    ## Particle information passed to shaders
    x*, y*: float         # Particle position
    vx*, vy*: float       # Particle velocity
    life*, maxLife*: float
    color*: Color         # Particle color
    char*: string         # Particle character
    age*: float           # Normalized age (0.0 = birth, 1.0 = death)

  ShaderContext* = object
    ## Context information passed to cell shaders
    cellX*, cellY*: int   # Cell position being rendered
    time*: int            # Frame counter
    particle*: ParticleData  # Source particle (if rendering particle)
    hasParticle*: bool    # Whether particle data is valid
    backgroundColor*: Color  # System background color

  CellShader* = proc(inCell: Cell, ctx: ShaderContext): Cell {.closure.}
    ## A shader that transforms a cell
    ## Takes input cell + context, returns output cell

# ================================================================
# SHADER STATE
# ================================================================

type
  ShaderState* = ref object
    effectId*: int
    layerId*: int
    x*, y*: int
    width*, height*: int
    frame*: int
    paused*: bool
    reduction*: int  # Resolution divisor (1=full, 2=half, 4=quarter)

  DisplacementState* = ref object
    effectId*: int
    layerId*: int
    x*, y*: int
    width*, height*: int
    frame*: int
    paused*: bool
    intensity*: float  # Displacement strength multiplier
    speed*: float  # Animation speed multiplier (default 1.0)
    amplitude*: float  # Base displacement amplitude (default 1.0, lower = subtler)
    
var gShaderState*: ShaderState = nil
var gDisplacementState*: DisplacementState = nil

# ==============================================================================
# CHARACTER DENSITY RAMPS
# ==============================================================================

const
  ## ASCII luminance gradient (10 levels, dark to bright)
  DENSITY_ASCII* = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"]
  
  ## Smooth shading using box-drawing characters (5 levels)
  DENSITY_SMOOTH* = [" ", "░", "▒", "▓", "█"]
  
  ## Smooth shading using Unicode block elements (9 levels)
  DENSITY_BLOCKS* = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  
  ## Braille-based gradient (8 levels) - very fine control
  DENSITY_BRAILLE* = [" ", "⡀", "⡄", "⡆", "⡇", "⣇", "⣧", "⣷", "⣿"]
  
  ## Dotted pattern gradient
  DENSITY_DOTS* = [" ", "·", "•", "●", "⬤", "⬤", "⬤", "⬤", "█"]
  
  ## Technical/digital aesthetic
  DENSITY_TECH* = [" ", ".", ":", "=", "+", "▪", "▫", "▬", "█"]

# ==============================================================================
# COLOR PALETTES AND GRADIENTS
# ==============================================================================

proc heatmap*(value: int): Color =
  ## Classic heatmap: black → red → yellow → white
  ## value: 0..255
  let v = clamp(value, 0, 255)
  if v < 85:
    Color(r: uint8(v * 3), g: 0, b: 0)
  elif v < 170:
    Color(r: 255, g: uint8((v - 85) * 3), b: 0)
  else:
    let w = uint8((v - 170) * 3)
    Color(r: 255, g: 255, b: w)

proc plasma*(value: int): Color =
  ## Plasma-style rainbow gradient
  ## value: 0..255
  let v = clamp(value, 0, 255)
  let angle = float(v) * PI * 2.0 / 255.0
  Color(
    r: uint8(127.5 + 127.5 * sin(angle)),
    g: uint8(127.5 + 127.5 * sin(angle + PI * 2.0 / 3.0)),
    b: uint8(127.5 + 127.5 * sin(angle + PI * 4.0 / 3.0))
  )

proc coolWarm*(value: int): Color =
  ## Cool (blue) to warm (red) gradient
  ## value: 0..255
  let v = clamp(value, 0, 255)
  let t = float(v) / 255.0
  Color(
    r: uint8(t * 255.0),
    g: uint8((1.0 - abs(t - 0.5) * 2.0) * 255.0),
    b: uint8((1.0 - t) * 255.0)
  )

proc neon*(value: int): Color =
  ## Neon cyan-magenta gradient
  ## value: 0..255
  let v = clamp(value, 0, 255)
  let t = float(v) / 255.0
  Color(
    r: uint8(t * 255.0),
    g: uint8(sin(t * PI) * 128.0 + 127.0),
    b: 255
  )

proc fire*(value: int): Color =
  ## Fire gradient: black → red → orange → yellow
  ## value: 0..255
  let v = clamp(value, 0, 255)
  if v < 64:
    Color(r: uint8(v * 4), g: 0, b: 0)
  elif v < 128:
    Color(r: 255, g: uint8((v - 64) * 4), b: 0)
  elif v < 192:
    Color(r: 255, g: uint8(128 + (v - 128) * 2), b: 0)
  else:
    Color(r: 255, g: 255, b: uint8((v - 192) * 4))

proc ocean*(value: int): Color =
  ## Deep blue to cyan gradient
  ## value: 0..255
  let v = clamp(value, 0, 255)
  Color(
    r: 0,
    g: uint8(v div 2),
    b: uint8(128 + v div 2)
  )

proc matrix*(value: int): Color =
  ## Matrix-style green gradient
  ## value: 0..255
  let v = clamp(value, 0, 255)
  Color(r: 0, g: uint8(v), b: uint8(v div 4))

proc grayscale*(value: int): Color =
  ## Simple grayscale
  ## value: 0..255
  let v = uint8(clamp(value, 0, 255))
  Color(r: v, g: v, b: v)

# ==============================================================================
# PARTICLE CELL SHADERS
# ==============================================================================

proc replaceShader*(): CellShader =
  ## Replace entire cell with particle (char + fg + bg)
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    Cell(
      ch: ctx.particle.char,
      style: Style(
        fg: ctx.particle.color,
        bg: ctx.backgroundColor,
        bold: false, underline: false, italic: false, dim: false
      )
    )

proc charOnlyShader*(): CellShader =
  ## Replace only character, preserve colors
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    Cell(
      ch: ctx.particle.char,
      style: inCell.style
    )

proc foregroundOnlyShader*(): CellShader =
  ## Replace only foreground color, preserve char and background
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    Cell(
      ch: inCell.ch,
      style: Style(
        fg: ctx.particle.color,
        bg: inCell.style.bg,
        bold: inCell.style.bold,
        underline: inCell.style.underline,
        italic: inCell.style.italic,
        dim: inCell.style.dim
      )
    )

proc backgroundOnlyShader*(): CellShader =
  ## Replace only background color, preserve char and foreground
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    let ch = if inCell.ch.len == 0: " " else: inCell.ch
    Cell(
      ch: ch,
      style: Style(
        fg: inCell.style.fg,
        bg: ctx.particle.color,
        bold: inCell.style.bold,
        underline: inCell.style.underline,
        italic: inCell.style.italic,
        dim: inCell.style.dim
      )
    )

proc colorModulateShader*(strength: float = 1.0): CellShader =
  ## Modulate (tint) foreground color toward particle color
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    
    let t = clamp(strength, 0.0, 1.0)
    let fg = inCell.style.fg
    let pc = ctx.particle.color
    
    Cell(
      ch: inCell.ch,
      style: Style(
        fg: Color(
          r: uint8(float(fg.r) * (1.0 - t) + float(pc.r) * t),
          g: uint8(float(fg.g) * (1.0 - t) + float(pc.g) * t),
          b: uint8(float(fg.b) * (1.0 - t) + float(pc.b) * t)
        ),
        bg: inCell.style.bg,
        bold: inCell.style.bold,
        underline: inCell.style.underline,
        italic: inCell.style.italic,
        dim: inCell.style.dim
      )
    )

proc colorAdditiveShader*(strength: float = 1.0): CellShader =
  ## Add particle color to foreground (brightening effect)
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    
    let fg = inCell.style.fg
    let pc = ctx.particle.color
    let s = clamp(strength, 0.0, 1.0)
    
    Cell(
      ch: inCell.ch,
      style: Style(
        fg: Color(
          r: min(255'u8, uint8(min(255, int(fg.r) + int(float(pc.r) * s)))),
          g: min(255'u8, uint8(min(255, int(fg.g) + int(float(pc.g) * s)))),
          b: min(255'u8, uint8(min(255, int(fg.b) + int(float(pc.b) * s))))
        ),
        bg: inCell.style.bg,
        bold: inCell.style.bold,
        underline: inCell.style.underline,
        italic: inCell.style.italic,
        dim: inCell.style.dim
      )
    )

proc colorMultiplyShader*(): CellShader =
  ## Multiply particle color with foreground
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle:
      return inCell
    
    let fg = inCell.style.fg
    let pc = ctx.particle.color
    
    Cell(
      ch: inCell.ch,
      style: Style(
        fg: Color(
          r: uint8((float(fg.r) / 255.0) * (float(pc.r) / 255.0) * 255.0),
          g: uint8((float(fg.g) / 255.0) * (float(pc.g) / 255.0) * 255.0),
          b: uint8((float(fg.b) / 255.0) * (float(pc.b) / 255.0) * 255.0)
        ),
        bg: inCell.style.bg,
        bold: inCell.style.bold,
        underline: inCell.style.underline,
        italic: inCell.style.italic,
        dim: inCell.style.dim
      )
    )

const CharDensityScale* = [" ", ".", "·", ":", "-", "=", "+", "*", "#", "@", "█"]

proc charDensityReduceShader*(amount: int = 1): CellShader =
  ## Reduce character density (make less dense)
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle or inCell.ch.len == 0:
      return inCell
    
    # Find current char in density scale
    var idx = -1
    for i, ch in CharDensityScale:
      if ch == inCell.ch:
        idx = i
        break
    
    let newIdx = if idx >= 0: max(0, idx - amount) else: 0
    
    Cell(
      ch: CharDensityScale[newIdx],
      style: inCell.style
    )

proc charDensityIncreaseShader*(amount: int = 1): CellShader =
  ## Increase character density (make more dense)
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    if not ctx.hasParticle or inCell.ch.len == 0:
      return inCell
    
    # Find current char in density scale
    var idx = -1
    for i, ch in CharDensityScale:
      if ch == inCell.ch:
        idx = i
        break
    
    let newIdx = if idx >= 0: min(CharDensityScale.high, idx + amount) else: 0
    
    Cell(
      ch: CharDensityScale[newIdx],
      style: inCell.style
    )

proc compositeShader*(shaders: seq[CellShader]): CellShader =
  ## Compose multiple shaders (apply in sequence)
  result = proc(inCell: Cell, ctx: ShaderContext): Cell =
    result = inCell
    for shader in shaders:
      result = shader(result, ctx)

# ==============================================================================
# SHADER OUTPUT TYPE (LEGACY)
# ==============================================================================

type
  ShaderPixel* = object
    ## The result of a shader computation for one cell
    char*: string
    fg*: Color
    bg*: Color

  ShaderFunc* = proc(x, y, time: int): ShaderPixel {.closure.}
    ## A shader function takes position (x, y) and time, returns a pixel

  DisplacementFunc* = proc(x, y, time: int): (float, float) {.closure.}
    ## A displacement function takes position and time, returns (dx, dy) offset

# ==============================================================================
# DISTANCE FIELD UTILITIES
# ==============================================================================

proc distSq*(x1, y1, x2, y2: int): int =
  ## Squared distance (faster, avoids sqrt)
  let dx = x1 - x2
  let dy = y1 - y2
  dx * dx + dy * dy

proc dist*(x1, y1, x2, y2: int): int =
  ## Euclidean distance
  int(sqrt(float(distSq(x1, y1, x2, y2))))

proc distManhattan*(x1, y1, x2, y2: int): int =
  ## Manhattan distance
  abs(x1 - x2) + abs(y1 - y2)

proc distChebyshev*(x1, y1, x2, y2: int): int =
  ## Chebyshev distance (chessboard)
  max(abs(x1 - x2), abs(y1 - y2))

# ==============================================================================
# DISPLACEMENT EFFECTS
# ==============================================================================

proc waveDisplacement*(amplitude: float = 2.0, frequency: float = 0.2, 
                       speed: float = 0.1, vertical: bool = false): DisplacementFunc =
  ## Sine wave displacement - creates a wave effect
  ## amplitude: How far pixels move (in cells)
  ## frequency: Wave frequency (higher = more waves)
  ## speed: Animation speed
  ## vertical: If true, wave moves vertically; otherwise horizontally
  result = proc(x, y, time: int): (float, float) =
    if vertical:
      let wave = sin(float(x) * frequency + float(time) * speed)
      (0.0, wave * amplitude)
    else:
      let wave = sin(float(y) * frequency + float(time) * speed)
      (wave * amplitude, 0.0)

proc rippleDisplacement*(centerX, centerY: int, amplitude: float = 2.0,
                         frequency: float = 0.3, speed: float = 0.1): DisplacementFunc =
  ## Radial ripple displacement - creates water ripple effect
  result = proc(x, y, time: int): (float, float) =
    let dx = float(x - centerX)
    let dy = float(y - centerY)
    let distance = sqrt(dx * dx + dy * dy)
    
    if distance < 0.1:
      return (0.0, 0.0)
    
    let wave = sin(distance * frequency - float(time) * speed)
    let strength = wave * amplitude / distance
    
    (dx * strength, dy * strength)

proc noiseDisplacement*(scale: int = 20, amplitude: float = 1.5, 
                        seed: int = 42, animateX: bool = true, 
                        animateY: bool = true): DisplacementFunc =
  ## Noise-based displacement - creates organic distortion
  result = proc(x, y, time: int): (float, float) =
    let t = time div 5
    let noiseX = if animateX: fractalNoise2D(x + t, y, 3, scale, seed) else: 
                              fractalNoise2D(x, y, 3, scale, seed)
    let noiseY = if animateY: fractalNoise2D(x, y + t, 3, scale, seed + 1000) else:
                              fractalNoise2D(x, y, 3, scale, seed + 1000)
    
    let dx = (float(noiseX) / 32768.0 - 1.0) * amplitude
    let dy = (float(noiseY) / 32768.0 - 1.0) * amplitude
    (dx, dy)

proc heatHazeDisplacement*(amplitude: float = 1.0, frequency: float = 0.3,
                           speed: float = 0.08, seed: int = 42): DisplacementFunc =
  ## Heat haze effect - wavy vertical distortion like hot air
  result = proc(x, y, time: int): (float, float) =
    let noise = float(intHash2D(x div 3, time div 10, seed)) / 65536.0
    let wave = sin(float(y) * frequency + float(time) * speed + noise * 10.0)
    let dx = wave * amplitude
    let dy = noise * amplitude * 0.3
    (dx, dy)

proc swirlDisplacement*(centerX, centerY: int, strength: float = 0.5,
                        radius: float = 20.0): DisplacementFunc =
  ## Swirl/vortex displacement - rotates pixels around center
  result = proc(x, y, time: int): (float, float) =
    let dx = float(x - centerX)
    let dy = float(y - centerY)
    let distance = sqrt(dx * dx + dy * dy)
    
    if distance > radius or distance < 0.1:
      return (0.0, 0.0)
    
    let angle = float(time) * 0.05 * strength * (1.0 - distance / radius)
    let cosA = cos(angle)
    let sinA = sin(angle)
    
    let rotX = dx * cosA - dy * sinA
    let rotY = dx * sinA + dy * cosA
    
    (rotX - dx, rotY - dy)

proc fisheyeDisplacement*(centerX, centerY: int, strength: float = 0.3,
                          radius: float = 30.0): DisplacementFunc =
  ## Fisheye lens distortion
  result = proc(x, y, time: int): (float, float) =
    let dx = float(x - centerX)
    let dy = float(y - centerY)
    let distance = sqrt(dx * dx + dy * dy)
    
    if distance > radius or distance < 0.1:
      return (0.0, 0.0)
    
    let amount = strength * (1.0 - distance / radius)
    let scale = 1.0 + amount
    
    (dx * scale - dx, dy * scale - dy)

proc bulgeDisplacement*(centerX, centerY: int, strength: float = 0.5,
                        radius: float = 15.0, time: int = 0): DisplacementFunc =
  ## Bulge/pinch effect - can be animated by passing time
  result = proc(x, y, t: int): (float, float) =
    let dx = float(x - centerX)
    let dy = float(y - centerY)
    let distance = sqrt(dx * dx + dy * dy)
    
    if distance > radius or distance < 0.1:
      return (0.0, 0.0)
    
    let pulse = if time > 0: (1.0 + sin(float(t) * 0.1) * 0.3) else: 1.0
    let amount = strength * pulse * (1.0 - distance / radius) * (1.0 - distance / radius)
    
    (dx * amount, dy * amount)

proc scrollDisplacement*(dx: float = 0.0, dy: float = 0.0): DisplacementFunc =
  ## Simple scroll/offset - useful for parallax effects
  result = proc(x, y, time: int): (float, float) =
    (dx * float(time) * 0.1, dy * float(time) * 0.1)

proc multiDisplacement*(displacements: varargs[DisplacementFunc]): DisplacementFunc =
  ## Combine multiple displacement effects additively
  result = proc(x, y, time: int): (float, float) =
    var totalDx = 0.0
    var totalDy = 0.0
    for disp in displacements:
      let (dx, dy) = disp(x, y, time)
      totalDx += dx
      totalDy += dy
    (totalDx, totalDy)

# ==============================================================================
# CORE SHADER EFFECTS
# ==============================================================================

proc rippleShader*(centerX, centerY: int, speed: float = 0.1, frequency: float = 0.3, 
                   ramp: seq[string] = @DENSITY_SMOOTH,
                   colorFunc: proc(v: int): Color = heatmap): ShaderFunc =
  ## Animated ripple effect emanating from a center point
  result = proc(x, y, time: int): ShaderPixel =
    let d = dist(x, y, centerX, centerY)
    let wave = sin(float(d) * frequency - float(time) * speed)
    let value = int((wave + 1.0) * 0.5 * float(len(ramp) - 1))
    let colorValue = int((wave + 1.0) * 127.5)
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc plasmaShader*(scale: float = 0.15, speed: float = 0.05,
                   ramp: seq[string] = @DENSITY_SMOOTH,
                   colorFunc: proc(v: int): Color = plasma): ShaderFunc =
  ## Classic plasma effect with sine waves
  result = proc(x, y, time: int): ShaderPixel =
    let fx = float(x)
    let fy = float(y)
    let ft = float(time)
    
    let v1 = sin(fx * scale + ft * speed)
    let v2 = sin(fy * scale + ft * speed)
    let v3 = sin((fx + fy) * scale * 0.5 + ft * speed)
    let v4 = sin(sqrt(fx * fx + fy * fy) * scale + ft * speed)
    
    let plasma = (v1 + v2 + v3 + v4) / 4.0
    let value = int((plasma + 1.0) * 0.5 * float(len(ramp) - 1))
    let colorValue = int((plasma + 1.0) * 127.5)
    
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc noiseShader*(scale: int = 10, seed: int = 42,
                  ramp: seq[string] = @DENSITY_ASCII,
                  colorFunc: proc(v: int): Color = grayscale): ShaderFunc =
  ## Static noise pattern (no animation)
  result = proc(x, y, time: int): ShaderPixel =
    let noise = intHash2D(x div scale, y div scale, seed)
    let value = (noise * len(ramp)) div 65536
    let colorValue = noise div 256
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc fractalNoiseShader*(scale: int = 50, octaves: int = 4, seed: int = 42,
                         animate: bool = true,
                         ramp: seq[string] = @DENSITY_BRAILLE,
                         colorFunc: proc(v: int): Color = coolWarm): ShaderFunc =
  ## Smooth fractal noise (Perlin-like)
  result = proc(x, y, time: int): ShaderPixel =
    let t = if animate: time div 10 else: 0
    let noise = fractalNoise2D(x + t, y, octaves, scale, seed)
    let value = (noise * len(ramp)) div 65536
    let colorValue = noise div 256
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc waveShader*(horizontal: bool = true, frequency: float = 0.2, speed: float = 0.1,
                 ramp: seq[string] = @DENSITY_BLOCKS,
                 colorFunc: proc(v: int): Color = ocean): ShaderFunc =
  ## Simple directional wave
  result = proc(x, y, time: int): ShaderPixel =
    let pos = if horizontal: float(x) else: float(y)
    let wave = sin(pos * frequency + float(time) * speed)
    let value = int((wave + 1.0) * 0.5 * float(len(ramp) - 1))
    let colorValue = int((wave + 1.0) * 127.5)
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc tunnelShader*(centerX, centerY: int, speed: float = 0.05,
                   ramp: seq[string] = @DENSITY_TECH,
                   colorFunc: proc(v: int): Color = neon): ShaderFunc =
  ## Rotating tunnel effect
  result = proc(x, y, time: int): ShaderPixel =
    let dx = float(x - centerX)
    let dy = float(y - centerY)
    let dist = sqrt(dx * dx + dy * dy)
    let angle = arctan2(dy, dx)
    
    let tunnel = sin(dist * 0.2 - float(time) * speed) + sin(angle * 5.0 + float(time) * speed)
    let value = int((tunnel + 2.0) * 0.25 * float(len(ramp) - 1))
    let colorValue = int((tunnel + 2.0) * 63.75)
    
    ShaderPixel(
      char: ramp[clamp(value, 0, len(ramp) - 1)],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc matrixRainShader*(speed: float = 0.5, density: float = 0.1, seed: int = 42,
                       ramp: seq[string] = @DENSITY_ASCII,
                       colorFunc: proc(v: int): Color = matrix): ShaderFunc =
  ## Matrix-style falling characters
  result = proc(x, y, time: int): ShaderPixel =
    let columnSeed = intHash(x, seed)
    let dropStart = (intHash(x, seed + 1) + int(float(time) * speed)) mod 100
    let dropPos = (dropStart * 2) mod 200 - 100
    let dist = abs(y - dropPos)
    
    if dist < 10 and intHash2D(x, y, seed) mod 100 < int(density * 100.0):
      let brightness = 255 - dist * 20
      let charIdx = intHash3D(x, y, time div 2, seed) mod len(ramp)
      ShaderPixel(
        char: ramp[charIdx],
        fg: colorFunc(brightness),
        bg: Color(r: 0, g: 0, b: 0)
      )
    else:
      ShaderPixel(char: " ", fg: Color(r: 0, g: 0, b: 0), bg: Color(r: 0, g: 0, b: 0))

proc fireShader*(bottomY: int, intensity: float = 1.0, seed: int = 42,
                 ramp: seq[string] = @DENSITY_SMOOTH,
                 colorFunc: proc(v: int): Color = fire): ShaderFunc =
  ## Rising fire effect
  result = proc(x, y, time: int): ShaderPixel =
    let distFromBottom = bottomY - y
    if distFromBottom < 0:
      return ShaderPixel(char: " ", fg: Color(r: 0, g: 0, b: 0), bg: Color(r: 0, g: 0, b: 0))
    
    let turbulence = intHash3D(x div 2, y div 2, time div 3, seed) mod 100
    let heat = int((float(distFromBottom) + float(turbulence) * 0.5) * intensity)
    let value = clamp(heat div 10, 0, len(ramp) - 1)
    let colorValue = clamp(255 - distFromBottom * 10 + turbulence, 0, 255)
    
    ShaderPixel(
      char: ramp[value],
      fg: colorFunc(colorValue),
      bg: Color(r: 0, g: 0, b: 0)
    )

proc checkerboardShader*(size: int = 4,
                         color1: Color = Color(r: 255, g: 255, b: 255),
                         color2: Color = Color(r: 0, g: 0, b: 0),
                         char1: string = "█",
                         char2: string = " "): ShaderFunc =
  ## Simple checkerboard pattern
  result = proc(x, y, time: int): ShaderPixel =
    if ((x div size) + (y div size)) mod 2 == 0:
      ShaderPixel(char: char1, fg: color1, bg: Color(r: 0, g: 0, b: 0))
    else:
      ShaderPixel(char: char2, fg: color2, bg: Color(r: 0, g: 0, b: 0))

# ==============================================================================
# SHADER COMBINATORS
# ==============================================================================

proc blendShader*(shader1, shader2: ShaderFunc, mixAmount: float = 0.5): ShaderFunc =
  ## Blend two shaders together
  result = proc(x, y, time: int): ShaderPixel =
    let p1 = shader1(x, y, time)
    let p2 = shader2(x, y, time)
    
    # Simple blend - could be more sophisticated
    if intHash2D(x, y, time) mod 100 < int(mixAmount * 100.0):
      p2
    else:
      p1

proc layerShader*(base, overlay: ShaderFunc): ShaderFunc =
  ## Layer one shader over another (overlay replaces where it's not empty)
  result = proc(x, y, time: int): ShaderPixel =
    let overlayPixel = overlay(x, y, time)
    if overlayPixel.char == " ":
      base(x, y, time)
    else:
      overlayPixel

# ==============================================================================
# NATIVE RENDERING FUNCTIONS
# ==============================================================================

proc renderPlasma*(buffer: var TermBuffer, x, y, width, height, frame: int, 
                   scale: float = 0.15, speed: float = 0.05, reduction: int = 1) =
  ## Render plasma effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  
  for row in 0..<rh:
    for col in 0..<rw:
      let fx = float(col * r)
      let fy = float(row * r)
      let ft = float(frame)
      
      let v1 = sin(fx * scale + ft * speed)
      let v2 = sin(fy * scale + ft * speed)
      let v3 = sin((fx + fy) * scale * 0.5 + ft * speed)
      let v4 = sin(sqrt(fx * fx + fy * fy) * scale + ft * speed)
      
      let plasma = (v1 + v2 + v3 + v4) / 4.0
      let value = int((plasma + 1.0) * 2.5)
      
      var char = " "
      if value >= 4: char = "█"
      elif value >= 3: char = "▓"
      elif value >= 2: char = "▒"
      elif value >= 1: char = "░"
      
      # Rainbow color
      let angle = (plasma + 1.0) * PI
      let color = plasma(int((plasma + 1.0) * 127.5))
      
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderRipple*(buffer: var TermBuffer, x, y, width, height, frame: int,
                   centerX, centerY: int, speed: float = 0.1, frequency: float = 0.3, reduction: int = 1) =
  ## Render ripple effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  let rcx = centerX div r
  let rcy = centerY div r
  
  for row in 0..<rh:
    for col in 0..<rw:
      let dx = col - rcx
      let dy = row - rcy
      let d = sqrt(float(dx * dx + dy * dy))
      let wave = sin(d * frequency - float(frame) * speed)
      let value = int((wave + 1.0) * 2.5)
      
      var char = " "
      if value >= 4: char = "█"
      elif value >= 3: char = "▓"
      elif value >= 2: char = "▒"
      elif value >= 1: char = "░"
      
      let color = heatmap(int((wave + 1.0) * 127.5))
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderFire*(buffer: var TermBuffer, x, y, width, height, frame: int,
                 intensity: float = 1.0, seed: int = 42, reduction: int = 1) =
  ## Render fire effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  
  for row in 0..<rh:
    let distFromBottom = rh - row - 1
    if distFromBottom < 0: continue
    
    for col in 0..<rw:
      let turbulence = intHash3D(col div 2, row div 2, frame div 3, seed) mod 100
      let heat = int((float(distFromBottom) + float(turbulence) * 0.5) * intensity)
      let value = clamp(heat div 10, 0, 4)
      
      var char = " "
      if value >= 4: char = "█"
      elif value >= 3: char = "▒"
      elif value >= 2: char = ":"
      elif value >= 1: char = "."
      
      let colorValue = clamp(255 - distFromBottom * 10 + turbulence, 0, 255)
      let color = fire(colorValue)
      
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderFractalNoise*(buffer: var TermBuffer, x, y, width, height, frame: int,
                         scale: int = 30, octaves: int = 4, seed: int = 42, reduction: int = 1) =
  ## Render fractal noise effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  
  for row in 0..<rh:
    for col in 0..<rw:
      let t = frame div 10
      let noise = fractalNoise2D((col * r) + t, row * r, octaves, scale, seed)
      # Avoid overflow by dividing first: (noise * 5) / 65536 = noise / 13107
      let value = clamp(noise div 13107, 0, 4)
      
      var char = " "
      if value >= 4: char = "⣿"
      elif value >= 3: char = "⣧"
      elif value >= 2: char = "⣇"
      elif value >= 1: char = "⡇"
      
      let colorValue = clamp(noise div 256, 0, 255)
      let color = coolWarm(colorValue)
      
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderWave*(buffer: var TermBuffer, x, y, width, height, frame: int,
                 frequency: float = 0.3, speed: float = 0.1, reduction: int = 1) =
  ## Render wave effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  
  for row in 0..<rh:
    for col in 0..<rw:
      let wave = sin(float(col * r) * frequency + float(frame) * speed)
      let value = int((wave + 1.0) * 4.5)
      
      var char = " "
      if value >= 8: char = "█"
      elif value >= 7: char = "▇"
      elif value >= 6: char = "▆"
      elif value >= 5: char = "▅"
      elif value >= 4: char = "▄"
      elif value >= 3: char = "▃"
      elif value >= 2: char = "▂"
      elif value >= 1: char = "▁"
      
      let color = ocean(int((wave + 1.0) * 127.5))
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderTunnel*(buffer: var TermBuffer, x, y, width, height, frame: int,
                   centerX, centerY: int, speed: float = 0.05, reduction: int = 1) =
  ## Render tunnel effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  let rcx = centerX div r
  let rcy = centerY div r
  
  for row in 0..<rh:
    for col in 0..<rw:
      let dx = float(col - rcx)
      let dy = float(row - rcy)
      let dist = sqrt(dx * dx + dy * dy)
      let angle = arctan2(dy, dx)
      
      let tunnel = sin(dist * 0.2 - float(frame) * speed) + sin(angle * 5.0 + float(frame) * speed)
      let value = int((tunnel + 2.0) * 1.25)
      
      var char = " "
      if value >= 4: char = "▬"
      elif value >= 3: char = "▫"
      elif value >= 2: char = "▪"
      elif value >= 1: char = "+"
      
      let colorValue = int((tunnel + 2.0) * 63.75)
      let color = neon(colorValue)
      
      let style = Style(
        fg: color,
        bg: Color(r: 0, g: 0, b: 0),
        bold: false, underline: false, italic: false, dim: false
      )
      
      # Draw block for reduced resolution
      for dy in 0..<r:
        for dx in 0..<r:
          if col * r + dx < width and row * r + dy < height:
            buffer.write(x + col * r + dx, y + row * r + dy, char, style)

proc renderMatrixRain*(buffer: var TermBuffer, x, y, width, height, frame: int,
                       speed: float = 0.5, density: float = 0.1, seed: int = 42, reduction: int = 1) =
  ## Render matrix rain effect directly to buffer
  let r = max(1, reduction)
  let rw = width div r
  let rh = height div r
  
  for col in 0..<rw:
    let dropStart = (intHash(col, seed + 1) + int(float(frame) * speed)) mod 100
    let dropPos = (dropStart * 2) mod 200 - 100
    
    for row in 0..<rh:
      let distFromDrop = abs(row - dropPos)
      
      if distFromDrop < 10 and intHash2D(col, row, seed) mod 100 < int(density * 100.0):
        let brightness = 255 - distFromDrop * 20
        let charIdx = intHash3D(col, row, frame div 2, seed) mod 10
        
        var char = " "
        if charIdx < 2: char = "."
        elif charIdx < 4: char = ":"
        elif charIdx < 6: char = "="
        elif charIdx < 8: char = "+"
        else: char = "#"
        
        let color = matrix(brightness)
        let style = Style(
          fg: color,
          bg: Color(r: 0, g: 0, b: 0),
          bold: false, underline: false, italic: false, dim: false
        )
        
        # Draw block for reduced resolution
        for dy in 0..<r:
          for dx in 0..<r:
            if col * r + dx < width and row * r + dy < height:
              buffer.write(x + col * r + dx, y + row * r + dy, char, style)
      else:
        # Clear with transparent
        let style = Style(
          fg: Color(r: 0, g: 0, b: 0),
          bg: Color(r: 0, g: 0, b: 0),
          bold: false, underline: false, italic: false, dim: false
        )
        
        # Draw block for reduced resolution
        for dy in 0..<r:
          for dx in 0..<r:
            if col * r + dx < width and row * r + dy < height:
              buffer.write(x + col * r + dx, y + row * r + dy, " ", style)

# ==============================================================================
# DISPLACEMENT RENDERING
# ==============================================================================

proc applyDisplacement*(destBuffer: var TermBuffer, sourceBuffer: TermBuffer,
                        x, y, width, height: int,
                        displacement: DisplacementFunc,
                        time: int,
                        intensity: float = 1.0,
                        clampEdges: bool = true) =
  ## Apply displacement effect to buffer contents
  ## Reads from sourceBuffer and writes displaced content to destBuffer
  ## 
  ## Parameters:
  ##   destBuffer: Target buffer to write to
  ##   sourceBuffer: Source buffer to read from
  ##   x, y: Top-left corner of region
  ##   width, height: Size of region
  ##   displacement: Displacement function
  ##   time: Animation frame
  ##   intensity: Multiplier for displacement strength (0.0 to 1.0+)
  ##   clampEdges: If true, clamp to edges; if false, wrap around
  
  for row in 0..<height:
    for col in 0..<width:
      let screenX = x + col
      let screenY = y + row
      
      # Calculate displacement
      let (rawDx, rawDy) = displacement(col, row, time)
      let dx = rawDx * intensity
      let dy = rawDy * intensity
      
      # Source position (with displacement)
      let srcX = col + int(dx)
      let srcY = row + int(dy)
      
      # Handle bounds
      var finalSrcX = srcX
      var finalSrcY = srcY
      
      if clampEdges:
        finalSrcX = clamp(srcX, 0, width - 1)
        finalSrcY = clamp(srcY, 0, height - 1)
      else:
        # Wrap around
        finalSrcX = ((srcX mod width) + width) mod width
        finalSrcY = ((srcY mod height) + height) mod height
      
      # Read from source buffer (relative to region)
      let srcScreenX = x + finalSrcX
      let srcScreenY = y + finalSrcY
      
      # Bounds check for source buffer
      if srcScreenX >= 0 and srcScreenX < sourceBuffer.width and
         srcScreenY >= 0 and srcScreenY < sourceBuffer.height:
        let srcCell = sourceBuffer.getCell(srcScreenX, srcScreenY)
        # Write to destination
        destBuffer.write(screenX, screenY, srcCell.ch, srcCell.style)

proc applyDisplacementInPlace*(buffer: var TermBuffer,
                               x, y, width, height: int,
                               displacement: DisplacementFunc,
                               time: int,
                               intensity: float = 1.0) =
  ## Apply displacement effect in-place (creates temporary copy)
  ## Less efficient but more convenient for simple cases
  
  # Create temporary buffer with just the region we need
  var tempBuffer = newTermBuffer(width, height)
  
  # Copy region to temp buffer
  for row in 0..<height:
    for col in 0..<width:
      let cell = buffer.getCell(x + col, y + row)
      tempBuffer.write(col, row, cell.ch, cell.style)
  
  # Apply displacement from temp buffer back to original
  for row in 0..<height:
    for col in 0..<width:
      let screenX = x + col
      let screenY = y + row
      
      let (rawDx, rawDy) = displacement(col, row, time)
      let dx = rawDx * intensity
      let dy = rawDy * intensity
      
      let srcX = clamp(col + int(dx), 0, width - 1)
      let srcY = clamp(row + int(dy), 0, height - 1)
      
      let srcCell = tempBuffer.getCell(srcX, srcY)
      buffer.write(screenX, screenY, srcCell.ch, srcCell.style)

proc applyDisplacementFromLayer*(destBuffer: var TermBuffer, 
                                  sourceBuffer: TermBuffer,
                                  displacementBuffer: TermBuffer,
                                  x, y, width, height: int,
                                  strength: float = 1.0,
                                  mode: int = 0) =
  ## Apply displacement using another layer's content as displacement map
  ## 
  ## The brightness/intensity of cells in displacementBuffer determines how much
  ## to displace the content from sourceBuffer when writing to destBuffer.
  ## 
  ## Parameters:
  ##   destBuffer: Target buffer to write displaced content to
  ##   sourceBuffer: Source buffer to read content from
  ##   displacementBuffer: Buffer whose content drives the displacement
  ##   x, y: Top-left corner of region
  ##   width, height: Size of region
  ##   strength: Multiplier for displacement amount (0.0 to 1.0+)
  ##   mode: 0=vertical displacement, 1=radial, 2=horizontal, 3=both axes
  
  for row in 0..<height:
    for col in 0..<width:
      let screenX = x + col
      let screenY = y + row
      
      # Sample displacement buffer to get intensity at this position
      if screenX >= 0 and screenX < displacementBuffer.width and
         screenY >= 0 and screenY < displacementBuffer.height:
        let dispCell = displacementBuffer.getCell(screenX, screenY)
        
        # Calculate luminance from color (0-255)
        # Only displace where there's visible content
        let luminance = if dispCell.ch == " ": 
          0
        else:
          (int(dispCell.style.fg.r) + int(dispCell.style.fg.g) + int(dispCell.style.fg.b)) div 3
        
        if luminance > 10:  # Threshold to avoid displacing on dark/empty areas
          # Normalize luminance to 0.0-1.0
          let intensity = float(luminance) / 255.0
          
          # Calculate displacement based on mode
          var dx = 0.0
          var dy = 0.0
          
          case mode
          of 0:  # Vertical displacement (like rain falling)
            dy = intensity * strength * 3.0
          of 1:  # Radial displacement from center
            let centerX = width div 2
            let centerY = height div 2
            let dirX = float(col - centerX)
            let dirY = float(row - centerY)
            let dist = sqrt(dirX * dirX + dirY * dirY)
            if dist > 0.1:
              dx = (dirX / dist) * intensity * strength * 2.0
              dy = (dirY / dist) * intensity * strength * 2.0
          of 2:  # Horizontal displacement
            dx = intensity * strength * 3.0
          of 3:  # Both axes (creates a ripple-like effect)
            dx = intensity * strength * 2.0
            dy = intensity * strength * 2.0
          else:
            dy = intensity * strength * 3.0
          
          # Sample from source with displacement
          let srcX = clamp(col + int(dx), 0, width - 1)
          let srcY = clamp(row + int(dy), 0, height - 1)
          let srcScreenX = x + srcX
          let srcScreenY = y + srcY
          
          if srcScreenX >= 0 and srcScreenX < sourceBuffer.width and
             srcScreenY >= 0 and srcScreenY < sourceBuffer.height:
            let srcCell = sourceBuffer.getCell(srcScreenX, srcScreenY)
            destBuffer.write(screenX, screenY, srcCell.ch, srcCell.style)
        else:
          # No displacement, copy directly
          if screenX >= 0 and screenX < sourceBuffer.width and
             screenY >= 0 and screenY < sourceBuffer.height:
            let srcCell = sourceBuffer.getCell(screenX, screenY)
            destBuffer.write(screenX, screenY, srcCell.ch, srcCell.style)
  ##   x, y: Top-left corner of region
  ##   width, height: Size of region
  ##   strength: Displacement strength multiplier (typical: 0.5 to 2.0)
  ##   mode: Displacement mode (0=radial, 1=horizontal, 2=vertical, 3=both)
  
  for row in 0..<height:
    for col in 0..<width:
      let screenX = x + col
      let screenY = y + row
      
      # Sample displacement map cell
      if screenX >= 0 and screenX < displacementBuffer.width and
         screenY >= 0 and screenY < displacementBuffer.height:
        let dispCell = displacementBuffer.getCell(screenX, screenY)
        
        # Calculate brightness from RGB (simple average)
        let brightness = float(int(dispCell.style.fg.r) + 
                               int(dispCell.style.fg.g) + 
                               int(dispCell.style.fg.b)) / 3.0
        
        # Normalize to 0..1 range
        let intensity = brightness / 255.0
        
        # Only displace if there's visible content (not just space)
        var dx = 0.0
        var dy = 0.0
        
        if dispCell.ch != " " and intensity > 0.1:
          # Calculate displacement based on mode
          case mode
          of 0: # Radial - push away from bright spots
            let centerX = width / 2
            let centerY = height / 2
            let dirX = float(col) - centerX
            let dirY = float(row) - centerY
            let dist = sqrt(dirX * dirX + dirY * dirY)
            if dist > 0.1:
              dx = (dirX / dist) * intensity * strength
              dy = (dirY / dist) * intensity * strength
          of 1: # Horizontal only
            dx = (intensity - 0.5) * strength * 2.0
          of 2: # Vertical only
            dy = (intensity - 0.5) * strength * 2.0
          of 3: # Both directions (push outward from cell)
            # Use position within cell for direction
            dx = (intensity - 0.5) * strength
            dy = (intensity - 0.5) * strength
          else:
            discard
        
        # Apply displacement
        let srcX = clamp(col + int(dx), 0, width - 1)
        let srcY = clamp(row + int(dy), 0, height - 1)
        
        # Read from source buffer
        let srcScreenX = x + srcX
        let srcScreenY = y + srcY
        
        if srcScreenX >= 0 and srcScreenX < sourceBuffer.width and
           srcScreenY >= 0 and srcScreenY < sourceBuffer.height:
          let srcCell = sourceBuffer.getCell(srcScreenX, srcScreenY)
          destBuffer.write(screenX, screenY, srcCell.ch, srcCell.style)

# ==============================================================================
# HIGH-LEVEL API FOR NIMINI
# ==============================================================================

proc initShader*(effectId: int, layerId: int, x, y, width, height: int, reduction: int = 1) =
  ## Initialize shader state
  ## reduction: resolution divisor (1=full res, 2=half res, 4=quarter res, etc.)
  gShaderState = ShaderState(
    effectId: effectId,
    layerId: layerId,
    x: x,
    y: y,
    width: width,
    height: height,
    frame: 0,
    paused: false,
    reduction: max(1, reduction)
  )

proc updateShader*() =
  ## Update shader animation (call in on:update)
  if gShaderState != nil and not gShaderState.paused:
    gShaderState.frame += 1

proc pauseShader*() =
  ## Pause shader animation
  if gShaderState != nil:
    gShaderState.paused = true

proc resumeShader*() =
  ## Resume shader animation
  if gShaderState != nil:
    gShaderState.paused = false

proc resetShader*() =
  ## Reset shader to frame 0
  if gShaderState != nil:
    gShaderState.frame = 0

proc setShaderEffect*(effectId: int) =
  ## Change shader effect
  if gShaderState != nil:
    gShaderState.effectId = effectId
    gShaderState.frame = 0

proc drawShader*(buffer: var TermBuffer) =
  ## Render current shader to buffer (call in on:render)
  if gShaderState == nil:
    return
  
  let r = gShaderState.reduction
  case gShaderState.effectId
  of 0: # Plasma
    renderPlasma(buffer, gShaderState.x, gShaderState.y, 
                 gShaderState.width, gShaderState.height, gShaderState.frame,
                 reduction = r)
  of 1: # Ripple
    renderRipple(buffer, gShaderState.x, gShaderState.y,
                 gShaderState.width, gShaderState.height, gShaderState.frame,
                 gShaderState.width div 2, gShaderState.height div 2,
                 reduction = r)
  of 2: # Fire
    renderFire(buffer, gShaderState.x, gShaderState.y,
               gShaderState.width, gShaderState.height, gShaderState.frame,
               reduction = r)
  of 3: # Fractal Noise
    renderFractalNoise(buffer, gShaderState.x, gShaderState.y,
                       gShaderState.width, gShaderState.height, gShaderState.frame,
                       reduction = r)
  of 4: # Wave
    renderWave(buffer, gShaderState.x, gShaderState.y,
               gShaderState.width, gShaderState.height, gShaderState.frame,
               reduction = r)
  of 5: # Tunnel
    renderTunnel(buffer, gShaderState.x, gShaderState.y,
                 gShaderState.width, gShaderState.height, gShaderState.frame,
                 gShaderState.width div 2, gShaderState.height div 2,
                 reduction = r)
  of 6: # Matrix Rain
    renderMatrixRain(buffer, gShaderState.x, gShaderState.y,
                     gShaderState.width, gShaderState.height, gShaderState.frame,
                     reduction = r)
  else:
    discard

# ==============================================================================
# DISPLACEMENT API FOR NIMINI
# ==============================================================================

proc initDisplacement*(effectId: int, layerId: int, x, y, width, height: int, 
                       intensity: float = 1.0, speed: float = 1.0, amplitude: float = 1.0) =
  ## Initialize displacement effect state
  ## effectId: Which displacement effect to use (0=wave, 1=ripple, 2=noise, etc.)
  ## intensity: Displacement strength multiplier (0.0 to 1.0+)
  ## speed: Animation speed multiplier (default 1.0, lower = slower)
  ## amplitude: Base displacement amount in cells (default 1.0, try 0.1-0.3 for subtle)
  gDisplacementState = DisplacementState(
    effectId: effectId,
    layerId: layerId,
    x: x,
    y: y,
    width: width,
    height: height,
    frame: 0,
    paused: false,
    intensity: intensity,
    speed: speed,
    amplitude: amplitude
  )

proc updateDisplacement*() =
  ## Update displacement animation (call in on:update)
  if gDisplacementState != nil and not gDisplacementState.paused:
    gDisplacementState.frame += 1

proc pauseDisplacement*() =
  ## Pause displacement animation
  if gDisplacementState != nil:
    gDisplacementState.paused = true

proc resumeDisplacement*() =
  ## Resume displacement animation
  if gDisplacementState != nil:
    gDisplacementState.paused = false

proc resetDisplacement*() =
  ## Reset displacement to frame 0
  if gDisplacementState != nil:
    gDisplacementState.frame = 0

proc setDisplacementEffect*(effectId: int) =
  ## Change displacement effect
  if gDisplacementState != nil:
    gDisplacementState.effectId = effectId
    gDisplacementState.frame = 0

proc setDisplacementIntensity*(intensity: float) =
  ## Change displacement intensity
  if gDisplacementState != nil:
    gDisplacementState.intensity = intensity

proc setDisplacementSpeed*(speed: float) =
  ## Change displacement animation speed (1.0 = normal, 0.5 = half speed, 2.0 = double speed)
  if gDisplacementState != nil:
    gDisplacementState.speed = speed

proc setDisplacementAmplitude*(amplitude: float) =
  ## Change displacement amplitude (1.0 = normal, 0.3 = subtle, 0.1 = very subtle)
  if gDisplacementState != nil:
    gDisplacementState.amplitude = amplitude

proc drawDisplacement*(buffer, sourceBuffer: var TermBuffer) =
  ## Apply current displacement effect to buffer (call in on:render)
  ## Reads from sourceBuffer and writes displaced content to buffer
  if gDisplacementState == nil:
    return
  
  var displacement: DisplacementFunc
  
  # Scale frame by speed for animation control
  let scaledFrame = int(float(gDisplacementState.frame) * gDisplacementState.speed)
  
  case gDisplacementState.effectId
  of 0: # Horizontal wave
    displacement = waveDisplacement(amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.2, speed = 0.1, vertical = false)
  of 1: # Vertical wave
    displacement = waveDisplacement(amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.2, speed = 0.1, vertical = true)
  of 2: # Ripple (center)
    displacement = rippleDisplacement(
      gDisplacementState.width div 2, 
      gDisplacementState.height div 2,
      amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.3, speed = 0.1
    )
  of 3: # Noise distortion
    displacement = noiseDisplacement(scale = 20, amplitude = 1.5 * gDisplacementState.amplitude)
  of 4: # Heat haze
    displacement = heatHazeDisplacement(amplitude = 1.0 * gDisplacementState.amplitude, frequency = 0.3, speed = 0.08)
  of 5: # Swirl (center)
    displacement = swirlDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.5 * gDisplacementState.amplitude, radius = 20.0
    )
  of 6: # Fisheye (center)
    displacement = fisheyeDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.3 * gDisplacementState.amplitude, radius = 30.0
    )
  of 7: # Bulge (center, animated)
    displacement = bulgeDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.5 * gDisplacementState.amplitude, radius = 15.0, time = scaledFrame
    )
  else:
    return  # Unknown effect
  
  applyDisplacement(
    buffer, sourceBuffer,
    gDisplacementState.x, gDisplacementState.y,
    gDisplacementState.width, gDisplacementState.height,
    displacement,
    scaledFrame,
    gDisplacementState.intensity
  )

proc drawDisplacementInPlace*(buffer: var TermBuffer) =
  ## Apply current displacement effect in-place (call in on:render)
  ## Creates temporary buffer - less efficient but more convenient
  if gDisplacementState == nil:
    return
  
  # Scale frame by speed for animation control
  let scaledFrame = int(float(gDisplacementState.frame) * gDisplacementState.speed)
  
  var displacement: DisplacementFunc
  
  case gDisplacementState.effectId
  of 0: # Horizontal wave
    displacement = waveDisplacement(amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.2, speed = 0.1, vertical = false)
  of 1: # Vertical wave
    displacement = waveDisplacement(amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.2, speed = 0.1, vertical = true)
  of 2: # Ripple
    displacement = rippleDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      amplitude = 2.0 * gDisplacementState.amplitude, frequency = 0.3, speed = 0.1
    )
  of 3: # Noise
    displacement = noiseDisplacement(scale = 20, amplitude = 1.5 * gDisplacementState.amplitude)
  of 4: # Heat haze
    displacement = heatHazeDisplacement(amplitude = 1.0 * gDisplacementState.amplitude, frequency = 0.3, speed = 0.08)
  of 5: # Swirl
    displacement = swirlDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.5 * gDisplacementState.amplitude, radius = 20.0
    )
  of 6: # Fisheye
    displacement = fisheyeDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.3 * gDisplacementState.amplitude, radius = 30.0
    )
  of 7: # Bulge (animated)
    displacement = bulgeDisplacement(
      gDisplacementState.width div 2,
      gDisplacementState.height div 2,
      strength = 0.5 * gDisplacementState.amplitude, radius = 15.0, time = scaledFrame
    )
  else:
    return
  
  applyDisplacementInPlace(
    buffer,
    gDisplacementState.x, gDisplacementState.y,
    gDisplacementState.width, gDisplacementState.height,
    displacement,
    scaledFrame,
    gDisplacementState.intensity
  )

# ==============================================================================
# LEGACY UTILITY FUNCTIONS
# ==============================================================================

proc renderShaderToString*(shader: ShaderFunc, width, height, time: int): string =
  ## Render a shader to a string with ANSI color codes
  result = ""
  for y in 0..<height:
    for x in 0..<width:
      let pixel = shader(x, y, time)
      # Add ANSI color codes
      result.add("\x1b[38;2;" & $pixel.fg.r & ";" & $pixel.fg.g & ";" & $pixel.fg.b & "m")
      result.add(pixel.char)
    result.add("\x1b[0m\n")  # Reset color and newline
