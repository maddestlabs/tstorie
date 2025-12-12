# Digital Clock Example

A real-time digital clock with large figlet-style digits that updates every frame.

```nim on:render
# Clear the screen
fgClear()

# Get current time
var hour = getHour()
var minute = getMinute()
var second = getSecond()

# Figlet font data - 5 lines tall, index 10 is colon
var figlet = [
  ["+---+", "|   |", "|   |", "|   |", "+---+"],  # 0
  ["    |", "    |", "    |", "    |", "    |"],  # 1
  ["+---+", "    |", "+---+", "|    ", "+---+"],  # 2
  ["+---+", "    |", "+---+", "    |", "+---+"],  # 3
  ["|   |", "|   |", "+---+", "    |", "    |"],  # 4
  ["+---+", "|    ", "+---+", "    |", "+---+"],  # 5
  ["+---+", "|    ", "+---+", "|   |", "+---+"],  # 6
  ["+---+", "    |", "    |", "    |", "    |"],  # 7
  ["+---+", "|   |", "+---+", "|   |", "+---+"],  # 8
  ["+---+", "|   |", "+---+", "    |", "+---+"],  # 9
  [" ", "o", " ", "o", " "]  # : (colon)
]

# Convert time to digits
var h1 = hour / 10
var h2 = hour - (h1 * 10)
var m1 = minute / 10
var m2 = minute - (m1 * 10)
var s1 = second / 10
var s2 = second - (s1 * 10)

# Calculate starting position to center the clock
# Format is: HH:MM:SS = 5+1+5+1+5+1+5+1+5 = 29 chars wide
var clockWidth = 29
var startX = (termWidth - clockWidth) / 2
var startY = (termHeight - 5) / 2

# Draw each digit line by line
var line = 0
while line < 5:
  var x = startX
  
  # Hour tens
  fgWriteText(x, startY + line, figlet[h1][line])
  x = x + 6
  
  # Hour ones
  fgWriteText(x, startY + line, figlet[h2][line])
  x = x + 6
  
  # Colon
  fgWriteText(x, startY + line, figlet[10][line])
  x = x + 2
  
  # Minute tens
  fgWriteText(x, startY + line, figlet[m1][line])
  x = x + 6
  
  # Minute ones
  fgWriteText(x, startY + line, figlet[m2][line])
  x = x + 6
  
  # Colon
  fgWriteText(x, startY + line, figlet[10][line])
  x = x + 2
  
  # Second tens
  fgWriteText(x, startY + line, figlet[s1][line])
  x = x + 6
  
  # Second ones
  fgWriteText(x, startY + line, figlet[s2][line])
  
  line = line + 1

# Show date below the clock
var dateY = startY + 7
var dateStr = $getYear() & "-"
var month = getMonth()
if month < 10:
  dateStr = dateStr & "0"
dateStr = dateStr & $month & "-"
var day = getDay()
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
