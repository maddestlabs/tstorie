---
title: "BSP Dungeon - Deterministic Edition"
author: "Guaranteed identical results in script and native!"
minWidth: 80
minHeight: 25
---

# BSP Dungeon Generator

Press **R** to regenerate with new seed.

**Guarantee:** Uses only procgen primitives - same seed produces **identical** dungeons in script and native!

```nim on:init
# Constants - identical in all implementations
const WALL = 0
const FLOOR = 1

const WIDTH = 79
const HEIGHT = 24

# State
var grid: seq
var seed: int
var roomCenters: seq  # Simple array of [x, y] pairs

# Helper to make a point [x, y]
proc makePoint(x: int, y: int): seq =
  var p = newSeq(2)
  p[0] = x
  p[1] = y
  return p

# Carve a room in given area
proc carveRoom(rng: Rand, areaX: int, areaY: int, areaW: int, areaH: int) =
  # Room size using clamp primitive
  var minSize = 4
  var maxW = clamp(areaW - 4, minSize, areaW - 2)
  var maxH = clamp(areaH - 4, minSize, areaH - 2)
  var roomW = clamp(rng.rand(minSize, maxW), minSize, maxW)
  var roomH = clamp(rng.rand(minSize, maxH), minSize, maxH)
  
  # Center room using idiv primitive
  var roomX = areaX + idiv(areaW - roomW, 2)
  var roomY = areaY + idiv(areaH - roomH, 2)
  
  # Carve room
  for ry in roomY..<(roomY + roomH):
    for rx in roomX..<(roomX + roomW):
      if ry >= 0 and ry < HEIGHT and rx >= 0 and rx < WIDTH:
        grid[ry][rx] = FLOOR
  
  # Store room center using idiv
  var cx = roomX + idiv(roomW, 2)
  var cy = roomY + idiv(roomH, 2)
  add(roomCenters, makePoint(cx, cy))

proc generateDungeon() =
  roomCenters = newSeq(0)
  
  # Initialize grid
  grid = newSeq(HEIGHT)
  for y in 0..<HEIGHT:
    var row = newSeq(WIDTH)
    for x in 0..<WIDTH:
      row[x] = WALL
    grid[y] = row
  
  # Get seed parameter or generate
  if hasParam("seed"):
    seed = getParamInt("seed", 0)
  
  if seed == 0:
    seed = rand(1, 999999)
  
  # Create isolated RNG - CRITICAL for determinism!
  var rng = initRand(seed)
  
  # Create 8-12 rooms in grid pattern using primitives
  var roomCount = clamp(rng.rand(8, 12), 8, 12)
  var cols = 3
  var rows = idiv(roomCount + cols - 1, cols)  # Ceiling division
  
  var cellW = idiv(WIDTH, cols)
  var cellH = idiv(HEIGHT, rows)
  
  for i in 0..<roomCount:
    var col = imod(i, cols)
    var row = idiv(i, cols)
    
    var cellX = col * cellW
    var cellY = row * cellH
    
    carveRoom(rng, cellX, cellY, cellW, cellH)
  
  # Connect rooms with corridors
  for i in 0..<(len(roomCenters) - 1):
    var center1 = roomCenters[i]
    var center2 = roomCenters[i + 1]
    var cx1 = center1[0]
    var cy1 = center1[1]
    var cx2 = center2[0]
    var cy2 = center2[1]
    
    # L-shaped corridor from room center to room center
    var x = cx1
    var y = cy1
    
    # Horizontal segment
    while x != cx2:
      if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
        grid[y][x] = FLOOR
      
      if x < cx2:
        x = x + 1
      else:
        x = x - 1
    
    # Vertical segment
    while y != cy2:
      if x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT:
        grid[y][x] = FLOOR
      
      if y < cy2:
        y = y + 1
      else:
        y = y - 1

# Initialize
generateDungeon()
```

```nim on:render
# Draw dungeon
clear()

for y in 0..<HEIGHT:
  for x in 0..<WIDTH:
    var cell = grid[y][x]
    var ch = "#"
    
    if cell == FLOOR:
      ch = "·"
    
    draw(0, x, y, ch)

# Draw room numbers (for debugging)
for i in 0..<len(roomCenters):
  var center = roomCenters[i]
  var cx = center[0]
  var cy = center[1]
  if cx >= 0 and cx < WIDTH and cy >= 0 and cy < HEIGHT:
    draw(0, cx, cy, str(i))

# Status
draw(0, 0, HEIGHT, "Seed: " & str(seed) & "  Rooms: " & str(len(roomCenters)))
draw(0, 0, HEIGHT + 1, "Using ONLY procgen primitives - guaranteed deterministic!")
draw(0, 0, HEIGHT + 2, "Press R to regenerate | Same seed = same dungeon in native too!")
```

```nim on:input
if event.type == "text":
  var key = event.text
  if key == "r" or key == "R":
    seed = 0  # Will generate new random seed
    generateDungeon()
    return true

return false
```
