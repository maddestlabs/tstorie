# TStoried Preview Architecture

## Overview

TStoried implements **platform-specific preview modes** that optimize for each target environment:

- **Native (Terminal)**: Shells out to separate `tstorie` process
- **WASM (Browser)**: Bundles tstorie rendering engine for split-canvas view

This document explains the design decisions and implementation details.

## Why Platform-Specific?

### Native Constraints
- Terminal is single-process by nature
- Can't easily render two independent views in one terminal
- tmux/screen provide natural split-pane functionality
- Shelling out keeps tstoried binary lean (240KB vs 450KB+)

### WASM Advantages
- Browser has proper UI layering and canvas support
- Can render multiple views simultaneously
- Cross-origin restrictions make shelling out impractical
- Users expect integrated split-view in web editors

## Native Implementation

### Architecture
```
┌─────────────────────────────────────┐
│  Terminal (managed by tmux)         │
├──────────────┬──────────────────────┤
│              │                      │
│  tstoried    │    ./tstorie         │
│  (editing)   │    (viewing)         │
│              │                      │
│  240KB       │    Separate process  │
└──────────────┴──────────────────────┘
```

### Code
```nim
when not defined(js):
  proc launchPreview() =
    # Save content to temp file
    let tempFile = "/tmp/tstoried_preview.md"
    writeFile(tempFile, getText())
    
    # Check if in tmux session
    if getEnv("TMUX") != "":
      # Split window horizontally, run tstorie
      discard execShellCmd("tmux split-window -h './tstorie " & tempFile & "'")
    else:
      # No tmux, take over terminal temporarily
      discard execShellCmd("./tstorie " & tempFile)
```

### Workflow
1. User presses `Ctrl+R` in tstoried
2. Current content saved to `/tmp/tstoried_preview.md`
3. If in tmux: Split pane and launch tstorie
4. If not in tmux: Launch tstorie in same terminal (blocks editor)
5. When tstorie exits, control returns to editor

### Benefits
- **Minimal overhead**: tstoried stays at 240KB
- **Full tstorie features**: Uses actual tstorie binary
- **Natural UX**: tmux users get expected split behavior
- **No code duplication**: One tstorie codebase

### Limitations
- **Requires tmux** for split view (or takes over terminal)
- **No live updates**: Must press Ctrl+R again to refresh
- **File-based communication**: Temp file as bridge

## WASM Implementation

### Architecture
```
┌─────────────────────────────────────┐
│  tstoried.wasm (single bundle)      │
├──────────────┬──────────────────────┤
│              │                      │
│  Editor      │    Preview           │
│  TextBox     │    tstorie renderer  │
│              │                      │
│  Same process, split canvas         │
└──────────────┴──────────────────────┘
```

### Code
```nim
when defined(js):
  # Import tstorie rendering modules
  import lib/[canvas, storie_md, section_manager, layout, drawing]
  
  proc renderPreview() =
    # Parse current markdown
    let sections = parseMarkdown(getText())
    
    # Render to preview canvas (right half)
    renderSectionToCanvas(sections[currentSection], previewCanvas)
  
  proc renderSplit() =
    let splitX = termWidth div 2
    
    # Left half: Editor
    renderEditor(0, 0, splitX, termHeight)
    
    # Vertical divider
    drawDivider(splitX)
    
    # Right half: Preview
    renderPreview()
```

### Workflow
1. User presses `Ctrl+R` in browser
2. Split mode activates
3. Canvas splits: left = editor, right = preview
4. Preview renders **live** as user types
5. Press `Esc` to exit split view

### Benefits
- **True live preview**: Updates as you type
- **Integrated UX**: No external processes
- **Section navigation**: Space/Enter for next, B for previous
- **No cross-origin issues**: All client-side

### Limitations
- **Larger bundle**: ~450KB (vs 240KB native)
- **More memory**: Full tstorie engine in memory
- **Complex build**: Must compile both editor + renderer

## Shared Code

Despite platform differences, most code is shared:

### Common (Both Platforms)
```nim
# Core editing logic
proc insertChar(ch: char)
proc deleteChar()
proc insertNewline()
proc moveCursor(drow, dcol)

# File operations
proc loadFile(path: string)
proc saveFile()

# Gist integration
proc loadGistById(id: string)
proc createOrUpdateGist()

# Browser
proc populateBrowser()
proc switchMode(mode: EditorMode)
```

### Platform-Specific
```nim
# Native only
when not defined(js):
  proc launchPreview()  # Shell out to tstorie

# WASM only
when defined(js):
  proc renderPreview()  # Inline rendering
  proc nextSection()
  proc prevSection()
```

## Build Implications

### Native
```bash
./builded.sh --native
# Compiles: tstoried only
# Output: tstoried (240KB)
# Runtime: Requires ./tstorie binary for preview
```

### WASM
```bash
./builded.sh --web
# Compiles: tstoried + tstorie renderer
# Output: tstoried.wasm (~450KB)
# Runtime: Self-contained, no dependencies
```

## Future Enhancements

### Native
- [ ] **Live reload**: Watch temp file, auto-refresh tstorie
- [ ] **IPC communication**: Socket between tstoried and tstorie
- [ ] **Screen support**: Detect and use `screen` like tmux
- [ ] **Vertical split**: Option for top/bottom layout

### WASM
- [ ] **Debounced updates**: Don't re-render on every keystroke
- [ ] **Section sync**: Auto-scroll to section cursor is in
- [ ] **Syntax highlighting**: Markdown aware in editor pane
- [ ] **Drag divider**: Resizable split position

### Both
- [ ] **Auto-save preview**: Don't lose work on preview
- [ ] **Preview config**: Theme, zoom, section start
- [ ] **Export from preview**: Save rendered output

## Design Lessons

### Why This Works

1. **Platform-appropriate UX**
   - Native: Terminal users expect tmux splits
   - WASM: Web users expect integrated views

2. **Optimal resource usage**
   - Native: Lean editor + delegate to viewer
   - WASM: Bundle everything for offline capability

3. **Code reuse where it matters**
   - Shared: 80% (editing, files, gists, UI)
   - Platform-specific: 20% (preview only)

4. **Clear separation of concerns**
   - tstoried: Editing + coordination
   - tstorie: Rendering + presentation

### What We Learned

Building tstoried standalone revealed:
- What's truly **core** (types, themes, input)
- What's **editor-specific** (TextBox, Browser)
- What's **renderer-specific** (Canvas, Section manager)

This informed the preview architecture: **delegate rendering rather than duplicate it**.

## Comparison to Alternatives

### Alternative 1: Always Bundle (Like Option 5)
```nim
# Both native and WASM bundle tstorie
when not defined(js):
  import lib/tstorie_renderer  # Adds 200KB to binary
```

**Rejected because:**
- Native terminal can't do split-canvas anyway
- Wastes 200KB+ for feature that needs tmux
- Duplicates code between tstoried and tstorie

### Alternative 2: Always Shell Out
```nim
# WASM also shells out to tstorie
when defined(js):
  openWindow("https://maddestlabs.github.io/telestorie/?gist=preview")
```

**Rejected because:**
- Cross-origin localStorage doesn't work
- Requires GitHub API for every preview
- Poor UX (opens new tab/window)
- Not truly "live"

### Alternative 3: No Preview in tstoried
```
User workflow:
1. Edit in tstoried
2. Save file
3. Open separate terminal
4. Run ./tstorie file.md
5. Go back to tstoried
```

**Rejected because:**
- Too many steps for rapid iteration
- Breaks flow for content creators
- Defeats purpose of integrated editor

## Conclusion

The **platform-specific preview** architecture is:
- ✅ **Optimal** for each platform's constraints
- ✅ **Lean** where it matters (native binary)
- ✅ **Rich** where it's practical (WASM bundle)
- ✅ **Maintainable** with 80% shared code
- ✅ **User-friendly** with appropriate UX per platform

This is a case where **one size does NOT fit all**, and recognizing that led to a better design.
