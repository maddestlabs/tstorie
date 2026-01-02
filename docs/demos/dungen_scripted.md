---
title: "Dungeon Generator - Nimini Edition"
author: "Procedural dungeon using nimini scripting with isolated RNG"
minWidth: 80
minHeight: 20
---

# Dungeon Generator

Press **R** to regenerate with a new random seed.

**Features:** Room-based dungeon with smart corridor connections and door placement!

```nim on:init

# Constants - identical in script and native
const WALL = 0
const FLOOR = 1
const DOOR = 2
const CORRIDOR = 3

# Global state
var grid: seq
var rooms: seq
var width = 79
var height = 25
var seedValue = 0

# Configuration
var maxRoomSize = 9
var minRoomSize = 4
var roomAttempts = 60

# Simple Rect structure using seq
proc makeRect(x: int, y: int, w: int, h: int): seq =
  var r = newSeq(4)
  r[0] = x
  r[1] = y
  r[2] = w
  r[3] = h
  return r

proc getRectX(r: seq): int =
  return r[0]

proc getRectY(r: seq): int =
  return r[1]

proc getRectW(r: seq): int =
  return r[2]

proc getRectH(r: seq): int =
  return r[3]

proc getRectCenterX(r: seq): int =
  return r[0] + idiv(r[2], 2)

proc getRectCenterY(r: seq): int =
  return r[1] + idiv(r[3], 2)

# Check if two rooms overlap (with buffer)
proc roomsOverlap(r1: seq, r2: seq): bool =
  var buffer = 3
  var r1Right = getRectX(r1) + getRectW(r1) + buffer
  var r1Bottom = getRectY(r1) + getRectH(r1) + buffer
  var r2Right = getRectX(r2) + getRectW(r2) + buffer
  var r2Bottom = getRectY(r2) + getRectH(r2) + buffer
  
  var r1Left = getRectX(r1) - buffer
  var r1Top = getRectY(r1) - buffer
  var r2Left = getRectX(r2) - buffer
  var r2Top = getRectY(r2) - buffer
  
  if r1Left >= r2Right or r2Left >= r1Right:
    return false
  if r1Top >= r2Bottom or r2Top >= r1Bottom:
    return false
  
  return true

# Get cell type
proc getCell(x: int, y: int): int =
  if y >= 0 and y < height and x >= 0 and x < width:
    var row = grid[y]
    return row[x]
  return WALL

# Set cell type
proc setCell(x: int, y: int, cellType: int) =
  if y >= 0 and y < height and x >= 0 and x < width:
    var row = grid[y]
    row[x] = cellType

# Generate dungeon with rooms and corridors
proc generateDungeon(w: int, h: int, seed: int): seq =
  var rng = initRand(seed)
  
  # Initialize grid - all walls
  var g = newSeq(h)
  for y in 0..<h:
    var row = newSeq(w)
    for x in 0..<w:
      row[x] = WALL
    g[y] = row
  
  grid = g
  rooms = newSeq(0)
  
  # Try to place rooms
  for attempt in 0..<roomAttempts:
    var roomW = rng.rand(maxRoomSize - minRoomSize) + minRoomSize
    var roomH = rng.rand(maxRoomSize - minRoomSize) + minRoomSize
    
    if roomW >= w - 4 or roomH >= h - 4:
      continue
    
    var roomX = rng.rand(w - roomW - 3) + 1
    var roomY = rng.rand(h - roomH - 3) + 1
    
    var newRoom = makeRect(roomX, roomY, roomW, roomH)
    
    # Check overlap with existing rooms
    var overlaps = false
    for i in 0..<len(rooms):
      var existingRoom = rooms[i]
      if roomsOverlap(newRoom, existingRoom):
        overlaps = true
        break
    
    if overlaps:
      continue
    
    # Add room
    add(rooms, newRoom)
    
    # Carve room
    var endY = roomY + roomH
    var endX = roomX + roomW
    for ry in roomY..<endY:
      for rx in roomX..<endX:
        setCell(rx, ry, FLOOR)
  
  # Connect rooms with corridors
  var roomCount = len(rooms)
  if roomCount > 1:
    for i in 0..<roomCount-1:
      var room1 = rooms[i]
      var room2 = rooms[i + 1]
      
      var x1 = getRectCenterX(room1)
      var y1 = getRectCenterY(room1)
      var x2 = getRectCenterX(room2)
      var y2 = getRectCenterY(room2)
      
      # Random corridor style (L or inverted L)
      if rng.rand(1) == 0:
        # Horizontal first
        var x = x1
        while x != x2:
          if getCell(x, y1) == WALL:
            setCell(x, y1, CORRIDOR)
          
          if x < x2:
            x = x + 1
          else:
            x = x - 1
        
        # Then vertical
        var y = y1
        while y != y2:
          if getCell(x2, y) == WALL:
            setCell(x2, y, CORRIDOR)
          
          if y < y2:
            y = y + 1
          else:
            y = y - 1
      else:
        # Vertical first
        var y = y1
        while y != y2:
          if getCell(x1, y) == WALL:
            setCell(x1, y, CORRIDOR)
          
          if y < y2:
            y = y + 1
          else:
            y = y - 1
        
        # Then horizontal
        var x = x1
        while x != x2:
          if getCell(x, y2) == WALL:
            setCell(x, y2, CORRIDOR)
          
          if x < x2:
            x = x + 1
          else:
            x = x - 1
  
  # Place doors at room entrances
  if roomCount > 0:
    for i in 0..<roomCount:
      var room = rooms[i]
      var rx = getRectX(room)
      var ry = getRectY(room)
      var rw = getRectW(room)
      var rh = getRectH(room)
      
      # Check around perimeter for corridor connections
      var endY = ry + rh
      var endX = rx + rw
      
      # Check each side of the room for adjacent corridors
      for py in ry..<endY:
        # Check left side (one tile outside room)
        if getCell(rx - 1, py) == CORRIDOR:
          setCell(rx - 1, py, DOOR)
        
        # Check right side (one tile outside room)
        if getCell(endX, py) == CORRIDOR:
          setCell(endX, py, DOOR)
      
      for px in rx..<endX:
        # Check top side (one tile outside room)
        if getCell(px, ry - 1) == CORRIDOR:
          setCell(px, ry - 1, DOOR)
        
        # Check bottom side (one tile outside room)
        if getCell(px, endY) == CORRIDOR:
          setCell(px, endY, DOOR)
  
  return g

# Initialize dungeon with isolated RNG!
proc initDungeon() =
  # Check if seed was provided via parameter (URL or command-line)
  var hasSeedParam = hasParam("seed")
  var seedParam = getParam("seed")
  
  if hasSeedParam and len(seedParam) > 0:
    seedValue = getParamInt("seed", 0)
    if seedValue <= 0:
      seedValue = rand(0, 999999)
  else:
    seedValue = rand(0, 999999)
  
  # Generate complete dungeon - instant and deterministic!
  grid = generateDungeon(width, height, seedValue)

initDungeon()

```

```nim on:update
# No incremental generation needed - dungeon generates instantly!
```

```nim on:render
# Draw the dungeon
clear()

for y in 0..<height:
  var row = grid[y]
  for x in 0..<width:
    var cell = row[x]
    var ch = " "
    
    if cell == WALL:
      ch = "#"
    elif cell == FLOOR:
      ch = "·"
    elif cell == DOOR:
      ch = "+"
    elif cell == CORRIDOR:
      ch = "·"
    
    draw(0, x, y, ch)

# Show info
draw(0, 0, height + 1, "Seed: " & str(seedValue) & " - Room-based with Smart Doors")
draw(0, 0, height + 2, "Press R to regenerate | Same seed = Same dungeon! (Export-safe)")
draw(0, 0, height + 3, "Rooms: " & str(len(rooms)) & " | Doors placed at corridor entrances")
```

```nim on:input
# Handle keyboard input
if event.type == "text":
  var key = event.text
  if key == "r" or key == "R":
    initDungeon()
    return true
  return false

return false
```
