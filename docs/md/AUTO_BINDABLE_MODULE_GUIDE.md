# Writing Auto-Bindable Modules

## The Vision: Zero Manual Wrappers

With the right infrastructure (`auto_registry.nim` and `auto_pointer.nim`), you can write modules from scratch that are **100% auto-bindable**.

## Module Design Patterns

### Pattern 1: Stateless Utilities → Use `autoExpose`

**When**: Pure functions, no state, simple types  
**Infrastructure**: Already exists (`nimini/auto_bindings.nim`)  
**Code Savings**: ~90%

```nim
# lib/math_utils.nim
import ../nimini/auto_bindings

proc clamp*(x, min, max: int): int {.autoExpose: "math".} =
  if x < min: min elif x > max: max else: x

proc lerp*(a, b, t: float): float {.autoExpose: "math".} =
  a + (b - a) * t

proc distance*(x1, y1, x2, y2: float): float {.autoExpose: "math".} =
  sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))

# lib/math_utils_bindings.nim
import ../nimini
import math_utils

proc registerMathUtilsBindings*(env: ref Env) =
  register_clamp()
  register_lerp()
  register_distance()
  # Done! 3 lines instead of ~60
```

---

### Pattern 2: Instance Management → Use `autoRegistry`

**When**: Multiple instances, ref objects, string IDs  
**Infrastructure**: NEW - `nimini/auto_registry.nim`  
**Code Savings**: ~95%

```nim
# lib/sprite_system.nim - Written from scratch for auto-binding
import ../nimini/auto_bindings
import ../nimini/auto_registry

type SpriteSystem* = ref object
  sprites: seq[Sprite]
  maxSprites: int
  activeCount: int

# Define the registry
autoRegistry(SpriteSystem, "sprite")

# Constructor - returns string ID automatically
proc createSpriteSystem*(maxSprites: int): SpriteSystem {.autoExposeRegistry: "sprite".} =
  result = SpriteSystem(
    sprites: newSeq[Sprite](maxSprites),
    maxSprites: maxSprites,
    activeCount: 0
  )

# Methods - first param is string ID (implicit)
proc addSprite*(id: string, x, y: float, texture: string): int {.autoExposeRegistryMethod: "sprite".} =
  ## 'self' is automatically the SpriteSystem instance
  if self.activeCount >= self.maxSprites:
    return -1
  
  let idx = self.activeCount
  self.sprites[idx] = Sprite(x: x, y: y, texture: texture)
  self.activeCount += 1
  return idx

proc updateSprite*(id: string, idx: int, dx, dy: float) {.autoExposeRegistryMethod: "sprite".} =
  if idx < 0 or idx >= self.activeCount:
    return
  
  self.sprites[idx].x += dx
  self.sprites[idx].y += dy

proc getSpriteCount*(id: string): int {.autoExposeRegistryMethod: "sprite".} =
  return self.activeCount

# lib/sprite_system_bindings.nim
import ../nimini
import sprite_system

proc registerSpriteSystemBindings*(env: ref Env) =
  register_createSpriteSystem()  # Returns "sprite_0", "sprite_1", etc.
  register_addSprite()
  register_updateSprite()
  register_getSpriteCount()
  # Done! 4 lines instead of ~120 lines of manual wrappers
```

**What happens in nimini scripts:**
```nim
# user.nimini
let sprites = createSpriteSystem(1000)  # Returns "sprite_0"
let idx = addSprite(sprites, 100.0, 200.0, "player.png")
updateSprite(sprites, idx, 5.0, 0.0)
let count = getSpriteCount(sprites)  # Returns 1
```

---

### Pattern 3: Pointer Handles → Use `autoPointer`

**When**: Complex ref objects, need efficient handles  
**Infrastructure**: NEW - `nimini/auto_pointer.nim`  
**Code Savings**: ~95%

```nim
# lib/world_generator.nim - Written from scratch for auto-binding
import ../nimini/auto_bindings
import ../nimini/auto_pointer

type WorldGenerator* = ref object
  width, height: int
  tiles: seq[seq[Tile]]
  entities: seq[Entity]
  step: int

# Define pointer management
autoPointer(WorldGenerator)

# Constructor - returns int pointer ID automatically
proc createWorldGenerator*(width, height, seed: int): WorldGenerator {.autoExposePointer.} =
  result = WorldGenerator(
    width: width,
    height: height,
    tiles: newSeq[seq[Tile]](height),
    entities: @[],
    step: 0
  )
  result.initialize(seed)

# Methods - first param is int pointer ID
proc worldUpdate*(ptrId: int): bool {.autoExposePointerMethod: WorldGenerator.} =
  ## 'self' is automatically the WorldGenerator instance
  self.step += 1
  self.updateEntities()
  return self.step < 1000  # Not complete yet

proc worldGetTile*(ptrId: int, x, y: int): string {.autoExposePointerMethod: WorldGenerator.} =
  if x < 0 or x >= self.width or y < 0 or y >= self.height:
    return "void"
  return $self.tiles[y][x].kind

proc worldGetStep*(ptrId: int): int {.autoExposePointerMethod: WorldGenerator.} =
  return self.step

# lib/world_generator_bindings.nim
import ../nimini
import world_generator

proc registerWorldGeneratorBindings*(env: ref Env) =
  register_createWorldGenerator()  # Returns int pointer ID
  register_worldUpdate()
  register_worldGetTile()
  register_worldGetStep()
  # Done! 4 lines instead of ~100 lines of manual casting
```

**What happens in nimini scripts:**
```nim
# user.nimini
let world = createWorldGenerator(100, 100, 12345)  # Returns int handle
while worldUpdate(world):
  let tile = worldGetTile(world, 50, 50)
  print("Tile at 50,50: " + tile)

let steps = worldGetStep(world)  # Uses int handle
```

---

## Comparison: Old vs New

### Old Way (Manual Wrappers)
```nim
# particles_bindings.nim - 647 lines
proc nimini_particleInit*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  initParticleSystemsRegistry()
  if args.len < 1: return valNil()
  let name = args[0].s
  let maxParticles = if args.len >= 2: args[1].i else: 1000
  gParticleSystems[name] = newParticleSystem(maxParticles)
  return valNil()

proc nimini_particleSetPosition*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  if args.len < 3: return valNil()
  let name = args[0].s
  if name notin gParticleSystems: return valNil()
  let x = valueToFloat(args[1])
  let y = valueToFloat(args[2])
  gParticleSystems[name].setPosition(x, y)
  return valNil()

# ... 25 more functions like this (~600 lines)

proc registerParticleSystemBindings*(env: ref Env) =
  registerNative("particleInit", nimini_particleInit, ...)
  registerNative("particleSetPosition", nimini_particleSetPosition, ...)
  # ... 25 more registrations
```

### New Way (Auto-Registry)
```nim
# particles.nim - rewritten for auto-binding
import ../nimini/auto_registry

type ParticleSystem* = ref object
  particles: seq[Particle]
  # ...

autoRegistry(ParticleSystem, "particle")

proc createParticleSystem*(maxParticles: int): ParticleSystem {.autoExposeRegistry: "particle".} =
  result = newParticleSystem(maxParticles)

proc setPosition*(id: string, x, y: float) {.autoExposeRegistryMethod: "particle".} =
  self.position = (x, y)

# ... 25 more functions with just pragmas

# particles_bindings.nim - 30 lines total
proc registerParticleSystemBindings*(env: ref Env) =
  register_createParticleSystem()
  register_setPosition()
  # ... 25 more one-liners
```

**Result**: 647 lines → 30 lines (95% reduction)

---

## Implementation Roadmap

### Phase 1: Finish Infrastructure (1-2 days)
- [ ] Complete `auto_registry.nim` macro implementation
- [ ] Complete `auto_pointer.nim` macro implementation  
- [ ] Add support for common types (seq, tuple, custom types)
- [ ] Write tests for auto-registry pattern
- [ ] Write tests for auto-pointer pattern

### Phase 2: Create Reference Module (1 day)
- [ ] Write new module from scratch using auto-registry
- [ ] Document every step and decision
- [ ] Validate it compiles and works
- [ ] Use as template for conversions

### Phase 3: Convert Existing Modules (3-5 days)
- [ ] particles.nim → auto-registry pattern
- [ ] text_editor.nim → auto-registry pattern
- [ ] dungeon_gen.nim → auto-pointer pattern
- [ ] Measure code reduction and binary impact

### Phase 4: Documentation (1 day)
- [ ] Update MODULE_BINDING_STANDARD.md
- [ ] Create "Writing New Modules" guide
- [ ] Document when to use each pattern

---

## Design Principles for New Modules

### ✅ DO: Design for Auto-Binding

```nim
# Good - auto-bindable instance management
type MySystem* = ref object
  data: seq[Thing]

autoRegistry(MySystem, "mysys")

proc create*(): MySystem {.autoExposeRegistry: "mysys".} =
  result = MySystem(data: @[])

proc addThing*(id: string, x: int) {.autoExposeRegistryMethod: "mysys".} =
  self.data.add(Thing(x: x))
```

### ❌ DON'T: Mix Instance Types

```nim
# Bad - can't auto-bind (multiple ways to access state)
var globalSystem: MySystem  # Global state

proc create*() =  # Modifies global
  globalSystem = MySystem(data: @[])

proc addThing*(sys: MySystem, x: int) =  # Takes ref object
  sys.data.add(Thing(x: x))

proc addThingGlobal*(x: int) =  # Uses global
  globalSystem.data.add(Thing(x: x))
```

### ✅ DO: Use Consistent Return Types

```nim
# Good - consistent primitives
proc getPosition*(id: string): tuple[x, y: float] {.autoExposeRegistryMethod.} =
  return (self.x, self.y)

proc getSize*(id: string): tuple[w, h: int] {.autoExposeRegistryMethod.} =
  return (self.width, self.height)
```

### ❌ DON'T: Return Complex Custom Types

```nim
# Bad - custom type not auto-convertible
proc getEntity*(id: string): Entity =  # Entity is complex custom type
  return self.entities[0]  # Can't auto-convert Entity to Value
```

---

## The Payoff

### Before (Current State)
- **Manual wrapper code**: ~600 lines per module
- **Type conversion duplication**: Every module has valueToStyle, valueToColor, etc.
- **Error-prone**: Easy to forget GC_ref, miss parameter validation
- **Maintenance burden**: Adding function requires 3 changes (native, wrapper, registration)

### After (With Infrastructure)
- **Manual wrapper code**: ~30 lines per module (just registrations)
- **Type conversion**: Centralized in auto_registry/auto_pointer
- **Safety**: GC management automatic
- **Maintenance**: Adding function requires 1 change (just add pragma)

### Estimated Impact
- **Code reduction**: 600 lines → 30 lines per module (95%)
- **Binary size**: Likely 0 bytes increase (same code, different generation)
- **New module creation time**: 1 hour → 15 minutes
- **Bug surface area**: 10x smaller

---

## Next Steps

1. **Validate approach**: Implement auto_registry.nim fully and test with one small module
2. **Measure impact**: Compile and check binary size stays stable  
3. **Get feedback**: Does the pragma-based API feel natural?
4. **Scale up**: Apply to all registry-pattern modules
5. **Document**: Update all guides with new approach

This is the **architecture you were originally aiming for** - where modules are written naturally and bindings are generated automatically. The infrastructure just needs to be built.
