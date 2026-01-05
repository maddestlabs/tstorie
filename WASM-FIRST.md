# WASM-First Development

## Development Strategy: Build WASM-First

**If it works in WASM, it will work native.** WASM is stricter about:
- Integer overflow (traps vs wraps)
- Memory safety (catches undefined behavior)
- Initialization requirements (RNG, globals)

## Critical WASM Pitfalls

### 1. Integer Overflow
```nim
# ❌ BAD - Overflows in WASM
let hash = (x * 374761393 + y * 668265263) xor seed

# ✅ GOOD - Bounded arithmetic
let hash = ((x mod 10000) * 37471 + (y mod 10000) * 66827) xor seed
```

**Fix**: Use modulo to bound inputs, use smaller multipliers

### 2. Pointer Arithmetic
```nim
# ❌ BAD - .addr usage
var p = particles[i].addr
p.x = newX
p.y = newY

# ✅ GOOD - Direct array indexing
particles[i].x = newX
particles[i].y = newY
```

**Fix**: Avoid `.addr` and pointer arithmetic, use direct access

### 3. Random Number Generator
```nim
# ❌ BAD - Uninitialized RNG
proc init*() =
  # Missing randomize()
  particles[i].vel = rand(10.0)

# ✅ GOOD - Explicit initialization
proc init*() =
  randomize()  # Seed the RNG!
  particles[i].vel = rand(10.0)
```

**Fix**: Always call `randomize()` at system/module initialization

### 4. Float Precision
```nim
# ⚠️  CAUTION - Accumulation errors
particle.x += velocity * dt  # Compounds over frames

# ✅ BETTER - Clamp deltaTime
dt = max(0.0, min(dt, 0.1))  # Prevent extreme values
particle.x += velocity * dt
```

**Fix**: Clamp time deltas, avoid long accumulation chains

### 5. Undefined Variables
```nim
# ❌ BAD - Native may tolerate, WASM catches
let dt = deltaMs / 1000.0
executeBlock(deltaTime = clampedDt)  # clampedDt doesn't exist!

# ✅ GOOD - Explicit variables
var dt = deltaMs / 1000.0
dt = clamp(dt, 0.0, 0.1)
executeBlock(deltaTime = dt)
```

**Fix**: Declare all variables, WASM is stricter about undefined refs

## Best Practices

### Use `procgen_primitives.nim` for Core Math
```nim
# Place WASM-tested utilities here
proc intHash2D*(x, y, seed: int): int =
  let sx = x mod 10000
  let sy = y mod 10000
  ((sx * 37471) + (sy * 66827) + seed) and 0x7FFFFFFF

proc safeNoise*(x, y: float): float =
  let ix = int(x * 0.1) mod 10000
  let iy = int(y * 0.1) mod 10000
  let h = ((ix * 37471) + (iy * 66827)) xor 101393
  float(h and 0xFFFF) / 32768.0 - 1.0
```

### Test Build Order
1. **Build WASM first**: `./build-web.sh`
2. **Test in browser**: Catches overflow, memory issues
3. **Build native**: `./build.sh`
4. **Test terminal**: Verify performance

### Common WASM-Safe Patterns
```nim
# Safe integer math
let value = clamp(x, 0, maxValue)
let index = x mod arrayLen

# Safe float operations
let dt = clamp(deltaTime, 0.0, 0.1)
let alpha = clamp(life / maxLife, 0.0, 1.0)

# Safe array access
if idx >= 0 and idx < array.len:
  array[idx] = value

# Safe RNG usage
randomize()  # Once at init
for i in 0 ..< count:
  let val = rand(1.0)
```

## Debugging WASM Issues

### Use `echo` for Console Logging
```nim
when defined(emscripten):
  echo "Debug value:", x, " y:", y
```

### Check Browser Console
- Integer overflow → "RuntimeError: unreachable"
- Memory access → "RuntimeError: out of bounds"
- Type mismatch → Compilation error

### Compare Native vs WASM
If native works but WASM fails:
1. Check for integer overflow (huge multipliers)
2. Check for pointer arithmetic (.addr usage)
3. Check for uninitialized RNG or globals
4. Add bounds checking to all array access

## Summary

**WASM is stricter but safer.** Build for WASM first, and you'll write more robust code that works everywhere. The particle system issues we debugged:

1. ✅ Missing `randomize()` → All particles at same position
2. ✅ Wrong render overload → Particles not drawing
3. ✅ Integer overflow in noise → WASM trap/crash
4. ✅ Missing collision flag → Fire particles frozen
5. ✅ Undefined `clampedDt` → Wrong deltaTime values

All caught and fixed by WASM-first development!
