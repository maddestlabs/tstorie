# Proposal: Self-Describing Functions with Import Metadata

## Problem Statement

The current Nim export system requires maintaining separate lookup tables mapping function names to their required imports. This is:
- **Error-prone**: Tables can get out of sync with actual functions
- **Not scalable**: Every new function needs manual table updates
- **Limited**: Can't handle transitive dependencies or user-defined functions
- **Duplicated**: Information exists in both the function and the table

## Proposed Solution

**Make every Nimini function self-describing by including import metadata at registration time.**

## Implementation

### Phase 1: Extend Registration System

```nim
# In nimini/runtime.nim

type
  FunctionMetadata* = object
    imports*: seq[string]              # Nim stdlib imports needed
    storieLibs*: seq[string]           # tStorie lib/ modules needed
    dependencies*: seq[string]         # Other nimini functions this calls
    description*: string               # Human-readable description
    paramTypes*: seq[string]           # Expected parameter types (future)
    returnType*: string                # Return type (future)
    platforms*: seq[string]            # Supported platforms (future)

# Global metadata registry
var gFunctionMetadata* = initTable[string, FunctionMetadata]()

proc registerNative*(name: string, 
                    fn: NativeProc,
                    imports: seq[string] = @[],
                    storieLibs: seq[string] = @[],
                    dependencies: seq[string] = @[],
                    description: string = "") =
  ## Register a native function with comprehensive metadata
  gNativeFuncs[name] = fn
  
  if imports.len > 0 or storieLibs.len > 0 or description.len > 0:
    gFunctionMetadata[name] = FunctionMetadata(
      imports: imports,
      storieLibs: storieLibs,
      dependencies: dependencies,
      description: description
    )

proc getImports*(funcName: string): seq[string] =
  ## Get required imports for a function
  if gFunctionMetadata.hasKey(funcName):
    return gFunctionMetadata[funcName].imports
  return @[]

proc getStorieLibs*(funcName: string): seq[string] =
  ## Get required tStorie libs for a function
  if gFunctionMetadata.hasKey(funcName):
    return gFunctionMetadata[funcName].storieLibs
  return @[]

proc resolveAllDependencies*(funcName: string): HashSet[string] =
  ## Recursively resolve all imports including transitive dependencies
  result = initHashSet[string]()
  var visited = initHashSet[string]()
  
  proc visit(name: string) =
    if name in visited: return
    visited.incl(name)
    
    if gFunctionMetadata.hasKey(name):
      let meta = gFunctionMetadata[name]
      
      # Add direct imports
      for imp in meta.imports:
        result.incl(imp)
      
      # Recursively resolve dependencies
      for dep in meta.dependencies:
        visit(dep)
  
  visit(funcName)
```

### Phase 2: Update All Stdlib Registrations

```nim
# In nimini.nim - initStdlib()

proc initStdlib*() =
  ## Register standard library functions with import metadata
  
  # Math functions
  registerNative("sin", niminiSin,
    imports = @["math"],
    description = "Sine function - returns the sine of x (x in radians)")
  
  registerNative("cos", niminiCos,
    imports = @["math"],
    description = "Cosine function - returns the cosine of x (x in radians)")
  
  registerNative("sqrt", niminiSqrt,
    imports = @["math"],
    description = "Square root function")
  
  registerNative("pow", niminiPow,
    imports = @["math"],
    description = "Power function - returns x raised to the power of y")
  
  registerNative("floor", niminiFloor,
    imports = @["math"],
    description = "Floor function - largest integer <= x")
  
  registerNative("ceil", niminiCeil,
    imports = @["math"],
    description = "Ceiling function - smallest integer >= x")
  
  # String functions
  registerNative("split", niminiSplit,
    imports = @["strutils"],
    description = "Split string by separator")
  
  registerNative("join", niminiJoin,
    imports = @["strutils"],
    description = "Join sequence of strings with separator")
  
  registerNative("strip", niminiStrip,
    imports = @["strutils"],
    description = "Remove leading/trailing whitespace")
  
  registerNative("replace", niminiReplace,
    imports = @["strutils"],
    description = "Replace all occurrences of substring")
  
  # Sequence operations (built-in, no imports needed)
  registerNative("add", niminiAdd,
    description = "Add element to sequence")
  
  registerNative("len", niminiLen,
    description = "Get length of sequence or string")
  
  # Random functions
  registerNative("randomize", niminiRandomize,
    imports = @["random"],
    description = "Initialize random number generator with current time")
  
  registerNative("rand", niminiRand,
    imports = @["random"],
    description = "Generate random integer in range")
  
  registerNative("sample", niminiSample,
    imports = @["random"],
    dependencies = @["rand"],  # Depends on rand
    description = "Randomly sample element from sequence")
  
  # Algorithm functions
  registerNative("sort", niminiSort,
    imports = @["algorithm"],
    description = "Sort sequence in place")
  
  registerNative("reverse", niminiReverse,
    imports = @["algorithm"],
    description = "Reverse sequence in place")
```

### Phase 3: Register tStorie Library Functions

```nim
# In tstorie.nim or wherever tStorie-specific functions are registered

proc registerTStorieLibs*() =
  ## Register tStorie library functions with their import metadata
  
  # Canvas/drawing functions
  registerNative("write", niminiWrite,
    storieLibs = @["canvas"],
    description = "Write text at position on current layer")
  
  registerNative("drawRect", niminiDrawRect,
    storieLibs = @["canvas"],
    description = "Draw rectangle on current layer")
  
  registerNative("fill", niminiFill,
    storieLibs = @["canvas"],
    description = "Fill region with character")
  
  registerNative("clear", niminiClear,
    storieLibs = @["canvas"],
    description = "Clear the current layer")
  
  # Layout functions
  registerNative("wrapText", niminiWrapText,
    storieLibs = @["layout"],
    description = "Wrap text to fit within width")
  
  registerNative("alignHorizontal", niminiAlignHorizontal,
    storieLibs = @["layout"],
    description = "Align text horizontally (left/center/right)")
  
  registerNative("writeAligned", niminiWriteAligned,
    storieLibs = @["layout", "canvas"],
    description = "Write aligned text on layer")
  
  # Audio functions
  registerNative("playTone", niminiPlayTone,
    storieLibs = @["audio"],
    description = "Play a tone at specified frequency")
  
  registerNative("playSound", niminiPlaySound,
    storieLibs = @["audio"],
    description = "Play a registered sound by name")
  
  registerNative("playBleep", niminiPlayBleep,
    storieLibs = @["audio"],
    dependencies = @["playTone"],
    description = "Play a short bleep sound")
  
  # Figlet functions
  registerNative("renderFiglet", niminiRenderFiglet,
    storieLibs = @["figlet"],
    description = "Render ASCII art text using figlet font")
```

### Phase 4: Simplify Export System

```nim
# NEW SIMPLIFIED lib/nim_export.nim

import tables, sets, strutils, sequtils
import storie_types, storie_md
import ../nimini
import ../nimini/ast
import ../nimini/runtime  # Import to access gFunctionMetadata

type
  ImportInfo* = object
    stdLibImports*: HashSet[string]
    storieLibImports*: HashSet[string]
    customImports*: HashSet[string]
  
  ExportContext* = object
    imports*: ImportInfo
    # ... rest same as before

# ==============================================================================
# DRAMATICALLY SIMPLIFIED AST Analysis
# ==============================================================================

proc analyzeExpression(expr: Expr, imports: var ImportInfo) =
  ## Recursively analyze expressions and gather imports from metadata
  if expr.isNil:
    return
  
  case expr.kind
  of ekCall:
    # Simply look up the function's metadata!
    if gFunctionMetadata.hasKey(expr.funcName):
      let meta = gFunctionMetadata[expr.funcName]
      
      # Add stdlib imports
      for imp in meta.imports:
        imports.stdLibImports.incl(imp)
      
      # Add tStorie lib imports
      for lib in meta.storieLibs:
        imports.storieLibImports.incl(lib)
      
      # Recursively resolve dependencies
      for dep in meta.dependencies:
        if gFunctionMetadata.hasKey(dep):
          let depMeta = gFunctionMetadata[dep]
          for imp in depMeta.imports:
            imports.stdLibImports.incl(imp)
          for lib in depMeta.storieLibs:
            imports.storieLibImports.incl(lib)
    
    # Analyze arguments
    for arg in expr.args:
      analyzeExpression(arg, imports)
  
  # ... rest of expression handling (same as before)

# That's it! No more giant lookup tables!
# The rest of the export system stays the same
```

## Benefits

### 1. Maintainability
- **Single source of truth**: Import info lives with the function
- **No sync issues**: Can't forget to update lookup tables
- **Easy to add new functions**: Just include metadata at registration

### 2. Extensibility
- **User functions**: Users can register their own with metadata
- **Plugins**: Third-party extensions automatically work
- **Transitive deps**: Automatically resolve dependency chains

### 3. Better Tooling
- **Auto-documentation**: Generate API docs with import requirements
- **IDE support**: Could provide import suggestions in editor
- **Validation**: Warn when functions lack metadata

### 4. Future Features
- **Type checking**: Can validate parameters at parse time
- **Platform detection**: Know which functions work on which platforms
- **Optimization hints**: Mark pure functions, inline candidates, etc.

## Migration Strategy

1. **Phase 1** (Non-breaking): Add metadata fields to `registerNative`
   - Old code still works (empty metadata)
   - New registrations can include metadata

2. **Phase 2**: Update stdlib registrations one module at a time
   - `mathops.nim` first (lots of functions, clear imports)
   - Then `collections.nim`, `typeconv.nim`, etc.

3. **Phase 3**: Update tStorie library registrations
   - `canvas`, `layout`, `audio`, etc.

4. **Phase 4**: Deprecate lookup tables in `nim_export.nim`
   - Keep as fallback for backwards compatibility
   - Add warning for functions without metadata

5. **Phase 5**: Eventually require metadata
   - Make imports/storieLibs required parameters
   - Remove fallback lookup tables

## Example: Before & After

### Before (Current System)

```nim
# In lib/nim_export.nim - manually maintained lookup table
const StdLibFunctionMap = {
  "sin": "math",
  "cos": "math",
  "sqrt": "math",
  "split": "strutils",
  # ... 50+ more entries
}.toTable

# In nimini.nim - function registration
registerNative("sin", niminiSin)
registerNative("cos", niminiCos)
# No connection between function and its imports!
```

### After (Metadata System)

```nim
# In nimini.nim - self-describing registration
registerNative("sin", niminiSin,
  imports = @["math"],
  description = "Sine function")

registerNative("cos", niminiCos,
  imports = @["math"],
  description = "Cosine function")

# In lib/nim_export.nim - no lookup table needed!
# Just query gFunctionMetadata directly
```

## Open Questions

1. **Should metadata be required or optional?**
   - Start optional for backwards compatibility
   - Eventually require for export-targeted code

2. **How to handle platform-specific imports?**
   - Add `when defined(...)` support to metadata?
   - Or register different versions per platform?

3. **Should user code be able to add metadata?**
   ```nim
   # In user's markdown:
   ```nim
   {.requires: "json".}
   proc parseJson(s: string): JsonNode = ...
   ```
   ```

4. **How to handle conflicting dependencies?**
   - If two functions need different versions of same lib?
   - Probably not an issue in practice

## Conclusion

This approach is **significantly better** than lookup tables:

✅ More maintainable (single source of truth)
✅ More accurate (can't get out of sync)
✅ More scalable (new functions just work)
✅ More extensible (user functions, plugins)
✅ Enables better tooling (docs, validation, IDE support)

The migration is straightforward and non-breaking. The export system becomes dramatically simpler.

**Recommendation**: Implement this before continuing with export Phases 2-7. The improved foundation will make all future work easier.
