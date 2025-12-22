# Test For Loop with Colon in Iterable

Test that for loops with function calls in the iterable don't accidentally parse the colon as do-notation.

```nim on:setup
proc len(s: seq): int =
  return 5

var nums = newSeq(0)
add(nums, 1)
add(nums, 2)
add(nums, 3)

bgWriteText(2, 2, "Testing for loop with len() in iterable:")

for i in 0..<len(nums):
  bgWriteText(2, 4 + i, "Index: " & $i)

bgWriteText(2, 10, "Success! Parser handled the colon correctly.")
```
