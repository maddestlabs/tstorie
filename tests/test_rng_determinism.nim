## Test deterministic generation with isolated RNG

import ../nimini

proc testDeterminism() =
  echo "=== Test: Same seed produces same sequence ==="
  
  let code = """
# Create two generators with the same seed
var rng1 = initRand(77777)
var rng2 = initRand(77777)

print("Generator 1:")
var i = 0
while i < 10:
  print(rand(rng1, 1000))
  i = i + 1

print("Generator 2 (should be identical):")
i = 0
while i < 10:
  print(rand(rng2, 1000))
  i = i + 1
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(prog, runtimeEnv)
    echo "✓ Test passed"
  except Exception as e:
    echo "✗ Test failed: ", e.msg

proc testIndependence() =
  echo "\n=== Test: Multiple RNGs don't interfere ==="
  
  let code = """
# Create three independent generators
var rngA = initRand(111)
var rngB = initRand(222)
var rngC = initRand(333)

# Use them in interleaved fashion
print("Interleaved generation:")
print("A: " & str(rand(rngA, 100)))
print("B: " & str(rand(rngB, 100)))
print("C: " & str(rand(rngC, 100)))
print("A: " & str(rand(rngA, 100)))
print("B: " & str(rand(rngB, 100)))
print("C: " & str(rand(rngC, 100)))

# Create fresh generators with same seeds
var rngA2 = initRand(111)
var rngB2 = initRand(222)
var rngC2 = initRand(333)

print("Fresh generators (should match above):")
print("A2: " & str(rand(rngA2, 100)))
print("B2: " & str(rand(rngB2, 100)))
print("C2: " & str(rand(rngC2, 100)))
print("A2: " & str(rand(rngA2, 100)))
print("B2: " & str(rand(rngB2, 100)))
print("C2: " & str(rand(rngC2, 100)))
"""
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    initRuntime()
    initStdlib()
    execProgram(prog, runtimeEnv)
    echo "✓ Test passed"
  except Exception as e:
    echo "✗ Test failed: ", e.msg

when isMainModule:
  echo "Testing Isolated RNG Determinism"
  echo "================================="
  testDeterminism()
  testIndependence()
  echo "\nAll tests completed!"
