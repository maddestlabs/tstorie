## Nimini Bindings for Dungeon Generator
## 
## Exposes the native dungeon generator to nimini scripting

import ../nimini
import dungeon_gen

# ==============================================================================
# Nimini Wrapper Functions
# ==============================================================================

proc nimini_newDungeonGenerator*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Create a new dungeon generator. Args: width (int), height (int), [seed (int)]
  if args.len < 2:
    return valNil()
  
  let width = toInt(args[0])
  let height = toInt(args[1])
  let seed = if args.len >= 3: toInt(args[2]) else: 0
  
  let gen = newDungeonGenerator(width, height, seed)
  GC_ref(gen)  # Keep the generator alive (it's a ref object)
  return valPointer(cast[pointer](gen))

proc nimini_dungeonGenerate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Generate complete dungeon (blocking). Args: generator (ptr)
  if args.len < 1 or args[0].kind != vkPointer:
    return valNil()
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  gen.generate()
  return valNil()

proc nimini_dungeonUpdate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Run one generation step. Args: generator (ptr)
  ## Returns: true if still generating, false if complete
  if args.len < 1 or args[0].kind != vkPointer:
    return valBool(false)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  let stillGenerating = gen.update()
  inc gen.step
  return valBool(stillGenerating)

proc nimini_dungeonGetCell*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get cell type at position. Args: generator (ptr), x (int), y (int)
  ## Returns: 0=solid, 1=floor, 2=door, 3=merged
  if args.len < 3 or args[0].kind != vkPointer:
    return valInt(0)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  let x = toInt(args[1])
  let y = toInt(args[2])
  let cell = gen.getCell(vec2(x, y))
  return valInt(ord(cell))

proc nimini_dungeonGetCellChar*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get character for cell type. Args: cellType (int)
  ## Returns: character string ("#", "·", "+")
  if args.len < 1:
    return valString(" ")
  
  let cellType = CellType(toInt(args[0]))
  return valString(getCellChar(cellType))

proc nimini_dungeonIsGenerating*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if generator is still generating. Args: generator (ptr)
  if args.len < 1 or args[0].kind != vkPointer:
    return valBool(false)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  return valBool(gen.isGenerating)

proc nimini_dungeonGetStep*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current generation step. Args: generator (ptr)
  if args.len < 1 or args[0].kind != vkPointer:
    return valInt(0)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  return valInt(gen.step)

proc nimini_dungeonGetWidth*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get dungeon width. Args: generator (ptr)
  if args.len < 1 or args[0].kind != vkPointer:
    return valInt(0)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  return valInt(gen.width)

proc nimini_dungeonGetHeight*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get dungeon height. Args: generator (ptr)
  if args.len < 1 or args[0].kind != vkPointer:
    return valInt(0)
  
  let gen = cast[DungeonGenerator](args[0].ptrVal)
  return valInt(gen.height)

proc nimini_dungeonReset*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Reset generator with new seed. Args: generator (ptr), width (int), height (int), [seed (int)]
  if args.len < 3 or args[0].kind != vkPointer:
    return valNil()
  
  let width = toInt(args[1])
  let height = toInt(args[2])
  let seed = if args.len >= 4: toInt(args[3]) else: 0
  
  # Create new generator and replace pointer
  let gen = newDungeonGenerator(width, height, seed)
  args[0].ptrVal = cast[pointer](gen)
  return valNil()

# ==============================================================================
# Registration
# ==============================================================================

proc registerDungeonBindings*() =
  ## Register all dungeon generator bindings with nimini runtime
  
  registerNative("newDungeonGenerator", nimini_newDungeonGenerator,
    storieLibs = @["dungeon_gen"],
    description = "Create new dungeon generator (native, high-performance)")
  
  registerNative("dungeonGenerate", nimini_dungeonGenerate,
    storieLibs = @["dungeon_gen"],
    description = "Generate complete dungeon instantly (blocking)")
  
  registerNative("dungeonUpdate", nimini_dungeonUpdate,
    storieLibs = @["dungeon_gen"],
    description = "Run one generation step (for incremental generation)")
  
  registerNative("dungeonGetCell", nimini_dungeonGetCell,
    storieLibs = @["dungeon_gen"],
    description = "Get cell type at position")
  
  registerNative("dungeonGetCellChar", nimini_dungeonGetCellChar,
    storieLibs = @["dungeon_gen"],
    description = "Get display character for cell type")
  
  registerNative("dungeonIsGenerating", nimini_dungeonIsGenerating,
    storieLibs = @["dungeon_gen"],
    description = "Check if dungeon is still generating")
  
  registerNative("dungeonGetStep", nimini_dungeonGetStep,
    storieLibs = @["dungeon_gen"],
    description = "Get current generation step")
  
  registerNative("dungeonGetWidth", nimini_dungeonGetWidth,
    storieLibs = @["dungeon_gen"],
    description = "Get dungeon width")
  
  registerNative("dungeonGetHeight", nimini_dungeonGetHeight,
    storieLibs = @["dungeon_gen"],
    description = "Get dungeon height")
  
  registerNative("dungeonReset", nimini_dungeonReset,
    storieLibs = @["dungeon_gen"],
    description = "Reset generator with new parameters")

export registerDungeonBindings
