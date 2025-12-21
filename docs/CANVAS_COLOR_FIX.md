# Canvas Color Rendering Fix

## Problem
When running `./ts depths.md`, colors were not displaying:
- Only black and white text appeared
- Arrow key navigation didn't show visual feedback (highlight not changing)
- Custom stylesheet colors (#FFD700, #4A9EFF, etc.) weren't being applied

## Root Cause
The `renderInlineMarkdown` function in `lib/canvas.nim` was using hardcoded ANSI color codes (30 for dark gray, 37 for white) instead of using the Style objects from the stylesheet. This meant:
1. Hardcoded colors overrode stylesheet colors for body text and non-link content
2. The function converted ANSI codes to basic colors via `ansiToColor()` instead of using true RGB values

## Changes Made

### 1. Updated `renderInlineMarkdown` signature (lib/canvas.nim)
**Before:**
```nim
proc renderInlineMarkdown(text: string, x, y: int, maxWidth: int, 
                         buffer: var TermBuffer, baseColor: int, baseBold: bool): int
```

**After:**
```nim
proc renderInlineMarkdown(text: string, x, y: int, maxWidth: int, 
                         buffer: var TermBuffer, baseStyle: Style): int
```

Now accepts a full `Style` object with RGB colors instead of an ANSI code.

### 2. Updated `renderTextWithLinks` signature
Added `bodyStyle: Style` parameter so it can pass the correct body text style to `renderInlineMarkdown`.

### 3. Updated all `renderInlineMarkdown` calls
Changed from:
```nim
renderInlineMarkdown(text, x, y, maxWidth, buffer, 37, false)  # Hardcoded white
```

To:
```nim
renderInlineMarkdown(text, x, y, maxWidth, buffer, bodyStyle)  # Uses stylesheet
```

### 4. Fixed dimmed text rendering
For non-current sections and disabled links, now properly applies dim attribute:
```nim
var dimStyle = bodyStyle
dimStyle.dim = true
renderInlineMarkdown(linkText, currentX, y, maxWidth - (currentX - x), buffer, dimStyle)
```

## Verification

### Color Support Detection
Your terminal supports 24-bit RGB colors:
- `COLORTERM=truecolor`
- `TERM=xterm-256color`

The `detectColorSupport()` function returns `16777216` (true color), so RGB colors should render correctly.

### Test Files Created
1. **examples/color_test.md** - Simple test showing RED, GREEN, BLUE, YELLOW text
2. **test_colors.sh** - Shell script to verify terminal RGB color support

## Testing

Run the following to verify colors are working:

```bash
# Test basic color rendering
./ts examples/color_test.md

# Test depths.md with custom stylesheet
./ts examples/depths.md
```

### Expected Results in depths.md:
- **Headings**: Gold color (#FFD700), bold
- **Links**: Blue (#4A9EFF), underlined  
- **Focused Links**: Gold (#FFD700), bold + underlined (should change when pressing arrow keys)
- **Body Text**: Light gray (#CCCCCC)
- **Placeholders**: Dark gray (#505050), dimmed

## If Colors Still Don't Appear

If you still see only black and white:

1. **Check VS Code Terminal Settings:**
   - Open Settings (Ctrl+,)
   - Search for "terminal.integrated.minimumContrastRatio"
   - Set to 1 to disable automatic contrast adjustments
   - Search for "terminal.integrated.gpuAcceleration"
   - Try setting to "off" if colors are garbled

2. **Verify True Color Support:**
   ```bash
   bash test_colors.sh
   ```
   You should see colored text. If not, VS Code terminal may not support RGB colors.

3. **Try External Terminal:**
   Test in a native terminal (not VS Code integrated terminal) to verify the fix works.

4. **Check Terminal Profile:**
   Some VS Code terminal profiles force monochrome. Try switching to the default profile.

## Technical Details

The canvas rendering pipeline now follows this flow:
1. Parse stylesheet from front matter → `StyleSheet` (Table[string, StyleConfig])
2. Convert to rendering styles → `toStyle(StyleConfig)` → `Style` with RGB colors
3. Pass to canvas render → `canvasRender(buffer, width, height, styleSheet)`
4. Extract styles → `renderSection` gets heading/body/link styles from sheet
5. Apply to text → `renderInlineMarkdown` uses `Style` objects directly
6. Output to terminal → `buildStyleCode` generates ANSI RGB sequences

All RGB color values are preserved throughout this pipeline.
