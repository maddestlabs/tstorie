# Pure Nimini UI Feasibility - Proof of Concept

## Summary

**Yes, it is absolutely possible to build UI entirely in Nimini scripting!**

Just like Storiel's Lua UI system, tStorie already exposes all the necessary primitives to build a complete UI widget system in pure scripting with **no native code dependencies**.

## What tStorie Already Provides

tStorie exposes these core primitives through Nimini:

### Drawing Primitives
- `fgWrite(x, y, ch, style)` - Write single character
- `fgWriteText(x, y, text, style)` - Write text string  
- `fgFillRect(x, y, w, h, ch, style)` - Fill rectangle
- `bgWrite()`, `bgWriteText()`, `bgFillRect()` - Background layer equivalents
- `fgClear()`, `bgClear()` - Clear buffers

### Styling
- `getStyle(name)` - Get named style from stylesheet
- `Style` type with fg/bg colors, bold, italic, underline, dim

### Events
- `event.type` - "key", "mouse", "arrow", "resize"
- `event.keyCode` - Key code for keyboard events
- `event.x`, `event.y` - Mouse coordinates
- `event.action` - "press", "release", "move", "drag"

### Context
- `termWidth`, `termHeight` - Terminal dimensions
- Lifecycle hooks: `on:init`, `on:render`, `on:input`, `on:update`

## Proof of Concept

See [docs/demos/ui-simple-poc.md](docs/demos/ui-simple-poc.md) for a working demonstration that implements:

- **TextBox Widget** - Text input with cursor
- **Button Widget** - Clickable button with pressed state
- **Box Drawing** - Helper function using Unicode box-drawing characters
- **Event Handling** - Keyboard and mouse input
- **Focus Management** - Visual focus states

All implemented in **pure Nimini code** using only the primitives listed above!

## Comparison with Storiel

### Storiel (Lua)
```lua
buffer:writeStyled(x, y, text, "style_name")
buffer:drawBox(x, y, w, h, style)
buffer:fillRect(x, y, w, h, ch, style)
```

### tStorie (Nimini)
```nim
fgWriteText(x, y, text, getStyle("style_name"))
drawBox(x, y, w, h, style)  # User-defined helper
fgFillRect(x, y, w, h, ch, style)
```

The APIs are nearly identical in capability!

## What's Different

### Storiel Had
- `buffer:drawBox()` built-in function
- `buffer:writeStyled()` convenience method
- Lua's metatable-based OOP

### tStorie Needs
- `drawBox()` can be easily implemented in Nimini (as shown in POC)
- `writeStyled()` is just `fgWriteText(x, y, text, getStyle(name))`
- Nimini uses structs and procs instead of metatables

## Recommended Approach

Create a standard UI library module in Nimini that provides:

1. **Widget Types** - TextBox, Button, Slider, Checkbox, etc.
2. **Widget Manager** - Focus handling, tab navigation
3. **Helper Functions** - drawBox, contains, centerText, etc.
4. **Event Routing** - Dispatch events to focused widgets

This library would be:
- Pure Nimini code (no native dependencies)
- Usable via `require("ui")` in any tStorie document
- Easily extensible by users
- Similar ergonomics to Storiel's UI system

## Benefits

1. **Zero Native Code** - All UI logic in scripting
2. **Rapid Development** - Iterate without recompiling
3. **User Extensible** - Users can create custom widgets
4. **Portable** - Works anywhere Nimini works
5. **Maintainable** - Simpler codebase, easier to debug

## Next Steps

1. ✅ **Proof of concept** - Demonstrated feasibility
2. Create full `ui.nim` module library
3. Add more widget types (List, Menu, Panel, etc.)
4. Document widget API
5. Create example applications

## Conclusion

tStorie already has everything needed to support UI development entirely in scripting, just like Storiel did. The proof-of-concept demonstrates this works with the existing API. A polished UI library module would make this even more accessible to users.
