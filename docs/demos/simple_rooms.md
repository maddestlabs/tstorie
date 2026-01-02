---
title: "Simple Rooms - Deterministic"
author: "Guaranteed identical results"
minWidth: 80
minHeight: 25
---

# Simple Room Generator

Press **R** to regenerate with new seed.

Using only procgen primitives - **same seed = same rooms**!

```nim on:init
const WALL = 0
const FLOOR = 1
const WIDTH = 79
const HEIGHT = 24

var grid: seq
var seed = 12345
var roomCount = 0

proc generateRooms() =
  # Initialize grid
  grid = newSeq(HEIGHT)
  for y in 0..<HEIGHT:
    var row = newSeq(WIDTH)
    for x in 0..<WIDTH:
      row[x] = WALL
    grid[y] = row
  
  # Get seed from param or use default
  if hasParam("seed"):
    seed = getParamInt("seed", 12345)
  
  # Create isolated RNG
  var rng = initRand(seed)
  
  # Generate 8 rooms using primitives
  roomCount = 8
  for i in 0..<roomCount:
    # Use primitives for all calculations
    var roomW = clamp(rng.rand(5, 15), 5, 15)
    var roomH = clamp(rng.rand(4, 8), 4, 8)
    var roomX = clamp(rng.rand(1, WIDTH - roomW - 1), 1, WIDTH - roomW - 1)
    var roomY = clamp(rng.rand(1, HEIGHT - roomH - 1), 1, HEIGHT - roomH - 1)
    
    # Carve room
    for ry in roomY..<(roomY + roomH):
      for rx in roomX..<(roomX + roomW):
        if ry >= 0 and ry < HEIGHT and rx >= 0 and rx < WIDTH:
          grid[ry][rx] = FLOOR

generateRooms()
```

```nim on:render
clear()

for y in 0..<HEIGHT:
  for x in 0..<WIDTH:
    var ch = "#"
    if grid[y][x] == FLOOR:
      ch = "·"
    draw(0, x, y, ch)

draw(0, 0, HEIGHT, "Seed: " & str(seed) & "  Rooms: " & str(roomCount))
draw(0, 0, HEIGHT + 1, "Using ONLY procgen primitives!")
draw(0, 0, HEIGHT + 2, "Press R to regenerate with same seed")
```

```nim on:input
if event.type == "text":
  var key = event.text
  if key == "r" or key == "R":
    generateRooms()
    return true

return false
```
