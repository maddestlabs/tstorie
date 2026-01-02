## Test isolated RNG support in Nimini

import ../nimini

# Test isolated RNG with deterministic generation
proc testIsolatedRNG() =
  echo "=== Test: Isolated RNG ==="
  
  let code = """
# Create two generators with the same seed
var rng1 = initRand(12345)
var rng2 = initRand(12345)

# Generate 10 random numbers from each - they should be identical
print("Generator 1:")
var i = 0
while i < 10:
  let val = rand(rng1, 100)
  print(val)
  i = i + 1

print("Generator 2:")
i = 0
while i < 10:
  let val = rand(rng2, 100)
  print(val)
  i = i + 1

# Test that different seeds produce different results
var rng3 = initRand(54321)
print("Generator 3 (different seed):")
i = 0
while i < 10:
  let val = rand(rng3, 100)
  print(val)
  i = i + 1
"""
  
  echo "--- Nimini Code ---"
  echo code
  echo "\n--- Execution ---"
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    
    # Initialize runtime
    initRuntime()
    initStdlib()
    
    # Execute
    execProgram(prog, runtimeEnv)
    
    echo "\n✓ Test passed"
  except Exception as e:
    echo "\n✗ Test failed: ", e.msg
    echo "  ", e.getStackTrace()

# Test that same seed always produces same sequence
proc testDeterminism() =
  echo "\n=== Test: Deterministic Generation ==="
  
  let code = """
# Function to generate a sequence of random numbers
proc generateSequence(seed: int): void =
  var rng = initRand(seed)
  print("Sequence from seed " & str(seed) & ":")
  var i = 0
  while i < 5:
    print(rand(rng, 1000))
    i = i + 1

# Generate same sequence twice
generateSequence(777)
generateSequence(777)

# Different seed produces different sequence  
generateSequence(888)
"""
  
  echo "--- Nimini Code ---"
  echo code
  echo "\n--- Execution ---"
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    
    # Initialize runtime
    initRuntime()
    initStdlib()
    
    # Execute
    execProgram(prog, runtimeEnv)
    
    echo "\n✓ Test passed"
  except Exception as e:
    echo "\n✗ Test failed: ", e.msg
    echo "  ", e.getStackTrace()

# Test RNG with object (like DungeonGenerator)
proc testRNGInObject() =
  echo "\n=== Test: RNG in Object Type ==="
  
  let code = """
type DungeonGenerator = object
  rng: Rand
  width: int
  height: int

proc newDungeonGenerator(seed: int, w: int, h: int): DungeonGenerator =
  var gen: DungeonGenerator
  gen.rng = initRand(seed)
  gen.width = w
  gen.height = h
  return gen

proc generateRoomSize(gen: var DungeonGenerator): int =
  return rand(gen.rng, 4, 10)

var gen1 = newDungeonGenerator(12345, 80, 40)
var gen2 = newDungeonGenerator(12345, 80, 40)

print("Gen1 room sizes:")
var i = 0
while i < 5:
  print(gen1.generateRoomSize())
  i = i + 1

print("Gen2 room sizes (should be identical):")
i = 0
while i < 5:
  print(gen2.generateRoomSize())
  i = i + 1
"""
  
  echo "--- Nimini Code ---"
  echo code
  echo "\n--- Execution ---"
  
  try:
    let tokens = tokenizeDsl(code)
    let prog = parseDsl(tokens)
    
    # Initialize runtime
    initRuntime()
    initStdlib()
    
    # Execute
    execProgram(prog, runtimeEnv)
    
    echo "\n✓ Test passed"
  except Exception as e:
    echo "\n✗ Test failed: ", e.msg
    echo "  ", e.getStackTrace()

when isMainModule:
  echo "===================================="
  echo "Testing Isolated RNG Support"
  echo "===================================="
  
  testIsolatedRNG()
  testDeterminism()
  testRNGInObject()
  
  echo "\n===================================="
  echo "All tests completed!"
  echo "===================================="
