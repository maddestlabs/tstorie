## Nimini API for WebGPU Compute Shaders
## 
## Provides simple functions for compiling and executing GPU shaders from nimini scripts.
## 
## Example usage:
## ```nim
## # Define noise configuration
## let terrain = noise(ntPerlin2D).seed(42).scale(100).octaves(3)
##
## # Compile to GPU shader
## compileShader("terrain", terrain)
##
## # Execute on GPU
## executeShader("terrain", 1920, 1080)
##
## # Read results (async)
## let pixels = await getShaderOutput("terrain")
## ```

import std/[strformat, tables]
import ../../lib/noise_composer

when defined(emscripten):
  import webgpu_compute
  
  # Global WebGPU context (lazy initialized)
  var globalWebGPU: WebGPUContext = nil
  
  proc getGlobalContext(): WebGPUContext =
    ## Get or create the global WebGPU context
    if globalWebGPU.isNil:
      globalWebGPU = newWebGPUContext()
      if globalWebGPU.checkInitialized():
        echo "[Nimini/WebGPU] Initialized"
      else:
        echo "[Nimini/WebGPU] WARNING: WebGPU not available"
    return globalWebGPU
  
  proc compileShader*(name: string, config: NoiseConfig): bool =
    ## Compile a noise configuration to a GPU shader
    ## 
    ## Example:
    ##   let terrain = noise(ntPerlin2D).seed(42).scale(100).octaves(3)
    ##   compileShader("terrain", terrain)
    let ctx = getGlobalContext()
    
    # Generate WGSL from config
    let wgsl = config.toWGSL()
    
    # Compile shader
    let shaderName = name & "_shader"
    if not ctx.compileShader(shaderName, wgsl):
      echo fmt"[Nimini] Failed to compile shader: {name}"
      return false
    
    # Create pipeline
    let pipelineName = name & "_pipeline"
    if not ctx.createPipeline(pipelineName, shaderName):
      echo fmt"[Nimini] Failed to create pipeline: {name}"
      return false
    
    echo fmt"[Nimini] Shader compiled: {name}"
    return true
  
  proc setupShaderBuffers*(name: string, width, height: int): bool =
    ## Set up buffers for a compiled shader
    ## 
    ## Example:
    ##   setupShaderBuffers("terrain", 1920, 1080)
    let ctx = getGlobalContext()
    
    let outputName = name & "_output"
    let paramsName = name & "_params"
    let bindGroupName = name & "_bindings"
    let pipelineName = name & "_pipeline"
    
    # Create output buffer if not exists
    if outputName notin ctx.buffers:
      let bufferSize = width * height * 4  # 4 bytes per u32
      if not ctx.createStorageBuffer(outputName, bufferSize):
        return false
    
    # Create params buffer if not exists
    if paramsName notin ctx.buffers:
      if not ctx.createUniformBuffer(paramsName, 16):
        return false
    
    # Write params
    if not ctx.writeBufferU32(paramsName, @[width.uint32, height.uint32, 0'u32, 0'u32]):
      return false
    
    # Create bind group if not exists
    if bindGroupName notin ctx.bindGroups:
      if not ctx.createBindGroup(bindGroupName, pipelineName, @[
        BindingInfo(binding: 0, bufferName: outputName),
        BindingInfo(binding: 1, bufferName: paramsName)
      ]):
        return false
    
    return true
  
  proc executeShader*(name: string, width, height: int, offsetX: int = 0, offsetY: int = 0): bool =
    ## Execute a compiled shader on the GPU
    ## 
    ## Example:
    ##   executeShader("terrain", 1920, 1080)
    ##   executeShader("terrain", 1920, 1080, offsetX=100)  # for animation
    let ctx = getGlobalContext()
    
    # Ensure buffers are set up
    if not setupShaderBuffers(name, width, height):
      echo fmt"[Nimini] Failed to setup buffers for: {name}"
      return false
    
    # Update params if offset changed
    if offsetX != 0 or offsetY != 0:
      let paramsName = name & "_params"
      if not ctx.writeBufferU32(paramsName, @[width.uint32, height.uint32, offsetX.uint32, offsetY.uint32]):
        echo fmt"[Nimini] Failed to update params for: {name}"
        return false
    
    # Dispatch
    let pipelineName = name & "_pipeline"
    let bindGroupName = name & "_bindings"
    let workgroupsX = calcWorkgroups(width, 8)
    let workgroupsY = calcWorkgroups(height, 8)
    
    if ctx.dispatch(pipelineName, bindGroupName, workgroupsX, workgroupsY):
      echo fmt"[Nimini] Shader executed: {name} ({width}x{height})"
      return true
    else:
      echo fmt"[Nimini] Failed to execute shader: {name}"
      return false
  
  # Note: Reading back buffer data requires async JS call
  # For now, we'll add a sync version that triggers the read
  # The actual data retrieval would need to be handled by JS callback
  
  proc compileAndExecuteShader*(name: string, config: NoiseConfig, width, height: int): bool =
    ## Convenience function: compile and execute in one call
    ## 
    ## Example:
    ##   let terrain = noise(ntPerlin2D).seed(42).scale(100)
    ##   compileAndExecuteShader("terrain", terrain, 1920, 1080)
    if not compileShader(name, config):
      return false
    if not executeShader(name, width, height):
      return false
    return true
  
  # High-level noise generation functions
  
  proc gpuTerrain*(width, height: int, seed: int = 42, scale: int = 100): bool =
    ## Generate terrain noise on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuTerrain(1920, 1080)
    let config = noise(ntPerlin2D)
      .seed(seed)
      .scale(scale)
      .octaves(3)
      .persistence(0.5)
    return compileAndExecuteShader("terrain", config, width, height)
  
  proc gpuClouds*(width, height: int, seed: int = 999, scale: int = 150): bool =
    ## Generate cloud noise on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuClouds(1920, 1080)
    let config = noise(ntSimplex2D)
      .seed(seed)
      .scale(scale)
      .octaves(3)
      .persistence(0.6)
    return compileAndExecuteShader("clouds", config, width, height)
  
  proc gpuMountains*(width, height: int, seed: int = 777, scale: int = 80): bool =
    ## Generate mountain noise (ridged) on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuMountains(1920, 1080)
    let config = noise(ntPerlin2D)
      .seed(seed)
      .scale(scale)
      .octaves(4)
      .ridged()
    return compileAndExecuteShader("mountains", config, width, height)
  
  proc gpuOcean*(width, height: int, seed: int = 555, scale: int = 200): bool =
    ## Generate ocean/water noise on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuOcean(1920, 1080)
    let config = noise(ntSimplex2D)
      .seed(seed)
      .scale(scale)
      .octaves(2)
      .persistence(0.4)
    return compileAndExecuteShader("ocean", config, width, height)
  
  proc gpuFire*(width, height: int, seed: int = 333, scale: int = 50): bool =
    ## Generate fire/turbulence noise on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuFire(1920, 1080)
    let config = noise(ntPerlin2D)
      .seed(seed)
      .scale(scale)
      .octaves(3)
      .turbulent()
    return compileAndExecuteShader("fire", config, width, height)
  
  proc gpuCells*(width, height: int, seed: int = 111, scale: int = 80): bool =
    ## Generate cellular/Worley noise on GPU with reasonable defaults
    ## 
    ## Example:
    ##   gpuCells(1920, 1080)
    let config = noise(ntWorley2D)
      .seed(seed)
      .scale(scale)
    return compileAndExecuteShader("cells", config, width, height)
  
  # Export everything
  export compileShader, setupShaderBuffers, executeShader, compileAndExecuteShader
  export gpuTerrain, gpuClouds, gpuMountains, gpuOcean, gpuFire, gpuCells
  export getGlobalContext, WebGPUContext

else:
  # Stub implementations when not on web
  proc compileShader*(name: string, config: NoiseConfig): bool =
    echo "[Nimini] WebGPU only available with -d:emscripten"
    return false
  
  proc executeShader*(name: string, width, height: int, offsetX: int = 0, offsetY: int = 0): bool =
    echo "[Nimini] WebGPU only available with -d:emscripten"
    return false
  
  export compileShader, executeShader
