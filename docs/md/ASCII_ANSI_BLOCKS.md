# ASCII and ANSI Art Blocks

## Overview

t|Storie now supports inline ASCII and ANSI art blocks that render directly without code block backticks.

## ASCII Blocks

Use ` ```ascii` for plain ASCII art that renders as preformatted text:

````markdown
```ascii
  _____         _     
 |_   _|__  ___| |_   
   | |/ _ \/ __| __|  
   | |  __/\__ \ |_   
   |_|\___||___/\__|  
```
````

This renders as plain text without the code block markers.

## ANSI Blocks

Use ` ```ansi` for ANSI art with color escape sequences:

````markdown
```ansi
[1;36m  ████████╗[0m[1;37m███████╗████████╗[0m
[1;36m  ╚══██╔══╝[0m[1;37m██╔════╝╚══██╔══╝[0m
[1;36m     ██║   [0m[1;37m█████╗     ██║   [0m
```
````

The ANSI escape sequences are parsed into a styled `TermBuffer` and **rendered with full color and style support** directly to the terminal buffer. All whitespace (including leading and trailing spaces) is preserved for perfect alignment.

**User-Friendly Bracket Notation:** You can use the standard bracket notation `[1;36m` in your markdown files. The parser automatically converts this to actual ANSI escape sequences (`\x1b[1;36m`) before parsing to a buffer. This means you can:
- Copy ANSI art directly from files (with actual ESC bytes)
- Type bracket notation like `[1;31mRED[0m` directly in your editor  
- Mix both formats - whatever works for you!
- Get full color rendering with proper styling!

**How It Works:**
1. Bracket notation is converted to actual ESC sequences
2. ANSI content is parsed into a `TermBuffer` (same as `ansi:name` blocks)
3. The styled buffer is rendered cell-by-cell with colors, bold, etc.
4. Works within t|Storie's frame-by-frame rendering system

**Supported ANSI Codes:**
- `[0m` - Reset all attributes
- `[1;31m` - Bold red text
- `[1;32m` - Bold green text
- `[1;36m` - Bold cyan text
- And all standard ANSI SGR codes (see [ansi_parser.nim](../lib/ansi_parser.nim) for details)

## Embedded Content (with `:name` qualifier)

The existing embedded content syntax still works:

- ` ```ansi:logo` - Stores ANSI art as embedded content
- ` ```ascii:name` - Stores ASCII art as embedded content (if added)

These are stored separately from the rendered content and can be accessed programmatically.

## No Conflicts

The parser checks for `:name` qualifiers **first**, so:
- ` ```ansi` → Creates an AnsiBlock (inline rendering)
- ` ```ansi:logo` → Creates embedded content (stored for later use)
- ` ```ascii` → Creates a PreformattedBlock (inline rendering)
- ` ```ascii:name` → Creates embedded content (stored for later use)

## Implementation Details

### Parser Changes

1. **storie_types.nim**: Added `AnsiBlock` to `ContentBlockKind` enum
2. **storie_md.nim**: 
   - Replaced `txt` language with `ascii`
   - Added `ansi` language handling that stores raw ANSI content
3. **ansi_parser.nim**: 
   - Added `convertBracketNotationToAnsi()` to convert user-friendly `[1;36m` to `\x1b[1;36m`
   - `parseAnsiToBuffer()` parses ANSI sequences into styled `TermBuffer`
4. **canvas.nim**: 
   - Stores parsed ANSI buffers in a global table
   - Renders ANSI blocks by copying styled cells directly to the terminal buffer
   - Preserves all colors, bold, and formatting from the ANSI art

### Type Structure

```nim
ContentBlockKind* = enum
  TextBlock, CodeBlock_Content, HeadingBlock, PreformattedBlock, AnsiBlock

ContentBlock* = object
  case kind*: ContentBlockKind
  of PreformattedBlock:
    content*: string
  of AnsiBlock:
    ansiContent*: string  # Raw ANSI escape sequence content
  # ... other variants
```

## Future Enhancements

- Additional ANSI features (cursor positioning for complex layouts)
- Export to HTML with color preservation
- Color theme customization
