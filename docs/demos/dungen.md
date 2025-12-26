---
title: "Dungeon Generator - Nimini Edition"
author: "Procedural dungeon using nimini scripting"
minWidth: 80
minHeight: 26
---

# Dungeon Generator

Press **R** to regenerate with a new random seed.
Press **Space** to step through generation (when complete).

```nim on:init

# Constants
const CELL_SOLID = 0
const CELL_MERGED = -1
const CELL_DOOR = -2
const WIGGLE_PERCENT = 50

# Global state
var width = 79
var height = 25
var floors = newSeq(0)
var rooms = newSeq(0)
var currentRegion = 0
var maxRoomSize = 5
var roomTriesLeft = 200
var mazeStartX = 1
var mazeStartY = 1
var lastMazeDir = 0
var mazeCells = newSeq(0)
var connectors = newSeq(0)
var mergeCells = newSeq(0)
var openCells = newSeq(0)
var deadEndSeek = 0
var seedValue = 0
var step = 0
var isGenerating = true
var maxSteps = 5000

# Helper: Create a Vec (vector/point)
proc makeVec(x: int, y: int): seq =
  var v = newSeq(2)
  v[0] = x
  v[1] = y
  return v

# Helper: Create a Rect
proc makeRect(x: int, y: int, w: int, h: int): seq =
  var r = newSeq(4)
  r[0] = x
  r[1] = y
  r[2] = w
  r[3] = h
  return r

# Helper: Vec addition
proc vecAdd(a: seq, b: seq): seq =
  return makeVec(a[0] + b[0], a[1] + b[1])

# Helper: Vec scalar multiply
proc vecMul(a: seq, scalar: int): seq =
  return makeVec(a[0] * scalar, a[1] * scalar)

# Helper: Manhattan distance
proc vecDist(a: seq, b: seq): int =
  var dx = a[0] - b[0]
  var dy = a[1] - b[1]
  if dx < 0:
    dx = -dx
  if dy < 0:
    dy = -dy
  return dx + dy

# Direction to vector (0=North, 1=South, 2=East, 3=West)
proc dirToVec(dir: int): seq =
  if dir == 0:
    return makeVec(0, -1)
  elif dir == 1:
    return makeVec(0, 1)
  elif dir == 2:
    return makeVec(1, 0)
  else:
    return makeVec(-1, 0)

# Get rect center
proc rectCenter(r: seq): seq =
  return makeVec(r[0] + r[2] / 2, r[1] + r[3] / 2)

# Check bounds
proc inBounds(pos: seq): bool =
  return pos[0] >= 0 and pos[0] < width and pos[1] >= 0 and pos[1] < height

# Get cell value
proc getCell(pos: seq): int =
  if not inBounds(pos):
    return CELL_SOLID
  var y = pos[1]
  var x = pos[0]
  var row = floors[y]
  return row[x]

# Set cell value
proc setCell(pos: seq, value: int) =
  if inBounds(pos):
    var y = pos[1]
    var x = pos[0]
    var row = floors[y]
    row[x] = value

# Carve floor at position
proc carve(pos: seq, value: int) =
  var finalValue = value
  if value == -99:
    finalValue = currentRegion
  setCell(pos, finalValue)

# Get unique regions touching a position
proc getRegionsTouching(pos: seq): seq =
  var regions = newSeq(0)
  if not inBounds(pos):
    return regions
  
  # Check all 4 cardinal directions
  for dir in 0..3:
    var checkPos = vecAdd(pos, dirToVec(dir))
    if inBounds(checkPos):
      var region = getCell(checkPos)
      if region != CELL_SOLID:
        # Check if already in list
        var found = false
        for i in 0..<len(regions):
          if regions[i] == region:
            found = true
            break
        if not found:
          add(regions, region)
  
  return regions

# Check if rect overlaps with any existing room
proc rectOverlaps(rect: seq): bool =
  var rx = rect[0]
  var ry = rect[1]
  var rw = rect[2]
  var rh = rect[3]
  
  for i in 0..<len(rooms):
    var other = rooms[i]
    var ox = other[0]
    var oy = other[1]
    var ow = other[2]
    var oh = other[3]
    
    # Calculate distance between rects
    var ax = rx + rw / 2
    var ay = ry + rh / 2
    var bx = ox + ow / 2
    var by = oy + oh / 2
    
    var distX = ax - bx
    var distY = ay - by
    if distX < 0:
      distX = -distX
    if distY < 0:
      distY = -distY
    
    distX = distX - (rw + ow) / 2
    distY = distY - (rh + oh) / 2
    
    var maxDist = distX
    if distY > maxDist:
      maxDist = distY
    
    if maxDist <= 0:
      return true
  
  return false

# Add a room to the dungeon
proc addRoom(): bool =
  if roomTriesLeft <= 0:
    return false
  
  while roomTriesLeft > 0:
    roomTriesLeft = roomTriesLeft - 1
    
    var w = (rand(1, maxRoomSize - 1) * 2) + 1
    var h = (rand(1, maxRoomSize - 1) * 2) + 1
    
    if w > width - 2:
      w = width - 2
    if h > height - 2:
      h = height - 2
    
    if w < 3 or h < 3:
      continue
    
    var maxX = width - w - 2
    var maxY = height - h - 2
    
    if maxX <= 0 or maxY <= 0:
      continue
    
    var x = (rand(0, maxX) / 2) * 2 + 1
    var y = (rand(0, maxY) / 2) * 2 + 1
    
    var room = makeRect(x, y, w, h)
    
    if rectOverlaps(room):
      continue
    
    add(rooms, room)
    currentRegion = currentRegion + 1
    
    # Carve room
    for ry in y..<(y + h):
      for rx in x..<(x + w):
        carve(makeVec(rx, ry), -99)
    
    return true
  
  return false

# Start a new maze cell
proc startMazeCell() =
  var pos = makeVec(mazeStartX, mazeStartY)
  add(mazeCells, pos)
  currentRegion = currentRegion + 1
  carve(pos, -99)

# Grow maze using recursive backtracking
proc growMaze(): bool =
  if len(mazeCells) == 0:
    return false
  
  while len(mazeCells) > 0:
    var cell = mazeCells[len(mazeCells) - 1]
    var openDirs = newSeq(0)
    
    # Check all 4 directions
    for dir in 0..3:
      var vec = dirToVec(dir)
      var checkPos = vecAdd(cell, vecMul(vec, 2))
      if not inBounds(checkPos):
        continue
      if getCell(checkPos) != CELL_SOLID:
        continue
      add(openDirs, dir)
    
    if len(openDirs) == 0:
      # Dead end, backtrack
      delete(mazeCells, len(mazeCells) - 1)
      continue
    
    # Pick direction (prefer continuing straight)
    var dir = 0
    var found = false
    for i in 0..<len(openDirs):
      if openDirs[i] == lastMazeDir:
        found = true
        break
    
    if found and rand(0, 100) > WIGGLE_PERCENT:
      dir = lastMazeDir
    else:
      dir = openDirs[rand(0, len(openDirs) - 1)]
    
    lastMazeDir = dir
    var vec = dirToVec(dir)
    carve(vecAdd(cell, vec), -99)
    carve(vecAdd(cell, vecMul(vec, 2)), -99)
    add(mazeCells, vecAdd(cell, vecMul(vec, 2)))
    
    return true
  
  return false

# Find next maze start position
proc startMaze(): bool =
  if mazeStartY >= height - 1:
    return false
  
  while getCell(makeVec(mazeStartX, mazeStartY)) != CELL_SOLID:
    mazeStartX = mazeStartX + 2
    if mazeStartX >= width - 1:
      mazeStartX = 1
      mazeStartY = mazeStartY + 2
      if mazeStartY >= height - 1:
        # Done with mazes, find connectors
        findConnectors()
        return false
  
  startMazeCell()
  return true

# Find all connector cells (walls touching 2+ regions)
proc findConnectors() =
  for y in 1..<(height - 1):
    for x in 1..<(width - 1):
      var pos = makeVec(x, y)
      if getCell(pos) > CELL_SOLID:
        continue
      var regions = getRegionsTouching(pos)
      if len(regions) >= 2:
        add(connectors, pos)
  
  # Shuffle connectors
  var n = len(connectors)
  for i in 0..<n:
    var j = rand(i, n - 1)
    var temp = connectors[i]
    connectors[i] = connectors[j]
    connectors[j] = temp
  
  # Start merge from first room
  if len(rooms) > 0:
    var pos = rectCenter(rooms[0])
    add(mergeCells, pos)
    carve(pos, CELL_MERGED)

# Merge regions using connectors
proc mergeRegions(): bool =
  if len(connectors) == 0 or len(rooms) == 0:
    return false
  
  var connector = newSeq(2)
  var merged = newSeq(0)
  var foundConnector = false
  
  # Find a connector touching the merged region
  for i in 0..<len(connectors):
    merged = getRegionsTouching(connectors[i])
    var hasMerged = false
    for j in 0..<len(merged):
      if merged[j] == CELL_MERGED:
        hasMerged = true
        break
    
    if hasMerged:
      connector = connectors[i]
      delete(connectors, i)
      foundConnector = true
      break
  
  if not foundConnector:
    return false
  
  # Remove nearby connectors and those that don't add new regions
  var i = 0
  while i < len(connectors):
    var pos = connectors[i]
    if vecDist(pos, connector) < 2:
      delete(connectors, i)
      continue
    
    var touchingRegions = getRegionsTouching(pos)
    var hasNewRegion = false
    for j in 0..<len(touchingRegions):
      var foundInMerged = false
      for k in 0..<len(merged):
        if touchingRegions[j] == merged[k]:
          foundInMerged = true
          break
      if not foundInMerged:
        hasNewRegion = true
        break
    
    if not hasNewRegion:
      # Random extra door
      if rand(0, 50) == 0:
        carve(pos, CELL_DOOR)
      delete(connectors, i)
      continue
    
    i = i + 1
  
  add(mergeCells, connector)
  carve(connector, CELL_DOOR)
  return true

# Fill merged region using flood fill
proc fillMerge(): bool =
  if len(mergeCells) == 0:
    return false
  
  while len(mergeCells) > 0:
    var pos = mergeCells[0]
    delete(mergeCells, 0)
    
    for dir in 0..3:
      var checkPos = vecAdd(pos, dirToVec(dir))
      if not inBounds(checkPos):
        continue
      if getCell(checkPos) <= CELL_SOLID:
        continue
      
      carve(checkPos, CELL_MERGED)
      add(mergeCells, checkPos)
    
    break
  
  if len(mergeCells) == 0 and len(connectors) == 0:
    findOpenCells()
  
  return true

# Find all open cells for dead-end removal
proc findOpenCells() =
  openCells = newSeq(0)
  for y in 1..<(height - 1):
    for x in 1..<(width - 1):
      var pos = makeVec(x, y)
      if getCell(pos) != CELL_SOLID:
        add(openCells, pos)
  
  # Shuffle
  var n = len(openCells)
  for i in 0..<n:
    var j = rand(i, n - 1)
    var temp = openCells[i]
    openCells[i] = openCells[j]
    openCells[j] = temp
  
  deadEndSeek = 0

# Remove dead ends
proc removeDeadEnd(): bool =
  if len(openCells) == 0:
    return false
  if deadEndSeek >= len(openCells):
    deadEndSeek = 0
  
  var start = deadEndSeek
  while true:
    var pos = openCells[deadEndSeek]
    var exits = 0
    
    for dir in 0..3:
      var checkPos = vecAdd(pos, dirToVec(dir))
      if getCell(checkPos) != CELL_SOLID:
        exits = exits + 1
    
    if exits == 1:
      carve(pos, CELL_SOLID)
      delete(openCells, deadEndSeek)
      if deadEndSeek == len(openCells):
        deadEndSeek = 0
      return true
    
    deadEndSeek = (deadEndSeek + 1) % len(openCells)
    if deadEndSeek == start:
      openCells = newSeq(0)
      break
  
  return false

# Main update step
proc updateDungeon(): bool =
  if addRoom():
    return true
  if growMaze():
    return true
  if startMaze():
    return true
  if fillMerge():
    return true
  if mergeRegions():
    return true
  if removeDeadEnd():
    return true
  return false

# Initialize dungeon
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
  
  randomize(seedValue)
  
  floors = newSeq(height)
  for y in 0..<height:
    floors[y] = newSeq(width)
    for x in 0..<width:
      floors[y][x] = CELL_SOLID
  
  rooms = newSeq(0)
  currentRegion = 0
  mazeStartX = 1
  mazeStartY = 1
  lastMazeDir = 0
  roomTriesLeft = 200
  mazeCells = newSeq(0)
  connectors = newSeq(0)
  mergeCells = newSeq(0)
  openCells = newSeq(0)
  deadEndSeek = 0
  step = 0
  isGenerating = true

initDungeon()

```

```nim on:update
# Generate dungeon incrementally
if isGenerating:
  var stepsPerFrame = 10
  for i in 0..<stepsPerFrame:
    if not updateDungeon() or step >= maxSteps:
      isGenerating = false
      break
    step = step + 1
```

```nim on:render
# Draw the dungeon (always show current state)
bgClear()

for y in 0..<height:
  for x in 0..<width:
    var cell = floors[y][x]
    var ch = " "
    
    if cell == CELL_SOLID:
      ch = "█"
    elif cell == CELL_MERGED:
      ch = "·"
    elif cell == CELL_DOOR:
      ch = "+"
    else:
      ch = "·"
    
    bgWrite(x, y, ch)

# Show status
var testHasParam = hasParam("seed")
var testGetParam = getParam("seed")

if isGenerating:
  var progress = step * 100 / maxSteps
  if progress > 100:
    progress = 100
  bgWriteText(0, height + 1, "GENERATING... " & str(progress) & "% complete  Step: " & str(step))
  bgWriteText(0, height + 2, "Seed: " & str(seedValue))
else:
  bgWriteText(0, height + 1, "Seed: " & str(seedValue) & "  Steps: " & str(step))
  bgWriteText(0, height + 2, "Press R to regenerate")
```

```nim on:input
# Handle keyboard input
if event.type == "text":
  var key = event.text
  if key == "r" or key == "R":
    initDungeon()
    isGenerating = true
    return true
  return false

return false
```
