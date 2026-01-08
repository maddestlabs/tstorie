# Mouse Event Handling in Tstorie

This document describes how to handle mouse events in tstorie scripts.

## Enabling Mouse Support

Mouse input is automatically enabled in tstorie, but you can explicitly control it:

```nim
enableMouse()   # Enable mouse reporting
disableMouse()  # Disable mouse reporting
```

## Mouse Event Structure

Mouse events are passed to global input handlers as Value tables with the following structure:

### Mouse Click/Button Events

```nim
{
  "type": "mouse",           # Event type
  "x": 10,                   # Mouse X coordinate
  "y": 5,                    # Mouse Y coordinate
  "button": "left",          # Button: "left", "right", "middle", "scroll_up", "scroll_down", "unknown"
  "action": "press",         # Action: "press", "release", "repeat"
  "mods": ["shift", "ctrl"]  # Modifiers: array of "shift", "alt", "ctrl", "super"
}
```

### Mouse Move Events

```nim
{
  "type": "mouse_move",      # Event type
  "x": 15,                   # Mouse X coordinate
  "y": 8,                    # Mouse Y coordinate
  "mods": ["alt"]            # Modifiers: array of "shift", "alt", "ctrl", "super"
}
```

## Handling Mouse Events

Use global input handlers to process mouse events:

```nim on:init
var mouseX = 0
var mouseY = 0

proc handleMouseInput(event):
  # Handle mouse click events
  if event.type == "mouse":
    mouseX = event.x
    mouseY = event.y
    
    if event.button == "left" and event.action == "press":
      print("Left click at (" + str(mouseX) + ", " + str(mouseY) + ")")
    
    elif event.button == "scroll_up":
      print("Scroll up")
    
    elif event.button == "scroll_down":
      print("Scroll down")
  
  # Handle mouse movement
  elif event.type == "mouse_move":
    mouseX = event.x
    mouseY = event.y
  
  return false  # Return true to consume the event, false to let it propagate

# Register the handler
registerGlobalInput("mouse_handler", handleMouseInput, 0)
```

## Event Coordinates

Mouse coordinates are 0-based:
- X: 0 to termWidth - 1
- Y: 0 to termHeight - 1

You can access mouse coordinates in two ways:

1. **From event objects** in `on:input` blocks:
```nim
if event.type == "mouse_move":
  var x = event.x
  var y = event.y
```

2. **Using getter functions** anywhere in your code:
```nim on:render
# Get current mouse position from anywhere
var x = getMouseX()
var y = getMouseY()

# Draw cursor follower
draw(0, x, y, "X")
```

The getter functions return the last known mouse position, which is updated whenever mouse events occur.

## Event Consumption

Input handlers can return `true` to consume an event (preventing other handlers from processing it) or `false` to allow event propagation:

```nim
proc myHandler(event):
  if event.type == "mouse" and event.button == "left":
    # Handle left click and consume it
    return true
  
  # Let other handlers process this event
  return false
```

## Button Types

The following mouse buttons are supported:

- `"left"` - Left mouse button
- `"right"` - Right mouse button
- `"middle"` - Middle mouse button
- `"scroll_up"` - Scroll wheel up
- `"scroll_down"` - Scroll wheel down
- `"unknown"` - Unknown button

## Actions

Mouse button actions:

- `"press"` - Button pressed
- `"release"` - Button released
- `"repeat"` - Button held (may not be supported on all platforms)

## Modifiers

Modifier keys that can be held during mouse events:

- `"shift"` - Shift key
- `"alt"` - Alt/Option key
- `"ctrl"` - Control key
- `"super"` - Super/Windows/Command key

Check for modifiers using array operations:

```nim
proc checkModifiers(mods):
  # Check if shift is pressed
  # (Note: Nimini doesn't have array 'contains', so check manually)
  var hasShift = false
  for mod in mods:
    if mod == "shift":
      hasShift = true
  
  if hasShift:
    print("Shift is pressed!")
```

## Complete Example

See [examples/mouse_test.md](../examples/mouse_test.md) for a complete interactive mouse handling example.

## Platform Notes

- Mouse reporting works in most modern terminals
- WASM/browser version may have different mouse handling behavior
- Some terminals may not support all mouse button types
- Mouse coordinates are based on character cells, not pixels

## Related APIs

- `registerGlobalInput(name, callback, priority)` - Register input handler
- `unregisterGlobalHandler(name)` - Remove handler
- `clearGlobalHandlers()` - Remove all handlers
- `getTermWidth()` - Get terminal width
- `getTermHeight()` - Get terminal height
- `getMouseX()` - Get last known mouse X coordinate
- `getMouseY()` - Get last known mouse Y coordinate
