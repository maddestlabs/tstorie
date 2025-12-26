# TUI TextField Demo

A demonstration of the basic textfield widget for tstoried's TUI toolkit.

## Overview

The `TextField` widget provides a single-line text input control with:
- Character insertion and deletion
- Cursor navigation (arrow keys, Home, End)
- Horizontal scrolling for long text
- Visual cursor feedback

## Basic Usage

```nim
#import editor_base
#import textfield

# Create a textfield at position (5, 10) with width of 40 characters
var field = newTextField(x = 5, y = 10, width = 40)

# Set initial text (optional)
field.setText("Hello, World!")

# Enable focus to receive input
field.focused = true

# Handle keyboard input
let event = InputEvent(
  kind: evKey,
  key: "a",
  keyCode: 97,
  action: "press"
)

if field.handleInput(event):
  echo "Event was handled by the textfield"

# Render to a buffer
var buffer = newBuffer(80, 24)
field.render(buffer)
```

## Keyboard Controls

| Key | Action |
|-----|--------|
| **Left Arrow** | Move cursor left |
| **Right Arrow** | Move cursor right |
| **Home** | Move cursor to start |
| **End** | Move cursor to end |
| **Backspace** | Delete character before cursor |
| **Delete** | Delete character at cursor |
| **Any character** | Insert character at cursor |

## API Reference

### Creating a TextField

```nim
proc newTextField*(x, y, width: int): TextField
```

Creates a new textfield widget positioned at `(x, y)` with the specified display width.

### Text Operations

```nim
proc insert*(tf: TextField, ch: string)
proc deleteChar*(tf: TextField)         # Delete at cursor
proc backspace*(tf: TextField)          # Delete before cursor
proc clear*(tf: TextField)              # Clear all text
proc setText*(tf: TextField, text: string)
```

### Cursor Navigation

```nim
proc moveCursorLeft*(tf: TextField)
proc moveCursorRight*(tf: TextField)
proc moveCursorHome*(tf: TextField)
proc moveCursorEnd*(tf: TextField)
```

### Input Handling

```nim
proc handleInput*(tf: TextField, event: InputEvent): bool
```

Processes an input event. Returns `true` if the event was handled, `false` otherwise. The textfield must be focused to handle input.

### Rendering

```nim
proc render*(tf: TextField, buf: var Buffer)
proc renderToLayer*(tf: TextField, layer: Layer)
```

Renders the textfield to a buffer or layer. The cursor is shown with a gray background when the field is focused.

## Example: Simple Input Form

```nim
import editor_base
import textfield

# Create multiple fields for a form
var nameField = newTextField(10, 5, 30)
var emailField = newTextField(10, 7, 30)
var currentField = nameField
nameField.focused = true

# Main input loop (pseudocode)
while true:
  # Get input event from terminal/system
  let event = getInputEvent()
  
  # Handle Tab to switch fields
  if event.kind == evKey and event.key == "tab":
    currentField.focused = false
    if currentField == nameField:
      currentField = emailField
    else:
      currentField = nameField
    currentField.focused = true
    continue
  
  # Let current field handle the input
  discard currentField.handleInput(event)
  
  # Render
  var buffer = newBuffer(80, 24)
  buffer.writeText(10, 4, "Name:  ", defaultStyle())
  buffer.writeText(10, 6, "Email: ", defaultStyle())
  nameField.render(buffer)
  emailField.render(buffer)
  
  # Display buffer...
```

## Styling

You can customize the appearance by modifying the style fields:

```nim
var field = newTextField(5, 10, 40)

# Customize text style
field.style.fg = rgb(0, 255, 0)  # Green text
field.style.bg = rgb(20, 20, 20) # Dark background

# Customize cursor style
field.cursorStyle.bg = rgb(255, 255, 0)  # Yellow cursor
field.cursorStyle.fg = rgb(0, 0, 0)      # Black text under cursor
```

## Future Extensions

This basic textfield widget can be extended to support:

- **Multi-line text editor**: Add line management, vertical scrolling
- **Selection**: Track selection start/end, copy/paste operations
- **Syntax highlighting**: Apply different styles based on content
- **Undo/redo**: Maintain edit history
- **Auto-completion**: Suggest completions as user types
- **Input validation**: Restrict or validate input based on rules
- **History**: Navigate through previous inputs (like shell history)

## Architecture Notes

The textfield is built on top of `editor_base.nim` primitives:
- Uses `Buffer` for rendering text and cursor
- Uses `Style` for visual appearance
- Uses `InputEvent` for keyboard handling

This makes it easy to integrate with the broader TUI system and extend with additional features.

## Testing

To test the textfield widget:

1. Import it in your TUI application
2. Create a textfield instance
3. Set up an input loop to capture keyboard events
4. Call `handleInput()` for each event
5. Call `render()` to display the current state
6. Verify insertion, deletion, and navigation work correctly

Example operations to test:
- Type several characters
- Use arrow keys to navigate
- Delete characters with backspace/delete
- Test Home/End keys
- Type text longer than the width to test scrolling
- Verify cursor visibility and position
