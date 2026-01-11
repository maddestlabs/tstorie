# Procedural Generation Primitives

## Goal
Provide a library of primitive functions that behave **identically** in both native Nim and nimini scripted implementations, guaranteeing that procedural generation with the same seed produces the same results.

## Discovered Requirements

Through implementing and debugging the dungeon generator, we identified several categories of primitives that must behave identically:

### 1. Math Primitives ✅ (Partially Complete)

**Issue Found**: Using `/` for division causes float results in scripts, `div` for integer division in native.

**Required Primitives**:
```nim
# Integer-only math operations
proc idiv(a, b: int): int          # Integer division: 5 idiv 2 = 2
proc imod(a, b: int): int          # Integer modulo
proc iabs(a: int): int             # Absolute value
proc clamp(v, min, max: int): int  # Clamp to range
proc sign(a: int): int             # Returns -1, 0, or 1
```

**Status**: Need to add as nimini stdlib functions and expose as native exports.

### 2. RNG Primitives ✅ (Complete!)

**Issue Found**: Global RNG state causes different sequences, non-isolated behavior.

**Solution Implemented**:
```nim
type Rand = object  # Isolated RNG state
  
proc initRand(seed: int): Rand
proc rand(rng: var Rand, max: int): int           # 0..max inclusive
proc rand(rng: var Rand, min, max: int): int      # min..max inclusive
proc shuffle(rng: var Rand, arr: var seq[T])      # Fisher-Yates
proc sample(rng: var Rand, arr: seq[T], n: int): seq[T]  # Random n items
```

**Status**: ✅ Working in both native and nimini! Isolated RNG proven.

### 3. Collection Operations ⚠️ (Needs Standardization)

**Issue Found**: Different shuffle implementations (forward vs Fisher-Yates backward).

**Required Primitives**:
```nim
# All should accept isolated RNG
proc shuffle(rng: var Rand, arr: var seq[T])
proc sample(rng: var Rand, arr: seq[T], n: int): seq[T]
proc choice(rng: var Rand, arr: seq[T]): T
proc sortStable(arr: var seq[T], cmp: proc)  # Deterministic stable sort
```

**Status**: Shuffle works but needs to be exposed as library function, not reimplemented each time.

### 4. Noise & Hash Functions ❌ (Not Yet Implemented)

**Purpose**: Procedural textures, terrain, particles.

**Required Primitives**:
```nim
# Integer-based noise (no floating point drift)
proc intPerlin2D(x, y, seed: int): int        # Returns -1000..1000
proc intSimplex2D(x, y, seed: int): int
proc intHash(x, y, seed: int): int            # Simple hash function
proc intHash3D(x, y, z, seed: int): int

# Cellular automata
proc caStep(grid: var seq[seq[int]], rule: int)
```

**Status**: Not yet implemented. Critical for terrain/texture generation.

### 5. Geometric Primitives ⚠️ (Implicit in Current Code)

**Issue Found**: Room validation logic differed (clamp vs continue).

**Required Primitives**:
```nim
# Rectangle operations (integer coordinates)
type IRect = object
  x, y, w, h: int
  
proc overlaps(a, b: IRect): bool
proc contains(r: IRect, x, y: int): bool
proc center(r: IRect): (int, int)
proc grow(r: IRect, amount: int): IRect
proc shrink(r: IRect, amount: int): IRect

# Distance and line drawing
proc manhattanDist(x1, y1, x2, y2: int): int
proc chebyshevDist(x1, y1, x2, y2: int): int
proc bresenhamLine(x1, y1, x2, y2: int): seq[(int, int)]
```

**Status**: Should be standardized and exposed.

## Implementation Strategy

### Phase 1: Standardize Math Primitives
- Add `idiv`, `imod`, `clamp`, `sign` to nimini stdlib
- Export as native Nim functions
- **Test**: Verify identical results for range of inputs

### Phase 2: Expose Collection Operations
- Move `shuffle`, `sample`, `choice` to library functions
- Ensure they take isolated `Rand` parameter
- **Test**: Verify identical sequences with same seed

### Phase 3: Add Noise & Hash Functions
- Implement integer-based noise functions
- Critical: NO floating point math
- **Test**: Generate noise fields, compare byte-for-byte

### Phase 4: Geometric Library
- Create `IRect` type and operations
- Add distance and line functions
- **Test**: Verify geometric calculations match

## Design Principles

1. **Integer Math Only**: Avoid floating point wherever possible
2. **Isolated State**: All randomness uses explicit `Rand` parameter
3. **Deterministic**: Same inputs always produce same outputs
4. **Tested**: Each primitive has test verifying native/scripted match
5. **Documented**: Clear specification of behavior including edge cases

## Testing Strategy

Create test suite that runs in both native and scripted:

```nim
# Test file that runs in both environments
proc testMathPrimitives(): bool =
  assert idiv(5, 2) == 2
  assert idiv(-5, 2) == -2  # Define edge case behavior
  assert imod(5, 3) == 2
  assert clamp(5, 0, 10) == 5
  assert clamp(-5, 0, 10) == 0
  assert clamp(15, 0, 10) == 10
  return true

proc testRNGPrimitives(): bool =
  var rng = initRand(12345)
  assert rng.rand(100) == rng.rand(100)  # Wait, this won't work...
  
  # Better: Record sequence
  var rng1 = initRand(12345)
  var rng2 = initRand(12345)
  for i in 0..<100:
    assert rng1.rand(1000) == rng2.rand(1000)
  return true
```

## Benefits

1. **Guaranteed Determinism**: Same seed = same result across implementations
2. **Easier Debugging**: Smaller, well-tested primitives
3. **Composability**: Build complex generators from simple parts
4. **Documentation**: Clear API for users
5. **Cross-Language**: Could extend to JavaScript, Python backends

## Use Cases

### Audio Generation (SFXR-style)
```nim
proc generateSound(seed: int): Sound =
  var rng = initRand(seed)
  var waveType = rng.rand(3)  # 0=square, 1=saw, 2=sine, 3=noise
  var frequency = rng.rand(100, 2000)
  var envelope = rng.rand(5)
  # ... build sound from primitives
```

### Terrain Generation
```nim
proc generateTerrain(seed: int, width, height: int): seq[seq[int]] =
  var result = newSeq[seq[int]](height)
  for y in 0..<height:
    result[y] = newSeq[int](width)
    for x in 0..<width:
      # Integer noise, no float drift
      result[y][x] = intPerlin2D(x, y, seed)
```

### Particle Systems
```nim
type Particle = object
  x, y, vx, vy: int  # Integer positions/velocities
  
proc spawnParticles(seed: int, count: int): seq[Particle] =
  var rng = initRand(seed)
  for i in 0..<count:
    result.add(Particle(
      x: rng.rand(800),
      y: rng.rand(600),
      vx: rng.rand(-100, 100),
      vy: rng.rand(-100, 100)
    ))
```

## Next Steps

1. ✅ Document discovered requirements (this file)
2. ⬜ Create `lib/primitives.nim` with math/geometric functions
3. ⬜ Add to nimini stdlib: `nimini/stdlib/procgen.nim`
4. ⬜ Create test suite: `tests/test_determinism.nim`
5. ⬜ Add noise/hash functions
6. ⬜ Document usage patterns and examples
7. ⬜ Update dungen_scripted.md to use library functions

## Conclusion

By identifying and standardizing these primitive components, we create a **guaranteed deterministic foundation** for procedural generation. Users can prototype in scripts knowing their algorithms will produce identical results when moved to native code.

The key insight: **Don't port algorithms, standardize primitives.**
