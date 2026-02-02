# t|Storie

Terminal engine in [Nim](https://nim-lang.org/). Build stuff using Markdown with executable Nim-like code blocks. Fast prototyping on the web or native that exports to Nim for fully native compilation across platforms. It's the abominable tech stack no one asked for!

Check it out: [Intro](https://maddestlabs.github.io/tstorie/)

Demos:
- [stonegarden.md](https://maddestlabs.github.io/tstorie/?content=stonegarden) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/stonegarden.md)
- [slides.md](https://maddestlabs.github.io/tstorie/?content=slides) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/slides.md)
- [her.md](https://maddestlabs.github.io/tstorie/?content=her) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/her.md)
- [depths.md](https://maddestlabs.github.io/tstorie/?content=depths&font=Courier+Prime) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/depths.md)
- [kanjifx.md](https://maddestlabs.github.io/tstorie?content=kanjifx) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/kanjifx.md)
- [minesweeper.md](https://maddestlabs.github.io/tstorie?content=minesweeper) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/minesweeper.md)
- [toxiclock.md](https://maddestlabs.github.io/tstorie?content=toxiclock) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/toxiclock.md)
- [magiclock.md](https://maddestlabs.github.io/tstorie?content=magiclock) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/magiclock.md)

Core examples:
- [figletclock.md](https://maddestlabs.github.io/tstorie?content=figletclock) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/figletclock.md)
- [dungen.md](https://maddestlabs.github.io/tstorie/?content=dungen) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/dungen.md)
- [edit.md](https://maddestlabs.github.io/tstorie?content=edit) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/edit.md)
- [hexview.md](https://maddestlabs.github.io/tstorie?content=hexview) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/hexview.md)
- [events.md](https://maddestlabs.github.io/tstorie?content=events) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/events.md)
- [drawing.md](https://maddestlabs.github.io/tstorie?content=drawing) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/drawing.md)
- [tui.md](https://maddestlabs.github.io/tstorie?content=tui) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/tui.md)
- [tui3.md](https://maddestlabs.github.io/tstorie?content=tui3) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/tui3.md)
- [shader.md](https://maddestlabs.github.io/tstorie?content=shader) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/shader.md)

Gist Example:
- [tstorie_rainclock.md](https://maddestlabs.github.io/tstorie/?content=863a4175989370857ccd67cb5492ac11&shader=crt&font=Zeyada) | [Source Gist](https://gist.github.com/R3V1Z3/863a4175989370857ccd67cb5492ac11)

The engine is built around GitHub features. No need to actually install Nim, or anything for that matter. Just create a new repo from the t|Storie template, update index.md with your own content and it'll auto-compile for the web. Enable GitHub Pages and you'll see that content served live within moments. GitHub Actions take care of the full compilation process.

## Features

Features inherited from Nim:
- **Cross-Platform** - Runs natively in terminals and in web browsers via WebAssembly.
- **Minimal Filesize** - Compiled games/apps average from maybe 200KB to 1MB.
- **Single-file Executable** - Bundle everything into one, compact binary.

Engine features:
- **Input Handling** - Comprehensive keyboard, mouse, and special key support.
- **WebGL Rendering** - Hardware-accelerated GPU rendering with dynamic Unicode glyph caching (10-100× faster than Canvas 2D).
- **Full Unicode Support** - CJK characters (Japanese, Chinese, Korean) and all Unicode ranges.
- **Optimized Rendering** - Double-buffered rendering of only recent changes for optimal FPS.
- **Color Support** - True color (24-bit), 256-color, and 8-color terminal support.
- **Layer System** - Z-ordered layers with transparency support.
- **Terminal Resizing** - All layers automatically resize when terminal or browser window changes size.
- **Nim-based scripting** - Code with executable code blocks. Powered by [Nimini](https://github.com/maddestlabs/nimini).
- **Reusable Libraries** - [Helper modules](https://github.com/maddestlabs/tstorie/tree/main/lib) for advanced events, animations, TUI, transitions and more.
- **Flexible Font System** - Hot-swappable fonts with progressive loading. Built-in support for Iosevka with 1000+ variants. [Learn more →](docs/FONT_HOT_SWAPPING.md)

## Documentation

- **[Font System](docs/FONT_HOT_SWAPPING.md)** - Hot-swapping fonts, testing variants, and switching to Iosevka
  - [Font Architecture](docs/FONT_SYSTEM.md) - How fonts are embedded and loaded
  - [Iosevka Variants Guide](docs/IOSEVKA_VARIANTS.md) - Complete variant reference
  - [Font Variant Switcher](docs/font-variant-switcher.html) - Interactive testing tool
- **[WebGPU Integration](docs/WEBGPU_INTEGRATION.md)** - GPU-accelerated rendering and compute shaders
- **[Modular Build System](MODULAR.md)** - Pluggable TTF renderer and progressive font loading

## Getting Started

Quick Start:
- Create a gist using Markdown and Nim code blocks
- See your gist running live: `https://maddestlabs.github.io/tstorie?content=gist:gistid`

Create your own project:
- Create a project from t|Storie template and enable GitHub Pages
- Update index.md with your content and commit the change
- See your content running live in moments

Native compilation:
- Export via CLI: `./tstorie export filename.md`
- Compile with nim: `nim c fildename.nim`

You'll get a native compiled binary in just moments, Nim compiles super fast. This is still early in development but supports small projects currently. The export is standalone with zero dependencies.

### Desktop App

**t|Stauri** is a desktop runner that lets you drag and drop `.md` files to run them locally:
- Native desktop app for Linux, macOS, and Windows
- Drag & drop `.md` files to run instantly
- Uses the same WASM engine as the web version
- Runs completely offline

### Web Usage

**Quick Start with Content Parameter:**
```
# Load from GitHub Gist
https://maddestlabs.github.io/tstorie?content=gist:abc123

# Load a local demo
https://maddestlabs.github.io/tstorie?content=demo:clock

# Load from browser localStorage (drafts, offline work)
https://maddestlabs.github.io/tstorie?content=browser:my-draft
```

### Command-Line Usage

**Install and run locally:**
```bash
# Install Nim if you haven't already
curl https://nim-lang.org/choosenim/init.sh -sSf | sh

# Clone and build
git clone https://github.com/maddestlabs/tstorie.git
cd tstorie
./build.sh

# Run with content parameter
./tstorie --content demo:clock
./tstorie --content gist:abc123

# Or run a local file
./tstorie myfile.md
```

**Content Sources:**
- `gist:<ID>` - Load from GitHub Gist
- `demo:<name>` - Load from local demos folder
- `file:<path>` - Load from file path

**Terminal Cleanup:**

If a t|Storie app crashes or you press CTRL-C, the terminal state is automatically restored. The engine uses multiple cleanup mechanisms (exit handlers and signal handlers) to ensure your terminal remains usable.

## API Reference

### Event Handling

TStorie provides SDL3-compatible event constants for clean, readable code:

#### Key Constants

```nim
# Control keys
KEY_ESCAPE, KEY_ESC       # Escape key
KEY_RETURN, KEY_ENTER     # Enter/Return
KEY_BACKSPACE             # Backspace
KEY_TAB                   # Tab
KEY_DELETE                # Delete
KEY_SPACE                 # Spacebar

# Arrow keys
KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT
KEY_HOME, KEY_END
KEY_PAGEUP, KEY_PAGEDOWN
KEY_INSERT

# Function keys
KEY_F1, KEY_F2, ... KEY_F12

# Numbers
KEY_0, KEY_1, ... KEY_9

# Letters
KEY_A, KEY_B, ... KEY_Z  # Works for both upper and lowercase
```

**Example Usage:**

```nim
# ❌ OLD WAY - Magic numbers
if event.keyCode == 1000:  # What key is this?
  echo "Up pressed"
elif event.keyCode == 27:  # What key is this?
  echo "Escape pressed"

# ✅ NEW WAY - Named constants
if event.keyCode == KEY_UP:
  echo "Up pressed"
elif event.keyCode == KEY_ESCAPE:
  echo "Escape pressed"
```

### Time & Animation

TStorie provides precise timing for smooth, frame-independent animations:

#### Time Queries

```nim
getTime()         # Monotonic time in seconds since app start
getTimeMs()       # Monotonic time in milliseconds
getDeltaTime()    # ACTUAL seconds since last frame (varies!)
getTotalTime()    # Total elapsed time (same as getTime)
getFrameCount()   # Total frames rendered
```

#### Timer Callbacks

```nim
# Call function once after delay
setTimeout(callback, seconds) -> timerId

# Call function repeatedly
setInterval(callback, seconds) -> timerId

# Cancel a timer
clearTimeout(timerId)
clearInterval(timerId)  # Alias for clearTimeout
```

**Note:** Timer callbacks have limitations in WASM builds. For simple time-based events, use manual time tracking with `getTime()` instead:

```nim
# ✅ WORKS IN WASM - Manual time tracking
var startTime = 0.0
var timerActive = false

# on:input (mouse press)
startTime = getTime()
timerActive = true

# on:update
if timerActive and (getTime() - startTime) >= 0.5:
  # Trigger after 500ms
  timerActive = false
```

**Example Usage:**

```nim
# ❌ BAD - Framerate dependent
position += velocity  # Too fast at high FPS!

# ✅ GOOD - Frame-independent
position += velocity * deltaTime

# ❌ BAD - Manual timing
var currentTime = 0.0
currentTime += 1.0/60.0  # Wrong if not 60fps!

# ✅ GOOD - Use timers
setTimeout(proc() = 
  showMenu = true
, 0.5)  # Show menu after 500ms

# ✅ GOOD - Periodic events
setInterval(proc() = 
  echo "Autosave..."
, 60.0)  # Every 60 seconds
```

### Best Practices

**Frame-Independent Movement:**
```nim
# on:update (deltaTime is auto-injected)
position.x += velocity.x * deltaTime
position.y += velocity.y * deltaTime
```

**Long-Press Detection (WASM-compatible):**
```nim
# on:init
var longPressStartTime = 0.0
var longPressActive = false
var longPressThreshold = 0.5  # 500ms

# on:input
if event.type == "mouse" and event.action == "press":
  # Start tracking long press
  longPressStartTime = getTime()
  longPressActive = true

if event.type == "mouse" and event.action == "release":
  # Cancel if released early
  longPressActive = false

# on:update
if longPressActive and (getTime() - longPressStartTime) >= longPressThreshold:
  showContextMenu = true
  longPressActive = false  # Prevent retriggering
```

**Periodic Updates:**
```nim
# on:init
setInterval(proc() =
  saveGameState()
, 30.0)  # Autosave every 30 seconds
```

## Classroom Setup

For educators who want to provie GitHub token access for classroom Gist creation with improved rate limits, see the [Educational Use Guide](https://maddestlabs.github.io/tstorie/md/CLASSROOM_SETUP.md).

## History

- Successor to [Storiel](https://github.com/maddestlabs/storiel), the Lua-based proof-of-concept.
- Rebuilt from [Backstorie](https://github.com/maddestlabs/backstorie), a template that extends concepts from Storiel, providing a more robust foundation for further projects.
- Forked from [Storie](https://github.com/maddestlabs/storie), which was originally just a terminal engine but this branch now continues with terminal functionality while the Storie fork is now a comprehensive game and media engine.

## Development & AI Disclosure

AI assistance has been used extensively throughout every part of this project's development, including the separate repositories that paved way to the engine's current state. However, the core concepts behind t|Storie have been in development for over 9 years, with foundational precedents established in prior projects such as [Treverse](https://github.com/R3V1Z3/treverse) from before the advent of modern AI tooling.

AI assistance is just that, assistance. It's a tool to quickly meet a vision that starts with the simplicity of scrpting in a browser app and ends with an optimized, natively compiled binary.

This project represents a blend of long-term creative vision with modern AI-assisted development.