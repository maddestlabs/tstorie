# tStauri Build System

This document explains the tStauri build process with the custom welcome screen.

## Overview

tStauri now uses a **separate web build** specifically configured for the desktop app. This allows:
- ✅ Custom welcome screen (animated tStorie UI instead of static HTML)
- ✅ Independent from the web/GitHub Pages build
- ✅ Automatic loading of welcome screen on startup
- ✅ Better desktop app experience

## Build Structure

```
/workspaces/telestorie/
├── build-web.sh              # Standard web build (for docs/)
├── build-web-tauri.sh        # Desktop-specific web build
├── build-tstauri-complete.sh # Full tStauri build (WASM + Desktop)
├── tstauri/
│   ├── welcome.md            # Custom welcome screen
│   ├── dist-tstauri/         # Desktop-specific WASM output
│   │   ├── index.md          # → welcome.md (auto-copied)
│   │   ├── tstorie.wasm.wasm
│   │   ├── tstorie.wasm.js
│   │   ├── tstorie.js
│   │   └── tstorie-webgl.js
│   └── src-tauri/
│       └── tauri.conf.json   # Points to dist-tstauri/
```

## Build Scripts

### 1. `build-web-tauri.sh`
Builds tStorie WASM specifically for tStauri with custom welcome screen.

```bash
./build-web-tauri.sh
```

**What it does:**
1. Runs `./build-web.sh -o tstauri/dist-tstauri`
2. Copies `tstauri/welcome.md` → `tstauri/dist-tstauri/index.md`
3. Ensures all required files are in place

### 2. `build-tstauri-complete.sh`
Complete build pipeline for tStauri desktop app.

```bash
./build-tstauri-complete.sh
```

**What it does:**
1. Builds WASM engine (`build-web-tauri.sh`)
2. Builds Vite frontend (`npm run vite:build`)
3. Builds Tauri app (`tauri build`)

### 3. NPM Scripts (in `tstauri/package.json`)

```bash
# Development mode (hot reload)
cd tstauri && npm run dev

# Build everything (WASM + Desktop)
cd tstauri && npm run build

# Build only WASM
cd tstauri && npm run build:web

# Build only Vite frontend
cd tstauri && npm run vite:build
```

## Custom Welcome Screen

The welcome screen is defined in [`tstauri/welcome.md`](./welcome.md):

- Animated matrix rain effect
- Floating dots particles
- Pulsing title and instructions
- Shows drop targets for .md and .png files
- Returns to welcome on ESC key

### Editing the Welcome Screen

Simply edit `tstauri/welcome.md` and rebuild:

```bash
./build-web-tauri.sh
cd tstauri && npm run build
```

## How It Works

### Startup Flow

1. **tStauri launches** → Shows HTML drop zone temporarily
2. **Auto-loads welcome.md** → From bundled resources
3. **WASM initializes** → Canvas becomes visible
4. **Welcome screen renders** → Animated tStorie UI
5. **User drops file** → Loads and runs the file
6. **Press ESC** → Returns to welcome screen

### File Drop Handling

The system now supports both `.md` and `.png` files:

**Rust Backend** (`src-tauri/src/main.rs`):
```rust
// Accepts .md and .png files
let ext = path.extension().and_then(|s| s.to_str());
if ext == Some("md") || ext == Some("png") {
    window_clone.emit("file-dropped", path);
}
```

**Frontend** (`src/main.js`):
```javascript
// Loads welcome screen on startup
loadWelcomeScreen();

// Handles file drops
await listen('file-dropped', async (event) => {
    const filePath = event.payload;
    await runMarkdown(filePath);
});
```

### Welcome Screen Loading

New Rust command:
```rust
#[tauri::command]
fn load_bundled_welcome(app: tauri::AppHandle) -> Result<String, String> {
    let resource_path = app.path().resource_dir()?;
    let file_path = resource_path.join("index.md");
    fs::read_to_string(&file_path)
}
```

Frontend calls it:
```javascript
async function loadWelcomeScreen() {
    const welcomeContent = await invoke('load_bundled_welcome');
    await loadMarkdownContent(welcomeContent, 'Welcome');
}
```

## Development Workflow

### Quick Development
```bash
cd tstauri
npm run dev
```

This starts Tauri in dev mode with hot reload for the HTML/JS (but not for WASM changes).

### After Changing WASM Code
```bash
./build-web-tauri.sh  # Rebuild WASM
cd tstauri && npm run dev  # Restart dev mode
```

### After Changing Welcome Screen
```bash
./build-web-tauri.sh  # Copies new welcome.md
cd tstauri && npm run dev  # Restart dev mode
```

### Full Production Build
```bash
./build-tstauri-complete.sh
```

## Differences from Web Build

| Feature | Web Build (`docs/`) | tStauri Build (`dist-tstauri/`) |
|---------|-------------------|----------------------------------|
| index.md | Default/demo | Custom welcome screen |
| Auto-load | Optional via URL | Always on startup |
| File drops | HTML5 drag-drop | Native OS drag-drop |
| Distribution | GitHub Pages | Desktop executable |
| Updates | Git push | New release build |

## Troubleshooting

### "Failed to load welcome screen"
- Ensure `tstauri/welcome.md` exists
- Run `./build-web-tauri.sh` to copy it
- Check `tstauri/dist-tstauri/index.md` is present

### WASM files not found
- Run `./build-web-tauri.sh` first
- Check `tstauri/dist-tstauri/` has all 5 files
- Verify `tauri.conf.json` points to `../dist-tstauri/`

### Changes not reflected
- Full rebuild: `./build-tstauri-complete.sh`
- Clear cache: `rm -rf tstauri/dist-tstauri/ tstauri/dist-frontend/`
- Clean build: `cd tstauri && cargo clean && npm run build`

## See Also

- [tStauri README](./README.md) - User documentation
- [DEVELOPMENT.md](./DEVELOPMENT.md) - Developer guide
- [../TSTAURI.md](../TSTAURI.md) - Project overview
