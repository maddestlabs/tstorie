# TStorie WGSL Shader Implementation Guide

## Current Status (✅ = Complete, ⚠️ = Partial, ❌ = Not Implemented)

### Fragment Shaders (Post-Processing Effects)
- ✅ Parser extracts uniforms, filters built-ins and padding
- ✅ Safety validation (circuit breaker, name/code validation)
- ✅ JS bridge pattern (no EM_JS issues)
- ✅ WebGPU pipeline creation and rendering
- ✅ Uniform buffer with vec4 alignment and padding
- ✅ `setShaderUniform()` API for runtime control
- ✅ Magic block support (compress/decompress shaders)
- ✅ UV coordinate handling (WebGPU texture origin)
- ✅ Shader registration at startup

### Compute Shaders (GPU Computation)
- ✅ Parser detects `@compute` and extracts `@workgroup_size(x,y,z)`
- ✅ JavaScript runtime has complete implementation (docs/wgsl_runtime.js)
- ⚠️ Nim bindings exist but compute shaders are SKIPPED at registration
- ❌ Pipeline caching (creates new pipeline every call - expensive!)
- ❌ Async callback support
- ❌ Synchronous blocking API
- ❌ Compute-specific safety validation

## Block Syntax (Use Existing!)

**Fragment shaders:**
```markdown
\`\`\`wgsl fragment:tint
struct Uniforms {
  time: f32,
  _pad0: f32, _pad1: f32, _pad2: f32,  // vec4 alignment padding
  resolution: vec2f,
  _pad3: f32, _pad4: f32,               // vec2 needs padding to vec4
  tintR: f32,
  tintG: f32,
  tintB: f32,
};
@group(0) @binding(2) var<uniform> uniforms: Uniforms;
@group(0) @binding(0) var inputTexture: texture_2d<f32>;
@group(0) @binding(1) var inputSampler: sampler;

@fragment
fn fragmentMain(input: VertexOutput) -> @location(0) vec4f {
  var color = textureSample(inputTexture, inputSampler, input.uv);
  return vec4f(color.rgb * vec3f(uniforms.tintR, uniforms.tintG, uniforms.tintB), color.a);
}
\`\`\`
```

**Compute shaders (to implement):**
```markdown
\`\`\`wgsl compute:particlePhysics
@group(0) @binding(0) var<storage, read> input: array<f32>;
@group(0) @binding(1) var<storage, read_write> output: array<f32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3u) {
  let i = id.x;
  if i >= arrayLength(&input) { return; }
  
  // Simple physics: velocity integration
  output[i] = input[i] + 0.1;  // position += velocity * dt
}
\`\`\`
```

Note: Parser already handles both - just checks for `@compute`, `@fragment`, or `@vertex` decorators.

## Implementation Checklist

### Phase 1: Enable Compute Shader Registration (30 min)

**Step 1.1: Remove obsolete EM_JS code**

**File: lib/wgsl_bindings.nim (Lines 30-125)**

Remove all EM_JS macros and wrapper procs. These are remnants from an earlier approach that fragment shaders successfully avoid.

Delete:
- `{.emit: """/*INCLUDESECTION*/` block (lines 35-103)
- All `EM_JS(...)` declarations
- All wrapper procs using `.emit:` (lines 106-125)

**Step 1.2: Enable compute shader processing**

**File: lib/wgsl_bindings.nim (Line 172)**

Current code SKIPS compute shaders:
```nim
# Only process fragment shaders for now
if shader.kind != FragmentShader:
  echo "[WGSL-NIM] ○ SKIPPED - Not a fragment shader: ", shader.name
  continue
```

**Change to:**
```nim
# Process fragment shaders
if shader.kind == FragmentShader:
  # ... existing fragment shader code ...
  
elif shader.kind == ComputeShader:
  echo "[WGSL-NIM] ✓ Registered compute shader: ", shader.name, " workgroup=", shader.workgroupSize
  # Compute shaders stored in gShaders, called via runComputeShader()
  inc successCount
  
else:
  echo "[WGSL-NIM] ○ SKIPPED - Unsupported shader type: ", shader.name
  continue
```

### Phase 2: Add Pipeline Caching (1 hour)

**File: docs/wgsl_runtime.js (at top with other storage)**

Add caching infrastructure:
```javascript
// Compute shader pipeline cache
const computePipelineCache = new Map();  // code hash -> pipeline
const computeBufferCache = new Map();     // size -> buffer pool

function hashString(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0; // Convert to 32-bit integer
  }
  return hash.toString(36);
}
```

**Modify window.runComputeShader (Line 185):**
```javascript
window.runComputeShader = async function(code, inputData, outputData, workgroupSize = [64, 1, 1]) {
  if (!window.webgpuDevice?.device) {
    console.warn('[WGSL Runtime] WebGPU not initialized');
    return false;
  }
  
  const device = window.webgpuDevice.device;
  const codeHash = hashString(code);
  
  try {
    // Get or create cached pipeline
    let pipeline = computePipelineCache.get(codeHash);
    if (!pipeline) {
      console.log('[WGSL Runtime] Compiling new compute pipeline:', codeHash);
      const shaderModule = device.createShaderModule({ code, label: 'Compute' });
      
      // Use async pipeline creation (faster, non-blocking)
      pipeline = await device.createComputePipelineAsync({
        layout: 'auto',
        compute: { module: shaderModule, entryPoint: 'main' }
      });
      
      computePipelineCache.set(codeHash, pipeline);
      console.log('[WGSL Runtime] ✓ Pipeline cached');
    }
    
    // ... rest of existing execution code ...
```

### Phase 3: Async Callback API (1.5 hours)

**File: lib/wgsl_bindings.nim (add new function)**

Add callback storage:
```nim
# Compute shader callback management
var gComputeCallbacks = initTable[int, Value]()
var gNextCallbackId = 0
```

Add C export for JavaScript to call:
```nim
proc invokeComputeCallback(callbackId: cint) {.exportc, cdecl.} =
  ## Called from JavaScript when GPU compute completes
  if storieCtx.isNil: return
  
  let callback = gComputeCallbacks.getOrDefault(callbackId.int)
  if callback.kind == vkFunction and callback.fnVal.isNative:
    let env = storieCtx.niminiContext.env
    discard callback.fnVal.native(env, @[])
  
  # Cleanup
  gComputeCallbacks.del(callbackId.int)
```

Add new nimini function:
```nim
proc nimini_runComputeShaderAsync*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Execute compute shader asynchronously with callback
  ## Usage: runComputeShaderAsync("name", input, output, callback=onComplete)
  ## 
  ## Callback signature: fn onComplete() { ... }
  ## Input/output arrays are modified in-place, accessible in callback
  if args.len < 4:
    return valBool(false)
  
  let name = valueToString(args[0])
  let inputData = args[1]
  let outputData = args[2]
  let callback = args[3]
  
  if callback.kind != vkFunction:
    echo "[Compute Shader] Callback must be a function"
    return valBool(false)
  
  # Find shader
  var shader: WGSLShader
  var found = false
  for s in gShaders:
    if s.name == name:
      shader = s
      found = true
      break
  
  if not found:
    echo "[Compute Shader] Shader not found: ", name
    return valBool(false)
  
  when defined(emscripten):
    # Store callback
    let callbackId = gNextCallbackId
    inc gNextCallbackId
    gComputeCallbacks[callbackId] = callback
    
    # Convert arrays
    var inputArr: seq[cfloat] = @[]
    for v in inputData.arr:
      if v.kind == vkFloat: inputArr.add(v.f.cfloat)
      elif v.kind == vkInt: inputArr.add(v.i.cfloat)
      else: inputArr.add(0.cfloat)
    
    var outputArr = newSeq[cfloat](outputData.arr.len)
    
    # Call JavaScript bridge function
    discard tStorie_runComputeShaderAsync(
      shader.code.cstring,
      if inputArr.len > 0: addr inputArr[0] else: nil, inputArr.len.cint,
      if outputArr.len > 0: addr outputArr[0] else: nil, outputArr.len.cint,
      shader.workgroupSize.x.cint,
      shader.workgroupSize.y.cint,
      shader.workgroupSize.z.cint,
      callbackId.cint
    )
    
    return valBool(true)  # Started successfully
  else:
    return valBool(false)
```

**Add JS bridge declaration (same pattern as fragment shaders):**
```nim
when defined(emscripten):
  # Bridge function for async compute shader execution
  # Implemented in wgsl_runtime.js as window.tStorie_runComputeShaderAsync
  proc tStorie_runComputeShaderAsync(codePtr: cstring,
                                     inputPtr: ptr cfloat, inputLen: cint,
                                     outputPtr: ptr cfloat, outputLen: cint,
                                     workX, workY, workZ: cint,
                                     callbackId: cint): cint {.importc.}
```

**File: docs/wgsl_runtime.js (add new function)**

Note: Uses same bridge pattern as fragment shaders (window.tStorie_* functions).
if (!window.webgpuDevice?.device) {
    console.warn('[WGSL Runtime] WebGPU not initialized');
    return 0;
  }
  
```javascript
window.tStorie_runComputeShaderAsync = async function(codePtr, inputPtr, inputLen, outputPtr, outputLen, workX, workY, workZ, callbackId) {
  // Convert WASM pointers to JavaScript arrays
  const code = UTF8ToString(codePtr);
  const inputData = Array.from(new Float32Array(Module.HEAPF32.buffer, inputPtr, inputLen));
  const outputData = new Float32Array(Module.HEAPF32.buffer, outputPtr, outputLen);
  const workgroupSize = [workX, workY, workZ];
  // Use cached pipeline
  const device = window.webgpuDevice.device;
  const codeHash = hashString(code);
  
  let pipeline = computePipelineCache.get(codeHash);
  if (!pipeline) {
    const shaderModule = device.createShaderModule({ code, label: 'Compute' });
    pipeline = await device.createComputePipelineAsync({
      layout: 'auto',
      compute: { module: shaderModule, entryPoint: 'main' }
    });
    computePipelineCache.set(codeHash, pipeline);
  }
  
  // Execute GPU work (same as sync version)
  const inputBuffer = device.createBuffer({
    size: inputData.length * 4,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    mappedAtCreation: true
  });
  new Float32Array(inputBuffer.getMappedRange()).set(inputData);
  inputBuffer.unmap();
  
  const outputBuffer = device.createBuffer({
    size: outputData.length * 4,
    usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC
  });
  
  const stagingBuffer = device.createBuffer({
    size: outputData.length * 4,
    usage: GPUBufferUsage.MAP_READ | GPUBufferUsage.COPY_DST
  });
  
  const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: { buffer: inputBuffer } },
      { binding: 1, resource: { buffer: outputBuffer } }
    ]
  });
  
  const commandEncoder = device.createCommandEncoder();
  const passEncoder = commandEncoder.beginComputePass();
  passEncoder.setPipeline(pipeline);
  passEncoder.setBindGroup(0, bindGroup);
  
  const workgroupCount = Math.ceil(outputData.length / workgroupSize[0]);
  passEncoder.dispatchWorkgroups(workgroupCount, workgroupSize[1], workgroupSize[2]);
  passEncoder.end();
  
  commandEncoder.copyBufferToBuffer(outputBuffer, 0, stagingBuffer, 0, outputData.length * 4);
  device.queue.submit([commandEncoder.finish()]);
  
  // Wait for GPU completion (non-blocking for browser)
  await device.queue.onSubmittedWorkDone();
  
  // Read back results
  await stagingBuffer.mapAsync(GPUMapMode.READ);
  const results = new Float32Array(stagingBuffer.getMappedRange());
  
  // Copy results back to WASM memory
  const outputPtr = Module._malloc(outputData.length * 4);
  Module.HEAPF32.set(results, outputPtr >> 2);
  
  stagingBuffer.unmap();
  
  // Cleanup
  inpCopy results back to WASM memory (outputData is already a view of HEAPF32)
  // No need to copy - direct memory sharing!
  
  // Invoke callback
  Module._invokeComputeCallback(callbackId);
  
  return 1;  // Success
  Module._invokeComputeCallback(callbackId);
  
  // Cleanup temp memory
  Module._free(outputPtr);
};
```

**Register new function (in registerWGSLBindings):**
```nim
queuePluginRegistration(proc() =
  registerNative("runComputeShaderAsync", nimini_runComputeShaderAsync)
)
```

### Phase 4: Synchronous Blocking API (30 min)

Keep existing `runComputeShader()` but make it actually work by calling the async version and spinning:

```javascript
window.runComputeShaderSync = async function(code, inputData, outputData, workgroupSize) {
  // Same as async but waits
  await window.runComputeShaderAsync(code, inputData, outputData, workgroupSize, -1);
  return true;
};
```

Update Nim side to properly await results (spin until ready).

### Phase 5: Safety Validation (30 min)

**File: lib/shader_safety.nim (add new function)**
```nim
proc validateComputeShader*(shader: WGSLShader): ValidationResult =
  result = ValidationResult(valid: true, errors: @[])
  
  # Check workgroup size limits
  let totalThreads = shader.workgroupSize.x * shader.workgroupSize.y * shader.workgroupSize.z
  if totalThreads > 256:
    result.valid = false
    result.errors.add("Workgroup size too large: " & $totalThreads & " threads (max 256)")
  
  # Check for infinite loops
  if "while(true)" in shader.code or "for(;;)" in shader.code:
    result.valid = false
    result.errors.add("Potential infinite loop detected")
  
  # Validate bindings
  if shader.bindings.len < 2:
    result.valid = false
    result.errors.add("Compute shader requires at least 2 bindings (input/output buffers)")
  
  # Check entry point
  if "fn main" notin shader.code:
    result.valid = false
    result.errors.add("Compute shader missing 'fn main' entry point")
```

Call in registration:
```nim
let computeValid = validateComputeShader(shader)
if not computeValid.valid:
  echo "[WGSL-NIM] ✗ REJECTED - Invalid compute shader: ", shader.name
  echo formatValidationErrors(computeValid.errors)
  inc failureCount
  continue
```

## Example Usage (After Implementation)

**docs/demos/compute-test.md:**
```markdown
---
title: Compute Shader Test
---

# GPU Particle Physics

\`\`\`wgsl compute:particlePhysics
@group(0) @binding(0) var<storage, read> positions: array<f32>;
@group(0) @binding(1) var<storage, read_write> velocities: array<f32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3u) {
  let i = id.x;
  if i >= arrayLength(&positions) { return; }
  
  // Simple gravity
  velocities[i] = velocities[i] + 0.001;
}
\`\`\`

\`\`\`nim on:init
var positions = [0.0, 10.0, 20.0, 30.0]
var velocities = [0.0, 0.0, 0.0, 0.0]

fn onPhysicsComplete()
  print("Physics updated!")
  # velocities array now has updated values
end
\`\`\`

\`\`\`nim on:update
# Async (non-blocking, elegant)
runComputeShaderAsync("particlePhysics", positions, velocities, callback=onPhysicsComplete)

# Or synchronous (blocks)
# runComputeShader("particlePhysics", positions, velocities)
\`\`\`
```

## Performance Expectations

| Operation | First Call | Cached Calls |
|-----------|-----------|--------------|
| Fragment shader init | 100-350ms | N/A |
| Fragment shader render | 0.1-2ms | 0.1-2ms |
| Compute shader init | 100-300ms | N/A |
| Compute shader execute | 0.3-54ms | 0.3-54ms |

With pipeline caching, **100x+ speedup** after first execution!

## Testing Strategy

1. **Simple test**: Array doubling compute shader
2. **Callback test**: Verify callback fires with correct data
3. **Performance test**: 1000 consecutive calls (ensure caching works)
4. **Safety test**: Invalid workgroup size, infinite loop detection
5. **Integration test**: Particle system with compute physics

## Files to Modify

1. `lib/wgsl_bindings.nim` - Remove EM_JS code, enable registration, add async API
2. `docs/wgsl_runtime.js` - Add caching and async function
3. `lib/shader_safety.nim` - Add compute validation
4. `src/runtime_api.nim` - Export callback invoker (if needed)

## Code to Remove

**lib/wgsl_bindings.nim (lines 30-125)**: All EM_JS-related code
- These use an older bridge approach incompatible with complex JavaScript
- Fragment shaders successfully use simple `{.importc.}` declarations instead
- Keeping both patterns creates confusion and maintenance burden

## GJS Bridge Pattern**: Uses same `{.importc.}` pattern as fragment shaders (no EM_JS!)
- **Direct Memory Sharing**: WASM heap shared with JavaScript typed arrays (zero-copy)
- **otchas & Notes

- **Vec4 alignment**: Fragment shaders need padding, compute shaders use arrays (no padding)
- **Output mutation**: Both sync and async modify output array in-place
- **Callback timing**: Fires AFTER GPU completes, not immediately
- **Pipeline caching**: CRITICAL for performance, without it every call is 100ms+
- **Browser async**: JavaScript `await` doesn't block browser, but Nim sync version will spin-wait

## Success Criteria

✅ Compute shaders register at startup  
✅ Pipeline caching works (log shows "using cached pipeline")  
✅ Async callback fires with correct results  
✅ Sync version blocks and returns correct results  
✅ Safety validation rejects bad shaders  
✅ No browser crashes or hangs  
✅ Performance: <1ms for cached small workloads  
