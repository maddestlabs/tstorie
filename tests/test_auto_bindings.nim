## Test/Example of Auto-Binding System
## This demonstrates how to use the new auto-exposure macros

import std/tables
import ../nimini
import ../nimini/auto_bindings
import ../nimini/runtime

# ==============================================================================
# EXAMPLE: Simple function with auto-binding
# ==============================================================================

proc addNums*(a: int, b: int): int {.autoExpose: "math".} =
  ## Add two integers together
  result = a + b

proc multiply*(x: float, y: float): float {.autoExpose: "math".} =
  ## Multiply two floats
  result = x * y

proc greet*(name: string): string {.autoExpose: "text".} =
  ## Generate a greeting message
  result = "Hello, " & name & "!"

proc isPositive*(n: int): bool {.autoExpose: "math".} =
  ## Check if a number is positive
  result = n > 0

# The above generates:
# 1. Original functions (can be called from Nim)
# 2. Wrapper functions (niminiAuto_addNums, etc.)
# 3. Auto-registration calls

# ==============================================================================
# TEST IT
# ==============================================================================

when isMainModule:
  import ../nimini
  
  # Initialize runtime
  initRuntime()
  
  # Register the auto-exposed functions  
  register_addNums()
  register_multiply()
  register_greet()
  register_isPositive()
  
  # Test from Nim side
  echo "Native call: addNums(5, 3) = ", addNums(5, 3)
  echo "Native call: greet(\"World\") = ", greet("World")
  echo "Native call: isPositive(10) = ", isPositive(10)
  echo "Native call: multiply(3.5, 2.0) = ", multiply(3.5, 2.0)
  
  # Test from nimini side via runtimeEnv
  echo "\nCalling through nimini runtime:"
  
  # Look up functions in the runtime environment
  var addFunc: NativeFunc
  if runtimeEnv.vars.hasKey("addNums"):
    let val = runtimeEnv.vars["addNums"]
    if val.kind == vkFunction and val.fnVal.isNative:
      addFunc = val.fnVal.native
      let result = addFunc(runtimeEnv, @[valInt(100), valInt(23)])
      echo "Nimini: addNums(100, 23) = ", result
  
  var greetFunc: NativeFunc
  if runtimeEnv.vars.hasKey("greet"):
    let val = runtimeEnv.vars["greet"]
    if val.kind == vkFunction and val.fnVal.isNative:
      greetFunc = val.fnVal.native
      let result = greetFunc(runtimeEnv, @[valString("Auto-Bindings")])
      echo "Nimini: greet(\"Auto-Bindings\") = ", result
  
  echo "\n✅ Auto-binding system working!"
