# tStauri Quick Reference

## 🎯 Most Common Commands

```bash
cd tstauri

# Local development (hot reload)
npm run dev

# Windows cross-compile (Linux → .exe)
bash build-windows.sh

# Full Windows package
bash package-windows.sh
```

## 📁 File Locations

| What | Where |
|------|-------|
| Dev app | http://localhost:1420 (when running dev) |
| Windows .exe | `src-tauri/target/x86_64-pc-windows-gnu/release/tstauri.exe` |
| Windows package | `dist/tstauri-windows-portable.zip` |
| App icons | `src-tauri/icons/` |
| WASM files | `../docs/tstorie.wasm.*` |

## 🔧 Setup Commands

```bash
# One-time setups
bash setup-windows-cross.sh    # Enable Windows cross-compilation
bash generate-icons.sh          # Regenerate icons from favicon
npm install                     # Install dependencies
```

## 🚀 Build Types

| Type | Command | Time | Output | Use For |
|------|---------|------|--------|---------|
| **Dev** | `npm run dev` | Instant | Local server | Development |
| **Windows (cross)** | `bash build-windows.sh` | 2-3 min | .exe | Testing |
| **Windows (package)** | `bash package-windows.sh` | +10 sec | .zip | Sharing |
| **Production (CI)** | Push tag | 15-20 min | All platforms + MSI | Release |

## 📚 Documentation

| Doc | Purpose |
|-----|---------|
| [README.md](README.md) | User docs |
| [WINDOWS_CROSS_COMPILE.md](WINDOWS_CROSS_COMPILE.md) | Windows builds |
| [BUILD_PROCESS.md](BUILD_PROCESS.md) | Release workflow |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Dev setup |
| [RELEASE.md](RELEASE.md) | Detailed releases |

## 🎨 Icon Workflow

```bash
# 1. Update source
#    Edit: ../docs/favicon.png

# 2. Regenerate
bash generate-icons.sh

# 3. Commit
git add src-tauri/icons/
git commit -m "Update tStauri icon"
```

## 🪟 Windows Testing Workflow

```
Linux (Development)              Windows (Testing)
───────────────────              ─────────────────

1. Edit code
2. bash build-windows.sh      → Creates .exe
3. bash package-windows.sh    → Creates .zip
                                 4. Transfer ZIP
                                 5. Extract & run
                                 6. Test
7. Fix issues
8. Repeat from step 2
```

## 🏷️ Release Workflow

```bash
# 1. Test locally
npm run dev

# 2. Optional: Quick Windows test
bash build-windows.sh && bash package-windows.sh

# 3. Trigger CI build
git tag tstauri-v0.1.0
git push origin tstauri-v0.1.0

# 4. Wait for draft release (~15-20 min)
# 5. Download & test binaries
# 6. Publish release
```

## ⚡ Speed Comparison

| Action | Time |
|--------|------|
| Local dev (hot reload) | Instant |
| Windows cross-compile | 2-3 min |
| Create portable package | 10 sec |
| CI build (all platforms) | 15-20 min |

## 🐛 Quick Fixes

```bash
# WASM missing
cd .. && ./build-web.sh -o docs && cd tstauri

# Icons missing
bash generate-icons.sh

# Dependencies outdated
npm install

# Clean build
rm -rf src-tauri/target node_modules
npm install
```

## 🎯 Target Platforms

| Platform | Dev | Cross-Compile | CI |
|----------|-----|---------------|-----|
| Linux | ✅ Native | ✅ Native | ✅ AppImage |
| macOS | ✅ Native | ❌ Complex | ✅ DMG (Intel + ARM) |
| Windows | ⚠️ WSL/VM | ✅ **Yes!** | ✅ MSI |

## 📊 Output Sizes

| Type | Size |
|------|------|
| .exe (cross-compiled) | ~5-8 MB |
| Portable .zip | ~6-9 MB |
| MSI installer (CI) | ~75 MB |
| AppImage (CI) | ~80 MB |
| macOS DMG (CI) | ~65-70 MB |

## 🔑 Key Features

- ✅ **Cross-compile Windows** - Build .exe on Linux
- ✅ **Fast iteration** - 2-3 min builds
- ✅ **Portable packages** - No installation needed
- ✅ **CI automation** - Full platform builds
- ✅ **Draft releases** - Test before publishing

## 💡 Pro Tips

1. **Fast Windows testing:** Use cross-compilation instead of waiting for CI
2. **Icon updates:** Just run `generate-icons.sh`
3. **WASM sync:** Rebuild WASM before tStauri releases
4. **CI is for releases:** Use cross-compile for development
5. **Portable first:** Test .exe before making MSI

## 🆘 Getting Help

- Check [WINDOWS_CROSS_COMPILE.md](WINDOWS_CROSS_COMPILE.md) for cross-compile issues
- Check [BUILD_PROCESS.md](BUILD_PROCESS.md) for CI/release issues
- Check [DEVELOPMENT.md](DEVELOPMENT.md) for setup problems
- Check GitHub Actions logs for CI failures

## 🎉 You're Ready!

Start with: `npm run dev` 🚀
