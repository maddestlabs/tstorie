## Drawing Module
## Provides convenient drawing functions for use with Nimini scripts
## Works with both background and foreground layers

import ../tstorie

# Figlet font data for digital clock
const figletDigits* = [
  # 0
  ["+---+", "|   |", "|   |", "|   |", "+---+"],
  # 1
  ["    |", "    |", "    |", "    |", "    |"],
  # 2
  ["+---+", "    |", "+---+", "|    ", "+---+"],
  # 3
  ["+---+", "    |", "+---+", "    |", "+---+"],
  # 4
  ["|   |", "|   |", "+---+", "    |", "    |"],
  # 5
  ["+---+", "|    ", "+---+", "    |", "+---+"],
  # 6
  ["+---+", "|    ", "+---+", "|   |", "+---+"],
  # 7
  ["+---+", "    |", "    |", "    |", "    |"],
  # 8
  ["+---+", "|   |", "+---+", "|   |", "+---+"],
  # 9
  ["+---+", "|   |", "+---+", "    |", "+---+"]
]

const figletColon* = [" ", "o", " ", "o", " "]

# ================================================================
# BACKGROUND LAYER OPERATIONS
# ================================================================

proc bgClear*(layer: Layer) =
  ## Clear the background layer buffer
  layer.buffer.clear()

proc bgClearTransparent*(layer: Layer) =
  ## Clear the background layer buffer with transparency
  layer.buffer.clearTransparent()

proc bgWrite*(layer: Layer, x, y: int, ch: string, style: Style) =
  ## Write a single character to the background layer
  layer.buffer.write(x, y, ch, style)

proc bgWriteText*(layer: Layer, x, y: int, text: string, style: Style) =
  ## Write a text string to the background layer
  layer.buffer.writeText(x, y, text, style)

proc bgFillRect*(layer: Layer, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangle on the background layer
  layer.buffer.fillRect(x, y, w, h, ch, style)

# ================================================================
# FOREGROUND LAYER OPERATIONS
# ================================================================

proc fgClear*(layer: Layer) =
  ## Clear the foreground layer buffer
  layer.buffer.clear()

proc fgClearTransparent*(layer: Layer) =
  ## Clear the foreground layer buffer with transparency
  layer.buffer.clearTransparent()

proc fgWrite*(layer: Layer, x, y: int, ch: string, style: Style) =
  ## Write a single character to the foreground layer
  layer.buffer.write(x, y, ch, style)

proc fgWriteText*(layer: Layer, x, y: int, text: string, style: Style) =
  ## Write a text string to the foreground layer
  layer.buffer.writeText(x, y, text, style)

proc fgFillRect*(layer: Layer, x, y, w, h: int, ch: string, style: Style) =
  ## Fill a rectangle on the foreground layer
  layer.buffer.fillRect(x, y, w, h, ch, style)

# ================================================================
# SPECIAL DRAWING FUNCTIONS
# ================================================================

proc drawFigletDigit*(layer: Layer, digit, x, y: int, style: Style) =
  ## Draw a figlet digit at x, y position
  ## digit: 0-9 for numbers, 10 for colon
  if digit >= 0 and digit <= 9:
    for line in 0..4:
      layer.buffer.writeText(x, y + line, figletDigits[digit][line], style)
  elif digit == 10:  # Colon
    for line in 0..4:
      layer.buffer.writeText(x, y + line, figletColon[line], style)
