# tStauri Windows Portable Build - GitHub Action

## Quick Start

### 1. Trigger the Build

Go to: **Actions** → **Build tStauri Windows Portable** → **Run workflow**

### 2. Wait for Completion

The build takes approximately **5-10 minutes** and includes:
- ✅ Building tStorie WASM with WebGL renderer
- ✅ Cross-compiling Windows executable from Linux
- ✅ Packaging with all dependencies
- ✅ Creating downloadable ZIP artifact

### 3. Download the Package

Once complete:
1. Click on the completed workflow run
2. Scroll to **Artifacts** section at the bottom
3. Download `tstauri-windows-portable` (≈8 MB)

## What's Included

The ZIP package contains:
- `tstauri.exe` - Main application (20 MB)
- `tstorie-webgl.js` - **WebGL renderer** (NEW!)
- `tstorie.wasm.js` - Emscripten runtime
- `tstorie.wasm.wasm` - WASM binary
- `tstorie.js` - Terminal wrapper
- `WebView2Loader.dll` - Required for WebView2
- `MicrosoftEdgeWebview2Setup.exe` - WebView2 installer
- `run-tstauri.bat` - Convenient launcher
- `README.txt` - Usage instructions

## Testing the Build

1. Extract the ZIP on Windows
2. Run `tstauri.exe` or `run-tstauri.bat`
3. Drag and drop a `.md` file to test
4. Check DevTools (F12) for WebGL initialization messages

## Manual Trigger Options

You can optionally specify:
- **Nim version** (default: 2.0.2)

## Advantages Over Local Build

✅ **Consistent environment** - Same build every time  
✅ **No local setup needed** - CI has all dependencies  
✅ **Automatic packaging** - One-click download  
✅ **Artifact retention** - Kept for 30 days  
✅ **Build logs** - Easy debugging if issues occur  

## Comparison with Full Release Build

| Feature | Windows Portable | Full Release |
|---------|-----------------|--------------|
| **Platforms** | Windows only | Linux, macOS, Windows |
| **Package Type** | Portable ZIP | MSI installer (+ others) |
| **Build Time** | ~5-10 min | ~15-20 min |
| **Trigger** | Manual only | Tag or manual |
| **Best For** | Quick testing | Production releases |

## Workflow Details

**File:** [.github/workflows/build-tstauri-windows-portable.yml](../.github/workflows/build-tstauri-windows-portable.yml)

**Process:**
1. Setup Nim + Emscripten
2. Build WASM files (`build-web.sh`)
3. Verify WebGL renderer is included
4. Setup Rust with Windows target
5. Install MinGW cross-compiler
6. Build frontend (Vite)
7. Cross-compile Windows .exe
8. Package with `package-windows.sh`
9. Upload as artifact

## Troubleshooting

### Build fails at "Verify WASM files"
**Cause:** WebGL renderer not built  
**Fix:** Ensure `build-web.sh` copies `tstorie-webgl.js` to docs/

### Build fails at "Build Windows executable"
**Cause:** Rust target or MinGW issue  
**Fix:** Check workflow logs, verify MinGW installation step

### Artifact not uploaded
**Cause:** Packaging script failed  
**Fix:** Check `package-windows.sh` execution in logs

## Manual Local Build

If you prefer building locally:
```bash
# Build WASM
./build-web.sh

# Build Windows portable
cd tstauri
bash build-windows.sh
bash package-windows.sh

# Package is at: dist/tstauri-windows-portable.zip
```

## See Also

- [BUILD_PROCESS.md](../tstauri/BUILD_PROCESS.md) - Full build documentation
- [WEBGL_UPDATE.md](../tstauri/WEBGL_UPDATE.md) - WebGL renderer details
- [build-tstauri.yml](build-tstauri.yml) - Full release workflow
