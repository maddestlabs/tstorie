# Time Test

```nim on:render
fgClear()

var time = now()
fgWriteText(10, 5, "Map type check")

# Try to print the hour
var h = time["hour"]
fgWriteText(10, 7, "Hour value: " & $h)

# Try building the time string
var timeStr = $h
fgWriteText(10, 9, "Time string: " & timeStr)
```
