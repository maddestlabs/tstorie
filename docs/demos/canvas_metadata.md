---
title: "Canvas Metadata Test"
theme: "catppuccin"
minWidth: 60
---

```nim on:init
# Initialize canvas system with all sections
# Start at section 1 (Introduction - section 0 is code blocks)
initCanvas(1)
```

```nim on:input
# Handle keyboard and mouse input for canvas navigation
if event.type == "key":
  if event.action == "press":
    # Pass key events to canvas system
    var handled = canvasHandleKey(event.keyCode, 0)
    if handled:
      return true
  return false

elif event.type == "mouse":
  if event.action == "press":
    # Pass mouse events to canvas system
    var handled = canvasHandleMouse(event.x, event.y, event.button, true)
    if handled:
      return true
  return false

return false
```

```nim on:update
canvasUpdate()
```

```nim on:render
# Clear screen and render canvas
clear()
canvasRender()
```

# Introduction

This demo tests the new canvas metadata features:
- Custom section width and height
- Non-navigable sections for visual decorations

Navigate with arrow keys or click links below.

[Go to Regular Section](#regular-section)
[Go to Large Art Section](#large-art)
[Try to go to Decoration](#decoration) (should not work - it's not navigable)

# Regular Section

This is a normal section with default dimensions (60x20).

It can be navigated to via links and arrow keys.

[Go to Wide Section](#wide-section)
[Back to Introduction](#introduction)

# Wide Section {"width": "100"}

This section has a custom width of 100 characters!

It's much wider than the default 60 characters, so it can display more content on a single line without wrapping.

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore.

[Go to Tall Section](#tall-section)
[Back to Regular](#regular-section)

# Tall Section {"height": "40"}

This section has a custom height of 40 lines!

Normally sections are only 20 lines tall.

Line 5
Line 6
Line 7
Line 8
Line 9
Line 10
Line 11
Line 12
Line 13
Line 14
Line 15
Line 16
Line 17
Line 18
Line 19
Line 20
Line 21
Line 22
Line 23
Line 24
Line 25
Line 26
Line 27
Line 28
Line 29
Line 30

Much more content fits!

[Go to Large Art](#large-art)
[Back to Wide](#wide-section)

# Large Art Section {"width": "120", "height": "50"}

This section is both wide (120) AND tall (50).

Perfect for large ASCII art or content displays!

```ascii:large-frame
╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                                                                                                ║
║                                         LARGE CONTENT AREA                                                     ║
║                                                                                                                ║
║                              This section can hold much more content                                           ║
║                              than a standard-sized section!                                                    ║
║                                                                                                                ║
║                              Width: 120 characters                                                             ║
║                              Height: 50 lines                                                                  ║
║                                                                                                                ║
║                                                                                                                ║
║                                                                                                                ║
║                                                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝
```

[Back to Introduction](#introduction)

# Decoration (Non-Navigable) {"x": "150", "y": "5", "width": "50", "height": "30", "navigable": "false"}

This section is positioned off to the side and is NOT navigable.

You cannot reach it via arrow keys or link clicks!

It's perfect for visual decorations that shouldn't interrupt the flow of navigation.

```ascii:decoration-art
    ╭─────────────────────╮
    │   DECORATION        │
    │                     │
    │   This is a         │
    │   non-interactive   │
    │   visual element    │
    │                     │
    ╰─────────────────────╯
```

Even if you try to link to it, navigation will fail because navigable=false.

# Another Regular Section

Back to normal content flow.

The decoration section to the right (if you pan there) won't interrupt keyboard navigation.

[Go to Custom Position](#custom-pos)
[Back to Introduction](#introduction)

# Custom Position Section {"x": "200", "y": "50", "width": "80", "height": "25"}

This section is positioned at a specific coordinate (200, 50) with custom dimensions.

You CAN navigate here because it doesn't have `navigable: false`.

Combine with non-navigable for full control:
- Use regular sections for story/gameplay flow
- Use non-navigable sections for visual decorations, borders, backgrounds

[Back to Introduction](#introduction)
