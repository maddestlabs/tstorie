# Export System Enhancement

## Problem Identified

The tStorie export system has a **design inconsistency**:

1. **Centralized metadata file** (`lib/tstorie_export_metadata.nim`) manually maintains function metadata for 46+ particle functions, plus functions from other binding libraries
2. **Metadata separated from source** - function definitions live in `*_bindings.nim`, but their export metadata lives elsewhere
3. **Manual maintenance required** - when adding new functions, developers must update multiple files
4. **Violates DRY principle** - function information duplicated across files

## Root Cause

Older binding files use manual registration pattern:
```nim
proc particleInit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Initialize particle system
  # implementation...

# Registered elsewhere without metadata
env.registerProc("particleInit", particleInit)
```

Newer bindings use `registerNative()` with inline metadata:
```nim
registerNative("dungeonGenerate", """
  Generate dungeon with parameters
  Args: name (string), width (int), height (int)
  Libs: dungeon
"""):
  # implementation inline
```

## Desired Architecture

**Self-contained modules** where each `*_bindings.nim` file:
- Defines function implementation
- Registers with nimini runtime
- Provides metadata for export system
- **All in one place**

This eliminates:
- ❌ `lib/tstorie_export_metadata.nim` (centralized patch file)
- ❌ Manual metadata duplication
- ❌ Export wrapper generation in `lib/nim_export.nim`

## Solution Created

### Tool: `tools/convert_to_register_native.nim`

Automatically converts old-style bindings to modern `registerNative()` pattern:

```bash
# Preview conversion for one file
nim c -r tools/convert_to_register_native.nim --dry-run lib/particles_bindings.nim

# Convert one file (creates .backup)
nim c -r tools/convert_to_register_native.nim lib/particles_bindings.nim

# Convert all binding files at once
nim c -r tools/convert_to_register_native.nim --all
```

**What it does:**
1. Parses `proc funcName*(env: ref Env; args: seq[Value]): Value {.nimini.}` declarations
2. Extracts doc comments, function bodies, parameters
3. Auto-detects module name from imports (e.g., `import particles` → `Libs: particles`)
4. Generates `registerNative("funcName", """metadata""")` with inline implementation
5. Creates `.backup` files for safety

## Current Status

### ✅ Completed
- Created conversion tool with dry-run support
- Tool correctly detects 46 particle functions
- Module detection working (`Libs: particles` not `Libs: [tables,`)
- Added all 46 particle function entries to `tstorie_export_metadata.nim` (temporary fix)
- Removed broken manual wrappers from `lib/nim_export.nim`
- Export system now imports `particles_bindings` directly

### 🚧 In Progress
- Tool tested with `--dry-run` on `particles_bindings.nim`
- Preview output looks correct

### 📋 Remaining Work

**Phase 1: Convert Binding Files** (Run tool)
```bash
cd /workspaces/telestorie
nim c -r tools/convert_to_register_native.nim --all
```

Files to convert (8 total):
- ✅ `lib/dungeon_bindings.nim` - already uses `registerNative()`
- ✅ `lib/text_editor_bindings.nim` - already uses `registerNative()`
- ⚠️ `lib/particles_bindings.nim` - needs conversion (46 functions)
- ⚠️ `lib/figlet_bindings.nim` - needs conversion
- ⚠️ `lib/ascii_art_bindings.nim` - needs conversion  
- ⚠️ `lib/ansi_art_bindings.nim` - needs conversion
- ⚠️ `lib/tui_helpers_bindings.nim` - needs conversion
- ❓ `lib/miniaudio_bindings.nim` - check if needs conversion

**Phase 2: Update Export System**
1. Modify `lib/nim_export.nim` to read metadata from `registerNative()` docstrings
2. Test export with converted binding files
3. Remove temporary hack: `if expr.funcName.startsWith("particle")`

**Phase 3: Deprecate Central Metadata**
1. Remove all entries from `lib/tstorie_export_metadata.nim` that are now in binding files
2. Keep only runtime-only functions (termWidth, termHeight, draw, etc.)
3. Consider renaming to `lib/runtime_export_metadata.nim` for clarity

**Phase 4: Validation**
1. Export and compile `docs/demos/depths.md` successfully
2. Verify all particle functions work in export mode
3. Test other demos using figlet, ascii_art, etc.
4. Confirm no duplicate metadata registrations

## Technical Details

### registerNative() Pattern

The `registerNative()` macro (in `nimini/runtime.nim`) reads the docstring to extract:
- **Description**: First line or paragraph
- **Args**: Parameter specifications with types and defaults
- **Libs**: Module dependencies for native exports
- **Imports**: Additional stdlib imports needed

Example metadata format:
```nim
registerNative("particleCheckHit", """
  Check particle collision at position
  Args: name (string), x (int), y (int), radius (float, optional, default=1.0)
  Libs: particles
  Returns: bool
"""):
  if args.len < 3 or not gParticleSystems.hasKey(args[0].s):
    return valBool(false)
  let ps = gParticleSystems[args[0].s]
  let x = args[1].i
  let y = args[2].i
  let radius = if args.len >= 4: args[3].f else: 1.0
  return valBool(ps.checkHit(x, y, radius))
```

### Export System Flow

**Current (with centralized metadata):**
1. `nim_export.nim` analyzes markdown code
2. Looks up function in `gFunctionMetadata` table
3. Adds imports based on `storieLibs` field
4. Generates wrappers or imports binding file

**Target (self-contained):**
1. `nim_export.nim` analyzes markdown code  
2. Queries binding files via reflection or compile-time parsing
3. Extracts metadata from `registerNative()` docstrings
4. Generates imports automatically

## Benefits

1. **Single source of truth** - function definition and metadata together
2. **Maintainability** - add new function, metadata comes free
3. **Consistency** - enforced by `registerNative()` pattern
4. **Scalability** - new binding libraries work automatically
5. **Reduced files** - eliminate large metadata patch file

## Next Steps

**Immediate:**
1. Run `convert_to_register_native.nim --all`
2. Review and test converted files
3. Commit conversions with good commit messages

**Follow-up:**
1. Enhance export system to read metadata from `registerNative()`
2. Remove redundant entries from central metadata file
3. Document new binding creation process

## Notes

- Tool creates `.backup` files - review diffs before committing
- Some binding files (dungeon, text_editor) already use correct pattern
- Export system currently works via temporary metadata entries
- The `depths.md` compile error is unrelated (initCanvas API mismatch, not particles)
