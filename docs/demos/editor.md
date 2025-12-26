---
title: Code Editor Demo
theme: "catpuccin"
---

# Code Editor Demo

A basic code editor with localStorage save/load and live preview.

**Controls:**
- Arrow keys: Navigate
- Type to edit
- Ctrl+S: Save to localStorage
- Ctrl+L: Load from localStorage
- Ctrl+P: Save & open live preview
- Q: Quit

```nim on:init
# Storage key for current document
var storageKey = "tstorie_editor_demo"

# Create widget manager
nimini_newWidgetManager()
nimini_enableMouse()

# Create the text editor (multi-line)
nimini_newTextBox("editor", 0, 3, 80, 18)

# Load from localStorage or set default content
var savedContent = nimini_localStorage_getItem(storageKey)
if savedContent == "":
  savedContent = "# My tstorie Script. Press Ctrl+S to save. Press Ctrl+P to preview"

nimini_widgetSetText("editor", savedContent)

# Create buttons
nimini_newButton("btn_save", 2, 22, 10, 3, "Save")
nimini_newButton("btn_load", 14, 22, 10, 3, "Load")  
nimini_newButton("btn_preview", 26, 22, 12, 3, "Preview")

# Status label
nimini_newLabel("status", 2, 26, 76, 1, "Ready - Type to edit, Ctrl+S to save")
```

```nim on:update
# Update widget manager
nimini_widgetManagerUpdate(deltaTime)
```

```nim on:render
# Clear layers
bgClear()
fgClear()

# Draw header
bgWriteText(2, 1, "CODE EDITOR - Edit markdown below")

# Render all widgets (including TextBox editor)
nimini_widgetManagerRender("foreground")
```

```nim on:input
# Handle keyboard shortcuts
if event.type == "key":
  # Ctrl+S - Save
  if event.keyMods == "ctrl" and event.keyCode == 115:  # 's'
    var content = nimini_widgetGetText("editor")
    nimini_localStorage_setItem(storageKey, content)
    nimini_widgetSetText("status", "✓ Saved to localStorage")
    return 1
  
  # Ctrl+L - Load
  if event.keyMods == "ctrl" and event.keyCode == 108:  # 'l'
    var content = nimini_localStorage_getItem(storageKey)
    if content != "":
      nimini_widgetSetText("editor", content)
      nimini_widgetSetText("status", "✓ Loaded from localStorage")
    else:
      nimini_widgetSetText("status", "⚠ No saved content found")
    return 1
  
  # Ctrl+P - Preview
  if event.keyMods == "ctrl" and event.keyCode == 112:  # 'p'
    var content = nimini_widgetGetText("editor")
    nimini_localStorage_setItem(storageKey, content)
    var previewUrl = "https://maddestlabs.github.io/tstorie?content=browser:" & storageKey
    nimini_window_open(previewUrl, "_blank")
    nimini_widgetSetText("status", "✓ Opening preview in new window...")
    return 1

# Let widget manager handle editor input (typing, arrows, etc)
var handled = nimini_widgetManagerHandleInput()
if handled:
  # Check for button clicks
  if nimini_widgetWasClicked("btn_save"):
    var content = nimini_widgetGetText("editor")
    nimini_localStorage_setItem(storageKey, content)
    nimini_widgetSetText("status", "✓ Saved to localStorage")
  
  if nimini_widgetWasClicked("btn_load"):
    var content = nimini_localStorage_getItem(storageKey)
    if content != "":
      nimini_widgetSetText("editor", content)
      nimini_widgetSetText("status", "✓ Loaded from localStorage")
    else:
      nimini_widgetSetText("status", "⚠ No saved content found")
  
  if nimini_widgetWasClicked("btn_preview"):
    var content = nimini_widgetGetText("editor")
    nimini_localStorage_setItem(storageKey, content)
    var previewUrl = "https://maddestlabs.github.io/tstorie?content=browser:" & storageKey
    nimini_window_open(previewUrl, "_blank")
    nimini_widgetSetText("status", "✓ Opening preview in new window...")

return 0
```

---

## How It Works

This demo shows localStorage integration for code editing workflows. Currently, the TextBox widget is not yet exposed to the nimini scripting API, so this demo:

1. **Displays content** from a variable using `fgWriteTextBox()`
2. **Saves/loads** to/from localStorage
3. **Opens previews** in new windows

To edit content, you can:
- Edit the `editorContent` variable in the init block
- Use browser DevTools to modify localStorage directly
- Wait for the interactive TextBox widget to be added to nimini API

### Current Workflow

1. Modify the content in the `on:init` block
2. Run the demo to see it displayed
3. Click **Save** to store it in localStorage
4. Click **Preview** to see it rendered in tstorie
5. Edit localStorage manually in browser DevTools
6. Click **Load** to reload from localStorage

### Widget Setup (on:init)
- **Buttons**: Save, Load, and Preview actions
- **localStorage**: Loads saved content on startup

### Input Handling (on:input)

The editor responds to:
- **Keyboard shortcuts**: Ctrl+S, Ctrl+L, Ctrl+P for save/load/preview
- **Button clicks**: Mouse-based alternatives to shortcuts
- **Text editing**: All typing, navigation, backspace, etc. handled by TextBox

### localStorage API

The nimini scripting environment provides:
- `nimini_localStorage_setItem(key, value)` - Save content
- `nimini_localStorage_getItem(key)` - Load content
- `nimini_window_open(url, target)` - Open preview window
- `fgWriteTextBox(x, y, w, h, text)` - Display text in a box

### Live Preview

Clicking Preview or pressing Ctrl+P:
1. Saves current content to localStorage
2. Opens `https://maddestlabs.github.io/tstorie?content=browser:<key>`
3. tstorie loads content from localStorage and renders it

### Available TextBox Operations

```nim
# Get/set text
var text = nimini_widgetGetText("editor")
nimini_widgetSetText("editor", "New content")

# Configure properties
nimini_widgetSetProperty("editor", "showLineNumbers", "true")
nimini_widgetSetProperty("editor", "readOnly", "false")

# The TextBox widget automatically handles:
# - Cursor movement (arrows, home, end)
# - Text insertion (typing)
# - Deletion (backspace, delete)
# - Line breaks (enter)
# - Scrolling (automatic when cursor moves)
```

## Try It Out

1. Type and edit the markdown content directly in the editor
2. Press **Ctrl+S** or click **Save** to store it in localStorage
3. Press **Ctrl+P** or click **Preview** to see it rendered
4. The preview opens in a new window/tab showing your presentation
5. Make more edits and preview again - changes update instantly!

## Storage Key

The demo uses `tstorie_editor_demo` as the localStorage key. You can:
- Change `storageKey` in the init block for different documents
- Create multiple editor demos with different keys
- Share the same key across demos to edit the same content

## Extending the Editor

This editor can be enhanced with:
- **Syntax highlighting**: Color markdown syntax elements
- **Find/replace**: Search functionality
- **Undo/redo**: Built into TextBox widget already!
- **Line/character count**: Display document statistics
- **Auto-save**: Save on timer or after changes
- **Multiple documents**: Tab-based interface
- **Export to file**: Download button for native builds
