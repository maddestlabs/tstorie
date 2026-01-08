---
title: "Theme Demo"
author: "Maddest Labs"
minWidth: 80
minHeight: 24
theme: "catpuccin"
---

```nim on:init
# Canvas-based Presentation System using Nimini
# Navigate with arrow keys: Left/Right for main topics, Up/Down for subtopics

# Get available themes
var themes = getThemes()
var currentThemeIndex = 0

# Find index of current theme
var currentTheme = getCurrentTheme()
if currentTheme == "":
  currentTheme = "catppuccin"

var i = 0
while i < len(themes):
  if themes[i] == currentTheme:
    currentThemeIndex = i
  i = i + 1

# Initialize canvas in presentation mode
# Second parameter = starting section (1 for first real section)
# Third parameter = presentation mode (true)
initCanvas(1, true)
```

```nim on:input
# Handle keyboard and mouse input for canvas navigation

if event.type == "key":
  lastKeyCode = event.keyCode
  lastKey = str(lastKeyCode)
  lastAction = event.action
  if lastKeyCode == 9:
    currentThemeIndex = (currentThemeIndex + 1) % len(themes)
    var newTheme = themes[currentThemeIndex]
    switchTheme(newTheme)
    return true
    
    # Pass key events to canvas system
    var handled = canvasHandleKey(event.keyCode, 0)
    if handled:
      return true
  return false

elif event.type == "mouse":
  if event.action == "press":
    # Pass mouse events to canvas system (only on press, not release)
    var handled = canvasHandleMouse(event.x, event.y, event.button, true)
    if handled:
      return true
  return false

return false
```

```nim on:render
clear()

canvasRender()

# Show current theme name in top-right corner
var style = defaultStyle()
style.fg = rgb(255, 255, 100)
style.bold = true
var themeName = themes[currentThemeIndex]
draw(0, termWidth - len(themeName) - 15, 1, "Theme: " & themeName, style)
draw(0, termWidth - 15, 2, "Press TAB to cycle", style)
```

```nim on:update
canvasUpdate()
```

# 🎨 Theme System Demo

Welcome to the TStorie theme system! This demo uses the **Catppuccin Mocha** theme by default.

**✨ NEW: Live Theme Switching! ✨**  
Press **T** to cycle through all available themes in real-time!

## What Are Themes?

Themes provide a complete color palette for your documents. Instead of manually defining colors for every element, just set:

```
theme: "catppuccin"
```

And you get beautiful, accessible colors automatically!

## Available Themes

Try these in your own documents (or press **T** to see them live!):

- **catppuccin** - Soft, modern (current theme!)
- **nord** - Cool Arctic palette
- **dracula** - Vibrant developer favorite
- **miami-vice** - Bold 80s cyberpunk
- **outrun** - Neon synthwave aesthetic
- **cyberpunk** - Classic duotone
- **terminal** - Classic green CRT
- **solarized-dark** - Elegant Solarized

## Live Theme Switching API

You can switch themes at runtime using Nimini functions:

```nim
# Get list of available themes
var themes = getThemes()

# Switch to a specific theme
switchTheme("nord")

# Get current theme name
var current = getCurrentTheme()
```

This enables:
- Interactive theme pickers
- Dynamic theme changes based on user input
- Theme cycling in presentations
- Context-aware theming

## Features

### Automatic Styling

All these elements are automatically styled:

- **Bold text** uses accent colors
- *Italic text* maintains readability
- `Code snippets` have distinct backgrounds
- Regular text is optimized for long reading

### Interactive Elements

Navigation links are automatically themed too:

- [Home](#home)
- [About](#about)
- [Contact](#contact)

### Hierarchical Headings

Headings at different levels use different accent colors:

#### This is an H4
##### This is an H5
###### This is an H6

## Override When Needed

You can still override individual styles:

```markdown
---
theme: "catppuccin"
styles.heading.fg: "#FF0080"  # Custom hot pink!
---
```

## Why Use Themes?

✅ **Instant visual consistency**  
✅ **Professional color harmony**  
✅ **Accessible contrast ratios**  
✅ **Easy to change entire look**  
✅ **Focus on content, not colors**

## Try It Yourself!

Edit this file's front matter to try different themes:

```yaml
---
theme: "nord"        # Try this!
# or
theme: "miami-vice"  # Or this!
# or
theme: "cyberpunk"   # Or this!
---
```

Each theme provides a completely different aesthetic while maintaining readability and usability!

---

*This demo showcases the theme system. See THEME_GUIDE.md for complete documentation.*
