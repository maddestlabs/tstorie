# Mouse Coordinate System - Proposed Solution

## Problem
Mouse coordinates break when:
- Terminal font size changes (zoom, accessibility)
- Window resizes
- Different sections render at different positions
- Content scrolling

Currently, games like Sokoban need hardcoded offsets like `(46, 19)` which are fragile.

## Root Cause
Mouse events provide coordinates in **character cell space** (already converted from pixels by tstorie.js):
- `event.x`, `event.y` are 0-based character grid positions
- These are relative to the **entire terminal viewport**

But game content renders within a **section's content area**, which has:
- Variable position (depends on layout, other sections)
- Margins/padding (theme-dependent)
- Different positions across sections

## Solution: Expose Content Bounds to Nimini

### Option 1: Add `contentX` and `contentY` to mouse events
**Modify the event object to include content-relative coordinates:**

```nim
{
  "type": "mouse",
  "x": 47,              # Screen position (terminal grid)
  "y": 19,
  "contentX": 1,        # Content-relative position (within current section)
  "contentY": 0,
  "button": "left",
  "action": "press"
}
```

**Implementation:**
1. Track current section's content bounds in canvas state
2. When dispatching mouse events to nimini, calculate: `contentX = x - sectionContentX`, `contentY = y - sectionContentY`
3. Add these fields to the nimini event table

**Pros:**
- Automatic, no user code needed
- Works across all sections
- Updates on resize/zoom automatically

**Cons:**
- Requires modifying event dispatch in multiple places
- What if mouse is outside content area? (negative coords)

### Option 2: Add helper functions
**Provide nimini functions to query content bounds:**

```nim
# Get current section's content area bounds
var bounds = getContentBounds()
# Returns: { x: 46, y: 19, width: 40, height: 20 }

# Convert screen coords to content coords
var contentX = event.x - bounds.x
var contentY = event.y - bounds.y

# Or use a helper:
var contentCoords = screenToContent(event.x, event.y)
# Returns: { x: 1, y: 0 }
```

**Implementation:**
1. Add `getContentBounds()` nimini function
2. Returns current section's rendering position and size
3. User code does the math

**Pros:**
- Explicit and flexible
- User can handle edge cases
- Minimal changes to event system

**Cons:**
- Requires user code to call it
- Two-step process (get bounds, subtract)

### Option 3: Hybrid Approach (RECOMMENDED)
**Combine both approaches:**

1. **Add helper functions** for explicit control
2. **Add `contentX`/`contentY`** to events for convenience
3. Make `contentX`/`contentY` `nil` if mouse is outside content area

```nim
proc handleClick(event):
  # Option A: Use pre-calculated content coords
  if event.contentX != nil:
    var gridX = event.contentX / 2  # Emoji width
    var gridY = event.contentY
    print("Clicked at grid: " & $gridX & ", " & $gridY)
  
  # Option B: Manual calculation for custom layouts
  var bounds = getContentBounds()
  var relX = event.x - bounds.x
  var relY = event.y - bounds.y
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. Add `contentBounds` tracking to canvas state
2. Update `renderSection()` to record bounds
3. Handle resize/zoom by invalidating bounds

### Phase 2: Nimini Bindings
```nim
proc nimini_getContentBounds(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current section's content rendering bounds
  ## Returns table: { x: int, y: int, width: int, height: int }
  let bounds = canvasState.currentContentBounds
  result = valTable()
  result.t["x"] = valInt(bounds.x)
  result.t["y"] = valInt(bounds.y)
  result.t["width"] = valInt(bounds.width)
  result.t["height"] = valInt(bounds.height)

proc nimini_screenToContent(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Convert screen coords to content-relative coords
  ## Args: screenX (int), screenY (int)
  ## Returns table: { x: int, y: int } or nil if outside content
  if args.len < 2: return valNil()
  let screenX = args[0].i
  let screenY = args[1].i
  let bounds = canvasState.currentContentBounds
  
  let contentX = screenX - bounds.x
  let contentY = screenY - bounds.y
  
  # Check if within content area
  if contentX < 0 or contentY < 0 or 
     contentX >= bounds.width or contentY >= bounds.height:
    return valNil()
  
  result = valTable()
  result.t["x"] = valInt(contentX)
  result.t["y"] = valInt(contentY)
```

### Phase 3: Event Enhancement
Modify event dispatch to auto-calculate `contentX`/`contentY`:

```nim
proc dispatchMouseEvent(...):
  var eventTable = valTable()
  eventTable.t["type"] = valStr("mouse")
  eventTable.t["x"] = valInt(mouseX)
  eventTable.t["y"] = valInt(mouseY)
  
  # Add content-relative coords
  let bounds = canvasState.currentContentBounds
  let relX = mouseX - bounds.x
  let relY = mouseY - bounds.y
  
  if relX >= 0 and relY >= 0 and relX < bounds.width and relY < bounds.height:
    eventTable.t["contentX"] = valInt(relX)
    eventTable.t["contentY"] = valInt(relY)
  else:
    eventTable.t["contentX"] = valNil()
    eventTable.t["contentY"] = valNil()
```

## Usage in Bloxes Game

**Before (fragile):**
```nim
var gridX = (clickX - 46) / 2  # Breaks on zoom/resize!
var gridY = clickY - 19
```

**After (robust):**
```nim
# Option A: Use event fields
if event.contentX != nil:
  var gridX = event.contentX / 2  # Emoji width = 2 cells
  var gridY = event.contentY
  
  if gridX >= 0 and gridX < levelWidth and gridY >= 0 and gridY < levelHeight:
    # Valid grid position
    handleGridClick(gridX, gridY)

# Option B: Use helper functions
var contentPos = screenToContent(event.x, event.y)
if contentPos != nil:
  var gridX = contentPos.x / 2
  var gridY = contentPos.y
```

## Additional Considerations

### Multi-Section Layouts
If multiple sections are visible (split view), each section needs its own bounds. The `contentX`/`contentY` should be relative to the **focused/active** section.

### Scrolling
When content scrolls, bounds need to account for scroll offset. Consider whether coordinates should be:
- **Viewport-relative**: What you see on screen
- **Content-absolute**: Position within full scrollable content

For games, viewport-relative makes more sense.

### Touch Events
The same system works for touch events (which also provide x/y coordinates).

## Benefits

✅ **Zoom-proof**: Works at any font size
✅ **Resize-proof**: Adapts to window changes
✅ **Section-aware**: Correct for any section layout
✅ **Theme-independent**: No hardcoded margins
✅ **Backward compatible**: Existing code still works

## Next Steps

1. Implement Phase 1 (track bounds in canvas.nim)
2. Implement Phase 2 (add nimini helper functions)
3. Update bloxes.md to use new system
4. Test with zoom/resize
5. Document in MOUSE_HANDLING.md
6. Consider Phase 3 (auto-add contentX/contentY) based on feedback
