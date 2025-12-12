# TStorie

Terminal engine in [Nim](https://nim-lang.org/). Build stuff using Markdown with executable Nim-like code blocks. Fast prototyping on the web or native that exports to Nim for fully native compilation across platforms.

Check it out live: [Demo](https://maddestlabs.github.io/tstorie/)

Examples on GitHub Gist:
- [tstorie_clock.nim](https://maddestlabs.github.io/tstorie?gist=3916b876cf87fc3db21171b76a512b65) | [Source Gist](https://gist.github.com/R3V1Z3/3916b876cf87fc3db21171b76a512b65)

The engine is built around GitHub features. No need to actually install Nim, or anything for that matter. Just create a new repo from the Storie template, update index.md with your own content and it'll auto-compile for the web. Enable GitHub Pages and you'll see that content served live within moments. GitHub Actions take care of the full compilation process.

## Features

Core engine features:
- **Cross-Platform** - Runs natively in terminals and in web browsers via WebAssembly.
- **Minimal Filesize** - Compiled games/apps average from maybe 400KB to 2MB.
- **Input Handling** - Comprehensive keyboard, mouse, and special key support.
- **Optimized Rendering** - Double-buffered rendering of only recent changes for optimal FPS.
- **Color Support** - True color (24-bit), 256-color, and 8-color terminal support.
- **Layer System** - Z-ordered layers with transparency support.
- **Terminal Resizing** - All layers automatically resize when terminal or browser window changes size.

Higher level features:
- **Literate programming** - Write with familiar markdown features, separating prose from code.
- **Nim-based scripting** - Code with executable code blocks. Powered by [Nimini](https://github.com/maddestlabs/nimini).
- **Reusable Libraries** - Helper modules for advanced events, animations, and UI components

## Getting Started

Quick Start:
- Create a gist using Markdown and Nim code blocks
- See your gist running live: `https://maddestlabs.github.io/tstorie?gist=gistid`

Create your own project:
- Create a template from Storie and enable GitHub Pages
- Update index.md with your content and commit the change
- See your content running live in moments

Native compilation:
- In your repo, go to Actions -> Export Code and get the exported code
- Install Nim locally
- Replace index.nim with your exported code
- On Linux: `./build.sh`. Windows: `build-win.bat`. For web: `./build-web.sh`

You'll get a native compiled binary in just moments, Nim compiles super fast.

## History

- Successor to [Storiel](https://github.com/maddestlabs/storiel), the Lua-based proof-of-concept.
- Rebuilt from [Backstorie](https://github.com/maddestlabs/backstorie), a template that extends concepts from Storiel, providing a more robust foundation for further projects.
- Forked from [Storie](https://github.com/maddestlabs/storie), which was originally just a terminal engine but this branch now continues with terminal functionality while the Storie fork is now a comprehensive game and media engine.