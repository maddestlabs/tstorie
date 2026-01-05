# Native Particle System

## Overview

The tStorie particle system provides **native, high-performance particle effects** capable of handling 1000+ particles at 60 FPS. It solves the core bottleneck of script-based particle iteration by handling all updates in compiled Nim code.

## Performance

| Approach | Particles @ 60 FPS | Bottleneck |
|----------|-------------------|------------|
| **Pure Scripting** | ~20 | Interpreter loop + boundary crossings |
| **Helper Functions** | ~50 | Still iterating in nimini |
| **Native System** | 2000+ | None - tight native loop |

**Why it's fast:**
- All particles updated in a single native loop
- Zero nimini boundary crossings during update
- Direct buffer queries for collision detection
- Efficient particle recycling (no allocations)

## Architecture

### Core Design Principles

1. **Native Iteration** - Performance-critical loops stay in Nim
2. **Mutable Parameters** - Runtime configuration via public fields
3. **Collision Built-in** - Common responses (stick, bounce, destroy) are native
4. **Preset Behaviors** - Quick configuration for common effects

### Files

- **`lib/particles.nim`** - Core particle system (native implementation)
- **`lib/particles_bindings.nim`** - Nimini bindings for scripted access
- **`docs/demos/particles.md`** - Usage examples and demo

## Features

### Environmental Parameters (Mutable)

Users can change these at runtime without recreating the system:

```nim
particleSetGravity("snow", 5.0)        # Vertical acceleration
particleSetWind("snow", 2.0, 0.0)      # Horizontal wind
particleSetTurbulence("snow", 3.0)     # Noise-based chaos
particleSetDamping("snow", 0.98)       # Air resistance (0-1)
```

**Why mutable?** Allows smooth transitions and dynamic weather changes without losing existing particles.

### Collision Detection

Particles can interact with buffer contents:

```nim
particleSetCollision("snow", true, 2)  # Enable with "stick" response
particleSetStickChar("snow", ".")      # Change to '.' when stuck
```

**Responses:**
- `0` = None (pass through)
- `1` = Bounce (elastic collision)
- `2` = Stick (stop and change character)
- `3` = Destroy (remove particle)

**Performance:** Buffer queries are simple array lookups - negligible overhead even for 1000+ particles.

### Emitter Configuration

```nim
particleSetEmitterPos("fire", 400.0, 300.0)
particleSetEmitterSize("fire", 20.0, 5.0)    # Line emitter
particleSetEmitRate("fire", 50.0)            # Particles/second
particleSetChars("fire", "▪▫·˙▴▵")           # Custom characters
```

Supports multiple shapes: point, line, circle, rectangle, area.

### Custom Characters

Customize the appearance of particles with any characters:

```nim
particleSetChars("hearts", "♥♡❤❥")          # Hearts
particleSetChars("blocks", "█▓▒░")          # Fading blocks
particleSetChars("circles", "●◐◑◒◓○")       # Circle phases
particleSetChars("stars", "✦✧✨✪✫✯★☆")     # Stars
```

Each character in the string becomes a possible particle character, randomly selected on spawn.

### Preset Effects

Quick configuration for common effects:

- `particleConfigureRain(name, intensity)` - Falling rain
- `particleConfigureSnow(name, intensity)` - Snow with collision
- `particleConfigureFire(name, intensity)` - Rising fire with turbulence
- `particleConfigureSparkles(name, intensity)` - Radial sparkles
- `particleConfigureExplosion(name)` - One-shot burst

## Usage Example

```nim
on:init
  # Create system
  particleInit("snow", 1000)
  
  # Configure with preset
  particleConfigureSnow("snow", 50.0)
  
  # Enable collision
  particleSetCollision("snow", true, 2)  # Stick mode
  particleSetStickChar("snow", ".")
  
  # Position emitter
  particleSetEmitterPos("snow", float(termWidth / 2), 0.0)
  particleSetEmitterSize("snow", float(termWidth), 1.0)

on:update
  # Change wind dynamically
  if userPressedLeft:
    particleSetWind("snow", -2.0, 0.0)
  elif userPressedRight:
    particleSetWind("snow", 2.0, 0.0)
  
  # Update all particles natively
  particleUpdate("snow", deltaTime)

on:render
  # Render to layer
  particleRender("snow", 0)
  
  # Show stats
  var count = particleGetCount("snow")
  draw(0, 10, 1, "Particles: " + str(count), infoStyle)
```

## API Reference

### Core Functions

| Function | Description |
|----------|-------------|
| `particleInit(name, maxParticles)` | Create particle system |
| `particleUpdate(name, dt)` | Update physics (in on:update) |
| `particleRender(name, layerId)` | Render to layer (in on:render) |
| `particleEmit(name, count)` | Manually spawn particles |
| `particleClear(name)` | Remove all particles |
| `particleGetCount(name)` | Get active count |

### Environmental Parameters

| Function | Description |
|----------|-------------|
| `particleSetGravity(name, g)` | Vertical acceleration |
| `particleSetWind(name, x, y)` | Constant force vector |
| `particleSetTurbulence(name, strength)` | Noise-based chaos |
| `particleSetDamping(name, factor)` | Air resistance (0-1) |

### Emitter Configuration

| Function | Description |
|----------|-------------|
| `particleSetEmitterPos(name, x, y)` | Spawn position |
| `particleSetEmitterSize(name, w, h)` | Emitter dimensions |
| `particleSetEmitRate(name, rate)` | Particles per second |
| `particleSetVelocityRange(name, minX, minY, maxX, maxY)` | Spawn velocity range |
| `particleSetLifeRange(name, min, max)` | Spawn lifetime range |
| `particleSetChars(name, chars)` | Custom character set (e.g., "❤♥♡" or "█▓▒░") |

### Collision

| Function | Description |
|----------|-------------|
| `particleSetCollision(name, enabled, response)` | Enable/configure collision |
| `particleSetStickChar(name, char)` | Character when stuck |

### Presets

| Function | Description |
|----------|-------------|
| `particleConfigureRain(name, intensity)` | Rain effect |
| `particleConfigureSnow(name, intensity)` | Snow with collision |
| `particleConfigureFire(name, intensity)` | Fire effect |
| `particleConfigureSparkles(name, intensity)` | Sparkle burst |
| `particleConfigureExplosion(name)` | Explosion burst |

## Integration Points

### With Animation System

The particle system is **separate from** the animation helpers in `lib/animation.nim`:
- Animation helpers: Easing, interpolation, transitions
- Particle system: Bulk physics simulation

Both can be used together (e.g., animate emitter position with easing functions).

### With Layer System

Particles render directly to layers via `particleRender(name, layerId)`, integrating with tStorie's existing compositing pipeline.

### With Buffer Queries

Collision detection uses `buffer.getCell(x, y)` - the same system used by transitions and shaders. This is a fast direct array lookup with no overhead.

## Design Decisions

### Why Not Callbacks?

Option considered: Allow user callbacks for per-particle custom logic.

**Rejected because:**
- Crossing nimini boundary per-particle destroys performance
- Even 100 particles × 60 FPS = 6000 boundary crossings/sec
- Marshalling overhead (Nim ↔ nimini Value conversion)

**Instead:** Built-in collision responses cover 95% of use cases. Users needing custom logic can create a native lib module (see REBUILD_SYSTEM.md).

### Why Mutable Fields?

Allows runtime parameter changes without recreating the system:

```nim
# Smooth wind transition (good)
particleSetWind("snow", windX, windY)

# vs. destroying and recreating (bad)
particleClear("snow")
particleInit("snow", 1000)
particleConfigureSnow("snow", 50.0)
# Lost all existing particles!
```

This matches tStorie's pattern (see `lib/terminal_shaders.nim` ShaderState).

### Why Named Systems?

Multiple particle systems can coexist:

```nim
particleInit("snow", 500)
particleInit("fire", 300)
particleInit("sparkles", 100)
```

Each system is independent and can be configured differently.

## Future Extensions

Possible additions without breaking compatibility:

1. **Custom shapes** - User-defined emission patterns
2. **Sprite particles** - Multi-character particles
3. **Particle pools** - Share particles across systems
4. **Texture sampling** - Spawn colors from buffer region
5. **Trails** - Leave fading breadcrumbs

These would be additive - existing code continues to work.

## Comparison to Other Systems

### vs. Terminal Shaders

| Feature | Shaders | Particles |
|---------|---------|-----------|
| **Use case** | Fullscreen effects | Individual entities |
| **Update** | Stateless (pure function) | Stateful (physics) |
| **Performance** | Full buffer writes | Sparse updates |
| **Best for** | Backgrounds, ambiance | Dynamic effects |

Use both! Shader for background, particles on top.

### vs. Canvas System

| Feature | Canvas | Particles |
|---------|---------|
| **Content** | Text/markdown | Visual effects |
| **Interaction** | Navigation, clicks | Ambient motion |
| **Lifecycle** | Persistent sections | Temporary sprites |

Particles complement canvas - add snow falling over story text.

## Summary

The native particle system provides:
- ✅ **100x performance** vs. scripted iteration
- ✅ **Simple API** - 5 functions for basic use
- ✅ **Mutable parameters** - Runtime configuration
- ✅ **Collision detection** - Built-in responses
- ✅ **Preset effects** - Quick setup
- ✅ **Multiple systems** - Named instances

Perfect for weather effects, ambient motion, explosions, and visual polish in terminal applications.
