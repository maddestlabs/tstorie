## Demo: CPU Preview → GPU Execution
## 
## Shows how to:
## 1. Use noise composer to preview on CPU
## 2. Generate WGSL shader from same config
## 3. Execute shader on GPU via WebGPU
## 4. Compare results (CPU vs GPU)

import std/[strformat, math, times, tables]
import ../../lib/[primitives, noise_composer]

when defined(emscripten):
  import webgpu_compute

proc generateTerrainCPU*(width, height: int, offsetX, offsetY: int = 0): seq[uint32] =
  ## Generate terrain noise on CPU (for preview/fallback)
  echo "[CPU] Generating terrain..."
  
  let start = cpuTime()
  
  # Configure noise
  let terrain = noise(ntPerlin2D)
    .seed(42)
    .scale(100)
    .octaves(3)
    .gain(500)
    .lacunarity(2000)
  
  # Generate pixels
  result = newSeq[uint32](width * height)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let value = terrain.sample2D(x + offsetX, y + offsetY)
      result[y * width + x] = uint32(value)
  
  let elapsed = cpuTime() - start
  echo fmt"[CPU] Generated {width}x{height} in {elapsed:.3f}s"

when defined(emscripten):
  proc generateTerrainGPU*(ctx: WebGPUContext, width, height: int, offsetX, offsetY: int = 0): bool =
    ## Generate terrain noise on GPU via WebGPU compute shader
    echo "[GPU] Generating terrain..."
    
    # Configure noise (same as CPU)
    let terrain = noise(ntPerlin2D)
      .seed(42)
      .scale(100)
      .octaves(3)
      .gain(500)
      .lacunarity(2000)
    
    # Generate WGSL shader
    let wgsl = terrain.toWGSL()
    
    # First time: set up pipeline
    if not ctx.shaders.hasKey("terrain_shader"):
      echo "[GPU] Setting up compute pipeline..."
      if not ctx.setupComputeShader("terrain", wgsl, width, height):
        echo "[GPU] Failed to setup compute shader"
        return false
    
    # Update params if offsetX/Y changed
    if offsetX != 0 or offsetY != 0:
      if not ctx.updateParams("terrain", width, height, offsetX, offsetY):
        echo "[GPU] Failed to update params"
        return false
    
    # Execute shader
    return ctx.executeShader("terrain", width, height)

proc generateCloudsCPU*(width, height: int, offsetX, offsetY: int = 0): seq[uint32] =
  ## Generate cloud noise on CPU
  echo "[CPU] Generating clouds..."
  
  let clouds = noise(ntSimplex2D)
    .seed(999)
    .scale(150)
    .octaves(3)
    .gain(600)
  
  result = newSeq[uint32](width * height)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let value = clouds.sample2D(x + offsetX, y + offsetY)
      result[y * width + x] = uint32(value)

when defined(emscripten):
  proc generateCloudsGPU*(ctx: WebGPUContext, width, height: int, offsetX, offsetY: int = 0): bool =
    ## Generate cloud noise on GPU
    echo "[GPU] Generating clouds..."
    
    let clouds = noise(ntSimplex2D)
      .seed(999)
      .scale(150)
      .octaves(3)
      .gain(600)
    
    let wgsl = clouds.toWGSL()
    
    if not ctx.shaders.hasKey("clouds_shader"):
      if not ctx.setupComputeShader("clouds", wgsl, width, height):
        return false
    
    if offsetX != 0 or offsetY != 0:
      discard ctx.updateParams("clouds", width, height, offsetX, offsetY)
    
    return ctx.executeShader("clouds", width, height)

proc generateMountainsCPU*(width, height: int, offsetX, offsetY: int = 0): seq[uint32] =
  ## Generate mountain noise on CPU (ridged)
  echo "[CPU] Generating mountains..."
  
  let mountains = noise(ntPerlin2D)
    .seed(777)
    .scale(80)
    .octaves(4)
    .ridged()
  
  result = newSeq[uint32](width * height)
  for y in 0 ..< height:
    for x in 0 ..< width:
      let value = mountains.sample2D(x + offsetX, y + offsetY)
      result[y * width + x] = uint32(value)

when defined(emscripten):
  proc generateMountainsGPU*(ctx: WebGPUContext, width, height: int, offsetX, offsetY: int = 0): bool =
    ## Generate mountain noise on GPU (ridged)
    echo "[GPU] Generating mountains..."
    
    let mountains = noise(ntPerlin2D)
      .seed(777)
      .scale(80)
      .octaves(4)
      .ridged()
    
    let wgsl = mountains.toWGSL()
    
    if not ctx.shaders.hasKey("mountains_shader"):
      if not ctx.setupComputeShader("mountains", wgsl, width, height):
        return false
    
    if offsetX != 0 or offsetY != 0:
      discard ctx.updateParams("mountains", width, height, offsetX, offsetY)
    
    return ctx.executeShader("mountains", width, height)

# Example usage in a nimini script:
#
# ```nim
# # Small preview on CPU
# let preview = generateTerrainCPU(100, 100)
# # Draw preview to canvas...
#
# # Full resolution on GPU
# let ctx = newWebGPUContext()
# if generateTerrainGPU(ctx, 1920, 1080):
#   echo "GPU generation complete!"
# ```

when defined(emscripten):
  export WebGPUContext, newWebGPUContext
  export generateTerrainGPU, generateCloudsGPU, generateMountainsGPU

export generateTerrainCPU, generateCloudsCPU, generateMountainsCPU
