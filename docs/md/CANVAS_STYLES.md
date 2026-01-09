# Canvas Style System

## Overview

The canvas navigation system now supports custom styling through front matter configuration. You can customize the appearance of headings, links, body text, and placeholder elements.

## Supported Style Names

The canvas system recognizes the following style names:

- **heading** - Markdown headings in sections
- **link** - Normal clickable links
- **link_focused** - Currently focused/selected link
- **body** - Regular text content
- **placeholder** - Hidden section placeholders ("???")

## Example Configuration

```yaml
---
title: "My Interactive Story"
styles.heading.fg: "#FFD700"
styles.heading.bold: "true"
styles.link.fg: "#4A9EFF"
styles.link.underline: "true"
styles.link_focused.fg: "#FFD700"
styles.link_focused.bold: "true"
styles.link_focused.underline: "true"
styles.body.fg: "#CCCCCC"
styles.placeholder.fg: "#505050"
styles.placeholder.dim: "true"
---
```

## Style Properties

Each style can have the following properties:

- **fg**: Foreground color (text color)
  - Format: `"#RRGGBB"` or `"R,G,B"`
  - Example: `"#FFD700"` or `"255,215,0"`
  
- **bg**: Background color
  - Format: Same as fg
  - Example: `"#000000"` or `"0,0,0"`

- **bold**: Make text bold
  - Values: `"true"` or `"false"`

- **italic**: Make text italic
  - Values: `"true"` or `"false"`

- **underline**: Underline text
  - Values: `"true"` or `"false"`

- **dim**: Dim/fade text
  - Values: `"true"` or `"false"`

## Default Styles

If no styles are configured, the canvas uses these defaults:

- **Headings**: Yellow (#FFAA00), bold
- **Links**: Blue (#4A9EFF), no underline (internal navigation)
- **Focused Links**: Yellow (#FFD700), bold, underlined
- **Body**: White (#FFFFFF)
- **Placeholder**: Dark gray (#303030)

Note: Internal navigation links in canvas mode don't have underlines by default (unlike traditional web links) since the canvas acts more like a game UI. The focused/selected link has an underline to show which option is currently active. You can still add underlines to all links by setting `styles.link.underline: "true"` in your front matter.

## Color Schemes Examples

### Dark Theme (Default)
```yaml
styles.heading.fg: "#FFD700"
styles.link.fg: "#4A9EFF"
styles.body.fg: "#CCCCCC"
```

### Warm Theme
```yaml
styles.heading.fg: "#FF8C42"
styles.heading.bold: "true"
styles.link.fg: "#FFD93D"
styles.link_focused.fg: "#FF6B6B"
styles.body.fg: "#FCF5C7"
```

### Cool Theme
```yaml
styles.heading.fg: "#00D9FF"
styles.heading.bold: "true"
styles.link.fg: "#7BFFB5"
styles.link_focused.fg: "#FFE66D"
styles.body.fg: "#D4F1F4"
```

### Monochrome
```yaml
styles.heading.fg: "#FFFFFF"
styles.heading.bold: "true"
styles.link.fg: "#AAAAAA"
styles.link.underline: "true"
styles.link_focused.fg: "#FFFFFF"
styles.link_focused.bold: "true"
styles.body.fg: "#888888"
```

### High Contrast (Accessibility)
```yaml
styles.heading.fg: "#FFFF00"
styles.heading.bold: "true"
styles.link.fg: "#00FFFF"
styles.link.underline: "true"
styles.link_focused.fg: "#FFFF00"
styles.link_focused.bold: "true"
styles.body.fg: "#FFFFFF"
```

## Use Cases

### 1. Themed Stories

Match your story's mood with appropriate colors:
- **Horror**: Dark reds, grays, dim lighting
- **Fantasy**: Golds, purples, mystical blues
- **Sci-fi**: Cyans, greens, neon colors
- **Mystery**: Muted tones, subtle highlights

### 2. Accessibility

Improve readability for users with:
- **High contrast** for visual impairments
- **Larger differences** between focused/unfocused links
- **Bold text** for better visibility

### 3. Branding

Match your game's visual identity:
- Use brand colors consistently
- Create memorable visual experiences
- Maintain style across multiple stories

## Integration with Custom Rendering

Canvas styles work alongside custom `on:render` blocks. You can use `getStyle()` to access the same styles:

```nim
```nim on:render
bgClear()

# Use canvas-defined styles in custom rendering
var headingStyle = getStyle("heading")
var linkStyle = getStyle("link")

bgWriteText(10, 5, "Custom Heading", headingStyle)
bgWriteText(10, 7, "Custom Link", linkStyle)

# Still render canvas normally
canvasRender()
```
```

## Complete Example

See [examples/depths.md](../examples/depths.md) for a full interactive fiction game with custom styling.

## Backward Compatibility

Canvas rendering works perfectly **without** any style configuration. If no styles are defined, the system uses sensible defaults. This means:

- Existing games continue to work unchanged
- You can add styles gradually
- Styles are purely cosmetic enhancements

## Tips

1. **Test on Your Terminal**: Color rendering varies by terminal emulator
2. **Use Hex Colors**: More portable than named colors
3. **Consider Contrast**: Ensure text is readable against backgrounds
4. **Bold for Focus**: Makes focused elements more obvious
5. **Underline Links**: Traditional web convention helps users
6. **Subtle Dimming**: Use `dim: "true"` for less important elements

## See Also

- [STYLES.md](STYLES.md) - General style system documentation
- [CANVAS_IMPLEMENTATION.md](CANVAS_IMPLEMENTATION.md) - Canvas system details
- [examples/depths.md](../examples/depths.md) - Complete styled example
- [examples/styles_demo.md](../examples/styles_demo.md) - Style system demonstration
