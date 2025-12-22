# Digital Clock Example

A real-time digital clock with large figlet-style digits that updates every frame.

```nim on:init
# Initialize rain particles using parallel arrays
var rainX = []
var rainY = []
var rainPrevY = []
var rainSpeed = []
var rainColor = []
var rainChar = []
var numRainParticles = 40

# Create rain particles
var i = 0
while i < numRainParticles:
  rainX = rainX + [randInt(80)]
  var startY = randInt(24)
  rainY = rainY + [startY]
  rainPrevY = rainPrevY + [startY]
  rainSpeed = rainSpeed + [1 + randInt(3)]
  rainColor = rainColor + [randInt(7)]
  rainChar = rainChar + [randInt(3)]
  i = i + 1
```

```nim on:render
# Clear the screen
fgClear()

# Update and draw rain particles
var i = 0
while i < numRainParticles:
  # Clear the previous position
  var prevPx = rainX[i]
  var prevPy = rainPrevY[i]
  if prevPx >= 0 and prevPx < termWidth and prevPy >= 0 and prevPy < termHeight:
    fgWrite(prevPx, prevPy, " ", defaultStyle())
  
  # Save current position as previous
  rainPrevY[i] = rainY[i]
  
  # Update position
  rainY[i] = rainY[i] + rainSpeed[i]
  
  # Wrap around when particle goes off bottom
  if rainY[i] >= termHeight:
    rainY[i] = 0
    rainPrevY[i] = 0
    rainX[i] = randInt(termWidth)
  
  # Choose rain character
  var pChar = " "
  var charType = rainChar[i]
  if charType == 0:
    pChar = "|"
  if charType == 1:
    pChar = "!"
  if charType == 2:
    pChar = "."
  
  # Choose color based on particle color value and create style
  var pStyle = defaultStyle()
  var colorType = rainColor[i]
  if colorType == 0:
    pStyle.fg = cyan()
  if colorType == 1:
    pStyle.fg = blue()
  if colorType == 2:
    pStyle.fg = rgb(100, 150, 255)
  if colorType == 3:
    pStyle.fg = rgb(150, 200, 255)
  if colorType == 4:
    pStyle.fg = magenta()
  if colorType == 5:
    pStyle.fg = rgb(200, 100, 255)
  if colorType == 6:
    pStyle.fg = rgb(100, 255, 200)
  
  # Draw the rain particle
  var px = rainX[i]
  var py = rainY[i]
  if px >= 0 and px < termWidth and py >= 0 and py < termHeight:
    fgWrite(px, py, pChar, pStyle)
  
  i = i + 1

# Get current time
var time = now()
var hour = time.hour
var minute = time.minute
var second = time.second

# Convert time to digits
var h1 = hour / 10
var h2 = hour - (h1 * 10)
var m1 = minute / 10
var m2 = minute - (m1 * 10)
var s1 = second / 10
var s2 = second - (s1 * 10)

# Calculate starting position to center the clock
var clockWidth = 29
var startX = (termWidth - clockWidth) / 2
var startY = (termHeight - 5) / 2

# Draw the digits using the helper function
var x = startX
drawFigletDigit(h1, x, startY)
x = x + 6
drawFigletDigit(h2, x, startY)
x = x + 6
drawFigletDigit(10, x, startY)
x = x + 2
drawFigletDigit(m1, x, startY)
x = x + 6
drawFigletDigit(m2, x, startY)
x = x + 6
drawFigletDigit(10, x, startY)
x = x + 2
drawFigletDigit(s1, x, startY)
x = x + 6
drawFigletDigit(s2, x, startY)

# Show date below the clock
var dateY = startY + 7
var year = time.year
var month = time.month
var day = time.day
var dateStr = $year & "-"
if month < 10:
  dateStr = dateStr & "0"
dateStr = dateStr & $month & "-"
if day < 10:
  dateStr = dateStr & "0"
dateStr = dateStr & $day

var dateX = (termWidth - 10) / 2
fgWriteText(dateX, dateY, dateStr)
```
