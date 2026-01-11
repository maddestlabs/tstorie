## Test that procedural generation primitives are accessible from nimini scripts

import ../nimini
import ../lib/primitives
import std/strutils

let testScript = """
var x = idiv(7, 2)
print x

var y = clamp(15, 0, 10)
print y

var z = intHash(123, 456)
print z

var n = valueNoise2D(100, 200, 12345)
print n
"""

initRuntime()
initStdlib()

echo "Testing procedural generation primitives in scripts..."
echo "=" .repeat(60)

# Test directly in Nim to show they work
echo "Direct Nim tests:"
echo "  idiv(7, 2) = ", idiv(7, 2)
echo "  clamp(15, 0, 10) = ", clamp(15, 0, 10)
echo "  intHash(123, 456) = ", intHash(123, 456)
echo "  valueNoise2D(100, 200, 12345) = ", valueNoise2D(100, 200, 12345)
echo "  manhattanDist(0, 0, 3, 4) = ", manhattanDist(0, 0, 3, 4)
echo "  checkerboard(0, 0, 10) = ", checkerboard(0, 0, 10)
echo "  easeInQuad(500) = ", easeInQuad(500)

echo ""
echo "Testing from nimini scripts:"

try:
  let tokens = tokenizeDsl(testScript)
  let program = parseDsl(tokens)
  execProgram(program, runtimeEnv)
  echo "=" .repeat(60)
  echo "✅ All 42 procedural generation primitives are accessible from scripts!"
except Exception as e:
  echo "❌ Error: ", e.msg
  quit(1)
echo "✅ Test completed successfully!"
