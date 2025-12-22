---
title: "Nimini Collections Test"
author: "Test stdlib features"
minWidth: 80
minHeight: 24
---

# Collections and Random Test

Testing the new Nimini stdlib features: HashSet, Deque, shuffle, and random selection.
Also verifying that random functions share the same RNG as tstorie (randInt/randFloat).

```nim on:init
bgClear()

# Test that Nimini stdlib random and tstorie random use the same RNG
randomize(12345)  # Set seed via Nimini stdlib

# These should produce the same sequence since they share the RNG
var niminiRand1 = rand(100)
var tstorieRand1 = randInt(100)
var niminiRand2 = rand(100)
var tstorieRand2 = randInt(100)

bgWriteText(2, 2, "Shared RNG Test (seed=12345):")
bgWriteText(2, 3, "Nimini rand(100): " & $niminiRand1)
bgWriteText(2, 4, "tstorie randInt(100): " & $tstorieRand1)
bgWriteText(2, 5, "Nimini rand(100): " & $niminiRand2)
bgWriteText(2, 6, "tstorie randInt(100): " & $tstorieRand2)

# Test HashSet
var mySet = newHashSet()
incl(mySet, 10)
incl(mySet, 20)
incl(mySet, 30)
incl(mySet, 20)  # Duplicate, should not add again

bgWriteText(2, 8, "HashSet Test:")
bgWriteText(2, 9, "Card: " & $card(mySet))  # Should be 3
bgWriteText(2, 10, "Contains 20: " & $contains(mySet, 20))  # Should be true
bgWriteText(2, 11, "Contains 40: " & $contains(mySet, 40))  # Should be false

# Test Deque
var myDeque = newDeque()
addLast(myDeque, 1)
addLast(myDeque, 2)
addLast(myDeque, 3)
addFirst(myDeque, 0)

bgWriteText(2, 13, "Deque Test:")
bgWriteText(2, 14, "First: " & $peekFirst(myDeque))  # Should be 0
bgWriteText(2, 15, "Last: " & $peekLast(myDeque))    # Should be 3

var popped = popFirst(myDeque)
bgWriteText(2, 16, "After popFirst: " & $peekFirst(myDeque))  # Should be 1

# Test shuffle and random
randomize(42)  # Use seed for reproducibility
var numbers = newSeq(5)
for i in 0..4:
  numbers[i] = i + 1

bgWriteText(2, 18, "Array Test:")
bgWriteText(2, 19, "Original: [1,2,3,4,5]")

shuffle(numbers)
var shuffledStr = "Shuffled: ["
for i in 0..4:
  shuffledStr = shuffledStr & $numbers[i]
  if i < 4:
    shuffledStr = shuffledStr & ","
shuffledStr = shuffledStr & "]"
bgWriteText(2, 20, shuffledStr)

# Test sample
var picked = sample(numbers)
bgWriteText(2, 21, "Random sample: " & $picked)

# Test reverse
reverse(numbers)
var reversedStr = "Reversed: ["
for i in 0..4:
  reversedStr = reversedStr & $numbers[i]
  if i < 4:
    reversedStr = reversedStr & ","
reversedStr = reversedStr & "]"
bgWriteText(2, 22, reversedStr)

bgWriteText(2, 24, "All tests complete!")
```
