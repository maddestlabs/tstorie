# Graph Paper Shader

A WebGL shader that transforms the terminal into graph paper, with grid lines perfectly aligned to character cells.

## Features

- **Cell-Aligned Grid**: Grid lines match exactly with terminal character boundaries
- **Dynamic Sizing**: Automatically adjusts to font size changes (`?fontsize=` parameter)
- **Paper Texture**: Subtle grain and crumpling effects for a realistic paper look
- **Customizable**: Adjust colors, opacity, thickness, and texture intensity

## Usage

```
index.html?shader=graphpaper
index.html?content=demo:graphpaper&shader=graphpaper
index.html?shader=graphpaper&fontsize=20
```

## Parameters

Edit the shader file to customize these uniforms:

```javascript
uniforms: {
    // Grid appearance
    gridColor: [0.2, 0.4, 0.9],  // RGB color (default: blue)
    gridAlpha: 0.25,              // Opacity (0.0-1.0)
    gridThickness: 0.5,           // Line thickness in pixels
    
    // Paper texture
    paperTexture: 1.0,            // Enable/disable (0.0-1.0)
    paperGrain: 0.15,             // Fine grain intensity
    paperCrumple: 0.3             // Crumpling distortion amount
}
```

## How It Works

The shader uses a special `cellSize` uniform that receives live updates from the terminal:

```glsl
uniform vec2 cellSize;  // [charWidth, charHeight] in pixels (with DPR scaling)
```

This allows the grid to perfectly align with text, regardless of:
- Font size (`?fontsize=12`, `?fontsize=24`, etc.)
- Font family (`?font=Courier+New`)
- Display scaling (Retina/HiDPI displays)
- Window resizing

## Technical Details

**Grid Algorithm:**
1. Convert UV coordinates to pixel coordinates
2. Calculate modulo position within cell grid
3. Find distance to nearest grid line (horizontal or vertical)
4. Apply smoothstep for anti-aliasing

**Paper Texture:**
1. Hash-based noise for fine grain
2. Multi-octave Worley noise for crumpling effect
3. Blended with content to maintain readability

## Examples

**Minimal grid (subtle):**
```javascript
gridAlpha: 0.15,
gridThickness: 0.3,
paperTexture: 0.0
```

**Bold grid (clear cell boundaries):**
```javascript
gridAlpha: 0.5,
gridThickness: 1.0,
gridColor: [0.0, 0.0, 0.0]  // Black lines
```

**Engineering paper look:**
```javascript
gridColor: [0.0, 0.5, 0.2],  // Green tint
gridAlpha: 0.35,
paperTexture: 1.0,
paperGrain: 0.25,
paperCrumple: 0.5
```

## Demo

See [graphpaper.md](../demos/graphpaper.md) for an interactive demo showcasing the effect.
