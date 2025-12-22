## Nimini Standard Library - Random Number Generation
## Provides random number utilities and random selection
## NOTE: RNG state is managed by the host application, not by this module

import ../runtime
import std/random

# External RNG reference - set by host application
var niminiRngPtr*: ptr Rand = nil

proc setNiminiRng*(rng: ptr Rand) =
  ## Set the RNG to be used by nimini stdlib functions
  ## This should be called by the host application during initialization
  niminiRngPtr = rng

proc niminiRandomize*(env: ref Env; args: seq[Value]): Value =
  ## randomize() or randomize(seed) - Initialize random number generator
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len > 0:
    let seed = toInt(args[0])
    niminiRngPtr[] = initRand(seed)
  else:
    niminiRngPtr[] = initRand()
  return valNil()

proc niminiRand*(env: ref Env; args: seq[Value]): Value =
  ## rand(max) - Generate random integer 0..max-1
  ## rand(min, max) - Generate random integer min..max-1
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len == 0:
    return valInt(0)
  elif args.len == 1:
    let max = toInt(args[0])
    if max <= 0:
      return valInt(0)
    return valInt(rand(niminiRngPtr[], max - 1))
  else:
    let min = toInt(args[0])
    let max = toInt(args[1])
    if max <= min:
      return valInt(min)
    return valInt(rand(niminiRngPtr[], max - min - 1) + min)

proc niminiRandFloat*(env: ref Env; args: seq[Value]): Value =
  ## randFloat() - Generate random float 0.0..1.0
  ## randFloat(max) - Generate random float 0.0..max
  if niminiRngPtr.isNil:
    quit "Random number generator not initialized"
  
  if args.len == 0:
    return valFloat(rand(niminiRngPtr[], 1.0))
  else:
    let max = toFloat(args[0])
    return valFloat(rand(niminiRngPtr[], max))

proc niminiSample*(env: ref Env; args: seq[Value]): Value =
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

proc niminiChoice*(env: ref Env; args: seq[Value]): Value =
  ## choice(seq) - Alias for sample, returns a random element
  return niminiSample(env, args)

proc niminiShuffle*(env: ref Env; args: seq[Value]): Value =
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
