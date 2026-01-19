# ANSI Parser Library

A comprehensive ANSI escape sequence parser for tStorie that converts ANSI art into styled `TermBuffer` structures. Designed for both immediate use with `ansi:name` blocks and future terminal emulator implementations (e.g., SDL3-based).

## Features

- **SGR (Select Graphic Rendition)**: Full support for colors, bold, italic, underline, and dim styles
- **Color Modes**:
  - 8-color ANSI (codes 30-37, 90-97)
  - 256-color palette (`ESC[38;5;Nm`)
  - True color RGB (`ESC[38;2;R;G;Bm`)
- **Cursor Control**: Positioning, movement, and saved positions
- **Efficient Parsing**: Single-pass state machine, minimal allocations
- **Caching**: Parsed buffers are cached for reuse

## Architecture

### Core Components

1. **`ansi_parser.nim`**: Core parsing engine
   - `parseAnsiToBuffer()`: Main entry point
   - `applySgrParams()`: Style application
   - `ansi8ToRgb()`, `ansi256ToRgb()`: Color conversion
   - Utility functions for text analysis

2. **`ansi_art_bindings.nim`**: Nimini script bindings
   - `drawAnsi()`: Draw ANSI art from embedded content
   - `parseAnsi()`: Parse raw ANSI text
   - `stripAnsi()`: Remove escape sequences
   - Buffer caching and management

3. **Integration**: 
   - `storie_md.nim`: Parses `ansi:name` blocks
   - `storie_types.nim`: `AnsiArt` content kind
   - `runtime_api.nim`: Registers bindings

## Usage in Markdown

### Embedding ANSI Art

```markdown
\`\`\`ansi:logo
[1;36m  ████████╗███████╗[0m
[1;36m  ╚══██╔══╝██╔════╝[0m
[1;34m     ██║   ███████╗[0m
\`\`\`
```

### Drawing in Scripts

```nim
# Simple draw - auto-loads and caches
drawAnsi(layer, x, y, "logo")

# Or use the colon prefix
drawAnsi(0, 10, 5, "ansi:logo")
```

### Advanced Usage

```nim
# Parse ANSI text manually
var bufferId = parseAnsi(ansiText, 80)

# Draw parsed buffer
drawAnsiBuffer(0, x, y, bufferId)

# Get dimensions without parsing
var dims = getAnsiDimensions(ansiText)
draw(0, 0, 0, "Size: " + str(dims["width"]) + "x" + str(dims["height"]))

# Strip ANSI codes for plain text
var plain = stripAnsi(ansiText)
```

## API Reference

### Nim API

#### `parseAnsiToBuffer(content: string, maxWidth: int = 120, maxHeight: int = 1000): TermBuffer`

Parse ANSI escape sequences into a styled buffer.

**Parameters:**
- `content`: Text with ANSI escape sequences
- `maxWidth`: Maximum buffer width (default 120)
- `maxHeight`: Maximum buffer height for allocation (default 1000)

**Returns:** `TermBuffer` with parsed, styled content

#### `applySgrParams(params: seq[int], style: var Style)`

Apply SGR parameters to a style (colors, bold, italic, etc.).

#### `stripAnsi(text: string): string`

Remove all ANSI escape sequences from text.

#### `getAnsiTextDimensions(text: string): tuple[width, height: int]`

Get dimensions of text containing ANSI sequences without fully parsing.

### Nimini Script API

#### `drawAnsi(layer, x, y, artName, [skipConversion])`

Draw ANSI art from an embedded `ansi:name` block.

**Parameters:**
- `layer`: Rendering layer (0-3)
- `x`, `y`: Position coordinates
- `artName`: Name of the embedded block (with or without "ansi:" prefix)
- `skipConversion` (optional): Set to `true` for content that already has proper escape sequences (e.g., .ans files). Default: `false`

**Example:**
```nim
# Standard markdown blocks (automatic conversion)
drawAnsi(0, 10, 5, "logo")
drawAnsi(1, 0, 0, "ansi:banner")  # Explicit prefix

# For .ans files or raw ANSI content (skip conversion)
drawAnsi(0, 0, 0, "amiex_ans", true)
```

#### `parseAnsi(ansiText, [maxWidth]) -> bufferId`

Parse ANSI text into a reusable buffer.

**Returns:** Buffer ID string for use with `drawAnsiBuffer()`

#### `drawAnsiBuffer(layer, x, y, bufferId)`

Draw a previously parsed ANSI buffer.

#### `stripAnsi(text) -> string`

Remove ANSI escape sequences from text.

#### `getAnsiDimensions(text) -> {width, height}`

Get dimensions of ANSI text.

**Returns:** Map with `width` and `height` properties

## ANSI Escape Sequence Reference

### Supported SGR Codes

| Code | Description |
|------|-------------|
| `0` | Reset all attributes |
| `1` | Bold |
| `2` | Dim/faint |
| `3` | Italic |
| `4` | Underline |
| `22` | Normal intensity |
| `23` | Not italic |
| `24` | Not underlined |
| `30-37` | Foreground 8-color |
| `38;5;N` | Foreground 256-color |
| `38;2;R;G;B` | Foreground RGB |
| `39` | Default foreground |
| `40-47` | Background 8-color |
| `48;5;N` | Background 256-color |
| `48;2;R;G;B` | Background RGB |
| `49` | Default background |
| `90-97` | Bright foreground |
| `100-107` | Bright background |

### Supported Cursor Control

| Sequence | Description |
|----------|-------------|
| `ESC[H`, `ESC[f` | Cursor position |
| `ESC[A` | Cursor up |
| `ESC[B` | Cursor down |
| `ESC[C` | Cursor forward |
| `ESC[D` | Cursor back |
| `ESC[E` | Cursor next line |
| `ESC[F` | Cursor previous line |
| `ESC[G` | Cursor horizontal absolute |
| `ESC[s` | Save cursor position |
| `ESC[u` | Restore cursor position |

## Implementation Details

### Color Space Conversion

**8-Color to RGB:**
- Uses predefined palette matching standard terminal colors
- Bright variants (8-15) have enhanced brightness

**256-Color to RGB:**
- Colors 0-15: System colors (matches 8-color palette)
- Colors 16-231: 6×6×6 RGB cube
- Colors 232-255: Grayscale ramp (24 shades)

**Conversion formulas:**
```nim
# RGB cube (16-231)
let idx = colorNum - 16
let r = (idx div 36) mod 6  # 0-5
let g = (idx div 6) mod 6   # 0-5
let b = idx mod 6           # 0-5
# Map to 0-255: 0→0, 1-5→55+(n*40)

# Grayscale (232-255)
let gray = 8 + (colorNum - 232) * 10
```

### State Machine

The parser uses a simple state machine:

1. **Character Scan**: Check for `\x1b[` escape sequence start
2. **Parameter Collection**: Parse semicolon-separated numbers
3. **Command Processing**: Apply command based on final character
4. **Text Output**: Write styled characters to buffer

### Performance

- **Single-pass parsing**: No backtracking or lookahead
- **Lazy caching**: Buffers parsed on first use
- **Memory efficient**: Buffers trimmed to actual content size
- **Zero-copy text**: Original ANSI content stored, not duplicated

## Future Enhancements

### For SDL3 Terminal Emulator

- **Full VT100/xterm compatibility**: Additional escape sequences
- **Double-width characters**: CJK and emoji support
- **Alternate screen buffer**: For full-screen apps
- **Scrollback buffer**: History management
- **Mouse tracking**: `ESC[?1000h` sequences
- **Title setting**: `ESC]0;title\x07`
- **Bracketed paste**: `ESC[?2004h`

### Optimization Opportunities

- **Incremental parsing**: Parse only changed regions
- **GPU upload**: Direct buffer-to-texture for SDL3/OpenGL
- **Dirty tracking**: Only redraw changed cells
- **SIMD color conversion**: Batch 256-color to RGB

## Testing

See `docs/demos/ansi_demo.md` for comprehensive examples including:

- Basic colors and styles
- 256-color gradients
- RGB true color
- Mixed foreground/background
- Complex logos and art

## Related Files

- `lib/ansi_parser.nim` - Core parser
- `lib/ansi_art_bindings.nim` - Nimini bindings
- `lib/storie_md.nim` - Markdown integration
- `lib/storie_types.nim` - Type definitions
- `src/runtime_api.nim` - API registration
- `docs/demos/ansi_demo.md` - Demo and examples

## License

Same as tStorie project.
