## Procedural Dungeon Generator
## 
## High-performance native implementation of dungeon generation
## using rooms + maze + connector merging algorithm.

import std/[random, sequtils]

type
  CellType* = enum
    ctSolid = 0
    ctFloor = 1
    ctDoor = 2
    ctMerged = 3

  Vec2* = object
    x*, y*: int

  Rect* = object
    x*, y*, w*, h*: int

  Direction* = enum
    dirNorth = 0
    dirSouth = 1
    dirEast = 2
    dirWest = 3

  DungeonGenerator* = ref object
    width*, height*: int
    cells*: seq[seq[CellType]]
    rooms*: seq[Rect]
    currentRegion*: int
    regionMap*: seq[seq[int]]  # Tracks which region each cell belongs to
    
    # Random number generator (isolated per instance for reliable seeds)
    rng*: Rand
    
    # Configuration
    maxRoomSize*: int
    roomTries*: int
    wigglePercent*: int
    
    # Generation state
    mazeStartX*, mazeStartY*: int
    lastMazeDir*: Direction
    mazeCells*: seq[Vec2]
    connectors*: seq[Vec2]
    mergeCells*: seq[Vec2]
    openCells*: seq[Vec2]
    deadEndSeek*: int
    
    step*: int
    maxSteps*: int
    isGenerating*: bool

# ==============================================================================
# Vector & Rect Helpers
# ==============================================================================

proc vec2*(x, y: int): Vec2 {.inline.} =
  Vec2(x: x, y: y)

proc rect*(x, y, w, h: int): Rect {.inline.} =
  Rect(x: x, y: y, w: w, h: h)

proc `+`*(a, b: Vec2): Vec2 {.inline.} =
  vec2(a.x + b.x, a.y + b.y)

proc `*`*(v: Vec2, s: int): Vec2 {.inline.} =
  vec2(v.x * s, v.y * s)

proc dist*(a, b: Vec2): int {.inline.} =
  abs(a.x - b.x) + abs(a.y - b.y)

proc center*(r: Rect): Vec2 {.inline.} =
  vec2(r.x + r.w div 2, r.y + r.h div 2)

proc toVec*(dir: Direction): Vec2 {.inline.} =
  case dir
  of dirNorth: vec2(0, -1)
  of dirSouth: vec2(0, 1)
  of dirEast:  vec2(1, 0)
  of dirWest:  vec2(-1, 0)

# ==============================================================================
# DungeonGenerator Methods
# ==============================================================================

proc newDungeonGenerator*(width, height: int, seed: int = 0): DungeonGenerator =
  ## Create a new dungeon generator
  result = DungeonGenerator(
    width: width,
    height: height,
    maxRoomSize: 5,
    roomTries: 200,
    wigglePercent: 50,
    mazeStartX: 1,
    mazeStartY: 1,
    step: 0,
    maxSteps: 5000,
    isGenerating: true
  )
  
  # Initialize isolated RNG for this generator
  if seed != 0:
    result.rng = initRand(seed)
  else:
    result.rng = initRand()
  
  # Initialize grids
  result.cells = newSeqWith(height, newSeq[CellType](width))
  result.regionMap = newSeqWith(height, newSeq[int](width))

proc inBounds*(gen: DungeonGenerator, pos: Vec2): bool {.inline.} =
  pos.x >= 0 and pos.x < gen.width and pos.y >= 0 and pos.y < gen.height

proc getCell*(gen: DungeonGenerator, pos: Vec2): CellType {.inline.} =
  if not gen.inBounds(pos):
    return ctSolid
  gen.cells[pos.y][pos.x]

proc getRegion*(gen: DungeonGenerator, pos: Vec2): int {.inline.} =
  if not gen.inBounds(pos):
    return -1
  gen.regionMap[pos.y][pos.x]

proc setCell*(gen: DungeonGenerator, pos: Vec2, cell: CellType) {.inline.} =
  if gen.inBounds(pos):
    gen.cells[pos.y][pos.x] = cell

proc carve*(gen: DungeonGenerator, pos: Vec2, cell: CellType = ctFloor) =
  if gen.inBounds(pos):
    gen.cells[pos.y][pos.x] = cell
    gen.regionMap[pos.y][pos.x] = gen.currentRegion

proc getRegionsTouching*(gen: DungeonGenerator, pos: Vec2): seq[int] =
  ## Get unique region IDs touching this position
  result = @[]
  if not gen.inBounds(pos):
    return
  
  for dir in Direction:
    let checkPos = pos + dir.toVec()
    if gen.inBounds(checkPos):
      let region = gen.getRegion(checkPos)
      if region > 0 and region notin result:
        result.add(region)

proc overlaps*(gen: DungeonGenerator, r: Rect): bool =
  ## Check if rect overlaps with any existing room
  for room in gen.rooms:
    let dx = abs((r.x + r.w div 2) - (room.x + room.w div 2))
    let dy = abs((r.y + r.h div 2) - (room.y + room.h div 2))
    let minDistX = (r.w + room.w) div 2
    let minDistY = (r.h + room.h) div 2
    
    if dx < minDistX and dy < minDistY:
      return true
  
  return false

# ==============================================================================
# Generation Steps
# ==============================================================================

proc addRoom*(gen: DungeonGenerator): bool =
  ## Try to add a room to the dungeon
  if gen.roomTries <= 0:
    return false
  
  while gen.roomTries > 0:
    dec gen.roomTries
    
    # Random odd-sized room (using isolated RNG)
    let w = (gen.rng.rand(1 .. gen.maxRoomSize - 1) * 2) + 1
    let h = (gen.rng.rand(1 .. gen.maxRoomSize - 1) * 2) + 1
    
    if w >= gen.width - 2 or h >= gen.height - 2 or w < 3 or h < 3:
      continue
    
    let maxX = gen.width - w - 2
    let maxY = gen.height - h - 2
    
    if maxX <= 0 or maxY <= 0:
      continue
    
    # Random position on odd coordinates (using isolated RNG)
    let x = (gen.rng.rand(0 .. maxX div 2) * 2) + 1
    let y = (gen.rng.rand(0 .. maxY div 2) * 2) + 1
    
    let room = rect(x, y, w, h)
    
    if gen.overlaps(room):
      continue
    
    # Add room
    gen.rooms.add(room)
    inc gen.currentRegion
    
    # Carve room
    for ry in y ..< (y + h):
      for rx in x ..< (x + w):
        gen.carve(vec2(rx, ry))
    
    return true
  
  return false

proc startMazeCell*(gen: DungeonGenerator) =
  ## Start a new maze cell at current position
  let pos = vec2(gen.mazeStartX, gen.mazeStartY)
  gen.mazeCells.add(pos)
  inc gen.currentRegion
  gen.carve(pos)

proc growMaze*(gen: DungeonGenerator): bool =
  ## Grow maze using recursive backtracking
  if gen.mazeCells.len == 0:
    return false
  
  while gen.mazeCells.len > 0:
    let cell = gen.mazeCells[^1]
    var openDirs: seq[Direction] = @[]
    
    # Check all 4 directions for carveable cells
    for dir in Direction:
      let checkPos = cell + dir.toVec() * 2
      if gen.inBounds(checkPos) and gen.getCell(checkPos) == ctSolid:
        openDirs.add(dir)
    
    if openDirs.len == 0:
      # Dead end, backtrack
      discard gen.mazeCells.pop()
      continue
    
    # Pick direction (prefer continuing straight, using isolated RNG)
    var dir = openDirs[gen.rng.rand(openDirs.len - 1)]
    if gen.lastMazeDir in openDirs and gen.rng.rand(100) > gen.wigglePercent:
      dir = gen.lastMazeDir
    
    gen.lastMazeDir = dir
    let vec = dir.toVec()
    
    # Carve corridor
    gen.carve(cell + vec)
    gen.carve(cell + vec * 2)
    gen.mazeCells.add(cell + vec * 2)
    
    return true
  
  return false

proc findConnectors*(gen: DungeonGenerator) =
  ## Find all connector cells (walls touching 2+ regions)
  gen.connectors = @[]
  
  for y in 1 ..< gen.height - 1:
    for x in 1 ..< gen.width - 1:
      let pos = vec2(x, y)
      if gen.getCell(pos) == ctSolid:
        let regions = gen.getRegionsTouching(pos)
        if regions.len >= 2:
          gen.connectors.add(pos)
  
  # Shuffle connectors (using isolated RNG)
  shuffle(gen.rng, gen.connectors)
  
  # Start merge from first room
  if gen.rooms.len > 0:
    let pos = gen.rooms[0].center
    gen.mergeCells.add(pos)
    gen.setCell(pos, ctMerged)

proc startMaze*(gen: DungeonGenerator): bool =
  ## Find next maze start position
  if gen.mazeStartY >= gen.height - 1:
    return false
  
  while gen.getCell(vec2(gen.mazeStartX, gen.mazeStartY)) != ctSolid:
    gen.mazeStartX += 2
    if gen.mazeStartX >= gen.width - 1:
      gen.mazeStartX = 1
      gen.mazeStartY += 2
      if gen.mazeStartY >= gen.height - 1:
        # Done with mazes, find connectors
        gen.findConnectors()
        return false
  
  gen.startMazeCell()
  return true

proc mergeRegions*(gen: DungeonGenerator): bool =
  ## Merge regions using connectors
  if gen.connectors.len == 0 or gen.rooms.len == 0:
    return false
  
  var connector: Vec2
  var merged: seq[int]
  var foundConnector = false
  
  # Find a connector touching the merged region
  for i in 0 ..< gen.connectors.len:
    merged = gen.getRegionsTouching(gen.connectors[i])
    
    # Check if any region is marked as merged
    var hasMerged = false
    for region in merged:
      if gen.inBounds(gen.connectors[i]):
        for dir in Direction:
          let checkPos = gen.connectors[i] + dir.toVec()
          if gen.inBounds(checkPos) and gen.getCell(checkPos) == ctMerged:
            hasMerged = true
            break
        if hasMerged:
          break
    
    if hasMerged:
      connector = gen.connectors[i]
      gen.connectors.delete(i)
      foundConnector = true
      break
  
  if not foundConnector:
    return false
  
  # Remove nearby connectors and those that don't add new regions
  var i = 0
  while i < gen.connectors.len:
    let pos = gen.connectors[i]
    
    # Remove if too close
    if dist(pos, connector) < 2:
      gen.connectors.delete(i)
      continue
    
    # Check if this connector adds a new region
    let touchingRegions = gen.getRegionsTouching(pos)
    var hasNewRegion = false
    for region in touchingRegions:
      if region notin merged:
        hasNewRegion = true
        break
    
    if not hasNewRegion:
      # Random extra door (using isolated RNG)
      if gen.rng.rand(50) == 0:
        gen.carve(pos, ctDoor)
      gen.connectors.delete(i)
      continue
    
    inc i
  
  gen.mergeCells.add(connector)
  gen.setCell(connector, ctDoor)
  return true

proc findOpenCells*(gen: DungeonGenerator) =
  ## Find all open cells for dead-end removal
  gen.openCells = @[]
  for y in 1 ..< gen.height - 1:
    for x in 1 ..< gen.width - 1:
      let pos = vec2(x, y)
      if gen.getCell(pos) != ctSolid:
        gen.openCells.add(pos)
  
  # Shuffle using isolated RNG for consistent behavior
  shuffle(gen.rng, gen.openCells)
  gen.deadEndSeek = 0

proc fillMerge*(gen: DungeonGenerator): bool =
  ## Fill merged region using flood fill
  if gen.mergeCells.len == 0:
    return false
  
  while gen.mergeCells.len > 0:
    let pos = gen.mergeCells[0]
    gen.mergeCells.delete(0)
    
    for dir in Direction:
      let checkPos = pos + dir.toVec()
      if gen.inBounds(checkPos):
        let cell = gen.getCell(checkPos)
        if cell != ctSolid and cell != ctMerged and cell != ctDoor:
          gen.setCell(checkPos, ctMerged)
          gen.mergeCells.add(checkPos)
    
    break
  
  if gen.mergeCells.len == 0 and gen.connectors.len == 0:
    gen.findOpenCells()
  
  return true

proc removeDeadEnd*(gen: DungeonGenerator): bool =
  ## Remove dead ends
  if gen.openCells.len == 0:
    return false
  
  if gen.deadEndSeek >= gen.openCells.len:
    gen.deadEndSeek = 0
  
  let start = gen.deadEndSeek
  while gen.openCells.len > 0:
    let pos = gen.openCells[gen.deadEndSeek]
    var exits = 0
    
    # Count exits
    for dir in Direction:
      let checkPos = pos + dir.toVec()
      if gen.getCell(checkPos) != ctSolid:
        inc exits
    
    if exits == 1:
      # Dead end found, fill it
      gen.setCell(pos, ctSolid)
      gen.openCells.delete(gen.deadEndSeek)
      if gen.deadEndSeek >= gen.openCells.len and gen.openCells.len > 0:
        gen.deadEndSeek = 0
      return true
    
    if gen.openCells.len == 0:
      break
    
    gen.deadEndSeek = (gen.deadEndSeek + 1) mod gen.openCells.len
    if gen.deadEndSeek == start:
      gen.openCells = @[]
      break
  
  return false

proc update*(gen: DungeonGenerator): bool =
  ## Run one generation step, returns true if still generating
  if gen.addRoom():
    return true
  if gen.growMaze():
    return true
  if gen.startMaze():
    return true
  if gen.fillMerge():
    return true
  if gen.mergeRegions():
    return true
  if gen.removeDeadEnd():
    return true
  
  gen.isGenerating = false
  return false

proc generate*(gen: DungeonGenerator) =
  ## Generate complete dungeon (blocking)
  while gen.isGenerating and gen.step < gen.maxSteps:
    discard gen.update()
    inc gen.step

proc getCellChar*(cell: CellType): string =
  ## Get character representation of cell type
  case cell
  of ctSolid: "#"
  of ctFloor, ctMerged: "·"
  of ctDoor: "+"

# Export for use in other modules
export CellType, Vec2, Rect, Direction, DungeonGenerator
export newDungeonGenerator, generate, update, getCellChar
export getCell, inBounds
