## Auto-Registry System for Nimini
##
## Provides infrastructure to auto-expose ref object methods using a registry pattern.
## This eliminates the need for manual wrapper code in *_bindings.nim files.
##
## USAGE EXAMPLE:
## ```nim
## # In lib/mymodule.nim
## import ../nimini/auto_registry
##
## type MyObject* = ref object
##   data: string
##   count: int
##
## # Define the registry
## autoRegistry(MyObject, "myobject")
##
## # Auto-expose constructor - returns string ID
## proc createMyObject*(initialData: string): MyObject {.autoExposeRegistry: "myobject".} =
##   result = MyObject(data: initialData, count: 0)
##
## # Auto-expose method - takes MyObject as first param
## proc updateData*(self: MyObject, data: string) {.autoExposeRegistryMethod: "myobject".} =
##   ## Updates the object's data
##   self.data = data
##   self.count += 1
##
## # Auto-expose getter
## proc getData*(self: MyObject): string {.autoExposeRegistryMethod: "myobject".} =
##   return self.data
## ```
##
## WHAT IT GENERATES:
## - Global registry table: gMyObjectRegistry: Table[string, MyObject]
## - Constructor wrapper: creates object, assigns ID, stores in registry, returns ID string
## - Method wrappers: take ID string, lookup instance, call method on instance
## - Cleanup: removeMyObject(id: string) to remove from registry
##
## BENEFITS:
## - Write module code naturally with methods
## - No manual *_bindings.nim code needed
## - Registry management is automatic
## - String IDs make scripts simple: "particle_rain", "editor_1", etc.

import std/[macros, tables, strutils]
import runtime

# Export runtime types needed by generated code
export runtime.Env, runtime.Value, runtime.ValueKind, runtime.valInt, runtime.valFloat,
       runtime.valString, runtime.valBool, runtime.valNil, runtime.registerNative

# Import plugin registration queue (defined once in auto_pointer)
type PluginRegistration* = proc() {.nimcall.}
when not declared(gPluginRegistrations):
  var gPluginRegistrations* {.global.}: seq[PluginRegistration] = @[]
when not declared(queuePluginRegistration):
  proc queuePluginRegistration*(callback: PluginRegistration) =
    gPluginRegistrations.add(callback)

## Registry storage and ID generation
type
  RegistryInfo = object
    table: NimNode        # The global Table[string, T] variable
    nextId: NimNode       # The global int counter
    typeName: string      # e.g., "ParticleSystem"
    prefix: string        # e.g., "particle" for IDs like "particle_0"

var gRegistries {.compileTime.}: Table[string, RegistryInfo]

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
    return quote do:
      convertTypeToValue(`expr`)

# ==============================================================================
# MACRO IMPLEMENTATIONS
# ==============================================================================

macro autoRegistry*(T: typedesc, prefix: static[string]): untyped =
  ## Define a registry for type T with ID prefix
  ## Example: autoRegistry(ParticleSystem, "particle")
  ## Creates:
  ##   - var gParticleSystemRegistry: Table[string, ParticleSystem]
  ##   - var gParticleSystemNextId: int = 0
  ##   - proc removeParticleSystem(id: string) for cleanup
  
  let typeName = $T
  let registryName = ident("g" & typeName & "Registry")
  let nextIdName = ident("g" & typeName & "NextId")
  let removeName = ident("remove" & typeName)
  let removeWrapperName = ident("niminiAuto_" & removeName.strVal)
  let removeRegisterName = ident("register_" & removeName.strVal)
  
  # Store registry info for later use by autoExposeRegistry macros
  gRegistries[typeName] = RegistryInfo(
    table: registryName,
    nextId: nextIdName,
    typeName: typeName,
    prefix: prefix
  )
  
  result = newStmtList()
  
  # Add table declarations
  result.add(quote do:
    var `registryName` {.global.}: Table[string, `T`]
    var `nextIdName` {.global.}: int = 0
  )
  
  # Add remove function
  result.add(quote do:
    proc `removeName`*(id: string): bool =
      if `registryName`.hasKey(id):
        let instance = `registryName`[id]
        GC_unref(instance)
        `registryName`.del(id)
        return true
      return false
  )
  
  # Build nimini wrapper body
  let vkString = bindSym("vkString")
  let wrapperBody = newStmtList()
  wrapperBody.add(quote do:
    if args.len < 1 or args[0].kind != `vkString`:
      return valBool(false)
    let id = args[0].s
    let success = `removeName`(id)
    return valBool(success)
  )
  
  let wrapperParams = nnkFormalParams.newTree(
    ident("Value"),
    nnkIdentDefs.newTree(ident("env"), nnkRefTy.newTree(ident("Env")), newEmptyNode()),
    nnkIdentDefs.newTree(ident("args"), nnkBracketExpr.newTree(ident("seq"), ident("Value")), newEmptyNode())
  )
  
  let wrapperProc = nnkProcDef.newTree(
    removeWrapperName,
    newEmptyNode(),
    newEmptyNode(),
    wrapperParams,
    newEmptyNode(),  # pragmas (skip nimini)
    newEmptyNode(),
    wrapperBody
  )
  
  result.add(wrapperProc)
  
  # Add registration proc
  result.add(quote do:
    proc `removeRegisterName`*() =
      registerNative(`removeName`.astToStr, `removeWrapperName`,
        description = "Remove " & `typeName` & " from registry")
  )
  
  # Queue auto-registration
  result.add(quote do:
    queuePluginRegistration(`removeRegisterName`)
  )

macro autoExposeRegistry*(libName: static[string], procDef: untyped): untyped =
  ## Auto-expose a constructor that returns a ref object
  ## Generates:
  ## - Original proc returning ref object
  ## - niminiAuto wrapper that creates object, stores in registry, returns ID string
  ## - register_* function to register the wrapper
  ##
  ## The original proc must return a ref object type that has been registered
  ## with autoRegistry()
  
  expectKind(procDef, nnkProcDef)
  
  # Handle both regular and exported proc names
  let procNameNode = procDef.name
  let procName = if procNameNode.kind == nnkPostfix:
    procNameNode[1].strVal
  else:
    procNameNode.strVal
  
  let returnType = procDef.params[0]
  
  if returnType.kind == nnkEmpty:
    error("autoExposeRegistry requires a return type", procDef)
  
  let typeName = getTypeString(returnType)
  
  if typeName notin gRegistries:
    error("Type " & typeName & " not registered. Use autoRegistry(" & typeName & ", \"prefix\") first", procDef)
  
  let regInfo = gRegistries[typeName]
  let registryTable = regInfo.table
  let nextIdVar = regInfo.nextId
  let prefix = regInfo.prefix
  
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
    let id = `prefix` & "_" & $`nextIdVar`
    `nextIdVar` += 1
    `registryTable`[id] = instance
    GC_ref(instance)
    return valString(id)
  
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
        storieLibs = @[`libName`],
        description = "Create " & `typeName` & " (returns registry ID)")
  )
  
  # Queue auto-registration
  result.add(quote do:
    queuePluginRegistration(`registerName`)
  )

macro autoExposeRegistryMethod*(libName: static[string], procDef: untyped): untyped =
  ## Auto-expose a method that operates on a registry instance
  ## First parameter must be the self type (e.g., self: MyObject)
  ## The generated wrapper takes string ID, looks up instance, and calls method
  ##
  ## Example:
  ## proc updateData*(self: MyObject, data: string) {.autoExposeRegistryMethod: "mylib".} =
  ##   self.data = data
  
  expectKind(procDef, nnkProcDef)
  
  # Get proc name
  let procNameNode = procDef.name
  let procName = if procNameNode.kind == nnkPostfix:
    procNameNode[1].strVal
  else:
    procNameNode.strVal
  
  # First param must be the self type
  if procDef.params.len < 2:
    error("autoExposeRegistryMethod requires at least one parameter (self: Type)", procDef)
  
  let firstParam = procDef.params[1]
  if firstParam.kind != nnkIdentDefs or firstParam.len < 2:
    error("First parameter must be typed (e.g., self: MyType)", procDef)
  
  let selfName = firstParam[0]
  let selfType = firstParam[^2]
  let typeName = getTypeString(selfType)
  
  if typeName notin gRegistries:
    error("Type " & typeName & " not registered. Use autoRegistry(" & typeName & ", \"prefix\") first", procDef)
  
  let regInfo = gRegistries[typeName]
  let registryTable = regInfo.table
  
  let wrapperName = ident("niminiAuto_" & procName)
  let registerName = ident("register_" & procName)
  let procIdent = ident(procName)
  let typeIdent = ident(typeName)
  
  # Generate parameter conversions (args[0] is the ID string, then actual params)
  var conversions = newStmtList()
  var callArgs: seq[NimNode] = @[selfName]  # First arg is self
  
  let vkString = bindSym("vkString")
  
  var argIdx = 1  # Start at 1, args[0] is the ID string
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
    if args.len < 1 or args[0].kind != `vkString`:
      return valNil()
    
    let id = args[0].s
    if not `registryTable`.hasKey(id):
      return valNil()
    
    let `selfName` = `registryTable`[id]
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
        storieLibs = @[`libName`],
        description = `procName` & " on " & `typeName`)
  )
  
  # Queue auto-registration
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
