# Canvas Interactive Fiction System for TStorie

This document explains the **Canvas Navigation System** - a Nim-based interactive fiction engine for TStorie that provides spatial layout, smooth camera movement, and rich interactivity using Nimini code blocks.

## Overview

The Canvas system recreates the Lua-based interactive fiction engine in pure Nim, making it fully compatible with TStorie's Nimini scripting system. It provides:

- **Spatial Layout**: Sections arranged in a 2D grid or custom positions
- **Smooth Camera Movement**: Animated panning between sections
- **Interactive Navigation**: Click links, use keyboard shortcuts, tab through options
- **Section State Management**: Track visited, hidden, and removed sections
- **Link Filtering**: Automatically hide links to removed sections
- **Metadata Support**: Control section behavior with JSON metadata

## Architecture

The system consists of three main modules:

### 1. `lib/canvas.nim` - Core Logic

Contains the core canvas functionality:
- Section layout calculation
- Camera management and smooth movement
- Section state tracking (visited/hidden/removed)
- Link parsing and filtering
- Text wrapping and formatting utilities

**Key Types:**
```nim
type
  Camera = object
    x, y: float                # Current position
    targetX, targetY: float    # Target position (for smooth movement)
  
  Link = object
    text, target: string       # Link display text and target section
    screenX, screenY: int      # Screen coordinates
    width, index: int          # Link width and index for navigation
  
  SectionLayout = object
    section: Section           # The markdown section
    x, y: int                  # Position in canvas space
    width, height: int         # Section dimensions
    index: int                 # Section index
  
  CanvasState = ref object
    camera: Camera
    sections: seq[SectionLayout]
    currentSectionIdx: int
    links: seq[Link]
    focusedLinkIdx: int
    visitedSections: HashSet[string]
    hiddenSections: HashSet[string]
    removedSections: HashSet[string]
```

**Key Functions:**
- `initCanvas(sections, currentIdx)` - Initialize the canvas system
- `calculateSectionPositions(sections)` - Calculate grid layout
- `updateCamera(deltaTime, viewportW, viewportH)` - Smooth camera movement
- `centerOnSection(idx, viewportW, viewportH)` - Center on a section
- `findSectionByReference(ref)` - Find section by ID or title
- `markVisited(title)` / `isVisited(title)` - Track visited sections
- `hideSection(title)` / `isHidden(title)` - Hide sections
- `removeSection(title)` / `isRemoved(title)` - Remove sections
- `filterRemovedSectionLinks(content)` - Filter list items with removed links

### 2. `lib/canvas_bridge.nim` - Rendering & Interaction

Bridges the canvas logic with the TStorie rendering system:
- Renders sections to screen buffer
- Handles keyboard and mouse input
- Manages link rendering with formatting
- Implements global render/update/input handlers

**Key Functions:**
- `canvasRender(buffer, width, height)` - Main render function
- `canvasUpdate(deltaTime)` - Update camera and state
- `canvasHandleKey(keyCode, mods)` - Handle keyboard input
- `canvasHandleMouse(x, y, button, isDown)` - Handle mouse input
- `renderSection(layout, screenX, screenY, buffer, isCurrent)` - Render a section
- `renderTextWithLinks(text, x, y, maxWidth, buffer, isCurrent)` - Render with clickable links

### 3. `lib/canvas_api.nim` - Nimini API

Provides a simple API for use in Nimini code blocks:
```nim
proc init(): bool
proc hideSection(sectionRef: string)
proc removeSection(sectionRef: string)
proc restoreSection(sectionRef: string)
proc markVisited(sectionRef: string)
proc isVisited(sectionRef: string): bool
```

## Usage

### Basic Setup

In your markdown document, create a global Nimini code block:

````markdown
```nim global
import lib/canvas
import lib/canvas_bridge

# Initialize the canvas system
# (In the full implementation, this would register global handlers)

type StoryState = ref object
  # Your game state here
  hasTorch: bool
  hasKey: bool

var state = StoryState(hasTorch: false, hasKey: false)
```
````

### Section Metadata

Control section behavior with JSON metadata in headings:

```markdown
# entrance {"hidden": true}
# treasure_room {"removeAfterVisit": "true", "x": 100, "y": 50}
# secret_passage {"hidden": "true"}
```

**Supported Metadata:**
- `hidden: true` - Section shows as "???" until visited
- `removeAfterVisit: true` - Section is removed after being visited and left
- `x: number, y: number` - Custom position (overrides grid layout)

### Lifecycle Hooks

Use lifecycle hooks in code blocks:

````markdown
```nim on:enter
# Code runs when entering this section
storyState.hasTorch = true
hideSection("dark_corridor")
```

```nim on:exit
# Code runs when leaving this section
removeSection("temporary_event")
```
````

### Creating Interactive Links

Use standard markdown links:

```markdown
- [Enter the dungeon](dungeon_entrance)
- [Examine the torch](examine_torch)
- [Go back](previous_section)
```

The system will:
- Parse and render links as clickable/focusable elements
- Allow navigation via Tab/Arrow keys
- Support mouse clicking
- Automatically hide links to removed sections
- Remove list items that only contain links to removed sections

### Navigation Controls

**Keyboard:**
- **Enter** - Follow the focused link
- **Tab** - Cycle through links
- **Arrow Up/Down** - Navigate links
- **1-9** - Jump to section by index
- **Q** - Quit

**Mouse:**
- **Click** on a link to follow it
- **Hover** over a link to focus it

## Rendering Features

### Text Formatting

The system supports inline markdown:
- `**bold text**` - Rendered in bold
- `*italic text*` - Rendered in italics
- `[link text](target)` - Rendered as clickable/underlined links

### Link States

Links have different visual states:
- **Normal**: Blue, underlined
- **Focused**: Yellow, underlined, bold
- **Removed**: Gray, not clickable (when target section is removed)

### Section Display

Sections can be in different states:
- **Normal**: Full content displayed
- **Hidden**: Shows "???" placeholder until visited
- **Removed**: Completely hidden from display
- **Current**: Contains interactive links

## Advanced Features

### Custom Positions

Override grid layout with custom coordinates:

```markdown
# boss_room {"x": 200, "y": 100}
```

### Dynamic Section Management

From Nimini code blocks:

```nim
# Hide a section
hideSection("secret_passage")

# Remove a section (completely hide it)
removeSection("temporary_event")

# Restore a removed section
restoreSection("temporary_event")

# Check if visited
if isVisited("library"):
  echo "You remember this place..."
```

### Smart Link Filtering

The system automatically filters out list items that only contain links to removed sections:

```markdown
- [Active link](active_section)
- [Removed link](removed_section)  # This entire list item disappears
- Text with [embedded link](removed) and more text  # This stays (mixed content)
```

## Implementation Notes

### Section Reference Resolution

When you use a link like `[Go north](treasury)`, the system resolves it:
1. Try exact title match
2. Try exact ID match
3. Try case-insensitive title match
4. Try partial title match

### Camera Smoothing

The camera uses exponential smoothing for fluid movement:
```nim
let t = min(1.0, deltaTime * SMOOTH_SPEED)
camera.x += (camera.targetX - camera.x) * t
```

### Viewport Handling

The system handles different viewport sizes and only renders visible sections for performance.

## Configuration Constants

In `lib/canvas.nim`:

```nim
const
  SECTION_WIDTH = 60        # Width of each section box
  SECTION_HEIGHT = 20       # Height of each section box
  SECTION_PADDING = 10      # Spacing between sections
  MAX_SECTIONS_PER_ROW = 3  # Grid layout columns
  PAN_SPEED = 5.0           # Camera pan speed
  SMOOTH_SPEED = 8.0        # Camera smoothing factor
```

## Example: Complete Interactive Fiction

See [depths_nim.md](depths_nim.md) for a complete example of an interactive fiction game using the canvas system. It demonstrates:

- Hidden sections revealed by exploration
- Item collection and state management
- Conditional content based on player knowledge
- One-time events (removeAfterVisit)
- Multiple paths and endings
- Rich narrative with formatted text

## Comparison: Lua vs Nim Implementation

| Feature | Lua (canvas.lua) | Nim (canvas.nim) |
|---------|------------------|------------------|
| Language | Lua | Nim with Nimini |
| Integration | Plugin system | Native library |
| Performance | Good | Excellent (compiled) |
| Type Safety | Dynamic | Static |
| Code Blocks | Lua code | Nimini code |
| Global Handlers | Lua functions | Nim procedures |
| State Management | Lua tables | Nim objects/refs |

## Future Enhancements

Potential improvements:
- [ ] Animation system for section transitions
- [ ] Sound effect integration
- [ ] Particle effects for special events
- [ ] Inventory system
- [ ] Combat system
- [ ] Save/load functionality
- [ ] Multiple camera modes (follow, fixed, etc.)
- [ ] Section zoom levels
- [ ] Mini-map display

## Troubleshooting

**Links not working:**
- Check that target sections exist
- Verify section IDs match link targets
- Ensure sections aren't removed

**Sections not displaying:**
- Check if section is hidden (needs to be visited)
- Verify section isn't removed
- Check metadata syntax

**Camera not centering:**
- Ensure canvas is initialized
- Check viewport dimensions
- Verify section positions

## License

Part of the TStorie project. See main LICENSE file.
