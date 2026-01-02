# getSectionMetrics() API Documentation

## Overview

The `getSectionMetrics()` function is available in `lib/canvas.nim` and provides access to the current section's screen coordinates and dimensions. This is useful for drawing borders, overlays, or any UI elements that need to align with the section boundaries.

## Function Signature

```nim
proc getSectionMetrics*(): SectionMetrics
```

## Return Type

```nim
type SectionMetrics* = object
  x*: int         # Screen X coordinate (after camera transform)
  y*: int         # Screen Y coordinate (after camera transform)
  width*: int     # Visual width of the section content
  height*: int    # Visual height of the section content
  worldX*: int    # World X coordinate (before camera transform)
  worldY*: int    # World Y coordinate (before camera transform)
```

## Fields Explanation

- **x, y**: Screen-relative coordinates. These are the actual positions on the terminal screen where the section content is being rendered. These coordinates account for the camera position (panning).

- **width, height**: The actual rendered dimensions of the section content. These use the `actualVisualWidth` and `actualVisualHeight` if available (which account for double-width characters and actual rendered content), otherwise fall back to the allocated section dimensions.

- **worldX, worldY**: World-space coordinates before camera transformation. These remain constant regardless of camera position.

## Usage Example

### Basic Border Drawing

```nim
```nim on:render
clear()
canvasRender()

# Get the current section's metrics
var metrics = getSectionMetrics()

# Draw a border around the section
var borderStyle = defaultStyle()
borderStyle.fg = rgb(255, 0, 255)  # Magenta
borderStyle.bold = true

# Top border
var x = metrics.x
while x < metrics.x + metrics.width:
  draw(0, x, metrics.y, "═", borderStyle)
  x = x + 1

# Bottom border
x = metrics.x
while x < metrics.x + metrics.width:
  draw(0, x, metrics.y + metrics.height - 1, "═", borderStyle)
  x = x + 1

# Left border
var y = metrics.y
while y < metrics.y + metrics.height:
  draw(0, metrics.x, y, "║", borderStyle)
  y = y + 1

# Right border
y = metrics.y
while y < metrics.y + metrics.height:
  draw(0, metrics.x + metrics.width - 1, y, "║", borderStyle)
  y = y + 1

# Corners
draw(0, metrics.x, metrics.y, "╔", borderStyle)
draw(0, metrics.x + metrics.width - 1, metrics.y, "╗", borderStyle)
draw(0, metrics.x, metrics.y + metrics.height - 1, "╚", borderStyle)
draw(0, metrics.x + metrics.width - 1, metrics.y + metrics.height - 1, "╝", borderStyle)
```
```

### Drawing a Status Bar at the Bottom

```nim
```nim on:render
clear()
canvasRender()

var metrics = getSectionMetrics()
var statusStyle = defaultStyle()
statusStyle.bg = rgb(40, 40, 40)
statusStyle.fg = rgb(255, 255, 255)

# Draw status bar at bottom of section
var statusY = metrics.y + metrics.height - 1
var x = metrics.x
while x < metrics.x + metrics.width:
  draw(0, x, statusY, " ", statusStyle)
  x = x + 1

# Draw status text
draw(0, metrics.x + 2, statusY, "Status: Active", statusStyle)
```
```

### Checking if Content is On Screen

```nim
```nim on:render
clear()
canvasRender()

var metrics = getSectionMetrics()

# Check if the section is fully visible on screen
if metrics.x >= 0 and metrics.x + metrics.width <= termWidth and
   metrics.y >= 0 and metrics.y + metrics.height <= termHeight:
  # Section is fully visible
  draw(0, metrics.x, metrics.y, "✓", getStyle("accent"))
```
```

## Notes

- The function returns zero values if the canvas is not initialized or if there is no current section.
- The screen coordinates (x, y) automatically adjust when the camera pans, so your UI elements will move with the section.
- The world coordinates (worldX, worldY) remain constant and can be useful for positioning elements in world space.
- Use `termWidth` and `termHeight` to get the terminal dimensions for bounds checking.

## See Also

- [border-example.md](docs/demos/border-example.md) - Complete example demonstrating border drawing
- [her.md](docs/demos/her.md) - Complex example with custom frame rendering
- `lib/canvas.nim` - Full canvas API documentation
