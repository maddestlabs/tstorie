# TStoried - TStorie Editor

A lightweight, standalone terminal markdown editor built for TStorie content.

## Features

- ✅ **Multi-line text editing** with cursor navigation
- ✅ **Line numbers** with current line highlighting  
- ✅ **File operations** - load and save markdown files
- ✅ **GitHub Gist integration** - load, create, and update gists
- ✅ **File browser** - browse local files and gists
- ✅ **Status bar** with current file and command hints
- ✅ **Theme system** - Miami Vice theme applied
- ✅ **Live preview** - Native: tmux split with tstorie | WASM: split-canvas view
- 🚧 **Syntax highlighting** (planned)

## Installation

```bash
# Build native editor
./builded.sh

# Or with specific options
./builded.sh --native --run
```

## Usage

```bash
# Start with new document
./tstoried

# Load existing file
./tstoried README.md

# Load from gist
./tstoried --gist abc123def456

# Show help
./tstoried --help
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+Q` | Quit editor |
| `Ctrl+W` | Save current file |
| `Ctrl+G` | Create or update gist |
| `Ctrl+O` | Open file/gist browser |
| `Ctrl+R` | Preview (tmux split or full screen) |
| `Esc` | Cancel/go back |
| Regular typing | Insert characters |
| `Backspace` | Delete character |
| `Enter` | New line |

### Browser Mode
| Key | Action |
|-----|--------|
| `j` or `J` | Move down |
| `k` or `K` | Move up |
| `Enter` | Open selected file/gist |
| `Esc` | Back to editor |

### Preview Mode (WASM only)
| Key | Action |
|-----|--------|
| `Space` or `Enter` | Next section |
| `B` | Previous section |
| `Esc` | Exit preview |

## GitHub Token Setup

For gist operations, set your GitHub token:

```bash
# Environment variable (recommended)
export GITHUB_TOKEN="ghp_your_token_here"
./tstoried

# Or compile-time (for deployments)
./builded.sh --token "ghp_your_token_here"
```

See [docs/md/CLASSROOM_SETUP.md](docs/md/CLASSROOM_SETUP.md) for educational use guidelines.

## Architecture

TStoried is built **standalone** - it does NOT depend on tstorie.nim. This design decision was intentional:

1. **Independence** - Editor functionality separate from game engine
2. **Learning tool** - Reveals what should be extracted from tstorie.nim
3. **Reference implementation** - Shows minimal terminal app needs
4. **Fast iteration** - No need to refactor tstorie.nim first

See [docs/md/TSTORIED_LESSONS.md](docs/md/TSTORIED_LESSONS.md) for architectural insights.

## File Structure

```
tstoried.nim              # Main editor application (463 lines)
lib/
  editor_base.nim         # Basic types (Color, Style, InputEvent)
  gist_api.nim            # GitHub Gist API wrapper
  storie_types.nim        # Core TStorie types
  storie_themes.nim       # Theme definitions
builded.sh                # Build script with token injection
```

## Current Limitations

- **Arrow keys not yet implemented** - Currently j/k in browser mode only
- **No undo/redo** - Coming soon
- **No syntax highlighting** - Displays plain text
- **No live preview** - Planned integration with tstorie canvas
- **No split view** - Single pane only

## Development Status

✅ **Core editor working** - File load/save, basic editing  
✅ **Gist integration working** - Create/load/update  
🚧 **Navigation improvements** - Arrow keys, page up/down  
🚧 **Syntax highlighting** - Markdown awareness  
🚧 **Preview mode** - Render using tstorie  
🚧 **Split view** - Edit + preview side-by-side  

## Binary Size

The standalone editor compiles to a tiny **236KB** native binary with full optimization:
- Release mode (`-d:release`)
- Size optimization (`--opt:size`)  
- Symbol stripping (`-d:strip`)
- Custom allocator (`-d:useMalloc`)

## Performance

- Compilation: ~5.7 seconds
- Startup: < 10ms
- No external dependencies at runtime

## Contributing

This is the foundation for future TStorie editing tools. Contributions welcome for:
- Arrow key navigation
- Syntax highlighting
- Live preview integration
- Additional keyboard shortcuts
- Bug fixes

## License

See [LICENSE](LICENSE) for details.
