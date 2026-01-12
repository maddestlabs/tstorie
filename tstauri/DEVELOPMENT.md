# tStauri Development Guide

## Quick Setup

### 1. Install Prerequisites

**All platforms:**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install Node.js (use your preferred method)
# On macOS: brew install node
# On Ubuntu: sudo apt install nodejs npm
# On Windows: Download from nodejs.org
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev \
    build-essential \
    curl \
    wget \
    file \
    libssl-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev
```

**macOS:**
```bash
xcode-select --install
```

**Windows:**
- Install [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)

### 2. Build tStorie WASM First

The desktop app bundles the WASM files from the `docs/` directory:

```bash
# From the repo root
./build-web.sh -o docs
```

This creates:
- `docs/tstorie.js`
- `docs/tstorie.wasm.js`
- `docs/tstorie.wasm.wasm`

### 3. Install tStauri Dependencies

```bash
cd tstauri
npm install
```

### 4. Run in Development Mode

```bash
npm run dev
```

This opens the app with hot-reload enabled. Any changes to `src/` files will trigger a reload.

### 5. Build for Production

```bash
npm run build
```

Binaries will be in:
- **Linux**: `src-tauri/target/release/bundle/appimage/`
- **macOS**: `src-tauri/target/release/bundle/macos/`
- **Windows**: `src-tauri/target/release/bundle/msi/`

## Project Structure

```
tstauri/
├── src/                          # Frontend (HTML/CSS/JS)
│   ├── index.html               # Main UI with drop zone
│   └── main.js                  # WASM loader & event handlers
│
├── src-tauri/                   # Rust backend
│   ├── src/
│   │   └── main.rs              # Tauri commands & file handling
│   ├── Cargo.toml               # Rust dependencies
│   ├── tauri.conf.json          # App configuration & bundling
│   └── icons/                   # App icons (need to add)
│
├── package.json                 # NPM scripts
└── README.md                    # User documentation
```

## Key Files Explained

### `src/main.js`

The frontend logic that:
1. Loads the tStorie WASM engine from bundled resources
2. Listens for file drop events from Tauri
3. Reads and executes dropped `.md` files
4. Manages UI state (drop zone ↔ running state)

### `src-tauri/src/main.rs`

The Rust backend that:
1. Sets up the Tauri window
2. Handles file drop events via `on_file_drop()`
3. Provides commands to read file contents
4. Exposes bundled resource paths to the frontend

### `src-tauri/tauri.conf.json`

Configuration for:
- App metadata (name, version, identifier)
- Window settings (size, title)
- Bundled resources (WASM files from `../../docs/`)
- Build targets and icons
- Security policies (CSP for WASM execution)

## Testing Locally

### Test with a sample file

Create a test markdown file:

```bash
cat > test.md << 'EOF'
# Hello from tStauri!

```nim
echo "This is running in the desktop app"
```
EOF
```

Then:
1. Run `npm run dev` in the `tstauri/` directory
2. Drag `test.md` onto the app window
3. You should see it execute

### Debugging

**Rust backend logs:**
- Check the terminal where you ran `npm run dev`
- Rust `println!()` statements appear here

**Frontend logs:**
- Open DevTools: Right-click → "Inspect Element"
- Check the Console tab for JavaScript logs

**Common issues:**

1. **WASM files not found**
   - Ensure you've run `./build-web.sh` first
   - Check that `docs/tstorie.wasm.*` files exist

2. **File drop not working**
   - Verify `fileDropEnabled: true` in `tauri.conf.json`
   - Check console for error messages

3. **Build fails on Linux**
   - Install webkit2gtk-4.1-dev (not 4.0)
   - Some distros may need additional dependencies

## GitHub Actions Build

The workflow at `.github/workflows/build-tstauri.yml`:

1. **Builds WASM** - Compiles tStorie to WASM
2. **Builds Tauri** - Creates desktop apps for:
   - Linux (AppImage)
   - macOS (DMG for Intel & Apple Silicon)
   - Windows (MSI installer)
3. **Creates Release** - Uploads binaries to GitHub Releases

**Triggered by:**
- Git tags matching `v*` (e.g., `v0.1.0`)
- Manual workflow dispatch

## Icon Generation

tStauri needs icons for each platform. Create them:

```bash
cd tstauri/src-tauri/icons

# Generate from a source PNG (1024x1024 recommended)
convert icon-source.png -resize 32x32 32x32.png
convert icon-source.png -resize 128x128 128x128.png
convert icon-source.png -resize 256x256 128x128@2x.png

# macOS .icns (requires iconutil on macOS)
mkdir icon.iconset
for size in 16 32 64 128 256 512; do
  convert icon-source.png -resize ${size}x${size} icon.iconset/icon_${size}x${size}.png
done
iconutil -c icns icon.iconset

# Windows .ico (requires ImageMagick)
convert icon-source.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

## Updating WASM Engine

When tStorie's WASM build changes:

```bash
# From repo root
./build-web.sh -o docs

# No need to rebuild tStauri for dev - it reads from docs/
# For production builds, the WASM is bundled into the binary
```

## Distribution

### Manual Distribution

After `npm run build`, distribute:
- **Linux**: `.AppImage` file (portable)
- **macOS**: `.dmg` file
- **Windows**: `.msi` installer

### Automated via GitHub

1. Tag a release: `git tag v0.1.0 && git push --tags`
2. GitHub Actions builds all platforms
3. Binaries appear in the GitHub Release

## Contributing

When adding features:

1. **Rust changes** → Edit `src-tauri/src/main.rs`
2. **UI changes** → Edit `src/index.html` and `src/main.js`
3. **Config changes** → Edit `src-tauri/tauri.conf.json`

Test on your platform, then submit a PR. CI will test all platforms.

## Troubleshooting

### "command not found: tauri"

Install Tauri CLI:
```bash
npm install
# or globally: npm install -g @tauri-apps/cli
```

### WASM execution fails

Check CSP in `tauri.conf.json`:
```json
"csp": "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline' 'wasm-unsafe-eval';"
```

### App won't start after build

- Check console output for missing dependencies
- Verify all bundled resources exist
- Test in dev mode first

## Resources

- [Tauri Documentation](https://tauri.app/)
- [Tauri API Reference](https://tauri.app/reference/)
- [tStorie Main README](../README.md)
- [WebAssembly MDN](https://developer.mozilla.org/en-US/docs/WebAssembly)
