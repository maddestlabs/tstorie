## WebGPU Backend for TStorie
## Provides GPU compute shader capabilities via WebGPU
## 
## This backend allows running noise generation and other compute operations
## on the GPU using WGSL shaders compiled from TStorie's noise primitives.

when not defined(emscripten):
  {.error: "webgpu backend requires -d:emscripten".}

import std/[strformat, tables, options]

# JavaScript bridge functions (imported from webgpu_bridge.js)
proc js_webgpu_is_initialized(): bool {.importc: "function(){return window.webgpuBridge && window.webgpuBridge.initialized;}".}
proc js_webgpu_compile_shader(name: cstring, code: cstring): bool {.importc: "function(n,c){return window.webgpuBridge.compileShader(n,c);}".}
proc js_webgpu_create_pipeline(name: cstring, shaderName: cstring, entryPoint: cstring): bool {.importc: "function(n,s,e){return window.webgpuBridge.createPipeline(n,s,e);}".}
proc js_webgpu_create_buffer(name: cstring, size: int, readable: bool): bool {.importc: "function(n,s,r){return window.webgpuBridge.createBuffer(n,s,r);}".}
proc js_webgpu_create_uniform_buffer(name: cstring, size: int): bool {.importc: "function(n,s){return window.webgpuBridge.createUniformBuffer(n,s);}".}
proc js_webgpu_write_buffer_u32(name: cstring, data: ptr UncheckedArray[uint32], length: int, offset: int): bool {.importc: "function(n,d,l,o){const arr=new Uint32Array(Module.HEAPU32.buffer,d,l);return window.webgpuBridge.writeBuffer(n,arr,o);}".}
proc js_webgpu_create_bind_group(name: cstring, pipelineName: cstring, bindingsJson: cstring): bool {.importc: "function(n,p,b){return window.webgpuBridge.createBindGroup(n,p,JSON.parse(b));}".}
proc js_webgpu_dispatch(pipelineName: cstring, bindGroupName: cstring, x, y, z: int): bool {.importc: "function(p,b,x,y,z){return window.webgpuBridge.dispatch(p,b,x,y,z);}".}

type
  WebGPUContext* = ref object
    initialized*: bool
    shaders*: Table[string, bool]      # shader name -> compiled
    pipelines*: Table[string, bool]    # pipeline name -> created
    buffers*: Table[string, int]       # buffer name -> size
    bindGroups*: Table[string, bool]   # bind group name -> created

proc newWebGPUContext*(): WebGPUContext =
  ## Create a new WebGPU context
  result = WebGPUContext(
    initialized: false,
    shaders: initTable[string, bool](),
    pipelines: initTable[string, bool](),
    buffers: initTable[string, int](),
    bindGroups: initTable[string, bool]()
  )

proc checkInitialized*(ctx: WebGPUContext): bool =
  ## Check if WebGPU is initialized and ready
  if not ctx.initialized:
    ctx.initialized = js_webgpu_is_initialized()
  return ctx.initialized

proc compileShader*(ctx: WebGPUContext, name: string, wgslCode: string): bool =
  ## Compile a WGSL shader module
  ## 
  ## Example:
  ##   let wgsl = noise(ntPerlin2D).seed(42).scale(100).toWGSL()
  ##   ctx.compileShader("terrain", wgsl)
  if not ctx.checkInitialized():
    echo "[WebGPU] Not initialized"
    return false
  
  let success = js_webgpu_compile_shader(name.cstring, wgslCode.cstring)
  if success:
    ctx.shaders[name] = true
    echo fmt"[WebGPU] Shader compiled: {name}"
  else:
    echo fmt"[WebGPU] Failed to compile shader: {name}"
  return success

proc createPipeline*(ctx: WebGPUContext, name: string, shaderName: string, entryPoint: string = "main"): bool =
  ## Create a compute pipeline from a compiled shader
  ## 
  ## Example:
  ##   ctx.createPipeline("terrain_pipeline", "terrain")
  if not ctx.checkInitialized():
    return false
  
  if shaderName notin ctx.shaders:
    echo fmt"[WebGPU] Shader not found: {shaderName}"
    return false
  
  let success = js_webgpu_create_pipeline(name.cstring, shaderName.cstring, entryPoint.cstring)
  if success:
    ctx.pipelines[name] = true
    echo fmt"[WebGPU] Pipeline created: {name}"
  else:
    echo fmt"[WebGPU] Failed to create pipeline: {name}"
  return success

proc createStorageBuffer*(ctx: WebGPUContext, name: string, size: int, readable: bool = true): bool =
  ## Create a storage buffer (for compute shader output)
  ## 
  ## Example:
  ##   ctx.createStorageBuffer("output", width * height * 4, readable=true)
  if not ctx.checkInitialized():
    return false
  
  let success = js_webgpu_create_buffer(name.cstring, size, readable)
  if success:
    ctx.buffers[name] = size
    echo fmt"[WebGPU] Storage buffer created: {name} ({size} bytes)"
  return success

proc createUniformBuffer*(ctx: WebGPUContext, name: string, size: int): bool =
  ## Create a uniform buffer (for parameters like width, height, time, etc.)
  ## 
  ## Example:
  ##   ctx.createUniformBuffer("params", 16)  # 4 * u32
  if not ctx.checkInitialized():
    return false
  
  let success = js_webgpu_create_uniform_buffer(name.cstring, size)
  if success:
    ctx.buffers[name] = size
    echo fmt"[WebGPU] Uniform buffer created: {name} ({size} bytes)"
  return success

proc writeBufferU32*(ctx: WebGPUContext, name: string, data: seq[uint32], offset: int = 0): bool =
  ## Write u32 data to a buffer
  ## 
  ## Example:
  ##   ctx.writeBufferU32("params", @[1920'u32, 1080'u32, 0'u32, 0'u32])
  if not ctx.checkInitialized():
    return false
  
  if name notin ctx.buffers:
    echo fmt"[WebGPU] Buffer not found: {name}"
    return false
  
  var mutableData = data
  let success = js_webgpu_write_buffer_u32(
    name.cstring,
    cast[ptr UncheckedArray[uint32]](addr mutableData[0]),
    data.len,
    offset
  )
  return success

type
  BindingInfo* = object
    binding*: int
    bufferName*: string

proc createBindGroup*(ctx: WebGPUContext, name: string, pipelineName: string, bindings: seq[BindingInfo]): bool =
  ## Create a bind group that connects buffers to a pipeline
  ## 
  ## Example:
  ##   ctx.createBindGroup("terrain_bindings", "terrain_pipeline", @[
  ##     BindingInfo(binding: 0, bufferName: "output"),
  ##     BindingInfo(binding: 1, bufferName: "params")
  ##   ])
  if not ctx.checkInitialized():
    return false
  
  if pipelineName notin ctx.pipelines:
    echo fmt"[WebGPU] Pipeline not found: {pipelineName}"
    return false
  
  # Convert bindings to JSON
  var json = "["
  for i, b in bindings:
    if i > 0: json.add(",")
    json.add(fmt"""{{ "binding": {b.binding}, "bufferName": "{b.bufferName}" }}""")
  json.add("]")
  
  let success = js_webgpu_create_bind_group(name.cstring, pipelineName.cstring, json.cstring)
  if success:
    ctx.bindGroups[name] = true
    echo fmt"[WebGPU] Bind group created: {name}"
  return success

proc dispatch*(ctx: WebGPUContext, pipelineName: string, bindGroupName: string, workgroupsX, workgroupsY: int, workgroupsZ: int = 1): bool =
  ## Dispatch a compute shader
  ## 
  ## Workgroups are typically calculated as: ceil(width / workgroupSize)
  ## For 8x8 workgroups: ceil(1920 / 8) = 240, ceil(1080 / 8) = 135
  ## 
  ## Example:
  ##   ctx.dispatch("terrain_pipeline", "terrain_bindings", 240, 135)
  if not ctx.checkInitialized():
    return false
  
  let success = js_webgpu_dispatch(pipelineName.cstring, bindGroupName.cstring, workgroupsX, workgroupsY, workgroupsZ)
  if not success:
    echo fmt"[WebGPU] Failed to dispatch: {pipelineName}"
  return success

# Helper proc to calculate workgroup counts
proc calcWorkgroups*(size: int, workgroupSize: int = 8): int =
  ## Calculate number of workgroups needed for a given size
  ## Default workgroup size is 8 (matching generated shaders)
  result = (size + workgroupSize - 1) div workgroupSize

# Convenience proc to set up a compute shader pipeline from start to finish
proc setupComputeShader*(ctx: WebGPUContext, name: string, wgslCode: string, 
                          width, height: int): bool =
  ## Set up a complete compute shader pipeline for noise generation
  ## Creates shader, pipeline, buffers, and bind group
  ## 
  ## Usage:
  ##   let wgsl = noise(ntPerlin2D).seed(42).scale(100).toWGSL()
  ##   ctx.setupComputeShader("terrain", wgsl, 1920, 1080)
  ##   ctx.dispatch("terrain_pipeline", "terrain_bindings", 240, 135)
  
  let shaderName = name & "_shader"
  let pipelineName = name & "_pipeline"
  let outputName = name & "_output"
  let paramsName = name & "_params"
  let bindGroupName = name & "_bindings"
  
  # Compile shader
  if not ctx.compileShader(shaderName, wgslCode):
    return false
  
  # Create pipeline
  if not ctx.createPipeline(pipelineName, shaderName):
    return false
  
  # Create output buffer (u32 per pixel)
  let bufferSize = width * height * 4  # 4 bytes per u32
  if not ctx.createStorageBuffer(outputName, bufferSize):
    return false
  
  # Create params buffer (width, height, offsetX, offsetY)
  if not ctx.createUniformBuffer(paramsName, 16):  # 4 * u32 = 16 bytes
    return false
  
  # Write initial params
  if not ctx.writeBufferU32(paramsName, @[width.uint32, height.uint32, 0'u32, 0'u32]):
    return false
  
  # Create bind group
  if not ctx.createBindGroup(bindGroupName, pipelineName, @[
    BindingInfo(binding: 0, bufferName: outputName),
    BindingInfo(binding: 1, bufferName: paramsName)
  ]):
    return false
  
  echo fmt"[WebGPU] Complete setup for: {name}"
  return true

proc updateParams*(ctx: WebGPUContext, name: string, width, height, offsetX, offsetY: int): bool =
  ## Update parameters for an existing shader (for animation)
  ## 
  ## Example:
  ##   ctx.updateParams("terrain", 1920, 1080, time, 0)
  let paramsName = name & "_params"
  return ctx.writeBufferU32(paramsName, @[width.uint32, height.uint32, offsetX.uint32, offsetY.uint32])

proc executeShader*(ctx: WebGPUContext, name: string, width, height: int): bool =
  ## Execute a shader that was set up with setupComputeShader
  ## 
  ## Example:
  ##   ctx.executeShader("terrain", 1920, 1080)
  let pipelineName = name & "_pipeline"
  let bindGroupName = name & "_bindings"
  
  let workgroupsX = calcWorkgroups(width, 8)
  let workgroupsY = calcWorkgroups(height, 8)
  
  return ctx.dispatch(pipelineName, bindGroupName, workgroupsX, workgroupsY)

# Export for use in runtime
export WebGPUContext, newWebGPUContext, checkInitialized, compileShader,
       createPipeline, createStorageBuffer, createUniformBuffer,
       writeBufferU32, createBindGroup, dispatch, calcWorkgroups,
       setupComputeShader, updateParams, executeShader, BindingInfo
