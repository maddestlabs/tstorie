# String Operations Demo

Test all the new string functions in nimini.

```nim on:init
var testStr = "Hello World"
var message = ""

# Test chr and ord
var charCode = ord("A")
var charFromCode = chr(65)

# Test case conversion
var upper = toUpper(testStr)
var lower = toLower(testStr)

# Test string checks
var startsH = startsWith(testStr, "Hello")
var endsD = endsWith(testStr, "World")

# Test split and join
var words = split(testStr, " ")
var joined = join(words, "-")

# Test strip
var spacey = "  trimmed  "
var trimmed = strip(spacey)

# Test replace
var replaced = replace(testStr, "World", "Nimini")

# Test find
var findPos = findStr(testStr, "World")

# Test repeat
var repeated = repeat("*", 5)

message = "String ops loaded!"
```

```nim on:render
clear()

var y = 2
draw(0, 2, y, "=== STRING OPERATIONS DEMO ===")
y = y + 2

draw(0, 2, y, "Original: " & testStr)
y = y + 1

draw(0, 2, y, "chr(65) = " & charFromCode)
y = y + 1

draw(0, 2, y, "ord('A') = " & str(charCode))
y = y + 1

draw(0, 2, y, "toUpper: " & upper)
y = y + 1

draw(0, 2, y, "toLower: " & lower)
y = y + 1

draw(0, 2, y, "startsWith 'Hello': " & str(startsH))
y = y + 1

draw(0, 2, y, "endsWith 'World': " & str(endsD))
y = y + 1

draw(0, 2, y, "split by space: [" & words[0] & ", " & words[1] & "]")
y = y + 1

draw(0, 2, y, "join with '-': " & joined)
y = y + 1

draw(0, 2, y, "strip '  trimmed  ': '" & trimmed & "'")
y = y + 1

draw(0, 2, y, "replace World->Nimini: " & replaced)
y = y + 1

draw(0, 2, y, "find 'World' at: " & str(findPos))
y = y + 1

draw(0, 2, y, "repeat '*' x5: " & repeated)
y = y + 1

y = y + 1
draw(0, 2, y, message)
```

Press Q to quit.
