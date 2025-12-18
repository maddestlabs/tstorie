# Global Event Handler System - Design Document

## Overview

Global event handlers allow loaded modules (like canvas.nim) to register callbacks that execute every frame, independent of section-specific code blocks. This is essential for complex interactive systems that need to maintain state and handle events globally.

## Design

### 1. Handler Registry

Add to `StorieContext`:

```nim
type
  GlobalHandler* = object
    name*: string
    callback*: Value  # Nimini function/closure
    priority*: int    # Lower = executes first
  
  StorieContext = ref object
    # ... existing fields ...
    globalRenderHandlers*: seq[GlobalHandler]
    globalUpdateHandlers*: seq[GlobalHandler]
    globalInputHandlers*: seq[GlobalHandler]
```

### 2. Registration API

Expose these functions to Nimini scripts:

```nim
proc registerGlobalRender*(name: string, callback: Value, priority: int = 0): bool
proc registerGlobalUpdate*(name: string, callback: Value, priority: int = 0): bool  
proc registerGlobalInput*(name: string, callback: Value, priority: int = 0): bool

proc unregisterGlobalHandler*(name: string): bool
proc clearGlobalHandlers*(): void
```

### 3. Execution Flow

**Render Phase:**
```nim
onRender = proc(state: AppState) =
  # 1. Execute global render handlers (modules like canvas)
  for handler in storieCtx.globalRenderHandlers (sorted by priority):
    callNiminiFunction(handler.callback, @[])
  
  # 2. Execute section-specific on:render blocks (user content)
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "render":
      executeCodeBlock(...)
```

**Update Phase:**
```nim
onUpdate = proc(state: AppState, dt: float) =
  # 1. Execute global update handlers
  for handler in storieCtx.globalUpdateHandlers:
    callNiminiFunction(handler.callback, @[valFloat(dt)])
  
  # 2. Execute section-specific on:update blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "update":
      executeCodeBlock(...)
```

**Input Phase:**
```nim
onInput = proc(state: AppState, event: InputEvent): bool =
  # 1. Execute global input handlers first (allow modules to intercept)
  for handler in storieCtx.globalInputHandlers:
    let handled = callNiminiFunction(handler.callback, @[encodeInputEvent(event)])
    if handled.kind == vkBool and handled.b:
      return true  # Handler consumed the event
  
  # 2. Execute section-specific on:input blocks
  for codeBlock in storieCtx.codeBlocks:
    if codeBlock.lifecycle == "input":
      if executeCodeBlock(...):
        return true
  
  return false
```

### 4. Module Usage Pattern

In a module like canvas.nim:

```nim
# Module initialization
proc init*() =
  registerGlobalRender("canvas_render", globalRender, 0)
  registerGlobalUpdate("canvas_update", globalUpdate, 0)
  registerGlobalInput("canvas_input", globalHandleInput, 0)

# Cleanup
proc shutdown*() =
  unregisterGlobalHandler("canvas_render")
  unregisterGlobalHandler("canvas_update")
  unregisterGlobalHandler("canvas_input")
```

Or simpler, using function references:

```nim
proc init*() =
  # These are defined in the module
  registerGlobalRender("canvas", render)
  registerGlobalUpdate("canvas", update)
```

### 5. Priority System

- **Lower priority = executes first**
- Default priority: 0
- Canvas/UI systems: -10 (render background first)
- Game logic: 0 (default)
- HUD/Overlays: 10 (render on top)

### 6. Advantages

✅ **Separation of concerns**: Modules handle their own lifecycle
✅ **Multiple handlers**: Different modules can coexist
✅ **Priority control**: Deterministic execution order
✅ **Easy cleanup**: Unregister by name
✅ **No magic globals**: Clean registration API

## Implementation Checklist

- [ ] Add handler registries to StorieContext
- [ ] Implement register/unregister functions
- [ ] Add Nimini wrapper functions
- [ ] Update onRender to call global handlers first
- [ ] Update onUpdate to call global handlers first
- [ ] Update onInput to call global handlers first
- [ ] Add input event encoding to Nimini Value
- [ ] Test with canvas module
- [ ] Document in README
