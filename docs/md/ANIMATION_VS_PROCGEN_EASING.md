# Animation vs Procedural Generation - Easing Functions

## Two Different Use Cases

### lib/animation.nim - UI/Visual Animations
**Purpose**: Real-time visual animations and transitions

**Characteristics**:
- Float input (0.0..1.0) - standard animation range
- Float output - smooth visual transitions
- More variety (Sine, Bounce, Elastic variants)
- Coupled with UI types (Color, Style, particles)

**Use when**:
- Animating UI elements
- Transitions between screens
- Particle effects
- Camera movements
- Any visual animation that runs in real-time

**Example**:
```nim
var trans = newTransition(2.0, easeInOutCubic)
trans.update(deltaTime)
let progress = trans.easedProgress()  # 0.0..1.0
lerpColor(startColor, endColor, progress)
```

### lib/procgen_primitives.nim - Procedural Generation
**Purpose**: Deterministic seed-based procedural generation

**Characteristics**:
- **Integer input** (0..1000) - fixed-point precision
- **Integer output** - no floating point drift
- **Identical results** native vs scripted
- Pure functions, no dependencies
- **Critical for seed-based systems**

**Use when**:
- SFXR-style sound generation
- Procedural terrain/dungeon generation
- Seeded particle distributions
- Any generation that must be **reproducible from a seed**

**Example**:
```nim
var rng = initRand(seed)
for i in 0..<100:
  let t = (i * 1000) div 100  # 0..1000
  let eased = easeInQuad(t)   # Deterministic easing
  let value = map(eased, 0, 1000, minVal, maxVal)
  # Same seed will ALWAYS produce same sequence
```

## Why Both Are Needed

### The Float Drift Problem
```nim
# Float version (animation.nim)
proc easeInQuad(t: float): float = t * t

# On different platforms or after many calculations:
# easeInQuad(0.5) might give:
#   Native:   0.25000000001
#   Scripted: 0.24999999999
# After 1000 iterations, these tiny differences compound!
```

### The Integer Solution
```nim
# Integer version (procgen_primitives.nim)  
proc easeInQuad(t: int): int = (t * t) div 1000

# ALWAYS gives exact same result:
# easeInQuad(500) = 250  (on ALL platforms, ALL implementations)
```

## Migration Guide

If you're using easing for procedural generation:

**Before** (using animation.nim - WRONG for proc-gen):
```nim
var rng = initRand(seed)
let t = rng.randFloat()  # 0.0..1.0
let eased = easeInQuad(t)  # Float! Will drift!
```

**After** (using procgen_primitives.nim - CORRECT):
```nim
var rng = initRand(seed)
let t = rng.rand(1000)  # 0..1000
let eased = easeInQuad(t)  # Integer! Deterministic!
```

## Naming Convention

To avoid confusion, consider these patterns:

**Animation easing** (float): Used directly for visual effects
```nim
import lib/animation
let progress = easeInQuad(animProgress)  # 0.0..1.0
```

**Procedural easing** (int): Import explicitly when needed
```nim
import lib/procgen_primitives
let curveValue = easeInQuad(t)  # 0..1000
```

Or use qualified imports:
```nim
import lib/animation as anim
import lib/procgen_primitives as procgen

anim.easeInQuad(0.5)      # Float version
procgen.easeInQuad(500)   # Integer version
```

## Summary

| Feature | animation.nim | procgen_primitives.nim |
|---------|--------------|------------------------|
| Input type | `float` (0.0..1.0) | `int` (0..1000) |
| Output type | `float` | `int` |
| Deterministic? | ❌ (float drift) | ✅ (exact integers) |
| Use for UI | ✅ Perfect | ❌ Overkill |
| Use for proc-gen | ❌ Will drift | ✅ Essential |
| Seed-based systems | ❌ Unreliable | ✅ Required |
| Real-time animation | ✅ Ideal | ⚠️ Works but unconventional |

**Conclusion**: Keep both! They solve different problems. The integer-based easing is **critical** for deterministic procedural generation.
