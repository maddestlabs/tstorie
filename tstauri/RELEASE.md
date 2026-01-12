# tStauri Release Process

## Overview

tStauri uses GitHub Actions to automatically build desktop binaries for Linux, macOS, and Windows. This document explains the complete release workflow.

## Build Process

### Automated Builds via GitHub Actions

The workflow (`.github/workflows/build-tstauri.yml`) is triggered by:

1. **Git tags** matching `tstauri-v*` (e.g., `tstauri-v0.1.0`)
2. **Manual dispatch** from GitHub Actions UI (with draft option)

When triggered, the workflow:
1. ✅ Builds the latest tStorie WASM from source
2. ✅ Generates app icons from `docs/favicon.png`
3. ✅ Compiles Tauri app for all platforms
4. ✅ Creates GitHub Release with binaries attached

### Platforms Built

- **Linux**: AppImage (Ubuntu 22.04 base)
- **macOS**: 
  - Apple Silicon (ARM64)
  - Intel (x86_64)
  - Packaged as universal DMG
- **Windows**: MSI installer

## Release Workflow (Recommended)

### Step 1: Test Locally

Before creating a release, test on your development machine:

```bash
# Build the latest WASM
./build-web.sh -o docs

# Generate icons
cd tstauri
bash generate-icons.sh

# Test in development mode
npm install
npm run dev
```

**Test checklist:**
- [ ] Drop a `.md` file onto the app
- [ ] Verify it runs correctly
- [ ] Test keyboard shortcuts (Escape)
- [ ] Check UI responsiveness
- [ ] Try different `.md` files (demos, etc.)

### Step 2: Create a Draft Release (Testing in CI)

Use manual workflow dispatch to test the full build process:

1. Go to **Actions** → **Build tStauri Desktop**
2. Click **Run workflow**
3. Select branch: `main`
4. Leave "Create as draft release" **checked** ✅
5. Click **Run workflow**

This creates a **draft release** that:
- Builds all platforms automatically
- Doesn't notify anyone
- Allows you to test binaries before publishing

### Step 3: Test the Built Binaries

Once the workflow completes (~15-20 minutes):

1. Go to **Releases** → find the draft release
2. Download binaries for your platform(s)
3. Test thoroughly:
   - **Linux**: `chmod +x tStauri*.AppImage && ./tStauri*.AppImage`
   - **macOS**: Open DMG, drag to Applications, test
   - **Windows**: Run MSI installer, test installed app

**Extended test checklist:**
- [ ] App launches without errors
- [ ] Icons display correctly
- [ ] File drag & drop works
- [ ] Multiple `.md` files work
- [ ] WASM engine loads properly
- [ ] No console errors

### Step 4: Publish the Release

If everything works:

1. Edit the draft release on GitHub
2. Update release notes if needed
3. Click **Publish release**

The binaries are now public and downloadable by users! 🎉

## Quick Release (When You're Confident)

For experienced releases after thorough local testing:

```bash
# Create and push a tag
git tag tstauri-v0.1.0
git push origin tstauri-v0.1.0
```

This triggers the workflow immediately and creates a draft release automatically.

## Version Numbering

Follow semantic versioning:
- `tstauri-v0.1.0` - First release
- `tstauri-v0.2.0` - New features
- `tstauri-v0.1.1` - Bug fixes
- `tstauri-v1.0.0` - Stable release

Keep tStauri version separate from tStorie core version.

## Manual Building (Advanced)

If you need to build locally instead of using CI:

### Prerequisites Per Platform

**Linux:**
```bash
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file \
  libssl-dev libayatana-appindicator3-dev librsvg2-dev
```

**macOS:**
```bash
xcode-select --install
```

**Windows:**
- Install [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
- Install [Rust](https://rustup.rs/)

### Build Commands

```bash
cd tstauri
npm install
npm run build
```

Binaries will be in `src-tauri/target/release/bundle/`:
- Linux: `appimage/`
- macOS: `macos/` or `dmg/`
- Windows: `msi/`

## Troubleshooting CI Builds

### Build fails on Linux

**Issue**: Webkit dependencies missing

**Fix**: Update workflow to install correct webkit version (4.1 vs 4.0)

### Build fails on macOS

**Issue**: Code signing / notarization

**Fix**: Tauri handles unsigned builds by default. For signed builds, add:
```yaml
env:
  APPLE_CERTIFICATE: ${{ secrets.APPLE_CERTIFICATE }}
  APPLE_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
```

### Build fails on Windows

**Issue**: MSI creation fails

**Fix**: Ensure all icon files are generated correctly

### WASM files not found

**Issue**: `docs/tstorie.wasm.*` missing during bundle

**Fix**: Workflow builds WASM first - check Nim/Emscripten setup in CI

## Icon Updates

To change the app icon:

```bash
# Replace docs/favicon.png with new icon (1024x1024 recommended)
# Then regenerate
cd tstauri
bash generate-icons.sh
git add src-tauri/icons/
git commit -m "Update tStauri icon"
```

## Continuous Integration Notes

### Build Time

Expect ~15-20 minutes total:
- WASM build: ~5 min
- macOS builds: ~5-7 min each
- Linux build: ~3-5 min
- Windows build: ~5-7 min

Builds run in parallel per platform.

### Artifacts

All builds upload artifacts even if release creation fails:
- Check **Actions** → Workflow run → **Artifacts**
- Download for manual inspection

## Security Considerations

### Code Signing

Current setup: **Unsigned binaries**
- macOS: Users see "unidentified developer" warning
- Windows: SmartScreen may warn
- Linux: No warnings

To add signing:
1. Get code signing certificates (Apple Developer account, etc.)
2. Add secrets to GitHub repository
3. Update workflow with signing configuration

### Dependencies

All Rust crates are pinned in `Cargo.toml`. Update regularly:
```bash
cd tstauri/src-tauri
cargo update
```

## Best Practices

1. **Always test locally first** - Saves CI minutes
2. **Use draft releases for testing** - Safe experimentation
3. **Version conservatively** - Users expect stability
4. **Document breaking changes** - Update release notes
5. **Keep WASM in sync** - Rebuild WASM before tStauri releases

## Release Checklist

Before any release:

- [ ] Test locally on at least one platform
- [ ] Verify WASM build is up-to-date
- [ ] Update version in `tstauri/src-tauri/Cargo.toml`
- [ ] Update version in `tstauri/package.json`
- [ ] Update CHANGELOG (if you maintain one)
- [ ] Create draft release via CI
- [ ] Test all platform binaries
- [ ] Update release notes
- [ ] Publish release
- [ ] Announce on relevant channels

## Future Enhancements

Potential improvements:
- Auto-updater (Tauri supports this)
- Code signing for macOS/Windows
- Performance metrics in CI
- Automated UI testing
- Release notes generation from commits

## Support

Issues with the build process? Check:
- [Tauri Documentation](https://tauri.app/)
- [GitHub Actions Logs](../../actions)
- [tStauri Issues](../../issues)
