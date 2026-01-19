# Particles: Click Explosion
Creates an explosion of particles when you click the mouse.

## Parameters
- `{name}` - Name of the particle system
- `{count}` - Total particle capacity (default: 200)
- `{burst}` - Number of particles per click (default: 50)
- `{layer}` - Render layer (default: "default")
- `{chars}` - Particle characters (default: "*+·")
- `{minLife}` - Minimum particle lifetime (default: 0.3)
- `{maxLife}` - Maximum particle lifetime (default: 1.0)

```nim on:init
# Initialize explosion particle system
particleInit("{name}", {count})
particleConfigureSparkles("{name}", 8.0)
particleSetChars("{name}", "{chars}")
particleSetEmitRate("{name}", 0.0)  # Don't auto-emit
particleSetLifeRange("{name}", {minLife}, {maxLife})
particleSetVelocityRange("{name}", -20.0, -20.0, 20.0, 20.0)
```

```nim on:input
# Emit explosion burst on mouse click
if event.type == "mouse" and event.action == "press":
  particleSetEmitterPos("{name}", float(event.x), float(event.y))
  particleEmit("{name}", {burst})
```

```nim on:update
# Update explosion particles
particleUpdate("{name}", deltaTime)
```

```nim on:render
# Render explosion particles
particleRender("{name}", "{layer}")
```
