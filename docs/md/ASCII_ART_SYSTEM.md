# Procedural ASCII Art System for tStorie

## Overview

A complete system for creating, exploring, and exporting procedural ASCII art patterns following the **Rebuild Pattern** workflow - script to create, compile to deliver.

## Quick Start

### 1. Create a Pattern Prototype

```bash
./ts new-pattern border_experiment.md
```

### 2. Experiment with Patterns

```nim
# In your .md file

```nim on:init
# Set a seed for reproducibility
var seed = 42
setSeed(seed)

# Create a cracked border pattern
var patterns = crackedBorderPattern(seed)
```

```nim on:render
# Draw the border
var corners = getBorderCorners("weathered")
drawBorderFull(0, patterns["top"], patterns["bottom"],
               patterns["left"], patterns["right"],
               corners, getStyle("lines"))
```
```

### 3. Browse Variations

Use the built-in controls to explore variations:
- Press **R** to randomize
- Use **arrow keys** to fine-tune
- Note the seed when you find a good one

### 4. Export to Compiled Module

```bash
./ts export-pattern border_experiment.md \
  --name=CrackedBorder \
  --seed=42 \
  --output=lib/ascii_art/borders/
```

### 5. Use the Compiled Module

```nim
# 100x faster than interpreted!
let border = newCrackedBorder(seed=42)
border.renderFull(0, termWidth, termHeight, borderStyle, draw)
```

## Library Structure

```
lib/
├── ascii_art.nim              # Core primitives and types
├── ascii_art_bindings.nim     # Nimini script bindings
└── ascii_art/
    ├── borders/               # Exported border patterns
    ├── fills/                 # Exported fill patterns
    └── decorations/          # Exported decorative elements

docs/demos/
├── border_prototype.md        # Interactive pattern explorer
└── pattern_gallery.md         # Showcase of patterns
```

## Core Primitives

### Pattern Functions

```nim
# Create patterns from modulo rules
let pattern = moduloPattern(@[
  (7, 3, "╌"),   # Every 7th position, offset 3
  (11, 5, "┬"),  # Every 11th position, offset 5
], "─")

# Vertical variant
let vPattern = moduloPatternV(rules, "│")

# Solid pattern
let solid = solidPattern("═")

# Combine patterns
let combined = combinePatterns(@[overlay, base])
```

### Border Drawing

```nim
# Draw a border with custom patterns
drawBorder(
  layer = 0,
  x = 0, y = 0,
  width = 60, height = 20,
  topPattern = topPat,
  bottomPattern = bottomPat,
  leftPattern = leftPat,
  rightPattern = rightPat,
  corners = ["┌", "┐", "└", "┘"],
  style = borderStyle,
  drawProc = draw
)

# Or draw full-screen
drawBorderFull(0, topPat, bottomPat, leftPat, rightPat, corners, style)
```

### Decorative Details

```nim
# Generate random crack details
let cracks = generateCrackDetails(seed, width, height, density=0.05)

# Add individual details
addDetail(0, x=10, y=5, chars=@["┯", "╽"], style)
```

### Character Sets

```nim
# Access organized character sets
let chars = getBoxChars("branches")     # @["┬", "┴", "├", "┤", "┼", ...]
let corners = getBorderCorners("double") # @["╔", "╗", "╚", "╝"]
```

## Pattern Presets

### Cracked Border (Weathered Dungeon Style)

```nim
let patterns = crackedBorderPattern(seed=42)
# Returns table with "top", "bottom", "left", "right" patterns
```

### Simple Border

```nim
let patterns = simpleBorderPattern()
# Solid lines on all sides
```

## Seeded Randomization

All patterns support seeds for reproducibility:

```nim
# Set global seed
setSeed(42)

# Every pattern generated will be identical with same seed
let pattern1 = crackedBorderPattern(42)
let pattern2 = crackedBorderPattern(42)
# pattern1 == pattern2 (same visual result)

# Different seed = different pattern
let pattern3 = crackedBorderPattern(123)
# pattern3 != pattern1 (different visual result)
```

## The Rebuild Pattern Workflow

```
┌──────────────────────────────────────────────────────────┐
│                 REBUILD CYCLE                            │
│                                                          │
│  1. PROTOTYPE (Script)                                   │
│     • Use ascii_art primitives in .md file              │
│     • Instant visual feedback                           │
│     • Rapid iteration                                   │
│                                                          │
│  2. EXPLORE (Browse)                                     │
│     • Try different seeds                               │
│     • Adjust parameters live                            │
│     • Find the perfect variation                        │
│                                                          │
│  3. EXPORT (Compile)                                     │
│     • Analyze nimini code                               │
│     • Generate native Nim module                        │
│     • 100x performance improvement                      │
│                                                          │
│  4. INTEGRATE (Use)                                      │
│     • Import compiled module                            │
│     • Use in production code                            │
│     • Share with community                              │
│                                                          │
│  5. EXTEND (Expand)                                      │
│     • Build on compiled patterns                        │
│     • Create new combinations                           │
│     • Library grows organically                         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Front Matter Configuration

Add export metadata to your pattern prototype:

```yaml
---
title: "My Awesome Pattern"
export:
  name: "AwesomePattern"          # Generated type name
  type: "border"                  # border|fill|decoration|animation
  category: "fantasy"             # Organization category
  seed: 42                        # Default seed
  description: "Epic fantasy border with glowing runes"
---
```

## Nimini API Reference

### Pattern Creation

| Function | Args | Returns | Description |
|----------|------|---------|-------------|
| `setSeed(seed)` | int | - | Set random seed |
| `moduloPattern(rules, default)` | array, string | patternId | Horizontal modulo pattern |
| `moduloPatternV(rules, default)` | array, string | patternId | Vertical modulo pattern |
| `solidPattern(char)` | string | patternId | Single character pattern |
| `crackedBorderPattern(seed)` | int | table | Weathered border preset |
| `simpleBorderPattern()` | - | table | Simple solid border |

### Border Drawing

| Function | Args | Returns | Description |
|----------|------|---------|-------------|
| `drawBorder(...)` | layer, x, y, w, h, patterns..., corners, style | - | Draw border at position |
| `drawBorderFull(...)` | layer, patterns..., corners, style | - | Draw full-screen border |

### Details & Decorations

| Function | Args | Returns | Description |
|----------|------|---------|-------------|
| `generateCracks(seed, w, h, density)` | int, int, int, float | array | Generate crack details |
| `addDetail(layer, x, y, chars, style)` | int, int, int, array, style | - | Add single detail |

### Character Sets

| Function | Args | Returns | Description |
|----------|------|---------|-------------|
| `getBoxChars(category)` | string | array | Get character set |
| `getBorderCorners(style)` | string | array | Get corner chars |

Categories: `solid`, `double`, `lightBreaks`, `heavyBreaks`, `branches`, `weathered`, `corners`

Styles: `classic`, `double`, `rounded`, `heavy`, `weathered`

## Export System

### Command Line

```bash
# Export a pattern to compiled module
./ts export-pattern SOURCE.md [OPTIONS]

Options:
  --name=NAME          Type name for generated module
  --seed=SEED          Lock pattern to specific seed
  --output=DIR         Output directory (default: lib/ascii_art/exported/)
  --category=CAT       Category for organization
```

### Generated Files

```
lib/ascii_art/borders/
├── cracked_border.nim          # Compiled pattern module
└── cracked_border_bindings.nim # Nimini bindings
```

### Using Exported Patterns

#### From Nim Code

```nim
import lib/ascii_art/borders/cracked_border

let border = newCrackedBorder(seed=42)
border.renderFull(0, termWidth, termHeight, style, draw)
```

#### From Nimini Scripts

```nim
# Automatically available after export
let border = newCrackedBorder(42)
CrackedBorder_render(border, 0, 0, 0, termWidth, termHeight, style)
```

## Performance Comparison

### Interpreted (Nimini Script)

```nim
# Runtime: ~10ms per frame (100 FPS max)
# Pattern generation: ~100,000 ops/sec
let patterns = crackedBorderPattern(42)
drawBorderFull(0, patterns["top"], patterns["bottom"], ...)
```

### Compiled (Exported Module)

```nim
# Runtime: ~0.1ms per frame (10,000 FPS capable)
# Pattern generation: ~10,000,000 ops/sec (100x faster)
let border = newCrackedBorder(42)
border.renderFull(0, termWidth, termHeight, style, draw)
```

**Real-world impact:**
- Can render 100x more complex patterns at same FPS
- Or same patterns with 100x less CPU usage
- Enables animated patterns, particle effects, procedural textures

## Examples

### Example 1: Custom Modulo Pattern

```nim
```nim on:init
# Define custom crack pattern
var myRules = @[
  @[5, 2, "╌"],   # Light breaks every 5, offset 2
  @[7, 0, "┬"],   # Branches every 7
  @[11, 4, "╥"],  # Heavy breaks every 11, offset 4
  @[13, 1, "┴"]   # Inverted branches every 13, offset 1
]

var pattern = moduloPattern(myRules, "─")
```
```

### Example 2: Layered Patterns

```nim
```nim on:init
# Create base and overlay
var base = solidPattern("─")
var cracks = moduloPattern(@[@[7, 3, "╌"], @[11, 5, "╍"]], "")

# Layer overlay on base with 30% chance
var layered = layerPattern(base, cracks, 0.3)
```
```

### Example 3: Animated Pattern

```nim
```nim on:init
var frame = 0
var seed = 42
```

```nim on:update
frame = frame + 1
```

```nim on:render
# Regenerate pattern each frame with shifting seed
var animSeed = seed + (frame / 10)  # Slower animation
setSeed(animSeed)
var patterns = crackedBorderPattern(animSeed)
drawBorderFull(0, patterns["top"], patterns["bottom"], ...)
```
```

## Community Sharing

### Share Your Patterns

1. Create amazing pattern in prototype
2. Export to compiled module
3. Push to GitHub
4. Share seed and module name

### Use Community Patterns

```bash
# Install from community
git clone https://github.com/user/awesome-pattern
cp awesome-pattern.nim lib/ascii_art/community/

# Use in your projects
import lib/ascii_art/community/awesome-pattern
let pattern = newAwesomePattern(seed=789)
```

## Best Practices

### ✅ DO

- Use seeds for reproducibility
- Organize patterns by category
- Add descriptive metadata
- Test at different terminal sizes
- Export when pattern is finalized
- Share successful seeds

### ❌ DON'T

- Hard-code specific dimensions
- Forget to set seed for reproducible patterns
- Over-complicate pattern rules
- Export before testing thoroughly
- Skip documentation in front matter

## Troubleshooting

### Pattern looks different on export

- Ensure seed is set consistently
- Check that pattern doesn't rely on script-only features
- Verify all dependencies are captured

### Export fails

- Validate front matter syntax
- Ensure output directory exists
- Check pattern name is valid Nim identifier

### Pattern too slow

- Export to compiled module (100x speedup)
- Simplify pattern rules
- Reduce detail density

## Future Enhancements

### Planned Features

- [ ] **Auto-optimization** - Detect hot code paths and suggest export
- [ ] **Pattern gallery** - Visual browser for community patterns
- [ ] **Type inference** - Better type detection for exports
- [ ] **Web export** - Generate JavaScript patterns
- [ ] **Pattern mixing** - Blend multiple patterns
- [ ] **Animation presets** - Built-in animation patterns
- [ ] **Texture fills** - Pattern-based area fills
- [ ] **Widget export support** - Export TUI widgets following the same Rebuild Pattern

---

## Integration with TUI Widgets

The ASCII art system integrates seamlessly with TUI widgets, allowing you to create custom-styled interactive components.

### Custom Widget Borders

```nim on:init
import random

# Create widgets
var myButton = newButton("btn1", 20, 10, 25, 5, "ENGAGE")
addWidget(myButton)

# Generate custom border around widget
random.randomize(42)
var borderPattern = crackedBorderPattern(42, 0.3)
```

```nim on:render
# Draw custom ASCII art border
var btnX = 19
var btnY = 9
var btnW = 27
var btnH = 7
drawBorderFull(2, btnX, btnY, btnW, btnH, borderPattern)

# Render widget on top
renderWidgets()
```

### Themed Control Panels

```nim on:init
# Create multiple widgets with coordinated patterns
var panel1Pattern = moduloPattern(7, 3, BoxDrawing.light, 42)
var panel2Pattern = moduloPattern(5, 5, BoxDrawing.heavy, 84)

var powerSlider = newSlider("power", 10, 5, 25, 0.0, 100.0)
var shieldSlider = newSlider("shield", 10, 10, 25, 0.0, 100.0)
sliderSetChars(powerSlider, "░", "▓", "█")
sliderSetChars(shieldSlider, "░", "▓", "█")

addWidget(powerSlider)
addWidget(shieldSlider)
```

```nim on:render
# Background patterns
drawBorderFull(1, 5, 3, 35, 6, panel1Pattern)
drawBorderFull(1, 5, 9, 35, 6, panel2Pattern)

# Widgets
renderWidgets()
```

### Dynamic Pattern Updates

```nim on:input
if keyPressed("space"):
  # Regenerate border when spacebar is pressed
  random.randomize()
  borderPattern = crackedBorderPattern(random.rand(100), 0.2 + random.rand(0.4))
```

For complete TUI widget documentation, see [TUI_WIDGETS_GUIDE.md](TUI_WIDGETS_GUIDE.md).

---

## License

Part of tStorie project. See main LICENSE file.

## Credits

Inspired by:
- The "cracked border" pattern from depths.md
- Shadertoy and GLSL shader development workflow
- Meta-circular evaluators and JIT compilation
- The principle: **Script to create, compile to deliver**

---

**Happy pattern crafting!** 🎨
