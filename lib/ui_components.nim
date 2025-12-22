## UI Components Module
## Reusable UI component utilities
## 
## Note: This module expects Color, Style, AppState, Layer, and color functions
## (white, blue, yellow, black) to be available from the importing/including context.
##
## NOTE: Button and other interactive widgets have been moved to lib/tui.nim
## This module now contains only simple drawing utilities.

# ================================================================
# BOX DRAWING
# ================================================================

proc drawBox*(state: AppState, x, y, w, h: int, style: Style, title: string = "") =
  ## Draw a box with optional title
  ## This is a simple reusable component that works directly with AppState
  
  # Top border
  state.currentBuffer.write(x, y, "┌", style)
  for i in 1 ..< w-1:
    state.currentBuffer.write(x + i, y, "─", style)
  state.currentBuffer.write(x + w - 1, y, "┐", style)
  
  # Title if provided
  if title.len > 0 and w > title.len + 4:
    let titleX = x + (w - title.len - 2) div 2
    state.currentBuffer.write(titleX, y, "┤", style)
    state.currentBuffer.writeText(titleX + 1, y, title, style)
    state.currentBuffer.write(titleX + title.len + 1, y, "├", style)
  
  # Sides
  for i in 1 ..< h-1:
    state.currentBuffer.write(x, y + i, "│", style)
    state.currentBuffer.write(x + w - 1, y + i, "│", style)
  
  # Bottom border
  state.currentBuffer.write(x, y + h - 1, "└", style)
  for i in 1 ..< w-1:
    state.currentBuffer.write(x + i, y + h - 1, "─", style)
  state.currentBuffer.write(x + w - 1, y + h - 1, "┘", style)

proc drawBoxOnLayer*(layer: Layer, x, y, w, h: int, style: Style, title: string = "") =
  ## Draw a box directly on a layer
  ## Same as drawBox but works with layers
  
  # Top border
  layer.buffer.write(x, y, "┌", style)
  for i in 1 ..< w-1:
    layer.buffer.write(x + i, y, "─", style)
  layer.buffer.write(x + w - 1, y, "┐", style)
  
  # Title if provided
  if title.len > 0 and w > title.len + 4:
    let titleX = x + (w - title.len - 2) div 2
    layer.buffer.write(titleX, y, "┤", style)
    layer.buffer.writeText(titleX + 1, y, title, style)
    layer.buffer.write(titleX + title.len + 1, y, "├", style)
  
  # Sides
  for i in 1 ..< h-1:
    layer.buffer.write(x, y + i, "│", style)
    layer.buffer.write(x + w - 1, y + i, "│", style)
  
  # Bottom border
  layer.buffer.write(x, y + h - 1, "└", style)
  for i in 1 ..< w-1:
    layer.buffer.write(x + i, y + h - 1, "─", style)
  layer.buffer.write(x + w - 1, y + h - 1, "┘", style)

# ================================================================
# PROGRESS BAR
# ================================================================

proc drawProgressBar*(state: AppState, x, y, width: int, progress: float, 
                     style: Style, label: string = "") =
  ## Draw a progress bar (0.0 to 1.0)
  let filled = int(progress * float(width))
  
  for i in 0 ..< width:
    if i < filled:
      state.currentBuffer.write(x + i, y, "█", style)
    else:
      state.currentBuffer.write(x + i, y, "░", style)
  
  if label.len > 0:
    let labelX = x + (width - label.len) div 2
    var labelStyle = style
    labelStyle.bold = true
    state.currentBuffer.writeText(labelX, y, label, labelStyle)
