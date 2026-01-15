# tStauri Optimal Build Process

## Quick Answer

**Yes!** GitHub Actions can auto-build tStauri binaries, and here's the optimal workflow:

## 🎯 Optimal Workflow

### 1. **Local Development & Testing** (You do this)

```bash
# Test your changes locally
cd tstauri
npm run dev
# Drop test files, verify everything works

# OPTIONAL: Quick Windows build for testing
bash build-windows.sh      # Cross-compile .exe on Linux
bash package-windows.sh    # Create portable package
# Transfer to Windows machine for testing
```

### 2. **Draft Release via GitHub Actions** (CI does this)

```bash
# When ready, trigger a CI build
# Option A: Manual dispatch (GitHub UI)
#   → Go to Actions → Build tStauri Desktop → Run workflow
#   → Keep "draft release" checked

# Option B: Create a tag
git tag tstauri-v0.1.0
git push origin tstauri-v0.1.0
```

**What happens:**
- ✅ Builds for Linux, macOS (Intel + ARM), Windows
- ✅ Creates a **draft release** (not public yet)
- ✅ Attaches all binaries
- ⏱️ Takes ~15-20 minutes

### 3. **Test the Draft Release** (You do this)

```bash
# Download binaries from the draft release
# Test on as many platforms as you can:

# Linux
chmod +x tStauri_*.AppImage
./tStauri_*.AppImage

# macOS - download and test
# Windows - download and test
```

**What to test:**
- App launches
- Drag & drop works
- Multiple files work
- No crashes or errors

### 4. **Publish Release** (You do this)

If tests pass:
- Go to the draft release on GitHub
- Click "Publish release"
- Binaries are now public! 🎉

## 💡 Why This Is Optimal

| Aspect | Solution |
|--------|----------|
| **Auto-build?** | ✅ Yes - GitHub Actions builds all platforms |
| **Test before release?** | ✅ Yes - Draft releases let you test first |
| **Windows cross-compile?** | ✅ Yes - Build .exe on Linux for quick testing |
| **Manual builds?** | ⚠️ Optional - Cross-compile Windows, CI for others |
| **Cost?** | ✅ Free on public repos |
| **Time?** | ⏱️ 15-20 min automated build, 2-3 min local Windows build |

## 📋 Full Release Process

```
┌─────────────────────┐
│ 1. Local Testing    │  ← You test locally first
│    npm run dev      │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 1a. Quick Windows   │  ← OPTIONAL: Cross-compile for early testing
│     Cross-Compile   │     bash build-windows.sh (2-3 min)
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 2. Trigger CI       │  ← Push tag or manual dispatch
│    git tag & push   │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 3. CI Builds All    │  ← Automated, ~15-20 min
│    Platforms        │     Linux, macOS, Windows (MSI)
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 4. Draft Release    │  ← You download & test binaries
│    Created          │
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ 5. You Test         │  ← Manual testing on real systems
│    Binaries         │     (This is the quality gate)
└──────────┬──────────┘
           │
           ├─── ❌ Issues found → Fix code, repeat from step 1
           │
┌──────────▼──────────┐
│ 6. Publish Release  │  ← Make binaries public
│    ✅ Done!         │
└─────────────────────┘
```

## 🧪 Testing Strategy

### Minimal Testing (Quick Release)

Test on **one platform** (your dev machine):
- ✅ Local dev mode (`npm run dev`)
- ✅ Download draft release binary for your OS
- ✅ Test basic functionality

**Good for:** Small fixes, documentation updates

### Thorough Testing (Major Release)

Test on **all platforms**:
- ✅ Local dev mode
- ✅ Download draft release for Linux, macOS, Windows
- ✅ Test on actual hardware (VMs count)
- ✅ Test multiple `.md` files
- ✅ Check for memory leaks, performance

**Good for:** New features, major versions

### Community Testing (Beta Release)

Publish draft as "pre-release":
- ✅ Mark as pre-release (not draft)
- ✅ Announce to community
- ✅ Gather feedback
- ✅ Create final release after fixes

**Good for:** Breaking changes, experimental features

## 🔄 Typical Release Cadence

```
Week 1-2: Development
├─ Local testing during development
├─ Multiple npm run dev sessions
└─ Code reviews

Week 3: Pre-release
├─ Trigger CI draft build
├─ Download & test binaries
├─ Fix any issues found
└─ Repeat if needed

Week 4: Release
├─ Final CI build
├─ Quick smoke test
├─ Publish release
└─ Monitor for issues
```

## 🚀 GitHub Actions Features We Use

### 1. **Matrix Builds**
Builds all platforms in parallel:
```yaml
matrix:
  platform: [ubuntu-22.04, macos-latest, windows-latest]
```

### 2. **Draft Releases**
```yaml
releaseDraft: ${{ github.event.inputs.draft != 'false' }}
```
Creates unpublished releases for testing.

### 3. **Artifacts**
Even if release fails, binaries are saved:
```yaml
- uses: actions/upload-artifact@v4
```

### 4. **Manual Dispatch**
Trigger builds from UI without tags:
```yaml
workflow_dispatch:
  inputs:
    draft: ...
```

## ❓ Common Questions

### Q: Do I need to build locally?

**A:** No for production! But yes for fast Windows testing:
- **Development**: `npm run dev` (instant feedback)
- **Windows testing**: `bash build-windows.sh` (2-3 min, .exe ready)
- **Production release**: CI builds everything (15-20 min, MSI + all platforms)

### Q: How do I test on platforms I don't have?

**A:** Options:
1. Ask community members to test
2. Use VMs (VirtualBox, Parallels, etc.)
3. GitHub Codespaces / cloud VMs
4. Trust CI if changes are minimal

### Q: What if the CI build fails?

**A:** Check the logs:
1. Go to Actions tab
2. Click the failed workflow
3. Read error messages
4. Fix code, push, retry

Common causes:
- WASM build fails (Nim/Emscripten issue)
- Icon generation fails (ImageMagick)
- Dependency issues (outdated Rust crates)

### Q: Can I automate testing too?

**A:** Yes! Future enhancements:
- Add automated smoke tests to CI
- Use Tauri's testing framework
- Screenshot comparison tests
- Performance benchmarks

### Q: Should every commit trigger a build?

**A:** No! That would be wasteful. Only build on:
- Tagged releases (`tstauri-v*`)
- Manual dispatch when ready
- Maybe on main branch PRs (optional)

## 📊 Build Time Breakdown

Typical CI run (~15-20 min total):

```
Setup Nim/Emscripten:     ~2 min
Build WASM:               ~5 min
Generate Icons:           ~10 sec
───────────────────────────────────
Linux build:              ~5 min  ┐
macOS builds (2):         ~7 min  │ In parallel
Windows build:            ~7 min  ┘
───────────────────────────────────
Create release:           ~30 sec
Total:                    ~15-20 min
```

## 🎬 First Release Walkthrough

Let's do a complete first release:

```bash
# 1. Make sure everything is committed
git status

# 2. Test locally
cd tstauri
npm install
npm run dev
# Test thoroughly!

# 3. Trigger CI build (manual dispatch)
# Go to: https://github.com/maddestlabs/tstorie/actions
# → Build tStauri Desktop
# → Run workflow
# → Leave "draft" checked
# → Run

# 4. Wait ~15-20 min, then:
# Go to: https://github.com/maddestlabs/tstorie/releases
# → Click the draft release
# → Download tStauri for your OS

# 5. Test the downloaded binary
chmod +x tStauri*.AppImage  # If Linux
./tStauri*.AppImage

# 6. If all good, publish!
# Edit draft release → Publish

# 🎉 First release complete!
```

## Summary

✅ **Feasible:** Absolutely! This is how most desktop apps do releases.  
✅ **Optimal:** CI handles all platforms, you just test and publish.  
✅ **Windows Priority:** Cross-compile .exe on Linux for fast testing.  
✅ **Testing:** Draft releases are the standard approach.  
✅ **Manual work:** Only testing - builds are automatic.

Your workflow is production-ready! 🚀

## WebGL Renderer Integration

tStauri now uses the **WebGL renderer** from tstorie core, providing:
- **10-100× faster rendering** through GPU instanced drawing
- **Full Unicode support** including CJK characters (Japanese, Chinese, Korean)
- **Dynamic glyph caching** for on-demand character atlas generation
- **Native shader support** for terminal effects

### Loading Sequence

The initialization order is critical for WebGL:

1. **Load WASM runtime** (`tstorie.wasm.js`)
2. **Wait for `onRuntimeInitialized` callback**
3. **Load WebGL renderer** (`tstorie-webgl.js`) - provides `TStorieTerminal` class
4. **Load terminal wrapper** (`tstorie.js`) - provides `inittstorie()` function
5. **Call `inittstorie()`** to create the terminal

### Bundled Files

The following files are bundled in `tauri.conf.json`:
- `tstorie.wasm.wasm` - Compiled WASM binary
- `tstorie.wasm.js` - Emscripten runtime
- `tstorie-webgl.js` - **WebGL renderer (NEW)**
- `tstorie.js` - Terminal wrapper API

### Browser Compatibility

WebGL2 is supported in 99%+ of browsers as of 2026:
- Chrome/Edge 56+ (March 2017+)
- Firefox 51+ (January 2017+)
- Safari 15+ (September 2021+)
- Opera 43+ (March 2017+)

Tauri's webview on all platforms supports WebGL2.

## See Also

- **[WINDOWS_CROSS_COMPILE.md](WINDOWS_CROSS_COMPILE.md)** - Build Windows .exe on Linux
- **[RELEASE.md](RELEASE.md)** - Complete release guide
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Local development setup
- **[../../WEBGL_MIGRATION.md](../../WEBGL_MIGRATION.md)** - WebGL renderer details
