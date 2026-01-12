# Windows Cross-Compilation Guide

## Quick Start

Build tStauri for Windows directly on Linux:

```bash
cd tstauri

# 1. One-time setup
bash setup-windows-cross.sh

# 2. Build for Windows
bash build-windows.sh

# 3. Create portable package
bash package-windows.sh
```

Result: `dist/tstauri-windows-portable.zip` ready to test on Windows!

## What Gets Built

**Portable Windows Build:**
- `tstauri.exe` - The application
- WASM files - Bundled engine
- `README.txt` - User instructions
- `run-tstauri.bat` - Launcher script

**Size:** ~5-8 MB (exe + WASM)

## How It Works

### Cross-Compilation Stack

```
Linux Host
    ↓
Rust + MinGW-w64 Toolchain
    ↓
Target: x86_64-pc-windows-gnu
    ↓
Windows Binary (tstauri.exe)
```

**Tools Used:**
- **Rust** - Cross-platform by design
- **MinGW-w64** - GCC toolchain for Windows
- **Cargo** - Builds with `--target x86_64-pc-windows-gnu`

### What setup-windows-cross.sh Does

1. ✅ Installs Rust (if needed)
2. ✅ Installs MinGW-w64 cross-compiler
3. ✅ Adds Windows target to Rust
4. ✅ Configures Cargo for cross-compilation
5. ✅ Creates `.cargo/config.toml` with linker settings

### What build-windows.sh Does

1. ✅ Verifies cross-compilation setup
2. ✅ Builds WASM (if needed)
3. ✅ Generates icons (if needed)
4. ✅ Compiles Tauri for Windows
5. ✅ Produces `tstauri.exe`

### What package-windows.sh Does

1. ✅ Creates portable folder structure
2. ✅ Bundles exe + WASM files
3. ✅ Adds user documentation
4. ✅ Creates ZIP archive for easy transfer

## Testing Workflow

```
Linux (Development)                  Windows (Testing)
─────────────────────                ────────────────

1. Edit code
2. bash build-windows.sh
3. bash package-windows.sh
                                     4. Transfer ZIP
                                     5. Extract & run tstauri.exe
                                     6. Test functionality
7. Fix issues (if any)
8. Repeat from step 2
```

## Limitations vs CI Builds

| Feature | Cross-Compiled | CI Build |
|---------|---------------|----------|
| **Speed** | Fast (local) | Slower (remote) |
| **Format** | .exe only | .exe + MSI installer |
| **Signing** | ❌ Unsigned | ✅ Can be signed |
| **Testing** | Quick iteration | Full QA process |
| **Use Case** | Development | Production release |

**When to use cross-compilation:**
- ✅ Quick Windows testing during development
- ✅ Share builds with testers
- ✅ Verify Windows compatibility early

**When to use CI:**
- ✅ Production releases
- ✅ MSI installer needed
- ✅ Multi-platform builds
- ✅ Automated testing

## Prerequisites

### Linux (Ubuntu/Debian)

```bash
# Installed by setup-windows-cross.sh
sudo apt install mingw-w64
```

### GitHub Codespaces / Dev Containers

Works out of the box! The setup script handles everything.

## Build Times

| Step | Time |
|------|------|
| Setup (one-time) | ~5 min |
| First build | ~10 min |
| Incremental builds | ~2-3 min |
| Package creation | ~10 sec |

## Output Structure

```
tstauri/
├── src-tauri/
│   └── target/
│       └── x86_64-pc-windows-gnu/
│           └── release/
│               └── tstauri.exe       # Windows binary
└── dist/
    ├── tstauri-windows-portable/     # Extracted
    │   ├── tstauri.exe
    │   ├── tstorie.js
    │   ├── tstorie.wasm.js
    │   ├── tstorie.wasm.wasm
    │   ├── README.txt
    │   └── run-tstauri.bat
    └── tstauri-windows-portable.zip  # Ready to transfer
```

## Testing on Windows

### Option 1: Real Windows Machine

```powershell
# 1. Copy ZIP to Windows
# 2. Extract
# 3. Double-click tstauri.exe
```

### Option 2: Windows VM

```bash
# On Linux host
bash package-windows.sh

# Transfer to VM (shared folder, scp, etc.)
# Run in VM
```

### Option 3: Wine (Quick Check Only)

```bash
# Install Wine
sudo apt install wine64

# Run (limited testing only)
wine tstauri.exe
```

**Note:** Wine testing is limited - WebView won't work properly. Use real Windows for full testing.

## Troubleshooting

### "x86_64-w64-mingw32-gcc not found"

Run setup:
```bash
bash setup-windows-cross.sh
```

### "error: linker `x86_64-w64-mingw32-gcc` not found"

Reinstall MinGW:
```bash
sudo apt install --reinstall mingw-w64
```

### Build fails with linking errors

Update Cargo config:
```bash
# Run setup again
bash setup-windows-cross.sh
```

### .exe won't run on Windows

**Check:**
1. WebView2 installed? (required for Tauri)
2. All WASM files in same folder?
3. Windows 10 or later?

**Install WebView2:**
https://developer.microsoft.com/microsoft-edge/webview2/

### Different Windows versions needed?

**32-bit Windows:**
```bash
rustup target add i686-pc-windows-gnu
cargo build --release --target i686-pc-windows-gnu
```

**ARM64 Windows:**
```bash
rustup target add aarch64-pc-windows-msvc
# Requires different toolchain setup
```

## Advanced: MSVC Target (Alternative)

For better Windows compatibility, use MSVC toolchain:

```bash
# Install xwin for MSVC cross-compilation
cargo install cargo-xwin

# Add target
rustup target add x86_64-pc-windows-msvc

# Build
cargo xwin build --release --target x86_64-pc-windows-msvc
```

**Pros:**
- Better Windows compatibility
- Smaller binaries
- Official Windows ABI

**Cons:**
- More complex setup
- Requires cargo-xwin
- Longer initial build

## Automation

Add to your workflow:

```bash
# .git/hooks/pre-push
#!/bin/bash
cd tstauri
bash build-windows.sh
bash package-windows.sh
echo "✅ Windows build ready in dist/"
```

## CI Integration (Optional)

Cross-compile in CI instead of using Windows runners:

```yaml
# .github/workflows/quick-windows-build.yml
- name: Cross-compile for Windows
  run: |
    cd tstauri
    bash setup-windows-cross.sh
    bash build-windows.sh
    bash package-windows.sh

- uses: actions/upload-artifact@v4
  with:
    name: windows-portable
    path: tstauri/dist/tstauri-windows-portable.zip
```

**Benefit:** Faster CI, no Windows runner needed for quick builds.

## FAQ

**Q: Is cross-compiled .exe safe?**  
A: Yes! Same as native build. Rust cross-compilation is production-ready.

**Q: Why not always cross-compile?**  
A: MSI installer creation needs Windows-specific tools. But for development, cross-compilation is perfect.

**Q: Can I sign the .exe?**  
A: Code signing typically needs Windows. Use CI for signed releases.

**Q: Performance difference?**  
A: None! Cross-compiled binaries perform identically.

**Q: Can I cross-compile macOS from Linux?**  
A: Technically yes with osxcross, but it's complex. Use CI for macOS builds.

## Best Practice

**Development cycle:**
```
1. Code changes (Linux)
2. Quick test: npm run dev
3. Windows check: bash build-windows.sh
4. Share test build if needed
5. For release: Use CI (all platforms + MSI)
```

This gives you fast iteration while maintaining production-quality releases!

## Summary

✅ **Setup:** One command, 5 minutes  
✅ **Build:** Fast, 2-3 minutes after first build  
✅ **Output:** Portable .exe ready to test  
✅ **Use Case:** Development & quick Windows testing  
✅ **Production:** Still use CI for MSI installers  

You get the best of both worlds: fast local iteration + polished CI releases! 🚀
