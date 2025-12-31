---
title: "ASCII Art Border Prototype"
author: "tStorie Pattern Lab"
minWidth: 60
minHeight: 18
theme: "nord"
styles.lines.fg: "#ffffff"
styles.lines.bold: "true"
export:
  name: "CrackedBorderEffect"
  type: "ascii-pattern"
  category: "borders"
  seed: 42
  description: "Weathered dungeon-style border with procedural cracks"
---

```nim on:init
# Procedural ASCII Art Border Prototype
# Using the new ascii_art primitives library

# Set seed for reproducible pattern
# Try different seeds to explore variations: 42, 123, 789, 1337
var borderSeed = 42
setSeed(borderSeed)

# Create cracked border patterns
# This returns a table with "top", "bottom", "left", "right" pattern IDs
var patterns = crackedBorderPattern(borderSeed)
```

```nim on:render
clear()

# Get style for border
var borderStyle = getStyle("lines")

# Get terminal dimensions
var w = termWidth
var h = termHeight

# Get corner characters
var corners = getBorderCorners("weathered")

# Draw the full-screen cracked border
drawBorderFull(0, patterns["top"], patterns["bottom"], 
               patterns["left"], patterns["right"], 
               corners, borderStyle)

# Add optional crack details
# These add extra weathering effects
if w > 10 and h > 5:
  # Top left crack
  addDetail(0, 5, 0, @["┯"], borderStyle)
  addDetail(0, 5, 1, @["╽"], borderStyle)
  
  # Top right crack
  addDetail(0, w - 6, 0, @["┯"], borderStyle)
  addDetail(0, w - 6, 1, @["╽"], borderStyle)
  
  # Bottom left crack
  addDetail(0, 4, h - 1, @["┷"], borderStyle)
  addDetail(0, 4, h - 2, @["╿"], borderStyle)
  
  # Bottom right crack
  addDetail(0, w - 7, h - 1, @["┷"], borderStyle)
  addDetail(0, w - 7, h - 2, @["╿"], borderStyle)

# Draw title in center
var title = "⟨ CRACKED BORDER PROTOTYPE ⟩"
var titleX = (w - len(title)) / 2
draw(0, titleX, h / 2, title, getStyle("heading"))

# Draw seed info
var seedInfo = "Seed: " & str(borderSeed) & " | Press R to randomize"
var infoX = (w - len(seedInfo)) / 2
draw(0, infoX, (h / 2) + 2, seedInfo, getStyle("body"))

# Draw variation preview
var preview = "═══════════════════════════════════════════"
var previewY = (h / 2) + 4
for i in 0..<5:
  var seed = borderSeed + i * 100
  setSeed(seed)
  var p = crackedBorderPattern(seed)
  
  # Draw small sample
  var y = previewY + i * 2
  draw(0, 10, y, "Seed " & str(seed) & ": ", getStyle("body"))
  
  # Draw pattern sample (top border pattern)
  var sampleX = 25
  var sampleWidth = 30
  # Here we'd ideally render a sample of the pattern
  # For now, just show the seed
  draw(0, sampleX, y, preview, borderStyle)
```

```nim on:input
# Handle input to change seed
if event.type == "key" and event.action == "press":
  # R key to randomize
  if event.keyCode == 114 or event.keyCode == 82:  # 'r' or 'R'
    borderSeed = randInt(1, 999999)
    patterns = crackedBorderPattern(borderSeed)
    return true
  
  # Number keys 1-9 to set specific seeds
  if event.keyCode >= 49 and event.keyCode <= 57:  # '1' to '9'
    var num = event.keyCode - 48
    borderSeed = num * 111
    patterns = crackedBorderPattern(borderSeed)
    return true
  
  # Arrow keys to fine-tune seed
  if event.keyCode == 1003:  # Right arrow
    borderSeed = borderSeed + 1
    patterns = crackedBorderPattern(borderSeed)
    return true
  
  if event.keyCode == 1002:  # Left arrow
    borderSeed = borderSeed - 1
    if borderSeed < 1:
      borderSeed = 1
    patterns = crackedBorderPattern(borderSeed)
    return true

return false
```

## Usage Instructions

This prototype demonstrates the procedural ASCII art system for tStorie.

### Controls

- **R** - Generate a random seed and new pattern
- **1-9** - Jump to preset seeds (111, 222, 333, etc.)
- **← →** - Fine-tune the seed by ±1
- **Resize terminal** - Pattern adapts to new dimensions

### Workflow

1. **Experiment** - Use R key to browse random variations
2. **Find a good one** - When you see a pattern you like, note the seed
3. **Fine-tune** - Use arrow keys to explore nearby seeds
4. **Export** - Run `./ts export-pattern` to generate a compiled module

### Export Command (Future)

```bash
# Export this pattern as a reusable compiled module
./ts export-pattern border_prototype.md \
  --name=CrackedBorder \
  --seed=42 \
  --output=lib/ascii_art/borders/

# The exported module can then be used like:
# let border = newCrackedBorder(seed=42)
# border.render(0, borderStyle)
```

### Pattern Customization

Edit the `on:init` block to create custom patterns:

```nim
# Custom pattern example
var myRules = @[
  @[5, 2, "╌"],   # Every 5th position offset by 2
  @[7, 0, "┬"],   # Every 7th position
  @[11, 3, "╥"]   # Every 11th position offset by 3
]

var myPattern = moduloPattern(myRules, "─")
```

### Benefits

- ✅ **Instant feedback** - See changes immediately
- ✅ **Reproducible** - Seed guarantees exact same result
- ✅ **Explorable** - Browse infinite variations
- ✅ **Exportable** - Convert to fast compiled code when ready
- ✅ **Reusable** - Share seeds and patterns with others

---

**Part of the tStorie Rebuild Pattern** - Script to create, compile to deliver.
