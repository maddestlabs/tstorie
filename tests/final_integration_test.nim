## Final Integration Test - RNG in Objects

import ../nimini

echo "=== Isolated RNG with Object Types ==="
echo "Testing runtime execution (not just codegen)\n"

let code = """
type Generator = object
  rng: Rand
  value: int

proc newGenerator(seed: int): Generator =
  var g: Generator
  g.rng = initRand(seed)
  g.value = 0
  return g

var gen = newGenerator(42)
print("Value 1: " & str(rand(gen.rng, 1000)))
print("Value 2: " & str(rand(gen.rng, 1000)))
print("Value 3: " & str(rand(gen.rng, 1000)))
"""

echo "Nimini Code:"
echo code

try:
  let tokens = tokenizeDsl(code)
  let prog = parseDsl(tokens)
  initRuntime()
  initStdlib()
  
  echo "\nRuntime Execution:"
  execProgram(prog, runtimeEnv)
  
  echo "\n✓ Success! Isolated RNG works in object types!"
except Exception as e:
  echo "\n✗ Failed: ", e.msg
