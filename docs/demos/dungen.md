---
title: "Dungeon Generator - Native Edition"
author: "High-performance procedural dungeon using native Nim"
theme: "coffee"
shader: grid+grid2x1+dirt+paper+lightsway+lightvignette
fontsize: 24
---

# Dungeon Generator

Press **R** to regenerate with a new random seed.

**Performance:** Native Nim implementation (~100x faster than interpreted)

```nim on:init
# Global state
var dungeon # Will hold pointer to DungeonGenerator
var width = termWidth - 1
var height = termHeight - 5
var seedValue = 0

# Initialize dungeon
proc initDungeon() =
  # Check if seed was provided via parameter (URL or command-line)
  var hasSeedParam = hasParam("seed")
  var seedParam = getParam("seed")
  
  if hasSeedParam == true and len(seedParam) > 0:
    seedValue = getParamInt("seed", 0)
    if seedValue <= 0:
      seedValue = rand(0, 999999)
  else:
    seedValue = rand(0, 999999)
  
  # Create native dungeon generator
  dungeon = newDungeonGenerator(width, height, seedValue)
  
  # Generate complete dungeon instantly (native is FAST!)
  generate(dungeon)

# Initialize on startup
initDungeon()
```

```nim on:update
width = termWidth - 1
height = termHeight - 5
```

```nim on:render
# Draw the dungeon
clear()

# Render the dungeon
for y in 0..<height:
  for x in 0..<width:
    var cellType = getCellAt(dungeon, x, y)
    var ch = dungeonGetCellChar(cellType)
    draw(0, x, y, ch)

# Show status
var steps = getStep(dungeon)
draw(0, 0, height + 1, "Seed: " & str(seedValue) & "  Steps: " & str(steps) & "  (Native Nim - Instant!)")
draw(0, 0, height + 2, "Press R or click/touch anywhere to regenerate")
```

```nim on:input
# Handle keyboard input
if event.type == "text":
  var key = event.text
  if key == "r" or key == "R":
    initDungeon()
    return true
  return false

# Handle mouse/touch input
elif event.type == "mouse":
  if event.action == "press":
    initDungeon()
    return true

return false
```
