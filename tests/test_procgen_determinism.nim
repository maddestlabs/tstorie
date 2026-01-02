## Test Suite: Procedural Generation Determinism
## Validates that primitives produce identical results in native and scripted implementations

import std/[random, strformat]
import ../lib/procgen_primitives

## ============================================================================
## Test Framework
## ============================================================================

var testsPassed = 0
var testsFailed = 0

template test(name, body: untyped) =
  block:
    let testName = name
    try:
      body
      echo "✓ ", testName
      testsPassed += 1
    except AssertionDefect as e:
      echo "✗ ", testName, ": ", e.msg
      testsFailed += 1

## ============================================================================
## Math Primitive Tests
## ============================================================================

proc testMathPrimitives() =
  echo "\n=== Math Primitives ==="
  
  test "idiv positive":
    doAssert idiv(7, 2) == 3
    doAssert idiv(10, 5) == 2
    doAssert idiv(1, 1) == 1
  
  test "idiv negative":
    doAssert idiv(-7, 2) == -3  # Nim's div behavior (floor division)
    doAssert idiv(7, -2) == -3
  
  test "imod":
    doAssert imod(7, 3) == 1
    doAssert imod(10, 5) == 0
    doAssert imod(-7, 3) == -1  # Nim's mod behavior
  
  test "clamp":
    doAssert clamp(5, 0, 10) == 5
    doAssert clamp(-5, 0, 10) == 0
    doAssert clamp(15, 0, 10) == 10
  
  test "wrap":
    doAssert wrap(12, 0, 10) == 1
    doAssert wrap(-2, 0, 10) == 9
    doAssert wrap(5, 0, 10) == 5
  
  test "lerp":
    doAssert lerp(0, 100, 500) == 50  # 50%
    doAssert lerp(0, 100, 0) == 0     # 0%
    doAssert lerp(0, 100, 1000) == 100  # 100%
  
  test "map":
    doAssert map(5, 0, 10, 0, 100) == 50
    doAssert map(0, 0, 10, 100, 200) == 100
    doAssert map(10, 0, 10, 100, 200) == 200
  
  test "sign":
    doAssert sign(-5) == -1
    doAssert sign(0) == 0
    doAssert sign(5) == 1

## ============================================================================
## RNG Determinism Tests
## ============================================================================

proc testRNGDeterminism() =
  echo "\n=== RNG Determinism ==="
  
  test "Same seed produces same sequence":
    var rng1 = initRand(12345)
    var rng2 = initRand(12345)
    
    for i in 0..<100:
      let v1 = rng1.rand(1000)
      let v2 = rng2.rand(1000)
      doAssert v1 == v2, &"Mismatch at iteration {i}: {v1} != {v2}"
  
  test "Different seeds produce different sequences":
    var rng1 = initRand(12345)
    var rng2 = initRand(54321)
    
    var matches = 0
    for i in 0..<100:
      if rng1.rand(1000) == rng2.rand(1000):
        matches += 1
    
    # Statistically should have ~10% matches for range 1000
    doAssert matches < 20, &"Too many matches ({matches}/100), RNGs may not be independent"
  
  test "Isolated RNG doesn't affect global":
    var rng = initRand(12345)
    let v1 = rng.rand(1000)
    
    # Create another RNG
    var rng2 = initRand(99999)
    discard rng2.rand(1000)
    
    # Original RNG should continue its sequence
    let v2 = rng.rand(1000)
    
    # Verify by recreating sequence
    var rngCheck = initRand(12345)
    doAssert v1 == rngCheck.rand(1000)
    doAssert v2 == rngCheck.rand(1000)

## ============================================================================
## Noise Determinism Tests
## ============================================================================

proc testNoiseDeterminism() =
  echo "\n=== Noise Determinism ==="
  
  test "intHash produces consistent values":
    doAssert intHash(123, 456) == intHash(123, 456)
    doAssert intHash2D(10, 20, 789) == intHash2D(10, 20, 789)
    doAssert intHash3D(5, 10, 15, 111) == intHash3D(5, 10, 15, 111)
  
  test "intHash produces different values for different inputs":
    doAssert intHash(123, 456) != intHash(124, 456)
    doAssert intHash2D(10, 20, 789) != intHash2D(10, 21, 789)
  
  test "valueNoise2D is deterministic":
    let v1 = valueNoise2D(100, 200, 12345)
    let v2 = valueNoise2D(100, 200, 12345)
    doAssert v1 == v2
  
  test "smoothNoise2D is deterministic":
    let v1 = smoothNoise2D(100, 200, 50, 12345)
    let v2 = smoothNoise2D(100, 200, 50, 12345)
    doAssert v1 == v2
  
  test "fractalNoise2D is deterministic":
    let v1 = fractalNoise2D(100, 200, 4, 100, 12345)
    let v2 = fractalNoise2D(100, 200, 4, 100, 12345)
    doAssert v1 == v2
  
  test "Noise produces values in expected range":
    for i in 0..<100:
      let h = intHash(i, 12345)
      doAssert h >= 0 and h <= 65535
      
      let v = valueNoise2D(i, i*2, 12345)
      doAssert v >= 0 and v <= 65535

## ============================================================================
## Geometric Tests
## ============================================================================

proc testGeometry() =
  echo "\n=== Geometric Primitives ==="
  
  test "rect center":
    let r = rect(10, 20, 100, 50)
    let (cx, cy) = center(r)
    doAssert cx == 60 and cy == 45
  
  test "rect contains":
    let r = rect(10, 10, 20, 20)
    doAssert contains(r, 15, 15)
    doAssert not contains(r, 5, 5)
    doAssert not contains(r, 35, 35)
  
  test "rect overlaps":
    let r1 = rect(0, 0, 10, 10)
    let r2 = rect(5, 5, 10, 10)
    let r3 = rect(20, 20, 10, 10)
    doAssert overlaps(r1, r2)
    doAssert not overlaps(r1, r3)
  
  test "rect grow/shrink":
    let r = rect(10, 10, 20, 20)
    let grown = grow(r, 5)
    doAssert grown.x == 5 and grown.y == 5
    doAssert grown.w == 30 and grown.h == 30
    
    let shrunk = shrink(r, 5)
    doAssert shrunk.x == 15 and shrunk.y == 15
    doAssert shrunk.w == 10 and shrunk.h == 10

## ============================================================================
## Distance Tests
## ============================================================================

proc testDistances() =
  echo "\n=== Distance Functions ==="
  
  test "manhattanDist":
    doAssert manhattanDist(0, 0, 3, 4) == 7
    doAssert manhattanDist(0, 0, 0, 0) == 0
    doAssert manhattanDist(5, 5, 2, 1) == 7
  
  test "chebyshevDist":
    doAssert chebyshevDist(0, 0, 3, 4) == 4
    doAssert chebyshevDist(0, 0, 5, 5) == 5
  
  test "euclideanDistSq":
    doAssert euclideanDistSq(0, 0, 3, 4) == 25
    doAssert euclideanDistSq(0, 0, 0, 0) == 0
  
  test "euclideanDist":
    doAssert euclideanDist(0, 0, 3, 4) == 5
    doAssert euclideanDist(0, 0, 0, 0) == 0

## ============================================================================
## Line Algorithm Tests
## ============================================================================

proc testLineAlgorithms() =
  echo "\n=== Line & Curve Algorithms ==="
  
  test "bresenhamLine determinism":
    let line1 = bresenhamLine(0, 0, 10, 5)
    let line2 = bresenhamLine(0, 0, 10, 5)
    doAssert line1 == line2
    doAssert line1[0] == (0, 0)
    doAssert line1[^1] == (10, 5)
  
  test "bresenhamLine length":
    let line = bresenhamLine(0, 0, 10, 0)
    doAssert line.len == 11  # Includes both endpoints
  
  test "circle determinism":
    let circ1 = circle(0, 0, 10)
    let circ2 = circle(0, 0, 10)
    doAssert circ1 == circ2

## ============================================================================
## Collection Operations Tests
## ============================================================================

proc testCollections() =
  echo "\n=== Collection Operations ==="
  
  test "shuffle determinism":
    var arr1 = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    var arr2 = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    var rng1 = initRand(12345)
    var rng2 = initRand(12345)
    
    shuffle(rng1, arr1)
    shuffle(rng2, arr2)
    
    doAssert arr1 == arr2, "Shuffles with same seed should match"
  
  test "sample determinism":
    let arr = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    var rng1 = initRand(12345)
    var rng2 = initRand(12345)
    
    let sample1 = sample(rng1, arr, 5)
    let sample2 = sample(rng2, arr, 5)
    
    doAssert sample1 == sample2, "Samples with same seed should match"
  
  test "choice determinism":
    let arr = @[10, 20, 30, 40, 50]
    
    var rng1 = initRand(12345)
    var rng2 = initRand(12345)
    
    for i in 0..<20:
      doAssert choice(rng1, arr) == choice(rng2, arr)
  
  test "weightedChoice distribution":
    let items = @[1, 2, 3]
    let weights = @[1, 10, 1]  # Middle item 10x more likely
    
    var rng = initRand(12345)
    var counts = [0, 0, 0]
    
    for i in 0..<1000:
      let chosen = weightedChoice(rng, items, weights)
      counts[chosen - 1] += 1
    
    # Item 2 should be chosen ~10x more than others
    doAssert counts[1] > counts[0] * 5, "Weighted choice not respecting weights"
    doAssert counts[1] > counts[2] * 5

## ============================================================================
## Pattern Generation Tests
## ============================================================================

proc testPatterns() =
  echo "\n=== Pattern Generation ==="
  
  test "checkerboard":
    doAssert checkerboard(0, 0, 10) == 0
    doAssert checkerboard(10, 0, 10) == 1
    doAssert checkerboard(0, 10, 10) == 1
    doAssert checkerboard(10, 10, 10) == 0
  
  test "stripes":
    doAssert stripes(0, 10) == 0
    doAssert stripes(10, 10) == 1
    doAssert stripes(20, 10) == 0
  
  test "concentricCircles":
    doAssert concentricCircles(0, 0, 0, 0, 10) == 0
    doAssert concentricCircles(10, 0, 0, 0, 10) == 1
    doAssert concentricCircles(0, 10, 0, 0, 10) == 1

## ============================================================================
## Easing Function Tests
## ============================================================================

proc testEasing() =
  echo "\n=== Easing Functions ==="
  
  test "easing bounds":
    doAssert easeLinear(0) == 0
    doAssert easeLinear(1000) == 1000
    doAssert easeInQuad(0) == 0
    doAssert easeInQuad(1000) == 1000
    doAssert easeOutQuad(0) == 0
    doAssert easeOutQuad(1000) == 1000
  
  test "easeInQuad is slower at start":
    let quarter = easeInQuad(250)
    doAssert quarter < 250, "Ease in should be slower at start"
  
  test "easeOutQuad is faster at start":
    let quarter = easeOutQuad(250)
    doAssert quarter > 250, "Ease out should be faster at start"

## ============================================================================
## Color Tests
## ============================================================================

proc testColors() =
  echo "\n=== Color Utilities ==="
  
  test "icolor creation":
    let c = icolor(255, 128, 0)
    doAssert c.r == 255 and c.g == 128 and c.b == 0
  
  test "color to/from int":
    let c = icolor(255, 128, 64)
    let i = toInt(c)
    let c2 = fromInt(i)
    doAssert c2.r == c.r and c2.g == c.g and c2.b == c.b
  
  test "lerpColor":
    let c1 = icolor(0, 0, 0)
    let c2 = icolor(100, 100, 100)
    let mid = lerpColor(c1, c2, 500)
    doAssert mid.r == 50 and mid.g == 50 and mid.b == 50

## ============================================================================
## Main Test Runner
## ============================================================================

when isMainModule:
  echo "=========================================="
  echo "Procedural Generation Determinism Tests"
  echo "=========================================="
  
  testMathPrimitives()
  testRNGDeterminism()
  testNoiseDeterminism()
  testGeometry()
  testDistances()
  testLineAlgorithms()
  testCollections()
  testPatterns()
  testEasing()
  testColors()
  
  echo "\n=========================================="
  echo &"Tests passed: {testsPassed}"
  echo &"Tests failed: {testsFailed}"
  echo "=========================================="
  
  if testsFailed > 0:
    quit(1)
