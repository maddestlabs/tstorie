---
title: "Welcome to t|Storie"
author: "Maddest Labs"
minWidth: 30
minHeight: 12
theme: "futurism"
targetFPS: 60
---

```nim on:init
# t|Storie Interactive Walkthrough
# Learn about features through an interactive journey

# Track progress through the walkthrough
var visitedMarkdown = false
var visitedCanvas = false
var visitedFrontmatter = false
var visitedRendering = false
var visitedInteractive = false
var explorerLevel = 0

print "t|Storie walkthrough initialized"

# Initialize canvas system - start at section 1
initCanvas(1)

particleInit("sparkles", 100)
particleInit("techbubbles", 100)
particleInit("fire", 100)
var accentStyle = getStyle("heading")
var defaultStyle = getStyle("default")

# Configure sparkles (manual emission on click)
particleConfigureSparkles("sparkles", 10.0)
particleSetDrawMode("sparkles", 1)
particleSetBackgroundFromStyle("sparkles", defaultStyle)
particleSetEmitterPos("sparkles", float(termWidth / 2), float(termHeight / 2))
# Speed up sparkles with higher velocity range
particleSetVelocityRange("sparkles", -15.0, -15.0, 15.0, 15.0)
# Set short lifetime so particles disappear quickly
particleSetLifeRange("sparkles", 0.2, 0.5)
# Disable automatic emission - only emit on manual clicks
particleSetEmitRate("sparkles", 0.0)
particleSetBackgroundFromStyle("sparkles", defaultStyle)
particleSetForegroundFromStyle("sparkles", accentStyle)

# Configure fire effect rising from bottom (always active)
particleConfigureFire("techbubbles", 10.0, false)
particleSetDrawMode("techbubbles", 0)  # Mode 2 = draw characters
particleSetBackgroundFromStyle("techbubbles", defaultStyle)
particleSetForegroundFromStyle("techbubbles", accentStyle)
particleSetEmitterPos("techbubbles", 0, termHeight)
particleSetEmitterSize("techbubbles", termWidth, float(termHeight) / 2)
particleSetLifeRange("techbubbles", 3.0, 5.0)
particleSetVelocityRange("techbubbles", 0.0, -20.0, 0.0, -40.0)
particleSetChars("techbubbles", "....o")

# Configure fire at bottom
particleConfigureFire("fire", 70.0)
particleSetEmitterPos("fire", float(termWidth / 2), float(termHeight - 1))
particleSetEmitterSize("fire", 30.0, 1.0)
particleSetBackgroundFromStyle("fire", defaultStyle)

var inFinalStats = false
var metrics = getSectionMetrics()

# Track mouse state for continuous particle emission
var mouseDown = false
var mouseX = 0
var mouseY = 0

# Track angle for sparkles oval motion
var sparklesAngle = 0.0
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
  # Always track mouse position (during press, release, and move)
  if event.action == "release":
    var handled = canvasHandleMouse(event.x, event.y, event.button, false)
    if handled:
      return true
```

```nim on:render
# Clear layer 0 (content layer) with solid background
clear(0)
canvasRender()
particleRender("techbubbles", 0)
if inFinalStats:
  particleRender("fire", 0)
# Render sparkles on layer 1 to appear on top of everything
particleRender("sparkles", 0)
```

```nim on:update
canvasUpdate()
mouseX = getMouseX()
mouseY = getMouseY()

# Move sparkles in oval path around center of screen
sparklesAngle += deltaTime * 2.0  # Adjust speed (2.0 radians per second)
var centerX = float(termWidth) / 2.0
var centerY = float(termHeight) / 2.0
var radiusX = float(termWidth) / 3.0  # Horizontal radius of oval
var radiusY = float(termHeight) / 3.0  # Vertical radius of oval
var sparklesX = centerX + radiusX * cos(sparklesAngle)
var sparklesY = centerY + radiusY * sin(sparklesAngle)
particleSetEmitterPos("sparkles", sparklesX, sparklesY)
particleEmit("sparkles", 5)

# Update all active particle systems
particleUpdate("sparkles", deltaTime)

# Update fire rising from bottom (always active)
particleSetEmitterPos("techbubbles", 0.0, float(termHeight - 1))
particleSetEmitterSize("techbubbles", float(termWidth), 1.0)
particleUpdate("techbubbles", deltaTime)

# Update fire emitter position to bottom of current section
if inFinalStats:
  metrics = getSectionMetrics()
  particleSetEmitterPos("fire", metrics.x, metrics.y - 1)
  particleUpdate("fire", deltaTime)
```

# Welcome to
⠀
```ansi
[38;2;0;217;142m  ▄  [0m [1;37m█[0m [38;2;100;100;100m▄▄▄▄   ▄                     [0m
[38;2;0;217;142m ▄█▄ [0m [1;37m█[0m [38;2;100;100;100m█     ▄█▄  ▄▄▄▄ ▄▄▄▄ ▄  ▄▄▄▄▄[0m
[38;2;0;217;142m  █  [0m [1;37m█[0m [38;2;100;100;100m▀▀▀▀▄  █   █  █ █    █  █▄▄▄█[0m
[38;2;0;217;142m  █  [0m [1;37m█[0m [38;2;100;100;100m    █  █   █  █ █    █  █    [0m
[38;2;0;217;142m  ▀▀ [0m [1;37m█[0m [38;2;100;100;100m▀▀▀▀   ▀▀  ▀▀▀▀ ▀    ▀  ▀▀▀▀▀[0m
```
⠀
The abominable, little terminal engine that could,
but probably shouldn't!
⠀
**Ready to explore?**
⠀
- [Start the tour](#tour_start)  
- [Learn about Markdown first](#what_is_markdown)  
- [Skip to advanced features](#advanced_hub)

# What is Markdown?
⠀
Markdown is a simple, plain text language that lets you create formatted documents quickly using basic symbols. It's how you naturally write in Notepad, with special symbols for emphasis.
⠀
For example:
- `# Heading` creates a heading
- `**bold**` creates **bold** text
- `[link](#url)` creates a clickable link
⠀
t|Storie extends Markdown with code blocks that can respond to events, render graphics, and create interactive experiences.
⠀
- [Continue the tour](#tour_start)  
- [Return to start](#welcome_to)

# Tour Start
⠀
**The Journey Begins**
⠀
t|Storie parses Markdown documents into **Sections** (separated by headings) and renders them in a large interactive canvas.
⠀
Each Section can contain:
- **Rich text content** - Markdown-formatted text
- **Links** - Navigate between Sections
- **Code blocks** - Executable Nim code that runs in response to events
- **Front matter** - Configuration variables in YAML format
⠀
Let's explore each feature:
⠀
- [Front Matter Variables](#frontmatter)
- [Markdown Sections](#markdown_sections)
- [Canvas & Rendering](#canvas_rendering)
- [Interactive Code](#interactive_code)
- [Skip to the end](#journey_complete)

# Frontmatter
⠀
At the top of any t|Storie document, you can define variables in YAML format:

```ascii
---
title: "My Story"
author: "Your Name"
targetFPS: 60
theme: "nord"
---
```
⠀
These variables become **global variables** in your code blocks! For example, this document's title is `? title` and it's running at `? targetFPS` FPS.
⠀
Front matter is perfect for configuration, game state, or any data you want to access throughout your document.
⠀
- [Continue to Markdown sections](#markdown_sections)  
- [Back to tour start](#tour_start)

```nim on:enter
visitedFrontmatter = true
explorerLevel++
```

# Markdown Sections {"hidden": true}
⠀
Each `# Heading` in your document creates a new **Section**. Sections are the building blocks of your interactive experience.
⠀
Sections can be:
- **Visible** - Show up in the table of contents
- **Hidden** - Marked with `{"hidden": true}` metadata
- **One-time** - Marked with `{"removeAfterVisit": "true"}`
⠀
Right now, you're in a hidden Section that's navigable via links but doesn't appear in the main contents listing. This is perfect for creating branching narratives!
⠀
- [Learn about canvas rendering](#canvas_rendering)  
- [Jump to interactive code](#interactive_code)  
- [Back to tour start](#tour_start)

```nim on:enter
visitedMarkdown = true
explorerLevel++
```

# Canvas Rendering
⠀
t|Storie provides a powerful terminal-based canvas with multiple layers:
⠀
**Unified Drawing API:**
- `draw(layer, x, y, text)` - Draw text on any layer
- `clear(layer)` - Clear a layer
- `fillRect(layer, x, y, w, h, char)` - Fill a rectangle
⠀
Use `on:render` code blocks to draw each frame!
⠀
- [Explore interactive code](#interactive_code)  
- [See a rendering example](#render_example)  
- [Back to tour](#tour_start)

```nim on:enter
visitedRendering = true
explorerLevel++
```

# Render Example
⠀
Here's a simple rendering code block:

```nim
# Example: on:render
clear()
var msg = "Hello from t|Storie!"
draw(0, 2, 2, msg)
```
⠀
This code would run **every frame** and:
1. Clear the background
2. Calculate center position
3. Draw centered text
⠀
You can combine multiple layers to create complex UIs and graphics!
⠀
- [Continue to interactive code](#interactive_code)  
- [Back to canvas info](#canvas_rendering)

# Interactive Code
⠀
t|Storie supports several event types:
⠀
**`on:init`** - Runs once when document loads  
**`on:render`** - Runs every frame for drawing  
**`on:update`** - Runs every frame for logic  
**`on:input`** - Handles keyboard/mouse events  
**`on:enter`** - Runs when entering a section
⠀
You can track state with variables, respond to player input, and create fully interactive experiences - all within a Markdown document!
⠀
The canvas navigation system you're using right now is built with these code blocks.
⠀
- [Learn about advanced features](#advanced_hub)  
- [Complete the tour](#journey_complete)  
- [Back to tour start](#tour_start)

```nim on:enter
visitedInteractive = true
explorerLevel++
```

# Advanced Hub
⠀
Ready to dive deeper? t|Storie includes powerful features for creating sophisticated interactive experiences:
⠀
- [Animation & Effects](#animation_features)  
- [Audio System](#audio_features)  
- [State Management](#state_management)  
- [Layout & Themes](#layout_themes)  
- [Gist Integration](#gist_integration)  
- [Complete the tour](#journey_complete)

# Animation Features
⠀
t|Storie includes built-in animation helpers:
- **Transitions** - Smooth property changes
- **Easing functions** - Make animations feel natural
- **Timing controls** - Frame-based or time-based
⠀
Combined with the rendering system, you can create:
- Scrolling text effects
- Character movement
- UI transitions
- Screen effects
⠀
Check out `lib/animation.nim` and `lib/transition_helpers.nim` for the full API.
⠀
- [Back to advanced hub](#advanced_hub)

# audio_features
⠀
Generate and play audio directly from your code:
⠀
- **Audio nodes** - Modular sound generation
- **Audio generation** - Create sounds procedurally
- **miniaudio bindings** - Full audio playback support
⠀
Perfect for:
- Background music
- Sound effects
- Interactive audio experiences
- Generative soundscapes
⠀
See `lib/audio.nim`, `lib/audio_gen.nim`, and `lib/audio_nodes.nim` for details.
⠀
- [Back to advanced hub](#advanced_hub)

# State Management
⠀
Manage complex application state with:
⠀
**Variables:**
- Declare with `var myState = false`
- Persist across sections
- Update in `on:enter` blocks
⠀
**Front Matter:**
- Global configuration
- Accessible everywhere
- Easy to modify
⠀
**Section Metadata:**
- Control visibility
- One-time visits
- Conditional content
⠀
- [Back to advanced hub](#advanced_hub)

# Layout Themes
⠀
Customize your experience:
⠀
**Themes:**
- Pre-built color schemes (nord, dark, etc.)
- CSS-like customization
- Theme variables
⠀
**Layout:**
- Responsive text wrapping
- Text box helpers
- Alignment controls
- Custom dimensions
⠀
Check `lib/layout.nim` and `lib/storie_themes.nim`.
⠀
- [Back to advanced hub](#advanced_hub)

# Gist Integration
⠀
**GitHub Gist Integration**
⠀
Load and share documents easily:
- Create a Markdown file in a GitHub Gist
- Get the Gist ID
- Load it directly in t|Storie with `?content=gistid`
⠀
GitHub Gist is totally free, facilitates sharing and collaboration and includes built-in version control. Made a mistake in your code? No problem, just revert back to previous version.
⠀
- [Back to advanced hub](#advanced_hub)

# Journey Complete
⠀
Congratulations! You've explored t|Storie and learned about:
⠀
✓ Markdown sections and navigation
✓ Front matter variables
✓ Canvas rendering system
✓ Interactive code blocks
✓ Event handling
✓ Advanced features
⠀
- [What's Next](#whats_next)
- [Return to start](#welcome_to)

```nim on:enter
# Activate fire particles in this section
inFinalStats = true
```

```nim on:exit
# Deactivate fire when leaving Final Stats section
inFinalStats = false
particleClear("fire")
```

# Whats Next
⠀
Check out these example documents:
- `docs/demos/depths.md` - Full dungeon adventure
- `examples/canvas_demo.md` - Canvas system basics
⠀
Or dive into the source code in `lib/` to see how it all works!
⠀
- [Start over](#welcome_to)  
- [Explore advanced features](#advanced_hub)  
- [See your explorer stats](#final_stats)

# Final Stats
⠀
**Your Explorer Stats**
⠀
**Sections Visited:** `? explorerLevel`
⠀
**Achievements Unlocked:**
⠀
```nim on:enter
contentClear()
if visitedFrontmatter:
  contentWrite("✓ Front Matter Master")
if visitedMarkdown:
  contentWrite("✓ Markdown Navigator")
if visitedRendering:
  contentWrite("✓ Canvas Artist")
if visitedInteractive:
  contentWrite("✓ Code Wizard")
```
⠀
You've completed the t|Storie walkthrough!
⠀
- [Start over](#welcome_to)  
- [Return to journey complete](#journey_complete)

```nim on:render
# Display explorer level at the bottom
if explorerLevel > 0:
  var stats = "Explorer Level: " & str(explorerLevel)
  draw(0, 2, getTermHeight() - 2, stats)
```