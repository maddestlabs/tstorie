---
title: "Primitive-Based Shader Effects"
description: "Demonstrating how noise primitives create complex visual effects"
---

# 🎨 Primitive-Based Shader Demo

This demo shows how TStorie's unified primitives can build complex shader effects using simple, composable noise functions.

## Example 1: Animated Clouds (Perlin + FBM)

```nimini
on:frame {
  let time = getTime()
  
  for y in 0..<height {
    for x in 0..<width {
      # Animate by offsetting X coordinate
      let animX = x + (time / 10)
      
      # Multi-octave Perlin noise for clouds
      let cloud = perlinNoise2D(animX, y, 50, 42)
      
      # Map to grayscale character
      let intensity = cloud / 2048  # 0..31
      let char = " .',:;clodxkO0KXN"[intensity]
      
      drawChar(x, y, char, 0xCCCCCC)
    }
  }
}
```

## Example 2: Stone Texture (Worley Noise)

```nimini
on:load {
  for y in 0..<height {
    for x in 0..<width {
      # Worley noise creates cellular patterns
      let (f1, f2) = worleyNoise2D(x * 3, y * 3, 100, 123)
      
      # Use f1 for base stone color
      let baseColor = f1 / 256  # 0..255
      
      # Use f2-f1 for cracks
      let crack = (f2 - f1) / 1024
      let crackMask = if crack < 8: 0 else: 255
      
      let r = baseColor
      let g = baseColor - crack * 10
      let b = baseColor - crack * 15
      
      drawChar(x, y, "▓", rgb(r, g, b))
    }
  }
}
```

## Example 3: Mountain Ridges (Ridged Noise)

```nimini
on:load {
  for y in 0..<height {
    for x in 0..<width {
      # Ridged noise creates sharp mountain peaks
      let height = ridgedNoise2D(x * 2, y * 2, 4, 80, 999)
      
      # Height-based coloring
      let char = if height < 20000: "." 
                 elif height < 35000: "^"
                 elif height < 50000: "▲"
                 else: "█"
      
      let color = if height < 20000: 0x228B22  # Forest green
                  elif height < 35000: 0x8B7355  # Brown
                  elif height < 50000: 0x808080  # Gray
                  else: 0xFFFFFF  # White snow
      
      drawChar(x, y, char, color)
    }
  }
}
```

## Example 4: Marble (Domain Warping)

```nimini
on:load {
  for y in 0..<height {
    for x in 0..<width {
      # Warp coordinate space for organic marble effect
      let marble = warpedNoise2D(x * 2, y * 2, 4, 60, 200, 555)
      
      # Enhance with sine wave for marble veins
      let vein = isin((marble / 18) % 3600)  # Sine in decidegrees
      let intensity = (marble + vein) / 512
      
      # Marble color palette
      let r = clamp(220 + intensity / 4, 0, 255)
      let g = clamp(220 + intensity / 3, 0, 255)
      let b = clamp(230 + intensity / 5, 0, 255)
      
      drawChar(x, y, "▒", rgb(r, g, b))
    }
  }
}
```

## Example 5: Fire Effect (Turbulence + Animation)

```nimini
on:frame {
  let time = getTime()
  
  for y in 0..<height {
    for x in 0..<width {
      # Rising animation (move Y down over time)
      let animY = y - (time / 5)
      
      # Turbulence creates chaotic fire movement
      let fire = turbulenceNoise2D(x * 3, animY * 4, 3, 40, 777)
      
      # Fade out toward top
      let fade = clamp((height - y) * 2048, 0, 65535)
      let intensity = (fire * fade) / 65535
      
      # Fire color gradient
      let color = colorFire(intensity / 256)
      
      # Fire characters by intensity
      let char = if intensity < 8000: " "
                 elif intensity < 20000: "."
                 elif intensity < 35000: "*"
                 elif intensity < 50000: "▒"
                 else: "█"
      
      drawChar(x, y, char, rgb(color.r, color.g, color.b))
    }
  }
}
```

## Example 6: Plasma Effect (Simplex + Sine Waves)

```nimini
on:frame {
  let time = getTime()
  
  for y in 0..<height {
    for x in 0..<width {
      # Combine multiple sine-based patterns
      let wave1 = isin((x * 18 + time * 2) % 3600)
      let wave2 = isin((y * 22 - time * 3) % 3600)
      
      # Add simplex noise for organic variation
      let noise = simplexNoise2D(x + time, y, 50, 321)
      
      # Combine waves and noise
      let plasma = (wave1 + wave2) / 2 + (noise - 32768) / 32
      
      # Map to rainbow colors
      let hue = ((plasma + 1000) * 360) / 2000
      let color = hsvToRgb(hue % 360, 1000, 1000)
      
      drawChar(x, y, "█", rgb(color.r, color.g, color.b))
    }
  }
}
```

## Example 7: Water Caustics (Worley + Animation)

```nimini
on:frame {
  let time = getTime()
  
  for y in 0..<height {
    for x in 0..<width {
      # Animate water movement
      let animX = x + isin((time * 5 + y * 10) % 3600) / 100
      let animY = y + icos((time * 4 + x * 12) % 3600) / 100
      
      # Worley noise creates water cells
      let (f1, f2) = worleyNoise2D(animX * 2, animY * 2, 80, 456)
      
      # Caustics are the edges between cells
      let caustic = (f2 - f1)
      let intensity = clamp(caustic / 128, 0, 255)
      
      # Ocean blue with bright caustic highlights
      let r = intensity / 8
      let g = 100 + intensity / 4
      let b = 180 + intensity / 3
      
      let char = if intensity < 50: "~"
                 elif intensity < 150: "≈"
                 else: "⋈"
      
      drawChar(x, y, char, rgb(r, g, b))
    }
  }
}
```

## Key Takeaways

**What makes this powerful:**

1. **Composability** - Combine primitives (noise + sine + color palettes) to create complex effects
2. **Determinism** - Same seed = same pattern every time
3. **Performance** - Integer math, no float operations
4. **Reusability** - Same primitives work for shaders, audio, world generation
5. **WebGPU Ready** - These patterns will translate directly to compute shaders

**Next Evolution:**

When we implement the composable noise API:
```nimini
let terrain = noise(Perlin)
  .seed(42)
  .scale(100)
  .octaves(4)
  .domainWarp(200)
  .ridged()

let value = terrain.sample2D(x, y)
```

This will enable:
- **GPU Compilation**: `terrain.toWGSL()` → compute shader code
- **Audio Sampling**: `terrain.toAudioFunc()` → audio modulation
- **Direct Execution**: Already works in Nimini!

The same high-level description generates optimal code for each target domain. 🚀
