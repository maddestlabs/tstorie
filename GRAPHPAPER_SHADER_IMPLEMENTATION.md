# Graph Paper Shader Implementation Summary

## Overview

Created an ultra-realistic graph paper shader for tStorie that draws grid lines perfectly aligned to terminal character cells, with subtle paper texture effects.

## Files Created

### 1. **docs/shaders/graphpaper.js** - Main shader implementation
- WebGL GLSL shader with vertex and fragment shaders
- Cell-aligned grid drawing using modulo arithmetic
- Paper texture with grain and crumpling effects
- Customizable uniforms for appearance

### 2. **docs/demos/graphpaper.md** - Interactive demo
- Shows the graph paper effect in action
- Example content with ASCII art boxes
- Usage instructions and URL parameters
- Technical details and customization guide

### 3. **docs/shaders/README_GRAPHPAPER.md** - Shader documentation
- Complete parameter reference
- Usage examples for different styles
- Technical implementation details
- Customization recipes

### 4. **docs/shaders/test-graphpaper.html** - Testing page
- Quick reference for test URLs
- Feature checklist
- Implementation details

## Code Changes

### 1. **web/index.html** - Added cell dimension support
Modified shader uniform handling to automatically pass terminal cell dimensions:

```javascript
// Special handling for cellSize - get live values from terminal
if (name === 'cellSize' && window.terminal) {
    const dpr = window.devicePixelRatio || 1;
    value = [window.terminal.charWidth * dpr, window.terminal.charHeight * dpr];
}
```

### 2. **docs/index.html** - Same cell dimension support
Applied identical changes for consistency across deployment targets.

### 3. **docs/md/SHADER_SYSTEM.md** - Updated documentation
Added section on "Cell-Aware Uniforms" explaining how to create shaders that align with terminal cells.

## How It Works

### Cell Dimension Passing

1. **Terminal calculates cell size** based on font metrics:
   ```javascript
   this.charWidth = Math.ceil(metrics.width);
   this.charHeight = this.fontSize;
   ```

2. **Shader system reads dimensions** during render loop:
   ```javascript
   window.terminal.charWidth * devicePixelRatio
   window.terminal.charHeight * devicePixelRatio
   ```

3. **Shader receives dimensions** as uniform:
   ```glsl
   uniform vec2 cellSize;
   ```

4. **Grid algorithm aligns to cells**:
   ```glsl
   vec2 pixelCoord = uv * resolution;
   vec2 gridPos = mod(pixelCoord, cellSize);
   vec2 distToLine = min(gridPos, cellSize - gridPos);
   float minDist = min(distToLine.x, distToLine.y);
   ```

### Paper Texture

1. **Fine grain** using hash-based noise
2. **Crumpling effect** using multi-octave Worley noise
3. **Subtle modulation** to maintain text readability

## Features

✓ **Perfect Cell Alignment** - Grid lines match character boundaries exactly
✓ **Dynamic Sizing** - Responds to `?fontsize=` URL parameter
✓ **HiDPI Support** - Accounts for device pixel ratio
✓ **Customizable** - 7 adjustable parameters for appearance
✓ **Realistic Texture** - Subtle grain and crumpling effects
✓ **Performance** - Efficient GLSL with minimal overdraw

## Usage Examples

```bash
# Basic usage
index.html?shader=graphpaper

# With demo content
index.html?content=demo:graphpaper&shader=graphpaper

# Different font sizes (grid adapts automatically)
index.html?shader=graphpaper&fontsize=12
index.html?shader=graphpaper&fontsize=16
index.html?shader=graphpaper&fontsize=24

# Combined with other shaders/content
index.html?content=gist:YOUR_GIST&shader=graphpaper&fontsize=18
```

## Customization

Edit `uniforms` in `graphpaper.js`:

```javascript
// Subtle blue grid (default)
gridColor: [0.2, 0.4, 0.9]
gridAlpha: 0.25
gridThickness: 0.5

// Bold black grid
gridColor: [0.0, 0.0, 0.0]
gridAlpha: 0.5
gridThickness: 1.0

// Engineering paper style
gridColor: [0.0, 0.5, 0.2]  // Green
gridAlpha: 0.35
paperCrumple: 0.5
```

## Technical Notes

### Why Device Pixel Ratio?

The terminal canvas is scaled by DPR for sharp rendering on HiDPI displays. The shader must use the same scaling to align with actual pixel positions:

```javascript
// Terminal canvas size
canvas.width = cols * charWidth * dpr
canvas.height = rows * charHeight * dpr

// Shader must use scaled cell size
cellSize = [charWidth * dpr, charHeight * dpr]
```

### Font Size Handling

The system reads the `?fontsize=` URL parameter and stores it in `Module.customFontSize`. The terminal applies this during initialization:

```javascript
const customFontSize = Module.customFontSize || null;
terminal = new TStorieTerminal(canvas, customFont, customFontSize);
```

The shader automatically picks up changes because it reads from the live terminal object each frame.

## Future Enhancements

Possible additions:
- Major/minor grid lines (like engineering paper)
- Adjustable grid density (cells per major line)
- Color schemes (blue, green, orange engineering paper)
- Dot grid mode (instead of lines)
- Isometric grid option
- Hexagonal grid for hex editors

## Testing

Test with various configurations:
1. Different font sizes (8-72px)
2. Different fonts (monospace, proportional)
3. HiDPI and standard displays
4. Window resizing
5. Combined with other demos

All grid lines should perfectly align with character cell boundaries in every configuration.
