---
title: "RNG Test - Isolated vs Global"
author: "Test isolated RNG determinism"
minWidth: 80
minHeight: 20
---

# Isolated RNG Test

This demo proves that isolated RNG produces deterministic results.

```nim on:init

# Test 1: Using isolated RNG (same seed = same sequence)
var rng1 = initRand(12345)
var rng2 = initRand(12345)

var test1Results = newSeq(10)
var test2Results = newSeq(10)

# Generate same sequence from both
for i in 0..<10:
  test1Results[i] = rng1.rand(0, 100)
  test2Results[i] = rng2.rand(0, 100)

# Test 2: Verify independence
var rngA = initRand(111)
var rngB = initRand(222)

var before = rngA.rand(0, 100)
var interference = rngB.rand(0, 100)  # This should NOT affect rngA
var after = rngA.rand(0, 100)

# Test 3: Create a simple object with RNG
type Generator = object
  rng: Rand
  counter: int

proc newGenerator(seed: int64): Generator =
  var gen = Generator(
    rng: initRand(seed),
    counter: 0
  )
  return gen

proc generate(gen: var Generator): int =
  gen.counter = gen.counter + 1
  return gen.rng.rand(0, 1000)

var gen1 = newGenerator(54321)
var gen2 = newGenerator(54321)

var gen1Results = newSeq(5)
var gen2Results = newSeq(5)

for i in 0..<5:
  gen1Results[i] = generate(gen1)
  gen2Results[i] = generate(gen2)

```

```nim on:render
clear()

var line = 0

# Header
draw(0, 0, line, "ISOLATED RNG TEST - Deterministic Procedural Generation")
line = line + 2

# Test 1: Same seed produces same sequence
draw(0, 0, line, "Test 1: Same seed (12345) should produce identical sequences")
line = line + 1
draw(0, 0, line, "RNG1: ")
for i in 0..<10:
  draw(0, 6 + (i * 4), line, str(test1Results[i]))
line = line + 1
draw(0, 0, line, "RNG2: ")
for i in 0..<10:
  draw(0, 6 + (i * 4), line, str(test2Results[i]))
line = line + 1

# Check if identical
var identical = true
for i in 0..<10:
  if test1Results[i] != test2Results[i]:
    identical = false
    break

if identical:
  draw(2, 0, line, "PASS: Sequences are identical!")
else:
  draw(1, 0, line, "FAIL: Sequences differ!")
line = line + 3

# Test 2: Independence
draw(0, 0, line, "Test 2: Independent RNG instances don't interfere")
line = line + 1
draw(0, 0, line, "RNG A (seed 111): before=" & str(before) & "  after=" & str(after))
line = line + 1
draw(0, 0, line, "RNG B (seed 222): value=" & str(interference) & " (should not affect A)")
line = line + 3

# Test 3: Object-based generators
draw(0, 0, line, "Test 3: Object-based generators with isolated RNG")
line = line + 1
draw(0, 0, line, "Gen1 (seed 54321): ")
for i in 0..<5:
  draw(0, 20 + (i * 5), line, str(gen1Results[i]))
line = line + 1
draw(0, 0, line, "Gen2 (seed 54321): ")
for i in 0..<5:
  draw(0, 20 + (i * 5), line, str(gen2Results[i]))
line = line + 1

# Check if identical
var gen_identical = true
for i in 0..<5:
  if gen1Results[i] != gen2Results[i]:
    gen_identical = false
    break

if gen_identical:
  draw(2, 0, line, "PASS: Object generators produce identical sequences!")
else:
  draw(1, 0, line, "FAIL: Object generators differ!")
line = line + 3

# Summary
draw(0, 0, line, "CONCLUSION:")
line = line + 1
if identical and gen_identical:
  draw(2, 0, line, "Isolated RNG works perfectly! Same seed = Same output")
  line = line + 1
  draw(0, 0, line, "This enables reliable seed-based procedural generation:")
  line = line + 1
  draw(0, 2, line, "- SFXR-style audio generation")
  line = line + 1
  draw(0, 2, line, "- Deterministic dungeons")
  line = line + 1
  draw(0, 2, line, "- Repeatable particle systems")
  line = line + 1
  draw(0, 2, line, "- Shareable procedural content via seeds")
else:
  draw(1, 0, line, "ERROR: Isolated RNG not working as expected!")

```

```nim on:input
# No input handling needed
return false
```
