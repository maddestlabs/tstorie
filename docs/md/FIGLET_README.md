# FIGlet Font Rendering Library

A complete implementation of FIGlet font rendering for tstorie, based on the FIGlet 2.2 specification (flf2a format).

## Features

- Full FIGlet flf2a format parsing
- Horizontal smushing with 6 standard rules
- Multiple layout modes (full-width, fitting, smushing)
- **Embedded fonts in markdown** - no file loading required!
- Works identically on native and web (WASM) builds

## Usage - Embedded Fonts in Markdown

The simplest way to use FIGlet fonts is to embed them directly in your markdown file:

```markdown
\```figlet:Standard
flf2a$ 6 5 16 15 11 0 24463
...font data...
\```

\```nim on:init
nimini_loadFont("Standard")
\```

\```nim on:render
var lines = nimini_render("Standard", "HELLO")
for line in lines:
  fgWriteText(x, y, line)
  y = y + 1
\```
```

This approach:
- Works identically on native and web
- No file I/O or async loading needed
- Self-contained - everything in one .md file
- Only includes the fonts you actually use

## API Functions

### nimini_loadFont(name: string): bool

Loads a FIGlet font that was embedded in the markdown with `figlet:NAME`. Returns true if successful.

```nim
var loaded = nimini_loadFont("Standard")
```

### nimini_render(fontName: string, text: string): seq[string]

Renders text using the named font, returning a sequence of strings (one per line).

```nim
var lines = nimini_render("Standard", "HELLO")
for line in lines:
  fgWriteText(x, y, line)
  y = y + 1
```

### nimini_isFontLoaded(name: string): bool

Checks if a font is already loaded.

```nim
if not nimini_isFontLoaded("Standard"):
  nimini_loadFont("Standard")
```

### nimini_listAvailableFonts(): seq[string]

Returns a list of all fonts embedded in the current markdown file.

```nim
var fonts = nimini_listAvailableFonts()
```

## Example: Digital Clock

See [docs/demos/clock_simple.md](docs/demos/clock_simple.md) for a complete example with an embedded Standard font.

## Font Storage

Fonts can be obtained from:
- http://www.figlet.org/fontdb.cgi (148+ fonts available)
- Downloaded to `docs/figlets/` for easy copy-paste

Just copy the .flf file content into a `figlet:NAME` code block in your markdown!

## Implementation

The library consists of 4 core modules in `lib/`:

- `figlet_types.nim` - Core types (FIGfont, FIGcharacter, layout modes)
- `figlet_parser.nim` - .flf file parser with stream support
- `figlet_render.nim` - Text rendering with smushing rules
- `figlet.nim` - Main API (parseFontFromString, render)

Font embedding is handled by `storie_md.nim` which parses `figlet:NAME` code blocks and stores them in `gEmbeddedFigletFonts` table.

## Specification

Based on FIGlet 2.2 specification (flf2a format):
- Magic signature: "flf2a"
- Required 102 ASCII characters (32-126 + German umlauts)
- Code-tagged characters support
- 6 horizontal smushing rules (equal, underscore, hierarchy, opposite, big X, hardblank)
- Full-width, fitting, and smushing layout modes

See `figlets.txt` for the complete specification.
