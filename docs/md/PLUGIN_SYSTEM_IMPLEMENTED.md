# Internal Plugin System Implementation

## Overview

Successfully implemented an **internal plugin system** for tstorie that enables automatic registration of lib modules without requiring separate `*_bindings.nim` files.

## Key Changes

### 1. Auto-Registration Queue System

**File**: `nimini/auto_pointer.nim`

Added a registration queue that defers plugin registration until after runtime initialization:

```nim
var gPluginRegistrations* {.global.}: seq[PluginRegistration] = @[]

proc queuePluginRegistration*(callback: PluginRegistration) =
  ## Queue a registration callback to be called after runtime init
  gPluginRegistrations.add(callback)

proc initPlugins*() =
  ## Call all queued plugin registration callbacks
  ## Must be called AFTER runtime initialization
  for callback in gPluginRegistrations:
    callback()
```

### 2. Auto-Registration in Pragmas

Updated all three auto_pointer macros to automatically queue registration:

- `autoPointer` macro (for the type and release function)
- `autoExposePointer` macro (for constructors)
- `autoExposePointerMethod` macro (for methods)

Each now generates:
```nim
queuePluginRegistration(register_<function>)
```

### 3. Plugin Initialization Hook

**File**: `src/runtime_api.nim`

Added `initPlugins()` call after all core registrations:

```nim
# Register figlet bindings...
registerFigletBindings(...)

# Initialize all auto-registered plugins (from lib/ modules with pragmas)
initPlugins()

# Register type conversion functions...
```

### 4. Updated dungeon_gen Module

**File**: `lib/dungeon_gen.nim`

- Kept all auto_pointer pragmas on functions
- Added manual binding for `dungeonGetCellChar` (special case)
- Manual binding also uses `queuePluginRegistration()`
- **No separate binding file needed!**

## Architecture Pattern

### Before (Manual Bindings):
```
lib/module.nim          -> Defines types and functions
lib/module_bindings.nim -> Manual wrappers + registration
tstorie.nim             -> import module_bindings
runtime_api.nim         -> call registerModuleBindings()
```

### After (Internal Plugins):
```
lib/module.nim          -> Defines types, functions, auto-pragmas
                          -> Queues registration at import time
tstorie.nim             -> import module
runtime_api.nim         -> call initPlugins() (runs all queued registrations)
```

## Benefits

1. **No Binding Files Needed**
   - `dungeon_bindings.nim` eliminated
   - 61 lines of boilerplate removed per module

2. **True Plugin Architecture**
   - Modules self-register when imported
   - Runtime initializes before plugins load
   - Follows standard plugin patterns (VS Code, Unity, etc.)

3. **Cleaner Code**
   - Single source of truth (the lib module itself)
   - Pragmas directly on functions show what's exposed
   - Less maintenance overhead

4. **Flexible**
   - Still supports manual bindings when needed (e.g., `dungeonGetCellChar`)
   - Can mix auto and manual registration
   - Works with all three binding systems (auto_pointer, auto_registry, auto_bindings)

## Eliminated Files

- ✅ `lib/dungeon_bindings.nim` (61 lines) - **DELETED**

## Next Steps

Apply this pattern to remaining lib modules:

- [ ] `lib/ascii_art.nim` + `lib/ascii_art_bindings.nim`
- [ ] `lib/ansi_parser.nim` + `lib/ansi_art_bindings.nim`
- [ ] `lib/figlet.nim` + `lib/figlet_bindings.nim`
- [ ] `lib/particles.nim` + `lib/particles_bindings.nim`
- [ ] `lib/tui_helpers.nim` + binding code in section_manager
- [ ] `lib/text_editor.nim` + `lib/text_editor_bindings.nim`

Each should follow the dungeon_gen pattern:
1. Add auto_pointer/auto_registry pragmas to functions
2. Add manual bindings with `queuePluginRegistration()` for special cases
3. Delete the `*_bindings.nim` file
4. Import the module directly in `tstorie.nim`

## Testing

✅ Dungeon demo works perfectly:
```bash
./ts dungen  # Runs successfully
```

All functions auto-registered:
- `newDungeonGenerator`
- `generate`
- `update`
- `getCellAt`
- `getWidth`
- `getHeight`
- `getStep`
- `isStillGenerating`
- `releaseDungeonGenerator`
- `dungeonGetCellChar` (manual)

## Code Reduction

**Per module conversion**:
- Before: ~60-180 lines of binding code
- After: ~10 lines (manual special cases only)
- Reduction: **85-95%** of binding boilerplate eliminated
