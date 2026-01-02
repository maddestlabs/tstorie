# Figlet Helper Function

## Overview

The `drawFigletText` function is a convenience helper that combines figlet text rendering and drawing into a single call, eliminating the need to manually loop through lines.

## Function Signature

```nim
drawFigletText(layer, x, y, fontName, text, [layoutMode], [style], [vertical], [letterSpacing])
```

### Parameters

- `layer` (int): The layer to draw on (0 for default layer)
- `x` (int): X coordinate for the start of the text
- `y` (int): Y coordinate for the first line of text
- `fontName` (string): Name of the loaded figlet font
- `text` (string): Text to render
- `layoutMode` (int, optional): Layout mode (0=FullWidth, 1=HorizontalFitting, 2=HorizontalSmushing). Default: 0
- `style` (Style, optional): Style to apply to the text. Default: defaultStyle()
- `vertical` (bool/int, optional): Drawing direction. Default: 0/false
  - 0/false: Horizontal (left-to-right, top-to-bottom)
  - 1/true: Vertical (each character printed downward from y coordinate)
- `letterSpacing` (int, optional): Number of empty spaces to add between characters. Default: 0

## Usage Examples

### Basic Usage

```nim
# Load the font first
figletLoadFont("standard")

# Draw figlet text
drawFigletText(0, 10, 5, "standard", "HELLO")
```

### With Layout Mode

```nim
# Use horizontal smushing for compact text
drawFigletText(0, 10, 5, "standard", "HELLO", 2)
```

### With Style

```nim
var style = defaultStyle()
style.fg = 2  # Green

drawFigletText(0, 10, 5, "standard", "HELLO", 0, style)
```

### With Letter Spacing

```nim
# Add 3 spaces between each character
drawFigletText(0, 10, 5, "standard", "HELLO", 0, 0, 0, 3)
```

### Vertical Text

```nim
# Draw text vertically (each character stacked downward)
drawFigletText(0, 10, 5, "standard", "HELLO", 0, 0, 1)

# Vertical with letter spacing (adds space between characters)
drawFigletText(0, 10, 5, "standard", "HELLO", 0, 0, 1, 2)
```

## Before and After

### Before (Manual Drawing)

```nim
var lines = figletRender("standard", "HELLO")
var y = 5
for line in lines:
  draw(0, 10, y, line)
  y = y + 1
```

### After (Using Helper)

```nim
drawFigletText(0, 10, 5, "standard", "HELLO")
```

## Notes

- The font must be loaded with `figletLoadFont()` before calling `drawFigletText()`
- Each line of the figlet text is drawn on a new line starting at the specified y coordinate
- The function automatically handles multi-line figlet output
- Returns nil (no return value)

## See Also

- `figletLoadFont(fontName)` - Load a figlet font
- `figletRender(fontName, text, [layoutMode])` - Render figlet text (returns array of lines)
- `figletIsFontLoaded(fontName)` - Check if a font is loaded
- `figletListAvailableFonts()` - Get list of available fonts
