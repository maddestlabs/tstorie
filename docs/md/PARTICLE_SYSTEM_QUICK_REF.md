# Particle System Quick Reference

## Minimal Example

```nim
on:init
  particleInit("fx", 500)
  particleConfigureSnow("fx", 50.0)
  particleSetEmitterPos("fx", float(termWidth/2), 0.0)

on:update
  particleUpdate("fx", deltaTime)

on:render
  particleRender("fx", 0)
```

## Common Patterns

### Weather Effects

**Rain:**
```nim
particleInit("rain", 1000)
particleConfigureRain("rain", 80.0)
particleSetEmitterSize("rain", float(termWidth), 1.0)
```

**Snow (with collision):**
```nim
particleInit("snow", 500)
particleConfigureSnow("snow", 40.0)
particleSetEmitterSize("snow", float(termWidth), 1.0)
particleSetCollision("snow", true, 2)  # Stick mode
```

### Fire/Smoke

**Rising fire:**
```nim
particleInit("fire", 300)
particleConfigureFire("fire", 100.0)
particleSetEmitterPos("fire", float(emitterX), float(emitterY))
particleSetEmitterSize("fire", 20.0, 5.0)
```

### Explosions

**Burst effect:**
```nim
particleInit("boom", 200)
particleConfigureExplosion("boom")
particleSetEmitterPos("boom", float(x), float(y))
particleEmit("boom", 100)  # Manual burst
```

### Sparkles/Stars

**Continuous sparkles:**
```nim
particleInit("sparkles", 150)
particleConfigureSparkles("sparkles", 15.0)
particleSetEmitterPos("sparkles", float(x), float(y))
```

### Custom Characters

**Hearts:**
```nim
particleInit("hearts", 200)
particleConfigureSnow("hearts", 30.0)
particleSetChars("hearts", "♥♡❤❥")
```

**Blocks:**
```nim
particleInit("blocks", 200)
particleConfigureSnow("blocks", 40.0)
particleSetChars("blocks", "█▓▒░")
```

**Circles:**
```nim
particleInit("dots", 200)
particleConfigureSparkles("dots", 25.0)
particleSetChars("dots", "●◐◑◒◓○")
```

## Dynamic Control

### Change Wind

```nim
if windLeft:
  particleSetWind("snow", -3.0, 0.0)
elif windRight:
  particleSetWind("snow", 3.0, 0.0)
else:
  particleSetWind("snow", 0.0, 0.0)
```

### Adjust Gravity

```nim
# Normal
particleSetGravity("particles", 9.8)

# Low gravity
particleSetGravity("particles", 2.0)

# Reverse (float up)
particleSetGravity("particles", -5.0)
```

### Toggle Turbulence

```nim
if stormMode:
  particleSetTurbulence("rain", 8.0)
else:
  particleSetTurbulence("rain", 0.5)
```

## Collision Responses

```nim
# Pass through (no collision)
particleSetCollision("fx", false, 0)

# Bounce off surfaces
particleSetCollision("fx", true, 1)

# Stick to surfaces
particleSetCollision("fx", true, 2)
particleSetStickChar("fx", ".")

# Destroy on contact
particleSetCollision("fx", true, 3)
```

## Multiple Systems

```nim
on:init
  # Background snow
  particleInit("bg_snow", 300)
  particleConfigureSnow("bg_snow", 20.0)
  
  # Foreground sparkles
  particleInit("fg_sparkles", 100)
  particleConfigureSparkles("fg_sparkles", 10.0)
  
  # Player fire spell
  particleInit("spell", 200)
  particleConfigureFire("spell", 50.0)

on:update
  particleUpdate("bg_snow", deltaTime)
  particleUpdate("fg_sparkles", deltaTime)
  
  if castingSpell:
    particleUpdate("spell", deltaTime)

on:render
  particleRender("bg_snow", 0)
  particleRender("fg_sparkles", 1)
  
  if castingSpell:
    particleRender("spell", 2)
```

## Performance Tips

1. **Adjust maxParticles** based on needs:
   - Background effects: 200-500
   - Main effects: 500-1000
   - Extreme effects: 1000-2000

2. **Use fadeOut** for natural disappearance:
   ```nim
   # Particles fade as they age (default: true)
   ```

3. **Lifetime management**:
   ```nim
   # Short-lived for bursts
   particleSetLifeRange("explosion", 0.3, 1.0)
   
   # Long-lived for snow
   particleSetLifeRange("snow", 5.0, 10.0)
   ```

4. **Control emission**:
   ```nim
   # Low-rate ambient
   particleSetEmitRate("ambient", 5.0)
   
   # High-rate effects
   particleSetEmitRate("rain", 100.0)
   
   # Manual bursts (no auto-emit)
   particleSetEmitRate("explosion", 0.0)
   particleEmit("explosion", 50)  # Spawn when needed
   ```

## Debugging

**Check active count:**
```nim
var count = particleGetCount("fx")
draw(0, 10, 1, "Active: " + str(count), infoStyle)
```

**Reset system:**
```nim
particleClear("fx")  # Remove all particles
```

**Query capacity:**
```nim
# A system is "full" when activeCount == maxParticles
# New particles won't spawn until others die
```

## Parameter Ranges

| Parameter | Typical Range | Units |
|-----------|--------------|-------|
| Gravity | -10 to 20 | pixels/sec² |
| Wind | -5 to 5 | pixels/sec |
| Turbulence | 0 to 10 | noise strength |
| Damping | 0.9 to 1.0 | factor (1.0 = none) |
| Emit Rate | 0 to 200 | particles/sec |
| Velocity | -30 to 30 | pixels/sec |
| Life | 0.5 to 10 | seconds |

## Integration

**With layers:**
```nim
# Render to specific layer
particleRender("particles", layerId)
```

**With state:**
```nim
# Position based on game state
particleSetEmitterPos("fx", float(player.x), float(player.y))
```

**With input:**
```nim
on:input
  if event.type == "mouse" and event.action == "press":
    particleSetEmitterPos("sparkles", float(event.x), float(event.y))
    particleEmit("sparkles", 20)
```

## Gotchas

❌ **Don't iterate in scripting:**
```nim
# SLOW - defeats the purpose!
for i in 0..<particleCount:
  # Manual update per particle
```

✅ **Do use bulk update:**
```nim
# FAST - native loop
particleUpdate("particles", deltaTime)
```

❌ **Don't recreate constantly:**
```nim
# WASTEFUL - loses particles
particleClear("fx")
particleInit("fx", 500)
```

✅ **Do mutate parameters:**
```nim
# EFFICIENT - keeps particles alive
particleSetWind("fx", newWindX, newWindY)
```

## Advanced: Custom Characters

```nim
# Snow with varied characters
# (Note: chars are set during configure, this shows the concept)
# Future: API to set custom char pool
```

## See Also

- **Full documentation:** `docs/md/PARTICLE_SYSTEM.md`
- **Demo:** `docs/demos/particles.md`
- **Performance guide:** `docs/md/REBUILD_SYSTEM.md`
