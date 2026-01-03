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
import procgen_primitives

when not declared(Color):
  import ../src/types
  import ../src/layers

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
    
var gShaderState*: ShaderState = nil

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
# SHADER OUTPUT TYPE
# ==============================================================================

type
  ShaderPixel* = object
    ## The result of a shader computation for one cell
    char*: string
    fg*: Color
    bg*: Color

  ShaderFunc* = proc(x, y, time: int): ShaderPixel {.closure.}
    ## A shader function takes position (x, y) and time, returns a pixel

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
