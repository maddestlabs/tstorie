## Test isolated RNG with object types (DungeonGenerator example)

import ../nimini

proc testDungeonGenerator() =
  echo "=== Test: RNG in Object Type (Dungeon Generator) ==="
  
  let code = """
type DungeonGenerator = object
  rng: Rand
  width: int
  height: int
  roomCount: int

proc newDungeonGenerator(seed: int, w: int, h: int): DungeonGenerator =
  var gen: DungeonGenerator
  gen.width = w
  gen.height = h
  gen.rng = initRand(seed)
  gen.roomCount = 0
  return gen

proc generateRoomSize(gen: var DungeonGenerator): int =
  return rand(gen.rng, 4, 10)

proc generateRoomPosition(gen: var DungeonGenerator): int =
  return rand(gen.rng, 0, gen.width - 10)

# Create two generators with the same seed
var gen1 = newDungeonGenerator(654321, 80, 40)
var gen2 = newDungeonGenerator(654321, 80, 40)

print("Gen1 - Room sizes and positions:")
var i = 0
while i < 5:
  let size = gen1.generateRoomSize()
  let pos = gen1.generateRoomPosition()
  print("Room " & str(i) & ": size=" & str(size) & ", x=" & str(pos))
  i = i + 1

print("Gen2 - Room sizes and positions (should be identical):")
i = 0
while i < 5:
  let size = gen2.generateRoomSize()
  let pos = gen2.generateRoomPosition()
  print("Room " & str(i) & ": size=" & str(size) & ", x=" & str(pos))
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
    echo e.getStackTrace()

when isMainModule:
  echo "Testing RNG in Object Types"
  echo "==========================="
  testDungeonGenerator()
  echo "\nTest completed!"
