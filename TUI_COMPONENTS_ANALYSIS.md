# TUI Component System Analysis & Recommendations

## Executive Summary

**Good news!** The existing TUI libraries provide an excellent foundation for your "ask Claude to generate a sci-fi textbox/slider" workflow. They already have:

✅ **Widget system** (base class, state management, styling)  
✅ **Button, CheckBox, RadioButton, Slider** widgets  
✅ **TextField** for text input  
✅ **Style system** with state-based styles (normal, focused, hover, active, disabled)  
✅ **Event handling** (mouse, keyboard)  
✅ **WidgetManager** for focus/tab management  

## What's Already There

### lib/tui.nim - Core TUI System

**Base Widget Framework:**
- `Widget` base class with position, size, state, styling
- `WidgetState` enum (normal, focused, hovered, disabled, active)
- `WidgetManager` for managing widget collections
- Style resolution system with stylesheet integration
- Event callbacks (onFocus, onBlur, onChange, onClick)
- Tab order management

**Existing Widgets:**
1. **Button** - Clickable buttons with labels, borders, alignment
2. **CheckBox** - Boolean toggles with customizable indicators
3. **RadioButton** - Single-selection groups
4. **Slider** - Numeric value selection (horizontal/vertical)

### lib/textfield.nim - Text Input

**TextField Widget:**
- Single-line text input
- Cursor navigation (left, right, home, end)
- Insert/delete operations
- Horizontal scrolling for long text
- Focused state with cursor rendering

### lib/tui_editor.nim
- Multi-line text editing (not yet examined, but exists)

## What's MISSING for Your Workflow

### 1. **More Widget Types** 🔴

Currently missing:
- **ProgressBar** - Visual progress indicator
- **Label** - Static text widget
- **Panel/Container** - Grouping widgets
- **Dropdown/ComboBox** - Selection from list
- **ListBox** - Scrollable list
- **ScrollBar** - Scroll indicators
- **TextBox (multi-line)** - Text area widget
- **ColorPicker** - Color selection
- **NumberInput** - Numeric input with +/- buttons

### 2. **Advanced Drawing Primitives** 🟡

For custom visual effects (sci-fi, glowing, etc.):
- Pattern-based fills (integrate with ascii_art.nim)
- Animated effects (pulsing, scanning, flickering)
- Multi-character glyphs (for fancy borders)
- Shadow/depth effects
- Color gradients

### 3. **Layout Helpers** 🟡

For easier positioning:
- `stackVertical(widgets, spacing)`
- `stackHorizontal(widgets, spacing)`
- `gridLayout(widgets, rows, cols)`
- `centerInArea(widget, x, y, w, h)`
- `autoResize(widget, minW, minH, maxW, maxH)`

### 4. **Nimini Bindings** 🔴 **CRITICAL**

The TUI widgets are **NOT currently exposed to nimini scripts!**
This is the main blocker for your workflow.

### 5. **Export System for Widgets** 🟡

The `pattern_export.nim` handles ASCII patterns, but needs:
- Component export (analyze widget prototypes)
- State management in exports
- Event handler preservation

## Recommended Implementation Plan

### Phase 1: Nimini Bindings (REQUIRED) ⭐

Create `lib/tui_bindings.nim` to expose widgets to scripts:

```nim
# Example bindings
proc nimini_newButton*(env: ref Env; args: seq[Value]): Value {.nimini.}
proc nimini_newSlider*(env: ref Env; args: seq[Value]): Value {.nimini.}
proc nimini_newTextField*(env: ref Env; args: seq[Value]): Value {.nimini.}
# etc.
```

**Why critical:** Without this, Claude can't generate widget code in nimini scripts!

### Phase 2: Missing Widget Types (HIGH PRIORITY) ⭐

Add these to `lib/tui.nim`:

1. **ProgressBar** - Most requested, simple to implement
2. **Label** - Simplest widget, useful everywhere
3. **Panel** - Container for grouping
4. **TextBox** - Multi-line text (might exist in tui_editor.nim)

### Phase 3: Visual Enhancement System (MEDIUM)

Create `lib/tui_visual_effects.nim`:

```nim
# Effects that can be applied to widgets
type EffectKind = enum
  efNone, efGlow, efPulse, efScan, efFlicker, efShadow

proc applyEffect*(widget: Widget, effect: EffectKind, intensity: float)
proc drawWithBorderPattern*(widget: Widget, pattern: PatternFunc)
proc animateWidget*(widget: Widget, animation: AnimationFunc)
```

Integrates with `ascii_art.nim` for custom borders!

### Phase 4: Layout Helpers (LOW PRIORITY)

Add to `lib/tui.nim`:

```nim
proc stackVertical*(widgets: seq[Widget], spacing: int)
proc stackHorizontal*(widgets: seq[Widget], spacing: int)
proc gridLayout*(widgets: seq[Widget], cols: int, spacing: int)
proc centerWidget*(w: Widget, containerX, containerY, containerW, containerH: int)
```

### Phase 5: Component Export (NICE TO HAVE)

Extend `pattern_export.nim` to handle widget prototypes.

## Your Workflow - Before & After

### ❌ Current State (Blocked)

```markdown
You: "Generate a sci-fi textbox with glowing edges"
Claude: "I can't - TUI widgets aren't exposed to nimini scripts yet"
```

### ✅ After Phase 1 (Nimini Bindings)

```markdown
---
title: "Sci-Fi TextBox Prototype"
---

```nim on:init
# Create a text field
var sciFiField = newTextField("input1", 10, 10, 30)

# Customize appearance (need to add these properties)
sciFiField.borderChar = "═"
sciFiField.cornerChars = @["╔", "╗", "╚", "╝"]
sciFiField.glowEffect = true
```

```nim on:render
# Render with custom styling
sciFiField.render()
```
```

### ✅ After Phase 3 (Visual Effects)

```markdown
```nim on:init
var sciFiField = newTextField("input1", 10, 10, 30)

# Apply visual effects
applyEffect(sciFiField, efGlow, 0.8)

# Use ASCII art pattern for border
var glowPattern = crackedBorderPattern(42)
setFieldBorderPattern(sciFiField, glowPattern)

# Animate border
var animFrame = 0.0
```

```nim on:update
animFrame = animFrame + deltaTime
sciFiField.borderIntensity = 0.5 + 0.5 * sin(animFrame * 2.0)
```

```nim on:render
sciFiField.render()
```
```

### ✅ After Phase 5 (Export)

```bash
./ts export-component scifi_textbox.md \
  --name=SciFiTextField \
  --output=lib/tui/components/
```

Result: Compiled `SciFiTextField` module, 100x faster!

## Integration with ASCII Art System

The ASCII art system you just built is **PERFECT** for customizing TUI widgets!

**Example integration:**

```nim
# In tui.nim, add to Button widget:
type Button* = ref object of Widget
  # ... existing fields ...
  borderPattern*: PatternFunc  # NEW: Custom border pattern
  usePattern*: bool             # NEW: Use pattern instead of solid border

# Update button rendering:
method render*(btn: Button, layer: Layer) =
  if btn.usePattern and not btn.borderPattern.isNil:
    # Use ASCII art pattern for border!
    drawBorder(layer, btn.x, btn.y, btn.width, btn.height,
               btn.borderPattern, btn.borderPattern, 
               btn.borderPattern, btn.borderPattern,
               ["┌", "┐", "└", "┘"], style, drawProc)
  else:
    # Use solid border (existing code)
    # ...
```

**Now you can:**
```nim
var fancyButton = newButton("btn1", 10, 5, 20, 3, "ACTIVATE")
fancyButton.usePattern = true
fancyButton.borderPattern = crackedBorderPattern(42)
```

## Recommendations

### Do This FIRST ⭐⭐⭐

1. **Create `lib/tui_bindings.nim`** - Expose existing widgets to nimini
   - Start with Button, Slider, TextField
   - Add CheckBox, RadioButton
   - This unblocks the entire workflow!

### Do This NEXT ⭐⭐

2. **Add ProgressBar & Label widgets** to `lib/tui.nim`
   - Most commonly requested
   - Simple to implement
   - Enables more use cases

3. **Integrate ascii_art patterns with widgets**
   - Add `borderPattern` field to widgets
   - Update render methods to use patterns
   - Enables custom visual styles

### Do This LATER ⭐

4. **Add visual effects system** (`lib/tui_visual_effects.nim`)
   - Glow, pulse, flicker effects
   - Animated borders
   - Color transitions

5. **Add layout helpers**
   - Simplify widget positioning
   - Nice-to-have, not critical

## Quick Implementation: Phase 1

Want me to implement Phase 1 (nimini bindings) right now? This is the critical piece that unblocks everything!

**Files to create:**
1. `lib/tui_bindings.nim` - Nimini bindings for all TUI widgets
2. Example prototype: `docs/demos/tui_components_demo.md`
3. Update `ASCII_ART_SYSTEM.md` with TUI integration notes

This will let you:
- ✅ Ask Claude to generate custom widgets
- ✅ Experiment with styling in .md files
- ✅ Combine ASCII art patterns with widgets
- ✅ Export successful widgets to compiled modules

Say the word and I'll implement it! 🚀
