## Noise Composer - Composable Noise API with Multi-Target Compilation
##
## Build complex noise patterns using a fluent API:
##   noise(Perlin).seed(42).scale(100).octaves(4).warp(200)
##
## Compile to multiple targets:
##   - Direct execution (Nim/Nimini)
##   - WGSL compute shaders (WebGPU)
##   - Audio modulation functions (future)

import std/[strformat, strutils, sequtils]
import primitives

type
  NoiseType* = enum
    ntPerlin2D    ## Perlin noise (2D) - natural terrain
    ntPerlin3D    ## Perlin noise (3D) - volumetric
    ntSimplex2D   ## Simplex noise (2D) - faster, cleaner
    ntSimplex3D   ## Simplex noise (3D) - much faster than Perlin3D
    ntWorley2D    ## Worley/Cellular (2D) - organic cells
    ntWorley3D    ## Worley/Cellular (3D) - volumetric cells
    ntValue2D     ## Value noise (2D) - simple grid noise
    ntFractal2D   ## Fractal/FBM (2D) - multi-octave value noise
  
  FBMMode* = enum
    fmStandard    ## Standard FBM (additive octaves)
    fmRidged      ## Ridged (sharp peaks)
    fmBillow      ## Billow (puffy clouds)
    fmTurbulence  ## Turbulence (chaotic)
  
  NoiseConfig* = object
    noiseType*: NoiseType
    seed*: int
    scale*: int           # Cell size in pixels/units
    octaves*: int         # Number of FBM layers (1 = no FBM)
    lacunarity*: int      # Frequency multiplier per octave (1000 = 1.0x, 2000 = 2.0x)
    gain*: int            # Amplitude multiplier per octave (1000 = 1.0x, 500 = 0.5x)
    warpStrength*: int    # Domain warping amount (0 = no warp)
    warpOctaves*: int     # Octaves for domain warp noise
    fbmMode*: FBMMode     # How to combine octaves
    is3D*: bool           # Whether this is a 3D noise configuration

## ============================================================================
## BUILDER API - Fluent interface for noise configuration
## ============================================================================

proc noise*(ntype: NoiseType): NoiseConfig =
  ## Start building a noise configuration
  ## Example: noise(Perlin2D)
  result = NoiseConfig(
    noiseType: ntype,
    seed: 0,
    scale: 100,
    octaves: 1,
    lacunarity: 2000,  # 2.0x frequency increase per octave
    gain: 500,         # 0.5x amplitude decrease per octave
    warpStrength: 0,
    warpOctaves: 1,
    fbmMode: fmStandard,
    is3D: ntype in [ntPerlin3D, ntSimplex3D, ntWorley3D]
  )

proc seed*(cfg: NoiseConfig, s: int): NoiseConfig =
  ## Set the random seed
  ## Example: noise(Perlin2D).seed(42)
  result = cfg
  result.seed = s

proc scale*(cfg: NoiseConfig, s: int): NoiseConfig =
  ## Set the noise scale (cell size)
  ## Smaller = more detail, Larger = broader features
  ## Example: noise(Perlin2D).scale(50)
  result = cfg
  result.scale = s

proc octaves*(cfg: NoiseConfig, o: int): NoiseConfig =
  ## Set number of octaves for FBM (fractal brownian motion)
  ## Each octave adds finer detail
  ## Example: noise(Perlin2D).octaves(4)
  result = cfg
  result.octaves = o

proc lacunarity*(cfg: NoiseConfig, lac: int): NoiseConfig =
  ## Set frequency multiplier per octave (1000 = 1.0x)
  ## Default 2000 (2.0x) - each octave is twice the frequency
  ## Example: noise(Perlin2D).lacunarity(2000)
  result = cfg
  result.lacunarity = lac

proc gain*(cfg: NoiseConfig, g: int): NoiseConfig =
  ## Set amplitude multiplier per octave (1000 = 1.0x)
  ## Default 500 (0.5x) - each octave is half the amplitude
  ## Example: noise(Perlin2D).gain(500)
  result = cfg
  result.gain = g

proc warp*(cfg: NoiseConfig, strength: int, octaves: int = 1): NoiseConfig =
  ## Enable domain warping for organic complexity
  ## strength: How much to warp (100-500 typical)
  ## octaves: Octaves for the warping noise itself
  ## Example: noise(Perlin2D).warp(200)
  result = cfg
  result.warpStrength = strength
  result.warpOctaves = octaves

proc ridged*(cfg: NoiseConfig): NoiseConfig =
  ## Use ridged FBM mode (sharp peaks like mountains)
  ## Example: noise(Perlin2D).octaves(4).ridged()
  result = cfg
  result.fbmMode = fmRidged

proc billow*(cfg: NoiseConfig): NoiseConfig =
  ## Use billow FBM mode (puffy clouds)
  ## Example: noise(Perlin2D).octaves(3).billow()
  result = cfg
  result.fbmMode = fmBillow

proc turbulent*(cfg: NoiseConfig): NoiseConfig =
  ## Use turbulence FBM mode (chaotic)
  ## Example: noise(Perlin2D).octaves(3).turbulent()
  result = cfg
  result.fbmMode = fmTurbulence

## ============================================================================
## DIRECT EXECUTION - Sample noise at coordinates
## ============================================================================

proc sample2D*(cfg: NoiseConfig, x, y: int): int =
  ## Sample the configured noise at 2D coordinates
  ## Returns value in range [0..65535]
  if cfg.is3D:
    raise newException(ValueError, "Cannot sample 3D noise in 2D - use sample3D()")
  
  # Apply domain warping if enabled
  var sampX = x
  var sampY = y
  if cfg.warpStrength > 0:
    let (wx, wy) = domainWarp2D(x, y, cfg.warpStrength, cfg.seed + 9999)
    sampX = wx
    sampY = wy
  
  # Single octave - direct sampling
  if cfg.octaves == 1:
    case cfg.noiseType
    of ntPerlin2D:
      return perlinNoise2D(sampX, sampY, cfg.scale, cfg.seed)
    of ntSimplex2D:
      return simplexNoise2D(sampX, sampY, cfg.scale, cfg.seed)
    of ntWorley2D:
      let (f1, _) = worleyNoise2D(sampX, sampY, cfg.scale, cfg.seed)
      return f1
    of ntValue2D:
      return valueNoise2D(sampX div cfg.scale, sampY div cfg.scale, cfg.seed)
    of ntFractal2D:
      return fractalNoise2D(sampX, sampY, cfg.octaves, cfg.scale, cfg.seed)
    else:
      raise newException(ValueError, "Unsupported 2D noise type: " & $cfg.noiseType)
  
  # Multi-octave FBM
  var total: int64 = 0  # Use int64 to prevent overflow
  var amplitude: int64 = 32768
  var frequency = cfg.scale
  var maxValue: int64 = 0
  
  for i in 0..<cfg.octaves:
    var value: int
    case cfg.noiseType
    of ntPerlin2D:
      value = perlinNoise2D(sampX, sampY, frequency, cfg.seed + i)
    of ntSimplex2D:
      value = simplexNoise2D(sampX, sampY, frequency, cfg.seed + i)
    of ntWorley2D:
      let (f1, _) = worleyNoise2D(sampX, sampY, frequency, cfg.seed + i)
      value = f1
    of ntValue2D:
      value = valueNoise2D(sampX div frequency, sampY div frequency, cfg.seed + i)
    else:
      value = 32768  # Fallback neutral
    
    # Apply FBM mode transformations
    case cfg.fbmMode
    of fmRidged:
      value = 65535 - iabs(value - 32768) * 2
    of fmBillow:
      value = iabs(value - 32768) * 2
    of fmTurbulence:
      value = iabs(value - 32768)
    of fmStandard:
      discard  # No transformation
    
    # Use int64 for intermediate calculations to prevent overflow
    total += (int64(value) * amplitude) div 65535
    maxValue += amplitude
    amplitude = (amplitude * int64(cfg.gain)) div 1000
    frequency = (frequency * 1000) div cfg.lacunarity
  
  # Normalize
  if maxValue > 0:
    result = int((total * 65535) div maxValue)
  else:
    result = 0

proc sample3D*(cfg: NoiseConfig, x, y, z: int): int =
  ## Sample the configured noise at 3D coordinates
  ## Returns value in range [0..65535]
  if not cfg.is3D:
    raise newException(ValueError, "Cannot sample 2D noise in 3D - use sample2D()")
  
  # Apply domain warping if enabled
  var sampX = x
  var sampY = y
  var sampZ = z
  if cfg.warpStrength > 0:
    let (wx, wy, wz) = domainWarp3D(x, y, z, cfg.warpStrength, cfg.seed + 9999)
    sampX = wx
    sampY = wy
    sampZ = wz
  
  # Single octave
  if cfg.octaves == 1:
    case cfg.noiseType
    of ntPerlin3D:
      return perlinNoise3D(sampX, sampY, sampZ, cfg.scale, cfg.seed)
    of ntSimplex3D:
      return simplexNoise3D(sampX, sampY, sampZ, cfg.scale, cfg.seed)
    of ntWorley3D:
      let (f1, _) = worleyNoise3D(sampX, sampY, sampZ, cfg.scale, cfg.seed)
      return f1
    else:
      raise newException(ValueError, "Unsupported 3D noise type: " & $cfg.noiseType)
  
  # Multi-octave FBM (similar to 2D)
  var total: int64 = 0  # Use int64 to prevent overflow
  var amplitude: int64 = 32768
  var frequency = cfg.scale
  var maxValue: int64 = 0
  
  for i in 0..<cfg.octaves:
    var value: int
    case cfg.noiseType
    of ntPerlin3D:
      value = perlinNoise3D(sampX, sampY, sampZ, frequency, cfg.seed + i)
    of ntSimplex3D:
      value = simplexNoise3D(sampX, sampY, sampZ, frequency, cfg.seed + i)
    of ntWorley3D:
      let (f1, _) = worleyNoise3D(sampX, sampY, sampZ, frequency, cfg.seed + i)
      value = f1
    else:
      value = 32768
    
    case cfg.fbmMode
    of fmRidged:
      value = 65535 - iabs(value - 32768) * 2
    of fmBillow:
      value = iabs(value - 32768) * 2
    of fmTurbulence:
      value = iabs(value - 32768)
    of fmStandard:
      discard
    
    # Use int64 for intermediate calculations to prevent overflow
    total += (int64(value) * amplitude) div 65535
    maxValue += amplitude
    amplitude = (amplitude * int64(cfg.gain)) div 1000
    frequency = (frequency * 1000) div cfg.lacunarity
  
  if maxValue > 0:
    result = int((total * 65535) div maxValue)
  else:
    result = 0



## ============================================================================
## WGSL CODE GENERATION - Convert noise configs to WebGPU compute shaders
## ============================================================================

proc generateWGSLHelpers(): string =
  ## Generate helper functions needed by all noise types
  result = """
// ============================================================================
// Hash Functions for Noise Generation
// ============================================================================

fn hash11(p: u32) -> u32 {
  var n = p;
  n = (n << 13u) ^ n;
  n = n * (n * n * 15731u + 789221u) + 1376312589u;
  return n;
}

fn hash21(p: vec2<u32>) -> u32 {
  var n = p.x;
  n = (n << 13u) ^ n;
  n = n * (n * n * 15731u + 789221u) + 1376312589u;
  n = n ^ (p.y * 1103515245u);
  return n;
}

fn hash31(p: vec3<u32>) -> u32 {
  var n = p.x;
  n = (n << 13u) ^ n;
  n = n * (n * n * 15731u + 789221u) + 1376312589u;
  n = n ^ (p.y * 1103515245u);
  n = n ^ (p.z * 12345789u);
  return n;
}

// Integer interpolation (0..65536 range)
fn smoothstep(t: u32) -> u32 {
  let v = (t * t) / 65536u;
  return (v * (196608u - (t * 2u))) / 65536u;
}

fn lerp(a: i32, b: i32, t: u32) -> i32 {
  return a + (((b - a) * i32(t)) / 65536);
}

"""

proc generateWGSLPerlin2D(scale: int, seed: int): string =
  ## Generate Perlin 2D noise function in WGSL
  result = fmt"""
// ============================================================================
// Perlin 2D Noise (seed: {seed}, scale: {scale})
// ============================================================================

fn perlinGrad2D(hash: u32, x: i32, y: i32) -> i32 {{
  let h = hash & 7u;
  let u = select(y, x, h < 4u);
  let v = select(x, y, h < 4u);
  
  let a = select(-u, u, (h & 1u) == 0u);
  let b = select(-v, v, (h & 2u) == 0u);
  
  return (a + b) * 23170 / 1000;
}}

fn perlinNoise2D(xIn: i32, yIn: i32) -> u32 {{
  let scaledX = (xIn * 1000) / {scale};
  let scaledY = (yIn * 1000) / {scale};
  
  let x0 = scaledX / 1000;
  let y0 = scaledY / 1000;
  let x1 = x0 + 1;
  let y1 = y0 + 1;
  
  let fx = u32(scaledX - x0 * 1000) * 65536 / 1000;
  let fy = u32(scaledY - y0 * 1000) * 65536 / 1000;
  
  let u = smoothstep(fx);
  let v = smoothstep(fy);
  
  let seed = {seed}u;
  let p00 = hash21(vec2<u32>(u32(x0), u32(y0)) + vec2<u32>(seed, seed * 2u));
  let p10 = hash21(vec2<u32>(u32(x1), u32(y0)) + vec2<u32>(seed, seed * 2u));
  let p01 = hash21(vec2<u32>(u32(x0), u32(y1)) + vec2<u32>(seed, seed * 2u));
  let p11 = hash21(vec2<u32>(u32(x1), u32(y1)) + vec2<u32>(seed, seed * 2u));
  
  let dx = scaledX - x0 * 1000;
  let dy = scaledY - y0 * 1000;
  
  let n00 = perlinGrad2D(p00, dx, dy);
  let n10 = perlinGrad2D(p10, dx - 1000, dy);
  let n01 = perlinGrad2D(p01, dx, dy - 1000);
  let n11 = perlinGrad2D(p11, dx - 1000, dy - 1000);
  
  let nx0 = lerp(n00, n10, u);
  let nx1 = lerp(n01, n11, u);
  let nxy = lerp(nx0, nx1, v);
  
  return u32((nxy + 32768) * 2);
}}

"""

proc generateWGSLSimplex2D(scale: int, seed: int): string =
  ## Generate Simplex 2D noise function in WGSL
  result = fmt"""
// ============================================================================
// Simplex 2D Noise (seed: {seed}, scale: {scale})
// ============================================================================

fn simplexGrad2D(hash: u32, x: i32, y: i32) -> i32 {{
  let h = hash & 7u;
  return select(
    select(-x - y, x + y, (h & 1u) == 0u),
    select(-x + y, x - y, (h & 1u) == 0u),
    (h & 4u) == 0u
  ) * 18919 / 1000;
}}

fn simplexNoise2D(xIn: i32, yIn: i32) -> u32 {{
  let scaledX = (xIn * 1000) / {scale};
  let scaledY = (yIn * 1000) / {scale};
  
  let F2 = 366;
  let G2 = 211;
  
  let s = ((scaledX + scaledY) * F2) / 1000;
  let i = (scaledX + s) / 1000;
  let j = (scaledY + s) / 1000;
  
  let t = ((i + j) * G2);
  let X0 = i * 1000 - t;
  let Y0 = j * 1000 - t;
  let x0 = scaledX - X0;
  let y0 = scaledY - Y0;
  
  var i1 = 0;
  var j1 = 0;
  if (x0 > y0) {{
    i1 = 1;
    j1 = 0;
  }} else {{
    i1 = 0;
    j1 = 1;
  }}
  
  let x1 = x0 - i1 * 1000 + G2;
  let y1 = y0 - j1 * 1000 + G2;
  let x2 = x0 - 1000 + 2 * G2;
  let y2 = y0 - 1000 + 2 * G2;
  
  let seed = {seed}u;
  let gi0 = hash21(vec2<u32>(u32(i), u32(j)) + vec2<u32>(seed, seed * 2u));
  let gi1 = hash21(vec2<u32>(u32(i + i1), u32(j + j1)) + vec2<u32>(seed, seed * 2u));
  let gi2 = hash21(vec2<u32>(u32(i + 1), u32(j + 1)) + vec2<u32>(seed, seed * 2u));
  
  var n0 = 0;
  var n1 = 0;
  var n2 = 0;
  
  let t0 = 500 - ((x0 * x0 + y0 * y0) / 1000);
  if (t0 > 0) {{
    let t0sq = (t0 * t0) / 1000;
    n0 = (t0sq * t0sq * simplexGrad2D(gi0, x0, y0)) / 1000000;
  }}
  
  let t1 = 500 - ((x1 * x1 + y1 * y1) / 1000);
  if (t1 > 0) {{
    let t1sq = (t1 * t1) / 1000;
    n1 = (t1sq * t1sq * simplexGrad2D(gi1, x1, y1)) / 1000000;
  }}
  
  let t2 = 500 - ((x2 * x2 + y2 * y2) / 1000);
  if (t2 > 0) {{
    let t2sq = (t2 * t2) / 1000;
    n2 = (t2sq * t2sq * simplexGrad2D(gi2, x2, y2)) / 1000000;
  }}
  
  let noise = (n0 + n1 + n2) * 70;
  return u32(((noise + 1000) * 65535) / 2000);
}}

"""

proc generateWGSLWorley2D(scale: int, seed: int): string =
  ## Generate Worley/Cellular 2D noise function in WGSL
  result = fmt"""
// ============================================================================
// Worley 2D Noise (seed: {seed}, scale: {scale})
// ============================================================================

fn worleyNoise2D(xIn: i32, yIn: i32) -> u32 {{
  let scaledX = (xIn * 1000) / {scale};
  let scaledY = (yIn * 1000) / {scale};
  
  let cellX = scaledX / 1000;
  let cellY = scaledY / 1000;
  
  let fx = scaledX - cellX * 1000;
  let fy = scaledY - cellY * 1000;
  
  var minDist = 999999999;
  
  for (var dy = -1; dy <= 1; dy = dy + 1) {{
    for (var dx = -1; dx <= 1; dx = dx + 1) {{
      let neighborX = cellX + dx;
      let neighborY = cellY + dy;
      
      let seed = {seed}u;
      let h = hash21(vec2<u32>(u32(neighborX), u32(neighborY)) + vec2<u32>(seed, seed * 2u));
      
      let pointX = ((h & 0xFFFFu) * 1000) / 65536;
      let pointY = (((h >> 16u) & 0xFFFFu) * 1000) / 65536;
      
      let vecX = fx - (dx * 1000 + i32(pointX));
      let vecY = fy - (dy * 1000 + i32(pointY));
      
      let dist = vecX * vecX + vecY * vecY;
      minDist = select(minDist, dist, dist < minDist);
    }}
  }}
  
  let normalized = (minDist * 65535) / 2000000;
  return u32(65535 - clamp(normalized, 0, 65535));
}}

"""

proc toWGSL*(cfg: NoiseConfig): string =
  ## Generate complete WGSL compute shader code for this noise configuration
  ## Returns a complete compute shader with bindings ready to execute
  
  # Start with helpers
  result = generateWGSLHelpers()
  result.add("\n")
  
  # Generate base noise function
  case cfg.noiseType
  of ntPerlin2D:
    result.add(generateWGSLPerlin2D(cfg.scale, cfg.seed))
  of ntSimplex2D:
    result.add(generateWGSLSimplex2D(cfg.scale, cfg.seed))
  of ntWorley2D:
    result.add(generateWGSLWorley2D(cfg.scale, cfg.seed))
  else:
    result.add("// TODO: WGSL generation for " & $cfg.noiseType & "\n")
    result.add(fmt"""
fn baseNoise(x: i32, y: i32) -> u32 {{
  return 32768u; // Placeholder
}}
""")
  
  # Generate FBM wrapper if multi-octave
  if cfg.octaves > 1:
    let fbmTransform = case cfg.fbmMode
      of fmRidged: "value = 65535u - abs(i32(value) - 32768) * 2u"
      of fmBillow: "value = u32(abs(i32(value) - 32768) * 2)"
      of fmTurbulence: "value = u32(abs(i32(value) - 32768))"
      of fmStandard: "// Standard FBM - no transform"
    
    let baseFunc = case cfg.noiseType
      of ntPerlin2D: "perlinNoise2D"
      of ntSimplex2D: "simplexNoise2D"
      of ntWorley2D: "worleyNoise2D"
      else: "baseNoise"
    
    result.add(fmt"""
// ============================================================================
// FBM Wrapper ({cfg.octaves} octaves, {cfg.fbmMode} mode)
// ============================================================================

fn sampleNoise(x: u32, y: u32) -> u32 {{
  var total: u32 = 0u;
  var amplitude: u32 = 32768u;  // Start at 0.5 * 65536
  var frequency: u32 = 1000u;
  var maxValue: u32 = 0u;
  
  for (var i = 0; i < {cfg.octaves}; i = i + 1) {{
    let scaledX = (i32(x) * i32(frequency)) / 1000;
    let scaledY = (i32(y) * i32(frequency)) / 1000;
    
    var value = {baseFunc}(scaledX, scaledY);
    
    // Apply FBM transform
    {fbmTransform};
    
    total = total + ((value * amplitude) / 65536u);
    maxValue = maxValue + amplitude;
    
    amplitude = (amplitude * {cfg.gain}u) / 1000u;
    frequency = (frequency * {cfg.lacunarity}u) / 1000u;
  }}
  
  if (maxValue > 0u) {{
    return (total * 65535u) / maxValue;
  }}
  return 0u;
}}

""")
  else:
    # Single octave - just alias the base function
    let baseFunc = case cfg.noiseType
      of ntPerlin2D: "perlinNoise2D"
      of ntSimplex2D: "simplexNoise2D"
      of ntWorley2D: "worleyNoise2D"
      else: "baseNoise"
    
    result.add(fmt"""
fn sampleNoise(x: u32, y: u32) -> u32 {{
  return {baseFunc}(i32(x), i32(y));
}}

""")
  
  # Add compute shader bindings and main function
  result.add("""
// ============================================================================
// Compute Shader Bindings and Entry Point
// ============================================================================

@group(0) @binding(0) var<storage, read_write> output: array<u32>;
@group(0) @binding(1) var<uniform> params: vec4<u32>;  // width, height, offsetX, offsetY

@compute @workgroup_size(8, 8)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
  let width = params.x;
  let height = params.y;
  let offsetX = params.z;
  let offsetY = params.w;
  
  let x = global_id.x;
  let y = global_id.y;
  
  // Bounds check
  if (x >= width || y >= height) {
    return;
  }
  
  // Calculate noise value
  let noiseValue = sampleNoise(x + offsetX, y + offsetY);
  
  // Write to output buffer
  let idx = y * width + x;
  output[idx] = noiseValue;
}
""")

## ============================================================================
## USAGE EXAMPLES (for documentation)
## ============================================================================

when isMainModule:
  echo "Noise Composer Examples:"
  echo ""
  
  # Example 1: Simple Perlin
  let terrain = noise(ntPerlin2D).seed(42).scale(100)
  echo "Terrain at (50, 50): ", terrain.sample2D(50, 50)
  
  # Example 2: Multi-octave clouds
  let clouds = noise(ntSimplex2D).seed(123).scale(60).octaves(3)
  echo "Clouds at (100, 100): ", clouds.sample2D(100, 100)
  
  # Example 3: Mountain ridges
  let mountains = noise(ntPerlin2D).seed(999).scale(80).octaves(4).ridged()
  echo "Mountains at (200, 150): ", mountains.sample2D(200, 150)
  
  # Example 4: Warped marble
  let marble = noise(ntPerlin2D).seed(555).scale(60).octaves(4).warp(200)
  echo "Marble at (75, 75): ", marble.sample2D(75, 75)
  
  echo ""
  echo "WGSL Generation:"
  echo "================"
  echo terrain.toWGSL()
