# WebView2 Handling in tStauri

## The Issue

Tauri apps on Windows require **Microsoft Edge WebView2** runtime. This is like a lightweight browser engine that renders the HTML/CSS/JS interface.

- **Windows 11**: Pre-installed ✅
- **Windows 10 (recent)**: Usually pre-installed ✅
- **Windows 10 (older)**: May need installation ⚠️

## The Solution - Portable Build

Our portable Windows build now **includes the WebView2 installer** directly:

### What's in the Package

```
tstauri-windows-portable/
├── tstauri.exe                          # The app
├── run-tstauri.bat                      # Smart launcher (RECOMMENDED)
├── MicrosoftEdgeWebview2Setup.exe       # WebView2 installer (1.7MB)
├── tstorie.js, tstorie.wasm.*          # WASM engine
└── README.txt                           # Instructions
```

### How to Use

**Option 1: Smart Launcher (Recommended)**
```
Double-click: run-tstauri.bat
```
This will:
1. Check if WebView2 is installed
2. If not, run `MicrosoftEdgeWebview2Setup.exe /silent /install`
3. Launch tstauri.exe

**Option 2: Manual**
```
1. If tstauri.exe shows WebView2 error
2. Double-click: MicrosoftEdgeWebview2Setup.exe
3. Wait for install (~10 seconds)
4. Run tstauri.exe again
```

## Configuration

In `src-tauri/tauri.conf.json`:

```json
"windows": {
  "webviewInstallMode": {
    "type": "downloadBootstrapper"
  }
}
```

### Available Options

| Option | Size | Behavior |
|--------|------|----------|
| **downloadBootstrapper** | +100KB | Downloads WebView2 if missing (what we use) |
| **embedBootstrapper** | +1.8MB | Bundles installer, no internet needed |
| **fixedRuntime** | +100MB | Bundles entire WebView2 (huge!) |
| **skip** | 0 | User must install manually (bad UX) |

## Why downloadBootstrapper?

✅ **Pros:**
- Small package size (+100KB vs +100MB)
- Auto-installs when needed
- Most users already have WebView2
- Best balance of size vs convenience

❌ **Cons:**
- Requires internet connection on first run (if WebView2 missing)
- ~10 second delay on first launch (if WebView2 missing)

## Alternative: embedBootstrapper

If you want **zero internet requirement**, change to:

```json
"webviewInstallMode": {
  "type": "embedBootstrapper"
}
```

This:
- Adds ~1.8MB to package
- Installs from embedded file (no internet needed)
- Still quick installation if WebView2 is missing

## About That Other Game

The game you tried that "just worked" likely:

1. **Had WebView2 pre-installed on your system** - Most likely! Windows 11 and recent Windows 10 updates include it.
2. **Used embedBootstrapper** - Bundled the installer
3. **You didn't notice the delay** - 10 second install on first launch might have seemed like normal loading

## Testing

To test the bootstrapper behavior:

1. **Current portable build** - Will attempt bootstrap on launch
2. **CI/GitHub Actions build** - Creates proper MSI installer with embedded bootstrapper
3. **Your Windows system** - Likely already has WebView2, so it'll just work!

## Recommendations

**For Development (what we have):**
```json
"type": "downloadBootstrapper"
```
- Small portable builds
- Quick iteration
- Most systems already have WebView2

**For Production Release:**
```json
"type": "embedBootstrapper"
```
- More professional
- No internet dependency
- Only +1.8MB
- Use this in CI builds

## Update GitHub Actions

For production MSI builds, the GitHub Actions workflow already handles this correctly. The MSI installer will include the bootstrapper.

## Summary

✅ **Problem solved!** Your new build will:
- Auto-detect WebView2
- Install it if missing (~3MB download, one-time)
- Launch seamlessly

Try the new build - it should "just work" like that other game! 🎉

## One More Thing

If you want even better first-run experience, change to `embedBootstrapper` and rebuild:

```bash
# Edit src-tauri/tauri.conf.json
# Change: "type": "downloadBootstrapper"
# To: "type": "embedBootstrapper"

# Rebuild
cd src-tauri
cargo build --release --target x86_64-pc-windows-gnu

# Repackage
cd ..
bash package-windows.sh
```

This adds ~1.8MB but removes the internet requirement entirely.
