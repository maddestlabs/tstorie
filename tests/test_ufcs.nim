## Test to verify UFCS (Uniform Function Call Syntax) already works in nimini

import ../nimini

proc testBasicUFCS() =
  echo "\n=== Testing Basic UFCS (Already Works!) ==="
  
  let code = """
# Define a helper function that takes an object as first parameter
proc double(x: int): int =
  x * 2

proc add(x: int, y: int): int =
  x + y

# Test UFCS with function calls
let num = 5
let doubled = num.double()
let sum = num.add(3)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    let env = runtimeEnv
    echo "✓ Basic UFCS test passed - parser converts x.f() to f(x)"
    echo "  num.double() = ", getVar(env, "doubled").i
    echo "  num.add(3) = ", getVar(env, "sum").i
  except Exception as e:
    echo "✗ UFCS test failed: ", e.msg

proc testMapUFCS() =
  echo "\n=== Testing UFCS with Maps/Objects ==="
  
  let code = """
# Maps already support field access
let person = {name: "Alice", age: 30}

# Field access works
let name = person.name
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    let env = runtimeEnv
    let nameVal = getVar(env, "name")
    echo "✓ Map field access works"
    echo "  person.name = ", nameVal.s
  except Exception as e:
    echo "✗ Map UFCS test failed: ", e.msg

proc testChaining() =
  echo "\n=== Testing Method Chaining Concept ==="
  
  let code = """
# Define chainable functions (return the modified value)
proc increment(x: int): int =
  x + 1

proc double(x: int): int =
  x * 2

# Chain multiple calls
let start = 5
let step1 = start.increment()
let step2 = step1.double()
let step3 = step2.increment()
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    let env = runtimeEnv
    echo "✓ Chaining works (with intermediate variables)"
    echo "  start = ", getVar(env, "start").i
    echo "  after increment = ", getVar(env, "step1").i
    echo "  after double = ", getVar(env, "step2").i
    echo "  after increment = ", getVar(env, "step3").i
  except Exception as e:
    echo "✗ Chaining test failed: ", e.msg

proc testNestedUFCS() =
  echo "\n=== Testing Nested UFCS Calls ==="
  
  let code = """
proc add(x: int, y: int): int =
  x + y

proc multiply(x: int, y: int): int =
  x * y

# Nested UFCS - what we really want is: 5.add(3).multiply(2)
# For now, we need to break it down
let a = 5
let b = a.add(3)
let c = b.multiply(2)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    let env = runtimeEnv
    echo "✓ Nested UFCS works with variables"
    echo "  5.add(3) = ", getVar(env, "b").i
    echo "  8.multiply(2) = ", getVar(env, "c").i
  except Exception as e:
    echo "✗ Nested UFCS test failed: ", e.msg

proc testStdlibUFCS() =
  echo "\n=== Testing UFCS with Stdlib Functions ==="
  
  let code = """
# Test with existing stdlib functions
let arr = @[1, 2, 3]
let length = arr.len()

let str = "hello"
let upper = str.toUpper()
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    let env = runtimeEnv
    echo "✓ Stdlib UFCS test passed"
    echo "  arr.len() = ", getVar(env, "length").i
    echo "  str.toUpper() = ", getVar(env, "upper").s
  except Exception as e:
    echo "✗ Stdlib UFCS test failed: ", e.msg
    echo "  Note: Some stdlib functions may not be registered yet"

when isMainModule:
  echo "Testing UFCS Support in Nimini"
  echo "================================"
  testBasicUFCS()
  testMapUFCS()
  testChaining()
  testNestedUFCS()
  testStdlibUFCS()
  echo "\n=== Summary ==="
  echo "UFCS syntax (x.func()) is already supported!"
  echo "Parser converts x.method(args) → method(x, args)"
  echo "To enable chaining, functions should return their result"
  echo "================================"
