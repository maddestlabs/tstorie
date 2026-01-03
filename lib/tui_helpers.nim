## TUI Helpers - Stateless widget drawing primitives
##
## All functions are pure, FFI-safe, and work from both Nim code and nimini scripts.
##
## Design principles:
## - Stateless: All state passed as parameters
## - Layer-aware: Takes layer parameter for compositing
## - Theme-aware: Uses storieCtx.styleSheet for automatic theming
## - Progressive: Multiple levels of abstraction (low/mid/high)

import tables
import ../src/types  # Style, Color
import ../src/layers  # TermBuffer, writeText, Layer
import storie_types   # StyleConfig, StyleSheet
import ascii_art
import layout

# Import AppState and related types from src
import ../src/types

# Minimal toStyle implementation
proc toStyle(config: StyleConfig): Style =
  ## Convert StyleConfig to Style
  Style(
    fg: rgb(config.fg.r, config.fg.g, config.fg.b),
    bg: rgb(config.bg.r, config.bg.g, config.bg.b),
    bold: config.bold,
    italic: config.italic,
    underline: config.underline,
    dim: config.dim
  )

# Global state access (set by tstorie.nim at initialization)
# These will point to the actual global variables in tstorie.nim
var gStorieStyleSheet*: ptr Table[string, StyleConfig] = nil
var gAppStateRef*: AppState = nil  # AppState is already a ref object
var gDefaultLayerRef*: Layer = nil  # Layer 0 (the default layer)

# Helper to get style from name
proc tuiGetStyle(name: string): Style =
  ## Internal helper to get style by name
  if not gStorieStyleSheet.isNil and gStorieStyleSheet[].hasKey(name):
    return gStorieStyleSheet[][name].toStyle()
  return defaultStyle()

# Helper to draw on a layer (wraps the buffer write operation)
proc tuiDraw(layer: int, x, y: int, text: string, style: Style) =
  ## Internal helper to draw on a layer
  # Layer 0 is special - use gDefaultLayer
  if layer == 0:
    if not gDefaultLayerRef.isNil:
      gDefaultLayerRef.buffer.writeText(x, y, text, style)
  elif not gAppStateRef.isNil and layer > 0 and layer < gAppStateRef.layers.len:
    gAppStateRef.layers[layer].buffer.writeText(x, y, text, style)

# ==============================================================================
# BOX DRAWING
# ==============================================================================

proc drawBox*(layer: int, x, y, w, h: int, style: Style,
              topLeft, top, topRight: string,
              left, right: string,
              bottomLeft, bottom, bottomRight: string) =
  ## Draw a box with custom characters for each part
  ## 
  ## Example:
  ##   drawBox(0, 5, 5, 20, 10, myStyle,
  ##           "+", "-", "+",
  ##           "|", "|", 
  ##           "+", "-", "+")
  ##
  ## You can use any Unicode characters or ASCII art
  
  # Corners
  tuiDraw(layer, x, y, topLeft, style)
  tuiDraw(layer, x + w - 1, y, topRight, style)
  tuiDraw(layer, x, y + h - 1, bottomLeft, style)
  tuiDraw(layer, x + w - 1, y + h - 1, bottomRight, style)
  
  # Top and bottom edges
  for dx in 1 ..< w - 1:
    tuiDraw(layer, x + dx, y, top, style)
    tuiDraw(layer, x + dx, y + h - 1, bottom, style)
  
  # Left and right edges
  for dy in 1 ..< h - 1:
    tuiDraw(layer, x, y + dy, left, style)
    tuiDraw(layer, x + w - 1, y + dy, right, style)

proc drawBoxSimple*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a simple ASCII box (compatible with all terminals)
  drawBox(layer, x, y, w, h, style,
          "+", "-", "+",
          "|", "|",
          "+", "-", "+")

proc drawBoxSingle*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with single-line Unicode borders
  drawBox(layer, x, y, w, h, style,
          "┌", "─", "┐",
          "│", "│",
          "└", "─", "┘")

proc drawBoxDouble*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with double-line Unicode borders
  drawBox(layer, x, y, w, h, style,
          "╔", "═", "╗",
          "║", "║",
          "╚", "═", "╝")

proc drawBoxRounded*(layer: int, x, y, w, h: int, style: Style) =
  ## Draw a box with rounded Unicode corners
  drawBox(layer, x, y, w, h, style,
          "╭", "─", "╮",
          "│", "│",
          "╰", "─", "╯")

proc fillBox*(layer: int, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangular area with a character
  for dy in 0 ..< h:
    for dx in 0 ..< w:
      tuiDraw(layer, x + dx, y + dy, ch, style)

# ==============================================================================
# TEXT HELPERS
# ==============================================================================

proc centerTextX*(text: string, boxX, boxWidth: int): int =
  ## Calculate X position to center text in a box
  let textWidth = text.len  # Simple length for now
  result = boxX + (boxWidth - textWidth) div 2

proc centerTextY*(boxY, boxHeight: int): int =
  ## Calculate Y position to center vertically
  result = boxY + boxHeight div 2

proc drawCenteredText*(layer: int, x, y, w, h: int, text: string, style: Style) =
  ## Draw text centered in a box
  let tx = centerTextX(text, x, w)
  let ty = centerTextY(y, h)
  tuiDraw(layer, tx, ty, text, style)

proc truncateText*(text: string, maxWidth: int): string =
  ## Truncate text to fit maxWidth, adding "..." if needed
  if text.len <= maxWidth:
    return text
  
  if maxWidth <= 3:
    return "...".substr(0, maxWidth - 1)
  
  return text.substr(0, maxWidth - 4) & "..."

# ==============================================================================
# HIT TESTING
# ==============================================================================

proc pointInRect*(px, py, rx, ry, rw, rh: int): bool =
  ## Check if point is inside rectangle
  px >= rx and px < rx + rw and py >= ry and py < ry + rh

proc findClickedWidget*(mouseX, mouseY: int,
                       widgetX, widgetY, widgetW, widgetH: seq[int]): int =
  ## Find which widget was clicked (returns index, or -1)
  ## Checks from last to first (top layer to bottom)
  for i in countdown(widgetX.len - 1, 0):
    if pointInRect(mouseX, mouseY, widgetX[i], widgetY[i], 
                   widgetW[i], widgetH[i]):
      return i
  return -1

# ==============================================================================
# WIDGET RENDERING (High-level convenience)
# ==============================================================================

proc drawButton*(layer: int, x, y, w, h: int, label: string,
                isFocused: bool, isPressed: bool = false,
                borderStyle: string = "single") =
  ## Draw a complete button widget
  let baseStyle = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  if isPressed:
    # Filled when pressed
    fillBox(layer, x, y, w, h, "█", tuiGetStyle("button"))
    drawCenteredText(layer, x, y, w, h, label, tuiGetStyle("button"))
  else:
    # Box with centered label
    case borderStyle
    of "simple":
      drawBoxSimple(layer, x, y, w, h, baseStyle)
    of "double":
      drawBoxDouble(layer, x, y, w, h, baseStyle)
    of "rounded":
      drawBoxRounded(layer, x, y, w, h, baseStyle)
    else:
      drawBoxSingle(layer, x, y, w, h, baseStyle)
    
    drawCenteredText(layer, x, y, w, h, label, baseStyle)

proc drawLabel*(layer: int, x, y: int, text: string, style: Style) =
  ## Draw a simple text label
  tuiDraw(layer, x, y, text, style)

proc drawTextBox*(layer: int, x, y, w, h: int, 
                 content: string, cursorPos: int,
                 isFocused: bool, borderStyle: string = "single") =
  ## Draw a text input box with cursor
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  # Draw border
  case borderStyle
  of "simple":
    drawBoxSimple(layer, x, y, w, h, style)
  of "double":
    drawBoxDouble(layer, x, y, w, h, style)
  of "rounded":
    drawBoxRounded(layer, x, y, w, h, style)
  else:
    drawBoxSingle(layer, x, y, w, h, style)
  
  # Draw content (simple, no scrolling for now)
  let contentY = centerTextY(y, h)
  let maxLen = w - 2
  let visibleContent = if content.len > maxLen: 
                        content[0..<maxLen]
                      else: 
                        content
  tuiDraw(layer, x + 1, contentY, visibleContent, style)
  
  # Draw cursor if focused
  if isFocused and cursorPos >= 0 and cursorPos <= content.len:
    let cursorX = x + 1 + min(cursorPos, maxLen - 1)
    tuiDraw(layer, cursorX, contentY, "_", tuiGetStyle("warning"))

proc drawSlider*(layer: int, x, y, w: int, value: float,
                minVal, maxVal: float, isFocused: bool) =
  ## Draw a slider widget (horizontal)
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  # Draw track
  for dx in 0..<w:
    tuiDraw(layer, x + dx, y, "─", style)
  
  # Draw handle
  let normalizedVal = (value - minVal) / (maxVal - minVal)
  let handleX = x + int(normalizedVal * float(w - 1))
  tuiDraw(layer, handleX, y, "█", tuiGetStyle("warning"))
  
  # Draw value text below
  let valueText = $int(value)
  tuiDraw(layer, x + w - valueText.len, y + 1, valueText, style)

proc drawCheckBox*(layer: int, x, y: int, label: string,
                  isChecked: bool, isFocused: bool) =
  ## Draw a checkbox with label
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  # Draw box
  tuiDraw(layer, x, y, "[", style)
  let checkChar = if isChecked: "X" else: " "
  tuiDraw(layer, x + 1, y, checkChar, style)
  tuiDraw(layer, x + 2, y, "]", style)
  
  # Draw label
  tuiDraw(layer, x + 4, y, label, tuiGetStyle("default"))

proc drawPanel*(layer: int, x, y, w, h: int, title: string,
               borderStyle: string = "single") =
  ## Draw a titled panel/frame
  let style = tuiGetStyle("border")
  
  # Draw border
  case borderStyle
  of "simple":
    drawBoxSimple(layer, x, y, w, h, style)
  of "double":
    drawBoxDouble(layer, x, y, w, h, style)
  of "rounded":
    drawBoxRounded(layer, x, y, w, h, style)
  else:
    drawBoxSingle(layer, x, y, w, h, style)
  
  # Draw title in top border
  if title.len > 0:
    let titleText = " " & truncateText(title, w - 4) & " "
    let titleX = centerTextX(titleText, x, w)
    tuiDraw(layer, titleX, y, titleText, tuiGetStyle("info"))

proc drawProgressBar*(layer: int, x, y, w: int, progress: float,
                     showPercent: bool = true) =
  ## Draw a progress bar (0.0 to 1.0)
  let style = tuiGetStyle("border")
  let fillStyle = tuiGetStyle("info")
  
  # Draw border
  tuiDraw(layer, x, y, "[", style)
  tuiDraw(layer, x + w - 1, y, "]", style)
  
  # Fill bar
  let fillWidth = int(progress * float(w - 2))
  for dx in 0 ..< fillWidth:
    tuiDraw(layer, x + 1 + dx, y, "█", fillStyle)
  
  # Empty space
  for dx in fillWidth ..< (w - 2):
    tuiDraw(layer, x + 1 + dx, y, " ", style)
  
  # Optional percentage
  if showPercent:
    let percentText = $(int(progress * 100)) & "%"
    let textX = centerTextX(percentText, x, w)
    tuiDraw(layer, textX, y, percentText, tuiGetStyle("warning"))

proc drawSeparator*(layer: int, x, y, w: int, style: Style, ch: string = "─") =
  ## Draw a horizontal separator line
  for dx in 0 ..< w:
    tuiDraw(layer, x + dx, y, ch, style)

# ==============================================================================
# LAYOUT HELPERS
# ==============================================================================

proc layoutVertical*(startY, spacing, count: int): seq[int] =
  ## Calculate Y positions for vertical layout
  result = newSeq[int](count)
  var y = startY
  for i in 0..<count:
    result[i] = y
    y += spacing

proc layoutHorizontal*(startX, spacing, count: int): seq[int] =
  ## Calculate X positions for horizontal layout
  result = newSeq[int](count)
  var x = startX
  for i in 0..<count:
    result[i] = x
    x += spacing

proc layoutGrid*(startX, startY, cols, rows, 
                cellWidth, cellHeight, 
                spacingX, spacingY: int): seq[tuple[x, y: int]] =
  ## Calculate positions for grid layout
  result = @[]
  for row in 0..<rows:
    for col in 0..<cols:
      let x = startX + col * (cellWidth + spacingX)
      let y = startY + row * (cellHeight + spacingY)
      result.add((x, y))

proc layoutCentered*(containerX, containerY, containerW, containerH,
                    itemW, itemH: int): tuple[x, y: int] =
  ## Center an item within a container
  result.x = containerX + (containerW - itemW) div 2
  result.y = containerY + (containerH - itemH) div 2

# ==============================================================================
# EXPORTS
# ==============================================================================

# Export everything for use in other modules
export drawBox, drawBoxSimple, drawBoxSingle, drawBoxDouble, drawBoxRounded, fillBox
export centerTextX, centerTextY, drawCenteredText, truncateText
export pointInRect, findClickedWidget
export drawButton, drawLabel, drawTextBox, drawSlider, drawCheckBox
export drawPanel, drawProgressBar, drawSeparator
export layoutVertical, layoutHorizontal, layoutGrid, layoutCentered
