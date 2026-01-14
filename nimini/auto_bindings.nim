## Automatic Nimini Bindings System
##
## Provides macros to auto-generate nimini wrappers from native functions
##
## Usage:
##   import nimini/auto_bindings
##   
##   proc myFunc*(arg1: int, arg2: string): bool {.autoExpose: "myLib".} =
##     ## Function description
##     result = true
##
## This generates a wrapper and registers it automatically

import std/[macros, strutils]
import runtime
import type_converters

# Re-export types needed by generated code
export runtime.Env, runtime.Value, runtime.valInt, runtime.valFloat, 
       runtime.valString, runtime.valBool, runtime.valNil, runtime.registerNative
# Re-export type converters for use by modules
export type_converters

# Import plugin registration queue (defined once in auto_pointer)
type PluginRegistration* = proc() {.nimcall.}
when not declared(gPluginRegistrations):
  var gPluginRegistrations* {.global.}: seq[PluginRegistration] = @[]
when not declared(queuePluginRegistration):
  proc queuePluginRegistration*(callback: PluginRegistration) =
    gPluginRegistrations.add(callback)

# ==============================================================================
# HELPER PROCS FOR VALUE CONVERSION
# ==============================================================================

proc niminiConvertToInt*(v: Value): int {.inline.} =
  case v.kind
  of vkInt: v.i
  of vkFloat: int(v.f)
  else: 0

proc niminiConvertToFloat*(v: Value): float {.inline.} =
  case v.kind
  of vkFloat: v.f
  of vkInt: float(v.i)
  else: 0.0

proc niminiConvertToString*(v: Value): string {.inline.} =
  if v.kind == vkString: v.s else: ""

proc niminiConvertToBool*(v: Value): bool {.inline.} =
  if v.kind == vkBool: v.b else: false

# ==============================================================================
# MACRO IMPLEMENTATION
# ==============================================================================

proc extractDocComment(node: NimNode): string {.compileTime.} =
  ## Extract documentation comment from proc
  for child in node:
    if child.kind == nnkCommentStmt:
      result = child.strVal
      if result.startsWith("##"):
        result = result[2..^1].strip()
      elif result.startsWith("#"):
        result = result[1..^1].strip()
      return
  return ""

proc getTypeIdent(typeNode: NimNode): string {.compileTime.} =
  case typeNode.kind
  of nnkIdent, nnkSym:
    return typeNode.strVal
  of nnkVarTy:
    return getTypeIdent(typeNode[0])
  of nnkBracketExpr:
    # For seq[T], get the outer type
    return getTypeIdent(typeNode[0])
  else:
    return typeNode.repr

proc makeConverter(argName: NimNode, typeName: string, valueExpr: NimNode): NimNode {.compileTime.} =
  ## Generate conversion code from Value to native type
  case typeName
  of "int":
    return quote do:
      niminiConvertToInt(`valueExpr`)
  of "float":
    return quote do:
      niminiConvertToFloat(`valueExpr`)
  of "string":
    return quote do:
      niminiConvertToString(`valueExpr`)
  of "bool":
    return quote do:
      niminiConvertToBool(`valueExpr`)
  of "Style":
    return quote do:
      valueToStyle(`valueExpr`)
  of "Color":
    return quote do:
      valueToColor(`valueExpr`)
  of "seq":
    # seq[int], seq[string], seq[float] - need full type info
    return quote do:
      valueToSeqInt(`valueExpr`)  # Default to int, will enhance later
  else:
    error("Unsupported type for auto-binding: " & typeName & ". Add converter to type_converters.nim")
    return valueExpr

proc makeReturnConverter(expr: NimNode, returnType: NimNode): NimNode {.compileTime.} =
  ## Generate conversion from native type to Value
  if returnType.kind == nnkEmpty:
    return quote do:
      `expr`
      valNil()
  
  let typeName = getTypeIdent(returnType)
  let typeRepr = returnType.repr  # Full type representation
  
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
  of "Style":
    return quote do:
      styleToValue(`expr`)
  of "Color":
    return quote do:
      colorToValue(`expr`)
  of "seq":
    # Check full type for seq element type
    if "tuple" in typeRepr:
      return quote do:
        seqTupleXYToValue(`expr`)
    elif "string" in typeRepr or typeRepr.contains("seq[string]"):
      return quote do:
        seqStringToValue(`expr`)
    elif "float" in typeRepr or typeRepr.contains("seq[float]"):
      return quote do:
        seqFloatToValue(`expr`)
    else:
      # Default to int for seq[int] or unknown seq types
      return quote do:
        seqIntToValue(`expr`)
  of "tuple":
    # Check for width/height vs x/y tuple
    if "width" in typeRepr and "height" in typeRepr:
      return quote do:
        tupleWidthHeightToValue(`expr`)
    else:
      # Default to x/y tuple
      return quote do:
        tupleXYToValue(`expr`)
  else:
    # Check if it's a tuple type by representation
    if typeRepr.startsWith("tuple["):
      # Check for width/height pattern
      if "width" in typeRepr and "height" in typeRepr:
        return quote do:
          tupleWidthHeightToValue(`expr`)
      else:
        return quote do:
          tupleXYToValue(`expr`)
    warning("Unsupported return type: " & typeRepr & ", returning nil. Add converter to type_converters.nim")
    return quote do:
      `expr`
      valNil()

macro autoExpose*(libName: string, procDef: untyped): untyped =
  ## Auto-generate nimini wrapper and registration for a proc
  expectKind(procDef, nnkProcDef)
  
  let originalName = procDef[0]
  let originalNameStr = if originalName.kind == nnkPostfix:
    originalName[1].strVal  # Handle exported procs (proc name*)
  else:
    originalName.strVal
  
  let baseIdent = if originalName.kind == nnkPostfix:
    originalName[1]
  else:
    originalName
  
  let wrapperName = ident("niminiAuto_" & originalNameStr)
  let params = procDef[3]
  let returnType = params[0]
  let doc = extractDocComment(procDef)
  
  # Generate argument conversions
  var argConversions = newStmtList()
  var callArgs: seq[NimNode] = @[]
  var argIdx = 0
  
  for i in 1 ..< params.len:
    let paramDef = params[i]
    if paramDef.kind == nnkIdentDefs:
      let argType = paramDef[^2]  # Type is second-to-last
      let typeName = getTypeIdent(argType)
      
      # Handle multiple params with same type: boxX, boxWidth: int
      for j in 0 ..< paramDef.len - 2:
        let argName = paramDef[j]
        
        let valueAccess = quote do:
          args[`argIdx`]
        
        let convertExpr = makeConverter(argName, typeName, valueAccess)
        
        argConversions.add(quote do:
          let `argName` = `convertExpr`
        )
        callArgs.add(argName)
        argIdx += 1
  
  # Generate function call using base ident (not Postfix)
  let funcCall = if callArgs.len > 0:
    newCall(baseIdent, callArgs)
  else:
    newCall(baseIdent)
  
  let returnConversion = makeReturnConverter(funcCall, returnType)
  
  # Build wrapper proc manually with proper structure
  let envParam = nnkIdentDefs.newTree(
    ident("env"),
    nnkRefTy.newTree(ident("Env")),
    newEmptyNode()
  )
  let argsParam = nnkIdentDefs.newTree(
    ident("args"),
    nnkBracketExpr.newTree(ident("seq"), ident("Value")),
    newEmptyNode()
  )
  let wrapperParams = nnkFormalParams.newTree(
    ident("Value"),
    envParam,
    argsParam
  )
  let wrapperBody = newStmtList(
    argConversions,
    nnkReturnStmt.newTree(returnConversion)
  )
  
  let wrapper = nnkProcDef.newTree(
    nnkPostfix.newTree(ident("*"), wrapperName),
    newEmptyNode(),  # term rewriting template
    newEmptyNode(),  # generic params
    wrapperParams,   # formal params
    newEmptyNode(),  # pragmas
    newEmptyNode(),  # reserved
    wrapperBody      # body
  )
  
  # Generate registration - but wrap it in a proc we can call later
  let registerProcName = ident("register_" & originalNameStr)
  let registration = quote do:
    proc `registerProcName`*() =
      registerNative(`originalNameStr`, `wrapperName`, 
        storieLibs = @[`libName`], 
        description = `doc`)
  
  result = newStmtList()
  result.add(procDef)
  result.add(wrapper)
  result.add(registration)
  
  # Queue auto-registration at module load time
  result.add(quote do:
    queuePluginRegistration(`registerProcName`)
  )

# ==============================================================================
# CONVENIENCE TEMPLATE
# ==============================================================================

template exposeProc*(lib: string, body: untyped): untyped =
  ## Template wrapper for easier syntax
  autoExpose(lib, body)

