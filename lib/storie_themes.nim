## Storie Themes
##
## Predefined color themes for TStorie applications.
## These themes can be applied via front matter with: `theme: "catppuccin"`
## Individual style overrides still work: `styles.heading.fg: "#custom"`

import tables, strutils, options
import storie_types

type
  ThemeColors* = object
    ## Standard theme color palette
    bg*: tuple[r, g, b: uint8]        # Primary background
    bgAlt*: tuple[r, g, b: uint8]     # Secondary/elevated surfaces
    fg*: tuple[r, g, b: uint8]        # Primary text
    fgAlt*: tuple[r, g, b: uint8]     # Secondary/muted text
    accent1*: tuple[r, g, b: uint8]   # Primary accent
    accent2*: tuple[r, g, b: uint8]   # Secondary accent
    accent3*: tuple[r, g, b: uint8]   # Tertiary accent

# Theme definitions
const
  Neotopia* = ThemeColors(
    bg:       (0x00'u8, 0x11'u8, 0x11'u8),   # Deep teal
    bgAlt:    (0x09'u8, 0x34'u8, 0x3a'u8),   # Lighter teal
    fg:       (0xe0'u8, 0xe0'u8, 0xe0'u8),   # Bright gray
    fgAlt:    (0x90'u8, 0x90'u8, 0x90'u8),   # Medium gray
    accent1:  (0x00'u8, 0xd9'u8, 0x8e'u8),   # Aquamarine
    accent2:  (0xff'u8, 0xff'u8, 0x00'u8),   # Yellow
    accent3:  (0xff'u8, 0x00'u8, 0x6e'u8),   # Pink
  )

  Neonopia* = ThemeColors(
    bg:       (0x05'u8, 0x00'u8, 0x00'u8),   # Deep burgundy
    bgAlt:    (0x34'u8, 0x09'u8, 0x05'u8),   # Dark coral
    fg:       (0xa0'u8, 0xa0'u8, 0xa0'u8),   # Dark gray
    fgAlt:    (0x6f'u8, 0x6f'u8, 0x6f'u8),   # Lighter gray
    accent1:  (0xff'u8, 0x26'u8, 0x71'u8),   # Hot pink
    accent2:  (0x00'u8, 0x00'u8, 0xff'u8),   # Pure blue
    accent3:  (0x00'u8, 0xff'u8, 0x91'u8),   # Bright mint
  )

  CatppuccinMocha* = ThemeColors(
    bg:       (0x1e'u8, 0x1e'u8, 0x2e'u8),
    bgAlt:    (0x31'u8, 0x32'u8, 0x44'u8),
    fg:       (0xcd'u8, 0xd6'u8, 0xf4'u8),
    fgAlt:    (0x6c'u8, 0x70'u8, 0x86'u8),
    accent1:  (0xf5'u8, 0xc2'u8, 0xe7'u8),  # Pink
    accent2:  (0x89'u8, 0xb4'u8, 0xfa'u8),  # Blue
    accent3:  (0xa6'u8, 0xe3'u8, 0xa1'u8)   # Green
  )
  
  Nord* = ThemeColors(
    bg:       (0x2e'u8, 0x34'u8, 0x40'u8),
    bgAlt:    (0x3b'u8, 0x42'u8, 0x52'u8),
    fg:       (0xec'u8, 0xef'u8, 0xf4'u8),
    fgAlt:    (0xd8'u8, 0xde'u8, 0xe9'u8),
    accent1:  (0x88'u8, 0xc0'u8, 0xd0'u8),  # Frost cyan
    accent2:  (0x81'u8, 0xa1'u8, 0xc1'u8),  # Frost teal
    accent3:  (0xa3'u8, 0xbe'u8, 0x8c'u8)   # Aurora green
  )
  
  Dracula* = ThemeColors(
    bg:       (0x28'u8, 0x2a'u8, 0x36'u8),
    bgAlt:    (0x44'u8, 0x47'u8, 0x5a'u8),
    fg:       (0xf8'u8, 0xf8'u8, 0xf2'u8),
    fgAlt:    (0x62'u8, 0x72'u8, 0xa4'u8),
    accent1:  (0xff'u8, 0x79'u8, 0xc6'u8),  # Pink
    accent2:  (0x8b'u8, 0xe9'u8, 0xfd'u8),  # Cyan
    accent3:  (0x50'u8, 0xfa'u8, 0x7b'u8)   # Green
  )
  
  Outrun* = ThemeColors(
    bg:       (0x1a'u8, 0x00'u8, 0x33'u8),
    bgAlt:    (0x2d'u8, 0x00'u8, 0x55'u8),
    fg:       (0xf0'u8, 0xf0'u8, 0xff'u8),
    fgAlt:    (0x8b'u8, 0x5c'u8, 0xf6'u8),
    accent1:  (0xff'u8, 0x00'u8, 0x6e'u8),  # Neon pink
    accent2:  (0x00'u8, 0xf5'u8, 0xff'u8),  # Electric cyan
    accent3:  (0xff'u8, 0xbe'u8, 0x0b'u8)   # Golden yellow
  )
  
  Alleycat* = ThemeColors(
    bg:       (0x0a'u8, 0x0a'u8, 0x0f'u8),
    bgAlt:    (0x1a'u8, 0x1a'u8, 0x2e'u8),
    fg:       (0xe0'u8, 0xe0'u8, 0xff'u8),
    fgAlt:    (0x6b'u8, 0x7f'u8, 0xd7'u8),
    accent1:  (0x00'u8, 0xff'u8, 0xff'u8),  # Electric cyan
    accent2:  (0xff'u8, 0x00'u8, 0xff'u8),  # Magenta
    accent3:  (0x00'u8, 0xff'u8, 0x00'u8)   # Matrix green
  )
  
  Terminal* = ThemeColors(
    bg:       (0x0a'u8, 0x0a'u8, 0x0a'u8),
    bgAlt:    (0x1a'u8, 0x1a'u8, 0x1a'u8),
    fg:       (0x00'u8, 0xff'u8, 0x00'u8),
    fgAlt:    (0x00'u8, 0x88'u8, 0x00'u8),
    accent1:  (0x00'u8, 0xff'u8, 0x00'u8),  # Bright green
    accent2:  (0x00'u8, 0xcc'u8, 0x00'u8),  # Medium green
    accent3:  (0x00'u8, 0xaa'u8, 0x00'u8)   # Dark green
  )

  SolarDark* = ThemeColors(
    bg:       (0x00'u8, 0x2b'u8, 0x36'u8),
    bgAlt:    (0x07'u8, 0x36'u8, 0x42'u8),
    fg:       (0x83'u8, 0x94'u8, 0x96'u8),
    fgAlt:    (0x58'u8, 0x6e'u8, 0x75'u8),
    accent1:  (0x26'u8, 0x8b'u8, 0xd2'u8),  # Blue
    accent2:  (0x2a'u8, 0xa1'u8, 0x98'u8),  # Cyan
    accent3:  (0x85'u8, 0x99'u8, 0x00'u8)   # Green
  )
  
  SolarLight* = ThemeColors(
    bg:       (0xfd'u8, 0xf6'u8, 0xe3'u8),
    bgAlt:    (0xee'u8, 0xe8'u8, 0xd5'u8),
    fg:       (0x65'u8, 0x7b'u8, 0x83'u8),
    fgAlt:    (0x93'u8, 0xa1'u8, 0xa1'u8),
    accent1:  (0x26'u8, 0x8b'u8, 0xd2'u8),  # Blue
    accent2:  (0x2a'u8, 0xa1'u8, 0x98'u8),  # Cyan
    accent3:  (0x85'u8, 0x99'u8, 0x00'u8)   # Green
  )
  
  Coffee* = ThemeColors(
    bg:       (0xf2'u8, 0xd3'u8, 0xac'u8),  # Cream
    bgAlt:    (0x73'u8, 0x14'u8, 0x25'u8),  # Dark burgundy
    fg:       (0x26'u8, 0x03'u8, 0x24'u8),  # Deep purple-brown
    fgAlt:    (0xbf'u8, 0x8c'u8, 0x6f'u8),  # Tan
    accent1:  (0xbf'u8, 0x34'u8, 0x34'u8),  # Rich red
    accent2:  (0xbf'u8, 0x8c'u8, 0x6f'u8),  # Tan
    accent3:  (0xf2'u8, 0xd3'u8, 0xac'u8)   # Cream accent
  )
  
  StoneGarden* = ThemeColors(
    bg:       (0x1a'u8, 0x1d'u8, 0x1e'u8),  # Darker stone
    bgAlt:    (0x2d'u8, 0x30'u8, 0x32'u8),  # Elevated surfaces
    fg:       (0xe8'u8, 0xe6'u8, 0xe3'u8),  # Soft cream
    fgAlt:    (0x98'u8, 0x96'u8, 0x93'u8),  # Muted stone
    accent1:  (0x8d'u8, 0xb8'u8, 0x8d'u8),  # Moss green
    accent2:  (0xc4'u8, 0xa7'u8, 0x77'u8),  # Warm sand
    accent3:  (0x5a'u8, 0x7a'u8, 0x8e'u8)   # Blue-gray
  )

  Wat* = ThemeColors(
    bg:       (0xff'u8, 0x00'u8, 0xff'u8),  # Screaming magenta
    bgAlt:    (0x00'u8, 0xff'u8, 0x00'u8),  # Blinding lime
    fg:       (0xff'u8, 0xff'u8, 0x00'u8),  # Eye-searing yellow
    fgAlt:    (0xff'u8, 0x69'u8, 0x00'u8),  # Aggressive orange
    accent1:  (0x00'u8, 0xff'u8, 0xff'u8),  # Electric cyan
    accent2:  (0xff'u8, 0x14'u8, 0x93'u8),  # Hot pink
    accent3:  (0x7f'u8, 0xff'u8, 0x00'u8)   # Chartreuse
  )

# Theme registry - single source of truth for theme names
const ThemeRegistry* = {
  "catppuccin": CatppuccinMocha,
  "nord": Nord,
  "dracula": Dracula,
  "outrun": Outrun,
  "alleycat": Alleycat,
  "terminal": Terminal,
  "solardark": SolarDark,
  "solarlight": SolarLight,
  "neotopia": Neotopia,
  "neonopia": Neonopia,
  "coffee": Coffee,
  "stonegarden": StoneGarden,
  "wat": Wat
}.toTable()

proc getAvailableThemes*(): seq[string] =
  ## Get list of all available theme names (derived from registry)
  result = @[]
  for name in ThemeRegistry.keys:
    result.add(name)

proc toHexString*(color: tuple[r, g, b: uint8]): string =
  ## Convert RGB tuple to hex string (without # prefix)
  result = ""
  result.add(toHex(color.r.int, 2))
  result.add(toHex(color.g.int, 2))
  result.add(toHex(color.b.int, 2))

proc toHexString*(theme: ThemeColors): string =
  ## Convert ThemeColors to hex string format for URL sharing
  ## Format: RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB
  ## Order: bg, bgAlt, fg, fgAlt, accent1, accent2, accent3
  result.add(theme.bg.toHexString())
  result.add("+" & theme.bgAlt.toHexString())
  result.add("+" & theme.fg.toHexString())
  result.add("+" & theme.fgAlt.toHexString())
  result.add("+" & theme.accent1.toHexString())
  result.add("+" & theme.accent2.toHexString())
  result.add("+" & theme.accent3.toHexString())

proc parseCustomTheme*(hexString: string): Option[ThemeColors] =
  ## Parse custom theme from hex color string
  ## Format: RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB+RRGGBB (preferred)
  ##     or: #RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB#RRGGBB (legacy)
  ## Order: bg, bgAlt, fg, fgAlt, accent1, accent2, accent3
  ## Returns None if parsing fails
  
  # Determine separator (+ or # or space from URL-decoded +)
  var separator = '+'
  if hexString.contains('#'):
    separator = '#'
  elif hexString.contains(' '):
    # URLSearchParams decodes + to space, handle that
    separator = ' '
  
  # Split by separator and remove empty strings
  var parts: seq[string] = @[]
  for part in hexString.split(separator):
    if part.len > 0:
      parts.add(part)
  
  # Must have exactly 7 colors
  if parts.len != 7:
    return none(ThemeColors)
  
  # Parse each hex color
  var colors: seq[tuple[r, g, b: uint8]] = @[]
  for hex in parts:
    if hex.len != 6:
      return none(ThemeColors)
    
    try:
      let r = parseHexInt(hex[0..1]).uint8
      let g = parseHexInt(hex[2..3]).uint8
      let b = parseHexInt(hex[4..5]).uint8
      colors.add((r, g, b))
    except:
      return none(ThemeColors)
  
  # Build ThemeColors from parsed values
  return some(ThemeColors(
    bg: colors[0],
    bgAlt: colors[1],
    fg: colors[2],
    fgAlt: colors[3],
    accent1: colors[4],
    accent2: colors[5],
    accent3: colors[6]
  ))

proc getTheme*(name: string): ThemeColors =
  ## Get theme colors by name (case-insensitive)
  ## Also supports custom hex format: RRGGBB+RRGGBB+... or #RRGGBB#RRGGBB#...
  ## Falls back to Neotopia if theme not found or parsing fails
  let normalized = name.toLowerAscii()
  
  # First try built-in themes
  if normalized in ThemeRegistry:
    return ThemeRegistry[normalized]
  
  # Then try parsing as custom hex colors (starts with # or contains + or has 42+ chars)
  if name.startsWith("#") or name.contains("+") or name.contains(" ") or name.len >= 42:
    let customTheme = parseCustomTheme(name)
    if customTheme.isSome:
      return customTheme.get()
  
  # Default to Neotopia if theme not found
  return Neotopia

proc applyTheme*(theme: ThemeColors, themeName: string = ""): StyleSheet =
  ## Convert a theme into a StyleSheet with standard style names
  ## This creates default styles that can be overridden individually
  ## Applies theme-specific adjustments when themeName is provided
  result = initTable[string, StyleConfig]()
  
  # Default body text
  result["body"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Primary heading (h1)
  result["heading"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Secondary heading (h2)
  result["heading2"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Tertiary heading (h3+)
  result["heading3"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Links (with theme-specific adjustments)
  var linkColor = theme.accent2
  
  # Neotopia theme: use darker gray for regular links to contrast with aquamarine focused links
  if themeName.toLowerAscii() == "neotopia":
    linkColor = (0xFF'u8, 0xFF'u8, 0xFF'u8)  # Darker gray, subdued
  
  result["link"] = StyleConfig(
    fg: linkColor,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,  # No underline for internal navigation links by default
    dim: false
  )
  
  # Focused/selected links
  result["link_focused"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,  # No underline on focused link for cleaner UI
    dim: false
  )
  
  # Placeholder or muted text
  result["placeholder"] = StyleConfig(
    fg: theme.fgAlt,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Code or monospace text
  result["code"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgAlt,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Emphasis/italic
  result["emphasis"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: true,
    underline: false,
    dim: false
  )
  
  # Strong/bold
  result["strong"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Warning/error
  result["warning"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Background surfaces (cards, panels)
  result["surface"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bgAlt,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Default/fallback style (commonly used in scripts)
  result["default"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Dim/muted text
  result["dim"] = StyleConfig(
    fg: theme.fgAlt,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Border/frame elements
  result["border"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Info/label text
  result["info"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Button/interactive elements
  result["button"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgAlt,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Accent color styles (for direct color access)
  result["accent1"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["accent2"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["accent3"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

proc applyEditorStyles*(theme: ThemeColors): StyleSheet =
  ## Generate editor-specific UI styles for tstoried
  ## These extend the base theme with editor chrome elements
  result = initTable[string, StyleConfig]()
  
  #Editor background
  result["editor.background"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Line numbers gutter
  result["editor.linenumber"] = StyleConfig(
    fg: theme.fgAlt,
    bg: theme.bgAlt,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Current line number (highlighted)
  result["editor.linenumber.active"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgAlt,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Cursor
  result["editor.cursor"] = StyleConfig(
    fg: theme.bg,
    bg: theme.accent1,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Text selection
  result["editor.selection"] = StyleConfig(
    fg: theme.fg,
    bg: theme.accent2,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Status bar
  result["editor.statusbar"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgAlt,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Status bar - modified indicator
  result["editor.statusbar.modified"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgAlt,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Border/divider
  result["editor.border"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - normal item
  result["browser.item"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - selected item
  result["browser.item.selected"] = StyleConfig(
    fg: theme.bg,
    bg: theme.accent1,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - directory
  result["browser.directory"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - gist item
  result["browser.gist"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Markdown syntax highlighting in editor
  result["markdown.heading"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.code"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgAlt,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.link"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: false,
    italic: false,
    underline: true,
    dim: false
  )
  
  result["markdown.emphasis"] = StyleConfig(
    fg: theme.fg,
    bg: theme.bg,
    bold: false,
    italic: true,
    underline: false,
    dim: false
  )
  
  result["markdown.strong"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.listmarker"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bg,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )

proc applyThemeByName*(name: string): StyleSheet =
  ## Convenience function to get and apply a theme by name
  let theme = getTheme(name)
  return applyTheme(theme, name)

proc applyFullTheme*(themeName: string): StyleSheet =
  ## Apply both base and editor styles for a complete themed editor
  let theme = getTheme(themeName)
  result = applyTheme(theme, themeName)
  
  # Merge in editor-specific styles
  for key, style in applyEditorStyles(theme):
    result[key] = style

# RGB Conversion Utilities
proc toRgbInt*(color: tuple[r, g, b: uint8]): tuple[r, g, b: int] =
  ## Convert uint8 RGB tuple to int RGB tuple
  result = (color.r.int, color.g.int, color.b.int)

proc toRgbUint8*(color: tuple[r, g, b: int]): tuple[r, g, b: uint8] =
  ## Convert int RGB tuple to uint8 RGB tuple
  ## Values are clamped to 0-255 range
  result = (
    clamp(color.r, 0, 255).uint8,
    clamp(color.g, 0, 255).uint8,
    clamp(color.b, 0, 255).uint8
  )

proc toRgbInts*(color: tuple[r, g, b: uint8]): (int, int, int) =
  ## Convert uint8 RGB tuple to individual int values
  result = (color.r.int, color.g.int, color.b.int)

# Theme Color Access Helpers
proc getColor*(theme: ThemeColors, name: string): tuple[r, g, b: uint8] =
  ## Get a specific color from a theme by name
  ## Supported names: bg, bgAlt, fg, fgAlt, accent1, accent2, accent3
  ## Returns bg if name is not recognized
  case name.toLowerAscii()
  of "bg", "background": theme.bg
  of "bgalt", "bg_alt", "bgsecondary", "bg_secondary": theme.bgAlt
  of "fg", "foreground": theme.fg
  of "fgalt", "fg_alt", "fgsecondary", "fg_secondary": theme.fgAlt
  of "accent1", "primary": theme.accent1
  of "accent2", "secondary": theme.accent2
  of "accent3", "tertiary": theme.accent3
  else: theme.bg

proc getAllColors*(theme: ThemeColors): seq[tuple[name: string, color: tuple[r, g, b: uint8]]] =
  ## Get all colors from a theme as a sequence of (name, color) tuples
  result = @[
    ("bg", theme.bg),
    ("bgAlt", theme.bgAlt),
    ("fg", theme.fg),
    ("fgAlt", theme.fgAlt),
    ("accent1", theme.accent1),
    ("accent2", theme.accent2),
    ("accent3", theme.accent3)
  ]

proc getColorAsInts*(theme: ThemeColors, name: string): tuple[r, g, b: int] =
  ## Get a specific color from a theme as int tuple
  result = theme.getColor(name).toRgbInt()
