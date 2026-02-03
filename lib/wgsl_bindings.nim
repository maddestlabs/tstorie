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

# ================================================================
# JAVASCRIPT BRIDGE (EM_JS)
# ================================================================

when defined(emscripten):
  # EM_JS implementations - bridge to wgsl_runtime.js
  {.emit: """/*INCLUDESECTION*/
#include <emscripten.h>

EM_JS(void, js_updateShaderUniforms, 
     (const char* namePtr, int nameLen, const char* uniformsJson), {
  const name = UTF8ToString(namePtr, nameLen);
  const uniforms = JSON.parse(UTF8ToString(uniformsJson));
  if (typeof window.updateShaderUniforms !== 'undefined') {
    window.updateShaderUniforms(name, uniforms);
  } else {
    console.warn('updateShaderUniforms not available - is wgsl_runtime.js loaded?');
  }
});

EM_JS(int, js_runComputeShader, 
     (const char* code, 
      const float* inputPtr, int inputLen,
      float* outputPtr, int outputLen,
      int workX, int workY, int workZ), {
  const codeStr = UTF8ToString(code);
  const input = new Float32Array(HEAPF32.buffer, inputPtr >> 2, inputLen);
  const output = new Float32Array(HEAPF32.buffer, outputPtr >> 2, outputLen);
  
  console.log('[EM_JS Bridge] runComputeShader called');
  console.log('  Code length:', codeStr.length);
  console.log('  Input length:', inputLen);
  console.log('  Output length:', outputLen);
  console.log('  Workgroup:', workX, workY, workZ);
  console.log('  window.runComputeShader exists?', typeof window.runComputeShader !== 'undefined');
  
  if (typeof window.runComputeShader !== 'undefined') {
    // Call async WebGPU function
    window.runComputeShader(
      codeStr, 
      Array.from(input), 
      Array.from(output), 
      [workX, workY, workZ]
    ).then(result => {
      console.log('[EM_JS Bridge] GPU compute completed, result length:', result.length);
      // Copy results back to WASM memory
      for (let i = 0; i < result.length && i < outputLen; i++) {
        output[i] = result[i];
      }
    }).catch(err => {
      console.error('[EM_JS Bridge] GPU compute shader failed:', err);
    });
    return 1; // Success (async)
  } else {
    console.warn('[EM_JS Bridge] runComputeShader not available - is wgsl_runtime.js loaded?');
    return 0; // WebGPU not available
  }
});

EM_JS(void, js_logRegisterShaders, (int count), {
  console.log("[WGSL-NIM] registerWGSLShaders called with", count, "shaders");
});

EM_JS(void, js_logAfterRegister, (int count), {
  console.log("[WGSL-NIM] gShaders after assignment:", count);
});

EM_JS(void, js_logListShaders, (int count), {
  console.log("[WGSL-NIM] listShaders called, gShaders.len =", count);
});

EM_JS(void, js_logReturnShaders, (int count), {
  console.log("[WGSL-NIM] Returning", count, "shader names");
});
  """.}
  
  # Nim wrapper procs that call the EM_JS functions
  proc js_updateShaderUniforms(namePtr: cstring, nameLen: cint, uniformsJson: cstring) =
    {.emit: "`js_updateShaderUniforms`(`namePtr`, `nameLen`, `uniformsJson`);".}
  
  proc js_runComputeShader(code: cstring, 
                           inputPtr: ptr cfloat, inputLen: cint,
                           outputPtr: ptr cfloat, outputLen: cint,
                           workX, workY, workZ: cint): cint =
    {.emit: "return `js_runComputeShader`(`code`, `inputPtr`, `inputLen`, `outputPtr`, `outputLen`, `workX`, `workY`, `workZ`);".}
  
  proc js_logRegisterShaders(count: cint) =
    {.emit: "`js_logRegisterShaders`(`count`);".}
  
  proc js_logAfterRegister(count: cint) =
    {.emit: "`js_logAfterRegister`(`count`);".}
  
  proc js_logListShaders(count: cint) =
    {.emit: "`js_logListShaders`(`count`);".}
  
  proc js_logReturnShaders(count: cint) =
    {.emit: "`js_logReturnShaders`(`count`);".}

# ================================================================
# GLOBAL SHADER REGISTRY
# ================================================================
  proc emscripten_run_script*(script: cstring) {.importc, header: "<emscripten.h>".}

# Global shader registry (populated by setMarkdownContent)
var gShaders*: seq[WGSLShader] = @[]

proc registerWGSLShaders*(shaders: seq[WGSLShader]) =
  ## Register WGSL shaders from parsed markdown
  when defined(emscripten):
    js_logRegisterShaders(cint(shaders.len))
  gShaders = shaders
  when defined(emscripten):
    js_logAfterRegister(cint(gShaders.len))

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
  when defined(emscripten):
    js_logListShaders(cint(gShaders.len))
  var names: seq[Value] = @[]
  for shader in gShaders:
    names.add(valString(shader.name))
  when defined(emscripten):
    js_logReturnShaders(cint(names.len))
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
    
    # Call JavaScript bridge
    js_updateShaderUniforms(name.cstring, name.len.cint, uniformsJson.cstring)
  else:
    # Native: Future SDL3 GPU implementation
    discard
  
  return valBool(true)

proc nimini_runComputeShader*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Execute a compute shader
  ## Usage: runComputeShader("particlePhysics", inputData, outputData)
  ##
  ## inputData: array of numbers (will be copied to GPU buffer)
  ## outputData: array (will be filled with GPU results)
  ##
  ## Returns: true on success, false on failure
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
    
    # Call JavaScript bridge
    let success = js_runComputeShader(
      shader.code.cstring,
      if inputArr.len > 0: addr inputArr[0] else: nil, inputArr.len.cint,
      if outputArr.len > 0: addr outputArr[0] else: nil, outputArr.len.cint,
      shader.workgroupSize.x.cint,
      shader.workgroupSize.y.cint,
      shader.workgroupSize.z.cint
    )
    
    # Note: Results are written asynchronously to outputArr by JavaScript
    # The output array in nimini will be updated in-place via HEAPF32
    return valBool(success == 1)
  else:
    # Native: Future SDL3 GPU + SDL_shadercross implementation
    return valBool(false)
  
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
