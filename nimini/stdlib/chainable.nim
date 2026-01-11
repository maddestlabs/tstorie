## Chainable functions for UFCS (Uniform Function Call Syntax) support
## These functions are designed to work with method chaining:
##   arr.filter(pred).map(transform).sorted()

import std/[algorithm, sequtils, tables, strutils]
import ../runtime
import ../ast

# Helper to call a function value with arguments
# Now uses properly exported ExecResult and helper functions
proc callFunction(fn: Value; args: seq[Value]; env: ref Env): Value =
  if fn.kind != vkFunction:
    quit "Expected a function"
  
  if fn.fnVal.isNative:
    return fn.fnVal.native(env, args)
  else:
    # Create new environment for function call (mimics runtime.nim)
    var callEnv = new(Env)
    callEnv.parent = env
    callEnv.vars = initTable[string, Value]()
    callEnv.deferStack = @[]
    
    # Bind parameters
    for i, param in fn.fnVal.params:
      if i < args.len:
        defineVar(callEnv, param, args[i])
      else:
        defineVar(callEnv, param, valNil())
    
    # Initialize 'result' variable if function has a return type
    if fn.fnVal.returnType != nil:
      defineVar(callEnv, "result", Value(kind: vkMap, map: initTable[string, Value]()))
    
    # Execute body, propagate return
    var returnValue = valNil()
    var hasReturnValue = false
    
    for st in fn.fnVal.stmts:
      let res = execStmt(st, callEnv)
      if res.hasReturn():
        returnValue = res.value
        hasReturnValue = true
        break
    
    if hasReturnValue:
      return returnValue
    
    # If no explicit return but function has return type, return result variable
    if fn.fnVal.returnType != nil:
      return getVar(callEnv, "result")
    
    return valNil()

# ============================================================================
# Array/Sequence Chainable Operations
# ============================================================================

proc nimini_filterArr*(env: ref Env; args: seq[Value]): Value =
  ## Filter array elements using a predicate function
  ## Usage: arr.filterArr(lambda x: x > 5)
  if args.len != 2:
    quit "filterArr requires 2 arguments (array, predicate)"
  
  let arr = args[0]
  let predicate = args[1]
  
  if arr.kind != vkArray:
    quit "filter requires an array as first argument"
  
  if predicate.kind != vkFunction:
    quit "filter requires a function as second argument"
  
  var result: seq[Value] = @[]
  for elem in arr.arr:
    let predicateResult = callFunction(predicate, @[elem], env)
    if toBool(predicateResult):
      result.add(elem)
  
  return valArray(result)

proc nimini_mapArr*(env: ref Env; args: seq[Value]): Value =
  ## Map array elements using a transform function
  ## Usage: arr.map(lambda x: x * 2)
  if args.len != 2:
    quit "map requires 2 arguments (array, transform)"
  
  let arr = args[0]
  let transform = args[1]
  
  if arr.kind != vkArray:
    quit "map requires an array as first argument"
  
  if transform.kind != vkFunction:
    quit "map requires a function as second argument"
  
  var result: seq[Value] = @[]
  for elem in arr.arr:
    let transformed = callFunction(transform, @[elem], env)
    result.add(transformed)
  
  return valArray(result)

proc nimini_sortedArr*(env: ref Env; args: seq[Value]): Value =
  ## Sort array and return it (for chaining)
  ## Usage: arr.sorted()
  if args.len != 1:
    quit "sorted requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "sorted requires an array"
  
  var sorted = arr.arr
  sorted.sort(proc (a, b: Value): int =
    let aVal = toFloat(a)
    let bVal = toFloat(b)
    if aVal < bVal: -1
    elif aVal > bVal: 1
    else: 0
  )
  
  return valArray(sorted)

proc nimini_reversedArr*(env: ref Env; args: seq[Value]): Value =
  ## Reverse array and return it (for chaining)
  ## Usage: arr.reversed()
  if args.len != 1:
    quit "reversed requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "reversed requires an array"
  
  var reversed = arr.arr
  reversed.reverse()
  
  return valArray(reversed)

proc nimini_takeArr*(env: ref Env; args: seq[Value]): Value =
  ## Take first N elements from array
  ## Usage: arr.take(5)
  if args.len != 2:
    quit "take requires 2 arguments (array, count)"
  
  let arr = args[0]
  let count = toInt(args[1])
  
  if arr.kind != vkArray:
    quit "take requires an array"
  
  let n = min(count, arr.arr.len)
  return valArray(arr.arr[0..<n])

proc nimini_dropArr*(env: ref Env; args: seq[Value]): Value =
  ## Drop first N elements from array
  ## Usage: arr.drop(2)
  if args.len != 2:
    quit "drop requires 2 arguments (array, count)"
  
  let arr = args[0]
  let count = toInt(args[1])
  
  if arr.kind != vkArray:
    quit "drop requires an array"
  
  if count >= arr.arr.len:
    return valArray(@[])
  
  return valArray(arr.arr[count..<arr.arr.len])

proc nimini_sumArr*(env: ref Env; args: seq[Value]): Value =
  ## Sum all elements in an array
  ## Usage: arr.sum()
  if args.len != 1:
    quit "sum requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "sum requires an array"
  
  var total = 0.0
  for elem in arr.arr:
    total += toFloat(elem)
  
  return valFloat(total)

proc nimini_firstArr*(env: ref Env; args: seq[Value]): Value =
  ## Get first element of array
  ## Usage: arr.first()
  if args.len != 1:
    quit "first requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "first requires an array"
  
  if arr.arr.len == 0:
    return valNil()
  
  return arr.arr[0]

proc nimini_lastArr*(env: ref Env; args: seq[Value]): Value =
  ## Get last element of array
  ## Usage: arr.last()
  if args.len != 1:
    quit "last requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "last requires an array"
  
  if arr.arr.len == 0:
    return valNil()
  
  return arr.arr[^1]

proc nimini_uniqueArr*(env: ref Env; args: seq[Value]): Value =
  ## Remove duplicate elements from array
  ## Usage: arr.unique()
  if args.len != 1:
    quit "unique requires 1 argument (array)"
  
  let arr = args[0]
  
  if arr.kind != vkArray:
    quit "unique requires an array"
  
  var seen: seq[Value] = @[]
  var result: seq[Value] = @[]
  
  for elem in arr.arr:
    var found = false
    for s in seen:
      # Simple equality check
      if elem.kind == s.kind:
        case elem.kind
        of vkInt:
          if elem.i == s.i:
            found = true
            break
        of vkFloat:
          if elem.f == s.f:
            found = true
            break
        of vkString:
          if elem.s == s.s:
            found = true
            break
        of vkBool:
          if elem.b == s.b:
            found = true
            break
        else:
          discard
    
    if not found:
      seen.add(elem)
      result.add(elem)
  
  return valArray(result)

proc nimini_countArr*(env: ref Env; args: seq[Value]): Value =
  ## Count elements in array matching predicate
  ## Usage: arr.count(lambda x: x > 5)
  if args.len != 2:
    quit "count requires 2 arguments (array, predicate)"
  
  let arr = args[0]
  let predicate = args[1]
  
  if arr.kind != vkArray:
    quit "count requires an array as first argument"
  
  if predicate.kind != vkFunction:
    quit "count requires a function as second argument"
  
  var counter = 0
  for elem in arr.arr:
    let predicateResult = callFunction(predicate, @[elem], env)
    if toBool(predicateResult):
      inc counter
  
  return valInt(counter)

proc nimini_anyArr*(env: ref Env; args: seq[Value]): Value =
  ## Check if any element matches predicate
  ## Usage: arr.any(lambda x: x > 10)
  if args.len != 2:
    quit "any requires 2 arguments (array, predicate)"
  
  let arr = args[0]
  let predicate = args[1]
  
  if arr.kind != vkArray:
    quit "any requires an array as first argument"
  
  if predicate.kind != vkFunction:
    quit "any requires a function as second argument"
  
  for elem in arr.arr:
    let predicateResult = callFunction(predicate, @[elem], env)
    if toBool(predicateResult):
      return valBool(true)
  
  return valBool(false)

proc nimini_allArr*(env: ref Env; args: seq[Value]): Value =
  ## Check if all elements match predicate
  ## Usage: arr.all(lambda x: x > 0)
  if args.len != 2:
    quit "all requires 2 arguments (array, predicate)"
  
  let arr = args[0]
  let predicate = args[1]
  
  if arr.kind != vkArray:
    quit "all requires an array as first argument"
  
  if predicate.kind != vkFunction:
    quit "all requires a function as second argument"
  
  for elem in arr.arr:
    let predicateResult = callFunction(predicate, @[elem], env)
    if not toBool(predicateResult):
      return valBool(false)
  
  return valBool(true)

# ============================================================================
# String Chainable Operations
# ============================================================================

proc nimini_trimStr*(env: ref Env; args: seq[Value]): Value =
  ## Trim whitespace from string
  ## Usage: str.trim()
  if args.len != 1:
    quit "trim requires 1 argument (string)"
  
  let str = $args[0]  # Convert to string using $
  return valString(str.strip())

proc nimini_concatStr*(env: ref Env; args: seq[Value]): Value =
  ## Concatenate two strings (chainable)
  ## Usage: str.concat(" world")
  if args.len != 2:
    quit "concat requires 2 arguments (string, string)"
  
  let str1 = $args[0]
  let str2 = $args[1]
  return valString(str1 & str2)
