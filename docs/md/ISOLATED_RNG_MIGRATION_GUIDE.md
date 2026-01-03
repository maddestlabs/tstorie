# Migrating to Isolated RNG

## Quick Migration Guide

### Before (Global RNG - Non-deterministic)
```nim
# Old way - uses global RNG, not deterministic across different contexts
randomize(12345)
let x = rand(100)
let y = rand(100)
# Problem: Other code using rand() interferes with this sequence!
```

### After (Isolated RNG - Deterministic)
```nim
# New way - isolated RNG, always deterministic
var rng = initRand(12345)
let x = rand(rng, 100)
let y = rand(rng, 100)
# Same seed = same sequence, always!
```

## Real-World Example: Dungeon Generator

### Before (Using Global RNG)
```nim
# docs/demos/dungen_scripted.md - Current implementation
proc generateDungeon():
  randomize(seedValue)  # Sets global RNG
  
  # Generate rooms
  var i = 0
  while i < 10:
    let roomX = rand(width - 10)      # Uses global RNG
    let roomY = rand(height - 10)     # Could be affected by other systems
    let roomW = rand(4, 10)
    let roomH = rand(4, 10)
    i = i + 1
```

**Problems:**
- If audio system also uses `rand()`, it changes the dungeon layout!
- Can't guarantee same seed produces same dungeon
- Difficult to share/reproduce specific dungeons

### After (Using Isolated RNG)
```nim
type DungeonGenerator = object
  rng: Rand
  width: int
  height: int
  rooms: seq

proc newDungeonGenerator(seed: int, w: int, h: int): DungeonGenerator =
  var gen: DungeonGenerator
  gen.rng = initRand(seed)  # Create isolated RNG
  gen.width = w
  gen.height = h
  gen.rooms = newSeq(0)
  return gen

proc generateRoom(gen: var DungeonGenerator):
  let roomX = rand(gen.rng, gen.width - 10)   # Uses isolated RNG
  let roomY = rand(gen.rng, gen.height - 10)  # Not affected by anything else!
  let roomW = rand(gen.rng, 4, 10)
  let roomH = rand(gen.rng, 4, 10)
  # Store room...

proc generate(gen: var DungeonGenerator):
  var i = 0
  while i < 10:
    gen.generateRoom()
    i = i + 1

# Usage:
var gen1 = newDungeonGenerator(12345, 80, 40)
gen1.generate()
# This dungeon is EXACTLY reproducible with seed 12345!

var gen2 = newDungeonGenerator(12345, 80, 40)
gen2.generate()
# gen1 and gen2 are identical!
```

**Benefits:**
- ✅ Same seed = same dungeon, guaranteed
- ✅ Audio/particles don't affect dungeon generation
- ✅ Users can share favorite dungeons via seed
- ✅ Works identically in scripts and native exports

## Pattern: Procedural Generator with Save/Share

```nim
type SoundGenerator = object
  rng: Rand
  waveType: int
  frequency: float
  envelope: float

proc newSound(seed: int): SoundGenerator =
  var sound: SoundGenerator
  sound.rng = initRand(seed)
  sound.randomize()
  return sound

proc randomize(sound: var SoundGenerator):
  sound.waveType = rand(sound.rng, 0, 3)
  sound.frequency = randFloat(sound.rng, 20.0, 2000.0)
  sound.envelope = randFloat(sound.rng, 0.1, 1.0)

# Share sound via seed:
var mySound = newSound(54321)
print("Share this seed: 54321")

# Anyone can recreate it:
var yourSound = newSound(54321)
# Identical to mySound!
```

## When to Use Each

### Use Global RNG (old way) when:
- Quick prototyping
- Don't care about reproducibility
- Single-threaded, no concurrent systems

### Use Isolated RNG (new way) when:
- Need deterministic generation
- Multiple procedural systems running
- Users should be able to share content via seeds
- Exporting to native code (ensures consistency)
- **Recommended for all procedural content generation!**

## API Reference

### Creating Isolated RNG
```nim
var rng = initRand(seed: int)  # Create with seed
```

### Using Isolated RNG
```nim
# Integer random (inclusive)
let n = rand(rng, max)           # 0..max
let n = rand(rng, min, max)      # min..max

# Float random
let f = randFloat(rng)           # 0.0..1.0
let f = randFloat(rng, max)      # 0.0..max

# Sampling
let item = sample(rng, myArray)  # Random element
shuffle(rng, myArray)            # Shuffle in place
```

### Global RNG (Legacy - Still Works)
```nim
randomize()                      # Random seed
randomize(seed)                  # Fixed seed (but still global!)

let n = rand(max)                # Uses global RNG
let f = randFloat()              # Uses global RNG
let item = sample(myArray)       # Uses global RNG
shuffle(myArray)                 # Uses global RNG
```

## Backward Compatibility

**Old scripts still work!** If you don't pass a `Rand` as the first argument, the functions automatically use the global RNG:

```nim
# This still works (uses global RNG):
randomize(12345)
let x = rand(100)

# This uses isolated RNG (detected automatically):
var rng = initRand(12345)
let y = rand(rng, 100)
```

The runtime automatically detects which version to use based on the first argument type.
