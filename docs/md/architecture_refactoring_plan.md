# tStorie Architecture Refactoring Plan

**Goal**: Modularize tStorie to enable clean exports and better maintainability

**Status**: Planning Phase  
**Started**: 2025-12-28

---

## Problem Statement

Currently:
- `index.nim` mixes runtime logic, includes, and entry point
- `tstorie.nim` is monolithic with types, rendering, lifecycle all mixed
- Libraries use `include` making them non-importable independently  
- Export system can't import just what's needed - requires entire runtime
- Circular dependencies and unclear module boundaries

## Objectives

1. ✅ Separate concerns into focused modules
2. ✅ Enable selective imports for export system
3. ✅ Make `index.nim` a minimal entry point
4. ✅ Keep backwards compatibility during refactoring
5. ✅ Improve testability and maintainability

---

## Architecture Overview

### Before (Current)
```
tstorie.nim (monolithic, 2600+ lines)
  ├─ Types mixed with logic
  ├─ Runtime mixed with initialization
  └─ Everything in one file

index.nim (runtime entry, 2100+ lines)
  ├─ include lib/* (drawing, canvas, audio, etc.)
  ├─ Runtime logic
  └─ Entry point

lib/*.nim
  └─ Use global types from tstorie.nim
```

### After (Target)
```
src/
  ├─ types.nim          # Core type definitions only
  ├─ appstate.nim       # AppState management
  ├─ layers.nim         # Layer system & compositing
  ├─ rendering.nim      # Rendering pipeline
  ├─ input.nim          # Input handling
  ├─ lifecycle.nim      # Lifecycle hooks
  ├─ runtime.nim        # Main event loop
  └─ platform/          # Platform-specific (exists)

tstorie.nim (thin orchestrator)
  └─ Imports all src/* and exposes main()

index.nim (minimal entry point, ~50 lines)
  └─ import tstorie; call main()

lib/*.nim (enhanced)
  └─ Import src/types.nim for type definitions
```

---

## Implementation Phases

### Phase 1: Extract Core Types ⭐ START HERE
**Goal**: Create `src/types.nim` with all type definitions

**Files to create:**
- `src/types.nim`

**Types to move from `tstorie.nim`:**
```nim
# Core rendering types
- Style, StyleConfig, StyleSheet
- TermBuffer, TermCell
- Layer, LayerKind
- Rect, Point

# State types
- AppState
- InputEvent, InputEventKind, KeyCode
- MarkdownSection, ContentBlock, etc.

# Audio types
- AudioSystem, Sound, etc.
```

**Steps:**
1. Create `src/types.nim`
2. Move type definitions (types only, no procs)
3. Update `tstorie.nim` to import `src/types`
4. Update `lib/*.nim` files to import `src/types`
5. Test compilation

**Success criteria:**
- ✅ All type definitions in one place
- ✅ tstorie.nim compiles
- ✅ Exports can import `src/types` independently

---

### Phase 2: Extract Layer System
**Goal**: Create `src/layers.nim` with layer management

**Files to create:**
- `src/layers.nim`

**Functions to move:**
```nim
- newLayer, newLayerTransparent
- clearLayer, clearLayerTransparent
- compositeLayersAdditive
- renderLayersToTerminal
- Layer-related helper functions
```

**Dependencies:**
- Imports: `src/types`
- Used by: rendering system, drawing lib

**Steps:**
1. Create `src/layers.nim`
2. Move layer creation/management functions
3. Update imports in `tstorie.nim`
4. Update drawing lib to import `src/layers` if needed
5. Test

---

### Phase 3: Extract AppState
**Goal**: Create `src/appstate.nim` for state management

**Files to create:**
- `src/appstate.nim`

**Functions to move:**
```nim
- AppState initialization
- State accessor functions
- Frame counting, FPS calculation
- State update functions
```

**Dependencies:**
- Imports: `src/types`

---

### Phase 4: Extract Rendering
**Goal**: Create `src/rendering.nim` for rendering pipeline

**Files to create:**
- `src/rendering.nim`

**Functions to move:**
```nim
- Terminal buffer management
- Cursor management (showCursor, hideCursor, moveCursor)
- Color/style application
- Diff-based rendering
- Terminal output functions
```

**Dependencies:**
- Imports: `src/types`, `src/layers`, `src/platform/terminal`

---

### Phase 5: Extract Lifecycle
**Goal**: Create `src/lifecycle.nim` for lifecycle hooks

**Files to create:**
- `src/lifecycle.nim`

**Functions to move:**
```nim
- Lifecycle hook registration
- Lifecycle hook execution
- Section transition handling
- Init/Update/Render/Shutdown management
```

**Dependencies:**
- Imports: `src/types`, `src/appstate`

---

### Phase 6: Extract Runtime
**Goal**: Create `src/runtime.nim` for main event loop

**Files to create:**
- `src/runtime.nim`

**Functions to move:**
```nim
- Main event loop
- Frame rate limiting
- Update/render cycle
- Terminal setup/teardown
```

**Dependencies:**
- Imports: `src/types`, `src/appstate`, `src/rendering`, `src/lifecycle`, `src/input`

---

### Phase 7: Refactor index.nim
**Goal**: Make index.nim a minimal entry point

**Current size**: ~2100 lines  
**Target size**: ~50 lines

**New structure:**
```nim
# index.nim - User entry point
import tstorie

# User code blocks execute through tstorie runtime
# This file is mainly for compile-time user file inclusion

when isMainModule:
  main()
```

**Steps:**
1. Move all runtime logic to appropriate src/ modules
2. Move helper functions to appropriate modules
3. Keep only the user file inclusion macro
4. Import tstorie and call main()

---

### Phase 8: Update Library Modules
**Goal**: Make lib/*.nim properly importable

**Files to update:**
- `lib/drawing.nim` → import `src/types`
- `lib/canvas.nim` → import `src/types`, `src/layers`
- `lib/layout.nim` → import `src/types`
- `lib/audio.nim` → import `src/types`, `src/appstate`
- `lib/animation.nim` → import `src/types`
- etc.

**Pattern:**
```nim
# Old (included into index.nim namespace)
# Relied on types from tstorie.nim

# New
import ../src/types
import ../src/layers  # if needed
# Explicit imports, can be used independently
```

---

### Phase 9: Update Export System
**Goal**: Enable clean imports in exported code

**Benefits after refactoring:**

**Standalone exports:**
```nim
import src/types
import lib/drawing

# Minimal dependencies, just types + specific libs
```

**Integrated exports:**
```nim
import src/types
import src/appstate
import src/runtime
import src/rendering
import lib/drawing

# Full runtime, but modular
```

**Steps:**
1. Update `lib/nim_export.nim` to generate proper imports
2. Add logic to detect export mode and required modules
3. Generate minimal imports for standalone
4. Generate full runtime imports for integrated
5. Test exported programs compile

---

## Module Dependency Graph

```
src/types.nim (foundation - no dependencies)
    ↓
src/layers.nim (depends on types)
    ↓
src/appstate.nim (depends on types)
    ↓
src/rendering.nim (depends on types, layers, platform/terminal)
    ↓
src/lifecycle.nim (depends on types, appstate)
    ↓
src/runtime.nim (depends on all above)
    ↓
tstorie.nim (imports all, provides main())
    ↓
index.nim (imports tstorie, minimal entry)
```

**Library dependencies:**
```
lib/drawing.nim → src/types, src/layers
lib/canvas.nim → src/types, src/layers
lib/layout.nim → src/types
lib/audio.nim → src/types
lib/animation.nim → src/types
```

---

## Testing Strategy

After each phase:
1. ✅ Compile tstorie.nim successfully
2. ✅ Run existing demos without errors
3. ✅ Verify no behavioral changes
4. ✅ Check that exports can import new modules

Integration tests:
- Run full test suite after each phase
- Compare output with pre-refactor baseline
- Verify exports compile and run

---

## Migration Checklist

### Phase 1: Types ✋ Current Phase
- [ ] Create `src/types.nim`
- [ ] Move all type definitions
- [ ] Update tstorie.nim imports
- [ ] Update lib imports
- [ ] Test compilation
- [ ] Commit: "refactor: extract core types to src/types.nim"

### Phase 2: Layers
- [ ] Create `src/layers.nim`
- [ ] Move layer functions
- [ ] Update imports
- [ ] Test
- [ ] Commit: "refactor: extract layer system to src/layers.nim"

### Phase 3: AppState
- [ ] Create `src/appstate.nim`
- [ ] Move AppState management
- [ ] Update imports
- [ ] Test
- [ ] Commit: "refactor: extract AppState to src/appstate.nim"

### Phase 4: Rendering
- [ ] Create `src/rendering.nim`
- [ ] Move rendering functions
- [ ] Update imports
- [ ] Test
- [ ] Commit: "refactor: extract rendering to src/rendering.nim"

### Phase 5: Lifecycle
- [ ] Create `src/lifecycle.nim`
- [ ] Move lifecycle hooks
- [ ] Update imports
- [ ] Test
- [ ] Commit: "refactor: extract lifecycle to src/lifecycle.nim"

### Phase 6: Runtime
- [ ] Create `src/runtime.nim`
- [ ] Move event loop
- [ ] Update imports
- [ ] Test
- [ ] Commit: "refactor: extract runtime to src/runtime.nim"

### Phase 7: index.nim
- [ ] Move logic to appropriate modules
- [ ] Simplify to minimal entry point
- [ ] Test
- [ ] Commit: "refactor: simplify index.nim to minimal entry point"

### Phase 8: Libraries
- [ ] Update each lib/*.nim
- [ ] Add proper imports
- [ ] Test each library
- [ ] Commit: "refactor: update lib modules with explicit imports"

### Phase 9: Exports
- [ ] Update export system
- [ ] Test standalone exports
- [ ] Test integrated exports
- [ ] Commit: "feat: enable modular exports with selective imports"

---

## Risks & Mitigation

**Risk**: Breaking existing functionality  
**Mitigation**: 
- Incremental changes with testing after each phase
- Keep git history clean with atomic commits
- Test demos after each change

**Risk**: Include vs import behavior differences  
**Mitigation**:
- Carefully manage symbol visibility
- Use explicit exports (`*`) where needed
- Test from multiple import contexts

**Risk**: Circular dependencies  
**Mitigation**:
- Follow dependency graph strictly (types → layers → appstate → etc.)
- Forward declarations if needed
- Keep dependency direction one-way

---

## Success Metrics

✅ **Modularity**: Each src/ module < 500 lines  
✅ **Independence**: Modules can be imported separately  
✅ **Export**: Standalone exports compile with <5 imports  
✅ **Maintainability**: Clear separation of concerns  
✅ **Compatibility**: All existing demos work unchanged  

---

## Notes

- Start with types - this is the foundation
- Test thoroughly after each phase
- Keep changes atomic and committable
- Document any breaking changes
- Update export metadata as modules are created

---

## Next Steps

**Immediate**: Start Phase 1 - Extract Types
1. Analyze tstorie.nim type definitions
2. Create src/types.nim structure
3. Begin migration
