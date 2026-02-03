---
title: "Stone Garden"
alttitle: "石庭/Sekitei"
author: "Maddest Labs"
chars: "岩僧石座固僧・苔霧松竹梅"
doubleWidth: true
theme: "stonegarden"
shaders: "paper+gradualblur+clouds"
font: "LXGW+WenKai+Mono+TC"
---

# Stone Garden⠀
```txt
; Level 1 - Getting started
#######
#     ####
#        #
# @  $ . #
#        #
##########
;
; 2
##########
##@#######
# $   ####
# ..$$ ###
#  $.  ###
#. #    ##
##########
;
; 3
##########
#### ##  #
##  .    #
### $    #
####  .$ #
  ##.@   #
  ##    .#
  ## $$ ##
  ##     #
  ########
;
; 4
##########
##########
##########
# ##### ##
#@.$  . .#
# $ $    #
#   ## . #
# $#######
#  #######
##########
;
; 5
##########
##   #####
### ######
## .#. ###
## .   $@#
#   $  ###
# $$  ####
#. #  ####
####  ####
##########
;
; 6
##########
#     ..##
#  $  .  #
#        #
####### ##
######  ##
######$$##
#### $ . #
####   @##
##########
;
; 7
##########
#    .  @#
#   $  . #
# #####  #
# $    $ #
# .$ # . #
#   ######
##########
##########
##########
;
; 8
##########
##### #. #
#### $   #
####@$  .#
###### $ #
#######  #
####  .  #
#### $  .#
#####    #
##########
;
; 9
##########
####     #
####  @$ #
#### $.  #
###.  $. #
####   $ #
#### .####
##########
##########
##########
;
; 10
##########
##########
####### ##
###      #
###$ . @ #
# .   .$ #
#  .  $  #
#     $  #
#    ### #
##########
;
; 11
##########
##      .#
## $.# $ #
##   #   #
##     $.#
###      #
### ######
## $ #####
## @.#####
##########
;
; 12
##########
##  # ####
#   $ .  #
#   #@$  #
### ## .##
#.$  $   #
#    .   #
##########
##########
##########
;
; 13
##########
#   @.   #
# $      #
# ##  # ##
# $ .#####
# $$. ####
#    #####
#.########
# ########
##########
;
; 14
##########
##########
# ########
#   ######
#.$@  $  #
#        #
##### $$ #
##### .. #
######.  #
##########
;
; 15
##########
#        #
#.$  $ $ #
#    #. @#
#.  $. # #
##     ###
##########
##########
##########
##########
;
; 16
##########
####### ##
######   #
#. $  $ ##
#       .#
#   # $ ##
# $.  . @#
#      ###
##########
##########
;
; 17
##########
##########
##########
#      ###
#.$$ #####
# #.  ####
#   .@####
#.$ $ ####
#  #######
##########
;
; 18
##########
##########
##########
##  ######
## $ #####
##   #  ##
## .## $##
##  . $  #
#  $. .@ #
##########
;
; 19
##########
#     .###
#   $ $###
# $      #
# . .$  @#
##### .###
##########
##########
##########
##########
;
; 20
##########
######@$.#
######.  #
#####  ###
##### $ ##
###### ###
#####  $ #
### .  $ #
#### .   #
##########
;
; 21
##########
#       .#
##  $ $$ #
#### #   #
# $   . .#
# #.  # ##
#@########
# ########
# ########
##########
;
; 22
##########
##########
#  #######
#  #######
#..#######
#  # #####
#  @$..###
#$ $$ ####
#      ###
##########
;
; 23
##########
####   .##
#### $.$##
#####.$ ##
######   #
####### ##
####     #
##### $  #
##@.     #
##########
;
; 24
##########
######.@##
#####  .##
##### $.##
####    ##
###### ###
### # $###
# $ $ .###
#      ###
##########
;;
; 25
##########
# @      #
#.    $$ #
#     #  #
#######. #
######## #
#######. #
##### #$ #
#    . $ #
##########
;
; 26
##########
#     @ .#
#  # ..###
# $##$$###
#  ##    #
# $  .   #
#   ##   #
##########
##########
##########
;
; 27
##########
#  . #####
# $.  ## #
#  $$    #
# .  #   #
#    #####
#.$ @#####
#    #####
##  ######
##########
;
; 28
##########
####### ##
##  . . ##
# $  $   #
#@$     .#
#######  #
######  .#
###### $ #
######   #
##########
;
; 29
##########
######## #
## @##.# #
##  ##   #
##  .#   #
##  .#  .#
##  ## $ #
### $ $$ #
###      #
##########
;
; 30
##########
######   #
#####@$ ##
#####   ##
####  .$ #
####     #
#### . $ #
####. .$ #
####    ##
##########
```

```nim on:init
# Parse character set from front matter
var wallChar = "#"
var boxChar = "$"
var playerChar = "@"
var goalChar = "."
var boxOnGoalChar = "*"
var playerOnGoalChar = "+"
var floorChar = " "
var outsideChars = ["~", ".", ":", "·", "∙"]  # Array of 5 outside chars for random selection

if len(chars) >= 8:
  # Parse chars string with proper UTF-8 multi-byte character handling
  var charsList = []
  var i = 0
  while i < len(chars):
    var b = ord(chars[i])
    
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
    if endIdx > len(chars):
      endIdx = len(chars)
    
    var ch = ""
    var j = i
    while j < endIdx:
      ch = ch & chars[j]
      j = j + 1
    
    charsList = charsList + [ch]
    i = endIdx
  
  # Assign characters (order: wall, player, box, goal, boxOnGoal, playerOnGoal, floor, outside1-5)
  if len(charsList) > 0:
    wallChar = charsList[0]
  if len(charsList) > 1:
    playerChar = charsList[1]
  if len(charsList) > 2:
    boxChar = charsList[2]
  if len(charsList) > 3:
    goalChar = charsList[3]
  if len(charsList) > 4:
    boxOnGoalChar = charsList[4]
  if len(charsList) > 5:
    playerOnGoalChar = charsList[5]
  if len(charsList) > 6:
    floorChar = charsList[6]
  # Parse 5 outside characters (indices 7-11)
  if len(charsList) > 7:
    var tempOutsideChars = []
    var oc = 7
    while oc < len(charsList) and oc < 12:
      tempOutsideChars = tempOutsideChars + [charsList[oc]]
      oc = oc + 1
    # Only replace if we got at least one character
    if len(tempOutsideChars) > 0:
      outsideChars = tempOutsideChars
      # If we got fewer than 5, duplicate the last one
      while len(outsideChars) < 5:
        outsideChars = outsideChars + [outsideChars[len(outsideChars) - 1]]

var charWidth = 1
# Calculate character width for rendering
if doubleWidth:
  charWidth = 2

# Random outside character selection
proc getRandomOutsideChar(x: int, y: int, offset: int): string =
  # Hash-based wave pattern - pseudo-random with wave-like structure
  var hash = (x * 73 + y * 37) mod 997  # Prime-based hash for randomness
  var wave = (x + y * 2) div 3  # Gentle diagonal wave component
  var idx = (hash + wave + offset) mod len(outsideChars)
  return outsideChars[idx]

# Get style objects - use theme defaults, unless user defines custom styles
# Available theme styles: default, accent1, accent2, accent3, border, info, dim, etc.
var styleWall = getStyle("bright")
var stylePlayer = getStyle("accent1")
var styleBox = getStyle("dim")
var styleGoal = getStyle("accent2")
var styleBoxGoal = getStyle("accent2")
var stylePlayerGoal = getStyle("accent2")
var styleFloor = brightness(getStyle("default"), 0.3)
var styleOutside = brightness(getStyle("default"), 0.3)

# Swap foreground and background colors for styleWall
var temp = styleWall.fg
styleWall.fg = styleWall.bg
styleWall.bg = temp

#temp = styleBox.fg
#styleBox.fg = styleBox.bg
#styleBox.bg = temp

# Apply inverse for boxGoal and playerGoal (defaults to true)
styleBoxGoal.inverse = true
stylePlayerGoal.inverse = true

# Game state
var playerX = 0
var playerY = 0
var boxes = []  # Each box is [x, y]
var goals = []  # Each goal is [x, y]
var walls = []  # Each wall is [x, y]
var reachableArea = []  # Cells reachable from player start [x, y]
var levelWidth = 0
var levelHeight = 0
var moveCount = 0
var gameWon = false
var currentLevelData = ""
var frameCount = 0  # Animation frame counter

# Level pack state
var levelPack = []  # Array of level strings
var currentLevelIndex = 0
var isLevelPack = false

# Mouse/input state
var nextMoveDX = 0
var nextMoveDY = 0

# Check if cell is in reachable area
proc isReachable(x: int, y: int): bool =
  var i = 0
  while i < len(reachableArea):
    if reachableArea[i][0] == x and reachableArea[i][1] == y:
      return true
    i = i + 1
  return false

# Parse level from string (standard Sokoban format)
proc parseLevel(levelData: string) =
  boxes = []
  goals = []
  walls = []
  reachableArea = []
  playerX = 0
  playerY = 0
  moveCount = 0
  gameWon = false
  
  if len(levelData) == 0:
    return
  
  # Split by newline
  var lines = split(levelData, "\n")
  
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
      
      if ch == "@" or ch == playerChar:
        playerX = x
        playerY = y
      elif ch == "+" or ch == playerOnGoalChar:
        playerX = x
        playerY = y
        goals = goals + [[x, y]]
      elif ch == "$" or ch == boxChar:
        boxes = boxes + [[x, y]]
      elif ch == "*" or ch == boxOnGoalChar:
        boxes = boxes + [[x, y]]
        goals = goals + [[x, y]]
      elif ch == "." or ch == goalChar:
        goals = goals + [[x, y]]
      elif ch == "#" or ch == wallChar:
        walls = walls + [[x, y]]
      
      x = x + 1
    y = y + 1
  
  # Flood-fill from player start to find all reachable cells
  # This helps identify "outside" areas in irregular maps
  var floodQueue = [[playerX, playerY]]
  reachableArea = [[playerX, playerY]]
  
  while len(floodQueue) > 0:
    var current = floodQueue[0]
    var cx = current[0]
    var cy = current[1]
    
    # Remove from queue
    var newQueue = []
    var i = 1
    while i < len(floodQueue):
      newQueue = newQueue + [floodQueue[i]]
      i = i + 1
    floodQueue = newQueue
    
    # Check all 4 directions
    var directions = [[0, -1], [0, 1], [-1, 0], [1, 0]]
    var d = 0
    while d < 4:
      var nx = cx + directions[d][0]
      var ny = cy + directions[d][1]
      
      # If valid position, not a wall, and not already visited
      if nx >= 0 and ny >= 0 and nx < levelWidth and ny < levelHeight:
        if not hasWall(nx, ny) and not isReachable(nx, ny):
          reachableArea = reachableArea + [[nx, ny]]
          floodQueue = floodQueue + [[nx, ny]]
      
      d = d + 1

# Parse level pack (semicolon-separated format)
proc parseLevelPack(packData: string): seq[string] =
  var levels = []
  var currentLevel = []
  var lines = split(packData, "\n")
  
  var j = 0
  while j < len(lines):
    var line = lines[j]
    var trimmed = strip(line)
    
    # Skip comments and empty lines before level data
    if len(trimmed) == 0 or (len(trimmed) > 0 and trimmed[0] == ';'):
      # If we have accumulated level data, this marks the end
      if len(currentLevel) > 0:
        levels = levels + [join(currentLevel, "\n")]
        currentLevel = []
      j = j + 1
    else:
      # This is level data
      currentLevel = currentLevel + [line]
      j = j + 1
  
  # Add final level if any
  if len(currentLevel) > 0:
    levels = levels + [join(currentLevel, "\n")]
  
  return levels

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

# Simple pathfinding (BFS) to target
proc findPath(targetX: int, targetY: int): bool =
  if gameWon:
    return false
  
  # BFS queue
  var queueX = [playerX]
  var queueY = [playerY]
  var queueFirstMoveX = [0]
  var queueFirstMoveY = [0]
  var visited = []
  
  while len(queueX) > 0:
    # Dequeue
    var cx = queueX[0]
    var cy = queueY[0]
    var firstMoveX = queueFirstMoveX[0]
    var firstMoveY = queueFirstMoveY[0]
    
    var i = 1
    var newQX = []
    var newQY = []
    var newFMX = []
    var newFMY = []
    while i < len(queueX):
      newQX = newQX + [queueX[i]]
      newQY = newQY + [queueY[i]]
      newFMX = newFMX + [queueFirstMoveX[i]]
      newFMY = newFMY + [queueFirstMoveY[i]]
      i = i + 1
    queueX = newQX
    queueY = newQY
    queueFirstMoveX = newFMX
    queueFirstMoveY = newFMY
    
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
      
      # Try all 4 directions
      var directions = [[0, -1], [0, 1], [-1, 0], [1, 0]]
      var d = 0
      while d < 4:
        var nx = cx + directions[d][0]
        var ny = cy + directions[d][1]
        
        if not hasWall(nx, ny) and not hasBox(nx, ny):
          var moveX = directions[d][0]
          var moveY = directions[d][1]
          if firstMoveX == 0 and firstMoveY == 0:
            queueX = queueX + [nx]
            queueY = queueY + [ny]
            queueFirstMoveX = queueFirstMoveX + [moveX]
            queueFirstMoveY = queueFirstMoveY + [moveY]
          else:
            queueX = queueX + [nx]
            queueY = queueY + [ny]
            queueFirstMoveX = queueFirstMoveX + [firstMoveX]
            queueFirstMoveY = queueFirstMoveY + [firstMoveY]
        d = d + 1
  
  nextMoveDX = 0
  nextMoveDY = 0
  return false

# Handle mouse click for movement
proc handleClick(gridX: int, gridY: int): bool =
  if gameWon:
    return false
  
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
    var dx = gridX - playerX
    var dy = gridY - playerY
    
    # Check if adjacent
    if (dx == 0 and (dy == 1 or dy == -1)) or (dy == 0 and (dx == 1 or dx == -1)):
      return tryMove(dx, dy)
    else:
      # Try to move adjacent to box first
      var adjacent = [[gridX - 1, gridY], [gridX + 1, gridY], [gridX, gridY - 1], [gridX, gridY + 1]]
      var a = 0
      while a < 4:
        var adjX = adjacent[a][0]
        var adjY = adjacent[a][1]
        if not hasWall(adjX, adjY) and not hasBox(adjX, adjY):
          if findPath(adjX, adjY):
            return tryMove(nextMoveDX, nextMoveDY)
        a = a + 1
      return false
  
  # Move to clicked position - execute the first move
  if findPath(gridX, gridY):
    return tryMove(nextMoveDX, nextMoveDY)
  
  return false

# Load next level from pack
proc loadNextLevel() =
  if not isLevelPack or len(levelPack) == 0:
    return
  
  currentLevelIndex = currentLevelIndex + 1
  if currentLevelIndex >= len(levelPack):
    currentLevelIndex = 0
  
  parseLevel(levelPack[currentLevelIndex])

# Load previous level from pack
proc loadPrevLevel() =
  if not isLevelPack or len(levelPack) == 0:
    return
  
  currentLevelIndex = currentLevelIndex - 1
  if currentLevelIndex < 0:
    currentLevelIndex = len(levelPack) - 1
  
  parseLevel(levelPack[currentLevelIndex])

# Load level data from txt block in first section (preserves newlines!)
var levelData = getCodeBlockText(0, "txt", 0)

currentLevelData = levelData

levelPack = parseLevelPack(levelData)
isLevelPack = true
currentLevelIndex = 0
if len(levelPack) > 0:
  parseLevel(levelPack[0])

# Auto-scale font to maximize game view
# Calculate maximum dimensions across all levels to ensure all fit
var maxWidth = levelWidth
var maxHeight = levelHeight
var i = 1
while i < len(levelPack):
  # Temporarily parse each level to get dimensions
  var tempLines = split(levelPack[i], "\n")
  var tempHeight = len(tempLines)
  var tempWidth = 0
  var j = 0
  while j < len(tempLines):
    if len(tempLines[j]) > tempWidth:
      tempWidth = len(tempLines[j])
    j = j + 1
  
  if tempWidth > maxWidth:
    maxWidth = tempWidth
  if tempHeight > maxHeight:
    maxHeight = tempHeight
  i = i + 1

# Calculate required terminal cells for game content using max dimensions
var requiredWidth = maxWidth * charWidth
var requiredHeight = maxHeight + 8  # Extra space for status/controls

# Get viewport and font metrics
var viewportWidth = getViewportPixelWidth()
var viewportHeight = getViewportPixelHeight()
var charPixelWidth = getCharPixelWidth()
var charPixelHeight = getCharPixelHeight()

# Calculate optimal scale to fit game in viewport
var scaleX = viewportWidth / (requiredWidth * charPixelWidth)
var scaleY = viewportHeight / (requiredHeight * charPixelHeight)

# Use the smaller scale to ensure everything fits
var scale = scaleX
if scaleY < scaleX:
  scale = scaleY

# Apply scale (clamp to reasonable range)
if scale > 1.0 and scale < 3.0:
  setFontScale(scale)
```

```nim on:input
# Handle input
if event.type == "mouse":
  var mouseAction = event.action
  
  if mouseAction == "press":
    # Mouse position is available as global variables mouseX and mouseY
    # (they are automatically injected by the runtime)
    
    # Check if clicking on button areas at top
    var buttonY = 0
    if mouseY == buttonY:
      # 前 button (chars 2-4)
      if mouseX >= 2 and mouseX <= 4:
        if isLevelPack:
          loadPrevLevel()
          return true
      # 次 button (chars 7-9)
      elif mouseX >= 7 and mouseX <= 9:
        if isLevelPack:
          loadNextLevel()
          return true
      # 復↻ button (right-aligned)
      elif mouseX >= termWidth - 4:
        if isLevelPack and len(levelPack) > 0:
          parseLevel(levelPack[currentLevelIndex])
        else:
          parseLevel(currentLevelData)
        return true
    
    # Calculate offset to match rendering
    var offsetX = (termWidth - (levelWidth * charWidth)) / 2
    var availableHeight = termHeight - 2
    var offsetY = (availableHeight - levelHeight) / 2 + 1
    
    # Convert screen coordinates to grid coordinates (accounting for charWidth)
    var gridX = (mouseX - offsetX) / charWidth
    var gridY = mouseY - offsetY
    
    # Validate grid position
    if gridX >= 0 and gridX < levelWidth and gridY >= 0 and gridY < levelHeight:
      var handled = handleClick(gridX, gridY)
      if handled:
        return true
  
  return false

elif event.type == "text":
  var key = event.text
  
  # Restart
  if key == "r" or key == "R":
    if isLevelPack and len(levelPack) > 0:
      parseLevel(levelPack[currentLevelIndex])
    else:
      parseLevel(currentLevelData)
    return true
  
  # Level pack navigation - Next
  elif key == "n" or key == "N" or key == "+":
    if isLevelPack:
      loadNextLevel()
      return true
  # Level pack navigation - Previous
  elif key == "p" or key == "P" or key == "-":
    if isLevelPack:
      loadPrevLevel()
      return true
  
  return false

elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    # Arrow keys - use KEY_* constants for portability
    if code == KEY_UP:
      if tryMove(0, -1):
        return true
    elif code == KEY_DOWN:
      if tryMove(0, 1):
        return true
    elif code == KEY_LEFT:
      if tryMove(-1, 0):
        return true
    elif code == KEY_RIGHT:
      if tryMove(1, 0):
        return true
    # Next level: Enter/Return
    elif code == KEY_ENTER:
      if isLevelPack:
        loadNextLevel()
        return true
    # Previous level: Backspace or Delete
    elif code == KEY_BACKSPACE or code == KEY_DELETE:
      if isLevelPack:
        loadPrevLevel()
        return true
  
  return false

return false
```

```nim on:render
# Clear screen
clear()

# Increment frame counter for smooth animation every frame
frameCount = frameCount + 1

# Calculate animation offset for win state
var animOffset = 0
if gameWon:
  var time = now()
  var second = time.second
  # Cycle through array positions every second
  animOffset = second mod len(outsideChars)

# Calculate rendering offset to center the level (both horizontal and vertical)
# For double-width chars, ensure offsetX aligns to character boundaries
var offsetX = (termWidth - (levelWidth * charWidth)) / 2
if charWidth == 2 and (offsetX mod 2) != 0:
  offsetX = offsetX - 1  # Align to even position for double-width chars
# Reserve line 0 for status, line termHeight-1 for buttons
var availableHeight = termHeight - 2
var offsetY = (availableHeight - levelHeight) / 2 + 1

# Fill top area with outside chars (if offsetY > 1)
var topY = 1
while topY < offsetY:
  var fillX = 0
  while fillX < termWidth:
    draw(0, fillX, topY, getRandomOutsideChar(fillX, topY, animOffset), styleOutside)
    fillX = fillX + charWidth
  topY = topY + 1

# Render the game area with outside borders
var y = 0
while y < levelHeight:
  # Draw outside area on the left
  var leftX = 0
  while leftX < offsetX:
    draw(0, leftX, offsetY + y, getRandomOutsideChar(leftX, offsetY + y, animOffset), styleOutside)
    leftX = leftX + charWidth
  
  # Draw the game grid
  var x = 0
  while x < levelWidth:
    var ch = floorChar
    var style = styleFloor
    
    # Check player position first (highest priority)
    if x == playerX and y == playerY:
      if isGoal(x, y):
        ch = playerOnGoalChar
        style = stylePlayerGoal
      else:
        ch = playerChar
        style = stylePlayer
    # Check box position
    elif hasBox(x, y):
      if isGoal(x, y):
        ch = boxOnGoalChar
        style = styleBoxGoal
      else:
        ch = boxChar
        style = styleBox
    # Check goal position
    elif isGoal(x, y):
      ch = goalChar
      style = styleGoal
    # Check wall position
    elif hasWall(x, y):
      ch = wallChar
      style = styleWall
    # Check if unreachable area (outside)
    elif not isReachable(x, y):
      ch = getRandomOutsideChar(x, y, animOffset)
      style = styleOutside
    
    # Draw the character (layer 0, accounting for charWidth)
    draw(0, offsetX + (x * charWidth), offsetY + y, ch, style)
    x = x + 1
  
  # Draw outside area on the right
  var rightX = offsetX + (levelWidth * charWidth)
  while rightX < termWidth:
    draw(0, rightX, offsetY + y, getRandomOutsideChar(rightX, offsetY + y, animOffset), styleOutside)
    rightX = rightX + charWidth
  
  y = y + 1

# Fill bottom area with outside chars
var bottomY = offsetY + levelHeight
while bottomY < termHeight - 1:
  var fillX = 0
  while fillX < termWidth:
    draw(0, fillX, bottomY, getRandomOutsideChar(fillX, bottomY, animOffset), styleOutside)
    fillX = fillX + charWidth
  bottomY = bottomY + 1

# Show clickable buttons at top (line 0) with kanji
var buttonY = 0
var accentStyle = getStyle("accent2")
# Left buttons: Previous and Next
draw(0, 0, buttonY, "< ", defaultStyle())
draw(0, 2, buttonY, "前", accentStyle)
draw(0, 4, buttonY, " | ", defaultStyle())
draw(0, 7, buttonY, "次", accentStyle)
draw(0, 9, buttonY, " >", defaultStyle())
# Right button: Restart with circular arrow
var restartX = termWidth - 4
if restartX > 0:
  draw(0, restartX, buttonY, "復", accentStyle)
  draw(0, restartX + 2, buttonY, "↻", defaultStyle())

# Show win message below the level
var statusY = offsetY + levelHeight + 1
if gameWon:
  var winText = "完 Level Complete!"
  var winX = offsetX + ((levelWidth * charWidth) - len(winText)) / 2
  draw(0, winX, statusY, winText, stylePlayer)

# Show level indicator and move count on bottom line (plain ASCII only, centered)
var statusY = termHeight - 1
if isLevelPack:
  var levelNum = $(currentLevelIndex + 1) & "/" & $len(levelPack)
  var statusText = levelNum
  # Add move counter if there are moves
  if moveCount > 0:
    statusText = statusText & " > " & $moveCount
  var statusX = (termWidth - len(statusText)) / 2
  draw(0, statusX, statusY, statusText, defaultStyle())
```
