# Binary Size Analysis - Comprehensive Report

## TL;DR
The tstorie binary is **1.2 MB** (1,205,824 bytes) when fully optimized. The largest contributors are:
1. **Nimini scripting engine** (~450 KB, 37%)
2. **Feature bindings** (~200 KB, 17%)
3. **Standard library** (~150 KB, 12%)
4. **Core rendering** (~120 KB, 10%)

Only ~44 KB (4%) comes from optional features like HTTP client for gist loading.

## Detailed Component Breakdown

Analysis of `tstorie` binary (native Linux x64, 1.2MB):

| Component | Size | % | Description |
|-----------|------|---|-------------|
| **Nimini Runtime** | ~450 KB | 37% | Parser, VM, AST, backends, stdlib |
| **Feature Bindings** | ~200 KB | 17% | All *_bindings.nim modules (API exposure) |
| **Standard Library** | ~150 KB | 12% | Nim stdlib (strings, tables, algorithms) |
| **Core Rendering** | ~120 KB | 10% | Layout, layers, terminal handling |
| **FIGlet System** | ~80 KB | 7% | Font rendering + embedded font data |
| **Particle System** | ~60 KB | 5% | Particle engine + graph system |
| **HTTP Client** | ~44 KB | 4% | Gist loading (verified by test) |
| **Dungeon Gen** | ~40 KB | 3% | Procedural dungeon generation |
| **Audio System** | ~30 KB | 2% | Audio plugin loader |
| **ASCII Art** | ~30 KB | 2% | ASCII art generators |
| **Other/Overhead** | ~16 KB | 1% | Miscellaneous |

### Verified Measurements

These were directly measured by compiling with/without the feature:

| Feature | Actual Impact | Test Method |
|---------|--------------|-------------|
| **HTTP client (gist loading)** | **44 KB (3.76%)** | Compiled with `-d:noGistLoading` |

## Per-Module Analysis

### /lib/ Module Contributions

Attempting to measure individual modules by removing them reveals dependencies. Here's what we found:

| Module File | Can Remove? | Estimated Size | Notes |
|-------------|-------------|----------------|-------|
| `figlet_bindings.nim` | No | ~25 KB | Requires nimini, figlet |
| `figlet.nim` | No | ~55 KB | Font rendering + data |
| `ascii_art_bindings.nim` | No | ~15 KB | Requires nimini |
| `ansi_art_bindings.nim` | No | ~20 KB | ANSI parser API |
| `dungeon_bindings.nim` | No | ~15 KB | Requires nimini |
| `particles_bindings.nim` | No | ~25 KB | Requires nimini |
| `particles.nim` | No | ~35 KB | Particle engine core |
| `graph.nim` | No | ~25 KB | Graph system |
| `tui_helpers_bindings.nim` | No | ~20 KB | TUI dialog APIs |
| `text_editor_bindings.nim` | No | ~15 KB | Editor widget API |
| `storie_md.nim` | No | ~60 KB | Markdown parser + embedded fonts |
| `section_manager.nim` | No | ~40 KB | Section navigation |
| `layout.nim` | No | ~20 KB | Text layout |
| `canvas.nim` | No | ~80 KB | Canvas navigation |
| `audio.nim` | No | ~15 KB | Audio system (plugin-based now) |
| `audio_gen.nim` | No | ~15 KB | Audio generation core |
| **httpclient** | **Yes** | **44 KB** | Can disable with `-d:noGistLoading` |

**Total for all bindings**: ~200 KB  
**Total for feature implementations**: ~200 KB  
**Core infrastructure**: ~240 KB

Note: Most modules cannot be removed independently due to interdependencies. They all depend on nimini for scripting integration.

## What Makes TStorie Large

### 1. Nimini Scripting Engine (~450 KB, 37%)

```nim
import nimini  # In nimini/ directory
```

This is the single largest component, providing:
- **Parser/Tokenizer**: Parses nimini language syntax
- **Runtime VM**: Executes nimini bytecode
- **AST System**: Abstract syntax tree manipulation
- **Multiple Backends**: Can generate Nim, Python, JavaScript
- **Standard Library**: Built-in functions (math, strings, arrays, etc.)
- **Type System**: Runtime type checking and coercion

Located in `nimini/` directory with these key modules:
- `nimini/parser.nim` - Language parser (~14 KB of symbols)
- `nimini/runtime.nim` - VM executor (~11 KB of symbols)
- `nimini/stdlib/` - Standard library (~80 KB total)
- `nimini/backends/` - Code generation

This provides the flexibility that makes tstorie scriptable, but comes at a cost.

### 2. Feature Bindings (~200 KB, 17%)

All the `*_bindings.nim` modules that expose tstorie APIs to nimini scripts:

- **figlet_bindings.nim** (~25 KB): FIGlet text art API
- **particles_bindings.nim** (~25 KB): Particle system control
- **tui_helpers_bindings.nim** (~20 KB): Dialog and UI helpers
- **text_editor_bindings.nim** (~15 KB): Text editor widget
- **ascii_art_bindings.nim** (~15 KB): ASCII art generation
- **ansi_art_bindings.nim** (~20 KB): ANSI art parser
- *Top Symbol Contributors

Based on `nm --size-sort` analysis, the largest individual functions:

| Symbol | Size | Description |
|--------|------|-------------|
| `createNiminiContext` | 23 KB | Initialize nimini VM |
| `parsePrefix` | 22 KB | Nimini parser prefix expressions |
| `registerTStorieExportMetadata` | 17 KB | Export system metadata |
| `parseMarkdownDocument` | 17 KB | Markdown parsing |
| `initStdlib` | 16 KB | Nimini stdlib initialization |
| `runExport` | 15 KB | Export command handler |
| `parseStmt` | 14 KB | Nimini statement parser |
| `buildExportContext` | 14 KB | Export context builder |
| `canvasRender` | 12 KB | Canvas rendering |
| `main` | 12 KB | Main entry point |

These 10 symbols alone account for ~168 KB (14% of binary).

## Optimization Opportunities

### Already Implemented ✓

**HTTP Client Conditional** - Working now
```bash
nim c -d:noGistLoading tstorie.nim  # Saves 44 KB
```

### Easy Wins (Conditional Compilation)

**1. Make All Bindings Optional** - ~200 KB potential savings
```nim
when not defined(minimal):
  import lib/figlet_bindings
  import lib/particles_bindings
  import lib/dungeon_bindings
  import lib/ascii_art_bindings
  import lib/ansi_art_bindings
  import lib/tui_helpers_bindings
  import lib/text_editor_bindings
```

**2. Embedded Fonts Optional** - ~40-50 KB savings
Move FIGlet fonts to external files:
```nim
when not defined(embedFonts):
  # Load fonts from disk instead
```

**3. Feature Flags** - Granular control
```nim
when defined(withParticles):
  import lib/particles_bindings
when defined(withDungeons):
  import lib/dungeon_bindings
```

### Medium Effort

**4. Plugin System** - Already done for audio, extend to:
- FIGlet rendering
- Particle system
- Dungeon generation
- Keep core minimal, load on demand

**5. Nimini Stdlib Trimming** - ~50-80 KB savings
Remove unused nimini stdlib modules

### Build Variants

**tstorie-minimal**: Core + markdown only
- Remove all bindings
- Remove nimini or make optional
- Estimated size: ~400-500 KB

**tstorie-standard**: Common features
- Core + FIGlet + basic features
- Estimated size: ~700-800 KB

**tstorie-full**: Everything (current)
- All features enabled
- Current size: 1.2 MB

**tstorie-web**: WASM optimized
- Already exists, proves core is compact
- Current size: ~180 KB

## Size Comparison Context

- **tstorie (current)**: 1.2 MB
- **tstorie without gist**: 1.16 MB
- **tstorie WASM**: ~180 KB (proves core is compact)
- **Typical Go CLI tool**: 2-10 MB
- **Typical Rust CLI tool**: 1-5 MB
- **Typical terminal app (C/C++)**: 500 KB - 2 MB
- **Python interpreter**: ~4 MB
- **Node.js runtime**: ~50 MB
- **Electron app**: 50-100 MB

tstorie is **reasonably sized** for a feature-rich terminal application with embedded scripting.

## Analysis Methodology

This analysis used multiple approaches:

1. **Direct Measurement**: Compiled with/without features using `-d:` flags
2. **Symbol Analysis**: Used `nm --size-sort` to identify largest functions
3. **Code Inspection**: Analyzed import dependencies and module structure
4. **Comparative Builds**: Compared native vs WASM builds
5. **Estimates**: For interdependent modules, estimated based on code size and complexity

### Tools Used

```bash
# Size measurement scripts
./analyze_binary_size.sh        # Per-module testing
./analyze_size_detailed.sh      # Symbol analysis

# Manual analysis
nim c -d:noGistLoading tstorie.nim
nm --print-size --size-sort --radix=d tstorie
```

## Conclusion

The tstorie binary is **1.2 MB**, with these key contributors:

1. **Nimini engine** (450 KB, 37%) - Provides scripting flexibility
2. **Feature bindings** (200 KB, 17%) - Expose APIs to scripts
3. **Standard library** (150 KB, 12%) - Nim stdlib overhead
4. **Core rendering** (120 KB, 10%) - Layout, layers, terminal
5. **Feature implementations** (240 KB, 20%) - FIGlet, particles, etc
6. **Other** (40 KB, 4%) - Including HTTP client

**Key Finding**: The nimini scripting system and feature bindings account for **54%** of the binary. This is the price of flexibility. The core rendering engine is quite compact (~120 KB), as proven by the 180 KB WASM build.

**For Smaller Binaries**: Use conditional compilation to disable unneeded features. The HTTP client flag already works (`-d:noGistLoading` saves 44 KB). Implementing similar flags for binding modules could save ~200 KB.

**Trade-off**: A minimal build without nimini and most features could be ~400-500 KB, but would lose the scriptability that makes tstorie unique.

## Audio Plugin Context

Even though the audio plugin didn't dramatically shrink tstorie (it was only ~50-100 KB), the plugin system is still valuable:

✅ **Clean architecture** - Separates audio from core  
✅ **WASM benefits** - WASM builds don't include miniaudio at all  
✅ **Future-proof** - Easy to swap audio backends  
✅ **Lazy loading** - Plugin loads only when audio used  

The audio work validated that plugins are a good approach for optional features.
