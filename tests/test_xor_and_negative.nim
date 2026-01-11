## Test file for XOR operator and negative variable support in nimini

import ../nimini
import std/[strutils]

proc testXorOperator() =
  echo "\n=== Testing XOR Operator ==="
  
  let code = """
let a = true
let b = false
let c = true

let result1 = a xor b
let result2 = a xor c
let result3 = b xor b
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    # Verify results
    let env = runtimeEnv
    let r1 = getVar(env, "result1")
    let r2 = getVar(env, "result2")
    let r3 = getVar(env, "result3")
    
    echo "true xor false = ", r1.b
    echo "true xor true = ", r2.b
    echo "false xor false = ", r3.b
    
    if r1.b == true and r2.b == false and r3.b == false:
      echo "✓ XOR operator test passed"
    else:
      echo "✗ XOR operator test failed: incorrect results"
  except Exception as e:
    echo "✗ XOR operator test failed: ", e.msg

proc testNegativeVariable() =
  echo "\n=== Testing Negative Variable ==="
  
  let code = """
let x = 10
let y = -x
let z = 5

let neg_z = -z
let double_neg = -(-x)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    # Verify results
    let env = runtimeEnv
    let x_val = getVar(env, "x")
    let y_val = getVar(env, "y")
    let z_val = getVar(env, "z")
    let neg_z_val = getVar(env, "neg_z")
    let double_neg_val = getVar(env, "double_neg")
    
    echo "x = ", x_val.i
    echo "-x = ", y_val.i
    echo "z = ", z_val.i
    echo "-z = ", neg_z_val.i
    echo "-(-x) = ", double_neg_val.i
    
    if y_val.i == -10 and neg_z_val.i == -5 and double_neg_val.i == 10:
      echo "✓ Negative variable test passed"
    else:
      echo "✗ Negative variable test failed: incorrect results"
  except Exception as e:
    echo "✗ Negative variable test failed: ", e.msg

proc testXorWithVariables() =
  echo "\n=== Testing XOR with Variables ==="
  
  let code = """
let x = 5
let y = 3

let result1 = (x > 4) xor (y > 4)
let result2 = (x > 4) xor (y > 2)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    # Verify results
    let env = runtimeEnv
    let x_val = getVar(env, "x")
    let y_val = getVar(env, "y")
    let r1 = getVar(env, "result1")
    let r2 = getVar(env, "result2")
    
    echo "x > 4 = true"
    echo "y > 4 = false"
    echo "y > 2 = true"
    echo "(x > 4) xor (y > 4) = ", r1.b
    echo "(x > 4) xor (y > 2) = ", r2.b
    
    if r1.b == true and r2.b == false:
      echo "✓ XOR with variables test passed"
    else:
      echo "✗ XOR with variables test failed: incorrect results"
  except Exception as e:
    echo "✗ XOR with variables test failed: ", e.msg

proc testNegativeInExpressions() =
  echo "\n=== Testing Negative Variables in Expressions ==="
  
  let code = """
let a = 10
let b = 5

let result1 = -a + b
let result2 = a + (-b)
let result3 = -a * -b
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(program, runtimeEnv)
    
    # Verify results
    let env = runtimeEnv
    let a_val = getVar(env, "a")
    let b_val = getVar(env, "b")
    let r1 = getVar(env, "result1")
    let r2 = getVar(env, "result2")
    let r3 = getVar(env, "result3")
    
    echo "a = ", a_val.i
    echo "b = ", b_val.i
    echo "-a + b = ", r1.i
    echo "a + (-b) = ", r2.i
    echo "-a * -b = ", r3.i
    
    if r1.i == -5 and r2.i == 5 and r3.i == 50:
      echo "✓ Negative in expressions test passed"
    else:
      echo "✗ Negative in expressions test failed: incorrect results"
  except Exception as e:
    echo "✗ Negative in expressions test failed: ", e.msg

when isMainModule:
  echo "Testing XOR operator and negative variable support"
  testXorOperator()
  testNegativeVariable()
  testXorWithVariables()
  testNegativeInExpressions()
  echo "\n=== All tests completed ==="
