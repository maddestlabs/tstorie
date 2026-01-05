# TStoried Development Status

## ✅ Completed Foundation

### 1. Enhanced Stylesheet System
- **File**: [lib/storie_themes.nim](lib/storie_themes.nim)
- Added `applyEditorStyles()` - Complete set of editor UI styles
- Added `applyFullTheme()` - Combines base + editor styles  
- Editor-specific styles: line numbers, cursor, selection, status bar, borders, file browser, markdown syntax

### 2. GitHub Gist API
- **File**: [lib/gist_api.nim](lib/gist_api.nim)
- Load, create, update gists
- Token handling (environment variable + compile-time injection)
- URL parsing helpers
- Error handling with `GistError`
- Convenience functions for markdown files

### 3. Editor Widgets  
- **File**: [lib/tui_editor.nim](lib/tui_editor.nim)
- **TextBox**: Multi-line text editor with cursor, line numbers, scrolling
- **ListView**: File/gist browser with keyboard navigation
- Built to extend lib/tui.nim Widget system

### 5. Build Script
- **File**: [builded.sh](builded.sh)
- Unified native and web compilation
- Arguments for: `-n` (native), `-w` (web), `-a` (both)
- Token injection support: `-t "token"`
- Auto-serve for web: `-w -s`

## 🔨 Architecture Decision Needed

### The Challenge

`tstorie.nim` is designed as a complete terminal application with its own `main()` and event loop. It **includes** user files (like `index.nim`) rather than being imported as a library.

`tstoried.nim` needs to be a standalone editor application, but wants to reuse tstorie's types and systems.

### Three Possible Approaches

#### Option A: Refactor tstorie.nim  
Split into:
- `lib/tstorie_core.nim` - Types, terminal handling, rendering (no main loop)
- `tstorie.nim` - Main application that imports core + includes user file
- `tstoried.nim` - Editor that imports core

**Pros**: Clean separation, reusable core
**Cons**: Requires refactoring existing tstorie.nim

#### Option B: Duplicate Foundation
- `tstoried.nim` uses only lib/ modules
- Implements its own minimal terminal loop
- Independent of tstorie.nim

**Pros**: No changes to tstorie.nim, simpler dependencies
**Cons**: Some code duplication (terminal setup, input parsing)

#### Option C: tstoried as tstorie Plugin
- Restructure tstoried to be included by tstorie like index.nim
- Compile as: `nim c tstorie.nim -d:userFile=tstoried`  
- tstoried gets access to all tstorie infrastructure

**Pros**: Full access to tstorie systems, no duplication
**Cons**: tstoried isn't truly standalone, less clear separation

## 📋 Next Steps

1. **Choose architecture** (recommend Option A for long-term, Option B for quick MVP)

2. **If Option B (Standalone)**:
   - Create minimal terminal init/shutdown in tstoried.nim
   - Implement simple input polling loop
   - Use lib/ module types directly
   - Build standalone TUI widget system

3. **If Option A (Refactor)**:
   - Extract tstorie.nim core into lib/tstorie_core.nim
   - Update tstorie.nim to import core
   - Update index.nim imports
   - tstoried.nim imports core

4. **Implement Editor Features**:
   - Hook up file save/load
   - Integrate gist API calls
   - Add preview rendering (using canvas if available)
   - Syntax highlighting in TextBox
   - Command palette

## 🎯 What Works Now

- All library modules compile independently
- Gist API is fully functional
- Themes and styles are complete
- Widget foundations are solid
- Build script is polished

## 💡 Recommendation

For fastest path to working editor:

**Go with Option B** - Make tstoried fully standalone using just lib/ modules. This avoids refactoring tstorie.nim and gives a clean, focused editor. Later, if there's value in sharing more code, refactor to Option A.

Implement:
1. Simple terminal setup (hideCursor, enableRawMode, etc.)
2. Basic input loop (readChar + parse to InputEvent)
3. Render loop using lib/ module types
4. Connect existing TextBox/ListView widgets
5. Hook up gist_api for load/save

Estimated: 2-3 hours for basic working editor.
