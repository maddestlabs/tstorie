# Style System

## Overview

TStorie now includes a powerful style configuration system that allows you to define and use custom styles through front matter. Styles control text appearance including colors, bold, italic, underline, and dim attributes.

## Defining Styles in Front Matter

Styles are defined in the front matter section using dot notation:

```yaml
---
targetFPS: 60
styles.<styleName>.<property>: "<value>"
---
```

### Style Properties

- **fg** (foreground): Text color as RGB values
  - Formats: `"255,0,0"` or `"#FF0000"`
- **bg** (background): Background color as RGB values
  - Formats: `"0,0,255"` or `"#0000FF"`
- **bold**: `"true"` or `"false"`
- **italic**: `"true"` or `"false"`
- **underline**: `"true"` or `"false"`
- **dim**: `"true"` or `"false"`

### Example Front Matter

```yaml
---
targetFPS: 30
styles.default.fg: "255,255,255"
styles.default.bg: "0,0,0"
styles.heading1.fg: "255,255,0"
styles.heading1.bold: "true"
styles.error.fg: "#FF0000"
styles.error.bold: "true"
styles.success.fg: "0,255,0"
styles.muted.fg: "128,128,128"
styles.muted.dim: "true"
---
```

## Using Styles in Code

### Getting Styles

Use `getStyle(name)` to retrieve a named style, or `defaultStyle()` for the default style:

```nim
```nim on:render
# Get predefined styles
var titleStyle = getStyle("heading1")
var errorStyle = getStyle("error")
var normalStyle = defaultStyle()

# Use styles with drawing functions
bgWriteText(5, 3, "Title Text", titleStyle)
bgWriteText(5, 5, "Error message", errorStyle)
bgWriteText(5, 7, "Normal text", normalStyle)
```
```

### Drawing Functions with Styles

All drawing functions accept an optional style parameter:

- `bgWriteText(x, y, text, [style])`
- `fgWriteText(x, y, text, [style])`
- `bgWrite(x, y, char, [style])`
- `fgWrite(x, y, char, [style])`
- `bgFillRect(x, y, w, h, char, [style])`
- `fgFillRect(x, y, w, h, char, [style])`

If style is omitted, the default text style is used.

## Color Functions

Create colors using these functions:

```nim
rgb(r, g, b)      # Custom RGB color
gray(level)       # Grayscale (0-255)
black()           # RGB(0, 0, 0)
white()           # RGB(255, 255, 255)
red()             # RGB(255, 0, 0)
green()           # RGB(0, 255, 0)
blue()            # RGB(0, 0, 255)
cyan()            # RGB(0, 255, 255)
magenta()         # RGB(255, 0, 255)
yellow()          # RGB(255, 255, 0)
```

### Creating Custom Styles at Runtime

You can create custom styles by combining `defaultStyle()` with color functions:

```nim
```nim on:init
var myStyle = defaultStyle()
myStyle.fg = rgb(100, 200, 255)
myStyle.bold = true
```

```nim on:render
bgWriteText(5, 3, "Custom styled text", myStyle)
```
```

## Complete Example

```markdown
---
targetFPS: 30
styles.title.fg: "255,255,0"
styles.title.bold: "true"
styles.subtitle.fg: "0,255,255"
styles.body.fg: "200,200,200"
styles.highlight.fg: "0,255,0"
styles.highlight.bold: "true"
---

```nim on:init
var messages = ["Welcome!", "Styles are easy!", "Try it yourself!"]
var currentMsg = 0
var timer = 0
```

```nim on:update
timer = timer + 1
if timer mod 120 == 0:
  currentMsg = (currentMsg + 1) mod 3
```

```nim on:render
bgClear()

var titleStyle = getStyle("title")
var subtitleStyle = getStyle("subtitle")
var bodyStyle = getStyle("body")
var highlightStyle = getStyle("highlight")

bgWriteText(5, 2, "Style System Demo", titleStyle)
bgWriteText(5, 4, "Current Message:", subtitleStyle)
bgWriteText(5, 6, messages[currentMsg], highlightStyle)

bgWriteText(5, 10, "Configure styles in front matter", bodyStyle)
bgWriteText(5, 11, "Then use them with getStyle()", bodyStyle)
```
```

## Style Inheritance

If a requested style doesn't exist, `getStyle()` returns the default style configuration:

```nim
var unknownStyle = getStyle("nonexistent")  # Returns default style
```

## Best Practices

1. **Define Reusable Styles**: Create named styles in front matter for consistency
2. **Use Semantic Names**: `error`, `warning`, `success` instead of `red`, `yellow`, `green`
3. **Leverage Defaults**: Use `defaultStyle()` for normal text
4. **Organize by Purpose**: Group related styles (headings, messages, UI elements)
5. **Test Colors**: Terminal color support varies - test your palette

## Canvas Integration

Canvas modules can access and use the stylesheet when rendering markdown sections:

```nim
proc renderWithStyles(section: Section, styleSheet: StyleSheet) =
  for block in section.blocks:
    case block.kind:
    of HeadingBlock:
      let styleName = "heading" & $block.level
      if styleSheet.hasKey(styleName):
        let style = convertToStyle(styleSheet[styleName])
        buffer.writeText(x, y, block.title, style)
```

## Limitations

- Styles are defined per-document in front matter
- Color rendering depends on terminal capabilities
- Bold/italic/underline support varies by terminal

## Migration from Hardcoded Styles

Before:
```nim
bgWriteText(5, 3, "Title")  # Uses default gTextStyle
```

After:
```nim
var titleStyle = getStyle("title")
bgWriteText(5, 3, "Title", titleStyle)
```

## See Also

- [examples/styles_demo.md](../examples/styles_demo.md) - Full demonstration
- [examples/scoping_test.md](../examples/scoping_test.md) - Updated to use basic rendering
- [CANVAS_IMPLEMENTATION.md](CANVAS_IMPLEMENTATION.md) - Canvas module integration
