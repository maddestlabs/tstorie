---
title: "Bloxes"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "futurism"
useEmoji: "true"
---

# Intro
⠀
Push the box onto the goal marker.
⠀
```lvl
#######
#     #
#  O  #
#  @  #
##    #
##   .#
#######
```
⠀
- [Instructions](#instructions) | [Two Boxes](#two_boxes)

# Two Boxes
⠀
Things get trickier with multiple boxes!
⠀
```lvl
########
#   . .#
# OO   #
#   @  #
########
```
⠀
- [Level 1](#intro) | [The Corridor](#the_corridor)

# The Corridor
⠀
Plan your moves carefully in tight spaces.
⠀
```lvl
########
###    #
### OO #
### .  #
#  .@ ##
#    ###
########
```
⠀
- [Two Boxes](#two_boxes) | [Cross Pattern](#cross_pattern)

# Cross Pattern
⠀
A classic puzzle layout.
⠀
```lvl
#########
####.####
####O####
##  O  ##
# .@O. ##
##  O  ##
####O####
####.####
#########
```
⠀
- [The Corridor](#the_corridor) | [Instructions](#instructions)

# Instructions
⠀
**How to Play:**
⠀
- You are the **☻** smiley face
- Push **■** boxes onto **○** targets
- Boxes on targets turn into **◆** filled diamonds
- You can only push, not pull!
- You can't push two boxes at once
⠀
**Controls:**
⠀
- **WASD** or **Arrow Keys**: Move
- **R**: Restart current level
- **Click links**: Navigate between levels
⠀
**Emoji Mode:** Set `useEmoji: "true"` in front matter to use 🧑📦🎯💎🧱 instead!
⠀
**Goal:** Get all boxes onto the target markers!
⠀
- [Level 1](#intro) | [Level 2](#two_boxes) | [Level 3](#the_corridor) | [Level 4](#cross_pattern)

```nim on:init
# Initialize canvas system with all sections
# Start at section 1 (entrance - section 0 is the code blocks)
initCanvas(0)

# Sokoban game state - using flat arrays
var playerX = 0
var playerY = 0
var boxesX = []
var boxesY = []
var goalsX = []
var goalsY = []
var wallsX = []
var wallsY = []
var levelWidth = 0
var levelHeight = 0
var moveCount = 0
var gameWon = false
var currentLevelData = ""

# Parse level data into game state
proc parseLevel(levelData: string) =
  # Clear existing data
  boxesX = []
  boxesY = []
  goalsX = []
  goalsY = []
  wallsX = []
  wallsY = []
  playerX = 0
  playerY = 0
  moveCount = 0
  gameWon = false
  
  if len(levelData) > 0:
    var lines = splitLines(levelData)
    
    # Parse level
    var y = 0
    levelHeight = len(lines)
    levelWidth = 0
    
    var lineIdx = 0
    while lineIdx < len(lines):
      var line = lines[lineIdx]
      if len(line) > levelWidth:
        levelWidth = len(line)
      
      var x = 0
      var charIdx = 0
      while charIdx < len(line):
        var ch = ""
        ch = ch & line[charIdx]
        if ch == "@":
          playerX = x
          playerY = y
        elif ch == "O":
          boxesX = boxesX + [x]
          boxesY = boxesY + [y]
        elif ch == ".":
          goalsX = goalsX + [x]
          goalsY = goalsY + [y]
        elif ch == "#":
          wallsX = wallsX + [x]
          wallsY = wallsY + [y]
        x = x + 1
        charIdx = charIdx + 1
      y = y + 1
      lineIdx = lineIdx + 1

# Load level from current section
proc loadLevel() =
  parseLevel(currentLevelData)

# Check if position has a wall
proc isWall(x: int, y: int): bool =
  var i = 0
  while i < len(wallsX):
    if wallsX[i] == x and wallsY[i] == y:
      return true
    i = i + 1
  return false

# Check if position has a box
proc hasBox(x: int, y: int): bool =
  var i = 0
  while i < len(boxesX):
    if boxesX[i] == x and boxesY[i] == y:
      return true
    i = i + 1
  return false

# Get box index at position
proc getBoxIndex(x: int, y: int): int =
  var i = 0
  while i < len(boxesX):
    if boxesX[i] == x and boxesY[i] == y:
      return i
    i = i + 1
  return -1

# Check if position is a goal
proc isGoal(x: int, y: int): bool =
  var i = 0
  while i < len(goalsX):
    if goalsX[i] == x and goalsY[i] == y:
      return true
    i = i + 1
  return false

# Check if all boxes are on goals
proc checkWin(): bool =
  var i = 0
  while i < len(boxesX):
    if not isGoal(boxesX[i], boxesY[i]):
      return false
    i = i + 1
  return true

# Try to move player
proc tryMove(dx: int, dy: int): bool =
  if gameWon:
    return false
  
  var newX = playerX + dx
  var newY = playerY + dy
  
  # Check if target is wall
  if isWall(newX, newY):
    return false
  
  # Check if target has box
  if hasBox(newX, newY):
    var boxNewX = newX + dx
    var boxNewY = newY + dy
    
    # Can't push box into wall or another box
    if isWall(boxNewX, boxNewY) or hasBox(boxNewX, boxNewY):
      return false
    
    # Move the box
    var boxIdx = getBoxIndex(newX, newY)
    boxesX[boxIdx] = boxNewX
    boxesY[boxIdx] = boxNewY
  
  # Move player
  playerX = newX
  playerY = newY
  moveCount = moveCount + 1
  
  # Check win condition
  gameWon = checkWin()
  
  return true
```

```nim on:input
# Handle keyboard and mouse input

if event.type == "text":
  var key = event.text
  # WASD for movement
  if key == "w" or key == "W":
    if tryMove(0, -1):
      return true
  elif key == "s" or key == "S":
    if tryMove(0, 1):
      return true
  elif key == "a" or key == "A":
    if tryMove(-1, 0):
      return true
  elif key == "d" or key == "D":
    if tryMove(1, 0):
      return true
  # R to restart level
  elif key == "r" or key == "R":
    parseLevel(currentLevelData)
    return true
  return false

elif event.type == "key":
  if event.action == "press":
    # Pass arrow keys and other special keys to canvas
    var handled = canvasHandleKey(event.keyCode, 0)
    return handled
  return false

elif event.type == "mouse":
  if event.action == "press":
    var handled = canvasHandleMouse(event.x, event.y, event.button, true)
    return handled
  return false

return false
```

```nim on:render
# Check if current section has a level code block
var levelBlocks = getCurrentSectionCodeBlocks("lvl")
if len(levelBlocks) > 0:
  # Load and parse level if it changed
  var idx = getCurrentSectionIndex()
  var newLevelData = getCodeBlockText(idx, "lvl")
  
  if newLevelData != currentLevelData or levelWidth == 0:
    currentLevelData = newLevelData
    parseLevel(currentLevelData)
  
  # Render game to content buffer
  contentClear()
  
  # Choose character set based on front matter
  var useWideChars = false
  if useEmoji == "true":
    useWideChars = true
  
  var y = 0
  while y < levelHeight:
    var row = ""
    var x = 0
    while x < levelWidth:
      var cell = " "
      if useWideChars:
        cell = "　"  # Double-width space (U+3000 ideographic space)
      
      if isWall(x, y):
        if useWideChars:
          cell = "⬜"
        else:
          cell = "█"
      elif playerX == x and playerY == y:
        if useWideChars:
          cell = "😶"
        else:
          cell = "☻"
      elif hasBox(x, y):
        if isGoal(x, y):
          if useWideChars:
            cell = "🈺"
          else:
            cell = "◆"
        else:
          if useWideChars:
            cell = "🔲"
          else:
            cell = "■"
      elif isGoal(x, y):
        if useWideChars:
          cell = "🔳"
        else:
          cell = "○"
      
      row = row & cell
      x = x + 1
    
    contentWrite(row)
    y = y + 1
  
  # Show status
  contentWrite("⠀")
  var numBoxes = len(boxesX)
  var numGoals = len(goalsX)
  var status = "Moves: " & $moveCount & " | Boxes: " & $numBoxes & "/" & $numGoals
  if gameWon:
    status = status & " | ★ LEVEL COMPLETE! ★"
  contentWrite(status)
  contentWrite("WASD: Move | R: Restart")

# Render canvas
canvasRender()
```

```nim on:update
canvasUpdate()
```