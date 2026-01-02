## Test object types and isolated RNG support in Nimini

import ../nimini/parser
import ../nimini/tokenizer
import ../nimini/codegen
import ../nimini/runtime
import ../nimini/ast
import std/[strutils, random]

# Test 1: Basic object type definition and field access
proc testBasicObjectType() =
  echo "Test 1: Basic object type definition"
  let code = """
type Point = object
  x: int
  y: int

let p = Point(x: 10, y: 20)
print(p.x)
print(p.y)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    let ctx = newCodegenContext()
    let nimCode = genProgram(prog, ctx)
    echo "Generated Nim code:"
    echo nimCode
    echo "✓ Test 1 passed"
  except Exception as e:
    echo "✗ Test 1 failed: ", e.msg

# Test 2: Object with var parameter (mutable reference)
proc testMutableObject() =
  echo "\nTest 2: Mutable object with var parameter"
  let code = """
type Counter = object
  value: int

proc increment(c: var Counter):
  c.value = c.value + 1

var counter = Counter(value: 0)
increment(counter)
print(counter.value)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    let ctx = newCodegenContext()
    let nimCode = genProgram(prog, ctx)
    echo "Generated Nim code:"
    echo nimCode
    echo "✓ Test 2 passed"
  except Exception as e:
    echo "✗ Test 2 failed: ", e.msg

# Test 3: Nested field access
proc testNestedFieldAccess() =
  echo "\nTest 3: Nested field access"
  let code = """
type Inner = object
  value: int

type Outer = object
  inner: Inner

let obj = Outer(inner: Inner(value: 42))
print(obj.inner.value)
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    let ctx = newCodegenContext()
    let nimCode = genProgram(prog, ctx)
    echo "Generated Nim code:"
    echo nimCode
    echo "✓ Test 3 passed"
  except Exception as e:
    echo "✗ Test 3 failed: ", e.msg

when isMainModule:
  echo "=== Testing Nimini Object Types ==="
  testBasicObjectType()
  testMutableObject()
  testNestedFieldAccess()
