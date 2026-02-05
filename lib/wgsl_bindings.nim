## WGSL Shader Bindings for Nimini
##
## Provides nimini API for GPU compute shaders:
## - getShader(name) - Get shader by name
## - updateComputeShader(name, uniforms) - Update uniform values
## - runComputeShader(name, inputData, outputData) - Execute compute shader
##
## Architecture:
## - Web: WebGPU via webgpu_bridge.js
## - Native (future): SDL3 GPU + SDL_shadercross for WGSL→SPIRV→Native

import ../nimini
import ../nimini/runtime
import ../nimini/type_converters
import ../nimini/auto_pointer  # For queuePluginRegistration
import storie_types
import tables, strutils
import shader_safety

# ================================================================
# EXTERNAL JS BRIDGE DECLARATIONS
# ================================================================

when defined(emscripten):
  # Bridge function defined in webgpu_bridge_extern.js
  proc tStorie_injectWGSLShader(namePtr: cstring, vertexPtr: cstring, 
                                fragmentPtr: cstring, uniformsPtr: cstring): cint {.importc.}
  
  # Bridge function for async compute shader execution
  # Implemented in wgsl_runtime.js as window.tStorie_runComputeShaderAsync
  proc tStorie_runComputeShaderAsync(codePtr: cstring,
                                     inputPtr: ptr cfloat, inputLen: cint,
                                     outputPtr: ptr cfloat, outputLen: cint,
                                     workX, workY, workZ: cint,
                                     callbackId: cint): cint {.importc.}
  
  # Bridge function for synchronous compute shader execution (fire-and-forget)
  # Implemented in wgsl_runtime.js as window.tStorie_runComputeShaderSync
  proc tStorie_runComputeShaderSync(codePtr: cstring,
                                    inputPtr: ptr cfloat, inputLen: cint,
                                    outputPtr: ptr cfloat, outputLen: cint,
                                    workX, workY, workZ: cint): cint {.importc.}
  
  # Emscripten helper for running JavaScript
  proc emscripten_run_script(script: cstring) {.importc, header: "<emscripten.h>".}
  proc emscripten_run_script_int(script: cstring): cint {.importc, header: "<emscripten.h>".}

# ================================================================
# GLOBAL SHADER REGISTRY
# ================================================================

# Global shader registry (populated by setMarkdownContent)
var gShaders*: seq[WGSLShader] = @[]

# Compute shader callback management
type ComputeCallback = ref object
  callback: Value
  env: ref Env
  outputData: Value
  outputPtr: ptr cfloat
  outputLen: int
  outputOwned: bool
  outputAsInts: bool

  # Keep buffers alive until JS callback fires.
  # Without this, JS writes into freed/moved seq memory.
  inputArr: seq[cfloat]

var gComputeCallbacks = initTable[int, ComputeCallback]()
var gNextCallbackId = 1

proc invokeComputeCallback(callbackId: cint) {.exportc, cdecl.} =
  ## Called from JavaScript when GPU compute completes
  when defined(emscripten):
    emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback enter')")

  if not gComputeCallbacks.hasKey(callbackId.int):
    when defined(emscripten):
      emscripten_run_script("console.warn('[WGSL-NIM] invokeComputeCallback missing id')")
    return
  
  let callbackData = gComputeCallbacks[callbackId.int]

  # Remove from registry early to avoid any chance of re-entrancy.
  # callbackData is a ref object, so it remains valid after deletion.
  gComputeCallbacks.del(callbackId.int)

  when defined(emscripten):
    emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback copying')")

  # Copy results from the pinned output buffer into the Nimini output array.
  # JS writes into callbackData.outputPtr via the pointer we passed.
  if callbackData != nil and callbackData.outputData != nil and callbackData.outputData.kind == vkArray:
    let outPtr = callbackData.outputPtr
    if outPtr == nil or callbackData.outputLen <= 0:
      when defined(emscripten):
        emscripten_run_script("console.warn('[WGSL-NIM] invokeComputeCallback no output buffer')")
    else:
      when defined(emscripten):
        let outPtrInt = cast[uint](outPtr)
        emscripten_run_script((
          "console.log('[WGSL-NIM] outPtr', " & $outPtrInt &
          ", 'outLen', " & $callbackData.outputLen &
          ", 'outDataLen', " & $callbackData.outputData.arr.len &
          ", 'heapBytes', HEAPU8.length);"
        ).cstring)

      let outBuf = cast[ptr UncheckedArray[cfloat]](outPtr)
      let n = min(callbackData.outputData.arr.len, callbackData.outputLen)

      var rangeOk: cint = 1
      when defined(emscripten):
        # If this fails, the pointer/len combination would read past the end of WASM memory.
        let byteEndExpr = "((" & $cast[uint](outPtr) & " + " & $(n * 4) & ") <= HEAPU8.length) ? 1 : 0"
        rangeOk = emscripten_run_script_int(byteEndExpr.cstring)

      if rangeOk == 0:
        when defined(emscripten):
          emscripten_run_script("console.error('[WGSL-NIM] output buffer range exceeds HEAPU8; skipping copy to avoid trap')")
      else:
        var i = 0
        while i < n:
          when defined(emscripten):
            if i == 1:
              emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback i=1 pre-read')")

          let f = outBuf[i].float

          when defined(emscripten):
            if i == 1:
              emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback i=1 post-read')")

          let existing = callbackData.outputData.arr[i]
          if existing == nil:
            if callbackData.outputAsInts:
              callbackData.outputData.arr[i] = valInt(int(f))
            else:
              callbackData.outputData.arr[i] = valFloat(f)
          else:
            if callbackData.outputAsInts:
              existing.kind = vkInt
              existing.i = int(f)
              existing.f = float(existing.i)
            else:
              existing.kind = vkFloat
              existing.f = f
              existing.i = int(f)

          when defined(emscripten):
            if i == 0:
              emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback copied i=0')")
            if i == 1:
              emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback copied i=1')")
          inc i

  when defined(emscripten):
    emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback calling cb')")

  if callbackData != nil and callbackData.callback.kind == vkFunction:
    discard callFunctionValue(callbackData.callback, @[], callbackData.env)

  when defined(emscripten):
    emscripten_run_script("console.log('[WGSL-NIM] invokeComputeCallback done')")

  # Free the owned output buffer after we're done copying.
  if callbackData != nil and callbackData.outputOwned and callbackData.outputPtr != nil:
    deallocShared(callbackData.outputPtr)

proc registerWGSLShaders*(shaders: seq[WGSLShader]) =
  ## Register WGSL shaders from parsed markdown with comprehensive safety validation
  ## Uses JS bridge pattern (webgpu_bridge_extern.js → wgsl_runtime.js)
  
  echo "[WGSL-NIM] Registering ", shaders.len, " shaders via JS bridge"
  
  gShaders = shaders
  
  when defined(emscripten):
    var successCount = 0
    var failureCount = 0
    
    for shader in shaders:
      # === NIM-SIDE SAFETY VALIDATION ===
      let nameValid = validateShaderName(shader.name)
      let codeValid = validateShaderCode(shader.code)
      let uniformsValid = validateUniforms(shader.uniforms)
      
      if not nameValid.valid:
        echo "[WGSL-NIM] ✗ REJECTED - Invalid name: ", shader.name
        echo formatValidationErrors(nameValid.errors)
        inc failureCount
        continue
      
      if not codeValid.valid:
        echo "[WGSL-NIM] ✗ REJECTED - Invalid code: ", shader.name
        echo formatValidationErrors(codeValid.errors)
        inc failureCount
        continue
      
      if not uniformsValid.valid:
        echo "[WGSL-NIM] ✗ REJECTED - Invalid uniforms: ", shader.name
        echo formatValidationErrors(uniformsValid.errors)
        inc failureCount
        continue
      
      # Process fragment shaders
      if shader.kind == FragmentShader:
        echo "[WGSL-NIM] ✓ Validated: ", shader.name, " (", shader.uniforms.len, " uniforms)"
        
        # Determine vertex/fragment split
        var vertexShader = ""
        var fragmentShader = shader.code
        
        let hasVertexShader = "@vertex" in shader.code and "fn vertexMain" in shader.code
        
        if not hasVertexShader:
          # Fragment-only shader - add default vertex shader
          vertexShader = """
struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};

@vertex
fn vertexMain(@location(0) pos: vec2f) -> VertexOutput {
  var output: VertexOutput;
  output.position = vec4f(pos, 0.0, 1.0);
  output.uv = pos * 0.5 + 0.5;
  return output;
}
"""
        
        # Build uniforms JSON with sensible defaults
        # Use 1.0 for tint/color uniforms (neutral = no change)
        # Use 0.0 for time and other additive values
        var uniformsJson = "{"
        if shader.uniforms.len > 0:
          var first = true
          for uniformName in shader.uniforms:
            if not first: uniformsJson.add(",")
            let safeName = uniformName.replace("\"", "\\\"")
            
            # Smart defaults based on uniform name
            let defaultValue = 
              if "time" in uniformName.toLower: "0.0"
              elif "tint" in uniformName.toLower or "color" in uniformName.toLower: "1.0"
              elif uniformName.toLower in ["resolution", "cellsize"]: "1.0"
              else: "1.0"  # Default to 1.0 (neutral multiplier)
            
            uniformsJson.add("\"" & safeName & "\": " & defaultValue)
            first = false
        uniformsJson.add("}")
        uniformsJson = sanitizeJSON(uniformsJson)
        
        echo "[WGSL-NIM] Injecting via bridge: ", shader.name
        
        # Call JS bridge
        let result = tStorie_injectWGSLShader(
          shader.name.cstring,
          vertexShader.cstring,
          fragmentShader.cstring,
          uniformsJson.cstring
        )
        
        if result == 1:
          echo "[WGSL-NIM] ✓ Successfully injected: ", shader.name
          inc successCount
        else:
          echo "[WGSL-NIM] ✗ FAILED to inject: ", shader.name
          inc failureCount
      
      elif shader.kind == ComputeShader:
        # === COMPUTE SHADER SAFETY VALIDATION ===
        let computeValid = validateComputeShader(shader)
        if not computeValid.valid:
          echo "[WGSL-NIM] ✗ REJECTED - Invalid compute shader: ", shader.name
          echo formatValidationErrors(computeValid.errors)
          inc failureCount
          continue
        
        echo "[WGSL-NIM] ✓ Registered compute shader: ", shader.name, " workgroup=", shader.workgroupSize
        # Compute shaders stored in gShaders, called via runComputeShader()
        inc successCount
      
      else:
        echo "[WGSL-NIM] ○ SKIPPED - Unsupported shader type: ", shader.name
        continue
    
    echo "[WGSL-NIM] Registration complete: ", successCount, " success, ", failureCount, " failed"
  else:
    echo "[WGSL-NIM] Not compiled for emscripten - shaders stored only"

# ================================================================
# NIMINI BINDINGS
# ================================================================

proc nimini_getShader*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get shader by name
  ## Usage: getShader("particlePhysics")
  ## Returns: table with {name, code, kind, uniforms, bindings} or nil
  if args.len < 1:
    return valNil()
  
  let name = valueToString(args[0])
  
  for shader in gShaders:
    if shader.name == name:
      var table = initTable[string, Value]()
      table["name"] = valString(shader.name)
      table["code"] = valString(shader.code)
      table["kind"] = valString($shader.kind)
      
      # Convert uniforms to array
      var uniformsArr: seq[Value] = @[]
      for u in shader.uniforms:
        uniformsArr.add(valString(u))
      table["uniforms"] = valArray(uniformsArr)
      
      # Convert bindings to array
      var bindingsArr: seq[Value] = @[]
      for b in shader.bindings:
        bindingsArr.add(valInt(b))
      table["bindings"] = valArray(bindingsArr)
      
      if shader.kind == ComputeShader:
        table["workgroupSize"] = valArray(@[
          valInt(shader.workgroupSize.x),
          valInt(shader.workgroupSize.y),
          valInt(shader.workgroupSize.z)
        ])
      
      return valMap(table)
  
  return valNil()

proc nimini_listShaders*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## List all available shader names
  ## Usage: listShaders()
  ## Returns: array of shader names
  var names: seq[Value] = @[]
  for shader in gShaders:
    names.add(valString(shader.name))
  return valArray(names)

proc nimini_updateComputeShader*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update compute shader uniforms
  ## Usage: updateComputeShader("particlePhysics", {time: 1.5, velocity: 2.0})
  ## 
  ## This prepares uniform data for the next shader execution.
  ## Implementation:
  ## - Web: Stores uniforms for next executeComputeShader call (TODO: implement bridge)
  ## - Native: Will use SDL3 GPU uniform buffers
  if args.len < 2:
    return valBool(false)
  
  let name = valueToString(args[0])
  let uniforms = args[1]
  
  if uniforms.kind != vkMap:
    return valBool(false)
  
  # Find shader
  var found = false
  for shader in gShaders:
    if shader.name == name:
      found = true
      break
  
  if not found:
    return valBool(false)
  
  when defined(emscripten):
    # Serialize nimini map to JSON
    var uniformsJson = "{"
    var first = true
    for key, val in uniforms.map:
      if not first: uniformsJson.add(",")
      uniformsJson.add("\"" & key & "\":")
      case val.kind:
      of vkInt: uniformsJson.add($val.i)
      of vkFloat: uniformsJson.add($val.f)
      of vkString: uniformsJson.add("\"" & val.s & "\"")
      of vkBool: uniformsJson.add(if val.b: "true" else: "false")
      else: uniformsJson.add("null")
      first = false
    uniformsJson.add("}")
    
    # Call JavaScript bridge using emscripten_run_script
    let script = "if(window.updateShaderUniforms){window.updateShaderUniforms('" & 
                 name & "'," & uniformsJson & ");}"
    emscripten_run_script(script.cstring)
  else:
    # Native: Future SDL3 GPU implementation
    discard
  
  return valBool(true)

proc nimini_runComputeShader*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Execute a compute shader (fire-and-forget, non-blocking)
  ## Usage: runComputeShader("particlePhysics", inputData, outputData)
  ##
  ## inputData: array of numbers (will be copied to GPU buffer)
  ## outputData: array (will be filled with GPU results asynchronously)
  ##
  ## Note: This version is non-blocking. Results appear in outputData
  ## after GPU completes. Use runComputeShaderAsync for callback notification.
  ##
  ## Returns: true if shader started successfully, false on failure
  if args.len < 3:
    return valBool(false)
  
  let name = valueToString(args[0])
  let inputData = args[1]
  let outputData = args[2]
  
  if inputData.kind != vkArray:
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
    return valBool(false)
  
  when defined(emscripten):
    # Convert nimini arrays to raw float arrays
    var inputArr: seq[cfloat] = @[]
    for v in inputData.arr:
      if v.kind == vkFloat: 
        inputArr.add(v.f.cfloat)
      elif v.kind == vkInt: 
        inputArr.add(v.i.cfloat)
      else:
        inputArr.add(0.cfloat)
    
    var outputArr = newSeq[cfloat](outputData.arr.len)
    
    # Call JavaScript bridge (now uses cached pipeline)
    let success = tStorie_runComputeShaderSync(
      shader.code.cstring,
      if inputArr.len > 0: addr inputArr[0] else: nil, inputArr.len.cint,
      if outputArr.len > 0: addr outputArr[0] else: nil, outputArr.len.cint,
      shader.workgroupSize.x.cint,
      shader.workgroupSize.y.cint,
      shader.workgroupSize.z.cint
    )

    # Copy results back into the Nimini output array immediately.
    # Sync bridge fills outputArr before returning.
    if outputData.kind == vkArray:
      let n = min(outputData.arr.len, outputArr.len)
      let outputAsInts = (outputData.arr.len > 0 and outputData.arr[0].kind == vkInt)
      var i = 0
      while i < n:
        let f = outputArr[i].float
        if outputAsInts:
          outputData.arr[i] = valInt(int(f))
        else:
          outputData.arr[i] = valFloat(f)
        inc i

    return valBool(success == 1)
  else:
    # Native: Future SDL3 GPU + SDL_shadercross implementation
    return valBool(false)
  
  return valBool(false)

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
  
  if inputData.kind != vkArray:
    echo "[Compute Shader] Input must be an array"
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
    # Capture a stable environment for async callback execution.
    # The current `env` may be a short-lived call/update env.
    var rootEnv = env
    while rootEnv != nil and rootEnv.parent != nil:
      rootEnv = rootEnv.parent

    # Convert arrays
    var inputArr: seq[cfloat] = @[]
    for v in inputData.arr:
      if v.kind == vkFloat: inputArr.add(v.f.cfloat)
      elif v.kind == vkInt: inputArr.add(v.i.cfloat)
      else: inputArr.add(0.cfloat)
    
    let outputLen = outputData.arr.len
    let outputPtr = (if outputLen > 0:
      cast[ptr cfloat](allocShared0(outputLen * 4))
    else:
      nil)

    # Determine preferred output type based on existing array contents
    let outputAsInts = (outputData.arr.len > 0 and outputData.arr[0].kind == vkInt)

    # Store callback + buffers with environment (keeps seqs alive)
    let callbackId = gNextCallbackId
    inc gNextCallbackId
    var cb: ComputeCallback
    new(cb)
    cb.callback = callback
    cb.env = rootEnv
    cb.outputData = outputData
    cb.outputPtr = outputPtr
    cb.outputLen = outputLen
    cb.outputOwned = true
    cb.outputAsInts = outputAsInts
    cb.inputArr = inputArr
    gComputeCallbacks[callbackId] = cb
    
    # Call JavaScript bridge function
    let success = tStorie_runComputeShaderAsync(
      shader.code.cstring,
      if inputArr.len > 0: addr inputArr[0] else: nil, inputArr.len.cint,
      outputPtr, outputLen.cint,
      shader.workgroupSize.x.cint,
      shader.workgroupSize.y.cint,
      shader.workgroupSize.z.cint,
      callbackId.cint
    )
    
    return valBool(success == 1)  # Started successfully
  else:
    return valBool(false)

# Register bindings
proc registerWGSLBindings*() =
  ## Register all WGSL-related nimini functions
  ## Must be called explicitly to ensure module initialization
  queuePluginRegistration(proc() =
    registerNative("getShader", nimini_getShader)
  )
  queuePluginRegistration(proc() =
    registerNative("listShaders", nimini_listShaders)
  )
  queuePluginRegistration(proc() =
    registerNative("updateComputeShader", nimini_updateComputeShader)
  )
  queuePluginRegistration(proc() =
    registerNative("runComputeShader", nimini_runComputeShader)
  )
  queuePluginRegistration(proc() =
    registerNative("runComputeShaderAsync", nimini_runComputeShaderAsync)
  )
