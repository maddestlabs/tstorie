# tStauri Build Workflows

This document explains the two GitHub Actions workflows for building tStauri and when to use each one.

## Workflows

### 1. `build-tstauri-windows-portable.yml` - Testing & Development ✅ PRIMARY

**Purpose**: Quick Windows portable build for testing changes

**Trigger**: Manual workflow dispatch only

**Output**: 
- ZIP file: `tstauri-windows-portable.zip`
- Contains: `tstauri.exe`, `WebView2Loader.dll`, launcher, README
- **Portable**: No installer, just extract and run

**When to use**:
- Testing changes before release
- Development builds
- Quick validation of Windows functionality
- Any time you need to test on Windows without full release

**Build time**: ~15-20 minutes

**Advantages**:
- Single job (faster)
- Cross-compiles from Linux (consistent environment)
- Produces portable ZIP for easy testing
- No release/tagging required

**How to run**:
1. Go to Actions tab on GitHub
2. Select "Build tStauri Windows Portable"
3. Click "Run workflow"
4. Download artifact when complete

**Local equivalent**: `./build-windows-portable-local.sh`

---

### 2. `build-tstauri.yml` - Official Releases 📦 FUTURE

**Purpose**: Multi-platform release builds with installers

**Trigger**: 
- Push tags matching `tstauri-v*` (e.g., `tstauri-v0.1.0`)
- Manual workflow dispatch (draft mode)

**Output**:
- **Linux**: AppImage (portable)
- **macOS**: DMG installer (Intel + Apple Silicon)
- **Windows**: MSI installer
- Creates GitHub Release with all platform builds

**When to use**:
- Official versioned releases
- When you need installers (not portable)
- Multi-platform distribution
- Publishing to users

**Build time**: ~45-60 minutes (4 parallel jobs)

**Advantages**:
- Professional installers
- All platforms at once
- Automatic GitHub Release creation
- Proper version tagging

**How to run**:
```bash
# Create and push a tag
git tag tstauri-v0.1.0
git push origin tstauri-v0.1.0

# Or run manually in draft mode via Actions tab
```

---

## Current Status

- ✅ **Windows Portable workflow** - Ready for testing
- 🚧 **Multi-platform workflow** - Ready but not yet used (no tags created)

## Recommended Workflow

### Development Phase (NOW):
1. Make changes to tStauri
2. Test locally with `./build-windows-portable-local.sh`
3. If needed, run GitHub Action "Build tStauri Windows Portable"
4. Download and test on Windows
5. Iterate until satisfied

### Release Phase (LATER):
1. Finalize version
2. Update version in `tstauri/src-tauri/tauri.conf.json`
3. Create tag: `git tag tstauri-v0.1.0`
4. Push tag: `git push origin tstauri-v0.1.0`
5. Wait for all 4 platform builds to complete
6. Download and test all platform releases
7. Publish the GitHub Release (remove draft status)

---

## Which Workflow Should I Use?

| Scenario | Workflow | Command |
|----------|----------|---------|
| Testing a change on Windows | Windows Portable | Manual dispatch or local script |
| Quick validation | Windows Portable | `./build-windows-portable-local.sh` |
| Multi-platform testing | Multi-platform | Manual dispatch (draft mode) |
| Official release | Multi-platform | Push tag `tstauri-v*` |

---

## Notes

- Both workflows use the same WASM build process (`build-web-tauri.sh`)
- Both bundle `welcome.md` as `index.md` with interactive Nim code
- Windows Portable is cross-compiled from Linux (faster, consistent)
- Multi-platform uses native runners (better compatibility)
- Local build script (`build-windows-portable-local.sh`) matches GitHub Action exactly

