---
title: "Minesweeper"
author: "Maddest Labs"
minWidth: 20
minHeight: 14
chars: "█ *⚑₁₂₃₄₅₆₇₈"
theme: "coffee"
fontsize: 30
shaders: "ruledlines+paper"
---

# Minesweeper

```nim on:init
# Character width (2 for double-width)
var charWidth = 1

# Game state
var gridWidth = 8
var gridHeight = 8
var mineCount = 10
var grid = []  # Each cell: [revealed(0/1), isMine(0/1), flagged(0/1), adjacentMines]
var firstClick = true
var gameOver = false
var gameWon = false
var cellsRevealed = 0
var flagsPlaced = 0
var currentDifficulty = "easy"

# Kanji characters for display
var hiddenChar = "O"      # Hidden
var revealedChar = "."    # Empty
var mineChar = "*"        # Mine
var flagChar = "⚑"        # Flag
var num1Char = "1"        # One
var num2Char = "2"        # Two
var num3Char = "3"        # Three
var num4Char = "4"        # Four
var num5Char = "5"        # Five
var num6Char = "6"        # Six
var num7Char = "7"        # Seven
var num8Char = "8"        # Eight

# Load chars from front matter if defined
if len(chars) > 0:
  var charsList = []
  var i = 0
  while i < len(chars):
    var b = ord(chars[i])
    var charLen = 1
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
  
  if len(charsList) > 0:
    hiddenChar = charsList[0]
  if len(charsList) > 1:
    revealedChar = charsList[1]
  if len(charsList) > 2:
    mineChar = charsList[2]
  if len(charsList) > 3:
    flagChar = charsList[3]
  if len(charsList) > 4:
    num1Char = charsList[4]
  if len(charsList) > 5:
    num2Char = charsList[5]
  if len(charsList) > 6:
    num3Char = charsList[6]
  if len(charsList) > 7:
    num4Char = charsList[7]
  if len(charsList) > 8:
    num5Char = charsList[8]
  if len(charsList) > 9:
    num6Char = charsList[9]
  if len(charsList) > 10:
    num7Char = charsList[10]
  if len(charsList) > 11:
    num8Char = charsList[11]

# Styles
var styleHidden = getStyle("inverted")
var styleRevealed = defaultStyle()
var styleMine = getStyle("accent3")
var styleFlag = getStyle("accent2")
var styleNumber = defaultStyle()

# Initialize grid
proc initGrid() =
  grid = []
  var y = 0
  while y < gridHeight:
    var x = 0
    while x < gridWidth:
      # [revealed, isMine, flagged, adjacentMines]
      grid = grid + [[0, 0, 0, 0]]
      x = x + 1
    y = y + 1
  firstClick = true
  gameOver = false
  gameWon = false
  cellsRevealed = 0
  flagsPlaced = 0

# Get cell index
proc getCellIdx(x: int, y: int): int =
  if x < 0 or y < 0 or x >= gridWidth or y >= gridHeight:
    return -1
  return y * gridWidth + x

# Get cell data
proc getCell(x: int, y: int): seq[int] =
  var idx = getCellIdx(x, y)
  if idx >= 0 and idx < len(grid):
    return grid[idx]
  return [0, 0, 0, 0]

# Set cell data
proc setCell(x: int, y: int, revealed: int, isMine: int, flagged: int, adjacent: int) =
  var idx = getCellIdx(x, y)
  if idx >= 0 and idx < len(grid):
    grid[idx] = [revealed, isMine, flagged, adjacent]

# Place mines randomly, avoiding first click position
proc placeMines(avoidX: int, avoidY: int) =
  var minesPlaced = 0
  var attempts = 0
  var maxAttempts = mineCount * 100
  
  while minesPlaced < mineCount and attempts < maxAttempts:
    # Use actual random placement
    var rx = rand(gridWidth)
    var ry = rand(gridHeight)
    
    # Don't place mine on first click or adjacent cells
    var tooClose = false
    if rx == avoidX and ry == avoidY:
      tooClose = true
    var dx = rx - avoidX
    var dy = ry - avoidY
    if dx < 0:
      dx = -dx
    if dy < 0:
      dy = -dy
    if dx <= 1 and dy <= 1:
      tooClose = true
    
    if not tooClose:
      var cell = getCell(rx, ry)
      if cell[1] == 0:
        setCell(rx, ry, 0, 1, 0, 0)
        minesPlaced = minesPlaced + 1
    
    attempts = attempts + 1
  
  # Calculate adjacent mine counts
  var y = 0
  while y < gridHeight:
    var x = 0
    while x < gridWidth:
      var cell = getCell(x, y)
      if cell[1] == 0:
        var count = 0
        var dy = -1
        while dy <= 1:
          var dx = -1
          while dx <= 1:
            if dx != 0 or dy != 0:
              var nx = x + dx
              var ny = y + dy
              var neighbor = getCell(nx, ny)
              if neighbor[1] == 1:
                count = count + 1
            dx = dx + 1
          dy = dy + 1
        setCell(x, y, 0, 0, cell[2], count)
      x = x + 1
    y = y + 1

# Reveal cell (flood fill for empty cells)
proc revealCell(x: int, y: int): bool =
  if x < 0 or y < 0 or x >= gridWidth or y >= gridHeight:
    return false
  
  var cell = getCell(x, y)
  if cell[0] == 1:
    return false
  if cell[2] == 1:
    return false
  
  if firstClick:
    placeMines(x, y)
    firstClick = false
    cell = getCell(x, y)
  
  setCell(x, y, 1, cell[1], 0, cell[3])
  cellsRevealed = cellsRevealed + 1
  
  if cell[1] == 1:
    gameOver = true
    return true
  
  if cell[3] == 0:
    var dy = -1
    while dy <= 1:
      var dx = -1
      while dx <= 1:
        if dx != 0 or dy != 0:
          revealCell(x + dx, y + dy)
        dx = dx + 1
      dy = dy + 1
  
  return true

# Toggle flag on cell
proc toggleFlag(x: int, y: int): bool =
  if x < 0 or y < 0 or x >= gridWidth or y >= gridHeight:
    return false
  
  var cell = getCell(x, y)
  if cell[0] == 1:
    return false
  
  if cell[2] == 0:
    setCell(x, y, 0, cell[1], 1, cell[3])
    flagsPlaced = flagsPlaced + 1
  else:
    setCell(x, y, 0, cell[1], 0, cell[3])
    flagsPlaced = flagsPlaced - 1
  
  return true

# Check win condition
proc checkWin(): bool =
  if gameOver:
    return false
  var totalCells = gridWidth * gridHeight
  var targetRevealed = totalCells - mineCount
  if cellsRevealed >= targetRevealed:
    gameWon = true
    return true
  return false

# Set difficulty
proc setDifficulty(diff: string) =
  currentDifficulty = diff
  if diff == "easy":
    gridWidth = 8
    gridHeight = 8
    mineCount = 10
  elif diff == "medium":
    gridWidth = 12
    gridHeight = 12
    mineCount = 20
  elif diff == "hard":
    gridWidth = 16
    gridHeight = 16
    mineCount = 40
  initGrid()

# Initialize with easy difficulty
initGrid()
```

```nim on:input
# Handle mouse events
if event.type == "mouse":
  var mouseAction = event.action
  
  if mouseAction == "press":
    # Calculate offset to match rendering
    var offsetX = (termWidth - (gridWidth * charWidth)) / 2
    if charWidth == 2 and (offsetX mod 2) != 0:
      offsetX = offsetX - 1
    var availableHeight = termHeight - 3
    var offsetY = (availableHeight - gridHeight) / 2 + 1
    
    # Check if clicking on buttons at top
    var buttonY = 1
    if mouseY == buttonY:
      # Easy button
      if mouseX >= 0 and mouseX <= 5:
        setDifficulty("easy")
        return true
      # Medium button
      elif mouseX >= 7 and mouseX <= 14:
        setDifficulty("medium")
        return true
      # Hard button
      elif mouseX >= 16 and mouseX <= 22:
        setDifficulty("hard")
        return true
      # Restart button (right-aligned)
      elif mouseX >= termWidth - 4:
        initGrid()
        return true
    
    # Convert screen coordinates to grid coordinates
    var gridX = (mouseX - offsetX) / charWidth
    var gridY = mouseY - offsetY
    
    # Validate grid position
    if gridX >= 0 and gridX < gridWidth and gridY >= 0 and gridY < gridHeight:
      if not gameWon and not gameOver:
        if event.button == "left":
          revealCell(gridX, gridY)
          checkWin()
          return true
        elif event.button == "right":
          toggleFlag(gridX, gridY)
          return true
  
  return true

elif event.type == "key":
  if event.action == "press":
    var code = event.keyCode
    
    # R key - restart
    if code == KEY_R:
      initGrid()
      return true
    # ESC - quit
    elif code == KEY_ESCAPE:
      return false
  
  return false

return false
```

```nim on:render
# Clear screen
clear()

# Calculate rendering offset to center the grid
var offsetX = (termWidth - (gridWidth * charWidth)) / 2
if charWidth == 2 and (offsetX mod 2) != 0:
  offsetX = offsetX - 1  # Align to even position for double-width chars

var availableHeight = termHeight - 3  # Reserve lines for status
var offsetY = (availableHeight - gridHeight) / 2 + 1

# Render the game grid
var y = 0
while y < gridHeight:
  var x = 0
  while x < gridWidth:
    var cell = getCell(x, y)
    var ch = hiddenChar
    var style = styleHidden
    
    if cell[0] == 1:  # Revealed
      if cell[1] == 1:  # Mine
        ch = mineChar
        style = styleMine
      elif cell[3] > 0:  # Has adjacent mines
        if cell[3] == 1:
          ch = num1Char
        elif cell[3] == 2:
          ch = num2Char
        elif cell[3] == 3:
          ch = num3Char
        elif cell[3] == 4:
          ch = num4Char
        elif cell[3] == 5:
          ch = num5Char
        elif cell[3] == 6:
          ch = num6Char
        elif cell[3] == 7:
          ch = num7Char
        elif cell[3] == 8:
          ch = num8Char
        style = styleNumber
      else:  # No adjacent mines
        ch = revealedChar
        style = styleRevealed
    elif cell[2] == 1:  # Flagged
      ch = flagChar
      style = styleFlag
    
    # Draw the character
    draw(0, offsetX + (x * charWidth), offsetY + y, ch, style)
    x = x + 1
  y = y + 1

# Show clickable buttons at top (line 0)
var buttonY = 1
var accentStyle = getStyle("accent2")
draw(0, 0, buttonY, "[Easy]", accentStyle)
draw(0, 7, buttonY, "[Medium]", accentStyle)
draw(0, 16, buttonY, "[Hard]", accentStyle)
var restartX = termWidth - 4
if restartX > 0:
  draw(0, restartX, buttonY, "R ", accentStyle)
  draw(0, restartX + 2, buttonY, "↻", defaultStyle())

# Show status below the grid
var statusY = offsetY + gridHeight + 1
if gameWon:
  var winText = "★★★ YOU WIN! ★★★"
  var winX = offsetX + ((gridWidth * charWidth) - len(winText)) / 2
  draw(0, winX, statusY, winText, accentStyle)
elif gameOver:
  var loseText = "* GAME OVER *"
  var loseX = offsetX + ((gridWidth * charWidth) - len(loseText)) / 2
  draw(0, loseX, statusY, loseText, styleMine)

# Show stats on bottom line
var bottomY = termHeight - 1
var statsText = currentDifficulty & " | Mines: " & $mineCount & " | Flags: " & $flagsPlaced & "/" & $mineCount
var statsX = (termWidth - len(statsText)) / 2
draw(0, statsX, bottomY, statsText, defaultStyle())
```
