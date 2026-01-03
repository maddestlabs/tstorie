# Embedded Content in tStorie Exports

## Overview

tStorie now supports **embedded content blocks** in markdown files that can be included in exported programs. This allows you to embed reusable data (like FIGlet fonts, configuration files, or custom data) directly in your markdown without requiring external files.

## Supported Content Types

### 1. FIGlet Fonts (`figlet:NAME`)

Embed FIGlet font data for ASCII art rendering:

```markdown
\```figlet:standard
flf2a$ 6 5 16 15 11 0 24463
Standard font by Glenn Chappell
... (font data) ...
\```
```

Access in code:
```nim
let fontData = getEmbeddedFont("standard")
# or
let fontData = getEmbeddedContent("standard")
```

### 2. Data Files (`data:NAME`)

Embed configuration files, game data, or any text content:

```markdown
\```data:config
maxPlayers: 4
gameMode: adventure
difficulty: hard
\```
```

Access in code:
```nim
let config = getEmbeddedContent("config")
# Parse the config as needed
```

### 3. Custom Content (`custom:NAME`)

Embed any custom content for your application:

```markdown
\```custom:banner
=====================
  WELCOME TO GAME
=====================
\```
```

Access in code:
```nim
let banner = getEmbeddedContent("banner")
print(banner)
```

## Important: Nimini Code Blocks Are NOT Embedded

Regular nimini code blocks with lifecycle hooks (like `on:init`, `on:render`) are **executable code** and are NOT treated as embedded content. They are compiled into your program as normal:

```markdown
\```nim on:init
var x = 10  # This is EXECUTABLE CODE, not embedded data
\```
```

## API Reference

### Exported Functions

When you export a markdown file with embedded content, these functions are automatically generated:

#### `getEmbeddedContent(name: string): string`

Get any embedded content by name. Returns empty string if not found.

```nim
let data = getEmbeddedContent("mydata")
if data.len > 0:
  # Process the data
  echo data
```

#### `hasEmbeddedContent(name: string): bool`

Check if embedded content exists.

```nim
if hasEmbeddedContent("config"):
  let config = getEmbeddedContent("config")
  # Parse config...
```

#### `getEmbeddedFont(name: string): string`

Convenience function specifically for FIGlet fonts. Alias for `getEmbeddedContent()`.

```nim
let font = getEmbeddedFont("standard")
if font.len > 0:
  # Load the font
  figletLoadFontFromString("standard", font)
```

## How It Works

### 1. Parsing Phase

The markdown parser identifies code blocks with special prefixes:
- `figlet:NAME` → Stored as `EmbeddedContent` with kind `FigletFont`
- `data:NAME` → Stored as `EmbeddedContent` with kind `DataFile`
- `custom:NAME` → Stored as `EmbeddedContent` with kind `Custom`

### 2. Export Phase

During export, a special section is generated:

```nim
var gEmbeddedContent {.global.} = initTable[string, string]()

proc initEmbeddedContent() =
  gEmbeddedContent["standard"] = """
flf2a$ 6 5 16 15 11 0 24463
... font data ...
"""
  # ... more embedded content ...

# Helper functions
proc getEmbeddedContent*(name: string): string =
  gEmbeddedContent.getOrDefault(name, "")

proc hasEmbeddedContent*(name: string): bool =
  gEmbeddedContent.hasKey(name)

proc getEmbeddedFont*(name: string): string =
  getEmbeddedContent(name)
```

### 3. Initialization

In the generated `main()` function, embedded content is automatically initialized:

```nim
proc main() =
  # ... terminal setup ...
  
  # Initialize embedded content (fonts, data, etc.)
  initEmbeddedContent()
  
  # ... rest of initialization ...
```

## Complete Example

**myapp.md:**
```markdown
---
theme: "catppuccin"
---

# My Application

\```figlet:banner
flf2a$ 5 4 5 -1 1
Banner font
@@
@@
\```

\```data:settings
windowWidth: 80
windowHeight: 24
refreshRate: 30
\```

\```nim on:init
# Load embedded content
var bannerFont = getEmbeddedFont("banner")
var settings = getEmbeddedContent("settings")

print("Banner font loaded: ", bannerFont.len > 0)
print("Settings loaded: ", settings.len > 0)
\```

\```nim on:render
clear()
draw(0, 2, 2, "Application Ready!")
\```
```

**Export:**
```bash
tstorie export myapp.md -o myapp.nim
```

The exported `myapp.nim` will contain all embedded content as compile-time strings, making your application completely self-contained with zero file I/O overhead.

## Benefits

1. **Self-Contained**: No external files needed, everything in one markdown
2. **Zero Overhead**: Content embedded as compile-time strings
3. **Type-Safe**: Clear separation between code and data
4. **Portable**: Exported programs work identically on any platform
5. **Extensible**: Easy to add new content types as needed

## Implementation Details

### File Structure

- **Types**: [lib/storie_types.nim](../lib/storie_types.nim)
  - `EmbeddedContentKind` enum
  - `EmbeddedContent` object
  - Extended `MarkdownDocument` with `embeddedContent` field

- **Parser**: [lib/storie_md.nim](../lib/storie_md.nim)
  - Recognizes `figlet:`, `data:`, and `custom:` prefixes
  - Populates `doc.embeddedContent` array
  - Maintains backward compatibility with `gEmbeddedFigletFonts` for runtime

- **Export**: [lib/nim_export.nim](../lib/nim_export.nim)
  - `generateEmbeddedContentSection()` creates the embedded content code
  - Integrated into both standalone and integrated export modes
  - Auto-generates accessor functions

## Future Extensions

Possible future enhancements:

- **Binary Data**: Support for base64-encoded binary content
- **Compression**: Automatic compression of large embedded content
- **Validation**: Schema validation for structured data formats
- **Hot Reload**: Development mode with external file watching

## Migration from Global Tables

If you were previously using `gEmbeddedFigletFonts` directly:

**Old way:**
```nim
# This still works for backward compatibility at runtime
if gEmbeddedFigletFonts.hasKey("standard"):
  let font = gEmbeddedFigletFonts["standard"]
```

**New way (works in exports):**
```nim
# Use the new API for export compatibility
if hasEmbeddedContent("standard"):
  let font = getEmbeddedFont("standard")
```

The new API works both at runtime and in exports, making your code portable.
