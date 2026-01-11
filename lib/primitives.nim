## Primitives - The Foundation of tStorie
## 
## A comprehensive library of deterministic primitives for building
## visual effects, audio synthesis, procedural generation, transitions,
## and any other computational creative tasks.
##
## Designed like nodes in a visual programming system (TiXL/Tool3 style).
## All functions are deterministic and produce identical results in
## both native Nim and nimini scripted implementations.
##
## IMPORTANT: This library uses INTEGER MATH for deterministic generation.
## For float-based visual animations, use lib/animation.nim instead.
## See ANIMATION_VS_PROCGEN_EASING.md for detailed comparison.
##
## Design principles:
## - Pure functions (no side effects)
## - Integer math where possible (no float drift)
## - Composable (outputs feed into other primitives)
## - Small, single-responsibility operations
## - Universal applicability (shaders, audio, particles, transitions, etc.)

import std/[random, math]

## ============================================================================
## MATH PRIMITIVES
## Pure integer math operations guaranteed to behave identically
## ============================================================================

proc idiv*(a, b: int): int {.exportc: "pgIdiv".} =
  ## Integer division (no float conversion)
  ## Examples: idiv(5, 2) = 2, idiv(-5, 2) = -3
  result = a div b

proc imod*(a, b: int): int {.exportc: "pgImod".} =
  ## Integer modulo
  ## Examples: imod(5, 3) = 2, imod(-5, 3) = 1
  result = a mod b

proc iabs*(a: int): int {.exportc: "pgIabs".} =
  ## Absolute value
  ## Examples: iabs(-5) = 5, iabs(5) = 5
  result = abs(a)

proc sign*(a: int): int {.exportc: "pgSign".} =
  ## Sign function: returns -1, 0, or 1
  ## Examples: sign(-5) = -1, sign(0) = 0, sign(5) = 1
  if a < 0: -1
  elif a > 0: 1
  else: 0

proc clamp*(v, min, max: int): int {.exportc: "pgClamp".} =
  ## Clamp value to range [min, max]
  ## Examples: clamp(5, 0, 10) = 5, clamp(-5, 0, 10) = 0, clamp(15, 0, 10) = 10
  if v < min: min
  elif v > max: max
  else: v

proc wrap*(v, min, max: int): int {.exportc: "pgWrap".} =
  ## Wrap value into range [min, max]
  ## Examples: wrap(12, 0, 10) = 1, wrap(-2, 0, 10) = 9
  let range = max - min + 1
  result = ((v - min) mod range + range) mod range + min

proc lerp*(a, b, t: int): int {.exportc: "pgLerp".} =
  ## Integer linear interpolation (t is 0..1000 for precision)
  ## Examples: lerp(0, 100, 500) = 50 (t=500 is 50%)
  result = a + ((b - a) * t) div 1000

proc smoothstep*(t: int): int {.exportc: "pgSmoothstep".} =
  ## Smooth interpolation curve (t is 0..1000, returns 0..1000)
  ## Smoother than linear, useful for easing
  let t2 = clamp(t, 0, 1000)
  result = (t2 * t2 * (3000 - 2 * t2)) div 1000000

proc map*(value, inMin, inMax, outMin, outMax: int): int {.exportc: "pgMap".} =
  ## Map value from one range to another
  ## Examples: map(5, 0, 10, 0, 100) = 50
  result = outMin + ((value - inMin) * (outMax - outMin)) div (inMax - inMin)

## ============================================================================
## NOISE & HASH FUNCTIONS
## Integer-based noise for procedural textures, terrain, patterns
## ============================================================================

proc intHash*(x, seed: int): int {.exportc: "pgIntHash".} =
  ## Simple 1D integer hash function
  ## Returns value in range [0..65535]
  var h = cast[uint](x xor seed)
  h = h xor (h shr 16)
  h = h * 0x7feb352d'u
  h = h xor (h shr 15)
  h = h * 0x846ca68b'u
  h = h xor (h shr 16)
  result = int(h and 0xFFFF)

proc intHash2D*(x, y, seed: int): int {.exportc: "pgIntHash2D".} =
  ## Simple 2D integer hash function
  ## Returns value in range [0..65535]
  result = intHash(x + intHash(y, seed), seed)

proc intHash3D*(x, y, z, seed: int): int {.exportc: "pgIntHash3D".} =
  ## Simple 3D integer hash function
  ## Returns value in range [0..65535]
  result = intHash(x + intHash(y + intHash(z, seed), seed), seed)

proc valueNoise2D*(x, y, seed: int): int {.exportc: "pgValueNoise2D".} =
  ## 2D value noise (grid-based random values)
  ## Returns value in range [0..65535]
  result = intHash2D(x, y, seed)

proc smoothNoise2D*(x, y, scale, seed: int): int {.exportc: "pgSmoothNoise2D".} =
  ## 2D smoothed noise using bilinear interpolation
  ## scale: Size of noise cells (e.g., 100 = cells are 100 units wide)
  ## Returns value in range [0..65535]
  let cellX = x div scale
  let cellY = y div scale
  let localX = x mod scale
  let localY = y mod scale
  
  # Get corner values
  let v00 = intHash2D(cellX, cellY, seed)
  let v10 = intHash2D(cellX + 1, cellY, seed)
  let v01 = intHash2D(cellX, cellY + 1, seed)
  let v11 = intHash2D(cellX + 1, cellY + 1, seed)
  
  # Interpolation weights (0..1000)
  let tx = (localX * 1000) div scale
  let ty = (localY * 1000) div scale
  
  # Bilinear interpolation
  let top = lerp(v00, v10, tx)
  let bottom = lerp(v01, v11, tx)
  result = lerp(top, bottom, ty)

proc fractalNoise2D*(x, y, octaves, scale, seed: int): int {.exportc: "pgFractalNoise2D".} =
  ## 2D fractal noise (multiple octaves of smoothNoise2D)
  ## octaves: Number of noise layers (typically 3-6)
  ## scale: Base size of noise cells
  ## Returns value in range [0..65535]
  var total = 0
  var amplitude = 32768  # Start at half range
  var frequency = scale
  var maxValue = 0
  
  for i in 0..<octaves:
    total += (smoothNoise2D(x, y, frequency, seed + i) * amplitude) div 65535
    maxValue += amplitude
    amplitude = amplitude div 2
    frequency = frequency div 2
    
  # Normalize to [0..65535] - avoid overflow by checking bounds
  if maxValue > 0:
    # Prevent overflow: if total would overflow when multiplied by 65535,
    # do the division in a different order
    if total > 32767:  # total * 65535 would exceed int32 max
      result = total * (65535 div maxValue)
    else:
      result = (total * 65535) div maxValue
  else:
    result = 0

## ============================================================================
## GEOMETRIC PRIMITIVES
## Integer-based geometry operations
## ============================================================================

type
  IVec2* = tuple[x, y: int]
  IRect* = object
    x*, y*, w*, h*: int

proc ivec2*(x, y: int): IVec2 {.inline.} =
  ## Create 2D integer vector
  (x, y)

proc rect*(x, y, w, h: int): IRect {.exportc: "pgRect".} =
  ## Create rectangle
  IRect(x: x, y: y, w: w, h: h)

proc center*(r: IRect): IVec2 {.exportc: "pgRectCenter".} =
  ## Get center point of rectangle
  (r.x + r.w div 2, r.y + r.h div 2)

proc contains*(r: IRect, x, y: int): bool {.exportc: "pgRectContains".} =
  ## Check if point is inside rectangle
  x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h

proc overlaps*(a, b: IRect): bool {.exportc: "pgRectOverlaps".} =
  ## Check if two rectangles overlap
  a.x < b.x + b.w and a.x + a.w > b.x and
  a.y < b.y + b.h and a.y + a.h > b.y

proc grow*(r: IRect, amount: int): IRect {.exportc: "pgRectGrow".} =
  ## Grow rectangle by amount (negative to shrink)
  IRect(
    x: r.x - amount,
    y: r.y - amount,
    w: r.w + amount * 2,
    h: r.h + amount * 2
  )

proc shrink*(r: IRect, amount: int): IRect {.exportc: "pgRectShrink".} =
  ## Shrink rectangle by amount
  grow(r, -amount)

## ============================================================================
## DISTANCE FUNCTIONS
## Various distance metrics for different use cases
## ============================================================================

proc manhattanDist*(x1, y1, x2, y2: int): int {.exportc: "pgManhattanDist".} =
  ## Manhattan distance (grid-based, |dx| + |dy|)
  ## Useful for: Grid pathfinding, tile-based games
  iabs(x2 - x1) + iabs(y2 - y1)

proc chebyshevDist*(x1, y1, x2, y2: int): int {.exportc: "pgChebyshevDist".} =
  ## Chebyshev distance (max of |dx|, |dy|)
  ## Useful for: 8-directional movement, king moves in chess
  max(iabs(x2 - x1), iabs(y2 - y1))

proc euclideanDistSq*(x1, y1, x2, y2: int): int {.exportc: "pgEuclideanDistSq".} =
  ## Squared Euclidean distance (avoids sqrt, faster)
  ## Useful for: Distance comparisons without needing exact value
  let dx = x2 - x1
  let dy = y2 - y1
  dx * dx + dy * dy

proc euclideanDist*(x1, y1, x2, y2: int): int {.exportc: "pgEuclideanDist".} =
  ## Euclidean distance (true distance)
  ## Useful for: Circles, true distance calculations
  sqrt(euclideanDistSq(x1, y1, x2, y2).float).int

## ============================================================================
## LINE & CURVE ALGORITHMS
## Integer-based line drawing and curve generation
## ============================================================================

proc bresenhamLine*(x0, y0, x1, y1: int): seq[IVec2] {.exportc: "pgBresenhamLine".} =
  ## Bresenham's line algorithm - all integer math
  ## Returns all points on the line from (x0,y0) to (x1,y1)
  result = @[]
  var x = x0
  var y = y0
  let dx = iabs(x1 - x0)
  let dy = iabs(y1 - y0)
  let sx = if x0 < x1: 1 else: -1
  let sy = if y0 < y1: 1 else: -1
  var err = dx - dy
  
  while true:
    result.add((x, y))
    if x == x1 and y == y1:
      break
    let e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x += sx
    if e2 < dx:
      err += dx
      y += sy

proc circle*(centerX, centerY, radius: int): seq[IVec2] {.exportc: "pgCircle".} =
  ## Midpoint circle algorithm - all integer math
  ## Returns all points on the circle perimeter
  result = @[]
  var x = 0
  var y = radius
  var d = 3 - 2 * radius
  
  template addOctants(cx, cy, x, y: int) =
    # Add all 8 octants of the circle
    result.add((cx + x, cy + y))
    result.add((cx - x, cy + y))
    result.add((cx + x, cy - y))
    result.add((cx - x, cy - y))
    result.add((cx + y, cy + x))
    result.add((cx - y, cy + x))
    result.add((cx + y, cy - x))
    result.add((cx - y, cy - x))
  
  addOctants(centerX, centerY, x, y)
  while y >= x:
    x += 1
    if d > 0:
      y -= 1
      d = d + 4 * (x - y) + 10
    else:
      d = d + 4 * x + 6
    addOctants(centerX, centerY, x, y)

proc floodFill*(grid: var seq[seq[int]], x, y, fillValue, targetValue: int) {.exportc: "pgFloodFill".} =
  ## Flood fill algorithm (iterative, stack-based)
  ## Replaces all connected cells of targetValue with fillValue
  if y < 0 or y >= grid.len or x < 0 or x >= grid[0].len:
    return
  if grid[y][x] != targetValue or grid[y][x] == fillValue:
    return
    
  var stack = @[(x, y)]
  
  while stack.len > 0:
    let (cx, cy) = stack.pop()
    if cy < 0 or cy >= grid.len or cx < 0 or cx >= grid[0].len:
      continue
    if grid[cy][cx] != targetValue:
      continue
      
    grid[cy][cx] = fillValue
    
    # Add neighbors
    stack.add((cx + 1, cy))
    stack.add((cx - 1, cy))
    stack.add((cx, cy + 1))
    stack.add((cx, cy - 1))

## ============================================================================
## EASING FUNCTIONS
## Integer-based easing for smooth animations/transitions
## All functions take t in range [0..1000] and return [0..1000]
## ============================================================================

proc easeLinear*(t: int): int {.exportc: "pgEaseLinear".} =
  ## Linear easing (no easing)
  clamp(t, 0, 1000)

proc easeInQuad*(t: int): int {.exportc: "pgEaseInQuad".} =
  ## Quadratic ease in (slow start)
  let tc = clamp(t, 0, 1000)
  (tc * tc) div 1000

proc easeOutQuad*(t: int): int {.exportc: "pgEaseOutQuad".} =
  ## Quadratic ease out (slow end)
  let tc = clamp(t, 0, 1000)
  tc * (2000 - tc) div 1000

proc easeInOutQuad*(t: int): int {.exportc: "pgEaseInOutQuad".} =
  ## Quadratic ease in/out (slow start and end)
  let tc = clamp(t, 0, 1000)
  if tc < 500:
    (2 * tc * tc) div 1000
  else:
    let t2 = tc - 500
    500 + (2000 * t2 - t2 * t2) div 1000

proc easeInCubic*(t: int): int {.exportc: "pgEaseInCubic".} =
  ## Cubic ease in (slower start)
  let tc = clamp(t, 0, 1000)
  (tc * tc * tc) div 1000000

proc easeOutCubic*(t: int): int {.exportc: "pgEaseOutCubic".} =
  ## Cubic ease out (slower end)
  let tc = clamp(t, 0, 1000) - 1000
  ((tc * tc * tc) div 1000000) + 1000

## ============================================================================
## ARRAY/COLLECTION OPERATIONS
## Deterministic operations on sequences with isolated RNG
## ============================================================================

proc shuffle*[T](rng: var Rand, arr: var seq[T]) {.exportc: "pgShuffle".} =
  ## Fisher-Yates shuffle (deterministic with isolated RNG)
  ## CRITICAL: Must go backward for correct algorithm
  var n = arr.len
  while n > 1:
    n -= 1
    let k = rng.rand(n)  # 0..n inclusive
    swap(arr[n], arr[k])

proc sample*[T](rng: var Rand, arr: seq[T], count: int): seq[T] {.exportc: "pgSample".} =
  ## Select random sample of count items (without replacement)
  ## Uses partial Fisher-Yates for efficiency
  result = @[]
  if count >= arr.len:
    result = arr
    shuffle(rng, result)
    return
    
  var indices = newSeq[int](arr.len)
  for i in 0..<arr.len:
    indices[i] = i
    
  var n = arr.len
  for i in 0..<count:
    let k = rng.rand(n - 1 - i) + i
    swap(indices[n - 1 - i], indices[k])
    result.add(arr[indices[n - 1 - i]])

proc choice*[T](rng: var Rand, arr: seq[T]): T {.exportc: "pgChoice".} =
  ## Choose one random item from array
  arr[rng.rand(arr.len - 1)]

proc weightedChoice*[T](rng: var Rand, items: seq[T], weights: seq[int]): T {.exportc: "pgWeightedChoice".} =
  ## Choose random item with weighted probability
  ## weights: relative weights (e.g., [1, 2, 1] means middle item is 2x more likely)
  var total = 0
  for w in weights:
    total += w
  
  var r = rng.rand(total - 1)
  for i in 0..<items.len:
    if r < weights[i]:
      return items[i]
    r -= weights[i]
  
  return items[^1]  # Fallback to last item

## ============================================================================
## PATTERN GENERATION
## Common procedural patterns for textures, backgrounds, etc.
## ============================================================================

proc checkerboard*(x, y, size: int): int {.exportc: "pgCheckerboard".} =
  ## Generate checkerboard pattern (returns 0 or 1)
  ((x div size) + (y div size)) mod 2

proc stripes*(x, size: int): int {.exportc: "pgStripes".} =
  ## Generate vertical stripes (returns 0 or 1)
  (x div size) mod 2

proc concentricCircles*(x, y, centerX, centerY, spacing: int): int {.exportc: "pgConcentricCircles".} =
  ## Generate concentric circle pattern (returns ring number)
  let dist = euclideanDist(x, y, centerX, centerY)
  dist div spacing

proc spiralPattern*(x, y, centerX, centerY, rotation: int): int {.exportc: "pgSpiralPattern".} =
  ## Generate spiral pattern (rotation controls tightness)
  ## Returns value [0..65535] based on spiral position
  let dx = x - centerX
  let dy = y - centerY
  let dist = euclideanDist(x, y, centerX, centerY)
  # Simple approximation of angle using atan2-like logic
  let angle = if dx == 0 and dy == 0: 0
              elif dx >= 0 and dy >= 0: (dy * 1000) div (dx + dy + 1)
              elif dx < 0 and dy >= 0: 1000 + ((-dx) * 1000) div ((-dx) + dy + 1)
              elif dx < 0 and dy < 0: 2000 + ((-dy) * 1000) div ((-dx) + (-dy) + 1)
              else: 3000 + (dx * 1000) div (dx + (-dy) + 1)
  
  (dist * rotation + angle) mod 65536

## ============================================================================
## GRID UTILITIES
## Common grid/tilemap operations
## ============================================================================

proc inBounds*(x, y, width, height: int): bool {.exportc: "pgInBounds".} =
  ## Check if coordinates are within grid bounds
  x >= 0 and x < width and y >= 0 and y < height

proc neighbors4*(x, y: int): array[4, IVec2] {.inline.} =
  ## Get 4-connected neighbors (cardinal directions)
  [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]

proc neighbors8*(x, y: int): array[8, IVec2] {.inline.} =
  ## Get 8-connected neighbors (including diagonals)
  [
    (x+1, y), (x-1, y), (x, y+1), (x, y-1),
    (x+1, y+1), (x+1, y-1), (x-1, y+1), (x-1, y-1)
  ]

proc cellularAutomata*(grid: seq[seq[int]], birthRule, surviveRule: seq[int]): seq[seq[int]] {.exportc: "pgCellularAutomata".} =
  ## Run one step of cellular automata
  ## birthRule: neighbor counts that cause birth (e.g., [3] for Conway's Life)
  ## surviveRule: neighbor counts that allow survival (e.g., [2, 3] for Conway's Life)
  result = grid
  let height = grid.len
  let width = grid[0].len
  
  for y in 0..<height:
    for x in 0..<width:
      var count = 0
      for (nx, ny) in neighbors8(x, y):
        if inBounds(nx, ny, width, height) and grid[ny][nx] > 0:
          count += 1
      
      if grid[y][x] == 0:
        # Dead cell - check birth rules
        if count in birthRule:
          result[y][x] = 1
      else:
        # Alive cell - check survive rules
        if count notin surviveRule:
          result[y][x] = 0

## ============================================================================
## COLOR UTILITIES (Integer RGB)
## Integer-based color manipulation (24-bit RGB)
## ============================================================================

type
  IColor* = object
    r*, g*, b*: int  # 0..255

proc icolor*(r, g, b: int): IColor {.exportc: "pgIColor".} =
  ## Create color from RGB components (0..255)
  IColor(r: clamp(r, 0, 255), g: clamp(g, 0, 255), b: clamp(b, 0, 255))

proc toInt*(c: IColor): int {.exportc: "pgColorToInt".} =
  ## Convert color to single integer (0xRRGGBB)
  (c.r shl 16) or (c.g shl 8) or c.b

proc fromInt*(rgb: int): IColor {.exportc: "pgColorFromInt".} =
  ## Convert integer to color
  IColor(r: (rgb shr 16) and 0xFF, g: (rgb shr 8) and 0xFF, b: rgb and 0xFF)

proc lerpColor*(a, b: IColor, t: int): IColor {.exportc: "pgLerpColor".} =
  ## Interpolate between two colors (t is 0..1000)
  IColor(
    r: lerp(a.r, b.r, t),
    g: lerp(a.g, b.g, t),
    b: lerp(a.b, b.b, t)
  )

proc hsvToRgb*(h, s, v: int): IColor {.exportc: "pgHsvToRgb".} =
  ## Convert HSV to RGB (h: 0..360, s: 0..1000, v: 0..1000)
  let h60 = (h mod 360) div 60
  let f = ((h mod 360) mod 60) * 1000 div 60
  let p = (v * (1000 - s)) div 1000
  let q = (v * (1000 - (s * f) div 1000)) div 1000
  let t = (v * (1000 - (s * (1000 - f)) div 1000)) div 1000
  
  case h60
  of 0: icolor((v * 255) div 1000, (t * 255) div 1000, (p * 255) div 1000)
  of 1: icolor((q * 255) div 1000, (v * 255) div 1000, (p * 255) div 1000)
  of 2: icolor((p * 255) div 1000, (v * 255) div 1000, (t * 255) div 1000)
  of 3: icolor((p * 255) div 1000, (q * 255) div 1000, (v * 255) div 1000)
  of 4: icolor((t * 255) div 1000, (p * 255) div 1000, (v * 255) div 1000)
  else: icolor((v * 255) div 1000, (p * 255) div 1000, (q * 255) div 1000)

## ============================================================================
## SHADER PRIMITIVES
## Building blocks for terminal shader effects
## ============================================================================

# Sine lookup table for fast integer trigonometry
# Stores sin values * 1000 for angles 0-90 degrees
const SIN_TABLE = [
  0, 17, 35, 52, 70, 87, 105, 122, 139, 156, 174, 191, 208, 225, 242, 259,
  276, 292, 309, 326, 342, 358, 375, 391, 407, 423, 438, 454, 469, 485, 500,
  515, 530, 545, 559, 574, 588, 602, 616, 629, 643, 656, 669, 682, 695, 707,
  719, 731, 743, 755, 766, 777, 788, 799, 809, 819, 829, 839, 848, 857, 866,
  875, 883, 891, 899, 906, 914, 921, 927, 934, 940, 946, 951, 956, 961, 966,
  970, 974, 978, 982, 985, 988, 990, 993, 995, 997, 999, 1000, 1000, 1000, 1000
]

proc isin*(angle: int): int {.exportc: "pgIsin".} =
  ## Integer sine function
  ## angle: in decidegrees (0..3600 = 0°..360°)
  ## Returns: -1000..1000 (representing -1.0..1.0)
  ## Examples: isin(0) = 0, isin(900) = 1000 (90°), isin(1800) = 0 (180°)
  let a = ((angle mod 3600) + 3600) mod 3600  # Normalize to 0..3600
  let quadrant = a div 900
  let idx = (a mod 900) div 10
  
  case quadrant
  of 0: SIN_TABLE[idx]           # 0-90°: positive, ascending
  of 1: SIN_TABLE[90 - idx]      # 90-180°: positive, descending
  of 2: -SIN_TABLE[idx]          # 180-270°: negative, descending
  else: -SIN_TABLE[90 - idx]     # 270-360°: negative, ascending

proc icos*(angle: int): int {.exportc: "pgIcos".} =
  ## Integer cosine function
  ## angle: in decidegrees (0..3600 = 0°..360°)
  ## Returns: -1000..1000 (representing -1.0..1.0)
  ## cos(x) = sin(x + 90°)
  isin(angle + 900)

proc polarDistance*(x, y, centerX, centerY: int): int {.exportc: "pgPolarDistance".} =
  ## Calculate distance from point to center (integer sqrt)
  ## Returns: distance in pixels
  ## Useful for: ripple effects, radial patterns
  euclideanDist(x, y, centerX, centerY)

proc polarAngle*(x, y, centerX, centerY: int): int {.exportc: "pgPolarAngle".} =
  ## Calculate angle from center to point
  ## Returns: angle in decidegrees (0..3600 = 0°..360°)
  ## Useful for: tunnel effects, rotational patterns
  let dx = x - centerX
  let dy = y - centerY
  
  if dx == 0 and dy == 0:
    return 0
  
  # Integer arctan2 approximation using lookup
  let adx = iabs(dx)
  let ady = iabs(dy)
  
  var angle: int
  if adx > ady:
    # More horizontal, atan(dy/dx)
    let ratio = (ady * 1000) div adx
    # Linear approximation: atan(x) ≈ x for small x
    angle = (ratio * 450) div 1000  # Scale to ~45° max
  else:
    # More vertical, 90° - atan(dx/dy)
    if ady > 0:
      let ratio = (adx * 1000) div ady
      angle = 900 - (ratio * 450) div 1000
    else:
      angle = 0
  
  # Adjust for quadrant
  if dx >= 0 and dy >= 0: angle        # Q1: 0-90
  elif dx < 0 and dy >= 0: 1800 - angle  # Q2: 90-180
  elif dx < 0 and dy < 0: 1800 + angle   # Q3: 180-270
  else: 3600 - angle                     # Q4: 270-360

proc waveAdd*(wave1, wave2: int): int {.exportc: "pgWaveAdd".} =
  ## Add two wave values (with overflow protection)
  ## wave1, wave2: typically -1000..1000
  ## Returns: clamped sum
  clamp(wave1 + wave2, -2000, 2000)

proc waveMultiply*(wave1, wave2: int): int {.exportc: "pgWaveMultiply".} =
  ## Multiply two normalized wave values
  ## wave1, wave2: -1000..1000
  ## Returns: -1000..1000
  (wave1 * wave2) div 1000

proc waveMix*(wave1, wave2, amount: int): int {.exportc: "pgWaveMix".} =
  ## Mix/blend two wave values
  ## amount: 0..1000 (0=all wave1, 1000=all wave2, 500=50/50 mix)
  ## Returns: blended value
  lerp(wave1, wave2, amount)

proc mapToGradient5*(value: int, ramp: seq[int]): int {.exportc: "pgMapToGradient5".} =
  ## Map value (0..1000) to 5-level gradient
  ## ramp: array of 5 values to interpolate between
  ## Returns: interpolated value from ramp
  let idx = (value * 4) div 1000
  let t = ((value * 4) mod 1000)
  let i = clamp(idx, 0, 3)
  lerp(ramp[i], ramp[i + 1], t)

## Color palette functions for shader effects

proc colorHeatmap*(value: int): IColor {.exportc: "pgColorHeatmap".} =
  ## Heatmap color palette: black → red → yellow → white
  ## value: 0..255
  ## Useful for: fire effects, temperature visualization
  let v = clamp(value, 0, 255)
  if v < 85:
    icolor(v * 3, 0, 0)
  elif v < 170:
    icolor(255, (v - 85) * 3, 0)
  else:
    let w = (v - 170) * 3
    icolor(255, 255, w)

proc colorPlasma*(value: int): IColor {.exportc: "pgColorPlasma".} =
  ## Plasma/rainbow color palette
  ## value: 0..255
  ## Useful for: plasma effects, rainbow gradients
  let v = clamp(value, 0, 255)
  # Use HSV with varying hue
  let h = (v * 360) div 255
  hsvToRgb(h, 1000, 1000)

proc colorCoolWarm*(value: int): IColor {.exportc: "pgColorCoolWarm".} =
  ## Cool (blue) to warm (red) gradient
  ## value: 0..255
  ## Useful for: temperature maps, general gradients
  let v = clamp(value, 0, 255)
  let t = (v * 1000) div 255
  icolor(
    (t * 255) div 1000,
    (1000 - iabs(t - 500) * 2) * 255 div 1000,
    ((1000 - t) * 255) div 1000
  )

proc colorFire*(value: int): IColor {.exportc: "pgColorFire".} =
  ## Fire gradient: black → red → orange → yellow
  ## value: 0..255
  ## Useful for: fire effects
  let v = clamp(value, 0, 255)
  if v < 64:
    icolor(v * 4, 0, 0)
  elif v < 128:
    icolor(255, (v - 64) * 4, 0)
  elif v < 192:
    icolor(255, 128 + (v - 128) * 2, 0)
  else:
    icolor(255, 255, (v - 192) * 4)

proc colorOcean*(value: int): IColor {.exportc: "pgColorOcean".} =
  ## Deep blue to cyan gradient
  ## value: 0..255
  ## Useful for: water effects, ocean themes
  let v = clamp(value, 0, 255)
  icolor(0, v div 2, 128 + v div 2)

proc colorNeon*(value: int): IColor {.exportc: "pgColorNeon".} =
  ## Neon cyan-magenta gradient
  ## value: 0..255
  ## Useful for: cyber/neon aesthetics
  let v = clamp(value, 0, 255)
  let t = (v * 1000) div 255
  let sinT = isin((t * 1800) div 1000)  # 0 to 180 degrees
  icolor(
    (t * 255) div 1000,
    ((sinT + 1000) * 128) div 1000,
    255
  )

proc colorMatrix*(value: int): IColor {.exportc: "pgColorMatrix".} =
  ## Matrix-style green gradient
  ## value: 0..255
  ## Useful for: Matrix rain effect
  let v = clamp(value, 0, 255)
  icolor(0, v, v div 4)

proc colorGrayscale*(value: int): IColor {.exportc: "pgColorGrayscale".} =
  ## Simple grayscale
  ## value: 0..255
  let v = clamp(value, 0, 255)
  icolor(v, v, v)

## ============================================================================
## EXPORT INFO
## ============================================================================

when isMainModule:
  echo "Procedural Generation Primitives Library"
  echo "Designed for deterministic, composable procedural generation"
  echo "Compatible with TiXL/Tool3 style node-based workflows"
