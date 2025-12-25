# Live Theme Switching API

TStorie now supports dynamic theme switching at runtime! You can build interactive theme pickers, presentations with theme cycling, and more.

## Available Functions

### `nimini_getThemes()`
Returns an array of all available theme names.

**Example:**
```nim
var themes = nimini_getThemes()
# themes = ["catppuccin", "nord", "dracula", "miami-vice", "outrun", "cyberpunk", "terminal", "solarized-dark"]
```

### `nimini_switchTheme(themeName)`
Switches to the specified theme at runtime. Returns `true` on success, `false` if the theme doesn't exist.

**Arguments:**
- `themeName` (string): Name of the theme to switch to

**Example:**
```nim
var success = nimini_switchTheme("nord")
if success:
  print "Switched to Nord theme!"
```

### `nimini_getCurrentTheme()`
Returns the name of the currently active theme (from front matter). Returns empty string if no theme was specified.

**Example:**
```nim
var current = nimini_getCurrentTheme()
print "Current theme: " & current
```

## Complete Example: Theme Cycler

```markdown
---
title: "Theme Cycler Demo"
theme: "catppuccin"
---

\```nim on:init
var themes = nimini_getThemes()
var themeIndex = 0

# Find current theme index
var currentTheme = nimini_getCurrentTheme()
var i = 0
while i < len(themes):
  if themes[i] == currentTheme:
    themeIndex = i
  i = i + 1
\```

\```nim on:input
if event.type == "key" and event.action == "press":
  # Press T to cycle themes
  if event.keyCode == 116 or event.keyCode == 84:  # 't' or 'T'
    themeIndex = (themeIndex + 1) % len(themes)
    nimini_switchTheme(themes[themeIndex])
    return true
return false
\```

\```nim on:render
bgClear()
fgClear()

var style = defaultStyle()
style.fg = rgb(255, 255, 100)
style.bold = true

var msg = "Current theme: " & themes[themeIndex]
fgWriteText(10, 10, msg, style)
fgWriteText(10, 11, "Press T to cycle themes", style)
\```
```

## Available Themes

- **catppuccin** - Soft pastel colors with excellent readability
- **nord** - Cool Arctic palette inspired by the northern lights
- **dracula** - Popular dark theme with vibrant colors
- **miami-vice** - Bold 80s cyberpunk aesthetic with hot pink and cyan
- **outrun** - Neon synthwave theme perfect for retro aesthetics
- **cyberpunk** - Classic duotone with electric colors
- **terminal** - Classic green on black CRT terminal look
- **solarized-dark** - Precision colors for readability

## Use Cases

### Interactive Theme Picker
Build a menu system where users can select their preferred theme:

```nim
var selectedIndex = 0
var themes = nimini_getThemes()

# In your input handler:
if event.keyCode == INPUT_UP:
  selectedIndex = (selectedIndex - 1 + len(themes)) % len(themes)
elif event.keyCode == INPUT_DOWN:
  selectedIndex = (selectedIndex + 1) % len(themes)
elif event.keyCode == INPUT_ENTER:
  nimini_switchTheme(themes[selectedIndex])
```

### Presentation Mode
Automatically switch themes between sections:

```nim
# In on:enter hook for different sections:
\```nim on:enter
if sectionTitle == "Introduction":
  nimini_switchTheme("catppuccin")
elif sectionTitle == "Action Sequence":
  nimini_switchTheme("cyberpunk")
elif sectionTitle == "Conclusion":
  nimini_switchTheme("nord")
\```
```

### Time-Based Theming
Switch themes based on time of day or events:

```nim
var frameCount = 0

# In on:update:
frameCount = frameCount + 1
if frameCount % 300 == 0:  # Every 5 seconds at 60fps
  var newTheme = if frameCount % 2 == 0: "nord" else: "dracula"
  nimini_switchTheme(newTheme)
```

## Technical Notes

- Theme switching updates the entire stylesheet instantly
- Canvas rendering automatically uses the new theme
- Individual style overrides from front matter are preserved
- Switching themes is lightweight and doesn't affect performance
- Theme names are case-insensitive

## See Also

- [theme_demo.md](../demos/theme_demo.md) - Live interactive demo
- [storie_themes.nim](../../lib/storie_themes.nim) - Theme definitions
- [THEME_GUIDE.md](THEME_GUIDE.md) - Complete theming documentation
