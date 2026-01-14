## Storie Themes
##
## Predefined color themes for TStorie applications.
## These themes can be applied via front matter with: `theme: "catppuccin"`
## Individual style overrides still work: `styles.heading.fg: "#custom"`

import tables, strutils
import storie_types

type
  ThemeColors* = object
    ## Standard theme color palette
    bgPrimary*: tuple[r, g, b: uint8]
    bgSecondary*: tuple[r, g, b: uint8]
    fgPrimary*: tuple[r, g, b: uint8]
    fgSecondary*: tuple[r, g, b: uint8]
    accent1*: tuple[r, g, b: uint8]
    accent2*: tuple[r, g, b: uint8]
    accent3*: tuple[r, g, b: uint8]

#     fgPrimary:    (0x00'u8, 0xd9'u8, 0x8e'u8),   # Aquamarine
# Theme definitions
const
  Neotopia* = ThemeColors(
    bgPrimary:    (0x00'u8, 0x11'u8, 0x11'u8),   # Deep teal (#001111)
    bgSecondary:  (0x09'u8, 0x34'u8, 0x3a'u8),   # Slightly lighter teal (#09343a)
    fgPrimary:    (0xe0'u8, 0xe0'u8, 0xe0'u8),   # Bright gray (body text)
    fgSecondary:  (0x90'u8, 0x90'u8, 0x90'u8),   # Medium gray (muted text)
    accent1:      (0x00'u8, 0xd9'u8, 0x8e'u8),   # Aquamarine (signature color)
    accent2:      (0xff'u8, 0xff'u8, 0x00'u8),   # Electric yellow (highlights)
    accent3:      (0xff'u8, 0x00'u8, 0x6e'u8),   # Neon pink (emphasis)
  )

  Neonopia* = ThemeColors(
    bgPrimary:    (0x05'u8, 0x00'u8, 0x00'u8),   # Deep burgundy (#110000) - dark inverted teal
    bgSecondary:  (0x34'u8, 0x09'u8, 0x05'u8),   # Dark coral (#340905) - dark inverted teal
    fgPrimary:    (0xa0'u8, 0xa0'u8, 0xa0'u8),   # Dark gray (body text) - inverted bright
    fgSecondary:  (0x6f'u8, 0x6f'u8, 0x6f'u8),   # Lighter gray (muted text) - adjusted for dark bg
    accent1:      (0xff'u8, 0x26'u8, 0x71'u8),   # Hot pink (#ff2671) - inverted aquamarine
    accent2:      (0x00'u8, 0x00'u8, 0xff'u8),   # Pure blue (#0000ff) - inverted yellow
    accent3:      (0x00'u8, 0xff'u8, 0x91'u8),   # Bright mint (#00ff91) - inverted neon pink
  )

  CatppuccinMocha* = ThemeColors(
    bgPrimary:    (0x1e'u8, 0x1e'u8, 0x2e'u8),
    bgSecondary:  (0x31'u8, 0x32'u8, 0x44'u8),
    fgPrimary:    (0xcd'u8, 0xd6'u8, 0xf4'u8),
    fgSecondary:  (0x6c'u8, 0x70'u8, 0x86'u8),
    accent1:      (0xf5'u8, 0xc2'u8, 0xe7'u8),  # Pink
    accent2:      (0x89'u8, 0xb4'u8, 0xfa'u8),  # Blue
    accent3:      (0xa6'u8, 0xe3'u8, 0xa1'u8)   # Green
  )
  
  Nord* = ThemeColors(
    bgPrimary:    (0x2e'u8, 0x34'u8, 0x40'u8),
    bgSecondary:  (0x3b'u8, 0x42'u8, 0x52'u8),
    fgPrimary:    (0xec'u8, 0xef'u8, 0xf4'u8),
    fgSecondary:  (0xd8'u8, 0xde'u8, 0xe9'u8),
    accent1:      (0x88'u8, 0xc0'u8, 0xd0'u8),  # Frost cyan
    accent2:      (0x81'u8, 0xa1'u8, 0xc1'u8),  # Frost teal
    accent3:      (0xa3'u8, 0xbe'u8, 0x8c'u8)   # Aurora green
  )
  
  Dracula* = ThemeColors(
    bgPrimary:    (0x28'u8, 0x2a'u8, 0x36'u8),
    bgSecondary:  (0x44'u8, 0x47'u8, 0x5a'u8),
    fgPrimary:    (0xf8'u8, 0xf8'u8, 0xf2'u8),
    fgSecondary:  (0x62'u8, 0x72'u8, 0xa4'u8),
    accent1:      (0xff'u8, 0x79'u8, 0xc6'u8),  # Pink
    accent2:      (0x8b'u8, 0xe9'u8, 0xfd'u8),  # Cyan
    accent3:      (0x50'u8, 0xfa'u8, 0x7b'u8)   # Green
  )
  
  Outrun* = ThemeColors(
    bgPrimary:    (0x1a'u8, 0x00'u8, 0x33'u8),
    bgSecondary:  (0x2d'u8, 0x00'u8, 0x55'u8),
    fgPrimary:    (0xf0'u8, 0xf0'u8, 0xff'u8),
    fgSecondary:  (0x8b'u8, 0x5c'u8, 0xf6'u8),
    accent1:      (0xff'u8, 0x00'u8, 0x6e'u8),  # Neon pink
    accent2:      (0x00'u8, 0xf5'u8, 0xff'u8),  # Electric cyan
    accent3:      (0xff'u8, 0xbe'u8, 0x0b'u8)   # Golden yellow
  )
  
  Alleycat* = ThemeColors(
    bgPrimary:    (0x0a'u8, 0x0a'u8, 0x0f'u8),
    bgSecondary:  (0x1a'u8, 0x1a'u8, 0x2e'u8),
    fgPrimary:    (0xe0'u8, 0xe0'u8, 0xff'u8),
    fgSecondary:  (0x6b'u8, 0x7f'u8, 0xd7'u8),
    accent1:      (0x00'u8, 0xff'u8, 0xff'u8),  # Electric cyan
    accent2:      (0xff'u8, 0x00'u8, 0xff'u8),  # Magenta
    accent3:      (0x00'u8, 0xff'u8, 0x00'u8)   # Matrix green
  )
  
  Terminal* = ThemeColors(
    bgPrimary:    (0x0a'u8, 0x0a'u8, 0x0a'u8),
    bgSecondary:  (0x1a'u8, 0x1a'u8, 0x1a'u8),
    fgPrimary:    (0x00'u8, 0xff'u8, 0x00'u8),
    fgSecondary:  (0x00'u8, 0x88'u8, 0x00'u8),
    accent1:      (0x00'u8, 0xff'u8, 0x00'u8),  # Bright green
    accent2:      (0x00'u8, 0xcc'u8, 0x00'u8),  # Medium green
    accent3:      (0x00'u8, 0xaa'u8, 0x00'u8)   # Dark green
  )

  SolarDark* = ThemeColors(
    bgPrimary:    (0x00'u8, 0x2b'u8, 0x36'u8),
    bgSecondary:  (0x07'u8, 0x36'u8, 0x42'u8),
    fgPrimary:    (0x83'u8, 0x94'u8, 0x96'u8),
    fgSecondary:  (0x58'u8, 0x6e'u8, 0x75'u8),
    accent1:      (0x26'u8, 0x8b'u8, 0xd2'u8),  # Blue
    accent2:      (0x2a'u8, 0xa1'u8, 0x98'u8),  # Cyan
    accent3:      (0x85'u8, 0x99'u8, 0x00'u8)   # Green
  )
  
  SolarLight* = ThemeColors(
    bgPrimary:    (0xfd'u8, 0xf6'u8, 0xe3'u8),
    bgSecondary:  (0xee'u8, 0xe8'u8, 0xd5'u8),
    fgPrimary:    (0x65'u8, 0x7b'u8, 0x83'u8),
    fgSecondary:  (0x93'u8, 0xa1'u8, 0xa1'u8),
    accent1:      (0x26'u8, 0x8b'u8, 0xd2'u8),  # Blue
    accent2:      (0x2a'u8, 0xa1'u8, 0x98'u8),  # Cyan
    accent3:      (0x85'u8, 0x99'u8, 0x00'u8)   # Green
  )
  
  Coffee* = ThemeColors(
    bgPrimary:    (0xf2'u8, 0xd3'u8, 0xac'u8),  # Cream
    bgSecondary:  (0x73'u8, 0x14'u8, 0x25'u8),  # Dark burgundy
    fgPrimary:    (0x26'u8, 0x03'u8, 0x24'u8),  # Deep purple-brown
    fgSecondary:  (0xbf'u8, 0x8c'u8, 0x6f'u8),  # Tan
    accent1:      (0xbf'u8, 0x34'u8, 0x34'u8),  # Rich red
    accent2:      (0xbf'u8, 0x8c'u8, 0x6f'u8),  # Tan
    accent3:      (0xf2'u8, 0xd3'u8, 0xac'u8)   # Cream accent
  )
  
  StoneGarden* = ThemeColors(
    bgPrimary:    (0x1a'u8, 0x1d'u8, 0x1e'u8),  # Darker stone (better contrast)
    bgSecondary:  (0x2d'u8, 0x30'u8, 0x32'u8),  # Elevated surfaces
    fgPrimary:    (0xe8'u8, 0xe6'u8, 0xe3'u8),  # Soft cream
    fgSecondary:  (0x98'u8, 0x96'u8, 0x93'u8),  # Muted stone text
    accent1:      (0x8d'u8, 0xb8'u8, 0x8d'u8),  # Bright moss green (player)
    accent2:      (0xc4'u8, 0xa7'u8, 0x77'u8),  # Warm sand/stone (walls)
    accent3:      (0x5a'u8, 0x7a'u8, 0x8e'u8)   # Cool blue-gray stone (boxes)
  )

  Wat* = ThemeColors(
    bgPrimary:    (0xff'u8, 0x00'u8, 0xff'u8),  # Screaming magenta
    bgSecondary:  (0x00'u8, 0xff'u8, 0x00'u8),  # Blinding lime green
    fgPrimary:    (0xff'u8, 0xff'u8, 0x00'u8),  # Eye-searing yellow
    fgSecondary:  (0xff'u8, 0x69'u8, 0x00'u8),  # Aggressive orange
    accent1:      (0x00'u8, 0xff'u8, 0xff'u8),  # Electric cyan
    accent2:      (0xff'u8, 0x14'u8, 0x93'u8),  # Hot pink
    accent3:      (0x7f'u8, 0xff'u8, 0x00'u8)   # Chartreuse nightmare
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

proc getTheme*(name: string): ThemeColors =
  ## Get theme colors by name (case-insensitive)
  let normalized = name.toLowerAscii()
  if normalized in ThemeRegistry:
    return ThemeRegistry[normalized]
  else:
    # Default to Neotopia if theme not found
    return Neotopia

proc applyTheme*(theme: ThemeColors, themeName: string = ""): StyleSheet =
  ## Convert a theme into a StyleSheet with standard style names
  ## This creates default styles that can be overridden individually
  ## Applies theme-specific adjustments when themeName is provided
  result = initTable[string, StyleConfig]()
  
  # Default body text
  result["body"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Primary heading (h1)
  result["heading"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Secondary heading (h2)
  result["heading2"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Tertiary heading (h3+)
  result["heading3"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgPrimary,
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
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,  # No underline for internal navigation links by default
    dim: false
  )
  
  # Focused/selected links
  result["link_focused"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,  # No underline on focused link for cleaner UI
    dim: false
  )
  
  # Placeholder or muted text
  result["placeholder"] = StyleConfig(
    fg: theme.fgSecondary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Code or monospace text
  result["code"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgSecondary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Emphasis/italic
  result["emphasis"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: true,
    underline: false,
    dim: false
  )
  
  # Strong/bold
  result["strong"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Warning/error
  result["warning"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Background surfaces (cards, panels)
  result["surface"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgSecondary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Default/fallback style (commonly used in scripts)
  result["default"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Dim/muted text
  result["dim"] = StyleConfig(
    fg: theme.fgSecondary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Border/frame elements
  result["border"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Info/label text
  result["info"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Button/interactive elements
  result["button"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgSecondary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Accent color styles (for direct color access)
  result["accent1"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["accent2"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["accent3"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

proc applyEditorStyles*(theme: ThemeColors): StyleSheet =
  ## Generate editor-specific UI styles for tstoried
  ## These extend the base theme with editor chrome elements
  result = initTable[string, StyleConfig]()
  
  # Editor background
  result["editor.background"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Line numbers gutter
  result["editor.linenumber"] = StyleConfig(
    fg: theme.fgSecondary,
    bg: theme.bgSecondary,
    bold: false,
    italic: false,
    underline: false,
    dim: true
  )
  
  # Current line number (highlighted)
  result["editor.linenumber.active"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgSecondary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Cursor
  result["editor.cursor"] = StyleConfig(
    fg: theme.bgPrimary,
    bg: theme.accent1,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Text selection
  result["editor.selection"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.accent2,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Status bar
  result["editor.statusbar"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgSecondary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Status bar - modified indicator
  result["editor.statusbar.modified"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgSecondary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Border/divider
  result["editor.border"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - normal item
  result["browser.item"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - selected item
  result["browser.item.selected"] = StyleConfig(
    fg: theme.bgPrimary,
    bg: theme.accent1,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - directory
  result["browser.directory"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  # File browser list - gist item
  result["browser.gist"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  # Markdown syntax highlighting in editor
  result["markdown.heading"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.code"] = StyleConfig(
    fg: theme.accent3,
    bg: theme.bgSecondary,
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.link"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
    bold: false,
    italic: false,
    underline: true,
    dim: false
  )
  
  result["markdown.emphasis"] = StyleConfig(
    fg: theme.fgPrimary,
    bg: theme.bgPrimary,
    bold: false,
    italic: true,
    underline: false,
    dim: false
  )
  
  result["markdown.strong"] = StyleConfig(
    fg: theme.accent1,
    bg: theme.bgPrimary,
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )
  
  result["markdown.listmarker"] = StyleConfig(
    fg: theme.accent2,
    bg: theme.bgPrimary,
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
