## Nimini Standard Library - String Operations
## Provides string manipulation functions

import ../runtime
import strutils

# Convert ASCII value to character
proc niminiChr*(env: ref Env; args: seq[Value]): Value =
  ## chr(asciiCode: int) - Converts ASCII code to character
  if args.len < 1:
    quit "chr requires 1 argument (ASCII code)"
  
  let code = toInt(args[0])
  if code < 0 or code > 255:
    quit "chr: ASCII code must be between 0 and 255"
  
  return valString($char(code))

# Convert character to ASCII value
proc niminiOrd*(env: ref Env; args: seq[Value]): Value =
  ## ord(char: string) - Converts character to ASCII code
  if args.len < 1:
    quit "ord requires 1 argument (character)"
  
  if args[0].kind != vkString:
    quit "ord requires a string argument"
  
  let s = args[0].s
  if s.len == 0:
    quit "ord: empty string"
  
  return valInt(ord(s[0]))

# Convert string to uppercase
proc niminiToUpper*(env: ref Env; args: seq[Value]): Value =
  ## toUpper(s: string) - Converts string to uppercase
  if args.len < 1:
    quit "toUpper requires 1 argument"
  
  if args[0].kind != vkString:
    quit "toUpper requires a string argument"
  
  return valString(strutils.toUpper(args[0].s))

# Convert string to lowercase
proc niminiToLower*(env: ref Env; args: seq[Value]): Value =
  ## toLower(s: string) - Converts string to lowercase
  if args.len < 1:
    quit "toLower requires 1 argument"
  
  if args[0].kind != vkString:
    quit "toLower requires a string argument"
  
  return valString(strutils.toLower(args[0].s))

# Check if string starts with prefix
proc niminiStartsWith*(env: ref Env; args: seq[Value]): Value =
  ## startsWith(s: string, prefix: string) - Check if string starts with prefix
  if args.len < 2:
    quit "startsWith requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "startsWith requires string arguments"
  
  return valBool(strutils.startsWith(args[0].s, args[1].s))

# Check if string ends with suffix
proc niminiEndsWith*(env: ref Env; args: seq[Value]): Value =
  ## endsWith(s: string, suffix: string) - Check if string ends with suffix
  if args.len < 2:
    quit "endsWith requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "endsWith requires string arguments"
  
  return valBool(strutils.endsWith(args[0].s, args[1].s))

# Split string by delimiter
proc niminiSplit*(env: ref Env; args: seq[Value]): Value =
  ## split(s: string, sep: string) - Split string by separator into array
  if args.len < 2:
    quit "split requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "split requires string arguments"
  
  let parts = strutils.split(args[0].s, args[1].s)
  var arr: seq[Value] = @[]
  for part in parts:
    arr.add(valString(part))
  
  return Value(kind: vkArray, arr: arr)

# Join array of strings with separator
proc niminiJoin*(env: ref Env; args: seq[Value]): Value =
  ## join(arr: array, sep: string) - Join array elements with separator
  if args.len < 2:
    quit "join requires 2 arguments"
  
  if args[0].kind != vkArray or args[1].kind != vkString:
    quit "join requires array and string arguments"
  
  var parts: seq[string] = @[]
  for item in args[0].arr:
    if item.kind == vkString:
      parts.add(item.s)
    elif item.kind == vkInt:
      parts.add($item.i)
    elif item.kind == vkFloat:
      parts.add($item.f)
    elif item.kind == vkBool:
      parts.add($item.b)
    else:
      parts.add("")
  
  return valString(strutils.join(parts, args[1].s))

# Strip whitespace from string
proc niminiStrip*(env: ref Env; args: seq[Value]): Value =
  ## strip(s: string) - Remove leading and trailing whitespace
  if args.len < 1:
    quit "strip requires 1 argument"
  
  if args[0].kind != vkString:
    quit "strip requires a string argument"
  
  return valString(strutils.strip(args[0].s))

# Replace substring in string
proc niminiReplace*(env: ref Env; args: seq[Value]): Value =
  ## replace(s: string, old: string, new: string) - Replace all occurrences
  if args.len < 3:
    quit "replace requires 3 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString or args[2].kind != vkString:
    quit "replace requires string arguments"
  
  return valString(strutils.replace(args[0].s, args[1].s, args[2].s))

# Find substring in string
proc niminiFindStr*(env: ref Env; args: seq[Value]): Value =
  ## findStr(s: string, sub: string) - Find index of substring, returns -1 if not found
  if args.len < 2:
    quit "findStr requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "findStr requires string arguments"
  
  return valInt(strutils.find(args[0].s, args[1].s))

# Repeat string n times
proc niminiRepeat*(env: ref Env; args: seq[Value]): Value =
  ## repeat(s: string, n: int) - Repeat string n times
  if args.len < 2:
    quit "repeat requires 2 arguments"
  
  if args[0].kind != vkString:
    quit "repeat requires string and int arguments"
  
  let count = toInt(args[1])
  if count < 0:
    quit "repeat: count must be non-negative"
  
  return valString(strutils.repeat(args[0].s, count))
