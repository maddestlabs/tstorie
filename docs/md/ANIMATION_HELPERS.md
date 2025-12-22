# Animation & Transition Helpers

Simple, Nimini-friendly helper functions for creating smooth transitions and animations in your markdown presentations.

## Available Variables

In your `on:update` blocks:
- `deltaTime` - Time elapsed since last frame (in seconds)
- `termWidth`, `termHeight` - Terminal dimensions
- `fps` - Current frames per second
- `frameCount` - Total frames rendered

In your `on:input` blocks:
- `event` - Input event object with:
  - `event.type` - "key", "mouse", or "text"
  - `event.keyCode` - Key code (e.g., 32 for SPACE)
  - `event.action` - "press", "release", or "repeat"
  - `event.mods` - Array of modifier keys ["shift", "alt", "ctrl", "super"]

Note: ESC key to quit is handled automatically by the engine.

## Transition State Management

Track transition progress over time with automatic timing:

```nim
# Create a 1.5 second transition with cubic easing
var myTransition = nimini_newTransition(1.5, EASE_IN_OUT_CUBIC)

# In your update block:
nimini_updateTransition(myTransition, deltaTime)

# In your render block:
if nimini_transitionIsActive(myTransition):
  var t = nimini_transitionEasedProgress(myTransition)  # 0.0 to 1.0
  # Use t to animate something
```

## Interpolation Functions

### Linear Interpolation

```nim
# Interpolate between two floats
var value = nimini_lerp(0.0, 100.0, 0.5)  # Returns 50.0

# Interpolate between two integers  
var intValue = nimini_lerpInt(0, 255, 0.75)  # Returns 191

# Smooth interpolation (smoother than linear)
var smooth = nimini_smoothstep(0.5)  # Returns smoothed value
```

### Color Transitions

```nim
# Fade from red to blue
var r = nimini_lerpInt(255, 0, t)
var g = nimini_lerpInt(0, 0, t)
var b = nimini_lerpInt(0, 255, t)
var color = rgb(r, g, b)
```

## Easing Functions

Apply easing to any progress value (0.0 to 1.0):

```nim
var t = calculateProgress()  # Linear 0.0 to 1.0

# Apply different easing curves
var eased = nimini_easeInOutQuad(t)     # Ease in and out (quadratic)
var eased = nimini_easeInOutCubic(t)    # Ease in and out (cubic, more pronounced)
var eased = nimini_easeInOutSine(t)     # Smooth sine-based easing
var eased = nimini_easeInQuad(t)        # Ease in only
var eased = nimini_easeOutQuad(t)       # Ease out only
```

## Easing Constants

When creating transitions, use these constants:

```nim
EASE_LINEAR          # No easing (constant speed)
EASE_IN_QUAD         # Start slow, end fast (quadratic)
EASE_OUT_QUAD        # Start fast, end slow (quadratic)
EASE_IN_OUT_QUAD     # Start and end slow (quadratic)
EASE_IN_CUBIC        # Start slow, end fast (cubic)
EASE_OUT_CUBIC       # Start fast, end slow (cubic)
EASE_IN_OUT_CUBIC    # Start and end slow (cubic)
EASE_IN_SINE         # Sine-based ease in
EASE_OUT_SINE        # Sine-based ease out
EASE_IN_OUT_SINE     # Sine-based ease in/out
```

## Complete Example

```nim
on:init
var fadeTransition = 0
var colorValue = 0

on:render
fgClear()

# Get progress
var t = 1.0
if fadeTransition != 0:
  if nimini_transitionIsActive(fadeTransition):
    t = nimini_transitionEasedProgress(fadeTransition)

# Interpolate color
var brightness = nimini_lerpInt(0, 255, t)
var style = Style(fg: rgb(brightness, brightness, brightness), bg: black())

# Draw something
  for x in 0 ..< termWidth:
    fgWrite(x, y, "█", style)
```

```nim on:update
if fadeTransition != 0:
  nimini_updateTransition(fadeTransition, deltaTime)
```

```nim on:input
# SPACE key starts new fade transition (ESC to quit is built-in)
if event.type == "key" and event.action == "press":
  if event.keyCode == 32:  # SPACE key
    # Start new fade transition
    fadeTransition = nimini_newTransition(1.0, EASE_IN_OUT_CUBIC)
```

## Use Cases

### Slide Transitions
Fade between presentation slides

### Color Animations
Smoothly change colors over time

### UI Effects
Animate menus, dialogs, and UI elements

### Loading Screens
Create progress indicators with easing

### Visual Feedback
Animate responses to user input

## Tips

1. **Reset transitions** with `nimini_resetTransition(transId)` to restart
2. **Check if active** before applying - fully finished transitions return progress 1.0
3. **Combine multiple transitions** - run different animations simultaneously
4. **Use appropriate easing** - cubic for dramatic effects, sine for subtle smoothness
5. **Keep duration reasonable** - 0.3-1.5 seconds works well for most cases

See [transition_helpers_demo.md](../examples/transition_helpers_demo.md) for a working example!
