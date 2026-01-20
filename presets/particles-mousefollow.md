# Particles: Mouse Follower
Particles that smoothly follow the mouse cursor.

## Parameters
- `{name}` - Name of the particle system
- `{count}` - Number of particles (default: 50)
- `{smoothing}` - Follow smoothing factor 0-1 (default: 0.1)
- `{speed}` - Follow speed multiplier (default: 5.0)
- `{chars}` - Particle characters (default: "●○◉")
- `{emitRate}` - Particles per second (default: 20.0)

```nim on:init
# Initialize mouse follower particle system
var {name}_x = float(termWidth / 2)
var {name}_y = float(termHeight / 2)

particleInit("{name}", {count})
particleConfigureSparkles("{name}", 8.0)
particleSetChars("{name}", "{chars}")
particleSetEmitRate("{name}", {emitRate})
particleSetEmitterPos("{name}", {name}_x, {name}_y)
particleSetLifeRange("{name}", 0.5, 1.5)
particleSetVelocityRange("{name}", -5.0, -5.0, 5.0, 5.0)
```

```nim on:update
# Smoothly follow mouse position
var mx = float(mouseX)
var my = float(mouseY)
var dx = mx - {name}_x
var dy = my - {name}_y

{name}_x += dx * {smoothing} * deltaTime * {speed}
{name}_y += dy * {smoothing} * deltaTime * {speed}

particleSetEmitterPos("{name}", {name}_x, {name}_y)
particleUpdate("{name}", deltaTime)
```

```nim on:render
# Render follower particles
particleRender("{name}", "default")
```
