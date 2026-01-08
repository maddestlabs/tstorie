## Nimini Standard Library - Random Number Generation
## Provides random number utilities and random selection
## Supports both global RNG (for backward compatibility) and isolated RNG instances

import ../runtime
import std/random

# External RNG reference - set by host application
var niminiRngPtr*: ptr Rand = nil

proc setNiminiRng*(rng: ptr Rand) =
  ## Set the RNG to be used by nimini stdlib functions
  ## This should be called by the host application during initialization
  niminiRngPtr = rng

# ------------------------------------------------------------------------------
# Isolated RNG Functions (New - for deterministic generation)
# ------------------------------------------------------------------------------

proc nimini_initRand*(env: ref Env; args: seq[Value]): Value =
  ## initRand(seed) - Create an isolated RNG instance with a seed
  ## Returns a Rand object that can be used with rand(), sample(), etc.
  if args.len != 1:
    quit "initRand requires 1 argument (seed)"
  
  let seed = toInt(args[0])
  let rng = initRand(seed)
  return valRand(rng)

proc nimini_randIsolated*(env: ref Env; args: seq[Value]): Value =
  ## rand(rng, max) - Generate random integer 0..max using isolated RNG
  ## rand(rng, min, max) - Generate random integer min..max using isolated RNG
  ## The first argument must be a var Rand parameter (will be mutated)
  if args.len < 2:
    quit "rand with isolated RNG requires at least 2 arguments (rng, max)"
  
  if args[0].kind != vkRand:
    quit "First argument to rand must be a Rand instance"
  
  # Get the RNG value (which should be a var parameter, so it will be mutated)
  var rng = args[0].randState
  
  if args.len == 2:
    let max = toInt(args[1])
    if max <= 0:
      return valInt(0)
    let result = rand(rng, max)
    # Update the RNG state in the Value (important for var semantics)
    args[0].randState = rng
    return valInt(result)
  else:
    let min = toInt(args[1])
    let max = toInt(args[2])
    if max < min:
      return valInt(min)
    let result = rand(rng, max - min) + min
    # Update the RNG state in the Value
    args[0].randState = rng
    return valInt(result)

proc nimini_randFloatIsolated*(env: ref Env; args: seq[Value]): Value =
  ## randFloat(rng) - Generate random float 0.0..1.0 using isolated RNG
  ## randFloat(rng, max) - Generate random float 0.0..max using isolated RNG
  if args.len < 1:
    quit "randFloat with isolated RNG requires at least 1 argument (rng)"
  
  if args[0].kind != vkRand:
    quit "First argument to randFloat must be a Rand instance"
  
  var rng = args[0].randState
  
  let result = if args.len == 1:
    rand(rng, 1.0)
  else:
    let max = toFloat(args[1])
    rand(rng, max)
  
  # Update the RNG state
  args[0].randState = rng
  return valFloat(result)

proc nimini_sampleIsolated*(env: ref Env; args: seq[Value]): Value =
  ## sample(rng, seq) - Returns a random element from the array using isolated RNG
  if args.len < 2:
    quit "sample with isolated RNG requires 2 arguments (rng, seq)"
  
  if args[0].kind != vkRand:
    quit "First argument to sample must be a Rand instance"
  
  if args[1].kind != vkArray:
    quit "Second argument to sample must be an array"
  
  if args[1].arr.len == 0:
    quit "sample: cannot sample from empty array"
  
  var rng = args[0].randState
  let idx = rand(rng, args[1].arr.len - 1)
  args[0].randState = rng
  return args[1].arr[idx]

proc nimini_shuffleIsolated*(env: ref Env; args: seq[Value]): Value =
  ## shuffle(rng, seq) - Randomly shuffles an array in-place using isolated RNG
  if args.len < 2:
    quit "shuffle with isolated RNG requires 2 arguments (rng, seq)"
  
  if args[0].kind != vkRand:
    quit "First argument to shuffle must be a Rand instance"
  
  if args[1].kind != vkArray:
    quit "Second argument to shuffle must be an array"
  
  var rng = args[0].randState
  let arr = args[1]
  let n = arr.arr.len
  
  # Fisher-Yates shuffle algorithm
  for i in countdown(n - 1, 1):
    let j = rand(rng, i)
    # Swap arr[i] and arr[j]
    let temp = arr.arr[i]
    arr.arr[i] = arr.arr[j]
    arr.arr[j] = temp
  
  args[0].randState = rng
  return valNil()

# ------------------------------------------------------------------------------
# Global RNG Functions (Legacy - for backward compatibility)
# ------------------------------------------------------------------------------

proc nimini_randomize*(env: ref Env; args: seq[Value]): Value =
  ## randomize() or randomize(seed) - Initialize random number generator
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len > 0:
    let seed = toInt(args[0])
    niminiRngPtr[] = initRand(seed)
  else:
    niminiRngPtr[] = initRand()
  return valNil()

proc nimini_rand*(env: ref Env; args: seq[Value]): Value =
  ## rand(max) - Generate random integer 0..max (INCLUSIVE, matching Nim's std/random)
  ## rand(min, max) - Generate random integer min..max (INCLUSIVE, matching Nim's std/random)
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len == 0:
    return valInt(0)
  elif args.len == 1:
    let max = toInt(args[0])
    if max <= 0:
      return valInt(0)
    return valInt(rand(niminiRngPtr[], max))  # Changed: removed -1 for inclusive
  else:
    let min = toInt(args[0])
    let max = toInt(args[1])
    if max < min:
      return valInt(min)
    return valInt(rand(niminiRngPtr[], max - min) + min)  # Changed: removed -1 for inclusive

proc nimini_randFloat*(env: ref Env; args: seq[Value]): Value =
  ## randFloat() - Generate random float 0.0..1.0
  ## randFloat(max) - Generate random float 0.0..max
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len == 0:
    return valFloat(rand(niminiRngPtr[], 1.0))
  else:
    let max = toFloat(args[0])
    return valFloat(rand(niminiRngPtr[], max))

proc nimini_sample*(env: ref Env; args: seq[Value]): Value =
  ## sample(seq) - Returns a random element from the array
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len < 1:
    quit "sample requires 1 argument (seq)"
  
  if args[0].kind != vkArray:
    quit "sample argument must be an array"
  
  if args[0].arr.len == 0:
    quit "sample: cannot sample from empty array"
  
  let idx = rand(niminiRngPtr[], args[0].arr.len - 1)
  return args[0].arr[idx]

proc nimini_choice*(env: ref Env; args: seq[Value]): Value =
  ## choice(seq) - Alias for sample, returns a random element
  return niminiSample(env, args)

proc nimini_shuffle*(env: ref Env; args: seq[Value]): Value =
  ## shuffle(seq) - Randomly shuffles an array in-place using Fisher-Yates
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len < 1:
    quit "shuffle requires 1 argument (seq)"
  
  if args[0].kind != vkArray:
    quit "shuffle argument must be an array"
  
  let arr = args[0]
  let n = arr.arr.len
  
  # Fisher-Yates shuffle algorithm
  for i in countdown(n - 1, 1):
    let j = rand(niminiRngPtr[], i)
    # Swap arr[i] and arr[j]
    let temp = arr.arr[i]
    arr.arr[i] = arr.arr[j]
    arr.arr[j] = temp
  
  return valNil()

# Register all random operations
proc registerRandom*() =
  registerNative("randomize", niminiRandomize)
  registerNative("rand", niminiRand)
  registerNative("randFloat", niminiRandFloat)
  registerNative("sample", niminiSample)
  registerNative("choice", niminiChoice)
  registerNative("shuffle", niminiShuffle)
