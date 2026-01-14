## Auto-Pointer System for Nimini
##
## Provides infrastructure to auto-expose ref object methods using pointer handles.
## This eliminates manual pointer casting in *_bindings.nim files.
##
## USAGE EXAMPLE:
## ```nim
## # In lib/mymodule.nim
## import ../nimini/auto_pointer
##
## type MyGenerator* = ref object
##   state: int
##   data: seq[string]
##
## # Define pointer management
## autoPointer(MyGenerator)
##
## # Auto-expose constructor - returns int pointer ID
## proc createGenerator*(size: int): MyGenerator {.autoExposePointer.} =
##   result = MyGenerator(state: 0, data: newSeq[string](size))
##
## # Auto-expose method - first param is pointer ID
## proc updateGenerator*(self: MyGenerator, x: int): bool {.autoExposePointerMethod.} =
##   ## Updates generator state
##   self.state += x  # 'self' is automatically injected as first param
##   return self.state > 100
## ```
##
## WHAT IT GENERATES:
## - Global pointer table: gMyGeneratorPtrTable: Table[int, pointer]
## - Constructor wrapper: creates object, stores pointer, returns int ID
## - Method wrappers: take int ID, lookup pointer, cast to type, call method
## - Cleanup: releaseMyGenerator(id: int) to remove from table and GC_unref
##
## BENEFITS:
## - No manual pointer casting in wrapper code
## - Automatic GC_ref/GC_unref management
## - Type-safe pointer operations
## - Scripts just pass int handles around

import std/[macros, tables, strutils]
import runtime

# Export runtime types needed by generated code
export runtime.Env, runtime.Value, runtime.ValueKind, runtime.valInt, runtime.valFloat,
       runtime.valString, runtime.valBool, runtime.valNil, runtime.registerNative

## Pointer storage
type
  PointerInfo = object
    table: NimNode        # The global Table[int, pointer] variable
    nextId: NimNode       # The global int counter
    typeName: string      # e.g., "DungeonGenerator"

var gPointerTypes {.compileTime.}: Table[string, PointerInfo]

# ==============================================================================
# PLUGIN REGISTRATION QUEUE
# ==============================================================================

type
  PluginRegistration* = proc() {.nimcall.}

var gPluginRegistrations* {.global.}: seq[PluginRegistration] = @[]

proc queuePluginRegistration*(callback: PluginRegistration) =
  ## Queue a registration callback to be called after runtime init
  gPluginRegistrations.add(callback)

proc initPlugins*() =
  ## Call all queued plugin registration callbacks
  ## Must be called AFTER runtime initialization
  for callback in gPluginRegistrations:
    callback()
  gPluginRegistrations.setLen(0)

# ==============================================================================
# TYPE CONVERSION HELPERS
# ==============================================================================

proc getTypeString(typeNode: NimNode): string {.compileTime.} =
  ## Extract type as string, handling various node kinds
  case typeNode.kind
  of nnkIdent, nnkSym:
    return typeNode.strVal
  of nnkVarTy:
    return getTypeString(typeNode[0])
  of nnkBracketExpr:
    # For seq[T], return full type
    return typeNode.repr
  else:
    return typeNode.repr

proc makeValueToNativeConversion(paramName: NimNode, typeNode: NimNode, argIdx: int): NimNode {.compileTime.} =
  ## Generate code to convert Value to native type
  let typeName = getTypeString(typeNode)
  let idx = newLit(argIdx)
  let vkInt = bindSym("vkInt")
  let vkFloat = bindSym("vkFloat")
  let vkString = bindSym("vkString")
  let vkBool = bindSym("vkBool")
  
  case typeName
  of "int":
    return quote do:
      let `paramName` = if args[`idx`].kind == `vkInt`: args[`idx`].i else: 0
  of "float":
    return quote do:
      let `paramName` = if args[`idx`].kind == `vkFloat`: args[`idx`].f elif args[`idx`].kind == `vkInt`: float(args[`idx`].i) else: 0.0
  of "string":
    return quote do:
      let `paramName` = if args[`idx`].kind == `vkString`: args[`idx`].s else: ""
  of "bool":
    return quote do:
      let `paramName` = if args[`idx`].kind == `vkBool`: args[`idx`].b else: false
  else:
    # For custom types, try generic conversion
    return quote do:
      let `paramName` = convertValueToType[`typeNode`](args[`idx`])

proc makeNativeToValueConversion(expr: NimNode, typeNode: NimNode): NimNode {.compileTime.} =
  ## Generate code to convert native type to Value
  if typeNode.kind == nnkEmpty:
    return quote do:
      valNil()
  
  let typeName = getTypeString(typeNode)
  
  case typeName
  of "int":
    return quote do:
      valInt(`expr`)
  of "float":
    return quote do:
      valFloat(`expr`)
  of "string":
    return quote do:
      valString(`expr`)
  of "bool":
    return quote do:
      valBool(`expr`)
  else:
    # Try generic conversion
    return quote do:
      convertTypeToValue(`expr`)

# ==============================================================================
# MACRO IMPLEMENTATIONS
# ==============================================================================

macro autoPointer*(T: typedesc): untyped =
  ## Define pointer management for type T
  ## Example: autoPointer(DungeonGenerator)
  ## Creates:
  ##   - var gDungeonGeneratorPtrTable: Table[int, pointer]
  ##   - var gDungeonGeneratorNextId: int = 1
  ##   - proc releaseDungeonGenerator(id: int) for cleanup
  
  let typeName = $T
  let tableName = ident("g" & typeName & "PtrTable")
  let nextIdName = ident("g" & typeName & "NextId")
  let releaseName = ident("release" & typeName)
  let releaseWrapperName = ident("niminiAuto_" & releaseName.strVal)
  let releaseRegisterName = ident("register_" & releaseName.strVal)
  
  gPointerTypes[typeName] = PointerInfo(
    table: tableName,
    nextId: nextIdName,
    typeName: typeName
  )
  
  let niminiPragma = nnkExprColonExpr.newTree(ident("pragma"), ident("nimini"))
  
  result = newStmtList()
  
  # Add table declarations
  result.add(quote do:
    var `tableName` {.global.}: Table[int, pointer]
    var `nextIdName` {.global.}: int = 1
  )
  
  # Add release function
  result.add(quote do:
    proc `releaseName`*(ptrId: int): bool =
      if `tableName`.hasKey(ptrId):
        let instance = cast[`T`](`tableName`[ptrId])
        GC_unref(instance)
        `tableName`.del(ptrId)
        return true
      return false
  )
  
  # Build nimini wrapper body
  let vkInt = bindSym("vkInt")
  let wrapperBody = newStmtList()
  wrapperBody.add(quote do:
    if args.len < 1 or args[0].kind != `vkInt`:
      return valBool(false)
    let ptrId = args[0].i
    let success = `releaseName`(ptrId)
    return valBool(success)
  )
  
  let wrapperParams = nnkFormalParams.newTree(
    ident("Value"),
    nnkIdentDefs.newTree(ident("env"), nnkRefTy.newTree(ident("Env")), newEmptyNode()),
    nnkIdentDefs.newTree(ident("args"), nnkBracketExpr.newTree(ident("seq"), ident("Value")), newEmptyNode())
  )
  
  let wrapperProc = nnkProcDef.newTree(
    releaseWrapperName,
    newEmptyNode(),  # term rewriting template
    newEmptyNode(),  # generic params
    wrapperParams,
    newEmptyNode(),  # pragmas (skip nimini, it's just a marker)
    newEmptyNode(),  # reserved
    wrapperBody
  )
  
  result.add(wrapperProc)
  
  # Add registration proc
  result.add(quote do:
    proc `releaseRegisterName`*() =
      registerNative(`releaseName`.astToStr, `releaseWrapperName`,
        description = "Release " & `typeName` & " pointer")
  )
  
  # Queue auto-registration at module load time
  result.add(quote do:
    queuePluginRegistration(`releaseRegisterName`)
  )

macro autoExposePointer*(procDef: untyped): untyped =
  ## Auto-expose a constructor returning a ref object
  ## Returns int pointer ID to nimini scripts
  
  expectKind(procDef, nnkProcDef)
  
  # Handle both regular and exported proc names
  let procNameNode = procDef.name
  let procName = if procNameNode.kind == nnkPostfix:
    procNameNode[1].strVal
  else:
    procNameNode.strVal
  
  let returnType = procDef.params[0]
  
  if returnType.kind == nnkEmpty:
    error("autoExposePointer requires a return type", procDef)
  
  let typeName = getTypeString(returnType)
  
  if typeName notin gPointerTypes:
    error("Type " & typeName & " not registered. Use autoPointer(" & typeName & ") first", procDef)
  
  let ptrInfo = gPointerTypes[typeName]
  let ptrTable = ptrInfo.table
  let nextIdVar = ptrInfo.nextId
  
  let wrapperName = ident("niminiAuto_" & procName)
  let registerName = ident("register_" & procName)
  let procIdent = ident(procName)
  
  # Build parameter conversion
  var conversions = newStmtList()
  var callArgs: seq[NimNode] = @[]
  
  var argIdx = 0
  for i in 1 ..< procDef.params.len:
    let paramDef = procDef.params[i]
    if paramDef.kind == nnkIdentDefs:
      let paramType = paramDef[^2]
      
      # Handle multiple params with same type
      for j in 0 ..< paramDef.len - 2:
        let paramName = paramDef[j]
        let conv = makeValueToNativeConversion(paramName, paramType, argIdx)
        conversions.add(conv)
        callArgs.add(paramName)
        argIdx += 1
  
  # Build the call expression
  let callExpr = if callArgs.len > 0:
    newCall(procIdent, callArgs)
  else:
    newCall(procIdent)
  
  # Generate wrapper body
  let wrapperBody = quote do:
    `conversions`
    let instance = `callExpr`
    let ptrId = `nextIdVar`
    `nextIdVar` += 1
    `ptrTable`[ptrId] = cast[pointer](instance)
    GC_ref(instance)
    return valInt(ptrId)
  
  # Build wrapper proc with proper nimini pragma
  let wrapperParams = nnkFormalParams.newTree(
    ident("Value"),
    nnkIdentDefs.newTree(ident("env"), nnkRefTy.newTree(ident("Env")), newEmptyNode()),
    nnkIdentDefs.newTree(ident("args"), nnkBracketExpr.newTree(ident("seq"), ident("Value")), newEmptyNode())
  )
  
  let wrapperProc = nnkProcDef.newTree(
    nnkPostfix.newTree(ident("*"), wrapperName),
    newEmptyNode(),
    newEmptyNode(),
    wrapperParams,
    newEmptyNode(),  # pragmas (skip nimini)
    newEmptyNode(),
    wrapperBody
  )
  
  result = newStmtList()
  result.add(procDef)
  result.add(wrapperProc)
  
  # Add registration proc
  result.add(quote do:
    proc `registerName`*() =
      registerNative(`procName`, `wrapperName`,
        description = "Create " & `typeName` & " (returns pointer ID)")
  )
  
  # Queue auto-registration at module load time
  result.add(quote do:
    queuePluginRegistration(`registerName`)
  )

macro autoExposePointerMethod*(procDef: untyped): untyped =
  ## Auto-expose a method operating on a pointer handle
  ## First parameter must be the self type (e.g., self: DungeonGenerator)
  ##
  ## Example:
  ## proc dungeonUpdate*(self: DungeonGenerator): bool {.autoExposePointerMethod.} =
  ##   self.step()
  ##   return self.isComplete
  
  expectKind(procDef, nnkProcDef)
  
  # Get proc name
  let procNameNode = procDef.name
  let procName = if procNameNode.kind == nnkPostfix:
    procNameNode[1].strVal
  else:
    procNameNode.strVal
  
  # First param must be the self type
  if procDef.params.len < 2:
    error("autoExposePointerMethod requires at least one parameter (self: Type)", procDef)
  
  let firstParam = procDef.params[1]
  if firstParam.kind != nnkIdentDefs or firstParam.len < 2:
    error("First parameter must be typed (e.g., self: MyType)", procDef)
  
  let selfName = firstParam[0]
  let selfType = firstParam[^2]
  let typeName = getTypeString(selfType)
  
  if typeName notin gPointerTypes:
    error("Type " & typeName & " not registered. Use autoPointer(" & typeName & ") first", procDef)
  
  let ptrInfo = gPointerTypes[typeName]
  let ptrTable = ptrInfo.table
  
  let wrapperName = ident("niminiAuto_" & procName)
  let registerName = ident("register_" & procName)
  let procIdent = ident(procName)
  let typeIdent = ident(typeName)
  
  # Generate parameter conversions (skip first param, that's the pointer ID)
  var conversions = newStmtList()
  var callArgs: seq[NimNode] = @[selfName]  # First arg is self
  
  let vkInt = bindSym("vkInt")
  
  var argIdx = 1  # Start at 1, args[0] is the pointer ID
  for i in 2 ..< procDef.params.len:  # Start at 2 to skip self param
    let paramDef = procDef.params[i]
    if paramDef.kind == nnkIdentDefs:
      let paramType = paramDef[^2]
      
      for j in 0 ..< paramDef.len - 2:
        let paramName = paramDef[j]
        let conv = makeValueToNativeConversion(paramName, paramType, argIdx)
        conversions.add(conv)
        callArgs.add(paramName)
        argIdx += 1
  
  # Build the call expression
  let callExpr = newCall(procIdent, callArgs)
  
  # Generate return conversion
  let returnType = procDef.params[0]
  let returnStmt = if returnType.kind != nnkEmpty:
    let tempResult = ident("result")
    let returnConv = makeNativeToValueConversion(tempResult, returnType)
    quote do:
      let `tempResult` = `callExpr`
      return `returnConv`
  else:
    quote do:
      `callExpr`
      return valNil()
  
  # Generate wrapper
  let wrapperBody = quote do:
    if args.len < 1 or args[0].kind != `vkInt`:
      return valNil()
    
    let ptrId = args[0].i
    if not `ptrTable`.hasKey(ptrId):
      return valNil()
    
    let `selfName` = cast[`typeIdent`](`ptrTable`[ptrId])
    `conversions`
    `returnStmt`
  
  # Build wrapper proc with proper nimini pragma
  let wrapperParams = nnkFormalParams.newTree(
    ident("Value"),
    nnkIdentDefs.newTree(ident("env"), nnkRefTy.newTree(ident("Env")), newEmptyNode()),
    nnkIdentDefs.newTree(ident("args"), nnkBracketExpr.newTree(ident("seq"), ident("Value")), newEmptyNode())
  )
  
  let wrapperProc = nnkProcDef.newTree(
    nnkPostfix.newTree(ident("*"), wrapperName),
    newEmptyNode(),
    newEmptyNode(),
    wrapperParams,
    newEmptyNode(),  # pragmas (skip nimini)
    newEmptyNode(),
    wrapperBody
  )
  
  result = newStmtList()
  result.add(procDef)
  result.add(wrapperProc)
  
  # Add registration proc
  result.add(quote do:
    proc `registerName`*() =
      registerNative(`procName`, `wrapperName`,
        description = `procName` & " on " & `typeName`)
  )
  
  # Queue auto-registration at module load time
  result.add(quote do:
    queuePluginRegistration(`registerName`)
  )

# ==============================================================================
# FALLBACK TYPE CONVERTERS (for custom types not in type_converters.nim)
# ==============================================================================

proc convertValueToType*[T](v: Value): T =
  ## Generic fallback converter - extend as needed
  when T is int:
    return if v.kind == vkInt: v.i else: 0
  elif T is float:
    return if v.kind == vkFloat: v.f elif v.kind == vkInt: float(v.i) else: 0.0
  elif T is string:
    return if v.kind == vkString: v.s else: ""
  elif T is bool:
    return if v.kind == vkBool: v.b else: false
  else:
    {.error: "Unsupported type for convertValueToType: " & $T & ". Add converter to type_converters.nim".}

proc convertTypeToValue*[T](x: T): Value =
  ## Generic fallback converter - extend as needed
  when T is int:
    return valInt(x)
  elif T is float:
    return valFloat(x)
  elif T is string:
    return valString(x)
  elif T is bool:
    return valBool(x)
  else:
    {.error: "Unsupported type for convertTypeToValue: " & $T & ". Add converter to type_converters.nim".}

# ==============================================================================
# AUTO-REGISTRATION HELPER
# ==============================================================================

macro autoRegisterPointer*(body: untyped): untyped =
  ## Convenience macro to auto-call all register_* functions in scope.
  ## Usage in *_bindings.nim:
  ## ```nim
  ## proc registerMyBindings*() =
  ##   autoRegisterPointer:
  ##     newMyType
  ##     myMethod1
  ##     myMethod2
  ##     releaseMyType
  ## ```
  ## This expands to calling register_newMyType(), register_myMethod1(), etc.
  result = newStmtList()
  for statement in body:
    var funcName: string
    case statement.kind
    of nnkIdent, nnkSym:
      funcName = statement.strVal
    of nnkCall:
      if statement[0].kind in {nnkIdent, nnkSym}:
        funcName = statement[0].strVal
      else:
        continue
    else:
      continue
    
    let registerFunc = ident("register_" & funcName)
    result.add(newCall(registerFunc))
