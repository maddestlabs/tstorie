# EM_JS JavaScript Bridge for WGSL Bindings

## Overview

WGSL shader bindings need to call JavaScript WebGPU APIs from Nim/WASM. This document outlines the recommended EM_JS approach for bridging between Nim code and JavaScript GPU functions.

## Architecture

```
Nim Script (nimini)
    ↓
nimini_runComputeShader() [wgsl_bindings.nim]
    ↓
js_runComputeShader() [EM_JS C function]
    ↓
JavaScript WASM Heap Access
    ↓
window.runComputeShader() [wgsl_runtime.js]
    ↓
WebGPU API
```

## Current Status

**✅ Functions Registered**: `getShader`, `listShaders`, `updateShader`, `runComputeShader`  
**⚠️ Bridge Not Implemented**: Functions are stubs, return success but don't execute GPU code  
**📋 Next Step**: Implement EM_JS wrappers

## Implementation Plan

### 1. Add EM_JS Wrapper Functions

```nim
# In lib/wgsl_bindings.nim (after imports, in emscripten block)

when defined(emscripten):
  # JavaScript wrapper declarations
  proc js_updateShaderUniforms(namePtr: cstring, nameLen: int, 
                                uniformsJson: cstring) {.importc.}
  
  proc js_runComputeShader(code: cstring, 
                           inputPtr: ptr float32, inputLen: int,
                           outputPtr: ptr float32, outputLen: int,
                           workX, workY, workZ: int): cint {.importc.}
  
  # EM_JS implementations
  {.emit: """/*INCLUDESECTION*/
  #include <emscripten.h>
  
  EM_JS(void, js_updateShaderUniforms, 
       (const char* namePtr, int nameLen, const char* uniformsJson), {
    const name = UTF8ToString(namePtr, nameLen);
    const uniforms = JSON.parse(UTF8ToString(uniformsJson));
    if (typeof window.updateShaderUniforms !== 'undefined') {
      window.updateShaderUniforms(name, uniforms);
    }
  });
  
  EM_JS(int, js_runComputeShader, 
       (const char* code, 
        const float* inputPtr, int inputLen,
        float* outputPtr, int outputLen,
        int workX, int workY, int workZ), {
    const codeStr = UTF8ToString(code);
    const input = new Float32Array(HEAPF32.buffer, inputPtr, inputLen);
    const output = new Float32Array(HEAPF32.buffer, outputPtr, outputLen);
    
    if (typeof window.runComputeShader !== 'undefined') {
      // Async GPU execution (non-blocking)
      window.runComputeShader(
        codeStr, 
        Array.from(input), 
        Array.from(output), 
        [workX, workY, workZ]
      ).catch(err => console.error('Compute shader failed:', err));
      return 1; // Success
    }
    return 0; // WebGPU not available
  });
  """.}
```

### 2. Update nimini Functions

**updateShader**:
```nim
when defined(emscripten):
  # Serialize nimini map to JSON
  var uniformsJson = "{"
  var first = true
  for key, val in uniforms.m:
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
  
  js_updateShaderUniforms(name.cstring, name.len, uniformsJson.cstring)
```

**runComputeShader**:
```nim
when defined(emscripten):
  # Convert nimini arrays to raw float arrays
  var inputArr: seq[float32] = @[]
  for v in inputData.a:
    if v.kind == vkFloat: inputArr.add(v.f.float32)
    elif v.kind == vkInt: inputArr.add(v.i.float32)
  
  var outputArr = newSeq[float32](outputData.a.len)
  
  let success = js_runComputeShader(
    shader.code.cstring,
    addr inputArr[0], inputArr.len,
    addr outputArr[0], outputArr.len,
    shader.workgroupSize.x.cint,
    shader.workgroupSize.y.cint,
    shader.workgroupSize.z.cint
  )
  
  # Note: Results are written asynchronously to outputArr
  # For sync behavior, would need callback mechanism
  return valBool(success == 1)
```

## Key Technical Details

### EM_JS Macro
- **What**: Emscripten macro that defines JavaScript code callable from C/WASM
- **Why**: Provides direct JavaScript execution context with WASM memory access
- **How**: JavaScript code embedded in C, compiled into WASM glue code

### Memory Access
- `HEAPF32`: JavaScript typed array view of WASM memory heap
- Pointers from Nim become offsets into JavaScript typed arrays
- Zero-copy array passing (direct memory access)

### Data Serialization
- **Uniforms**: Nim map → JSON string → JavaScript object
- **Arrays**: Nim seq → raw pointer → JavaScript Float32Array → Array
- **Strings**: Nim cstring → `UTF8ToString()` → JavaScript string

### Async Handling
- GPU operations are asynchronous (WebGPU API design)
- Current design: Fire and forget (non-blocking)
- Future enhancement: Callback/promise mechanism for completion notifications

## Benefits

✅ **Direct JavaScript Access**: No HTTP or message passing overhead  
✅ **Efficient Arrays**: Zero-copy memory access via HEAPF32  
✅ **Clean Separation**: JavaScript stays in .js files, bridge is minimal  
✅ **Type Safety**: EM_JS signatures enforce parameter types  
✅ **Async Native**: GPU operations work naturally asynchronously  

## Alternatives Considered

### 1. JavaScript Backend Compilation
- Compile separate module with `--backend:js`
- **Pros**: Full JS object access, no serialization
- **Cons**: Dual compilation, module loading complexity

### 2. emscripten_run_script
- Execute JavaScript via string eval
- **Pros**: Simple API
- **Cons**: No type safety, string escaping hell, no return values

### 3. ccall/cwrap
- Call exported C functions from JS
- **Pros**: Bidirectional calls
- **Cons**: Wrong direction for this use case

## Testing

Once implemented, test with:

```javascript
// In markdown code block
let input = [1.0, 2.0, 3.0, 4.0];
let output = new Array(4);

runComputeShader("particleShader", input, output);
print(output); // Should show GPU-computed results
```

## References

- [Emscripten EM_JS Documentation](https://emscripten.org/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html#calling-javascript-from-c-c)
- [HEAPF32 Memory Access](https://emscripten.org/docs/api_reference/preamble.js.html#accessing-memory)
- [WebGPU Compute Shader Guide](https://webgpufundamentals.org/webgpu/lessons/webgpu-compute-shaders.html)

## Implementation Checklist

- [ ] Add EM_JS wrapper functions to wgsl_bindings.nim
- [ ] Update nimini_updateShader to serialize uniforms
- [ ] Update nimini_runComputeShader to pass arrays via HEAPF32
- [ ] Test with simple compute shader
- [ ] Add error handling and validation
- [ ] Document async behavior and limitations
- [ ] Consider callback mechanism for completion events

---

**Status**: Architecture defined, ready for implementation  
**Priority**: Medium (functions are registered and callable, but stubbed)  
**Estimated Effort**: 2-4 hours
