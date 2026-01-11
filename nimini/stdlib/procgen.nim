## Procedural Generation Primitives for Nimini
## Exposes lib/primitives.nim functions to nimini scripts

import ../../lib/primitives
import ../runtime
import std/random

## ============================================================================
## Math Primitives Wrappers
## ============================================================================

proc nimini_idiv*(env: ref Env; args: seq[Value]): Value =
  if args.len != 2:
    quit "idiv requires 2 arguments"
  valInt(idiv(toInt(args[0]), toInt(args[1])))

proc nimini_imod*(env: ref Env; args: seq[Value]): Value =
  if args.len != 2:
    quit "imod requires 2 arguments"
  valInt(imod(toInt(args[0]), toInt(args[1])))

proc nimini_iabs*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "iabs requires 1 argument"
  valInt(iabs(toInt(args[0])))

proc nimini_sign*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "sign requires 1 argument"
  valInt(sign(toInt(args[0])))

proc nimini_clamp*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "clamp requires 3 arguments"
  valInt(clamp(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_wrap*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "wrap requires 3 arguments"
  valInt(wrap(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_lerp*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "lerp requires 3 arguments"
  valInt(lerp(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_smoothstep*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "smoothstep requires 1 argument"
  valInt(smoothstep(toInt(args[0])))

proc nimini_map*(env: ref Env; args: seq[Value]): Value =
  if args.len != 5:
    quit "map requires 5 arguments"
  valInt(map(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3]), toInt(args[4])))

## ============================================================================
## Noise & Hash Functions Wrappers
## ============================================================================

proc nimini_intHash*(env: ref Env; args: seq[Value]): Value =
  if args.len != 2:
    quit "intHash requires 2 arguments"
  valInt(intHash(toInt(args[0]), toInt(args[1])))

proc nimini_intHash2D*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "intHash2D requires 3 arguments"
  valInt(intHash2D(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_intHash3D*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "intHash3D requires 4 arguments"
  valInt(intHash3D(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_valueNoise2D*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "valueNoise2D requires 3 arguments"
  valInt(valueNoise2D(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_smoothNoise2D*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "smoothNoise2D requires 4 arguments"
  valInt(smoothNoise2D(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_fractalNoise2D*(env: ref Env; args: seq[Value]): Value =
  if args.len != 5:
    quit "fractalNoise2D requires 5 arguments"
  valInt(fractalNoise2D(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3]), toInt(args[4])))

## ============================================================================
## Distance Functions Wrappers
## ============================================================================

proc nimini_manhattanDist*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "manhattanDist requires 4 arguments"
  valInt(manhattanDist(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_chebyshevDist*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "chebyshevDist requires 4 arguments"
  valInt(chebyshevDist(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_euclideanDist*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "euclideanDist requires 4 arguments"
  valInt(euclideanDist(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_euclideanDistSq*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "euclideanDistSq requires 4 arguments"
  valInt(euclideanDistSq(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

## ============================================================================
## Pattern Generation Wrappers
## ============================================================================

proc nimini_checkerboard*(env: ref Env; args: seq[Value]): Value =
  if args.len != 3:
    quit "checkerboard requires 3 arguments"
  valInt(checkerboard(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_stripes*(env: ref Env; args: seq[Value]): Value =
  if args.len != 2:
    quit "stripes requires 2 arguments"
  valInt(stripes(toInt(args[0]), toInt(args[1])))

proc nimini_concentricCircles*(env: ref Env; args: seq[Value]): Value =
  if args.len != 5:
    quit "concentricCircles requires 5 arguments"
  valInt(concentricCircles(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3]), toInt(args[4])))

proc nimini_spiralPattern*(env: ref Env; args: seq[Value]): Value =
  if args.len != 5:
    quit "spiralPattern requires 5 arguments"
  valInt(spiralPattern(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3]), toInt(args[4])))

## ============================================================================
## Easing Functions Wrappers
## ============================================================================

proc nimini_easeLinear*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeLinear requires 1 argument"
  valInt(easeLinear(toInt(args[0])))

proc nimini_easeInQuad*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeInQuad requires 1 argument"
  valInt(easeInQuad(toInt(args[0])))

proc nimini_easeOutQuad*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeOutQuad requires 1 argument"
  valInt(easeOutQuad(toInt(args[0])))

proc nimini_easeInOutQuad*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeInOutQuad requires 1 argument"
  valInt(easeInOutQuad(toInt(args[0])))

proc nimini_easeInCubic*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeInCubic requires 1 argument"
  valInt(easeInCubic(toInt(args[0])))

proc nimini_easeOutCubic*(env: ref Env; args: seq[Value]): Value =
  if args.len != 1:
    quit "easeOutCubic requires 1 argument"
  valInt(easeOutCubic(toInt(args[0])))

## ============================================================================
## Grid Utility Wrappers
## ============================================================================

proc nimini_inBounds*(env: ref Env; args: seq[Value]): Value =
  if args.len != 4:
    quit "inBounds requires 4 arguments"
  valBool(inBounds(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

## ============================================================================
## Collection Operations with Isolated RNG
## ============================================================================

proc nimini_pgShuffle*(env: ref Env; args: seq[Value]): Value =
  ## Shuffle array using isolated RNG
  ## Usage: shuffle(myRand, myArray)
  if args.len != 2:
    quit "shuffle requires 2 arguments (rng, array)"
  if args[0].kind != vkRand:
    quit "First argument to shuffle must be Rand"
  if args[1].kind != vkArray:
    quit "Second argument to shuffle must be array"
  
  # Get mutable copy of RNG
  var rng = args[0].randState
  
  # Convert to native seq, shuffle, convert back
  var intSeq = newSeq[int](args[1].arr.len)
  for i in 0..<args[1].arr.len:
    intSeq[i] = toInt(args[1].arr[i])
  
  shuffle(rng, intSeq)
  
  # Update array in place
  for i in 0..<args[1].arr.len:
    args[1].arr[i] = valInt(intSeq[i])
  
  # Update RNG state
  args[0].randState = rng
  valNil()

proc nimini_pgSample*(env: ref Env; args: seq[Value]): Value =
  ## Sample random items from array
  ## Usage: sample(myRand, myArray, count)
  if args.len != 3:
    quit "sample requires 3 arguments (rng, array, count)"
  if args[0].kind != vkRand:
    quit "First argument to sample must be Rand"
  if args[1].kind != vkArray:
    quit "Second argument to sample must be array"
  
  var rng = args[0].randState
  let count = toInt(args[2])
  
  # Convert to native seq
  var intSeq = newSeq[int](args[1].arr.len)
  for i in 0..<args[1].arr.len:
    intSeq[i] = toInt(args[1].arr[i])
  
  let sampled = sample(rng, intSeq, count)
  
  # Convert back to Value array
  var result = valArray(@[])
  for val in sampled:
    result.arr.add(valInt(val))
  
  args[0].randState = rng
  result

proc nimini_pgChoice*(env: ref Env; args: seq[Value]): Value =
  ## Choose one random item
  ## Usage: choice(myRand, myArray)
  if args.len != 2:
    quit "choice requires 2 arguments (rng, array)"
  if args[0].kind != vkRand:
    quit "First argument to choice must be Rand"
  if args[1].kind != vkArray:
    quit "Second argument to choice must be array"
  if args[1].arr.len == 0:
    quit "Cannot choose from empty array"
  
  var rng = args[0].randState
  
  # Convert to native seq
  var intSeq = newSeq[int](args[1].arr.len)
  for i in 0..<args[1].arr.len:
    intSeq[i] = toInt(args[1].arr[i])
  
  let chosen = choice(rng, intSeq)
  
  args[0].randState = rng
  valInt(chosen)

proc nimini_pgWeightedChoice*(env: ref Env; args: seq[Value]): Value =
  ## Weighted random choice
  ## Usage: weightedChoice(myRand, items, weights)
  if args.len != 3:
    quit "weightedChoice requires 3 arguments (rng, items, weights)"
  if args[0].kind != vkRand:
    quit "First argument to weightedChoice must be Rand"
  if args[1].kind != vkArray or args[2].kind != vkArray:
    quit "Items and weights must be arrays"
  if args[1].arr.len != args[2].arr.len:
    quit "Items and weights must have same length"
  
  var rng = args[0].randState
  
  # Convert both arrays
  var items = newSeq[int](args[1].arr.len)
  var weights = newSeq[int](args[2].arr.len)
  for i in 0..<args[1].arr.len:
    items[i] = toInt(args[1].arr[i])
    weights[i] = toInt(args[2].arr[i])
  
  let chosen = weightedChoice(rng, items, weights)
  
  args[0].randState = rng
  valInt(chosen)

## ============================================================================
## Shader Primitives Wrappers
## ============================================================================

proc nimini_isin*(env: ref Env; args: seq[Value]): Value =
  ## Integer sine function: returns -1000..1000 for angle in decidegrees (0..3600)
  if args.len != 1:
    quit "isin requires 1 argument (angle in decidegrees)"
  valInt(isin(toInt(args[0])))

proc nimini_icos*(env: ref Env; args: seq[Value]): Value =
  ## Integer cosine function: returns -1000..1000 for angle in decidegrees (0..3600)
  if args.len != 1:
    quit "icos requires 1 argument (angle in decidegrees)"
  valInt(icos(toInt(args[0])))

proc nimini_polarDistance*(env: ref Env; args: seq[Value]): Value =
  ## Calculate distance from center point
  if args.len != 4:
    quit "polarDistance requires 4 arguments (x, y, centerX, centerY)"
  valInt(polarDistance(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_polarAngle*(env: ref Env; args: seq[Value]): Value =
  ## Calculate angle from center point (returns 0..3600 decidegrees)
  if args.len != 4:
    quit "polarAngle requires 4 arguments (x, y, centerX, centerY)"
  valInt(polarAngle(toInt(args[0]), toInt(args[1]), toInt(args[2]), toInt(args[3])))

proc nimini_waveAdd*(env: ref Env; args: seq[Value]): Value =
  ## Add two waves together with clamping
  if args.len != 2:
    quit "waveAdd requires 2 arguments"
  valInt(waveAdd(toInt(args[0]), toInt(args[1])))

proc nimini_waveMultiply*(env: ref Env; args: seq[Value]): Value =
  ## Multiply two waves together
  if args.len != 2:
    quit "waveMultiply requires 2 arguments"
  valInt(waveMultiply(toInt(args[0]), toInt(args[1])))

proc nimini_waveMix*(env: ref Env; args: seq[Value]): Value =
  ## Mix two waves with interpolation factor (t=0..1000)
  if args.len != 3:
    quit "waveMix requires 3 arguments (wave1, wave2, t)"
  valInt(waveMix(toInt(args[0]), toInt(args[1]), toInt(args[2])))

proc nimini_colorHeatmap*(env: ref Env; args: seq[Value]): Value =
  ## Get heatmap color for value (0..255)
  if args.len != 1:
    quit "colorHeatmap requires 1 argument (value 0..255)"
  valInt(colorHeatmap(toInt(args[0])).toInt())

proc nimini_colorPlasma*(env: ref Env; args: seq[Value]): Value =
  ## Get plasma color for value (0..255)
  if args.len != 1:
    quit "colorPlasma requires 1 argument (value 0..255)"
  valInt(colorPlasma(toInt(args[0])).toInt())

proc nimini_colorCoolWarm*(env: ref Env; args: seq[Value]): Value =
  ## Get cool-warm color for value (0..255)
  if args.len != 1:
    quit "colorCoolWarm requires 1 argument (value 0..255)"
  valInt(colorCoolWarm(toInt(args[0])).toInt())

proc nimini_colorFire*(env: ref Env; args: seq[Value]): Value =
  ## Get fire color for value (0..255)
  if args.len != 1:
    quit "colorFire requires 1 argument (value 0..255)"
  valInt(colorFire(toInt(args[0])).toInt())

proc nimini_colorOcean*(env: ref Env; args: seq[Value]): Value =
  ## Get ocean color for value (0..255)
  if args.len != 1:
    quit "colorOcean requires 1 argument (value 0..255)"
  valInt(colorOcean(toInt(args[0])).toInt())

proc nimini_colorNeon*(env: ref Env; args: seq[Value]): Value =
  ## Get neon color for value (0..255)
  if args.len != 1:
    quit "colorNeon requires 1 argument (value 0..255)"
  valInt(colorNeon(toInt(args[0])).toInt())

proc nimini_colorMatrix*(env: ref Env; args: seq[Value]): Value =
  ## Get matrix green color for value (0..255)
  if args.len != 1:
    quit "colorMatrix requires 1 argument (value 0..255)"
  valInt(colorMatrix(toInt(args[0])).toInt())

proc nimini_colorGrayscale*(env: ref Env; args: seq[Value]): Value =
  ## Get grayscale color for value (0..255)
  if args.len != 1:
    quit "colorGrayscale requires 1 argument (value 0..255)"
  valInt(colorGrayscale(toInt(args[0])).toInt())

