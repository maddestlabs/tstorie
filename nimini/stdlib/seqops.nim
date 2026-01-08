## Nimini Standard Library - Sequence Operations
## Provides newSeq, setLen, and other sequence manipulation functions

import ../runtime

# Create a new sequence with given size
proc nimini_newSeq*(env: ref Env; args: seq[Value]): Value =
  ## newSeq[T](size: int) - Creates a new sequence of given size
  if args.len < 1:
    quit "newSeq requires at least 1 argument (size)"
  
  let size = toInt(args[0])
  var arr: seq[Value] = @[]
  for i in 0..<size:
    arr.add(valNil())  # Initialize with nil values
  
  return Value(kind: vkArray, arr: arr)

# Set the length of a sequence
proc nimini_setLen*(env: ref Env; args: seq[Value]): Value =
  ## setLen(seq, newLen: int) - Resizes a sequence
  if args.len < 2:
    quit "setLen requires 2 arguments (seq, newLen)"
  
  if args[0].kind != vkArray:
    quit "setLen first argument must be an array"
  
  let newLen = toInt(args[1])
  let arr = args[0]
  
  if newLen > arr.arr.len:
    # Extend with nil values
    for i in arr.arr.len..<newLen:
      arr.arr.add(valNil())
  elif newLen < arr.arr.len:
    # Truncate
    arr.arr.setLen(newLen)
  
  return valNil()

# Get the length of a sequence
proc nimini_len*(env: ref Env; args: seq[Value]): Value =
  ## len(seq) - Returns the length of a sequence or string
  if args.len < 1:
    quit "len requires 1 argument"
  
  case args[0].kind
  of vkArray:
    return valInt(args[0].arr.len)
  of vkString:
    return valInt(args[0].s.len)
  else:
    quit "len requires an array or string"

# Add element to sequence
proc nimini_add*(env: ref Env; args: seq[Value]): Value =
  ## add(seq, elem) - Adds an element to the end of a sequence
  if args.len < 2:
    quit "add requires 2 arguments (seq, elem)"
  
  if args[0].kind != vkArray:
    quit "add first argument must be an array"
  
  args[0].arr.add(args[1])
  return valNil()

# Delete element from sequence
proc nimini_delete*(env: ref Env; args: seq[Value]): Value =
  ## delete(seq, index) - Deletes an element at the given index
  if args.len < 2:
    quit "delete requires 2 arguments (seq, index)"
  
  if args[0].kind != vkArray:
    quit "delete first argument must be an array"
  
  let idx = toInt(args[1])
  if idx < 0 or idx >= args[0].arr.len:
    quit "delete: index out of bounds"
  
  args[0].arr.delete(idx)
  return valNil()

# Insert element into sequence
proc nimini_insert*(env: ref Env; args: seq[Value]): Value =
  ## insert(seq, elem, index) - Inserts an element at the given index
  if args.len < 3:
    quit "insert requires 3 arguments (seq, elem, index)"
  
  if args[0].kind != vkArray:
    quit "insert first argument must be an array"
  
  let idx = toInt(args[2])
  if idx < 0 or idx > args[0].arr.len:
    quit "insert: index out of bounds"
  
  args[0].arr.insert(args[1], idx)
  return valNil()

# Pop element from end of array (like stack)
proc nimini_pop*(env: ref Env; args: seq[Value]): Value =
  ## pop(seq) - Removes and returns the last element
  if args.len < 1:
    quit "pop requires 1 argument (seq)"
  
  if args[0].kind != vkArray:
    quit "pop argument must be an array"
  
  if args[0].arr.len == 0:
    quit "pop: array is empty"
  
  let item = args[0].arr[^1]
  args[0].arr.setLen(args[0].arr.len - 1)
  return item

# Reverse array in-place
proc nimini_reverse*(env: ref Env; args: seq[Value]): Value =
  ## reverse(seq) - Reverses an array in-place
  if args.len < 1:
    quit "reverse requires 1 argument (seq)"
  
  if args[0].kind != vkArray:
    quit "reverse argument must be an array"
  
  # Get mutable reference to the array
  let n = args[0].arr.len
  for i in 0 ..< (n div 2):
    let temp = args[0].arr[i]
    args[0].arr[i] = args[0].arr[n - 1 - i]
    args[0].arr[n - 1 - i] = temp
  
  return valNil()

# Check if array contains element
proc nimini_contains*(env: ref Env; args: seq[Value]): Value =
  ## contains(seq, item) - Checks if array contains an item
  if args.len < 2:
    quit "contains requires 2 arguments (seq, item)"
  
  if args[0].kind != vkArray:
    quit "contains first argument must be an array"
  
  # Simple comparison - compares string representations
  let searchStr = $args[1]
  for item in args[0].arr:
    if $item == searchStr:
      return valBool(true)
  
  return valBool(false)

# Find index of element
proc nimini_findIndex*(env: ref Env; args: seq[Value]): Value =
  ## find(seq, item) - Returns the index of item in array, or -1 if not found
  if args.len < 2:
    quit "find requires 2 arguments (seq, item)"
  
  if args[0].kind != vkArray:
    quit "find first argument must be an array"
  
  let searchStr = $args[1]
  for i, item in args[0].arr:
    if $item == searchStr:
      return valInt(i)
  
  return valInt(-1)

# Register all sequence operations
proc registerSeqOps*() =
  registerNative("newSeq", niminiNewSeq)
  registerNative("setLen", niminiSetLen)
  registerNative("len", niminiLen)
  registerNative("add", niminiAdd)
  registerNative("delete", niminiDelete)
  registerNative("insert", niminiInsert)
  registerNative("pop", niminiPop)
  registerNative("reverse", niminiReverse)
  registerNative("contains", niminiContains)
  registerNative("find", niminiFindIndex)
