# Procedural Generation Primitives Demo

```nimini
# Example: Generate deterministic terrain with noise

type TerrainGenerator = object
  rng: Rand
  width: int
  height: int
  seed: int

proc newTerrainGenerator(seed: int, w: int, h: int): TerrainGenerator =
  TerrainGenerator(
    rng: initRand(seed),
    width: w,
    height: h,
    seed: seed
  )

proc generateTerrain(gen: var TerrainGenerator): seq[seq[int]] =
  var terrain = newSeq[seq[int]](gen.height)
  
  for y in 0..<gen.height:
    terrain[y] = newSeq[int](gen.width)
    for x in 0..<gen.width:
      # Use fractal noise for natural-looking terrain
      let noise = fractalNoise2D(x * 10, y * 10, 4, 100, gen.seed)
      
      # Map noise [0..65535] to height levels [0..10]
      terrain[y][x] = map(noise, 0, 65535, 0, 10)
  
  return terrain

proc visualizeTerrain(terrain: seq[seq[int]]): string =
  var output = ""
  let chars = " .:-=+*#%@"
  
  for row in terrain:
    for height in row:
      output += chars[height]
    output += "\n"
  
  return output

# Generate deterministic terrain
var gen = newTerrainGenerator(12345, 60, 20)
var terrain = gen.generateTerrain()
echo visualizeTerrain(terrain)

# Generate again with same seed - will be identical!
var gen2 = newTerrainGenerator(12345, 60, 20)
var terrain2 = gen2.generateTerrain()
echo "\nRegenerated (should be identical):"
echo visualizeTerrain(terrain2)
```

```nimini
# Example: Generate dungeon with rooms and corridors

type SimpleDungeonGen = object
  rng: Rand
  width: int
  height: int
  grid: seq[seq[int]]

const
  WALL = 0
  FLOOR = 1
  DOOR = 2

proc newSimpleDungeonGen(seed: int, w: int, h: int): SimpleDungeonGen =
  var grid = newSeq[seq[int]](h)
  for y in 0..<h:
    grid[y] = newSeq[int](w)
    for x in 0..<w:
      grid[y][x] = WALL
  
  SimpleDungeonGen(
    rng: initRand(seed),
    width: w,
    height: h,
    grid: grid
  )

proc addRoom(gen: var SimpleDungeonGen, room: IRect) =
  for y in room.y..<(room.y + room.h):
    if y >= 0 and y < gen.height:
      for x in room.x..<(room.x + room.w):
        if x >= 0 and x < gen.width:
          gen.grid[y][x] = FLOOR

proc generateRooms(gen: var SimpleDungeonGen, roomCount: int) =
  var attempts = 0
  var placed = 0
  
  while placed < roomCount and attempts < 100:
    attempts += 1
    
    # Random room size
    let w = gen.rng.rand(5, 12)
    let h = gen.rng.rand(5, 12)
    let x = gen.rng.rand(1, gen.width - w - 1)
    let y = gen.rng.rand(1, gen.height - h - 1)
    
    let room = rect(x, y, w, h)
    
    # Check if room overlaps existing rooms
    var overlaps = false
    for oy in (room.y - 1)..<(room.y + room.h + 1):
      if oy >= 0 and oy < gen.height:
        for ox in (room.x - 1)..<(room.x + room.w + 1):
          if ox >= 0 and ox < gen.width:
            if gen.grid[oy][ox] == FLOOR:
              overlaps = true
              break
        if overlaps:
          break
    
    if not overlaps:
      gen.addRoom(room)
      placed += 1

proc visualizeDungeon(gen: SimpleDungeonGen): string =
  var output = ""
  for row in gen.grid:
    for cell in row:
      case cell
      of WALL: output += "#"
      of FLOOR: output += "."
      of DOOR: output += "+"
      else: output += "?"
    output += "\n"
  return output

# Generate dungeon
var dgen = newSimpleDungeonGen(54321, 60, 25)
dgen.generateRooms(8)
echo visualizeDungeon(dgen)
```

```nimini
# Example: Procedural particle colors using HSV

type ParticleSystem = object
  rng: Rand
  particles: seq[Particle]

type Particle = object
  x: int
  y: int
  vx: int
  vy: int
  color: IColor
  life: int

proc newParticleSystem(seed: int): ParticleSystem =
  ParticleSystem(
    rng: initRand(seed),
    particles: @[]
  )

proc spawnParticle(ps: var ParticleSystem, x: int, y: int) =
  # Generate particle with procedural color
  let hue = ps.rng.rand(360)  # Random hue
  let sat = 800 + ps.rng.rand(200)  # High saturation (800-1000)
  let val = 800 + ps.rng.rand(200)  # High value (800-1000)
  
  let color = hsvToRgb(hue, sat, val)
  
  let particle = Particle(
    x: x,
    y: y,
    vx: ps.rng.rand(-50, 50),
    vy: ps.rng.rand(-100, -20),  # Mostly upward
    color: color,
    life: 100
  )
  
  ps.particles.add(particle)

proc updateParticles(ps: var ParticleSystem) =
  var i = 0
  while i < ps.particles.len:
    ps.particles[i].x += ps.particles[i].vx
    ps.particles[i].y += ps.particles[i].vy
    ps.particles[i].vy += 2  # Gravity
    ps.particles[i].life -= 1
    
    if ps.particles[i].life <= 0:
      ps.particles.delete(i)
    else:
      i += 1

# Demo
var ps = newParticleSystem(99999)
echo "Spawning particles with deterministic colors..."
for i in 0..<10:
  ps.spawnParticle(400, 300)
  echo "Particle ", i, " color: RGB(", ps.particles[i].color.r, ",", 
       ps.particles[i].color.g, ",", ps.particles[i].color.b, ")"
```

```nimini
# Example: Cellular automata cave generation

proc generateCave(seed: int, width: int, height: int, steps: int): seq[seq[int]] =
  # Initialize with random noise
  var grid = newSeq[seq[int]](height)
  var rng = initRand(seed)
  
  for y in 0..<height:
    grid[y] = newSeq[int](width)
    for x in 0..<width:
      # 45% chance of wall
      if rng.rand(100) < 45:
        grid[y][x] = 1
      else:
        grid[y][x] = 0
  
  # Run cellular automata
  # Rule: If 5+ neighbors are walls, become wall. If 4+ are floors, become floor.
  for step in 0..<steps:
    let birthRule = @[5, 6, 7, 8]
    let surviveRule = @[4, 5, 6, 7, 8]
    grid = cellularAutomata(grid, birthRule, surviveRule)
  
  return grid

proc visualizeCave(grid: seq[seq[int]]): string =
  var output = ""
  for row in grid:
    for cell in row:
      if cell == 1:
        output += "#"
      else:
        output += " "
    output += "\n"
  return output

# Generate cave
echo "Generating cave with cellular automata..."
var cave = generateCave(77777, 60, 25, 5)
echo visualizeCave(cave)

# Regenerate with same seed - identical!
echo "\nRegenerating (should be identical):"
var cave2 = generateCave(77777, 60, 25, 5)
echo visualizeCave(cave2)
```

```nimini
# Example: Procedural sound generation (SFXR-style)

type SoundGen = object
  rng: Rand
  waveType: int
  frequency: int
  frequencySlide: int
  attack: int
  sustain: int
  decay: int
  vibratoDepth: int
  vibratoSpeed: int

proc newSoundGen(seed: int): SoundGen =
  var rng = initRand(seed)
  
  SoundGen(
    rng: rng,
    waveType: rng.rand(3),  # 0=square, 1=saw, 2=sine, 3=noise
    frequency: rng.rand(100, 2000),
    frequencySlide: rng.rand(-500, 500),
    attack: rng.rand(10, 100),
    sustain: rng.rand(50, 300),
    decay: rng.rand(10, 200),
    vibratoDepth: rng.rand(0, 50),
    vibratoSpeed: rng.rand(0, 20)
  )

proc describeSound(sg: SoundGen): string =
  var waveTypeName = "unknown"
  case sg.waveType
  of 0: waveTypeName = "square"
  of 1: waveTypeName = "sawtooth"
  of 2: waveTypeName = "sine"
  of 3: waveTypeName = "noise"
  
  return "Sound: " & waveTypeName & " wave, " & 
         $sg.frequency & "Hz, " &
         "envelope(" & $sg.attack & "," & $sg.sustain & "," & $sg.decay & "), " &
         "vibrato(" & $sg.vibratoDepth & "," & $sg.vibratoSpeed & ")"

# Generate sounds
echo "Generating sounds with seeds..."
for i in 0..<5:
  let seed = 10000 + i * 1000
  let sound = newSoundGen(seed)
  echo "Seed ", seed, ": ", sound.describeSound()

echo "\nRegenerating seed 11000 - should match above:"
let sound2 = newSoundGen(11000)
echo "Seed 11000: ", sound2.describeSound()
```

```nimini
# Example: Line art generation with Bresenham

type Drawing = object
  width: int
  height: int
  pixels: seq[seq[int]]

proc newDrawing(w: int, h: int): Drawing =
  var pixels = newSeq[seq[int]](h)
  for y in 0..<h:
    pixels[y] = newSeq[int](w)
  Drawing(width: w, height: h, pixels: pixels)

proc drawLine(d: var Drawing, x0: int, y0: int, x1: int, y1: int) =
  let points = bresenhamLine(x0, y0, x1, y1)
  for (x, y) in points:
    if x >= 0 and x < d.width and y >= 0 and y < d.height:
      d.pixels[y][x] = 1

proc drawCircle(d: var Drawing, cx: int, cy: int, r: int) =
  let points = circle(cx, cy, r)
  for (x, y) in points:
    if x >= 0 and x < d.width and y >= 0 and y < d.height:
      d.pixels[y][x] = 1

proc visualize(d: Drawing): string =
  var output = ""
  for row in d.pixels:
    for pixel in row:
      if pixel == 1:
        output += "*"
      else:
        output += " "
    output += "\n"
  return output

# Generate procedural line art
echo "Generating procedural line art..."
var drawing = newDrawing(60, 25)
var rng = initRand(55555)

# Draw random lines
for i in 0..<8:
  let x0 = rng.rand(drawing.width - 1)
  let y0 = rng.rand(drawing.height - 1)
  let x1 = rng.rand(drawing.width - 1)
  let y1 = rng.rand(drawing.height - 1)
  drawing.drawLine(x0, y0, x1, y1)

# Draw circles
drawing.drawCircle(30, 12, 8)
drawing.drawCircle(30, 12, 5)

echo visualize(drawing)
```

## Key Takeaways

1. **All primitives are deterministic** - Same seed = same result, always
2. **Composable design** - Mix and match primitives like nodes
3. **Integer-based** - No floating point drift between implementations
4. **Isolated RNG** - Each generator has its own random state
5. **Native speed** - Primitives are implemented in native Nim for performance

## Node-Based Workflow (TiXL/Tool3 Style)

Think of each primitive as a node:
- **Input nodes**: Seeds, coordinates, parameters
- **Processing nodes**: Noise, hash, easing, lerp
- **Output nodes**: Colors, positions, values

Connect them together to create complex procedural systems!
