# Isolated RNG Support for Nimini

## Problem Statement

Currently, Nimini scripts use a shared global RNG (`niminiRngPtr`) which makes reliable seed-based procedural generation impossible. When multiple procedural systems run (dungeons, audio, particles, etc.), they interfere with each other's RNG state.

**Critical for TStorie:** Procedural generation is core to TStorie. Users need to "save" generated content using seeds (SFXR-style), where the same seed always produces the same result regardless of what other systems are running.

## Current Limitation

**Native Nim (Works):**
```nim
type DungeonGenerator = object
  rng: Rand  # Isolated RNG per instance
  width: int
  height: int

proc newGenerator(seed: int64): DungeonGenerator =
  result.rng = initRand(seed)
  
proc generate(gen: var DungeonGenerator) =
  let x = gen.rng.rand(10)  # Uses isolated RNG
```

**Nimini Scripts (Doesn't Work):**
```nim
# Currently forced to use shared global:
randomize(12345)
let x = rand(10)  # Uses niminiRngPtr - affected by everything
```

## Solution: Full Object Type Support with Isolated RNG

Enable Nimini scripts to use the same isolated RNG pattern as native Nim code.

---

## Required Language Features

### 1. Object Types with Fields

**Type System Extensions:**
- Add support for custom object types with fields
- Support field access syntax: `obj.field`
- Support field mutation: `obj.field = value`
- Support nested field access: `obj.field1.field2`

**AST Nodes Needed:**
```nim
# In ast.nim:
NiminiObjectTypeDef = object
  name: string
  fields: seq[NiminiField]

NiminiField = object
  name: string
  typ: NiminiType
  mutable: bool

# Field access expression:
NiminiFieldAccess = object
  obj: NiminiExpr
  fieldName: string
```

**Example Usage:**
```nim
type Point = object
  x: int
  y: int

type DungeonGenerator = object
  rng: Rand
  width: int
  height: int
  rooms: seq[Room]
```

### 2. Mutable Reference Semantics

**Variable Mutation:**
- Support `var` parameters for objects
- Track mutability through call chain
- Handle state changes on method calls

**Example:**
```nim
proc generate(gen: var DungeonGenerator) =
  # gen.rng state mutates on each rand() call
  let x = gen.rng.rand(10)
  let y = gen.rng.rand(10)
  # Mutations persist after function returns
```

### 3. Method Call Syntax

**Chained Field/Method Access:**
- Support: `obj.field.method(args)`
- Resolve method calls on field types
- Handle proper scoping for methods

**Example:**
```nim
let x = gen.rng.rand(10)  # Field access + method call
let y = point.x.abs()     # Field access + method call
```

### 4. Built-in Rand Type

**Add Rand as Core Type:**
```nim
# In nimini type system:
NiminiTypeKind = enum
  # ... existing types ...
  ntkRand  # New: Random number generator type

# Runtime representation:
NiminiValue = object
  case kind: NiminiTypeKind
  # ... existing cases ...
  of ntkRand:
    randState: ptr Rand  # Points to actual Nim Rand instance
```

---

## Standard Library Updates

### nimini/stdlib/random.nim

**New Functions for Isolated RNG:**
```nim
# Create isolated RNG instance
proc initRand*(seed: int64): Rand

# Methods on Rand instance (isolated)
proc rand*(r: var Rand, max: int): int
proc rand*(r: var Rand, min: int, max: int): int
proc sample*(r: var Rand, arr: seq): auto
proc shuffle*(r: var Rand, arr: var seq)

# Keep existing for backward compatibility (global RNG)
proc rand*(max: int): int
proc rand*(min: int, max: int): int
proc randomize*(seed: int64)
proc sample*(arr: seq): auto
```

**Implementation Notes:**
- Isolated functions operate on `var Rand` parameter
- Global functions use `niminiRngPtr` (existing behavior)
- Both inclusive ranges: `rand(10)` returns 0..10

---

## Backend Implementation

### 1. Nim Backend (nim_backend.nim)

**Object Type Generation:**
```nim
proc generateObjectType(obj: NiminiObjectTypeDef): string =
  result = "type " & obj.name & " = object\n"
  for field in obj.fields:
    result &= "  " & field.name & ": " & generateType(field.typ) & "\n"
```

**Field Access:**
```nim
proc generateFieldAccess(access: NiminiFieldAccess): string =
  result = generate(access.obj) & "." & access.fieldName
```

**Rand Type Handling:**
```nim
proc generateType(typ: NiminiType): string =
  case typ.kind
  of ntkRand:
    return "Rand"  # Maps to std/random.Rand
  # ... other types ...
```

### 2. JavaScript Backend (javascript_backend.nim)

**Object Type Generation:**
```nim
proc generateObjectType(obj: NiminiObjectTypeDef): string =
  # Generate JS class or object constructor
  result = "class " & obj.name & " {\n"
  result &= "  constructor() {\n"
  for field in obj.fields:
    result &= "    this." & field.name & " = " & defaultValue(field.typ) & ";\n"
  result &= "  }\n}\n"
```

**Rand Type in JS:**
```nim
# Use seedrandom.js or custom PRNG implementation
proc generateRandInit(seed: int64): string =
  result = "Math.seedrandom(" & $seed & ")"

proc generateRandCall(rng: string, max: int): string =
  result = "Math.floor(" & rng & "() * (" & $max & " + 1))"
```

---

## Implementation Phases

### Phase 1: Object Types (Foundation)
**Priority: High - Required for everything else**

Tasks:
- [ ] Add object type definition to AST
- [ ] Implement object type parser in frontend
- [ ] Add field access expression to AST
- [ ] Implement field access parser
- [ ] Add object type to type system
- [ ] Generate Nim code for object types
- [ ] Generate JavaScript code for object types
- [ ] Test: Simple objects with primitive fields

### Phase 2: Mutable References
**Priority: High - Required for Rand state**

Tasks:
- [ ] Add `var` parameter support to functions
- [ ] Track mutability in type checker
- [ ] Implement copy vs reference semantics
- [ ] Handle mutation in Nim backend
- [ ] Handle mutation in JS backend
- [ ] Test: Object mutation through functions

### Phase 3: Method Syntax
**Priority: Medium - Quality of life**

Tasks:
- [ ] Add method call syntax parser
- [ ] Implement method resolution
- [ ] Support chained calls: `obj.field.method()`
- [ ] Generate proper method calls in backends
- [ ] Test: Method calls on fields

### Phase 4: Rand Type Integration
**Priority: High - The actual goal**

Tasks:
- [ ] Add Rand to nimini type system
- [ ] Implement `initRand()` in stdlib
- [ ] Implement `rand(r, max)` methods
- [ ] Add Rand support to Nim backend
- [ ] Add Rand support to JS backend (seedrandom)
- [ ] Update dungeon generator to use isolated RNG
- [ ] Test: Same seed produces same output consistently

### Phase 5: Extended Rand API
**Priority: Low - Nice to have**

Tasks:
- [ ] Implement `sample()` with Rand
- [ ] Implement `shuffle()` with Rand
- [ ] Add `choice()` for weighted random
- [ ] Add Gaussian/normal distribution
- [ ] Documentation and examples

---

## Example Usage After Implementation

### Dungeon Generator
```nim
type DungeonGenerator = object
  rng: Rand
  width: int
  height: int
  map: seq[seq[int]]
  rooms: seq[Room]

type Room = object
  x: int
  y: int
  width: int
  height: int

proc newDungeonGenerator(seed: int64, w: int, h: int): DungeonGenerator =
  result.rng = initRand(seed)
  result.width = w
  result.height = h
  # Initialize map...

proc generateRoom(gen: var DungeonGenerator): Room =
  result.x = gen.rng.rand(0, gen.width - 10)
  result.y = gen.rng.rand(0, gen.height - 10)
  result.width = gen.rng.rand(4, 10)
  result.height = gen.rng.rand(4, 10)

proc generate(gen: var DungeonGenerator) =
  let numRooms = gen.rng.rand(8, 15)
  for i in 0..<numRooms:
    let room = gen.generateRoom()
    # Place room...
```

### SFXR-Style Audio Generator
```nim
type SoundGenerator = object
  rng: Rand
  waveType: int
  baseFreq: float
  freqSlide: float
  # ... all SFXR parameters

proc newSound(seed: int64): SoundGenerator =
  result.rng = initRand(seed)
  result.randomize()

proc randomize(gen: var SoundGenerator) =
  gen.waveType = gen.rng.rand(0, 3)
  gen.baseFreq = gen.rng.rand(0.0, 1.0)
  gen.freqSlide = gen.rng.rand(-1.0, 1.0)
  # ... randomize all parameters

# Same seed always produces same sound!
let sound1 = newSound(12345)
let sound2 = newSound(12345)
# sound1 == sound2 (identical parameters)
```

### Particle System
```nim
type ParticleSystem = object
  rng: Rand
  particles: seq[Particle]

proc emit(sys: var ParticleSystem) =
  let angle = sys.rng.rand(0.0, TAU)
  let speed = sys.rng.rand(50.0, 150.0)
  let lifetime = sys.rng.rand(0.5, 2.0)
  sys.particles.add(Particle(
    angle: angle,
    speed: speed,
    lifetime: lifetime
  ))
```

---

## Testing Strategy

### Unit Tests

**Object Type Tests:**
```nim
# Test object creation and field access
type Point = object
  x: int
  y: int

let p = Point(x: 10, y: 20)
assert p.x == 10
assert p.y == 20
```

**Mutation Tests:**
```nim
# Test mutable references
proc movePoint(p: var Point, dx: int, dy: int) =
  p.x += dx
  p.y += dy

var p = Point(x: 0, y: 0)
p.movePoint(5, 10)
assert p.x == 5
assert p.y == 10
```

**Isolated RNG Tests:**
```nim
# Test seed consistency
var gen1 = initRand(12345)
var gen2 = initRand(12345)

for i in 0..<100:
  let v1 = gen1.rand(1000)
  let v2 = gen2.rand(1000)
  assert v1 == v2  # Must be identical

# Test independence
var genA = initRand(111)
var genB = initRand(222)
let a1 = genA.rand(100)
let b1 = genB.rand(100)
let a2 = genA.rand(100)
# b1 should not affect a2's sequence
```

### Integration Tests

**Dungeon Generation:**
```nim
# Same seed produces same dungeon
let dg1 = newDungeonGenerator(654321, 80, 40)
dg1.generate()
let map1 = dg1.map

let dg2 = newDungeonGenerator(654321, 80, 40)
dg2.generate()
let map2 = dg2.map

assert map1 == map2  # Exact match required
```

**Multi-System Test:**
```nim
# Multiple systems don't interfere
var dungeonGen = newDungeonGenerator(111, 80, 40)
var soundGen = newSound(222)
var particles = newParticleSystem(333)

dungeonGen.generate()
soundGen.randomize()
particles.emit()

# Generate again with same seeds
var dungeonGen2 = newDungeonGenerator(111, 80, 40)
dungeonGen2.generate()

# Must produce identical dungeon
assert dungeonGen.map == dungeonGen2.map
```

---

## Alternative: Opaque Handle Approach (Not Recommended)

If full object support is too complex initially, a simpler opaque handle could work:

```nim
# Simpler API without objects
var dungeonRng = createRand(12345)
let x = randWith(dungeonRng, 10)

var soundRng = createRand(54321)
let freq = randWith(soundRng, 0.0, 1.0)
```

**Cons:**
- Less ergonomic syntax
- Can't bundle RNG with generator state
- Manually manage multiple RNG handles
- Still need some object support eventually

**Decision:** Go with full object support since it's needed anyway.

---

## Benefits After Implementation

✅ **Reliable Seed-Based Generation:** Same seed always produces same result  
✅ **System Independence:** Multiple procedural systems don't interfere  
✅ **User Content Sharing:** Share procedural content via seeds  
✅ **Native Parity:** Nimini scripts work like native Nim code  
✅ **Performance:** No different from current approach  
✅ **Ecosystem Growth:** Enables entire category of procedural tools

---

## References

- **Nim std/random:** https://nim-lang.org/docs/random.html
- **SFXR:** Original seed-based sound generator concept
- **Procedural Generation:** Requires isolated RNG for determinism
- **Current Issue:** [lib/dungeon_gen.nim](lib/dungeon_gen.nim) vs [docs/demos/dungen_scripted.md](docs/demos/dungen_scripted.md)

---

## Status

**Current State:** Native code has isolated RNG, Nimini scripts use shared global  
**Blocker:** Nimini lacks object types with fields  
**Priority:** Critical for TStorie's procedural generation ecosystem  
**Timeline:** Phase 1-2 needed before other procgen systems can be added
