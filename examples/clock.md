# Digital Clock Example

A real-time digital clock with large figlet-style digits that updates every frame.

```nim on:render
# Clear the screen
fgClear()

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

# Draw border
bgFillRect(0, 0, termWidth, 1, "═")
bgFillRect(0, termHeight - 1, termWidth, 1, "═")

# Show FPS counter in corner
fgWriteText(2, 1, "FPS: " & $int(fps))
```
