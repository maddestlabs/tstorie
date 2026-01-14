# Nimini Bindings Consolidation Plan

## Problem Analysis

The current binding system has **three different patterns** across modules:

### Pattern 1: Manual Registration (OLD - particles, figlet, ascii_art, ansi_art)
```nim
proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize particle system
  # implementation...

proc registerParticleBindings*(env: ref Env, appState: AppState) =
  env.vars["particleInit"] = valNativeFunc(particleInit)
  # ... 46 more functions
```

**Problems:**
- No export metadata
- Manual registration is error-prone
- Metadata lives in separate `tstorie_export_metadata.nim`
- ~200 KB of binding overhead

### Pattern 2: registerNative with metadata (NEW - dungeon, tui_helpers)
```nim
proc nimini_dungeonGenerate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  # implementation...

proc registerDungeonBindings*() =
  registerNative("dungeonGenerate", nimini_dungeonGenerate,
    storieLibs = @["dungeon_gen"],
    description = "Generate dungeon with parameters")
```

**Better but:**
- Still requires wrapper `nimini_*` procs
- Registration boilerplate
- Function name duplicated

### Pattern 3: IDEAL (not yet implemented)
```nim
proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini, 
  storieLib: "particles",
  desc: "Initialize particle system"
.} =
  # implementation...
```

**Benefits:**
- Single source of truth
- No wrapper functions needed
- Metadata attached to function
- Automatic registration via pragma

## Root Cause

The `.nimini.` pragma was designed for **type checking** but doesn't:
1. Auto-register functions
2. Carry export metadata
3. Generate wrappers

This forces us to create separate `*_bindings.nim` files that are mostly boilerplate.

## Solution Strategy

### Phase 1: Consolidate to registerNative (IMMEDIATE)

Convert all old-style bindings to use `registerNative()` with metadata:

**Files to convert:**
- ✅ `lib/dungeon_bindings.nim` - already done
- ✅ `lib/tui_helpers_bindings.nim` - already done  
- ❌ `lib/particles_bindings.nim` - **46 functions** to convert
- ❌ `lib/figlet_bindings.nim` - ~15 functions to convert
- ❌ `lib/ascii_art_bindings.nim` - ~8 functions to convert
- ❌ `lib/ansi_art_bindings.nim` - ~5 functions to convert

**Conversion tool exists:** `tools/convert_to_register_native.nim`

### Phase 2: Eliminate Wrapper Functions (NEXT)

Many binding functions are trivial wrappers. Check if we can:

1. **Call implementation directly** if it already takes `(env, args)`
2. **Use inline lambda** for simple wrappers
3. **Move logic into impl** module with `.nimini.` pragma

Example:
```nim
# BEFORE: Wrapper in particles_bindings.nim
proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 1: return valNil()
  let name = args[0].s
  let maxParticles = if args.len >= 2: args[1].i else: 1000
  gParticleSystems[name] = initParticleSystem(maxParticles)
  return valNil()

# AFTER: Direct in particles.nim  
proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini,
  storieLib: "particles",
  desc: "Initialize particle system"
.} =
  if args.len < 1: return valNil()
  let name = args[0].s
  let maxParticles = if args.len >= 2: args[1].i else: 1000
  gParticleSystems[name] = initParticleSystem(maxParticles)
  return valNil()
```

### Phase 3: Enhanced .nimini Pragma (FUTURE)

Extend the pragma to carry metadata and auto-register:

```nim
# In nimini/lang/nim_extensions.nim
template nimini*(storieLib: string = "", 
                 desc: string = "",
                 deps: seq[string] = @[]) {.pragma.}

# Macro to process .nimini procs and auto-register them
macro registerNiminiProcs*(): untyped =
  # Scan for procs with .nimini pragma
  # Extract metadata from pragma parameters
  # Generate registerNative() calls
```

## Implementation Plan

### Step 1: Convert particles_bindings.nim ✅ Tool exists

```bash
nim c -r tools/convert_to_register_native.nim lib/particles_bindings.nim
```

This will:
- Convert 46 functions to `registerNative()` pattern
- Extract metadata from doc comments
- Add `storieLibs: @["particles"]`
- Create `.backup` file

### Step 2: Convert remaining bindings

```bash
nim c -r tools/convert_to_register_native.nim lib/figlet_bindings.nim
nim c -r tools/convert_to_register_native.nim lib/ascii_art_bindings.nim
nim c -r tools/convert_to_register_native.nim lib/ansi_art_bindings.nim
```

### Step 3: Clean up tstorie_export_metadata.nim

Remove entries that now have metadata in binding files:
- All particle functions (46 entries)
- Figlet functions
- ASCII/ANSI art functions

Keep only:
- Runtime-only functions (termWidth, termHeight, draw, clear)
- Functions that aren't in binding modules

### Step 4: Identify redundant wrappers

Audit each binding file to see if:
1. Function just calls another function → inline it
2. Function does arg conversion → can impl module do it?
3. Function maintains global state → move state to impl module

### Step 5: Test exports

```bash
./ts export docs/demos/depths.md
nim c output/standalone_compiled_particle  
./standalone_compiled_particle
```

## Size Impact Estimation

### Current Binding Modules (~200 KB total):
- `particles_bindings.nim`: ~25 KB
- `figlet_bindings.nim`: ~25 KB
- `tui_helpers_bindings.nim`: ~20 KB
- `ascii_art_bindings.nim`: ~15 KB
- `ansi_art_bindings.nim`: ~20 KB
- `dungeon_bindings.nim`: ~15 KB
- `text_editor_bindings.nim`: ~15 KB
- Other bindings: ~65 KB

### After Consolidation:

**registerNative conversion** (Phase 1): ~0 KB savings
- Same functions, just better organized
- But enables future savings

**Eliminate wrappers** (Phase 2): ~50-80 KB savings
- Move simple wrappers into impl modules
- Reduce duplicate code
- Fewer function calls

**Enhanced pragma** (Phase 3): ~100-150 KB savings
- Eliminate binding files entirely
- Direct registration from impl modules
- Smaller binary, cleaner code

**Total potential:** 150-230 KB reduction (12-19% of binary)

## Files to Modify

### Immediate (Phase 1):
1. Run conversion tool on 4 binding files
2. Update `tstorie_export_metadata.nim`
3. Test exports

### Next (Phase 2):
1. `lib/particles.nim` - add nimini functions directly
2. `lib/figlet.nim` - add nimini functions directly
3. Remove `lib/particles_bindings.nim` (or reduce to just registration)
4. Remove `lib/figlet_bindings.nim` (or reduce)

### Future (Phase 3):
1. `nimini/lang/nim_extensions.nim` - enhance pragma
2. Add auto-registration macro
3. Eliminate all `*_bindings.nim` files

## Validation

After each phase:
1. Build tstorie: `./build.sh`
2. Test export: `./ts export docs/demos/depths.md`
3. Compile export: `nim c output/standalone_compiled_particle`
4. Run export: `./standalone_compiled_particle`
5. Check binary size: `ls -lh tstorie`

## Next Action

Start with Phase 1 - run the conversion tool:

```bash
cd /workspaces/telestorie
nim c -r tools/convert_to_register_native.nim --dry-run lib/particles_bindings.nim
# Review output
nim c -r tools/convert_to_register_native.nim lib/particles_bindings.nim
```
