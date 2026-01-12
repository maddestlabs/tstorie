# tStauri

**Desktop tStorie Runner** - Drag and drop `.md` files to run them with the tStorie WASM engine.

## What is tStauri?

tStauri is a desktop application built with [Tauri](https://tauri.app/) that bundles the tStorie WASM engine, allowing you to:
- Run tStorie `.md` documents locally without a browser
- Drag and drop files for instant execution
- Work offline with full tStorie capabilities
- Have a dedicated development environment for tStorie projects

## Features

✨ **Drag & Drop Interface** - Simply drag `.md` files onto the app  
🚀 **Fast Startup** - Lightweight Rust backend with WebView frontend  
📦 **Bundled WASM** - Includes latest tStorie engine  
🖥️ **Cross-Platform** - Linux, macOS, and Windows support  
⌨️ **Keyboard Shortcuts** - Press `Escape` to return to drop zone  

## Development

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install)
- [Node.js](https://nodejs.org/) (for npm)
- Platform-specific dependencies:
  - **Linux**: `webkit2gtk`, `libgtk-3-dev`, `libayatana-appindicator3-dev`, `librsvg2-dev`
  - **macOS**: Xcode Command Line Tools
  - **Windows**: Microsoft C++ Build Tools

### Quick Start

```bash
cd tstauri
npm install
npm run dev
```

### Windows Cross-Compilation (Linux → Windows)

Build Windows binaries directly on Linux:

```bash
# One-time setup
bash setup-windows-cross.sh

# Build .exe
bash build-windows.sh

# Create portable package
bash package-windows.sh
```

See [WINDOWS_CROSS_COMPILE.md](WINDOWS_CROSS_COMPILE.md) for details.

### Build for Production

```bash
npm run build
```

Binaries will be in `src-tauri/target/release/`.

### Build for All Platforms

The GitHub Actions workflow automatically builds for Linux, macOS, and Windows on every release.

## Architecture

```
tstauri/
├── src/                    # Frontend (HTML/CSS/JS)
│   ├── index.html         # Main UI
│   └── main.js            # WASM loader & file handler
├── src-tauri/             # Rust backend
│   ├── src/main.rs        # Tauri app logic
│   ├── Cargo.toml         # Rust dependencies
│   └── tauri.conf.json    # App configuration
└── package.json           # Node.js build scripts
```

## How It Works

1. **Drop a file** → Tauri's file drop API catches it
2. **Read content** → Rust backend reads the `.md` file
3. **Load WASM** → Frontend initializes tStorie engine
4. **Execute** → WASM engine runs the markdown document

## Bundled Resources

tStauri automatically bundles:
- `tstorie.js` - WASM loader
- `tstorie.wasm.js` - Compiled JavaScript
- `tstorie.wasm.wasm` - WebAssembly binary

These are copied from `../docs/` during build.

## Contributing

tStauri is part of the main tStorie repository. Contributions welcome!

### Documentation

- **[BUILD_PROCESS.md](BUILD_PROCESS.md)** - Optimal build & release workflow
- **[RELEASE.md](RELEASE.md)** - Complete release process guide
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Local development setup

### Quick Start

1. The WASM build must be up-to-date (`../docs/tstorie.wasm.*`)
2. Icons are auto-generated from `../docs/favicon.png`
3. Test locally with `npm run dev`
4. CI builds all platforms automatically

## License

Same as tStorie - see [../LICENSE](../LICENSE)

## Related

- [tStorie](../) - Main project
- [tStorie Docs](../docs/) - Documentation & demos
- [Tauri](https://tauri.app/) - Desktop framework
