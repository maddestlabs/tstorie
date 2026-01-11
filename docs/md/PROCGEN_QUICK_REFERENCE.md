# Procedural Generation Primitives - Quick Reference

## 🎲 RNG (Always Required!)

```nim
var rng = initRand(seed)          # Create isolated RNG
let n = rng.rand(100)              # 0..100 inclusive
let n = rng.rand(10, 20)           # 10..20 inclusive
```

## 🔢 Math

```nim
idiv(7, 2)           # 3 (integer division)
imod(7, 3)           # 1 (modulo)
clamp(x, 0, 100)     # Constrain to range
wrap(x, 0, 100)      # Wrap around range
lerp(0, 100, 500)    # Linear interpolate (t=0..1000)
map(x, 0, 10, 0, 100) # Map range to range
sign(x)              # -1, 0, or 1
```

## 🎨 Noise & Hash

```nim
intHash(x, seed)                    # [0..65535]
intHash2D(x, y, seed)               # [0..65535]
valueNoise2D(x, y, seed)            # [0..65535]
smoothNoise2D(x, y, scale, seed)    # [0..65535] smooth
fractalNoise2D(x, y, octaves, scale, seed)  # [0..65535] fractal
```

**Usage**: Terrain, textures, clouds, organic patterns

## 📐 Geometry

```nim
let r = rect(x, y, w, h)         # Create rectangle
let (cx, cy) = r.center()        # Get center
r.contains(x, y)                 # Point inside?
overlaps(r1, r2)                 # Rectangles overlap?
r.grow(5)                        # Expand by 5
r.shrink(5)                      # Contract by 5
```

## 📏 Distance

```nim
manhattanDist(x1, y1, x2, y2)    # Grid distance (4-way)
chebyshevDist(x1, y1, x2, y2)    # Grid distance (8-way)
euclideanDist(x1, y1, x2, y2)    # True distance
euclideanDistSq(x1, y1, x2, y2)  # Squared (faster)
```

## ✏️ Lines & Curves

```nim
let points = bresenhamLine(x0, y0, x1, y1)  # All points on line
let points = circle(cx, cy, radius)          # All points on circle
floodFill(grid, x, y, fillValue, targetValue)  # Fill area
```

## 🎭 Collections (Need RNG!)

```nim
shuffle(rng, arr)                           # Shuffle in place
let items = sample(rng, arr, 5)             # Pick 5 random
let item = choice(rng, arr)                 # Pick 1 random
let item = weightedChoice(rng, items, weights)  # Weighted pick
```

## 🌊 Easing (t=0..1000)

```nim
easeLinear(t)       # No easing
easeInQuad(t)       # Slow start
easeOutQuad(t)      # Slow end
easeInOutQuad(t)    # Slow both ends
easeInCubic(t)      # Slower start
easeOutCubic(t)     # Slower end
```

**Usage**: Animations, smooth transitions, camera movement

## 🎨 Patterns

```nim
checkerboard(x, y, size)              # 0 or 1
stripes(x, size)                      # 0 or 1
concentricCircles(x, y, cx, cy, spacing)  # Ring number
spiralPattern(x, y, cx, cy, rotation)     # [0..65535]
```

## 🗺️ Grid

```nim
inBounds(x, y, width, height)        # Inside grid?
neighbors4(x, y)                     # 4-connected neighbors
neighbors8(x, y)                     # 8-connected neighbors
cellularAutomata(grid, birth, survive)  # CA step
```

**CA Example**: `cellularAutomata(grid, @[3], @[2,3])`  # Conway's Life

## 🎨 Color (RGB 0..255)

```nim
let c = icolor(r, g, b)              # Create color
let i = c.toInt()                    # To 0xRRGGBB
let c = fromInt(0xFF8040)            # From integer
let c = lerpColor(c1, c2, 500)       # Interpolate (t=0..1000)
let c = hsvToRgb(h, s, v)            # HSV (h=0..360, s/v=0..1000)
```

## 🎯 Common Patterns

### Terrain Generation
```nim
var rng = initRand(seed)
for y in 0..<height:
  for x in 0..<width:
    let noise = fractalNoise2D(x*10, y*10, 4, 100, seed)
    terrain[y][x] = map(noise, 0, 65535, 0, 10)
```

### Dungeon Rooms
```nim
var rng = initRand(seed)
for i in 0..<roomCount:
  let w = rng.rand(5, 12)
  let h = rng.rand(5, 12)
  let x = rng.rand(1, width - w - 1)
  let y = rng.rand(1, height - h - 1)
  addRoom(rect(x, y, w, h))
```

### Particle Colors
```nim
var rng = initRand(seed)
let hue = rng.rand(360)
let color = hsvToRgb(hue, 1000, 1000)  # Full saturation/value
```

### Cave Generation
```nim
# Initialize with noise
var rng = initRand(seed)
for y/x: grid[y][x] = if rng.rand(100) < 45: 1 else: 0

# Run CA
for step in 0..<5:
  grid = cellularAutomata(grid, @[5,6,7,8], @[4,5,6,7,8])
```

## ⚠️ Critical Rules

1. **Always use isolated RNG**: `var rng = initRand(seed)`
2. **Use `div` not `/`**: Integer division only
3. **Use `rand(N)` not `rand(0,N)`**: Consistent form
4. **Shuffle backward**: Fisher-Yates requires countdown
5. **Document ranges**: Know your [min..max] values

## 🔗 Import

```nim
# Native Nim
import lib/primitives

# Nimini script  
# Functions automatically available!
```

## 📊 Value Ranges

| Function | Range |
|----------|-------|
| Noise functions | 0..65535 |
| Colors (RGB) | 0..255 |
| Easing | 0..1000 (input/output) |
| HSV hue | 0..360 |
| HSV sat/val | 0..1000 |
| lerp t | 0..1000 |

## 🎓 Tips

- **Start with noise** for natural patterns
- **Use easing** for smooth motion
- **Combine primitives** for complex effects
- **Test with multiple seeds** to verify determinism
- **Profile before optimizing** - integers are already fast!

---

**See also**: 
- `PROCEDURAL_GENERATION_PRIMITIVES.md` - Full API docs
- `docs/demos/procgen_demo.md` - Working examples
- `tests/test_procgen_determinism.nim` - Test suite
