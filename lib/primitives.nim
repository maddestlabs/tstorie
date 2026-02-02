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
import ../nimini/auto_bindings

{.used.}  # Prevent dead code elimination

## ============================================================================
## MATH PRIMITIVES
## Pure integer math operations guaranteed to behave identically
## ============================================================================

proc idiv*(a, b: int): int {.exportc: "pgIdiv", autoExpose: "primitives".} =
  ## Integer division (no float conversion)
  ## Examples: idiv(5, 2) = 2, idiv(-5, 2) = -3
  result = a div b

proc imod*(a, b: int): int {.exportc: "pgImod", autoExpose: "primitives".} =
  ## Integer modulo
  ## Examples: imod(5, 3) = 2, imod(-5, 3) = 1
  result = a mod b

proc iabs*(a: int): int {.exportc: "pgIabs", autoExpose: "primitives".} =
  ## Absolute value
  ## Examples: iabs(-5) = 5, iabs(5) = 5
  result = abs(a)

proc sign*(a: int): int {.exportc: "pgSign", autoExpose: "primitives".} =
  ## Sign function: returns -1, 0, or 1
  ## Examples: sign(-5) = -1, sign(0) = 0, sign(5) = 1
  if a < 0: -1
  elif a > 0: 1
  else: 0

proc clamp*(v, min, max: int): int {.exportc: "pgClamp", autoExpose: "primitives".} =
  ## Clamp value to range [min, max]
  ## Examples: clamp(5, 0, 10) = 5, clamp(-5, 0, 10) = 0, clamp(15, 0, 10) = 10
  if v < min: min
  elif v > max: max
  else: v

proc wrap*(v, min, max: int): int {.exportc: "pgWrap", autoExpose: "primitives".} =
  ## Wrap value into range [min, max]
  ## Examples: wrap(12, 0, 10) = 1, wrap(-2, 0, 10) = 9
  let range = max - min + 1
  result = ((v - min) mod range + range) mod range + min

proc lerp*(a, b, t: int): int {.exportc: "pgLerp", autoExpose: "primitives".} =
  ## Integer linear interpolation (t is 0..1000 for precision)
  ## Examples: lerp(0, 100, 500) = 50 (t=500 is 50%)
  result = a + ((b - a) * t) div 1000

proc smoothstep*(t: int): int {.exportc: "pgSmoothstep", autoExpose: "primitives".} =
  ## Smooth interpolation curve (t is 0..1000, returns 0..1000)
  ## Smoother than linear, useful for easing
  let t2 = clamp(t, 0, 1000)
  result = (t2 * t2 * (3000 - 2 * t2)) div 1000000

proc map*(value, inMin, inMax, outMin, outMax: int): int {.exportc: "pgMap", autoExpose: "primitives".} =
  ## Map value from one range to another
  ## Examples: map(5, 0, 10, 0, 100) = 50
  result = outMin + ((value - inMin) * (outMax - outMin)) div (inMax - inMin)

## ============================================================================
## NOISE & HASH FUNCTIONS
## Integer-based noise for procedural textures, terrain, patterns
## ============================================================================

proc intHash*(x, seed: int): int {.exportc: "pgIntHash", autoExpose: "primitives".} =
  ## Simple 1D integer hash function
  ## Returns value in range [0..65535]
  var h = cast[uint](x xor seed)
  h = h xor (h shr 16)
  h = h * 0x7feb352d'u
  h = h xor (h shr 15)
  h = h * 0x846ca68b'u
  h = h xor (h shr 16)
  result = int(h and 0xFFFF)

proc intHash2D*(x, y, seed: int): int {.exportc: "pgIntHash2D", autoExpose: "primitives".} =
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
## PERLIN NOISE
## Industry-standard gradient noise for natural-looking patterns
## ============================================================================

# Perlin permutation table - deterministically generated from seed
# This ensures the same seed always produces the same noise pattern
proc perlinPerm(i, seed: int): int {.inline.} =
  ## Get permutation value for Perlin noise
  (intHash(i, seed) and 0xFF)

# Perlin gradient vectors (precomputed for integer math)
# These represent unit vectors at various angles
const PERLIN_GRADIENTS_2D = [
  (1000, 0), (923, 382), (707, 707), (382, 923),
  (0, 1000), (-382, 923), (-707, 707), (-923, 382),
  (-1000, 0), (-923, -382), (-707, -707), (-382, -923),
  (0, -1000), (382, -923), (707, -707), (923, -382)
]

proc perlinGrad2D(hash, x, y: int): int {.inline.} =
  ## Compute dot product of gradient vector with distance vector
  ## x, y: distance from grid point (0..1000)
  let grad = PERLIN_GRADIENTS_2D[hash and 15]
  result = (grad[0] * x + grad[1] * y) div 1000

proc perlinFade(t: int): int {.inline.} =
  ## Perlin's fade function: 6t^5 - 15t^4 + 10t^3
  ## Smoother than smoothstep, reduces grid artifacts
  ## t: 0..1000, returns 0..1000
  let t2 = (t * t) div 1000
  let t3 = (t2 * t) div 1000
  let t4 = (t3 * t) div 1000
  let t5 = (t4 * t) div 1000
  result = ((6 * t5 - 15 * t4 + 10 * t3)) div 1

proc perlinNoise2D*(x, y, scale, seed: int): int {.exportc: "pgPerlinNoise2D", autoExpose: "primitives".} =
  ## 2D Perlin noise - smooth gradient noise
  ## scale: Size of noise cells (e.g., 100 = cells are 100 units wide)
  ## Returns value in range [0..65535]
  ## 
  ## Perlin noise is the industry standard for natural terrain and textures.
  ## It uses gradient vectors at grid points for smooth, natural-looking patterns.
  ## Better than value noise - no grid artifacts, more organic appearance.
  let cellX = x div scale
  let cellY = y div scale
  let localX = (x mod scale * 1000) div scale  # 0..1000
  let localY = (y mod scale * 1000) div scale  # 0..1000
  
  # Get gradient hashes at four corners
  let aa = perlinPerm(perlinPerm(cellX, seed) + cellY, seed)
  let ab = perlinPerm(perlinPerm(cellX, seed) + cellY + 1, seed)
  let ba = perlinPerm(perlinPerm(cellX + 1, seed) + cellY, seed)
  let bb = perlinPerm(perlinPerm(cellX + 1, seed) + cellY + 1, seed)
  
  # Compute dot products with distance vectors
  let gx0 = perlinGrad2D(aa, localX, localY)
  let gx1 = perlinGrad2D(ba, localX - 1000, localY)
  let gy0 = perlinGrad2D(ab, localX, localY - 1000)
  let gy1 = perlinGrad2D(bb, localX - 1000, localY - 1000)
  
  # Interpolate using fade curve
  let u = perlinFade(localX)
  let v = perlinFade(localY)
  
  let x1 = lerp(gx0, gx1, u)
  let x2 = lerp(gy0, gy1, u)
  let noise = lerp(x1, x2, v)
  
  # Map from [-1000..1000] to [0..65535]
  result = ((noise + 1000) * 65535) div 2000

# 3D Perlin gradient vectors
const PERLIN_GRADIENTS_3D = [
  (1000, 1000, 0), (-1000, 1000, 0), (1000, -1000, 0), (-1000, -1000, 0),
  (1000, 0, 1000), (-1000, 0, 1000), (1000, 0, -1000), (-1000, 0, -1000),
  (0, 1000, 1000), (0, -1000, 1000), (0, 1000, -1000), (0, -1000, -1000),
  (1000, 1000, 0), (-1000, 1000, 0), (0, -1000, 1000), (0, -1000, -1000)
]

proc perlinGrad3D(hash, x, y, z: int): int {.inline.} =
  ## Compute dot product of 3D gradient with distance vector
  let grad = PERLIN_GRADIENTS_3D[hash and 15]
  result = (grad[0] * x + grad[1] * y + grad[2] * z) div 1000

proc perlinNoise3D*(x, y, z, scale, seed: int): int {.exportc: "pgPerlinNoise3D", autoExpose: "primitives".} =
  ## 3D Perlin noise - for volumetric effects and 3D terrain
  ## scale: Size of noise cells
  ## Returns value in range [0..65535]
  let cellX = x div scale
  let cellY = y div scale
  let cellZ = z div scale
  let localX = (x mod scale * 1000) div scale
  let localY = (y mod scale * 1000) div scale
  let localZ = (z mod scale * 1000) div scale
  
  # Get gradient hashes at 8 corners of cube
  let aaa = perlinPerm(perlinPerm(perlinPerm(cellX, seed) + cellY, seed) + cellZ, seed)
  let aba = perlinPerm(perlinPerm(perlinPerm(cellX, seed) + cellY + 1, seed) + cellZ, seed)
  let aab = perlinPerm(perlinPerm(perlinPerm(cellX, seed) + cellY, seed) + cellZ + 1, seed)
  let abb = perlinPerm(perlinPerm(perlinPerm(cellX, seed) + cellY + 1, seed) + cellZ + 1, seed)
  let baa = perlinPerm(perlinPerm(perlinPerm(cellX + 1, seed) + cellY, seed) + cellZ, seed)
  let bba = perlinPerm(perlinPerm(perlinPerm(cellX + 1, seed) + cellY + 1, seed) + cellZ, seed)
  let bab = perlinPerm(perlinPerm(perlinPerm(cellX + 1, seed) + cellY, seed) + cellZ + 1, seed)
  let bbb = perlinPerm(perlinPerm(perlinPerm(cellX + 1, seed) + cellY + 1, seed) + cellZ + 1, seed)
  
  # Compute dot products
  let g000 = perlinGrad3D(aaa, localX, localY, localZ)
  let g100 = perlinGrad3D(baa, localX - 1000, localY, localZ)
  let g010 = perlinGrad3D(aba, localX, localY - 1000, localZ)
  let g110 = perlinGrad3D(bba, localX - 1000, localY - 1000, localZ)
  let g001 = perlinGrad3D(aab, localX, localY, localZ - 1000)
  let g101 = perlinGrad3D(bab, localX - 1000, localY, localZ - 1000)
  let g011 = perlinGrad3D(abb, localX, localY - 1000, localZ - 1000)
  let g111 = perlinGrad3D(bbb, localX - 1000, localY - 1000, localZ - 1000)
  
  # Interpolate
  let u = perlinFade(localX)
  let v = perlinFade(localY)
  let w = perlinFade(localZ)
  
  let x1 = lerp(g000, g100, u)
  let x2 = lerp(g010, g110, u)
  let x3 = lerp(g001, g101, u)
  let x4 = lerp(g011, g111, u)
  let y1 = lerp(x1, x2, v)
  let y2 = lerp(x3, x4, v)
  let noise = lerp(y1, y2, w)
  
  # Map from [-1000..1000] to [0..65535]
  result = ((noise + 1000) * 65535) div 2000

## ============================================================================
## SIMPLEX NOISE
## Ken Perlin's improved noise - faster and less directional artifacts
## ============================================================================

proc simplexNoise2D*(x, y, scale, seed: int): int {.exportc: "pgSimplexNoise2D", autoExpose: "primitives".} =
  ## 2D Simplex noise - faster and better looking than Perlin in 2D
  ## scale: Size of noise cells
  ## Returns value in range [0..65535]
  ##
  ## Simplex noise uses triangular grid instead of square grid.
  ## Advantages: Fewer gradients to compute (3 vs 4), less directional bias.
  
  # Skew input space to determine which simplex cell we're in
  const F2 = 366  # (sqrt(3)-1)/2 * 1000 ≈ 0.366
  const G2 = 211  # (3-sqrt(3))/6 * 1000 ≈ 0.211
  
  let sx = x div scale
  let sy = y div scale
  let localX = (x mod scale * 1000) div scale
  let localY = (y mod scale * 1000) div scale
  
  let s = ((localX + localY) * F2) div 1000
  let i = sx + ((localX + s) div 1000)
  let j = sy + ((localY + s) div 1000)
  
  let t = ((i + j) * G2) div 1000
  let X0 = i - ((i + j) * G2) div 1000
  let Y0 = j - t
  let x0 = localX - (X0 * 1000)
  let y0 = localY - (Y0 * 1000)
  
  # Determine which simplex we're in
  var i1, j1: int
  if x0 > y0:
    i1 = 1; j1 = 0  # Lower triangle
  else:
    i1 = 0; j1 = 1  # Upper triangle
  
  # Offsets for middle and top corners
  let x1 = x0 - i1 * 1000 + G2
  let y1 = y0 - j1 * 1000 + G2
  let x2 = x0 - 1000 + 2 * G2
  let y2 = y0 - 1000 + 2 * G2
  
  # Get gradient hashes
  let gi0 = perlinPerm(i + perlinPerm(j, seed), seed)
  let gi1 = perlinPerm(i + i1 + perlinPerm(j + j1, seed), seed)
  let gi2 = perlinPerm(i + 1 + perlinPerm(j + 1, seed), seed)
  
  # Calculate contributions from three corners
  var n0, n1, n2: int
  
  let t0 = 500 - ((x0 * x0) div 1000 + (y0 * y0) div 1000)
  if t0 > 0:
    let t0sq = (t0 * t0) div 1000
    n0 = (t0sq * t0sq * perlinGrad2D(gi0, x0, y0)) div 1000000
  
  let t1 = 500 - ((x1 * x1) div 1000 + (y1 * y1) div 1000)
  if t1 > 0:
    let t1sq = (t1 * t1) div 1000
    n1 = (t1sq * t1sq * perlinGrad2D(gi1, x1, y1)) div 1000000
  
  let t2 = 500 - ((x2 * x2) div 1000 + (y2 * y2) div 1000)
  if t2 > 0:
    let t2sq = (t2 * t2) div 1000
    n2 = (t2sq * t2sq * perlinGrad2D(gi2, x2, y2)) div 1000000
  
  # Sum and scale to [0..65535]
  let noise = (n0 + n1 + n2) * 70  # Scale factor for proper range
  result = ((noise + 1000) * 65535) div 2000

proc simplexNoise3D*(x, y, z, scale, seed: int): int {.exportc: "pgSimplexNoise3D", autoExpose: "primitives".} =
  ## 3D Simplex noise - significantly faster than 3D Perlin
  ## scale: Size of noise cells
  ## Returns value in range [0..65535]
  ##
  ## In 3D, Simplex noise is MUCH faster than Perlin (4 gradients vs 8).
  ## Uses tetrahedral grid instead of cubic grid.
  
  const F3 = 333  # 1/3 * 1000
  const G3 = 166  # 1/6 * 1000
  
  let sx = x div scale
  let sy = y div scale
  let sz = z div scale
  let localX = (x mod scale * 1000) div scale
  let localY = (y mod scale * 1000) div scale
  let localZ = (z mod scale * 1000) div scale
  
  let s = ((localX + localY + localZ) * F3) div 1000
  let i = sx + (localX + s) div 1000
  let j = sy + (localY + s) div 1000
  let k = sz + (localZ + s) div 1000
  
  let t = ((i + j + k) * G3) div 1000
  let x0 = localX - ((i * 1000) - (i + j + k) * G3)
  let y0 = localY - ((j * 1000) - (i + j + k) * G3)
  let z0 = localZ - ((k * 1000) - (i + j + k) * G3)
  
  # Determine which simplex we're in (6 possibilities in 3D)
  var i1, j1, k1, i2, j2, k2: int
  if x0 >= y0:
    if y0 >= z0:      # X Y Z order
      i1=1; j1=0; k1=0; i2=1; j2=1; k2=0
    elif x0 >= z0:    # X Z Y order
      i1=1; j1=0; k1=0; i2=1; j2=0; k2=1
    else:             # Z X Y order
      i1=0; j1=0; k1=1; i2=1; j2=0; k2=1
  else:
    if y0 < z0:       # Z Y X order
      i1=0; j1=0; k1=1; i2=0; j2=1; k2=1
    elif x0 < z0:     # Y Z X order
      i1=0; j1=1; k1=0; i2=0; j2=1; k2=1
    else:             # Y X Z order
      i1=0; j1=1; k1=0; i2=1; j2=1; k2=0
  
  # Offsets for corners
  let x1 = x0 - i1 * 1000 + G3
  let y1 = y0 - j1 * 1000 + G3
  let z1 = z0 - k1 * 1000 + G3
  let x2 = x0 - i2 * 1000 + 2 * G3
  let y2 = y0 - j2 * 1000 + 2 * G3
  let z2 = z0 - k2 * 1000 + 2 * G3
  let x3 = x0 - 1000 + 3 * G3
  let y3 = y0 - 1000 + 3 * G3
  let z3 = z0 - 1000 + 3 * G3
  
  # Get gradient hashes
  let gi0 = perlinPerm(i + perlinPerm(j + perlinPerm(k, seed), seed), seed)
  let gi1 = perlinPerm(i + i1 + perlinPerm(j + j1 + perlinPerm(k + k1, seed), seed), seed)
  let gi2 = perlinPerm(i + i2 + perlinPerm(j + j2 + perlinPerm(k + k2, seed), seed), seed)
  let gi3 = perlinPerm(i + 1 + perlinPerm(j + 1 + perlinPerm(k + 1, seed), seed), seed)
  
  # Calculate contributions
  var n0, n1, n2, n3: int
  
  let t0 = 600 - ((x0*x0 + y0*y0 + z0*z0) div 1000)
  if t0 > 0:
    let t0sq = (t0 * t0) div 1000
    n0 = (t0sq * t0sq * perlinGrad3D(gi0, x0, y0, z0)) div 1000000
  
  let t1 = 600 - ((x1*x1 + y1*y1 + z1*z1) div 1000)
  if t1 > 0:
    let t1sq = (t1 * t1) div 1000
    n1 = (t1sq * t1sq * perlinGrad3D(gi1, x1, y1, z1)) div 1000000
  
  let t2 = 600 - ((x2*x2 + y2*y2 + z2*z2) div 1000)
  if t2 > 0:
    let t2sq = (t2 * t2) div 1000
    n2 = (t2sq * t2sq * perlinGrad3D(gi2, x2, y2, z2)) div 1000000
  
  let t3 = 600 - ((x3*x3 + y3*y3 + z3*z3) div 1000)
  if t3 > 0:
    let t3sq = (t3 * t3) div 1000
    n3 = (t3sq * t3sq * perlinGrad3D(gi3, x3, y3, z3)) div 1000000
  
  # Sum and scale
  let noise = (n0 + n1 + n2 + n3) * 32
  result = ((noise + 1000) * 65535) div 2000

## ============================================================================
## WORLEY/CELLULAR NOISE
## Creates organic cellular patterns - stone, water, cells, cracks
## ============================================================================

proc worleyNoise2D*(x, y, scale, seed: int): tuple[f1, f2: int] {.exportc: "pgWorleyNoise2D".} =
  ## 2D Worley/Cellular noise - returns distances to two closest feature points
  ## scale: Size of cells containing random points
  ## Returns: (closest_distance, second_closest_distance) in range [0..65535]
  ##
  ## Worley noise is perfect for:
  ## - Stone/rock textures (f1)
  ## - Cell structures (f1)
  ## - Cracks/veins (f2 - f1)
  ## - Water caustics (f1 with animation)
  ## - Organic patterns
  
  let cellX = x div scale
  let cellY = y div scale
  
  var minDist1 = 999999999
  var minDist2 = 999999999
  
  # Check 3x3 grid of cells around current position
  for offsetY in -1..1:
    for offsetX in -1..1:
      let checkX = cellX + offsetX
      let checkY = cellY + offsetY
      
      # Get random point position within this cell
      let hash = intHash2D(checkX, checkY, seed)
      let pointX = checkX * scale + (hash mod scale)
      let pointY = checkY * scale + ((hash shr 8) mod scale)
      
      # Calculate distance squared to this point (inline to avoid dependency)
      let dx = x - pointX
      let dy = y - pointY
      let dist = dx * dx + dy * dy
      
      # Update closest distances
      if dist < minDist1:
        minDist2 = minDist1
        minDist1 = dist
      elif dist < minDist2:
        minDist2 = dist
  
  # Normalize to [0..65535]
  # Scale factor depends on typical max distance
  let maxDist = scale * scale * 2  # Diagonal across cell
  result.f1 = min(65535, (minDist1 * 65535) div maxDist)
  result.f2 = min(65535, (minDist2 * 65535) div maxDist)

proc worleyNoise3D*(x, y, z, scale, seed: int): tuple[f1, f2: int] {.exportc: "pgWorleyNoise3D".} =
  ## 3D Worley/Cellular noise - for volumetric cellular patterns
  ## scale: Size of cells
  ## Returns: (closest_distance, second_closest_distance) in range [0..65535]
  
  let cellX = x div scale
  let cellY = y div scale
  let cellZ = z div scale
  
  var minDist1 = 999999999
  var minDist2 = 999999999
  
  # Check 3x3x3 grid of cells
  for offsetZ in -1..1:
    for offsetY in -1..1:
      for offsetX in -1..1:
        let checkX = cellX + offsetX
        let checkY = cellY + offsetY
        let checkZ = cellZ + offsetZ
        
        # Get random point position within this cell
        let hash = intHash3D(checkX, checkY, checkZ, seed)
        let pointX = checkX * scale + (hash mod scale)
        let pointY = checkY * scale + ((hash shr 8) mod scale)
        let pointZ = checkZ * scale + ((hash shr 16) mod scale)
        
        # Calculate distance
        let dx = x - pointX
        let dy = y - pointY
        let dz = z - pointZ
        let dist = dx*dx + dy*dy + dz*dz
        
        if dist < minDist1:
          minDist2 = minDist1
          minDist1 = dist
        elif dist < minDist2:
          minDist2 = dist
  
  let maxDist = scale * scale * 3
  result.f1 = min(65535, (minDist1 * 65535) div maxDist)
  result.f2 = min(65535, (minDist2 * 65535) div maxDist)

## ============================================================================
## DOMAIN WARPING
## Warp coordinate space using noise to create complex organic patterns
## ============================================================================

proc domainWarp2D*(x, y, strength, seed: int): tuple[x, y: int] {.exportc: "pgDomainWarp2D".} =
  ## Warp 2D coordinates using Perlin noise
  ## strength: How much to warp (typically 100-500)
  ## Returns: Warped (x, y) coordinates
  ##
  ## Domain warping is a powerful technique:
  ## 1. Generate noise at (x,y)
  ## 2. Use that noise to offset x and y
  ## 3. Sample final noise at warped coordinates
  ## Result: Much more complex, organic patterns than plain noise
  
  # Use two different noise octaves for x and y warping
  let warpX = perlinNoise2D(x, y, 100, seed)
  let warpY = perlinNoise2D(x, y, 100, seed + 1000)
  
  # Map noise [0..65535] to offset [-strength..strength]
  let offsetX = ((warpX - 32768) * strength) div 32768
  let offsetY = ((warpY - 32768) * strength) div 32768
  
  result = (x + offsetX, y + offsetY)

proc domainWarp3D*(x, y, z, strength, seed: int): tuple[x, y, z: int] {.exportc: "pgDomainWarp3D".} =
  ## Warp 3D coordinates using Perlin noise
  ## strength: How much to warp
  ## Returns: Warped (x, y, z) coordinates
  
  let warpX = perlinNoise3D(x, y, z, 100, seed)
  let warpY = perlinNoise3D(x, y, z, 100, seed + 1000)
  let warpZ = perlinNoise3D(x, y, z, 100, seed + 2000)
  
  let offsetX = ((warpX - 32768) * strength) div 32768
  let offsetY = ((warpY - 32768) * strength) div 32768
  let offsetZ = ((warpZ - 32768) * strength) div 32768
  
  result = (x + offsetX, y + offsetY, z + offsetZ)

## ============================================================================
## ADVANCED NOISE TECHNIQUES (FBM Variations)
## Different ways to combine octaves for specific effects
## ============================================================================

proc ridgedNoise2D*(x, y, octaves, scale, seed: int): int {.exportc: "pgRidgedNoise2D", autoExpose: "primitives".} =
  ## Ridged multifractal noise - creates sharp ridges like mountains
  ## Perfect for: Mountain ridges, crystalline structures, sharp terrain features
  ##
  ## Unlike standard FBM, this inverts and sharpens the noise to create ridges.
  var total = 0
  var amplitude = 32768
  var frequency = scale
  var maxValue = 0
  
  for i in 0..<octaves:
    var n = perlinNoise2D(x, y, frequency, seed + i)
    n = 65535 - iabs(n - 32768) * 2  # Invert and sharpen
    total += (n * amplitude) div 65535
    maxValue += amplitude
    amplitude = amplitude div 2
    frequency = frequency div 2
  
  if maxValue > 0:
    result = (total * 65535) div maxValue
  else:
    result = 0

proc billowNoise2D*(x, y, octaves, scale, seed: int): int {.exportc: "pgBillowNoise2D", autoExpose: "primitives".} =
  ## Billow noise - creates puffy cloud-like patterns
  ## Perfect for: Clouds, steam, smoke, fluffy textures
  ##
  ## Takes absolute value of noise for billowy appearance.
  var total = 0
  var amplitude = 32768
  var frequency = scale
  var maxValue = 0
  
  for i in 0..<octaves:
    var n = perlinNoise2D(x, y, frequency, seed + i)
    n = iabs(n - 32768) * 2  # Take absolute value for billows
    total += (n * amplitude) div 65535
    maxValue += amplitude
    amplitude = amplitude div 2
    frequency = frequency div 2
  
  if maxValue > 0:
    result = (total * 65535) div maxValue
  else:
    result = 0

proc turbulenceNoise2D*(x, y, octaves, scale, seed: int): int {.exportc: "pgTurbulenceNoise2D", autoExpose: "primitives".} =
  ## Turbulence noise - chaotic, swirling patterns
  ## Perfect for: Fire, marble, chaotic energy, magic effects
  ##
  ## Similar to billow but with different octave combination.
  var total = 0
  var frequency = scale
  
  for i in 0..<octaves:
    let n = perlinNoise2D(x, y, frequency, seed + i)
    total += iabs(n - 32768)
    frequency = frequency div 2
  
  # Average and normalize
  result = min(65535, (total * 2) div octaves)

proc warpedNoise2D*(x, y, octaves, scale, warpStrength, seed: int): int {.exportc: "pgWarpedNoise2D", autoExpose: "primitives".} =
  ## Fractal noise with domain warping - creates complex organic patterns
  ## Perfect for: Wood grain, marble, complex terrain, organic textures
  ##
  ## This is where it gets REALLY interesting - combines FBM with domain warping
  ## for incredibly complex patterns that would be impossible with simple noise.
  
  # First warp pass
  let (wx1, wy1) = domainWarp2D(x, y, warpStrength, seed)
  
  # Second warp pass (optional, for even more complexity)
  let (wx2, wy2) = domainWarp2D(wx1, wy1, warpStrength div 2, seed + 1000)
  
  # Sample fractional noise at warped coordinates
  var total = 0
  var amplitude = 32768
  var frequency = scale
  var maxValue = 0
  
  for i in 0..<octaves:
    total += (perlinNoise2D(wx2, wy2, frequency, seed + i) * amplitude) div 65535
    maxValue += amplitude
    amplitude = amplitude div 2
    frequency = frequency div 2
  
  if maxValue > 0:
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

# Explicit module initialization - ensures plugin registration happens
# The autoExpose pragmas generate register_* procs, we queue them explicitly for WASM
proc initPrimitivesModule*() =
  ## Called explicitly to ensure module initialization in WASM builds
  ## Manually queues all registration functions that were generated by {.autoExpose.} pragmas
  
  # Math primitives
  queuePluginRegistration(register_idiv)
  queuePluginRegistration(register_imod)
  queuePluginRegistration(register_iabs)
  queuePluginRegistration(register_sign)
  queuePluginRegistration(register_clamp)
  queuePluginRegistration(register_wrap)
  queuePluginRegistration(register_lerp)
  queuePluginRegistration(register_smoothstep)
  queuePluginRegistration(register_map)
  
  # Basic hash & noise
  queuePluginRegistration(register_intHash)
  queuePluginRegistration(register_intHash2D)
  
  # Perlin noise
  queuePluginRegistration(register_perlinNoise2D)
  queuePluginRegistration(register_perlinNoise3D)
  
  # Simplex noise
  queuePluginRegistration(register_simplexNoise2D)
  queuePluginRegistration(register_simplexNoise3D)
  
  # Worley/Cellular noise - Note: Returns tuples, use in compiled Nim only
  # (not exposed to nimini due to tuple return type)
  
  # Domain warping - Note: Returns tuples, use in compiled Nim only
  # Use warpedNoise2D/3D for exposed warped noise functions
  
  # Advanced noise techniques
  queuePluginRegistration(register_ridgedNoise2D)
  queuePluginRegistration(register_billowNoise2D)
  queuePluginRegistration(register_turbulenceNoise2D)
  queuePluginRegistration(register_warpedNoise2D)

when isMainModule:
  echo "Procedural Generation Primitives Library"
  echo "Designed for deterministic, composable procedural generation"
  echo "Compatible with TiXL/Tool3 style node-based workflows"
