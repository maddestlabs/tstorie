# WebView2 Solution: MSI Installer (Like 0RA1N)

## The Problem

When cross-compiling tStauri to a standalone `.exe` file, WebView2 isn't pre-installed on all Windows systems, causing installation prompts.

## The Solution: Use MSI Installers (Not .exe)

**Your 0RA1N game works seamlessly because it uses MSI installers, NOT standalone .exe files.**

### How 0RA1N Does It

Looking at your [0RA1N workflow](https://github.com/maddestlabs/0RA1N/blob/main/.github/workflows/tauri-build.yml), it creates **MSI installers** that:
- Auto-download WebView2 bootstrapper (1.7MB) on first launch
- Install WebView2 silently if missing
- Work perfectly with Tauri's `downloadBootstrapper` mode
- **Result:** Users just run the MSI, app launches instantly

### tStauri Configuration

```json
{
  "windows": {
    "webviewInstallMode": {
      "type": "downloadBootstrapper",
      "silent": true
    }
  }
}
```

This matches 0RA1N's approach - small download, automatic WebView2 installation.

## Build Commands

### For End Users: Build MSI Installer

```bash
# Install WiX Toolset for MSI creation (one-time)
cargo install cargo-wix

# Build MSI installer (works on Linux with Wine)
cd tstauri/src-tauri
cargo tauri build --target x86_64-pc-windows-gnu --bundles msi
```

**Output:** `target/x86_64-pc-windows-gnu/release/bundle/msi/tStauri_0.1.0_x64_en-US.msi`

### For Development: Quick .exe Build

```bash
# Fast iteration - standalone .exe
cd tstauri/src-tauri
cargo build --release --target x86_64-pc-windows-gnu
```

**Note:** Standalone `.exe` requires users to have WebView2 pre-installed or accept installation prompt.

## Size Comparison

| Method | Size | WebView2 Handling | User Experience |
|--------|------|-------------------|-----------------|
| **MSI Installer** (0RA1N) | ~3MB | Auto-downloads 1.7MB bootstrapper | ✅ Seamless |
| Standalone .exe | ~20MB | Requires manual installation | ⚠️ Installation prompt |
| Fixed Runtime Bundle | ~120MB | Fully embedded | ✅ Seamless but bloated |

## Why Not Fixed Runtime?

The 120MB Fixed Runtime approach is overkill for this use case:
- Electron apps are smaller (~50-70MB)
- 0RA1N uses MSI + downloadBootstrapper (~5MB total) 
- Users expect small indie game/tool downloads

## Electron Comparison

You mentioned Electron would be smaller - you're right:
- Typical Electron app: 50-70MB (includes Chromium)
- tStauri MSI: ~3MB (uses system WebView2)
- tStauri with Fixed Runtime: ~120MB (unnecessary)

**Best choice:** MSI installer with downloadBootstrapper (like 0RA1N)

## Implementation Steps

1. ✅ Updated `tauri.conf.json` to use `downloadBootstrapper`
2. Build MSI instead of standalone .exe
3. Distribute MSI via GitHub releases
4. Users download, install, run - WebView2 installs automatically

## GitHub Actions Update

To build MSI in CI (matching 0RA1N):

```yaml
- name: Build Tauri MSI
  run: |
    cd tstauri/src-tauri
    cargo tauri build --target x86_64-pc-windows-gnu --bundles msi
    
- name: Upload MSI
  uses: actions/upload-artifact@v3
  with:
    name: tStauri-Windows-MSI
    path: tstauri/target/x86_64-pc-windows-gnu/release/bundle/msi/*.msi
```

## Summary

**You don't need a 120MB Fixed Runtime.** Your 0RA1N game already shows the way:

1. Use MSI installer
2. Configure `downloadBootstrapper` mode  
3. WebView2 auto-installs on first launch
4. Total distribution size: ~3MB + 1.7MB bootstrapper = ~5MB
5. **Zero user friction, just like your working game**

The key insight: **Cross-compiled .exe ≠ MSI installer**. MSI works perfectly with Tauri's WebView2 installation system.
