---
title: "Welcome to TStorie"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "futurism"
targetFPS: 60
---

```nim on:init
# TStorie Interactive Walkthrough
# Learn about TStorie's features through an interactive journey

# Track progress through the walkthrough
var visitedMarkdown = false
var visitedCanvas = false
var visitedFrontmatter = false
var visitedRendering = false
var visitedInteractive = false
var explorerLevel = 0

print "TStorie walkthrough initialized"

# Initialize canvas system - start at section 1
nimini_initCanvas(1)
```

```nim on:input
# Handle keyboard and mouse input for canvas navigation

if event.type == "key":
  if event.action == "press":
    var handled = nimini_canvasHandleKey(event.keyCode, 0)
    if handled:
      return true
  return false

elif event.type == "mouse":
  if event.action == "press":
    var handled = nimini_canvasHandleMouse(event.x, event.y, event.button, true)
    if handled:
      return true
  return false

return false
```

```nim on:render
bgClear()
fgClear()

nimini_canvasRender()
```

```nim on:update
nimini_canvasUpdate()
```

# welcome
⠀
Welcome to **TStorie Engine** - an open canvas for immersive interaction with Markdown documents and interactive stories!
⠀
You're currently experiencing TStorie's **canvas-based interactive fiction system**. This walkthrough will guide you through the engine's key features.
⠀
Think of TStorie as a bridge between traditional text documents and dynamic, interactive experiences. Using simple Markdown syntax combined with embedded code blocks, you can create everything from documentation to full adventure games.
⠀
**Ready to explore?**
⠀
➛ [Start the tour](tour_start)  
➛ [Learn about Markdown first](what_is_markdown)  
➛ [Skip to advanced features](advanced_hub)

# what_is_markdown
⠀
**What is Markdown?**
⠀
Markdown is a simple, plain text language that lets you create formatted documents quickly using basic symbols. Think of it like a simpler, more readable version of HTML.
⠀
For example:
- `# Heading` creates a heading
- `**bold**` creates **bold** text
- `[link](url)` creates a clickable link
⠀
TStorie extends Markdown by allowing you to embed executable code blocks that can respond to events, render graphics, and create interactive experiences.
⠀
➛ [Continue the tour](tour_start)  
➛ [Return to start](welcome)

# tour_start
⠀
**The Journey Begins**
⠀
TStorie parses Markdown documents into **sections** (separated by headings) and renders them in a large interactive canvas. You're navigating this document right now using the clickable links!
⠀
Each section can contain:
- **Rich text content** - Markdown-formatted text
- **Links** - Navigate between sections
- **Code blocks** - Executable Nim code that runs in response to events
- **Front matter** - Configuration variables in YAML format
⠀
Let's explore each feature:
⠀
➛ [Front Matter Variables](frontmatter_section)  
➛ [Markdown Sections](markdown_sections)  
➛ [Canvas & Rendering](canvas_rendering)  
➛ [Interactive Code](interactive_code)  
➛ [Skip to the end](journey_complete)

# frontmatter_section
⠀
**Front Matter Variables**
⠀
At the top of any TStorie document, you can define variables in YAML format:

```
---
title: "My Story"
author: "Your Name"
targetFPS: 60
theme: "nord"
---
```
⠀
These variables become **global variables** in your code blocks! For example, this document's title is "{title}" and it's running at {targetFPS} FPS.
⠀
Front matter is perfect for configuration, game state, or any data you want to access throughout your document.
⠀
➛ [Continue to Markdown sections](markdown_sections)  
➛ [Back to tour start](tour_start)

```nim on:enter
visitedFrontmatter = true
explorerLevel = explorerLevel + 1
```

# markdown_sections
⠀
**Markdown Sections**
⠀
Each `# Heading` in your document creates a new **section**. Sections are the building blocks of your interactive experience.
⠀
Sections can be:
- **Visible** - Show up in the table of contents
- **Hidden** - Marked with `{"hidden": true}` metadata
- **One-time** - Marked with `{"removeAfterVisit": "true"}`
⠀
Right now, you're in a hidden section that's navigable via links but doesn't appear in the main contents listing. This is perfect for creating branching narratives!
⠀
➛ [Learn about canvas rendering](canvas_rendering)  
➛ [Jump to interactive code](interactive_code)  
➛ [Back to tour start](tour_start)

```nim on:enter
visitedMarkdown = true
explorerLevel = explorerLevel + 1
```

# canvas_rendering
⠀
**Canvas & Rendering System**
⠀
TStorie provides a powerful terminal-based canvas with multiple layers:
⠀
**Background Layer (bg):**
- `bgClear()` - Clear the background
- `bgFillRect(x, y, w, h, char)` - Fill a rectangle
- `bgWriteText(x, y, text)` - Write text
⠀
**Foreground Layer (fg):**
- `fgClear()` - Clear the foreground
- `fgFillRect(x, y, w, h, char)` - Fill with character
- `fgWriteText(x, y, text)` - Write text
⠀
Use `on:render` code blocks to draw each frame!
⠀
➛ [Explore interactive code](interactive_code)  
➛ [See a rendering example](render_example)  
➛ [Back to tour](tour_start)

```nim on:enter
visitedRendering = true
explorerLevel = explorerLevel + 1
```

# render_example
⠀
**Rendering Example**
⠀
Here's a simple rendering code block:

```nim on:render
bgClear()
var msg = "Hello from t|Storie!"
fgWriteText(2, 2, msg)
```
⠀
This code runs **every frame** and:
1. Clears the background
2. Calculates center position
3. Draws centered text
⠀
You can combine multiple layers to create complex UIs and graphics!
⠀
➛ [Continue to interactive code](interactive_code)  
➛ [Back to canvas info](canvas_rendering)

# interactive_code
⠀
**Interactive Code Blocks**
⠀
TStorie supports several event types:
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
➛ [Learn about advanced features](advanced_hub)  
➛ [Complete the tour](journey_complete)  
➛ [Back to tour start](tour_start)

```nim on:enter
visitedInteractive = true
explorerLevel = explorerLevel + 1
```

# advanced_hub
⠀
**Advanced Features Hub**
⠀
Ready to dive deeper? TStorie includes powerful features for creating sophisticated interactive experiences:
⠀
➛ [Animation & Effects](animation_features)  
➛ [Audio System](audio_features)  
➛ [State Management](state_management)  
➛ [Layout & Themes](layout_themes)  
➛ [Gist Integration](gist_integration)  
➛ [Complete the tour](journey_complete)

# animation_features
⠀
**Animation & Effects**
⠀
TStorie includes built-in animation helpers:
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
➛ [Back to advanced hub](advanced_hub)

# audio_features
⠀
**Audio System**
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
➛ [Back to advanced hub](advanced_hub)

# state_management
⠀
**State Management**
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
➛ [Back to advanced hub](advanced_hub)

# layout_themes
⠀
**Layout & Themes**
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
➛ [Back to advanced hub](advanced_hub)

# gist_integration
⠀
**GitHub Gist Integration**
⠀
Load and share documents easily:
⠀
- Create a Markdown file in a GitHub Gist
- Get the Gist ID
- Load it directly in TStorie
⠀
Perfect for:
- Sharing stories
- Collaborative editing
- Version control
- Easy publishing
⠀
See `lib/gist_api.nim` for the implementation.
⠀
➛ [Back to advanced hub](advanced_hub)

# journey_complete
⠀
**Journey Complete! 🎉**
⠀
Congratulations! You've explored the TStorie Engine and learned about:
⠀
✓ Markdown sections and navigation  
✓ Front matter variables  
✓ Canvas rendering system  
✓ Interactive code blocks  
✓ Event handling  
✓ Advanced features
⠀
**What's Next?**
⠀
Check out these example documents:
- `docs/demos/depths.md` - Full dungeon adventure
- `examples/canvas_demo.md` - Canvas system basics
⠀
Or dive into the source code in `lib/` to see how it all works!
⠀
➛ [Start over](welcome)  
➛ [Explore advanced features](advanced_hub)  
➛ [See your explorer stats](final_stats)

# final_stats
⠀
**Your Explorer Stats**
⠀
**Sections Visited:** {explorerLevel}
⠀
**Achievements Unlocked:**
⠀
{if visitedFrontmatter}✓ Front Matter Master{endif}  
{if visitedMarkdown}✓ Markdown Navigator{endif}  
{if visitedRendering}✓ Canvas Artist{endif}  
{if visitedInteractive}✓ Code Wizard{endif}
⠀
You've completed the TStorie walkthrough!
⠀
**Pro Tip:** This entire experience was created with just Markdown and embedded Nim code. You can create similar interactive documents for tutorials, games, presentations, or anything else you can imagine!
⠀
➛ [Start over](welcome)  
➛ [Return to journey complete](journey_complete)

```nim on:render
# Display explorer level at the bottom
if explorerLevel > 0:
  var stats = "Explorer Level: " & str(explorerLevel) & " | Achievements: "
  if visitedFrontmatter:
    stats = stats & "FM "
  if visitedMarkdown:
    stats = stats & "MD "
  if visitedRendering:
    stats = stats & "RND "
  if visitedInteractive:
    stats = stats & "INT "
  bgWriteText(2, getTermHeight() - 2, stats)
```