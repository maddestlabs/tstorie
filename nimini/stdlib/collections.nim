## Nimini Standard Library - Collection Data Structures
## Provides HashSet and Deque implementations

import ../runtime
import std/tables

# ==============================================================================
# HashSet Implementation
# ==============================================================================
# In Nimini runtime, we represent a HashSet as a map with keys and dummy values
# The presence of a key indicates membership in the set

proc niminiNewHashSet*(env: ref Env; args: seq[Value]): Value =
  ## newHashSet() - Creates a new empty hash set
  ## In runtime, represented as a map where keys are set members
  return Value(kind: vkMap, map: initTable[string, Value]())

proc niminiHashSetIncl*(env: ref Env; args: seq[Value]): Value =
  ## incl(set, item) - Includes an item in the hash set
  if args.len < 2:
    quit "incl requires 2 arguments (set, item)"
  
  if args[0].kind != vkMap:
    quit "incl first argument must be a hash set (map)"
  
  # Convert item to string to use as key
  let key = $args[1]
  args[0].map[key] = valBool(true)  # Value doesn't matter, just presence
  
  return valNil()

proc niminiHashSetExcl*(env: ref Env; args: seq[Value]): Value =
  ## excl(set, item) - Excludes an item from the hash set
  if args.len < 2:
    quit "excl requires 2 arguments (set, item)"
  
  if args[0].kind != vkMap:
    quit "excl first argument must be a hash set (map)"
  
  let key = $args[1]
  args[0].map.del(key)
  
  return valNil()

proc niminiHashSetContains*(env: ref Env; args: seq[Value]): Value =
  ## contains(set, item) - Checks if item is in the hash set
  ## Can also be used as: item in set
  if args.len < 2:
    quit "contains requires 2 arguments (set, item)"
  
  if args[0].kind != vkMap:
    quit "contains first argument must be a hash set (map)"
  
  let key = $args[1]
  return valBool(args[0].map.hasKey(key))

proc niminiHashSetCard*(env: ref Env; args: seq[Value]): Value =
  ## card(set) - Returns the cardinality (size) of the hash set
  if args.len < 1:
    quit "card requires 1 argument (set)"
  
  if args[0].kind != vkMap:
    quit "card argument must be a hash set (map)"
  
  return valInt(args[0].map.len)

proc niminiHashSetClear*(env: ref Env; args: seq[Value]): Value =
  ## clear(set) - Removes all items from the hash set
  if args.len < 1:
    quit "clear requires 1 argument (set)"
  
  if args[0].kind != vkMap:
    quit "clear argument must be a hash set (map)"
  
  args[0].map.clear()
  return valNil()

proc niminiHashSetToSeq*(env: ref Env; args: seq[Value]): Value =
  ## toSeq(set) - Converts hash set to sequence/array
  if args.len < 1:
    quit "toSeq requires 1 argument (set)"
  
  if args[0].kind != vkMap:
    quit "toSeq argument must be a hash set (map)"
  
  var arr: seq[Value] = @[]
  for key in args[0].map.keys:
    # Try to parse back to original type
    # For simplicity, we'll keep as strings for now
    arr.add(valString(key))
  
  return Value(kind: vkArray, arr: arr)

# ==============================================================================
# Deque Implementation  
# ==============================================================================
# Represented as an array with special metadata for efficient front operations

proc niminiNewDeque*(env: ref Env; args: seq[Value]): Value =
  ## newDeque() - Creates a new empty double-ended queue
  ## Represented as a simple array in runtime
  return Value(kind: vkArray, arr: @[])

proc niminiDequeAddFirst*(env: ref Env; args: seq[Value]): Value =
  ## addFirst(deque, item) - Adds item to the front of the deque
  if args.len < 2:
    quit "addFirst requires 2 arguments (deque, item)"
  
  if args[0].kind != vkArray:
    quit "addFirst first argument must be a deque (array)"
  
  args[0].arr.insert(args[1], 0)
  return valNil()

proc niminiDequeAddLast*(env: ref Env; args: seq[Value]): Value =
  ## addLast(deque, item) - Adds item to the back of the deque
  if args.len < 2:
    quit "addLast requires 2 arguments (deque, item)"
  
  if args[0].kind != vkArray:
    quit "addLast first argument must be a deque (array)"
  
  args[0].arr.add(args[1])
  return valNil()

proc niminiDequePopFirst*(env: ref Env; args: seq[Value]): Value =
  ## popFirst(deque) - Removes and returns the first item
  if args.len < 1:
    quit "popFirst requires 1 argument (deque)"
  
  if args[0].kind != vkArray:
    quit "popFirst argument must be a deque (array)"
  
  if args[0].arr.len == 0:
    quit "popFirst: deque is empty"
  
  let item = args[0].arr[0]
  args[0].arr.delete(0)
  return item

proc niminiDequePopLast*(env: ref Env; args: seq[Value]): Value =
  ## popLast(deque) - Removes and returns the last item
  if args.len < 1:
    quit "popLast requires 1 argument (deque)"
  
  if args[0].kind != vkArray:
    quit "popLast argument must be a deque (array)"
  
  if args[0].arr.len == 0:
    quit "popLast: deque is empty"
  
  let item = args[0].arr[^1]
  args[0].arr.setLen(args[0].arr.len - 1)
  return item

proc niminiDequePeekFirst*(env: ref Env; args: seq[Value]): Value =
  ## peekFirst(deque) - Returns the first item without removing it
  if args.len < 1:
    quit "peekFirst requires 1 argument (deque)"
  
  if args[0].kind != vkArray:
    quit "peekFirst argument must be a deque (array)"
  
  if args[0].arr.len == 0:
    quit "peekFirst: deque is empty"
  
  return args[0].arr[0]

proc niminiDequePeekLast*(env: ref Env; args: seq[Value]): Value =
  ## peekLast(deque) - Returns the last item without removing it
  if args.len < 1:
    quit "peekLast requires 1 argument (deque)"
  
  if args[0].kind != vkArray:
    quit "peekLast argument must be a deque (array)"
  
  if args[0].arr.len == 0:
    quit "peekLast: deque is empty"
  
  return args[0].arr[^1]

proc niminiDequeClear*(env: ref Env; args: seq[Value]): Value =
  ## clear(deque) - Removes all items from the deque
  if args.len < 1:
    quit "clear requires 1 argument (deque)"
  
  if args[0].kind != vkArray:
    quit "clear argument must be a deque (array)"
  
  args[0].arr.setLen(0)
  return valNil()

# Register all collection operations
proc registerCollections*() =
  # HashSet operations
  registerNative("newHashSet", niminiNewHashSet)
  registerNative("incl", niminiHashSetIncl)
  registerNative("excl", niminiHashSetExcl)
  registerNative("contains", niminiHashSetContains)
  registerNative("card", niminiHashSetCard)
  registerNative("toSeq", niminiHashSetToSeq)
  
  # Deque operations
  registerNative("newDeque", niminiNewDeque)
  registerNative("addFirst", niminiDequeAddFirst)
  registerNative("addLast", niminiDequeAddLast)
  registerNative("popFirst", niminiDequePopFirst)
  registerNative("popLast", niminiDequePopLast)
  registerNative("peekFirst", niminiDequePeekFirst)
  registerNative("peekLast", niminiDequePeekLast)
