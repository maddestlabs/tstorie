import nimini
import std/tables

let code = """
# Test door placement
var grid: seq
var width = 20
var height = 10

proc getCell(x: int, y: int): int =
  if y >= 0 and y < height and x >= 0 and x < width:
    var row = grid[y]
    return row[x]
  return 0

proc setCell(x: int, y: int, cellType: int) =
  if y >= 0 and y < height and x >= 0 and x < width:
    var row = grid[y]
    row[x] = cellType

# Init grid
grid = newSeq(height)
for y in 0..<height:
  var row = newSeq(width)
  for x in 0..<width:
    row[x] = 0
  grid[y] = row

# Create a simple room (5x5 at position 5,2)
for y in 2..<7:
  for x in 5..<10:
    setCell(x, y, 1)

# Create a corridor to the left
for x in 2..<5:
  setCell(x, 4, 3)

# Place door at corridor next to room
if getCell(4, 4) == 3:
  setCell(4, 4, 2)

# Print the result
for y in 0..<height:
  var row = grid[y]
  for x in 0..<width:
    var cell = row[x]
    if cell == 0:
      echo("#")
    elif cell == 1:
      echo(".")
    elif cell == 2:
      echo("+")
    elif cell == 3:
      echo("~")
  echo("")
"""

try:
  let tokens = tokenizeDsl(code)
  initRuntime()
  let program = parseDsl(tokens)
  execProgram(program, runtimeEnv)
  echo "Done"
except Exception as e:
  echo "Error: ", e.msg
