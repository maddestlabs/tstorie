## Nimini Standard Library - String Operations
## Provides string manipulation functions

import ../runtime
import strutils

# Convert ASCII value to character
proc nimini_chr*(env: ref Env; args: seq[Value]): Value =
  ## chr(asciiCode: int) - Converts ASCII code to character
  if args.len < 1:
    quit "chr requires 1 argument (ASCII code)"
  
  let code = toInt(args[0])
  if code < 0 or code > 255:
    quit "chr: ASCII code must be between 0 and 255"
  
  return valString($char(code))

# Convert character to ASCII value
proc nimini_ord*(env: ref Env; args: seq[Value]): Value =
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
proc nimini_toUpper*(env: ref Env; args: seq[Value]): Value =
  ## toUpper(s: string) - Converts string to uppercase
  if args.len < 1:
    quit "toUpper requires 1 argument"
  
  if args[0].kind != vkString:
    quit "toUpper requires a string argument"
  
  return valString(strutils.toUpper(args[0].s))

# Convert string to lowercase
proc nimini_toLower*(env: ref Env; args: seq[Value]): Value =
  ## toLower(s: string) - Converts string to lowercase
  if args.len < 1:
    quit "toLower requires 1 argument"
  
  if args[0].kind != vkString:
    quit "toLower requires a string argument"
  
  return valString(strutils.toLower(args[0].s))

# Check if string starts with prefix
proc nimini_startsWith*(env: ref Env; args: seq[Value]): Value =
  ## startsWith(s: string, prefix: string) - Check if string starts with prefix
  if args.len < 2:
    quit "startsWith requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "startsWith requires string arguments"
  
  return valBool(strutils.startsWith(args[0].s, args[1].s))

# Check if string ends with suffix
proc nimini_endsWith*(env: ref Env; args: seq[Value]): Value =
  ## endsWith(s: string, suffix: string) - Check if string ends with suffix
  if args.len < 2:
    quit "endsWith requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "endsWith requires string arguments"
  
  return valBool(strutils.endsWith(args[0].s, args[1].s))

# Split string by delimiter
proc nimini_split*(env: ref Env; args: seq[Value]): Value =
  ## split(s: string, sep: string) - Split string by separator into array
  ## Special handling: if sep is "\n", it splits by actual newline (char 10)
  if args.len < 2:
    quit "split requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "split requires string arguments"
  
  # Special case: if separator is the string "\n", split by actual newline character
  let separator = args[1].s
  var parts: seq[string] = @[]
  
  if separator == "\\n" or (separator.len == 1 and ord(separator[0]) == 10):
    # Split by actual newline character (ASCII 10)
    parts = strutils.split(args[0].s, '\n')
  else:
    # Normal string split
    parts = strutils.split(args[0].s, separator)
  
  var arr: seq[Value] = @[]
  for part in parts:
    arr.add(valString(part))
  
  return Value(kind: vkArray, arr: arr)

# Join array of strings with separator
proc nimini_join*(env: ref Env; args: seq[Value]): Value =
  ## join(arr: array, sep: string) - Join array elements with separator
  ## Special handling: if sep is "\n", it joins with actual newline (char 10)
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
  
  # Special case: if separator is the string "\n", use actual newline character
  let separator = args[1].s
  if separator == "\\n" or (separator.len == 1 and ord(separator[0]) == 10):
    # Join with actual newline character (ASCII 10)
    return valString(strutils.join(parts, "\n"))
  else:
    # Normal join
    return valString(strutils.join(parts, separator))

# Strip whitespace from string
proc nimini_strip*(env: ref Env; args: seq[Value]): Value =
  ## strip(s: string) - Remove leading and trailing whitespace
  if args.len < 1:
    quit "strip requires 1 argument"
  
  if args[0].kind != vkString:
    quit "strip requires a string argument"
  
  return valString(strutils.strip(args[0].s))

# Replace substring in string
proc nimini_replace*(env: ref Env; args: seq[Value]): Value =
  ## replace(s: string, old: string, new: string) - Replace all occurrences
  if args.len < 3:
    quit "replace requires 3 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString or args[2].kind != vkString:
    quit "replace requires string arguments"
  
  return valString(strutils.replace(args[0].s, args[1].s, args[2].s))

# Find substring in string
proc nimini_findStr*(env: ref Env; args: seq[Value]): Value =
  ## findStr(s: string, sub: string) - Find index of substring, returns -1 if not found
  if args.len < 2:
    quit "findStr requires 2 arguments"
  
  if args[0].kind != vkString or args[1].kind != vkString:
    quit "findStr requires string arguments"
  
  return valInt(strutils.find(args[0].s, args[1].s))

# Split string into lines
proc nimini_splitLines*(env: ref Env; args: seq[Value]): Value =
  ## splitLines(s: string) - Split string by actual newline characters into array
  if args.len < 1:
    quit "splitLines requires 1 argument"
  
  if args[0].kind != vkString:
    quit "splitLines requires a string argument"
  
  let parts = strutils.split(args[0].s, '\n')
  var arr: seq[Value] = @[]
  for part in parts:
    arr.add(valString(part))
  
  return Value(kind: vkArray, arr: arr)

# Repeat string n times
proc nimini_repeat*(env: ref Env; args: seq[Value]): Value =
  ## repeat(s: string, n: int) - Repeat string n times
  if args.len < 2:
    quit "repeat requires 2 arguments"
  
  if args[0].kind != vkString:
    quit "repeat requires string and int arguments"
  
  let count = toInt(args[1])
  if count < 0:
    quit "repeat: count must be non-negative"
  
  return valString(strutils.repeat(args[0].s, count))
