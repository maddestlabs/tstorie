# Content Drawing API

The Canvas system now supports styled, positioned drawing within section content buffers - similar to how `draw()` works for the overall canvas, but specifically for game/interactive content within sections.

## New Functions

### `contentDraw(x, y, text, styleName)`

Draw styled text at a specific position in the content buffer.

**Parameters:**
- `x` (int) - X coordinate (character position)
- `y` (int) - Y coordinate (line number)  
- `text` (string) - Text to draw
- `styleName` (string, optional) - Style name from stylesheet (e.g., "accent2", "accent3", "inverted")

**Example:**
```nim
# Draw a red mine at position (5, 3)
contentDraw(5, 3, "雷", "accent3")

# Draw inverted hidden cell
contentDraw(0, 0, "石", "inverted")

# Draw default styled text
contentDraw(10, 2, "・", "")
```

### `contentPut(x, y, char, styleName)`

Alias for `contentDraw()` - more semantically clear when placing single characters.

## How It Works

1. **Clear the buffer**: `contentClear()` at the start of your render block
2. **Position & style**: Use `contentDraw()` to place characters at specific coordinates with styles
3. **Add status text**: Use `contentWrite()` for sequential text (status lines, etc.)
4. **Render**: Call `canvasRender()` to display everything

## Comparison with Previous Approach

### Before (Line-based, no styling):
```nim
on:render
  contentClear()
  var y = 0
  while y < gridHeight:
    var row = ""
    var x = 0
    while x < gridWidth:
      row = row & getCell(x, y)
      x = x + 1
    contentWrite(row)  # Can't style individual cells
    y = y + 1
  canvasRender()
```

### After (Positioned, styled):
```nim
on:render
  contentClear()
  var y = 0
  while y < gridHeight:
    var x = 0
    while x < gridWidth:
      var cell = getCellChar(x, y)
      var style = getCellStyle(x, y)
      contentDraw(x, y, cell, style)  # Full control!
      x = x + 1
    y = y + 1
  canvasRender()
```

## Available Styles

Common stylesheet styles you can use:
- `"accent1"` - Primary accent color
- `"accent2"` - Secondary accent color  
- `"accent3"` - Tertiary accent (often red/danger)
- `"inverted"` - Inverted foreground/background
- `"heading"` - Heading style
- `"body"` - Body text style
- `""` (empty) - Default style

Styles are defined in your theme and accessible via the stylesheet.

## Complete Minesweeper Example

```nim
on:render
  var gameBlocks = getCurrentSectionCodeBlocks("game")
  if len(gameBlocks) > 0:
    contentClear()
    
    # Render game grid with individual cell styling
    var y = 0
    while y < gridHeight:
      var x = 0
      while x < gridWidth:
        var cell = getCell(x, y)
        var cellChar = hiddenChar
        var style = ""
        
        if cellIsRevealed(cell):
          if cellIsMine(cell):
            cellChar = mineChar
            style = "accent3"  # Red for danger
          elif cellHasNumber(cell):
            cellChar = getNumberChar(cell)
          else:
            cellChar = emptyChar
        elif cellIsFlagged(cell):
          cellChar = flagChar
          style = "accent2"  # Colored flag
        else:
          cellChar = hiddenChar
          style = "inverted"  # Hidden cells stand out
        
        # Draw each cell individually with its style
        contentDraw(x * 2, y, cellChar, style)
        x = x + 1
      y = y + 1
    
    # Add status text below grid
    contentWrite("")
    contentWrite("Status: " & gameStatus)
    
  canvasRender()
```

## Benefits

✅ **Individual cell styling** - Each character can have its own color/style  
✅ **Positioned drawing** - Place content at exact coordinates  
✅ **Theme integration** - Uses stylesheet styles automatically  
✅ **Game-friendly** - Perfect for grids, boards, and interactive content  
✅ **HTML-like control** - Similar flexibility to JavaScript DOM manipulation  
✅ **Clean separation** - Game logic separate from rendering

## Technical Details

Internally, `contentDraw()` creates special marker lines in the content buffer:
```
{{DRAW:x,y,styleName}}text
```

These are parsed during canvas rendering and converted to properly styled, positioned `buffer.writeText()` calls. The system handles:
- Style resolution from stylesheet
- Coordinate translation to screen space
- Width tracking for proper layout
- Double-width character support

This approach gives you DOM-like manipulation of section content while maintaining the simplicity of the canvas system!
