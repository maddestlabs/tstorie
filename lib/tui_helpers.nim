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
import ../nimini/auto_bindings  # Auto-binding system

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

# ==============================================================================
# PATTERN: Simple Style functions → Auto-expose
# These functions have straightforward parameters (int + Style) and delegate
# to internal helpers. Perfect candidates for auto-bindings.
# ==============================================================================

proc drawBoxSimple*(layer: int, x, y, w, h: int, style: Style) {.autoExpose: "tui".} =
  ## Draw a simple ASCII box (compatible with all terminals)
  drawBox(layer, x, y, w, h, style,
          "+", "-", "+",
          "|", "|",
          "+", "-", "+")

proc drawBoxSingle*(layer: int, x, y, w, h: int, style: Style) {.autoExpose: "tui".} =
  ## Draw a box with single-line Unicode borders
  drawBox(layer, x, y, w, h, style,
          "┌", "─", "┐",
          "│", "│",
          "└", "─", "┘")

proc drawBoxDouble*(layer: int, x, y, w, h: int, style: Style) {.autoExpose: "tui".} =
  ## Draw a box with double-line Unicode borders
  drawBox(layer, x, y, w, h, style,
          "╔", "═", "╗",
          "║", "║",
          "╚", "═", "╝")

proc drawBoxRounded*(layer: int, x, y, w, h: int, style: Style) {.autoExpose: "tui".} =
  ## Draw a box with rounded Unicode corners
  drawBox(layer, x, y, w, h, style,
          "╭", "─", "╮",
          "│", "│",
          "╰", "─", "╯")

proc fillBox*(layer: int, x, y, w, h: int, ch: string, style: Style) {.autoExpose: "tui".} =
  ## Fill a rectangular area with a character
  for dy in 0 ..< h:
    for dx in 0 ..< w:
      tuiDraw(layer, x + dx, y + dy, ch, style)

# ==============================================================================
# TEXT HELPERS
# ==============================================================================
# PATTERN: Simple utility functions → Auto-expose
# Pure calculation functions with basic types are ideal for auto-bindings.
# ==============================================================================

proc centerTextX*(text: string, boxX, boxWidth: int): int {.autoExpose: "tui".} =
  ## Calculate X position to center text in a box
  let textWidth = text.len  # Simple length for now
  result = boxX + (boxWidth - textWidth) div 2

proc centerTextY*(boxY, boxHeight: int): int {.autoExpose: "tui".} =
  ## Calculate Y position to center vertically
  result = boxY + boxHeight div 2

proc drawCenteredText*(layer: int, x, y, w, h: int, text: string, style: Style) {.autoExpose: "tui".} =
  ## Draw text centered in a box
  let tx = centerTextX(text, x, w)
  let ty = centerTextY(y, h)
  tuiDraw(layer, tx, ty, text, style)

proc truncateText*(text: string, maxWidth: int): string {.autoExpose: "tui".} =
  ## Truncate text to fit maxWidth, adding "..." if needed
  if text.len <= maxWidth:
    return text
  
  if maxWidth <= 3:
    return "...".substr(0, maxWidth - 1)
  
  return text.substr(0, maxWidth - 4) & "..."

# ==============================================================================
# HIT TESTING
# ==============================================================================

proc pointInRect*(px, py, rx, ry, rw, rh: int): bool {.autoExpose: "tui".} =
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

proc drawLabel*(layer: int, x, y: int, text: string, style: Style) {.autoExpose: "tui".} =
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
  ## Draw a titled panel/frame with filled interior
  let style = tuiGetStyle("border")
  let bgStyle = tuiGetStyle("default")
  
  # Fill interior with spaces to clear background content
  fillBox(layer, x, y, w, h, " ", bgStyle)
  
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

proc drawSeparator*(layer: int, x, y, w: int, style: Style, ch: string = "─") {.autoExpose: "tui".} =
  ## Draw a horizontal separator line
  for dx in 0 ..< w:
    tuiDraw(layer, x + dx, y, ch, style)

# ==============================================================================
# LAYOUT HELPERS
# ==============================================================================
# PATTERN: Functions with seq/tuple returns → Auto-expose
# type_converters.nim handles seq[int] and tuple conversions automatically.
# ==============================================================================

proc layoutVertical*(startY, spacing, count: int): seq[int] {.autoExpose: "tui".} =
  ## Calculate Y positions for vertical layout
  result = newSeq[int](count)
  var y = startY
  for i in 0..<count:
    result[i] = y
    y += spacing

proc layoutHorizontal*(startX, spacing, count: int): seq[int] {.autoExpose: "tui".} =
  ## Calculate X positions for horizontal layout
  result = newSeq[int](count)
  var x = startX
  for i in 0..<count:
    result[i] = x
    x += spacing

proc layoutGrid*(startX, startY, cols, rows, 
                cellWidth, cellHeight, 
                spacingX, spacingY: int): seq[tuple[x, y: int]] {.autoExpose: "tui".} =
  ## Calculate positions for grid layout
  result = @[]
  for row in 0..<rows:
    for col in 0..<cols:
      let x = startX + col * (cellWidth + spacingX)
      let y = startY + row * (cellHeight + spacingY)
      result.add((x, y))

proc layoutCentered*(containerX, containerY, containerW, containerH,
                    itemW, itemH: int): tuple[x, y: int] {.autoExpose: "tui".} =
  ## Center an item within a container
  result.x = containerX + (containerW - itemW) div 2
  result.y = containerY + (containerH - itemH) div 2

# ==============================================================================
# INPUT HANDLING HELPERS
# ==============================================================================

proc handleTextInput*(text: string, cursorPos: var int, content: var string): bool =
  ## Handle text input for text fields
  ## Returns true if input was handled
  content = content & text
  cursorPos = cursorPos + 1
  return true

proc handleBackspace*(cursorPos: var int, content: var string): bool =
  ## Handle backspace for text fields
  ## Returns true if input was handled
  if cursorPos > 0 and content.len > 0:
    content = content[0..<content.len - 1]
    cursorPos = cursorPos - 1
    return true
  return false

proc handleArrowKeys*(keyCode: int, value: var float, minVal, maxVal, step: float): bool =
  ## Handle arrow keys for sliders/numeric inputs
  ## keyCode: 37=Left, 38=Up, 39=Right, 40=Down
  ## Returns true if input was handled
  if keyCode == 37 or keyCode == 40:  # Left or Down
    value = value - step
    if value < minVal:
      value = minVal
    return true
  elif keyCode == 39 or keyCode == 38:  # Right or Up
    value = value + step
    if value > maxVal:
      value = maxVal
    return true
  return false

# ==============================================================================
# RADIO BUTTON WIDGET
# ==============================================================================

proc drawRadioButton*(layer: int, x, y: int, label: string,
                     isSelected: bool, isFocused: bool) =
  ## Draw a single radio button with label
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  # Draw radio button
  tuiDraw(layer, x, y, "(", style)
  let selectChar = if isSelected: "•" else: " "
  tuiDraw(layer, x + 1, y, selectChar, style)
  tuiDraw(layer, x + 2, y, ")", style)
  
  # Draw label
  tuiDraw(layer, x + 4, y, label, tuiGetStyle("default"))

proc drawRadioGroup*(layer: int, x, y: int, options: seq[string], 
                    selected: int, focusIndex: int) =
  ## Draw a group of radio buttons (vertical layout)
  ## focusIndex: which option is focused (-1 for none)
  for i in 0..<options.len:
    let optY = y + i
    let isSelected = i == selected
    let isFocused = i == focusIndex
    drawRadioButton(layer, x, optY, options[i], isSelected, isFocused)

# ==============================================================================
# DROPDOWN/SELECT WIDGET
# ==============================================================================

proc drawDropdown*(layer: int, x, y, w: int, options: seq[string],
                  selected: int, isOpen: bool, isFocused: bool) =
  ## Draw a dropdown/select widget
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  
  if not isOpen:
    # Draw closed dropdown
    drawBoxSingle(layer, x, y, w, 3, style)
    
    # Draw selected option
    if selected >= 0 and selected < options.len:
      let selectedText = truncateText(options[selected], w - 4)
      tuiDraw(layer, x + 2, y + 1, selectedText, tuiGetStyle("default"))
    
    # Draw dropdown arrow
    tuiDraw(layer, x + w - 3, y + 1, "▼", style)
  else:
    # Draw open dropdown with options
    let dropHeight = min(options.len + 2, 10)  # Max 10 items visible
    drawBoxSingle(layer, x, y, w, dropHeight, style)
    
    # Draw options
    for i in 0..<min(options.len, 8):
      let optY = y + 1 + i
      let optText = truncateText(options[i], w - 4)
      let optStyle = if i == selected: tuiGetStyle("info") else: tuiGetStyle("default")
      tuiDraw(layer, x + 2, optY, optText, optStyle)

# ==============================================================================
# LIST/MENU WIDGET
# ==============================================================================

proc drawList*(layer: int, x, y, w, h: int, items: seq[string], 
              selected: int, scrollOffset: int, isFocused: bool) =
  ## Draw a scrollable list with keyboard navigation
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  drawBoxSingle(layer, x, y, w, h, style)
  
  # Draw visible items
  let maxVisible = h - 2
  let endIdx = min(scrollOffset + maxVisible, items.len)
  
  for i in scrollOffset..<endIdx:
    let itemY = y + 1 + (i - scrollOffset)
    let itemText = truncateText(items[i], w - 4)
    let itemStyle = if i == selected: tuiGetStyle("info") else: tuiGetStyle("default")
    
    if i == selected:
      # Highlight selected item
      fillBox(layer, x + 1, itemY, w - 2, 1, " ", tuiGetStyle("button"))
    
    tuiDraw(layer, x + 2, itemY, itemText, itemStyle)
  
  # Draw scrollbar if needed
  if items.len > maxVisible:
    let scrollbarHeight = h - 2
    let scrollbarPos = int((float(scrollOffset) / float(items.len - maxVisible)) * float(scrollbarHeight - 1))
    tuiDraw(layer, x + w - 1, y + 1 + scrollbarPos, "█", tuiGetStyle("warning"))

# ==============================================================================
# TEXT AREA (MULTI-LINE)
# ==============================================================================

proc drawTextArea*(layer: int, x, y, w, h: int, lines: seq[string],
                  cursorLine, cursorCol, scrollY: int, isFocused: bool) =
  ## Draw a multi-line text area with scrolling
  let style = if isFocused: tuiGetStyle("info") else: tuiGetStyle("border")
  drawBoxSingle(layer, x, y, w, h, style)
  
  # Draw visible lines
  let maxVisible = h - 2
  let endLine = min(scrollY + maxVisible, lines.len)
  
  for i in scrollY..<endLine:
    let lineY = y + 1 + (i - scrollY)
    let lineText = if lines[i].len > w - 4:
                     lines[i][0..<(w - 4)]
                   else:
                     lines[i]
    tuiDraw(layer, x + 2, lineY, lineText, tuiGetStyle("default"))
    
    # Draw cursor if on this line and focused
    if isFocused and i == cursorLine:
      let cursorX = x + 2 + min(cursorCol, w - 4)
      tuiDraw(layer, cursorX, lineY, "_", tuiGetStyle("warning"))
  
  # Line number indicator
  let lineInfo = $(cursorLine + 1) & ":" & $(cursorCol + 1)
  tuiDraw(layer, x + 2, y + h - 1, lineInfo, tuiGetStyle("info"))

# ==============================================================================
# TOOLTIP WIDGET
# ==============================================================================

proc drawTooltip*(layer: int, x, y: int, text: string) =
  ## Draw a tooltip (floating help text)
  let w = text.len + 4
  let h = 3
  let style = tuiGetStyle("warning")
  
  # Draw semi-transparent background (using dim style)
  fillBox(layer, x, y, w, h, " ", tuiGetStyle("button"))
  drawBoxSingle(layer, x, y, w, h, style)
  tuiDraw(layer, x + 2, y + 1, text, style)

# ==============================================================================
# TAB CONTAINER WIDGET
# ==============================================================================

proc drawTabBar*(layer: int, x, y, w: int, tabs: seq[string], activeTab: int) =
  ## Draw a tab bar at the top of a container
  var currentX = x + 1
  
  for i in 0..<tabs.len:
    let tabText = " " & tabs[i] & " "
    let tabWidth = tabText.len
    let style = if i == activeTab: tuiGetStyle("info") else: tuiGetStyle("border")
    
    # Draw tab
    if i == activeTab:
      # Active tab
      tuiDraw(layer, currentX, y, "┌", style)
      for dx in 1..<tabWidth - 1:
        tuiDraw(layer, currentX + dx, y, "─", style)
      tuiDraw(layer, currentX + tabWidth - 1, y, "┐", style)
      tuiDraw(layer, currentX, y + 1, "│", style)
      tuiDraw(layer, currentX + tabWidth - 1, y + 1, "│", style)
    else:
      # Inactive tab
      tuiDraw(layer, currentX, y + 1, "│", style)
      tuiDraw(layer, currentX + tabWidth - 1, y + 1, "│", style)
    
    # Tab label
    tuiDraw(layer, currentX + 1, y + 1, tabs[i], style)
    currentX += tabWidth + 1

proc drawTabContent*(layer: int, x, y, w, h: int, borderStyle: string = "single") =
  ## Draw the content area below tabs
  let style = tuiGetStyle("border")
  
  # Draw top line connecting to tabs
  tuiDraw(layer, x, y, "├", style)
  for dx in 1..<w - 1:
    tuiDraw(layer, x + dx, y, "─", style)
  tuiDraw(layer, x + w - 1, y, "┤", style)
  
  # Draw sides and bottom
  for dy in 1..<h - 1:
    tuiDraw(layer, x, y + dy, "│", style)
    tuiDraw(layer, x + w - 1, y + dy, "│", style)
  
  tuiDraw(layer, x, y + h - 1, "└", style)
  for dx in 1..<w - 1:
    tuiDraw(layer, x + dx, y + h - 1, "─", style)
  tuiDraw(layer, x + w - 1, y + h - 1, "┘", style)

# ==============================================================================
# FORM LAYOUT HELPER
# ==============================================================================

proc layoutForm*(startX, startY, labelWidth, fieldWidth, fieldHeight, 
                spacing: int, fieldCount: int): seq[tuple[labelX, labelY, fieldX, fieldY: int]] =
  ## Calculate positions for form fields (label + input pairs)
  result = @[]
  var currentY = startY
  
  for i in 0..<fieldCount:
    let labelX = startX
    let labelY = currentY + (fieldHeight div 2)  # Vertically center label
    let fieldX = startX + labelWidth + 2
    let fieldY = currentY
    
    result.add((labelX, labelY, fieldX, fieldY))
    currentY += fieldHeight + spacing

# ==============================================================================
# ENHANCED TEXT BOX WITH SCROLLING
# ==============================================================================

proc drawTextBoxWithScroll*(layer: int, x, y, w, h: int, content: string,
                           cursorPos, scrollOffset: int, isFocused: bool,
                           borderStyle: string = "single"): int =
  ## Draw a text input box with horizontal scrolling
  ## Returns the new scroll offset
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
  
  # Calculate visible area
  let contentY = centerTextY(y, h)
  let maxLen = w - 4  # Leave padding
  
  # Calculate scroll offset to keep cursor visible
  var newScrollOffset = scrollOffset
  if cursorPos < newScrollOffset:
    newScrollOffset = cursorPos
  elif cursorPos >= newScrollOffset + maxLen:
    newScrollOffset = cursorPos - maxLen + 1
  
  # Extract visible portion
  let visibleStart = newScrollOffset
  let visibleEnd = min(content.len, visibleStart + maxLen)
  let visibleContent = if visibleStart < content.len:
                         content[visibleStart..<visibleEnd]
                       else:
                         ""
  
  # Draw content
  tuiDraw(layer, x + 2, contentY, visibleContent, style)
  
  # Draw cursor if focused
  if isFocused and cursorPos >= 0 and cursorPos <= content.len:
    let relativeCursorPos = cursorPos - newScrollOffset
    if relativeCursorPos >= 0 and relativeCursorPos < maxLen:
      let cursorX = x + 2 + relativeCursorPos
      tuiDraw(layer, cursorX, contentY, "_", tuiGetStyle("warning"))
  
  # Draw scroll indicators
  if newScrollOffset > 0:
    tuiDraw(layer, x + 1, contentY, "◀", tuiGetStyle("warning"))
  if visibleEnd < content.len:
    tuiDraw(layer, x + w - 2, contentY, "▶", tuiGetStyle("warning"))
  
  return newScrollOffset

# ==============================================================================
# VIEWPORT / SCROLLABLE CONTAINER
# ==============================================================================

proc drawViewport*(layer: int, x, y, viewW, viewH: int,
                   content: seq[string], scrollY: int,
                   borderStyle: string = "single"): tuple[needsScrollbar: bool, maxScrollY: int] =
  ## Generic scrollable viewport for line-based content
  ## 
  ## Parameters:
  ##   layer: Which layer to draw on
  ##   x, y: Top-left position of the viewport
  ##   viewW, viewH: Width and height of the viewport (including border)
  ##   content: Array of strings, each representing a line
  ##   scrollY: Current vertical scroll position (line index)
  ##   borderStyle: "simple", "single", "double", or "rounded"
  ## 
  ## Returns:
  ##   needsScrollbar: True if content is larger than viewport
  ##   maxScrollY: Maximum valid scroll position
  ## 
  ## Example:
  ##   let lines = @["Line 1", "Line 2", "Line 3", ...]
  ##   let info = drawViewport(1, 10, 10, 40, 15, lines, myScrollPos)
  ##   # Use info.maxScrollY to clamp scroll input
  
  let style = tuiGetStyle("border")
  
  # Draw border
  case borderStyle
  of "simple":
    drawBoxSimple(layer, x, y, viewW, viewH, style)
  of "double":
    drawBoxDouble(layer, x, y, viewW, viewH, style)
  of "rounded":
    drawBoxRounded(layer, x, y, viewW, viewH, style)
  else:
    drawBoxSingle(layer, x, y, viewW, viewH, style)
  
  let contentHeight = viewH - 2  # Account for top and bottom borders
  let contentWidth = viewW - 4   # Account for borders and padding
  let startLine = scrollY
  let endLine = min(scrollY + contentHeight, content.len)
  
  # Draw visible lines
  for i in startLine..<endLine:
    let lineY = y + 1 + (i - scrollY)
    let lineText = truncateText(content[i], contentWidth)
    tuiDraw(layer, x + 2, lineY, lineText, tuiGetStyle("default"))
  
  # Draw scrollbar if content is larger than viewport
  let needsScroll = content.len > contentHeight
  if needsScroll:
    let scrollbarHeight = contentHeight
    let scrollRange = content.len - contentHeight
    let scrollbarPos = if scrollRange > 0:
                         int((float(scrollY) / float(scrollRange)) * 
                             float(scrollbarHeight - 1))
                       else:
                         0
    tuiDraw(layer, x + viewW - 2, y + 1 + scrollbarPos, "█", tuiGetStyle("info"))
  
  result.needsScrollbar = needsScroll
  result.maxScrollY = max(0, content.len - contentHeight)

proc drawViewportNoReturn*(layer: int, x, y, viewW, viewH: int,
                           content: seq[string], scrollY: int,
                           borderStyle: string = "single") =
  ## Simplified viewport without return value (easier for scripting)
  discard drawViewport(layer, x, y, viewW, viewH, content, scrollY, borderStyle)

# ==============================================================================
# SCROLL MANAGEMENT HELPERS
# ==============================================================================

proc updateScroll*(currentScroll: int, maxScroll: int, delta: int): int =
  ## Update scroll position with bounds checking
  ## 
  ## Parameters:
  ##   currentScroll: Current scroll position
  ##   maxScroll: Maximum allowed scroll position
  ##   delta: Amount to scroll (negative = up, positive = down)
  ## 
  ## Returns:
  ##   New scroll position, clamped to [0, maxScroll]
  result = currentScroll + delta
  if result < 0:
    result = 0
  elif result > maxScroll:
    result = maxScroll

proc handleScrollKeys*(keyCode: int, scrollY: var int, maxScrollY: int,
                      pageSize: int = 10): bool =
  ## Handle keyboard scrolling (Up/Down/PageUp/PageDown/Home/End)
  ## 
  ## Parameters:
  ##   keyCode: Key code from keyboard event
  ##     38 = Up arrow, 40 = Down arrow
  ##     33 = Page Up, 34 = Page Down
  ##     36 = Home, 35 = End
  ##   scrollY: Current scroll position (will be modified)
  ##   maxScrollY: Maximum scroll position
  ##   pageSize: Lines to scroll for Page Up/Down
  ## 
  ## Returns:
  ##   True if the key was handled, false otherwise
  case keyCode
  of 38:  # Up arrow
    scrollY = updateScroll(scrollY, maxScrollY, -1)
    return true
  of 40:  # Down arrow
    scrollY = updateScroll(scrollY, maxScrollY, 1)
    return true
  of 33:  # Page Up
    scrollY = updateScroll(scrollY, maxScrollY, -pageSize)
    return true
  of 34:  # Page Down
    scrollY = updateScroll(scrollY, maxScrollY, pageSize)
    return true
  of 36:  # Home
    scrollY = 0
    return true
  of 35:  # End
    scrollY = maxScrollY
    return true
  else:
    return false

proc clampScroll*(scrollY: int, maxScrollY: int): int =
  ## Clamp scroll position to valid range [0, maxScrollY]
  if scrollY < 0:
    return 0
  elif scrollY > maxScrollY:
    return maxScrollY
  else:
    return scrollY

proc calculateMaxScroll*(contentLines: int, viewportHeight: int): int =
  ## Calculate maximum scroll position for given content and viewport
  ## 
  ## Parameters:
  ##   contentLines: Total number of lines in content
  ##   viewportHeight: Height of viewport (including borders)
  ## 
  ## Returns:
  ##   Maximum scroll position (0 if content fits in viewport)
  let contentHeight = viewportHeight - 2  # Account for borders
  result = max(0, contentLines - contentHeight)

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
# Internal helpers (for text_editor and other internal modules)
export tuiGetStyle, tuiDraw
# New exports
export handleTextInput, handleBackspace, handleArrowKeys
export drawRadioButton, drawRadioGroup
export drawDropdown
export drawList
export drawTextArea
export drawTooltip
export drawTabBar, drawTabContent
export layoutForm
export drawTextBoxWithScroll
# Viewport exports
export drawViewport, drawViewportNoReturn
export updateScroll, handleScrollKeys, clampScroll, calculateMaxScroll
