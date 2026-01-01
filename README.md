# t|Storie

Terminal engine in [Nim](https://nim-lang.org/). Build stuff using Markdown with executable Nim-like code blocks. Fast prototyping on the web or native that exports to Nim for fully native compilation across platforms. It's the abominable tech stack no one asked for!

Check it out: [Intro](https://maddestlabs.github.io/tstorie/)

Demos:
- [slides.md](https://maddestlabs.github.io/tstorie/?content=demo:slides&theme=catppuccin&fontsize=22) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/slides.md)
- [her.md](https://maddestlabs.github.io/tstorie/?content=demo:her&shader=crt&fontsize=20) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/her.md)
- [depths.md](https://maddestlabs.github.io/tstorie/?content=demo:depths&shader=invert&font=Cutive+Mono) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/depths.md)
- [bloxes.md](https://maddestlabs.github.io/tstorie/?content=demo:bloxes&fontsize=24&shader=crt) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/bloxes.md)
- [dungen.md](https://maddestlabs.github.io/tstorie?content=demo:dungen&shader=crt) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/dungen.md)
- [clock.md](https://maddestlabs.github.io/tstorie?content=demo:clock&shader=crt) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/clock.md)

Core examples:
- [layout.md](https://maddestlabs.github.io/tstorie?content=demo:layout&shader=crt) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/layout.md)
- [tui.md](https://maddestlabs.github.io/tstorie?content=demo:tui&shader=crt) | [Source](https://github.com/maddestlabs/tstorie/blob/main/docs/demos/tui_simple.md)

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
- **Optimized Rendering** - Double-buffered rendering of only recent changes for optimal FPS.
- **Color Support** - True color (24-bit), 256-color, and 8-color terminal support.
- **Layer System** - Z-ordered layers with transparency support.
- **Terminal Resizing** - All layers automatically resize when terminal or browser window changes size.
- **Nim-based scripting** - Code with executable code blocks. Powered by [Nimini](https://github.com/maddestlabs/nimini).
- **Reusable Libraries** - [Helper modules](https://github.com/maddestlabs/tstorie/tree/main/lib) for advanced events, animations, TUI, transitions and more.

## Getting Started

Quick Start:
- Create a gist using Markdown and Nim code blocks
- See your gist running live: `https://maddestlabs.github.io/tstorie?content=gist:gistid`

Create your own project:
- Create a project from t|Storie template and enable GitHub Pages
- Update index.md with your content and commit the change
- See your content running live in moments

Native compilation:
- In your repo, go to Actions -> Export Code and get the exported code
- Install Nim locally
- Replace index.nim with your exported code
- On Linux: `./build.sh`. Windows: `build-win.bat`. For web: `./build-web.sh`

You'll get a native compiled binary in just moments, Nim compiles super fast.

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

## Classroom Setup

For educators who want to provie GitHub token access for classroom Gist creation with improved rate limits, see the [Educational Use Guide](https://maddestlabs.github.io/tstorie/md/CLASSROOM_SETUP.md).

## History

- Successor to [Storiel](https://github.com/maddestlabs/storiel), the Lua-based proof-of-concept.
- Rebuilt from [Backstorie](https://github.com/maddestlabs/backstorie), a template that extends concepts from Storiel, providing a more robust foundation for further projects.
- Forked from [Storie](https://github.com/maddestlabs/storie), which was originally just a terminal engine but this branch now continues with terminal functionality while the Storie fork is now a comprehensive game and media engine.