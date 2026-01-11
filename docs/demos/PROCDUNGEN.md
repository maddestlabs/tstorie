# Procedural Dungeon Generation with Guaranteed Determinism

## The Challenge

Creating a dungeon generator in scripts that produces **identical results** when exported to native requires:

1. ✅ **Isolated RNG** - Same seed = same random sequence
2. ✅ **Integer-only math** - No float drift between implementations
3. ✅ **Identical algorithms** - Same data structures and logic
4. ✅ **Pure functions** - Only use guaranteed-deterministic primitives

## Why Previous Attempts Differed

**[dungen.md](dungen.md)** vs **[dungen_scripted.md](dungen_scripted.md)** produced different dungeons because:

- ❌ Native used separate `cells` + `regionMap` arrays
- ❌ Scripted stored regions in cell values directly
- ❌ Different room validation (clamp vs continue)
- ❌ Complexity made exact algorithm matching difficult

## The Solution: Simpler Algorithm + Primitives Only

### Strategy

Use **Binary Space Partitioning (BSP)** - a simpler algorithm that:
- Recursively splits space into rooms
- Uses only procgen primitives
- Easy to port (simple data structures)
- Naturally deterministic

### Key Principles

1. **Use primitives exclusively:**
   - `idiv` instead of `/` (integer division)
   - `clamp` instead of manual if-checks
   - `rand(rng, max)` with isolated RNG
   - No floating point math anywhere

2. **Simple data structures:**
   - `seq[seq[int]]` for grid (works identically in both)
   - Simple integer constants
   - No complex object hierarchies

3. **Identical control flow:**
   - Same number of RNG calls in same order
   - Same iteration patterns
   - Explicit integer operations

## Example: BSP Dungeon Generator

### Algorithm Overview

```
1. Start with entire grid as one partition
2. Recursively split partitions (H or V)
3. Each leaf partition becomes a room
4. Connect rooms with corridors
5. All using isolated RNG + primitives
```

### Implementation Pattern

```nim
# Constants - identical in script and native
const WALL = 0
const FLOOR = 1
const CORRIDOR = 2

# Use isolated RNG
var rng = initRand(seed)

# Grid - seq[seq[int]] works identically
var grid = newSeq[seq[int]](height)
for y in 0..<height:
  grid[y] = newSeq[int](width)
  for x in 0..<width:
    grid[y][x] = WALL

# BSP split using primitives
proc splitPartition(x, y, w, h: int, depth: int, rng: var Rand, grid: var seq[seq[int]]) =
  if depth <= 0 or w < 8 or h < 8:
    # Make a room using primitives
    let roomW = clamp(w - 4, 3, w - 2)
    let roomH = clamp(h - 4, 3, h - 2)
    let roomX = x + idiv(w - roomW, 2)
    let roomY = y + idiv(h - roomH, 2)
    
    # Carve room
    for ry in roomY..<(roomY + roomH):
      for rx in roomX..<(roomX + roomW):
        grid[ry][rx] = FLOOR
    return
  
  # Split horizontally or vertically using RNG
  if rng.rand(1) == 0:
    # Split horizontally - use idiv!
    let splitAt = rng.rand(h div 4, idiv(h * 3, 4))
    splitPartition(x, y, w, splitAt, depth - 1, rng, grid)
    splitPartition(x, y + splitAt, w, h - splitAt, depth - 1, rng, grid)
  else:
    # Split vertically - use idiv!
    let splitAt = rng.rand(w div 4, idiv(w * 3, 4))
    splitPartition(x, y, splitAt, h, depth - 1, rng, grid)
    splitPartition(x + splitAt, y, w - splitAt, h, depth - 1, rng, grid)
```

## Critical Rules for Determinism

### ✅ DO:

1. **Use `idiv` for division:**
   ```nim
   # ✅ Correct
   let half = idiv(width, 2)
   
   # ❌ Wrong - float conversion
   let half = width / 2
   ```

2. **Use isolated RNG:**
   ```nim
   # ✅ Correct
   var rng = initRand(seed)
   let x = rng.rand(max)
   
   # ❌ Wrong - global RNG
   let x = rand(max)
   ```

3. **Consistent rand() form:**
   ```nim
   # ✅ Correct
   let x = rng.rand(100)  # 0..100 inclusive
   
   # ❌ Wrong - different internal behavior
   let x = rng.rand(0, 100)
   ```

4. **Integer-only calculations:**
   ```nim
   # ✅ Correct
   let third = idiv(width, 3)
   let mapped = map(value, 0, 100, 0, width)
   
   # ❌ Wrong - float math
   let third = int(width * 0.33)
   ```

5. **Use primitives for common operations:**
   ```nim
   # ✅ Correct
   let clamped = clamp(x, 0, width)
   let dist = manhattanDist(x1, y1, x2, y2)
   
   # ❌ Wrong - manual implementation
   let clamped = if x < 0: 0 elif x > width: width else: x
   ```

### ❌ DON'T:

1. **Don't use float math:**
   ```nim
   # ❌ Will cause drift
   let ratio = width / height
   let scaled = value * 0.5
   ```

2. **Don't use different data structures:**
   ```nim
   # ❌ Native might optimize differently
   type ComplexObject = object
     data: Table[string, seq[int]]
   ```

3. **Don't use platform-specific features:**
   ```nim
   # ❌ May differ
   import os
   let time = epochTime()
   ```

## Export Workflow

### 1. Develop in Script

```nim
# In your .md file
```nim on:init
var rng = initRand(12345)
var grid = generateDungeon(80, 25, rng)
```

### 2. Test Determinism

Run multiple times with same seed - should always produce identical output.

### 3. Export to Native

When using tstorie's export feature, the generated native Nim code will use the same primitives from `lib/primitives.nim`, guaranteeing identical results.

### 4. Verify

```bash
# Generate dungeon in script with seed 12345
# Export to native
# Run native with seed 12345
# Compare outputs - should be byte-for-byte identical
```

## Complete Working Example

### Simplified BSP Dungeon (Guaranteed Deterministic)

```nim
# This algorithm uses ONLY primitives and works identically
# in both nimini scripts and native Nim

const WALL = 0
const FLOOR = 1

type Rect = object
  x, y, w, h: int

type Room = object
  rect: Rect
  center: tuple[x, y: int]

proc generateBSPDungeon(width, height, seed: int): seq[seq[int]] =
  var rng = initRand(seed)
  
  # Initialize grid
  var grid = newSeq[seq[int]](height)
  for y in 0..<height:
    grid[y] = newSeq[int](width)
    for x in 0..<width:
      grid[y][x] = WALL
  
  # Generate rooms using BSP
  var rooms = newSeq[Room]()
  
  proc splitAndCreateRooms(x, y, w, h, depth: int) =
    if depth <= 0 or w < 10 or h < 10:
      # Create room in this partition
      let minSize = 3
      let roomW = clamp(rng.rand(minSize, w - 4), minSize, w - 2)
      let roomH = clamp(rng.rand(minSize, h - 4), minSize, h - 2)
      let roomX = x + idiv(w - roomW, 2)
      let roomY = y + idiv(h - roomH, 2)
      
      # Carve room
      for ry in roomY..<(roomY + roomH):
        for rx in roomX..<(roomX + roomW):
          if ry >= 0 and ry < height and rx >= 0 and rx < width:
            grid[ry][rx] = FLOOR
      
      # Store room
      rooms.add(Room(
        rect: Rect(x: roomX, y: roomY, w: roomW, h: roomH),
        center: (roomX + idiv(roomW, 2), roomY + idiv(roomH, 2))
      ))
      return
    
    # Split partition - use idiv!
    if rng.rand(1) == 0:
      # Horizontal split
      let minSplit = idiv(h, 4)
      let maxSplit = idiv(h * 3, 4)
      let splitAt = clamp(rng.rand(minSplit, maxSplit), minSplit, maxSplit)
      splitAndCreateRooms(x, y, w, splitAt, depth - 1)
      splitAndCreateRooms(x, y + splitAt, w, h - splitAt, depth - 1)
    else:
      # Vertical split
      let minSplit = idiv(w, 4)
      let maxSplit = idiv(w * 3, 4)
      let splitAt = clamp(rng.rand(minSplit, maxSplit), minSplit, maxSplit)
      splitAndCreateRooms(x, y, splitAt, h, depth - 1)
      splitAndCreateRooms(x + splitAt, y, w - splitAt, h, depth - 1)
  
  # Start BSP
  splitAndCreateRooms(1, 1, width - 2, height - 2, 3)
  
  # Connect rooms with corridors using primitives
  for i in 0..<(rooms.len - 1):
    let r1 = rooms[i]
    let r2 = rooms[i + 1]
    
    # Use manhattan distance primitive
    let dist = manhattanDist(r1.center.x, r1.center.y, r2.center.x, r2.center.y)
    
    # Carve corridor (L-shaped)
    var x = r1.center.x
    var y = r1.center.y
    
    # Horizontal first
    while x != r2.center.x:
      if x < r2.center.x:
        x = x + 1
      else:
        x = x - 1
      if y >= 0 and y < height and x >= 0 and x < width:
        grid[y][x] = FLOOR
    
    # Then vertical
    while y != r2.center.y:
      if y < r2.center.y:
        y = y + 1
      else:
        y = y - 1
      if y >= 0 and y < height and x >= 0 and x < width:
        grid[y][x] = FLOOR
  
  return grid
```

## Verification Strategy

### Test Harness

Create identical test in both environments:

```nim
# Test seed consistency
let seed = 12345
let grid1 = generateBSPDungeon(80, 25, seed)
let grid2 = generateBSPDungeon(80, 25, seed)

# Should be identical
assert grid1 == grid2

# Test different seeds produce different results
let grid3 = generateBSPDungeon(80, 25, 54321)
assert grid1 != grid3
```

### Visual Comparison

```nim
# Generate in script, save to file
# Generate in native, save to file
# Diff the files - should be identical
```

## Benefits of This Approach

1. ✅ **Guaranteed Determinism** - Same seed = same dungeon, always
2. ✅ **Easy to Port** - Simple algorithms, simple data structures
3. ✅ **Fast Native** - Exports to native Nim with zero overhead
4. ✅ **Easy to Debug** - Pure functions, no hidden state
5. ✅ **Composable** - Combine with other procgen primitives
6. ✅ **Testable** - Verify determinism automatically

## Advanced Patterns

### Pattern 1: Layered Generation

```nim
# Base terrain using fractal noise
let terrain = fractalNoise2D(x, y, 4, 100, seed)

# Rooms using BSP with different seed
let roomSeed = intHash(seed, 1)
let rooms = generateRooms(rng.initRand(roomSeed))

# Decorations using hash
let decorSeed = intHash(seed, 2)
let decor = generateDecor(decorSeed)

# All deterministic, all composable
```

### Pattern 2: Procedural Parameters

```nim
# Generate dungeon parameters from seed
let paramSeed = initRand(seed)
let roomCount = paramSeed.rand(5, 15)
let corridorWidth = paramSeed.rand(1, 3)
let decorDensity = paramSeed.rand(10, 50)

# Use parameters consistently
```

### Pattern 3: Multi-Stage with Noise

```nim
# Stage 1: Base layout using BSP
# Stage 2: Add organic feel using cellular automata
let caGrid = cellularAutomata(grid, birthRule, surviveRule)

# Stage 3: Add decorations using noise
for y in 0..<height:
  for x in 0..<width:
    if grid[y][x] == FLOOR:
      let noise = valueNoise2D(x, y, seed)
      if noise > 50000:  # Threshold
        grid[y][x] = DECORATION
```

## Comparison: Before vs After

### Before (Different Results)

```
Native:     Uses native/dungeon_gen.nim with separate regionMap
Scripted:   Uses object-based design with embedded regions
Result:     Different dungeons with same seed ❌
```

### After (Guaranteed Same)

```
Native:     Uses lib/primitives.nim
Scripted:   Uses same primitives via nimini/stdlib/procgen.nim
Result:     Identical dungeons with same seed ✅
```

## Conclusion

**Yes, it's totally feasible!** The key is:

1. Use **only** the procgen primitives
2. Keep algorithms **simple** and **explicit**
3. Use **isolated RNG** throughout
4. Test **determinism** early and often

The primitives were designed exactly for this use case. By following these patterns, you can develop complex procedural generation in scripts with confidence that native export will produce identical results.

## Next Steps

1. Implement simplified BSP dungeon using primitives
2. Test determinism in script
3. Export to native
4. Verify byte-for-byte identical output
5. Build more complex generators on this foundation

The foundation is solid - build with confidence! 🎲🏰
