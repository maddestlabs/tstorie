# Layer Naming vs Index Issue

> **Status: ✅ RESOLVED** - All phases complete! String-based layer API is now the primary interface.
> - ✅ Phase 1: Core infrastructure with layer name cache
> - ✅ Phase 2: String overloads for all drawing functions
> - ✅ Phase 3: Documentation and demos updated
> 
> **See [Implementation Summary](#implementation-summary) for details.**

## Problem Statement

There is a critical inconsistency in how layers are referenced in tstorie:

1. **Layer creation** uses names: `addLayer("sky", -3)` returns a `Layer` object with an `id` field
2. **Drawing functions** use numeric indices: `draw(1, x, y, ...)`, `clear(1, true)`, `fillBox(1, ...)`
3. **Layer effects functions** use names: `setLayerOffset("sky", x, y)`, `setLayerDarkness("mountains", 0.5)`

This creates confusion and makes code harder to write and maintain.

## Current Behavior

### How Layers Are Stored

From [src/layers.nim](src/layers.nim#L150-L159):

```nim
proc addLayer*(state: AppState, id: string, z: int): Layer =
  let layer = Layer(
    id: id,
    z: z,
    visible: true,
    buffer: newTermBuffer(state.termWidth, state.termHeight)
  )
  layer.buffer.clearTransparent()
  state.layers.add(layer)
  return layer
```

Layers are stored in `state.layers: seq[Layer]` and **sorted by z-order**:

```nim
proc compositeLayers*(state: AppState) =
  # ...
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
```

### The Index Problem

**Drawing functions expect array indices**, not layer IDs:

```nim
# This works - draws to layer at index 1
draw(1, 10, 10, "*", getStyle("info"))

# This does NOT work - tries to use "sky" as an index
draw("sky", 10, 10, "*", getStyle("info"))  # Runtime error!
```

**But users create layers with meaningful names:**

```nim
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)
```

### Why Indices Are Problematic

1. **Array indices change with sorting** - After sorting by z, the array indices don't match creation order
2. **Indices are implementation details** - Users shouldn't need to know array positions
3. **Fragile code** - Adding/removing layers breaks index references
4. **Inconsistent with layer effects** - Effects use names, drawing uses indices

## Real-World Example from layer-effects-demo.md

The confusion this causes:

```nim
# Init: Create layers with meaningful names
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)

# Render: Must guess array indices after sorting!
clear(1, true)  # Which layer is this? sky? mountains?
draw(1, x, y, "*", getStyle("info"))

# Layer effects: Use names (the RIGHT way)
setLayerOffset("sky", offsetX, offsetY)
setLayerDarkness("mountains", 0.5)
```

**Users have to mentally map**: "Okay, after sorting by z, sky (-3) is first, so it's index 1 (after default layer 0)"

## Current Workarounds

### Workaround 1: Don't use named layers
```nim
# Just use numeric indices directly
clear(1, true)
draw(1, x, y, "*", getStyle("info"))
# Note: Layer auto-creates with z=index
```

**Problems:**
- Can't use layer effects functions (they require names!)
- No semantic meaning to layer indices
- Layer effects demo becomes impossible to write correctly

### Workaround 2: Manual index tracking
```nim
# Create layers and manually track indices
addLayer("sky", -3)
addLayer("mountains", -2)
var skyIdx = 1  # Guess after sorting
var mountainsIdx = 2

draw(skyIdx, x, y, "*", getStyle("info"))
```

**Problems:**
- Error-prone (indices change if you add/remove layers)
- Defeats the purpose of named layers
- Requires deep knowledge of internal sorting

### Workaround 3: Use getLayer() and manual lookup
```nim
# Find layer by name each frame
for i, layer in state.layers:
  if layer.id == "sky":
    draw(i, x, y, "*", getStyle("info"))
```

**Problems:**
- Performance overhead (linear search every frame)
- Verbose and repetitive
- Not available in nimini scripts (getLayer returns Layer object, not index)

## What drawing-layers.md Does (The Current "Working" Pattern)

The [drawing-layers.md](docs/demos/drawing-layers.md) demo avoids the issue by:

1. **Never calling `addLayer()` with names**
2. **Relying on auto-creation**: Drawing to index N auto-creates a layer with z=N
3. **Using raw indices throughout**

```nim
# No addLayer() calls!

# Drawing auto-creates layers with z=index
clear(1, true)   # Auto-creates layer with z=1
clear(2, true)   # Auto-creates layer with z=2
clear(3, true)   # Auto-creates layer with z=3
```

**This works but**:
- Can't use negative z-values (no way to create z=-3 layer)
- Can't use layer effects functions that require names
- Limited to z=index pattern (z=5 means it must be at index 5)

## Impact on Layer Effects Plugin

The layer effects plugin ([lib/layerfx.nim](lib/layerfx.nim)) was designed around **named layers**:

```nim
setLayerOffset("sky", x, y)
setLayerDarkness("mountains", 0.5)
enableAutoDepthing(0.3, 1.0)  # Applies to all layers by z-order
```

**But the demo can't use these effectively** because drawing functions need indices, not names!

## Proposed Solutions

### Option 1: Add layer name parameter to drawing functions

```nim
# New signature (backwards compatible via overloading)
proc draw*(layerId: string, x, y: int, ch: string, style: Style)

# Usage
draw("sky", x, y, "*", getStyle("info"))
clear("mountains", true)
fillBox("trees", 0, 0, 10, 10, "#", getStyle("success"))
```

**Implementation:**
```nim
proc draw*(layerId: string, x, y: int, ch: string, style: Style) =
  # Look up layer index by ID
  for i, layer in state.layers:
    if layer.id == layerId:
      draw(i, x, y, ch, style)
      return
  # Layer not found - error or auto-create?
```

**Pros:**
- Consistent with layer effects API
- Semantic layer references
- Backwards compatible (keep numeric versions)

**Cons:**
- Performance overhead (O(n) lookup per draw call)
- Need to decide: error on missing layer, or auto-create?
- Lots of functions to update (draw, clear, fillBox, drawLabel, etc.)

### Option 2: Return and use layer indices from addLayer

```nim
# Modified addLayer returns index
proc addLayer*(state: AppState, id: string, z: int): int =
  # ... create layer ...
  state.layers.add(layer)
  state.layers.sort(proc(a, b: Layer): int = cmp(a.z, b.z))
  
  # Return index after sorting
  for i, layer in state.layers:
    if layer.id == id:
      return i
  return -1

# Usage
let skyIdx = addLayer("sky", -3)
let mountainsIdx = addLayer("mountains", -2)

draw(skyIdx, x, y, "*", getStyle("info"))
```

**Pros:**
- No performance overhead
- Explicit about indices

**Cons:**
- Breaks existing code (addLayer returns Layer, not int)
- Still fragile (indices change when layers added/removed)
- Have to re-sort and re-lookup after every addLayer call
- Type inconsistency (Layer object vs int)

### Option 3: Cache layer ID->index mapping

```nim
# Add to AppState
type AppState = object
  layers: seq[Layer]
  layerIndexCache: Table[string, int]  # NEW

proc updateLayerCache*(state: AppState) =
  state.layerIndexCache.clear()
  for i, layer in state.layers:
    state.layerIndexCache[layer.id] = i

proc getLayerIndex*(state: AppState, id: string): int =
  return state.layerIndexCache.getOrDefault(id, -1)
```

**Pros:**
- O(1) lookup instead of O(n)
- Can provide both name and index APIs
- Less invasive change

**Cons:**
- Cache must be invalidated/rebuilt when layers change
- More state to manage
- Still need wrapper functions for string-based drawing

### Option 4: Layer handles/references

```nim
# Return opaque handle that encapsulates index
type LayerHandle = distinct int

proc addLayer*(state: AppState, id: string, z: int): LayerHandle =
  # ... add layer ...
  return LayerHandle(actualIndex)

# Drawing functions accept handles
proc draw*(handle: LayerHandle, x, y: int, ...)

# Usage
let sky = addLayer("sky", -3)
draw(sky, x, y, "*", getStyle("info"))
```

**Pros:**
- Type-safe
- Efficient (no lookups)
- Clear ownership

**Cons:**
- Large breaking change
- Handles can become stale if layers reordered
- Need handle validation

## Recommendation

**Hybrid approach (Options 1 + 3):**

1. **Add string overloads** to drawing functions using a cached index lookup
2. **Keep existing numeric API** for performance-critical code
3. **Cache layer ID→index mapping**, rebuild on layer add/remove/sort
4. **Make layer names the PRIMARY API** in documentation and examples

### Implementation Sketch

```nim
# In src/layers.nim or src/appstate.nim
var gLayerIndexCache {.threadvar.}: Table[string, int]

proc rebuildLayerCache*(state: AppState) =
  gLayerIndexCache.clear()
  for i, layer in state.layers:
    gLayerIndexCache[layer.id] = i

proc getLayerIndex*(state: AppState, id: string): int =
  if not gLayerIndexCache.hasKey(id):
    rebuildLayerCache(state)
  return gLayerIndexCache.getOrDefault(id, -1)

# In drawing functions (add overloads)
proc draw*(layerId: string, x, y: int, ch: string, style: Style) =
  let idx = getLayerIndex(gAppState, layerId)
  if idx >= 0:
    draw(idx, x, y, ch, style)

proc clear*(layerId: string, transparent: bool = false) =
  let idx = getLayerIndex(gAppState, layerId)
  if idx >= 0:
    clear(idx, transparent)

# etc for all drawing functions
```

### Migration Path

1. **Phase 1**: Add string overloads, keep numeric versions (backwards compatible)
2. **Phase 2**: Update documentation to prefer string versions
3. **Phase 3**: Update demos to use string versions
4. **Phase 4**: Consider deprecating numeric versions (far future)

## Files That Need Updates

Drawing API functions (need string overloads):
- [ ] `draw()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] `clear()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] `fillBox()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] `drawBox()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] `drawLabel()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] `drawPanel()` - [src/runtime_api.nim](src/runtime_api.nim)
- [ ] Any other layer-specific drawing functions

Layer management:
- [ ] [src/layers.nim](src/layers.nim) - Add cache management
- [ ] [src/appstate.nim](src/types.nim) - Add cache field to AppState
- [ ] [src/runtime_api.nim](src/runtime_api.nim) - Rebuild cache on layer changes

Documentation:
- [ ] Update all demos to use string-based layer references
- [ ] Update [LAYER_EFFECTS_USER_GUIDE.md](LAYER_EFFECTS_USER_GUIDE.md)
- [ ] Add section to README about layer naming

## Testing Considerations

1. **Performance testing**: Measure overhead of string lookups vs direct indexing
2. **Cache invalidation**: Ensure cache updates when layers added/removed/reordered
3. **Backwards compatibility**: Verify existing demos still work with numeric indices
4. **Edge cases**: 
   - What happens when layer name doesn't exist?
   - Should drawing to non-existent name auto-create layer?
   - How to handle empty string as layer ID?

## Example of Fixed layer-effects-demo.md

```nim
# Init
addLayer("sky", -3)
addLayer("mountains", -2)
addLayer("trees", -1)
addLayer("player", 0)

# Render (now consistent!)
clear("sky", true)
draw("sky", x, y, "*", getStyle("info"))

clear("mountains", true)
draw("mountains", x, y, "▓", getStyle("primary"))

# Layer effects (already uses names)
setLayerOffset("sky", offsetX, offsetY)
setLayerDarkness("mountains", 0.5)
```

**Clean, consistent, semantic!**

## Context for Future Discussion

This issue was discovered while implementing the layer effects plugin ([lib/layerfx.nim](lib/layerfx.nim)). The plugin was designed around named layers for clarity:

```nim
enableAutoDepthing(0.3, 1.0)  # Applies to all layers
setLayerOffset("sky", x, y)   # Semantic names
```

But when creating the demo ([docs/demos/layer-effects-demo.md](docs/demos/layer-effects-demo.md)), we hit the inconsistency:
- Can create named layers with `addLayer("sky", -3)`
- But can't draw to them by name - must use numeric indices
- Led to confusing code with manual index tracking

The working demo ([docs/demos/drawing-layers.md](docs/demos/drawing-layers.md)) avoids this by never using `addLayer()` at all, relying on auto-creation. But this limits functionality (no negative z-values, can't use layer effects).

## Related Files

- [lib/layerfx.nim](lib/layerfx.nim) - Layer effects plugin (uses names)
- [src/layers.nim](src/layers.nim) - Core layer management with cache infrastructure
- [lib/tui_helpers.nim](lib/tui_helpers.nim) - Drawing functions with string overloads
- [lib/tui_helpers_bindings.nim](lib/tui_helpers_bindings.nim) - Polymorphic nimini bindings
- [src/runtime_api.nim](src/runtime_api.nim) - Registration order management
- [docs/demos/layer-effects-demo.md](docs/demos/layer-effects-demo.md) - Updated demo using string API
- [docs/demos/drawing-layers.md](docs/demos/drawing-layers.md) - Updated layer tutorial using string API
- [LAYER_EFFECTS_USER_GUIDE.md](LAYER_EFFECTS_USER_GUIDE.md) - User documentation

---

## Implementation Summary

### Phase 1: Core Infrastructure ✅

**Files Modified:**
- [src/types.nim](src/types.nim#L293-L314) - Added `layerIndexCache: Table[string, int]` and `cacheValid: bool` to `AppState`
- [src/layers.nim](src/layers.nim) - Added cache management functions

**Key Functions Added:**
```nim
proc rebuildLayerCache*(state: AppState)
proc invalidateLayerCache*(state: AppState)
proc resolveLayerIndex*(state: AppState, layerId: string): int
proc resolveLayerIndex*(state: AppState, layerId: int): int  # Bounds checking overload
```

**Cache Invalidation Points:**
- `addLayer()` - New layer added
- `removeLayer()` - Layer removed
- `compositeLayers()` - Layers sorted by z-order

**Performance:** O(1) lookups after initial O(n) cache build

### Phase 2: String Overloads ✅

**Files Modified:**
- [lib/tui_helpers.nim](lib/tui_helpers.nim) - Added string overloads for all drawing functions
- [lib/tui_helpers_bindings.nim](lib/tui_helpers_bindings.nim) - Manual polymorphic wrappers
- [src/runtime_api.nim](src/runtime_api.nim) - Adjusted registration order

**Functions Updated (10 total):**
- `fillBox(layer: string, ...)`
- `drawLabel(layer: string, ...)`
- `drawPanel(layer: string, ...)`
- `drawBoxSingle/Double/Rounded(layer: string, ...)`
- `drawButton(layer: string, ...)`
- `drawTextBox(layer: string, ...)`
- `drawSlider(layer: string, ...)`
- `drawCheckBox(layer: string, ...)`
- `drawProgressBar(layer: string, ...)`
- `drawSeparator(layer: string, ...)`

**Nimini Binding Strategy:**
- Created `resolveNiminiLayer(layerVal: Value): int` helper
- Manual polymorphic wrappers check value type (vkInt vs vkString)
- Disabled auto-registration for int versions to prevent conflicts
- Registration order: manual bindings before auto-exposed functions

### Phase 3: Documentation & Demos ✅

**Files Updated:**
- [docs/demos/layer-effects-demo.md](docs/demos/layer-effects-demo.md) - Now uses `"sky"`, `"mountains"`, `"trees"`, `"player"` throughout
- [docs/demos/drawing-layers.md](docs/demos/drawing-layers.md) - Updated to use `"background"`, `"middle"`, `"overlay"` with string API as primary
- [LAYER_NAMING_ISSUE.md](LAYER_NAMING_ISSUE.md) - This document, marked as resolved

**Documentation Changes:**
- String-based API presented as primary/recommended approach
- Numeric API documented as legacy/backwards-compatible
- Examples use semantic layer names consistently
- Added "String-Based Layer API" sections to tutorials

### Testing ✅

**Test Suite:**
- [test_layer_cache.nim](test_layer_cache.nim) - 7 tests, all passing
- [docs/demos/test-string-layers.md](docs/demos/test-string-layers.md) - Integration test demo

**Verified:**
- Cache invalidation and rebuild
- String and int resolveLayerIndex overloads
- Polymorphic function dispatch from nimini
- Backwards compatibility with existing demos
- Layer effects + drawing API consistency

### Migration Impact

**✅ Backwards Compatible:** All existing code continues to work
- Numeric indices still supported
- Auto-layer-creation unchanged
- No breaking changes

**✅ Forward Compatible:** New code can use cleaner API
```nim
# Old way (still works)
clear(1, true)
draw(1, x, y, "*", style)

# New way (recommended)
addLayer("sky", -3)
clear("sky", true)
draw("sky", x, y, "*", style)
```

### Performance Characteristics

- **Cache Build:** O(n) - only on first string lookup after invalidation
- **String Lookup:** O(1) - hash table lookup
- **Int Lookup:** O(1) - direct array access
- **Memory Overhead:** ~40 bytes per layer (string → int mapping)

**Cache is lazy:** Only rebuilds when needed, minimizing overhead.

### Lessons Learned

1. **Auto-binding limitations:** Nim's macro-based auto-binding doesn't handle polymorphic overloads well
2. **Manual wrappers required:** Type checking must happen in binding layer, not in core functions
3. **Registration order matters:** Manual bindings must register before auto-exposed versions
4. **Caching strategy:** Lazy cache rebuild is more efficient than eager updates

### Future Work

**Potential Phase 4 (Far Future):**
- Consider deprecating numeric API if string adoption is strong
- Add compile-time warnings for numeric usage
- Migrate all internal code to string-based API
- Remove numeric overloads (breaking change)

**Not recommended now:** Numeric API is stable, widely used, and has zero overhead.

## Conclusion

The layer naming vs indexing inconsistency creates friction for users and limits the usability of the layer effects system. A hybrid approach with cached lookups and string overloads would provide the best balance of usability and performance, while maintaining backwards compatibility.

The layer effects plugin proves the value of semantic layer names - the API is much clearer with `setLayerOffset("sky", ...)` than `setLayerOffset(1, ...)`. Extending this pattern to the drawing API would make tstorie more intuitive and maintainable.
