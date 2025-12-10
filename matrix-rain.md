# Matrix Digital Rain Effect

Classic green cascading code effect inspired by The Matrix.

```nim on:init
# Matrix rain drops - each column has its own drop
var drops = []
var matrixChars = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Initialize drops for each column with random starting positions
var col = 0
while col < termWidth:
  var drop = {
    "y": 0 - randInt(termHeight * 2),
    "speed": randInt(1, 4),
    "length": randInt(10, 30),
    "lastUpdate": 0
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
  
  # Move drop based on its individual speed
  if frameCount - lastUpdate >= speed:
    y = y + 1
    lastUpdate = frameCount
    
    # Reset when completely off screen
    if y - length > termHeight:
      y = 0 - randInt(termHeight)
      speed = randInt(2, 6)
      length = randInt(10, 30)
  
  # Update drop with new values
  drops[col] = {"y": y, "speed": speed, "length": length, "lastUpdate": lastUpdate}
  col = col + 1
```

```nim on:render
bgClear()

var col = 0
while col < termWidth:
  var drop = drops[col]
  var y = drop["y"]
  var length = drop["length"]
  
  # Draw the trail
  var i = 0
  while i < length:
    var cy = y - i
    if cy >= 0 and cy < termHeight:
      # Pick random character
      var charIdx = randInt(len(matrixChars))
      var ch = matrixChars[charIdx]
      
      # Fade effect - brighter at head
      if i == 0:
        # Brightest - white head
        bgWrite(col, cy, ch)
      elif i < 3:
        # Bright green
        bgWrite(col, cy, ch)
      elif i < length / 2:
        # Medium green
        bgWrite(col, cy, ch)
      else:
        # Dark green (fading tail)
        bgWrite(col, cy, ch)
    i = i + 1
  
  col = col + 1

# Title
fgWriteText(2, 0, "MATRIX RAIN")
```
