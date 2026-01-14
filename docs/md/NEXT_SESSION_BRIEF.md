# Next Session: Complete Auto-Binding Infrastructure

## Goal
Eliminate 95% of manual wrapper code by completing auto-binding infrastructure for registry and pointer patterns.

## Current State

### What Works ✅
- **auto_bindings.nim** (274 lines) - Auto-exposes simple functions
  - Handles: int, float, string, bool, Style, Color, seq[T], tuple
  - Used successfully in: ascii_art, figlet, ansi_parser (10 functions)
  - Binary: 1.2M (no increase)

### What's Incomplete 🚧
- **auto_registry.nim** (195 lines) - Skeleton only, macros not functional
- **auto_pointer.nim** (248 lines) - Skeleton only, macros not functional

### Problem Modules (Need Infrastructure)
These modules have 600+ lines of manual wrappers that can be eliminated:

| Module | Pattern | Lines | Functions | Issue |
|--------|---------|-------|-----------|-------|
| particles_bindings.nim | Registry | 647 | ~25 | Manual string ID lookups |
| text_editor_bindings.nim | Registry | 645 | ~30 | Manual EditorState lookups |
| dungeon_bindings.nim | Pointer | 181 | ~10 | Manual pointer casting |

**Total removable code: ~1,473 lines**

---

## What Needs to Be Built

### 1. Complete `auto_registry.nim` Macro System

**Purpose**: Auto-generate wrappers for modules with multiple named instances

**Required Functionality**:
```nim
# In lib/mymodule.nim
type MySystem* = ref object
  data: seq[Thing]

# Declare registry (generates global Table[string, MySystem])
autoRegistry(MySystem, "mysys")

# Constructor - auto-generates wrapper that returns string ID
proc createMySystem*(capacity: int): MySystem {.autoExposeRegistry: "mysys".} =
  result = MySystem(data: newSeqOfCap[Thing](capacity))

# Methods - auto-generates wrappers that lookup by ID
proc addThing*(id: string, x: int) {.autoExposeRegistryMethod: "mysys".} =
  # 'self' is auto-injected as the MySystem instance
  self.data.add(Thing(x: x))

proc getCount*(id: string): int {.autoExposeRegistryMethod: "mysys".} =
  return self.data.len
```

**What the Macros Must Generate**:
```nim
# From autoRegistry(MySystem, "mysys"):
var gMySystemRegistry {.global.}: Table[string, MySystem]
var gMySystemNextId {.global.}: int = 0

# From {.autoExposeRegistry: "mysys".}:
proc createMySystem*(capacity: int): MySystem =
  result = MySystem(data: newSeqOfCap[Thing](capacity))

proc niminiAuto_createMySystem(env: ref Env; args: seq[Value]): Value {.nimini.} =
  let capacity = valueToInt(args[0])
  let instance = createMySystem(capacity)
  let id = "mysys_" & $gMySystemNextId
  gMySystemNextId += 1
  gMySystemRegistry[id] = instance
  GC_ref(instance)
  return valString(id)

proc register_createMySystem*() =
  registerNative("createMySystem", niminiAuto_createMySystem, 
    storieLibs = @["mysys"])

# From {.autoExposeRegistryMethod: "mysys".}:
proc addThing*(self: MySystem, x: int) =  # Rewritten with explicit self
  self.data.add(Thing(x: x))

proc niminiAuto_addThing(env: ref Env; args: seq[Value]): Value {.nimini.} =
  let id = valueToString(args[0])
  if id notin gMySystemRegistry: return valNil()
  let self = gMySystemRegistry[id]
  let x = valueToInt(args[1])
  addThing(self, x)
  return valNil()

proc register_addThing*() =
  registerNative("addThing", niminiAuto_addThing, 
    storieLibs = @["mysys"])
```

**Key Macro Challenges**:
1. Rewrite proc signature to inject `self` parameter
2. Parse original proc body and replace implicit `self` references
3. Generate parameter conversion code for all Value types
4. Handle return type conversion (void, int, string, etc.)
5. Store compile-time registry info for use across multiple macros

---

### 2. Complete `auto_pointer.nim` Macro System

**Purpose**: Auto-generate wrappers for ref objects using pointer handles

**Required Functionality**:
```nim
# In lib/mymodule.nim
type MyGenerator* = ref object
  state: int
  items: seq[Item]

# Declare pointer management (generates global Table[int, pointer])
autoPointer(MyGenerator)

# Constructor - auto-generates wrapper that returns int pointer ID
proc createGenerator*(size: int): MyGenerator {.autoExposePointer.} =
  result = MyGenerator(state: 0, items: newSeq[Item](size))

# Methods - auto-generates wrappers that cast pointer
proc updateGenerator*(ptrId: int, delta: int): bool {.autoExposePointerMethod: MyGenerator.} =
  # 'self' is auto-injected as cast MyGenerator
  self.state += delta
  return self.state > 100
```

**What the Macros Must Generate**:
```nim
# From autoPointer(MyGenerator):
var gMyGeneratorPtrTable {.global.}: Table[int, pointer]
var gMyGeneratorNextId {.global.}: int = 1

# From {.autoExposePointer.}:
proc createGenerator*(size: int): MyGenerator =
  result = MyGenerator(state: 0, items: newSeq[Item](size))

proc niminiAuto_createGenerator(env: ref Env; args: seq[Value]): Value {.nimini.} =
  let size = valueToInt(args[0])
  let instance = createGenerator(size)
  let id = gMyGeneratorNextId
  gMyGeneratorNextId += 1
  gMyGeneratorPtrTable[id] = cast[pointer](instance)
  GC_ref(instance)
  return valInt(id)

proc register_createGenerator*() =
  registerNative("createGenerator", niminiAuto_createGenerator)

# From {.autoExposePointerMethod: MyGenerator.}:
proc updateGenerator*(self: MyGenerator, delta: int): bool =
  self.state += delta
  return self.state > 100

proc niminiAuto_updateGenerator(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args[0].kind != vkInt: return valNil()
  let ptrId = args[0].i
  if ptrId notin gMyGeneratorPtrTable: return valNil()
  let self = cast[MyGenerator](gMyGeneratorPtrTable[ptrId])
  let delta = valueToInt(args[1])
  let result = updateGenerator(self, delta)
  return valBool(result)

proc register_updateGenerator*() =
  registerNative("updateGenerator", niminiAuto_updateGenerator)
```

---

### 3. Apply to Existing Modules

**Order of Conversion** (easiest to hardest):

#### Phase 1: Dungeon (Pointer Pattern - Simplest)
- **File**: lib/dungeon_gen.nim
- **Current**: 181 lines of manual wrappers in dungeon_bindings.nim
- **Target**: 10 one-line registrations
- **Complexity**: Low (only ~10 functions, simple types)

#### Phase 2: Particles (Registry Pattern)
- **File**: lib/particles.nim
- **Current**: 647 lines of manual wrappers in particles_bindings.nim
- **Target**: 25 one-line registrations
- **Complexity**: Medium (vector operations, more functions)

#### Phase 3: Text Editor (Registry Pattern - Most Complex)
- **File**: lib/text_editor.nim
- **Current**: 645 lines of manual wrappers in text_editor_bindings.nim
- **Target**: 30 one-line registrations
- **Complexity**: High (~30 functions, complex state, undo system)

---

## Step-by-Step Implementation Plan

### Step 1: Complete auto_pointer.nim (Simpler Than Registry)
1. Implement `autoPointer` macro - generate global tables
2. Implement `autoExposePointer` macro - constructor wrapper
3. Implement `autoExposePointerMethod` macro - method wrappers
4. Write test module to verify (simple ref object with 3 methods)
5. Compile and verify binary size unchanged

### Step 2: Convert dungeon_gen.nim
1. Add `autoPointer(DungeonGenerator)` to dungeon_gen.nim
2. Add pragmas to all exported procs
3. Rewrite dungeon_bindings.nim to just call register_* functions
4. Compile, test, measure (should reduce ~170 lines)

### Step 3: Complete auto_registry.nim (More Complex)
1. Implement `autoRegistry` macro - generate global tables
2. Implement `autoExposeRegistry` macro - constructor wrapper
3. Implement `autoExposeRegistryMethod` macro - method wrappers
4. Write test module to verify (simple ref object with 3 methods)
5. Compile and verify binary size unchanged

### Step 4: Convert particles.nim
1. Add `autoRegistry(ParticleSystem, "particle")` to particles.nim
2. Add pragmas to all exported procs
3. Rewrite particles_bindings.nim to just call register_* functions
4. Compile, test, measure (should reduce ~620 lines)

### Step 5: Convert text_editor.nim
1. Add `autoRegistry(EditorState, "editor")` to text_editor.nim
2. Add pragmas to all exported procs
3. Rewrite text_editor_bindings.nim to just call register_* functions
4. Compile, test, measure (should reduce ~615 lines)

---

## Success Criteria

### Functional Requirements
- ✅ All existing tests pass (dungeon, particles, text_editor)
- ✅ No behavior changes (scripts work identically)
- ✅ Binary size: 1.2M ± 10KB (allow small variance)

### Code Quality Requirements
- ✅ Macro error messages are helpful (not cryptic)
- ✅ Type safety maintained (no raw casts in user code)
- ✅ GC_ref/GC_unref handled automatically
- ✅ Parameter validation in generated wrappers

### Documentation Requirements
- ✅ Update MODULE_BINDING_STANDARD.md with new patterns
- ✅ Add examples to AUTO_BINDABLE_MODULE_GUIDE.md
- ✅ Document macro limitations and edge cases

### Measurement Requirements
- **Code Reduction**: ~1,473 lines → ~65 lines (95% reduction)
- **Compile Time**: Should remain ~22 seconds
- **Runtime**: No performance degradation
- **Binary**: No size increase

---

## Key Files Reference

### Infrastructure (To Complete)
- `nimini/auto_registry.nim` - Registry pattern macros (NEEDS IMPLEMENTATION)
- `nimini/auto_pointer.nim` - Pointer pattern macros (NEEDS IMPLEMENTATION)

### Already Working
- `nimini/auto_bindings.nim` - Simple function auto-binding (COMPLETE ✅)
- `nimini/type_converters.nim` - Type conversion helpers (COMPLETE ✅)

### Modules to Convert
- `lib/dungeon_gen.nim` + `lib/dungeon_bindings.nim` (181 lines → ~10)
- `lib/particles.nim` + `lib/particles_bindings.nim` (647 lines → ~25)
- `lib/text_editor.nim` + `lib/text_editor_bindings.nim` (645 lines → ~30)

### Documentation
- `MODULE_BINDING_STANDARD.md` - Current patterns (TO UPDATE)
- `docs/AUTO_BINDABLE_MODULE_GUIDE.md` - Vision and examples (REFERENCE)

---

## Technical Notes

### Macro Implementation Hints

**For auto_registry.nim**:
- Use `{.compileTime.}` table to track registry info across macro invocations
- Parse proc body with `macros.nnkStmtList` traversal
- Replace `id: string` first param with explicit `self: Type` param
- Use `getTypeImpl()` to extract type info for conversion generation

**For auto_pointer.nim**:
- Simpler than registry (no ID generation, just pointer casting)
- Use `{.compileTime.}` table to associate type with pointer table name
- First param must be `ptrId: int` for method macros
- Generate pointer validation (check `vkInt` and table contains key)

**Type Conversion Strategy**:
- Reuse existing `valueToInt`, `valueToFloat`, etc. from type_converters.nim
- Generate calls to these helpers in wrapper code
- For returns: use `valInt()`, `valString()`, `valNil()`, etc.

### Common Pitfalls to Avoid
1. **Hygiene**: Use `gensym()` for generated variable names
2. **Type inference**: Extract types from proc params, don't assume
3. **Error handling**: Check `args.len` before access
4. **GC management**: Always `GC_ref` stored instances, provide cleanup
5. **Scope**: Registry tables must be `{.global.}` for cross-module access

---

## Example Test Module Structure

```nim
# test_auto_registry.nim
import ../nimini/auto_registry

type TestSystem* = ref object
  value: int

autoRegistry(TestSystem, "test")

proc createTest*(initial: int): TestSystem {.autoExposeRegistry: "test".} =
  result = TestSystem(value: initial)

proc addValue*(id: string, amount: int) {.autoExposeRegistryMethod: "test".} =
  self.value += amount

proc getValue*(id: string): int {.autoExposeRegistryMethod: "test".} =
  return self.value

# test_auto_registry_bindings.nim
import ../nimini
import test_auto_registry

proc registerTestBindings*(env: ref Env) =
  register_createTest()
  register_addValue()
  register_getValue()

# test_registry.nimini
let sys = createTest(100)
addValue(sys, 50)
let result = getValue(sys)
assert(result == 150)
```

---

## Questions to Resolve During Implementation

1. **Naming**: Should registry IDs be user-specified or auto-generated?
   - Current plan: Auto-generate ("particle_0", "particle_1", etc.)
   - Alternative: User provides name in script

2. **Cleanup**: How to remove instances from registries?
   - Current plan: Add auto-generated `removeXxx(id: string)` functions
   - Need GC_unref + table deletion

3. **Type Support**: Which types need converters?
   - Already handled: int, float, string, bool, seq[T], tuple, Style, Color
   - May need: Custom types (Vec2, Rect, etc.)

4. **Error Handling**: What happens on invalid ID/pointer?
   - Current plan: Return valNil() silently
   - Alternative: Return error Value or throw

5. **Export**: Should these also work for wasm export?
   - Current plan: Yes, same infrastructure
   - May need additional export generation

---

## Current Binary Size Baseline
```
$ ls -lh tstorie
-rwxr-xr-x 1 vscode vscode 1.2M Jan 14 02:30 tstorie
```

**All changes must maintain this size (±10KB acceptable).**

---

## Start Here

1. **Read**: `nimini/auto_bindings.nim` (274 lines) - understand working macro
2. **Read**: `docs/AUTO_BINDABLE_MODULE_GUIDE.md` - understand target design
3. **Implement**: `auto_pointer.nim` first (simpler - no ID generation)
4. **Test**: Create small test module and verify compilation
5. **Apply**: Convert dungeon_gen.nim as proof of concept
6. **Measure**: Binary size, line count, compile time
7. **Iterate**: Complete auto_registry.nim and convert remaining modules

The infrastructure skeletons are in place, just need the macro logic completed.
