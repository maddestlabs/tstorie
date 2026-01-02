## Generate native Nim code from Nimini script with isolated RNG

import ../nimini

let code = """
type DungeonGenerator = object
  rng: Rand
  width: int
  height: int

proc newGenerator(seed: int): DungeonGenerator =
  var gen: DungeonGenerator
  gen.rng = initRand(seed)
  gen.width = 80
  gen.height = 40
  return gen

proc generateRoom(gen: var DungeonGenerator): int =
  return rand(gen.rng, 4, 10)

var gen = newGenerator(12345)
print("First room: " & str(gen.generateRoom()))
print("Second room: " & str(gen.generateRoom()))
"""

echo "=== Nimini Script with Isolated RNG ==="
echo code

echo "\n=== Generated Nim Code ==="
let tokens = tokenizeDsl(code)
let prog = parseDsl(tokens)
let ctx = newCodegenContext()
let nimCode = genProgram(prog, ctx)
echo nimCode

echo "\n=== Explanation ==="
echo "✓ Object type 'DungeonGenerator' has an isolated 'rng: Rand' field"
echo "✓ initRand(seed) creates a deterministic RNG instance"
echo "✓ rand(gen.rng, min, max) uses the isolated RNG"
echo "✓ Same seed always produces same sequence"
echo "✓ Multiple generators don't interfere with each other"
