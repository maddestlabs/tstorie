# Timing Auto-Exposure Test

Test that all auto-exposed timing functions work correctly.

```nimini
section "main"
on:render
  clear()
  
  # Test all auto-exposed timing functions
  let dt = getDeltaTime()
  let t = getTime()
  let tms = getTimeMs()
  let tt = getTotalTime()
  let fc = getFrameCount()
  let fps = getFps()
  
  # Display results
  moveCursor(0, 0)
  write("=== Auto-Exposed Timing Functions Test ===")
  
  moveCursor(0, 2)
  write("getDeltaTime(): " + toString(dt) + "s")
  
  moveCursor(0, 3)
  write("getTime(): " + toString(t) + "s")
  
  moveCursor(0, 4)
  write("getTimeMs(): " + toString(tms) + "ms")
  
  moveCursor(0, 5)
  write("getTotalTime(): " + toString(tt) + "s")
  
  moveCursor(0, 6)
  write("getFrameCount(): " + toString(fc))
  
  moveCursor(0, 7)
  write("getFps(): " + toString(fps))
  
  # Test calculation using auto-exposed functions
  let dtUs = dt * 1000000.0
  moveCursor(0, 9)
  write("Calculated DeltaTime µs: " + toString(dtUs))
  
  # Animated test - bouncing dot
  let x = 5 + toInt(sin(t * 2.0) * 20.0)
  let y = 12
  moveCursor(x, y)
  setFg(2)  # green
  write("●")
  
  moveCursor(0, 13)
  setFg(7)
  write("Animated dot position based on getTime()")
  
  moveCursor(0, 15)
  write("Press Q to quit")
  
on:key
  if key == KEY_Q
    exit()
```
