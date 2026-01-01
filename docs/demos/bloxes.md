---
title: "Bloxes"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "outrun"
useEmoji: "true"
emoji: "⬛⬜🔲😶🟨❎"
---

# Intro
⠀
```lvl
#####
#   #
# O #
# . #
# @ #
#####
```
⠀
- [Next Level](#two_boxes) | [How to Play](#instructions)

# Two Boxes
⠀
```lvl
#######
#  .  #
# O O #
#  .  #
#  @  #
#######
```
⠀
- [Next Level](#the_corridor) | [How to Play](#instructions)

# The Corridor
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

- [Next Level](#cross_pattern) | [How to Play](#instructions)

# Cross Pattern
⠀
```lvl
#########
####.####
### O####
##  O  ##
# .@O.  #
## .O   #
####O ###
####.####
#########
```

- [Restart](#intro) | [How to Play](#instructions)

# Instructions
⠀
**How to Play:**
⠀
```nim on:enter
contentClear()
contentWrite("-" & playerChar & " You are the player")
contentWrite("-" & boxChar & " Push bloxes onto goals")
contentWrite("-" & goalChar & " Goal markers")
contentWrite("-" & boxOnGoalChar & " Box on goal")
contentWrite("-" & wallChar & " Walls")
```
⠀
**Rules:**
- You can only push bloxes, not pull them
- You cannot push two bloxes at once
- Get all bloxes onto the goal markers to win!
⠀
- [Play Level 1](#intro)

```nim on:init
# Initialize canvas system
initCanvas(0)

# Game state
var playerX = 0
var playerY = 0
var boxes = []  # Each box is [x, y]
var goals = []  # Each goal is [x, y]
var walls = []  # Each wall is [x, y]
var levelWidth = 0
var levelHeight = 0
var moveCount = 0
var gameWon = false
var nextMoveDX = 0
var nextMoveDY = 0
var currentLevelData = ""

# Emoji characters from front matter
var emptyChar = "⬛"
var wallChar = "⬜"
var boxChar = "🔲"
var playerChar = "😶"
var goalChar = "🟨"
var boxOnGoalChar = "❎"

# Load emoji from front matter if defined
if len(emoji) > 0:
  # Parse emoji string (each emoji can be multiple bytes)
  var emojiList = []
  var i = 0
  while i < len(emoji):
    var b = ord(emoji[i])
    
    var charLen = 1
    # Detect UTF-8 character length based on first byte
    if b < 128:
      charLen = 1
    elif b >= 192 and b < 224:
      charLen = 2
    elif b >= 224 and b < 240:
      charLen = 3
    elif b >= 240:
      charLen = 4
    
    var endIdx = i + charLen
    if endIdx > len(emoji):
      endIdx = len(emoji)
    
    var ch = ""
    var j = i
    while j < endIdx:
      ch = ch & emoji[j]
      j = j + 1
    
    emojiList = emojiList + [ch]
    i = endIdx
  
  # Assign emoji to variables (order: empty, wall, box, player, goal, boxOnGoal)
  if len(emojiList) > 0:
    emptyChar = emojiList[0]
  if len(emojiList) > 1:
    wallChar = emojiList[1]
  if len(emojiList) > 2:
    boxChar = emojiList[2]
  if len(emojiList) > 3:
    playerChar = emojiList[3]
  if len(emojiList) > 4:
    goalChar = emojiList[4]
  if len(emojiList) > 5:
    boxOnGoalChar = emojiList[5]

# Parse level from string
proc parseLevel(levelData: string) =
  boxes = []
  goals = []
  walls = []
  playerX = 0
  playerY = 0
  moveCount = 0
  gameWon = false
  
  print("Parsing new level...")
  
  if len(levelData) > 0:
    var lines = splitLines(levelData)
    levelHeight = len(lines)
    levelWidth = 0
    
    var y = 0
    while y < len(lines):
      var line = lines[y]
      if len(line) > levelWidth:
        levelWidth = len(line)
      
      var x = 0
      while x < len(line):
        var ch = ""
        if x < len(line):
          ch = ch & line[x]
        
        if ch == "@":
          playerX = x
          playerY = y
        elif ch == "O":
          boxes = boxes + [[x, y]]
        elif ch == ".":
          goals = goals + [[x, y]]
        elif ch == "#":
          walls = walls + [[x, y]]
        
        x = x + 1
      y = y + 1

# Check if position has a wall
proc hasWall(x: int, y: int): bool =
  if x < 0 or y < 0 or x >= levelWidth or y >= levelHeight:
    return true
  var i = 0
  while i < len(walls):
    if walls[i][0] == x and walls[i][1] == y:
      return true
    i = i + 1
  return false

# Check if position has a box
proc hasBox(x: int, y: int): bool =
  # Bounds check first
  if x < 0 or y < 0 or x >= levelWidth or y >= levelHeight:
    return false
  var i = 0
  while i < len(boxes):
    if boxes[i][0] == x and boxes[i][1] == y:
      return true
    i = i + 1
  return false

# Get box index at position
proc getBoxIndex(x: int, y: int): int =
  var i = 0
  while i < len(boxes):
    if boxes[i][0] == x and boxes[i][1] == y:
      return i
    i = i + 1
  return -1

# Check if position is a goal
proc isGoal(x: int, y: int): bool =
  var i = 0
  while i < len(goals):
    if goals[i][0] == x and goals[i][1] == y:
      return true
    i = i + 1
  return false

# Check if all boxes are on goals
proc checkWin(): bool =
  var i = 0
  while i < len(boxes):
    if not isGoal(boxes[i][0], boxes[i][1]):
      return false
    i = i + 1
  return true

# Try to move player
proc tryMove(dx: int, dy: int): bool =
  if gameWon:
    return false
  
  var newX = playerX + dx
  var newY = playerY + dy
  
  # Check wall collision
  if hasWall(newX, newY):
    return false
  
  # Check box collision
  if hasBox(newX, newY):
    var boxNewX = newX + dx
    var boxNewY = newY + dy
    
    # Can't push box into wall or another box
    if hasWall(boxNewX, boxNewY) or hasBox(boxNewX, boxNewY):
      return false
    
    # Move the box
    var boxIdx = getBoxIndex(newX, newY)
    boxes[boxIdx] = [boxNewX, boxNewY]
  
  # Move player
  playerX = newX
  playerY = newY
  moveCount = moveCount + 1
  
  # Check win
  gameWon = checkWin()
  
  return true

# Calculate simple pathfinding (BFS) to target - returns true and sets nextMoveDX/nextMoveDY
proc findPath(targetX: int, targetY: int): bool =
  if gameWon:
    return false
  
  # BFS to find shortest path
  var queueX = []
  var queueY = []
  var queueFirstMoveX = []
  var queueFirstMoveY = []
  var visited = []
  
  queueX = queueX + [playerX]
  queueY = queueY + [playerY]
  queueFirstMoveX = queueFirstMoveX + [0]
  queueFirstMoveY = queueFirstMoveY + [0]
  
  while len(queueX) > 0:
    # Dequeue first element
    var cx = queueX[0]
    var cy = queueY[0]
    var firstMoveX = queueFirstMoveX[0]
    var firstMoveY = queueFirstMoveY[0]
    
    var newQueueX = []
    var newQueueY = []
    var newFirstMoveX = []
    var newFirstMoveY = []
    var i = 1
    while i < len(queueX):
      newQueueX = newQueueX + [queueX[i]]
      newQueueY = newQueueY + [queueY[i]]
      newFirstMoveX = newFirstMoveX + [queueFirstMoveX[i]]
      newFirstMoveY = newFirstMoveY + [queueFirstMoveY[i]]
      i = i + 1
    queueX = newQueueX
    queueY = newQueueY
    queueFirstMoveX = newFirstMoveX
    queueFirstMoveY = newFirstMoveY
    
    # Check if reached target
    if cx == targetX and cy == targetY:
      nextMoveDX = firstMoveX
      nextMoveDY = firstMoveY
      return true
    
    # Check if visited
    var visitKey = $cx & "," & $cy
    var alreadyVisited = false
    var j = 0
    while j < len(visited):
      if visited[j] == visitKey:
        alreadyVisited = true
      j = j + 1
    
    if not alreadyVisited:
      visited = visited + [visitKey]
      
      # Try all 4 directions: up, down, left, right
      # Up
      var nx = cx + 0
      var ny = cy + -1
      if not hasWall(nx, ny) and not hasBox(nx, ny):
        var moveX = 0
        var moveY = -1
        if firstMoveX == 0 and firstMoveY == 0:
          moveX = 0
          moveY = -1
        else:
          moveX = firstMoveX
          moveY = firstMoveY
        queueX = queueX + [nx]
        queueY = queueY + [ny]
        queueFirstMoveX = queueFirstMoveX + [moveX]
        queueFirstMoveY = queueFirstMoveY + [moveY]
      
      # Down
      nx = cx + 0
      ny = cy + 1
      if not hasWall(nx, ny) and not hasBox(nx, ny):
        var moveX = 0
        var moveY = 1
        if firstMoveX == 0 and firstMoveY == 0:
          moveX = 0
          moveY = 1
        else:
          moveX = firstMoveX
          moveY = firstMoveY
        queueX = queueX + [nx]
        queueY = queueY + [ny]
        queueFirstMoveX = queueFirstMoveX + [moveX]
        queueFirstMoveY = queueFirstMoveY + [moveY]
      
      # Left
      nx = cx + -1
      ny = cy + 0
      if not hasWall(nx, ny) and not hasBox(nx, ny):
        var moveX = -1
        var moveY = 0
        if firstMoveX == 0 and firstMoveY == 0:
          moveX = -1
          moveY = 0
        else:
          moveX = firstMoveX
          moveY = firstMoveY
        queueX = queueX + [nx]
        queueY = queueY + [ny]
        queueFirstMoveX = queueFirstMoveX + [moveX]
        queueFirstMoveY = queueFirstMoveY + [moveY]
      
      # Right
      nx = cx + 1
      ny = cy + 0
      if not hasWall(nx, ny) and not hasBox(nx, ny):
        var moveX = 1
        var moveY = 0
        if firstMoveX == 0 and firstMoveY == 0:
          moveX = 1
          moveY = 0
        else:
          moveX = firstMoveX
          moveY = firstMoveY
        queueX = queueX + [nx]
        queueY = queueY + [ny]
        queueFirstMoveX = queueFirstMoveX + [moveX]
        queueFirstMoveY = queueFirstMoveY + [moveY]
  
  nextMoveDX = 0
  nextMoveDY = 0
  return false

# Handle mouse/touch click to move player
proc handleClick(clickX: int, clickY: int): bool =
  if gameWon:
    return false
  
  print("handleClick called with: " & $clickX & ", " & $clickY)
  print("Level size: " & $levelWidth & " x " & $levelHeight)
  
  # Coordinates are already buffer-relative!
  # Each emoji takes 2 character cells width
  var gridX = clickX / 2
  var gridY = clickY
  
  print("Converted to grid: " & $gridX & ", " & $gridY)
  print("Valid range: 0-" & $(levelWidth-1) & ", 0-" & $(levelHeight-1))
  
  # Validate grid position
  if gridX < 0 or gridX >= levelWidth or gridY < 0 or gridY >= levelHeight:
    return false
  
  # If clicking on current player position, do nothing
  if gridX == playerX and gridY == playerY:
    return false
  
  # If clicking on a wall, do nothing
  if hasWall(gridX, gridY):
    return false
  
  # If clicking on a box, try to push it
  if hasBox(gridX, gridY):
    # Check if player is adjacent to the box
    var dx = gridX - playerX
    var dy = gridY - playerY
    var isAdjacent = false
    var pushDirX = 0
    var pushDirY = 0
    
    if dx == 0 and dy == 1:
      isAdjacent = true
      pushDirX = 0
      pushDirY = 1
    elif dx == 0 and dy == -1:
      isAdjacent = true
      pushDirX = 0
      pushDirY = -1
    elif dy == 0 and dx == 1:
      isAdjacent = true
      pushDirX = 1
      pushDirY = 0
    elif dy == 0 and dx == -1:
      isAdjacent = true
      pushDirX = -1
      pushDirY = 0
    
    if isAdjacent:
      # Try to push the box
      return tryMove(pushDirX, pushDirY)
    else:
      # Player needs to move adjacent to box first
      # Try each adjacent position around the box
      var bestPath = ""
      var bestPathLen = 999999
      
      # Check position to the left of box
      var adjX = gridX - 1
      var adjY = gridY
      if not hasWall(adjX, adjY) and not hasBox(adjX, adjY):
        var path = findPath(adjX, adjY)
        if len(path) > 0 and len(path) < bestPathLen:
          bestPathLen = len(path)
          bestPath = path
      
      # Check position to the right of box
      adjX = gridX + 1
      adjY = gridY
      if not hasWall(adjX, adjY) and not hasBox(adjX, adjY):
        var path = findPath(adjX, adjY)
        if len(path) > 0 and len(path) < bestPathLen:
          bestPathLen = len(path)
          bestPath = path
      
      # Check position above box
      adjX = gridX
      adjY = gridY - 1
      if not hasWall(adjX, adjY) and not hasBox(adjX, adjY):
        if findPath(adjX, adjY):
          return tryMove(nextMoveDX, nextMoveDY)
      
      # Check position below box
      adjX = gridX
      adjY = gridY + 1
      if not hasWall(adjX, adjY) and not hasBox(adjX, adjY):
        if findPath(adjX, adjY):
          return tryMove(nextMoveDX, nextMoveDY)
      
      return false
  
  # Find path to clicked position and move player directly there
  if findPath(gridX, gridY):
    print("Path found! Moving player from (" & $playerX & "," & $playerY & ") to (" & $gridX & "," & $gridY & ")")
    # Move player directly to the clicked position
    playerX = gridX
    playerY = gridY
    moveCount = moveCount + 1
    gameWon = checkWin()
    return true
  
  return false
```

```nim on:input
# Handle input
if event.type == "mouse":
  # Extract coordinates to local variables
  var mouseX = event.x
  var mouseY = event.y
  var mouseAction = event.action
  
  print("Mouse event detected!")
  print("mouseX: " & $mouseX & ", mouseY: " & $mouseY)
  print("mouseAction: " & $mouseAction)
  
  if mouseAction == "press":
    print("Mouse press at: " & $mouseX & ", " & $mouseY)
    
    # Check if we're on a level section (has lvl code blocks)
    var levelBlocks = getCurrentSectionCodeBlocks("lvl")
    
    if len(levelBlocks) > 0:
      # Method 1: Use buffer-relative coordinates (automatically calculated by tstorie)
      # bufferX/bufferY are relative to the content buffer, perfect for games!
      if event.bufferX >= 0 and event.bufferY >= 0:
        var handled = handleClick(event.bufferX, event.bufferY)
        if handled:
          return true
      
      # Method 2 (alternative): Use the eventToGrid helper for even simpler code:
      # var grid = eventToGrid(event, 2, 1)  # cellWidth=2 (emoji width), cellHeight=1
      # if grid.valid:
      #   handleClick(grid.x, grid.y)
      
      # Fallback: try handling as canvas navigation
      var handled = canvasHandleMouse(mouseX, mouseY, 0, true)
      return handled
    
    # If not handled by game, let canvas handle link navigation
    var handled = canvasHandleMouse(mouseX, mouseY, 0, true)
    return handled
  return true

elif event.type == "text":
  var key = event.text
  
  # Movement
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
  
  # Restart
  elif key == "r" or key == "R":
    parseLevel(currentLevelData)
    return true
  
  return false

elif event.type == "key":
  if event.action == "press":
    var handled = canvasHandleKey(event.keyCode, 0)
    return handled
  return false

return false
```

```nim on:render
# Check if current section has level data
var levelBlocks = getCurrentSectionCodeBlocks("lvl")
if len(levelBlocks) > 0:
  # Load level if changed
  var idx = getCurrentSectionIndex()
  var newLevelData = getCodeBlockText(idx, "lvl")
  
  # Check against stored level or treat empty as new
  if levelWidth == 0:
    # First time loading - parse immediately
    currentLevelData = newLevelData
    parseLevel(currentLevelData)
  elif newLevelData != currentLevelData:
    # Level changed
    currentLevelData = newLevelData
    parseLevel(currentLevelData)
  
  # Render game
  contentClear()
  
  # Render each row
  var y = 0
  while y < levelHeight:
    var row = ""
    var x = 0
    while x < levelWidth:
      var cell = emptyChar
      
      # Check what's at this position
      if hasWall(x, y):
        cell = wallChar
      elif playerX == x and playerY == y:
        cell = playerChar
      elif hasBox(x, y):
        if isGoal(x, y):
          cell = boxOnGoalChar
        else:
          cell = boxChar
      elif isGoal(x, y):
        cell = goalChar
      
      row = row & cell
      x = x + 1
    
    contentWrite(row)
    y = y + 1
  
  # Status line
  contentWrite("⠀")
  var status = "Moves: " & $moveCount
  if gameWon:
    status = status & "　★ LEVEL COMPLETE! ★"
  contentWrite(status)
  contentWrite("WASD: Move | R: Restart")

# Render canvas
canvasRender()
```

```nim on:update
canvasUpdate()
```
