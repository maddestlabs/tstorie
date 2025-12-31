---
title: "Box Pusher"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "futurism"
useEmoji: "true"
emoji: "⬛⬜🔲😶🟨❎"
---

# Level 1
⠀
Get the box to the goal!
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
- [Next Level](#level_2) | [How to Play](#instructions)

# Level 2
⠀
Two boxes, two goals!
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
- [Restart](#level_1) | [How to Play](#instructions)

# Instructions
⠀
**How to Play:**
⠀
```nim on:enter
contentClear()
contentWrite("-" & playerChar & " You are the player")
contentWrite("-" & boxChar & "  Push boxes onto goals")
contentWrite("-" & goalChar & " Goal markers")
contentWrite("-" & boxOnGoalChar & " Box on goal")
contentWrite("-" & wallChar & " Walls")
```
⠀
**Controls:**
- **WASD** to move
- **R** to restart the current level
⠀
**Rules:**
- You can only push boxes, not pull them
- You cannot push two boxes at once
- Get all boxes onto the goal markers to win!
⠀
- [Play Level 1](#level_1)

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
  var i = 0
  while i < len(walls):
    if walls[i][0] == x and walls[i][1] == y:
      return true
    i = i + 1
  return false

# Check if position has a box
proc hasBox(x: int, y: int): bool =
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
```

```nim on:input
# Handle input
if event.type == "text":
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

elif event.type == "mouse":
  if event.action == "press":
    var handled = canvasHandleMouse(event.x, event.y, event.button, true)
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
  
  if newLevelData != currentLevelData or levelWidth == 0:
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
