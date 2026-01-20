# Building tStauri Windows Portable Locally

This guide explains how to build the Windows portable version of tStauri locally for testing, producing **exactly** the same output as the GitHub Action.

## Quick Start

```bash
./build-windows-portable-local.sh
```

The script will:
1. Check all prerequisites
2. Build WASM engine with custom welcome screen
3. Verify all files are present
4. Generate app icons
5. Install dependencies
6. Build Vite frontend
7. Cross-compile Windows executable
8. Package everything into a portable ZIP

## Output

```
tstauri/dist/tstauri-windows-portable.zip
```

Contains:
- `tstauri.exe` - All-in-one executable with bundled WASM engine and UI
- `WebView2Loader.dll` - Required Windows WebView2 component
- `run-tstauri.bat` - Launcher script with auto-install
- `MicrosoftEdgeWebview2Setup.exe` - WebView2 installer (if needed)
- `README.txt` - User instructions

## Prerequisites

All prerequisites are **already installed** in the dev container:

- ✅ Nim 2.2.6
- ✅ Emscripten 4.0.21
- ✅ Rust 1.92.0
- ✅ Rust Windows target (x86_64-pc-windows-gnu)
- ✅ mingw-w64 cross-compiler
- ✅ Node.js 22.21.1

## Testing on Windows

1. **Transfer**: Copy `tstauri-windows-portable.zip` to a Windows machine
2. **Extract**: Unzip anywhere (Desktop, Downloads, etc.)
3. **Run**: Double-click `run-tstauri.bat` (recommended) or `tstauri.exe`
4. **Test**: Drag and drop a `.md` file onto the window

## What Gets Bundled

### Inside tstauri.exe:
- ✅ WASM engine (`tstorie.wasm.wasm`, `tstorie.wasm.js`)
- ✅ Terminal wrapper (`tstorie.js`)
- ✅ WebGL renderer (`tstorie-webgl.js`)
- ✅ Welcome screen (`index.md` - built from `tstauri/welcome.md`)
- ✅ Shader library (19 shaders from `docs/shaders/`)
- ✅ Vite frontend (`index.html`, `main.js`)

### External (required by Windows):
- `WebView2Loader.dll` - Windows WebView2 interface (must be external)

## Build Time

**Total**: ~15-20 minutes
- WASM build: ~1 minute
- Frontend build: ~30 seconds
- Windows cross-compile: ~12-15 minutes
- Packaging: ~1 minute

## Verification Steps

The script automatically verifies:
1. All WASM files present (4 files)
2. Welcome screen installed from `welcome.md`
3. Shader library bundled (19+ shaders)
4. Executable created
5. DLL copied
6. Launcher scripts created

## Troubleshooting

### Build fails at WASM step
```bash
# Re-run just the WASM build
./build-web-tauri.sh
```

### Build fails at Rust/Windows step
```bash
# Verify Rust target
rustup target list | grep x86_64-pc-windows-gnu
# Should show: x86_64-pc-windows-gnu (installed)
```

### Want to rebuild just the package
```bash
cd tstauri
bash package-windows.sh
```

## Comparing with GitHub Action

This script replicates **exactly** what the GitHub Action does:

| Step | Local Script | GitHub Action |
|------|--------------|---------------|
| Environment | Dev container (Ubuntu) | ubuntu-22.04 runner |
| Nim version | 2.2.6 | 2.0.2 (configurable) |
| Emscripten | 4.0.21 | 3.1.50 |
| Cross-compile | ✅ Linux → Windows | ✅ Linux → Windows |
| Output | `tstauri/dist/tstauri-windows-portable.zip` | Artifact download |
| Verification | ✅ Same checks | ✅ Same checks |

The only differences:
- Local uses dev container versions (newer Nim/Emscripten)
- GitHub Action uploads as artifact, local creates ZIP
- Otherwise **identical process and output**

## When to Use

**Use local build when**:
- Testing changes quickly
- Iterating on features
- Verifying fixes work
- Before pushing to GitHub

**Use GitHub Action when**:
- Need clean environment
- Want artifact uploaded
- Testing with specific Nim version
- Sharing with team

## Related Files

- [`build-windows-portable-local.sh`](build-windows-portable-local.sh) - This build script
- [`build-web-tauri.sh`](build-web-tauri.sh) - WASM build step
- [`tstauri/package-windows.sh`](tstauri/package-windows.sh) - Packaging step
- [`tstauri/welcome.md`](tstauri/welcome.md) - Desktop welcome screen
- [`.github/workflows/build-tstauri-windows-portable.yml`](.github/workflows/build-tstauri-windows-portable.yml) - GitHub Action
- [`tstauri/BUILD_WORKFLOWS.md`](tstauri/BUILD_WORKFLOWS.md) - Workflow comparison

## Next Steps

After successful build:
1. Test on Windows 10/11
2. Verify welcome screen displays
3. Test drag-and-drop functionality
4. Check WebGL rendering
5. Test shader loading

If everything works, push to GitHub and run the Action to verify in clean environment!

