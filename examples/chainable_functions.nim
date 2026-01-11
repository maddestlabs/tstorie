## Example: Adding Chainable Functions to Nimini Stdlib

import std/[algorithm, sequtils, strutils]
import ../nimini/runtime
import ../nimini/plugin

# ============================================================================
# Chainable Array/Sequence Functions
# ============================================================================

proc nimini_filter*(env: ref Env; args: seq[Value]): Value =
  ## Filter array elements using a predicate function
  ## Usage: arr.filter(lambda x: x > 5)
  if args.len != 2:
    quit "filter requires 2 arguments (array, predicate)"
  
  let arr = args[0]
  let predicate = args[1]
  
  if arr.kind != vkArray:
    quit "filter requires an array as first argument"
  
  if predicate.kind != vkFunction:
    quit "filter requires a function as second argument"
  
  var result: seq[Value] = @[]
  for elem in arr.arr:
    let predicateResult = evalCall("", @[elem], env, predicate.fnVal)
    if toBool(predicateResult):
      result.add(elem)
  
  return valArray(result)

proc nimini_map*(env: ref Env; args: seq[Value]): Value =
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
    let transformed = evalCall("", @[elem], env, transform.fnVal)
    result.add(transformed)
  
  return valArray(result)

proc nimini_filter_int*(env: ref Env; args: seq[Value]): Value =
  ## Filter array elements using an integer threshold
  ## Usage: arr.filterGreaterThan(5)
  if args.len != 2:
    quit "filterGreaterThan requires 2 arguments (array, threshold)"
  
  let arr = args[0]
  let threshold = toInt(args[1])
  
  if arr.kind != vkArray:
    quit "filterGreaterThan requires an array as first argument"
  
  var result: seq[Value] = @[]
  for elem in arr.arr:
    if toInt(elem) > threshold:
      result.add(elem)
  
  return valArray(result)

proc nimini_sorted*(env: ref Env; args: seq[Value]): Value =
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

proc nimini_reversed*(env: ref Env; args: seq[Value]): Value =
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

proc nimini_take*(env: ref Env; args: seq[Value]): Value =
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

proc nimini_drop*(env: ref Env; args: seq[Value]): Value =
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

# ============================================================================
# Chainable String Functions
# ============================================================================

proc nimini_trim*(env: ref Env; args: seq[Value]): Value =
  ## Trim whitespace from string
  ## Usage: str.trim()
  if args.len != 1:
    quit "trim requires 1 argument (string)"
  
  let str = toString(args[0])
  return valString(str.strip())

proc nimini_toLowerStr*(env: ref Env; args: seq[Value]): Value =
  ## Convert string to lowercase (chainable)
  ## Usage: str.toLower()
  if args.len != 1:
    quit "toLower requires 1 argument (string)"
  
  let str = toString(args[0])
  return valString(str.toLowerAscii())

proc nimini_toUpperStr*(env: ref Env; args: seq[Value]): Value =
  ## Convert string to uppercase (chainable)
  ## Usage: str.toUpper()
  if args.len != 1:
    quit "toUpper requires 1 argument (string)"
  
  let str = toString(args[0])
  return valString(str.toUpperAscii())

# ============================================================================
# Utility Functions
# ============================================================================

proc nimini_sum*(env: ref Env; args: seq[Value]): Value =
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

proc nimini_first*(env: ref Env; args: seq[Value]): Value =
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

proc nimini_last*(env: ref Env; args: seq[Value]): Value =
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

# ============================================================================
# Example: Initialize Chainable Functions
# ============================================================================

proc initChainableFunctions*() =
  ## Register all chainable functions with the runtime
  ## Call this after initStdlib()
  exportNiminiProcsClean(
    # Array operations
    nimini_filter,
    nimini_map,
    nimini_sorted,
    nimini_reversed,
    nimini_take,
    nimini_drop,
    nimini_sum,
    nimini_first,
    nimini_last,
    nimini_filter_int,
    
    # String operations
    nimini_trim,
    nimini_toLowerStr,
    nimini_toUpperStr
  )

# ============================================================================
# Usage Example
# ============================================================================

when isMainModule:
  import ../nimini
  
  echo "Example: Chainable Functions in Nimini"
  echo "======================================="
  
  let code = """
# Array chaining example
let numbers = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

# Filter, then reverse
let result1 = numbers.filterGreaterThan(5)
let result2 = result1.reversed()

# Sort example
let unsorted = @[5, 2, 8, 1, 9]
let sorted = unsorted.sorted()

# Take and drop
let first3 = numbers.take(3)
let skip2 = numbers.drop(2)

# String chaining
let text = "  HELLO WORLD  "
let cleaned = text.trim()
let lower = cleaned.toLower()
"""
  
  let tokens = tokenizeDsl(code)
  let program = parseDsl(tokens)
  initRuntime()
  initStdlib()
  initChainableFunctions()
  execProgram(program, runtimeEnv)
  
  let env = runtimeEnv
  echo "\nResults:"
  echo "  Filtered (>5): ", getVar(env, "result1")
  echo "  Then reversed: ", getVar(env, "result2")
  echo "  Sorted: ", getVar(env, "sorted")
  echo "  First 3: ", getVar(env, "first3")
  echo "  Skip 2: ", getVar(env, "skip2")
  echo "  Cleaned text: '", getVar(env, "lower").s, "'"
