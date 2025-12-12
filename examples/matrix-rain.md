# Matrix Digital Rain Effect

Classic green cascading code effect inspired by The Matrix.

```nim on:init
# Matrix rain drops - each column has its own drop
var drops = []
var matrixChars = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Initialize drops for each column with random starting positions
var col = 0
while col < termWidth:
  # Calculate values first, then create map with literal values
  # Spread drops across a much larger range for varied start times
  var startY = 0 - randInt(termHeight * 10)
  var dropSpeed = randInt(1, 5)
  var dropLength = randInt(8, 25)
  var drop = {"y": startY, "speed": dropSpeed, "length": dropLength, "lastUpdate": 0}
  drops = drops + [drop]
  col = col + 1
```

```nim on:update
# Update each drop independently - each moves at its own speed
var col = 0
while col < termWidth:
  var drop = drops[col]
  var y = drop["y"]
  var speed = drop["speed"]
  var length = drop["length"]
  
  # Move drop down by its speed (pixels per frame)
  y = y + speed
  
  # Reset when the tail completely leaves the screen
  if y - length > termHeight:
    y = 0 - randInt(termHeight * 5)
    speed = randInt(1, 5)
    length = randInt(8, 25)
  
  # Update drop with new values (using literal values in map)
  var updatedDrop = {"y": y, "speed": speed, "length": length, "lastUpdate": 0}
  drops[col] = updatedDrop
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
