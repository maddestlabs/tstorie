# Noise Algorithm Visual Guide

Quick reference for choosing the right noise primitive for your effect.

## Perlin Noise
```
Pattern: Smooth, rolling hills
├─ 2D: Clouds, terrain heightmap, organic textures
└─ 3D: Volumetric clouds, 3D terrain, animated fog

Scale=50          Scale=100         Scale=200
█▓▒░  ░▒▓█      ▓▓▓░░░▒▒▒▓       ▒▒▒▒▒▒▒▒▒▒
▓▒░   ░░▒▓█     ▓▓░░░░▒▒▒▓       ▒▒▒▒▒▒▒▒▒▒
▒░    ░░░▒▓     ▓░░░░░▒▒▓▓       ▒▒▒▒▒▒▒▒▒▒
░     ░░░░▒     ░░░░░░▒▓▓▓       ▒▒▒▒▒▒▒▒▒▒
      ░░░░░     ░░░░░▒▒▓▓        ▓▓▓▓▓▓▓▓▓▓

Characteristics:
• Smooth gradients
• No obvious grid artifacts
• Natural-looking
• Medium computation cost
```

## Simplex Noise
```
Pattern: Similar to Perlin, slightly more organic
├─ 2D: Faster clouds, terrain (20% speed boost)
└─ 3D: Volumetric effects (50% speed boost!)

▓▓▒░   ░▒▓█      (Similar appearance to Perlin)
▒░░    ░░▒▓      (Less directional bias)
░░     ░░░▒      (Fewer gradients needed)
░      ░░░░      (Triangular grid, not square)

Characteristics:
• Similar to Perlin but faster
• Less directional artifacts
• Better for 3D (significant speedup)
• Modern standard (Ken Perlin's improved algorithm)
```

## Worley/Cellular Noise
```
Pattern: Organic cells, like stone or water
Use f1 for cells, f2-f1 for cracks

f1 (closest)     f2-f1 (cracks)    Combined
█████  ████      ·····  ····       █████··████
████    ███      ····    ···       ████···████
███      ██      ···      ··       ███····███
██        █      ··        ·       ██·····█
█          █     ·          ·      █······█

Characteristics:
• Cell/bubble patterns
• f1 = distance to nearest point
• f2 = distance to second nearest
• f2-f1 = crack/vein patterns
• Perfect for stone, cells, caustics
```

## Ridged Noise
```
Pattern: Sharp mountain ridges, crystals

Standard FBM      Ridged FBM
▓▓▒░   ░▒▓█      ▓█▓▒░  ░▒█▓
▒░░    ░░▒▓      ▓█▓░   ░█▓▓
░░     ░░░▒      ▒█░    ░█▒▒
░      ░░░░      ░█     █░░░

Characteristics:
• Inverts and sharpens noise
• Creates ridge lines
• Perfect for mountains, crystals
• More dramatic than standard FBM
```

## Billow Noise
```
Pattern: Puffy clouds, steam

Standard FBM      Billow FBM
▓▓▒░   ░▒▓█      ▓▓▓░   ░▓▓▓
▒░░    ░░▒▓      ▒▒░    ░▒▒▒
░░     ░░░▒      ░░     ░░░░
░      ░░░░      ░      ░░░░

Characteristics:
• Takes absolute value of noise
• Creates puffy, billowing shapes
• Perfect for clouds, smoke, steam
• More rounded than standard FBM
```

## Turbulence Noise
```
Pattern: Chaotic, swirling

Standard FBM      Turbulence
▓▓▒░   ░▒▓█      ▓▒░█▓░▒▓█░
▒░░    ░░▒▓      ░█▒░▓█░▒▓▒
░░     ░░░▒      █▓░▒░█▒░▓░
░      ░░░░      ▒░▓█░▒▓░█▓

Characteristics:
• Chaotic, highly varied
• Lots of high-frequency detail
• Perfect for fire, magic effects
• More energetic than standard FBM
```

## Domain Warping
```
Pattern: Complex, organic, impossible with plain noise

Before Warp       After Warp
▓▓▒░   ░▒▓█      ▓▓█▒▒░░░▓██
▒░░    ░░▒▓      ░▓▒░░▓▓▒░▓█
░░     ░░░▒      ░░▓▓██▓░░▒▓
░      ░░░░      ░▒▓█▓▒░░░░▓

Characteristics:
• Warps coordinates using noise
• Creates swirls, distortions
• Perfect for wood grain, marble
• Can be applied multiple times
• Most organic-looking result
```

## Quick Selection Guide

| Effect You Want | Algorithm | Parameters |
|-----------------|-----------|------------|
| Basic terrain | `perlinNoise2D()` | scale=100, seed=any |
| Fast 3D fog | `simplexNoise3D()` | scale=50, seed=any |
| Stone texture | `worleyNoise2D()` | scale=100, use f1 |
| Cracks/veins | `worleyNoise2D()` | scale=100, use f2-f1 |
| Mountains | `ridgedNoise2D()` | octaves=4, scale=80 |
| Clouds | `billowNoise2D()` | octaves=3, scale=60 |
| Fire | `turbulenceNoise2D()` | octaves=3, scale=40 |
| Wood grain | `warpedNoise2D()` | octaves=4, warp=200 |
| Marble | `warpedNoise2D()` | octaves=4, warp=300 |
| Water caustics | `worleyNoise2D()` + animation | scale=80, animate coordinates |

## Combining Techniques

### Layered Effects
```nim
# Terrain with rocky outcrops
let base = perlinNoise2D(x, y, 100, 42)
let (rocks, _) = worleyNoise2D(x, y, 50, 123)
let final = (base * 7 + rocks * 3) div 10  # 70% perlin, 30% worley
```

### Animated Effects
```nim
# Flowing water
let time = getTime()
let animX = x + isin((time * 5 + y * 10) % 3600) div 100
let animY = y + icos((time * 4 + x * 12) % 3600) div 100
let (f1, f2) = worleyNoise2D(animX * 2, animY * 2, 80, 456)
```

### Masked Effects
```nim
# Clouds with clear sky
let clouds = billowNoise2D(x, y, 3, 60, 100)
let mask = perlinNoise2D(x, y, 200, 200)  # Large-scale mask
let visible = if mask > 32768: clouds else: 0  # Only show clouds in masked areas
```

## Performance Tips

1. **2D vs 3D**: Use 2D when possible (3x faster)
2. **Simplex for 3D**: Always prefer Simplex in 3D (50% faster than Perlin)
3. **Octaves**: Each octave doubles computation time
4. **Scale**: Larger scales = faster (fewer cell lookups)
5. **Pre-compute**: For static patterns, compute once and cache
6. **GPU**: All algorithms designed for parallel execution

## Scale Guidelines

| Scale Value | Effect | Use Case |
|-------------|--------|----------|
| 10-30 | Very fine detail | Micro textures, noise |
| 40-80 | Medium detail | Fire, clouds, water |
| 100-200 | Large features | Terrain, large clouds |
| 300+ | Macro patterns | Biomes, large-scale variation |

## Seed Guidelines

- **Same seed** = identical pattern (deterministic)
- **Different seeds** = completely different pattern
- **Seed + offset** = related but different (e.g., seed+1, seed+2 for octaves)
- **Seed from coordinates** = consistent per-pixel patterns

## WebGPU Readiness

All algorithms:
✅ Integer operations only  
✅ No platform-specific functions  
✅ Parallel-safe (no shared state)  
✅ Constant memory usage  
✅ Ready for compute shader translation  

Coming soon: `noise.toWGSL()` → WGSL compute shader code!

---

**Need help choosing?** Start with Perlin for natural patterns, Simplex for speed, Worley for cells!
