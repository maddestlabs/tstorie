# Matrix Digital Rain - Enhanced

A sophisticated Matrix-inspired digital rain effect with glitch effects, variable speeds, and erasers.

## Features

- **Variable Speed Drops**: Each column has its own speed multiplier
- **Dynamic Trail Lengths**: Trails vary from 8-25 characters
- **Glitch Effects**: Random character glitches in trailing characters
- **Eraser Drops**: Optional clearing drops that follow main drops
- **Color Intensity**: Bright white heads fading to dark green trails
- **Unicode Characters**: Authentic Matrix-style katakana and alphanumerics

```nim on:init
# Character sets
var matrixChars = "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ012345789Z:.=*+-<>¦"

# Configuration
var speedMultiplier = 2
var glitchChance = 3          # Percentage chance per frame
var eraserChance = 20          # Percentage of drops that spawn erasers
var maxTrailPercent = 80       # Maximum trail length as % of screen height
var dropSpawnChance = 100      # Percentage chance to spawn drops per column

# Drop system
var drops = []
var erasers = []

# Initialize drops for each column
var col = 0
while col < termWidth:
  # Spread drops across vertical space for staggered start
  var startY = 0 - randInt(termHeight * 8)
  var dropSpeed = randInt(1, 6)
  var maxLength = max(8, (termHeight * maxTrailPercent) / 100)
  var dropLength = randInt(8, maxLength)
  
  # Create trail arrays - store historical characters
  var trail = []
  var glitchTrail = []
  var glitchActive = []
  var i = 0
  while i < dropLength:
    trail = trail + [" "]
    glitchTrail = glitchTrail + [" "]
    glitchActive = glitchActive + [0]
    i = i + 1
  
  # Determine if this drop spawns an eraser
  var hasEraser = 0
  if randInt(100) < eraserChance:
    hasEraser = 1
  
  var drop = {
    "y": startY,
    "speed": dropSpeed,
    "length": dropLength,
    "headChar": matrixChars[randInt(len(matrixChars))],
    "trail": trail,
    "glitchTrail": glitchTrail,
    "glitchActive": glitchActive,
    "trailPos": 0,
    "lastUpdate": 0,
    "lastGlitch": 0,
    "hasEraser": hasEraser,
    "eraserSpawned": 0
  }
  drops = drops + [drop]
  col = col + 1
```

```nim on:update
# Update each drop independently
var col = 0
while col < termWidth:
  var drop = drops[col]
  var y = drop["y"]
  var speed = drop["speed"]
  var length = drop["length"]
  var lastUpdate = drop["lastUpdate"]
  var headChar = drop["headChar"]
  var trail = drop["trail"]
  var glitchTrail = drop["glitchTrail"]
  var glitchActive = drop["glitchActive"]
  var trailPos = drop["trailPos"]
  var lastGlitch = drop["lastGlitch"]
  var hasEraser = drop["hasEraser"]
  var eraserSpawned = drop["eraserSpawned"]
  
  # Move drop based on its speed
  if frameCount - lastUpdate >= speed * speedMultiplier:
    # Store current head character in trail before changing
    trail[trailPos] = headChar
    trailPos = (trailPos + 1) % length
    
    y = y + 1
    lastUpdate = frameCount
    
    # Generate new head character
    headChar = matrixChars[randInt(len(matrixChars))]
    
    # Spawn eraser if needed (when drop is far enough down)
    if hasEraser == 1 and eraserSpawned == 0 and y > 20:
      var followDist = length + randInt(5, 15)
      var eraser = {
        "col": col,
        "y": y - followDist,
        "speed": speed * speedMultiplier - 1
      }
      erasers = erasers + [eraser]
      eraserSpawned = 1
    
    # Reset when tail leaves screen
    if y - length > termHeight:
      y = 0 - randInt(termHeight * 6)
      speed = randInt(1, 6)
      var maxLength = max(8, (termHeight * maxTrailPercent) / 100)
      length = randInt(8, maxLength)
      
      # Resize trail arrays if length changed
      trail = []
      glitchTrail = []
      glitchActive = []
      var i = 0
      while i < length:
        trail = trail + [" "]
        glitchTrail = glitchTrail + [" "]
        glitchActive = glitchActive + [0]
        i = i + 1
      trailPos = 0
      
      # Reset eraser status
      if randInt(100) < eraserChance:
        hasEraser = 1
      else:
        hasEraser = 0
      eraserSpawned = 0
  
  # Update glitch effects periodically
  if frameCount - lastGlitch >= 3:
    lastGlitch = frameCount
    
    var i = 0
    while i < length:
      # Start new glitch
      if glitchActive[i] == 0 and randInt(100) < glitchChance:
        glitchActive[i] = 1
        glitchTrail[i] = matrixChars[randInt(len(matrixChars))]
      # Stop existing glitch
      elif glitchActive[i] == 1 and randInt(100) < 40:
        glitchActive[i] = 0
      i = i + 1
  
  # Update drop with new values
  drops[col] = {
    "y": y,
    "speed": speed,
    "length": length,
    "headChar": headChar,
    "trail": trail,
    "glitchTrail": glitchTrail,
    "glitchActive": glitchActive,
    "trailPos": trailPos,
    "lastUpdate": lastUpdate,
    "lastGlitch": lastGlitch,
    "hasEraser": hasEraser,
    "eraserSpawned": eraserSpawned
  }
  
  col = col + 1

# Update erasers
var newErasers = []
var i = 0
while i < len(erasers):
  var eraser = erasers[i]
  var ey = eraser["y"]
  var espeed = eraser["speed"]
  var ecol = eraser["col"]
  
  # Move eraser down
  if frameCount % espeed == 0:
    ey = ey + 1
  
  # Keep eraser if still on screen
  if ey <= termHeight:
    newErasers = newErasers + [{
      "col": ecol,
      "y": ey,
      "speed": espeed
    }]
  
  i = i + 1
erasers = newErasers
```

```nim on:render
bgClear()

# Draw erasers first (clear cells)
var i = 0
while i < len(erasers):
  var eraser = erasers[i]
  var ey = eraser["y"]
  var ecol = eraser["col"]
  
  if ey >= 0 and ey < termHeight and ecol < termWidth:
    bgWrite(ecol, ey, " ")
  
  i = i + 1

# Draw drops
var col = 0
while col < termWidth:
  var drop = drops[col]
  var y = drop["y"]
  var length = drop["length"]
  var headChar = drop["headChar"]
  var trail = drop["trail"]
  var glitchTrail = drop["glitchTrail"]
  var glitchActive = drop["glitchActive"]
  var trailPos = drop["trailPos"]
  
  # Draw the bright head
  if y >= 0 and y < termHeight:
    fgWrite(col, y, headChar)
  
  # Draw the trail with historical characters
  var i = 0
  while i < length:
    var cy = y - i - 1
    if cy >= 0 and cy < termHeight:
      # Calculate trail index in circular buffer
      var trailIdx = (trailPos - 1 - i + length) % length
      
      # Choose character (glitched or normal)
      var ch = trail[trailIdx]
      if glitchActive[trailIdx] == 1:
        ch = glitchTrail[trailIdx]
      
      # Only draw if not empty space
      if ch != " ":
        # Brightness based on position (bright near head, dim at tail)
        if i < 2:
          # Very bright green near head
          fgWrite(col, cy, ch)
        elif i < length / 3:
          # Medium bright
          bgWrite(col, cy, ch)
        else:
          # Dim tail
          bgWrite(col, cy, ch)
    
    i = i + 1
  
  col = col + 1

# Title and stats
fgWriteText(2, 0, "MATRIX RAIN - ENHANCED | FPS: " & $int(fps) & " | Drops: " & $len(drops) & " | Erasers: " & $len(erasers))
```

## Configuration Tips

Edit the variables in the `on:init` block to customize:

- **speedMultiplier**: Higher = faster drops (try 1-5)
- **glitchChance**: Percentage chance for glitches (try 0-10)
- **eraserChance**: Percentage of drops with erasers (try 0-100)
- **maxTrailPercent**: Maximum trail length (try 30-100)
- **dropSpawnChance**: How quickly drops spawn (try 50-100)

## Try These Presets

**Classic Matrix** (current settings):
- speedMultiplier = 2, glitchChance = 3, eraserChance = 20

**Slow Glitchy**:
- speedMultiplier = 1, glitchChance = 8, eraserChance = 0

**Fast & Clear**:
- speedMultiplier = 4, glitchChance = 0, eraserChance = 50

**Chaotic**:
- speedMultiplier = 3, glitchChance = 10, eraserChance = 80
