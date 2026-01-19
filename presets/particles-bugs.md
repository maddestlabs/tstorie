# Particles: Wandering Bugs
This is a preset for creating wandering bug particles that move randomly around the screen.

## Parameters
- `{name}` - Name of the particle system (default: "bugs")
- `{count}` - Number of particles (default: 100)
- `{speed}` - Movement speed multiplier (default: 3.0)
- `{changeInterval}` - Time between direction changes in seconds (default: 1.0)
- `{chars}` - Characters to use for particles (default: "🐛🐜🐝")
- `{size}` - Particle size (default: 10.0)

```nim on:init
# Initialize wandering bug particle system
var {name}_x = float(termWidth / 2)
var {name}_y = float(termHeight / 2)
var {name}_dir_x = rand(-1.0..1.0)
var {name}_dir_y = rand(-1.0..1.0)
var {name}_timer = 0.0

particleInit("{name}", {count})
particleConfigureSparkles("{name}", {size})
particleSetChars("{name}", "{chars}")
particleSetEmitterPos("{name}", {name}_x, {name}_y)
```

```nim on:update
# Update bug movement - wander randomly with periodic direction changes
{name}_timer += deltaTime

if {name}_timer > {changeInterval}:
  {name}_dir_x = rand(-1.0..1.0)
  {name}_dir_y = rand(-1.0..1.0)
  {name}_timer = 0.0

{name}_x += {name}_dir_x * {speed} * deltaTime
{name}_y += {name}_dir_y * {speed} * deltaTime

# Wrap around screen edges
if {name}_x < 0: {name}_x = float(termWidth)
if {name}_x > float(termWidth): {name}_x = 0
if {name}_y < 0: {name}_y = float(termHeight)
if {name}_y > float(termHeight): {name}_y = 0

particleSetEmitterPos("{name}", {name}_x, {name}_y)
particleUpdate("{name}", deltaTime)
```

```nim on:render
# Render the bug particles
particleRender("{name}", "default")
```
