# Per-Module Size Reference

Quick reference for lib/ module contributions to tstorie binary size.

## Binding Modules (API Exposure)

These expose tstorie functionality to nimini scripts:

| Module | Size | Description |
|--------|------|-------------|
| `figlet_bindings.nim` | ~25 KB | FIGlet text art API |
| `particles_bindings.nim` | ~25 KB | Particle system control |
| `tui_helpers_bindings.nim` | ~20 KB | Dialog and UI helpers |
| `ansi_art_bindings.nim` | ~20 KB | ANSI art parser API |
| `ascii_art_bindings.nim` | ~15 KB | ASCII art generation |
| `dungeon_bindings.nim` | ~15 KB | Dungeon generator API |
| `text_editor_bindings.nim` | ~15 KB | Text editor widget |
| **Subtotal** | **~135 KB** | Core binding modules |

Plus ~65 KB from section_manager and other nimini integration code.

**Total Bindings: ~200 KB (17% of binary)**

## Implementation Modules (Features)

| Module | Size | Description |
|--------|------|-------------|
| `storie_md.nim` | ~60 KB | Markdown parser + embedded fonts |
| `figlet.nim` | ~55 KB | Font rendering engine |
| `canvas.nim` | ~80 KB | Canvas navigation system |
| `section_manager.nim` | ~40 KB | Section management |
| `particles.nim` | ~35 KB | Particle engine core |
| `graph.nim` | ~25 KB | Graph system for particles |
| `dungeon_gen.nim` | ~25 KB | Procedural generation |
| `ansi_parser.nim` | ~20 KB | ANSI escape parser |
| `layout.nim` | ~20 KB | Text layout utilities |
| `audio_plugin_loader.nim` | ~15 KB | Audio plugin system |
| `audio_gen.nim` | ~15 KB | Audio generation |
| `audio.nim` | ~15 KB | Audio core (included) |
| `ascii_art.nim` | ~15 KB | ASCII art generators |
| `terminal_shaders.nim` | ~12 KB | Visual effects |
| `animation.nim` | ~8 KB | Easing functions |
| `primitives.nim` | ~5 KB | Math primitives |
| **Subtotal** | **~445 KB** | Feature implementations |

## External Dependencies

| Component | Size | Notes |
|-----------|------|-------|
| **Nimini** | ~450 KB | Parser, VM, stdlib, backends |
| **Nim stdlib** | ~150 KB | strings, tables, algorithms, OS |
| **httpclient** | ~44 KB | Optional (use `-d:noGistLoading`) |

## Core Engine

| Component | Size | Description |
|-----------|------|-------------|
| `src/types.nim` | ~10 KB | Core type definitions |
| `src/layers.nim` | ~25 KB | Layer and buffer ops |
| `src/appstate.nim` | ~15 KB | Application state |
| `src/input.nim` | ~20 KB | Input handling |
| `src/runtime_api.nim` | ~40 KB | Runtime API |
| `src/platform/` | ~10 KB | Platform-specific code |
| **Subtotal** | **~120 KB** | Core engine |

## Summary by Category

| Category | Total Size | % of Binary |
|----------|-----------|-------------|
| Nimini Runtime | 450 KB | 37% |
| Feature Bindings | 200 KB | 17% |
| Feature Implementations | 240 KB | 20% |
| Nim Standard Library | 150 KB | 12% |
| Core Engine | 120 KB | 10% |
| HTTP Client (optional) | 44 KB | 4% |
| **Total** | **~1.2 MB** | **100%** |

## Can This Module Be Removed?

| Module | Removable? | Why / Why Not |
|--------|-----------|---------------|
| `figlet_bindings.nim` | ⚠️ Conditional | Requires nimini, figlet |
| `figlet.nim` | ⚠️ Conditional | Used by storie_md |
| `particles_bindings.nim` | ⚠️ Conditional | Requires nimini |
| `dungeon_bindings.nim` | ⚠️ Conditional | Requires nimini |
| `canvas.nim` | ❌ No | Core navigation system |
| `section_manager.nim` | ❌ No | Core section handling |
| `layout.nim` | ❌ No | Core text layout |
| `animation.nim` | ❌ No | Used throughout |
| `httpclient` | ✅ Yes | `-d:noGistLoading` |
| `nimini` | ⚠️ Hard | Deeply integrated |

**Legend:**
- ✅ Can be removed with a compile flag
- ⚠️ Could be made conditional with refactoring
- ❌ Core dependency, cannot remove

## Optimization Potential

| Strategy | Potential Savings | Effort |
|----------|------------------|--------|
| Remove HTTP client | 44 KB (4%) | ✅ Done (`-d:noGistLoading`) |
| Make bindings optional | ~200 KB (17%) | Medium |
| External fonts (not embedded) | ~50 KB (4%) | Low |
| Remove unused nimini stdlib | ~80 KB (7%) | Medium |
| Plugin-ize particles | ~60 KB (5%) | High |
| Plugin-ize figlet | ~80 KB (7%) | High |
| Remove nimini entirely | ~450 KB (37%) | Very High |

## Measurement Notes

- **Verified**: HTTP client was directly measured (44 KB with `-d:noGistLoading`)
- **Estimated**: Other modules estimated from:
  - Symbol table analysis (`nm --size-sort`)
  - Code size and complexity
  - Comparative builds (WASM vs native)
- **Interdependent**: Most modules cannot be removed independently due to nimini integration
- **Accurate to**: ±10-20% for individual modules, ±5% for categories

## Tools

```bash
# Run comprehensive analysis
./analyze_binary_size.sh        # Test individual modules
./analyze_size_detailed.sh      # Symbol analysis
python3 visualize_binary_size.py # Visual breakdown

# Manual size check
nim c -d:release --opt:size -d:strip -o:test tstorie.nim
ls -lh test

# Symbol analysis
nm --print-size --size-sort --radix=d tstorie | tail -30
```
