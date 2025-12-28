## How to Export tStorie Programs to Native Nim

### Quick Start

The export system is integrated into the tStorie codebase. Here's how to use it:

### Method 1: Programmatic Export (Current Method)

```nim
import lib/storie_md
import lib/nim_export
import lib/tstorie_export_metadata
import nimini

# Initialize runtime and metadata
initRuntime()
initStdlib()
registerTStorieExportMetadata()

# Parse your markdown document
let doc = parseMarkdownDocument(readFile("myapp.md"))

# Export to standalone Nim
let standaloneCode = exportToNim(doc, "myapp.md")
writeFile("myapp_standalone.nim", standaloneCode)

# Export to tStorie-integrated Nim
let integratedCode = exportToTStorieNim(doc, "myapp.md")
writeFile("myapp.nim", integratedCode)

# Export with optimizations
let (optimizedCode, stats) = exportToNimOptimized(doc, "myapp.md")
echo "Optimizations: ", stats.importsOptimized, " imports removed"
writeFile("myapp_optimized.nim", optimizedCode)
```

### Method 2: CLI Tool (Recommended - To Be Implemented)

**Proposed usage:**

```bash
# Simple export
tstorie export myapp.md

# Specify output file
tstorie export myapp.md -o myapp.nim

# Export with optimizations
tstorie export myapp.md --optimize

# Export standalone version
tstorie export myapp.md --mode:standalone

# Export tStorie-integrated version (default)
tstorie export myapp.md --mode:integrated

# Show what would be generated
tstorie export myapp.md --dry-run

# Compile after export
tstorie export myapp.md --compile

# Export and run
tstorie export myapp.md --run
```

### Method 3: Interactive (In tStorie Runtime)

**Future possibility - add export command to running tStorie:**

```markdown
# My App

Press E to export this to Nim!

\`\`\`nim on:input
if event.kind == KeyEvent and event.keyCode == ord('E'):
  exportCurrentToNim("exported.nim")
  echo "Exported to exported.nim!"
\`\`\`
```

### Current Workflow (Step by Step)

1. **Create your tStorie markdown file** (`myapp.md`)
2. **Create an export script** (`export_myapp.nim`):

```nim
import lib/storie_md
import lib/nim_export
import lib/tstorie_export_metadata
import nimini

proc main() =
  # Initialize
  initRuntime()
  initStdlib()
  registerTStorieExportMetadata()
  
  # Load and parse markdown
  let mdContent = readFile("myapp.md")
  let doc = parseMarkdownDocument(mdContent)
  
  # Export (choose your mode)
  let code = exportToTStorieNim(doc, "myapp.md")
  
  # Write output
  writeFile("myapp.nim", code)
  echo "Exported to myapp.nim"

when isMainModule:
  main()
```

3. **Run the export script:**
```bash
nim c -r export_myapp.nim
```

4. **Compile the generated code:**
```bash
nim c myapp.nim
```

5. **Run your native executable:**
```bash
./myapp
```

### Example: Complete Export Workflow

**Input:** `clock.md`
```markdown
# Simple Clock

\`\`\`nim on:init
var seconds = 0
\`\`\`

\`\`\`nim on:update
seconds = seconds + 1
\`\`\`

\`\`\`nim on:render
write(10, 5, "Time: " & $seconds & "s")
\`\`\`
```

**Export Script:** `export.nim`
```nim
import lib/storie_md, lib/nim_export, lib/tstorie_export_metadata, nimini

initRuntime()
initStdlib()
registerTStorieExportMetadata()

let doc = parseMarkdownDocument(readFile("clock.md"))
let code = exportToTStorieNim(doc, "clock.md")
writeFile("clock.nim", code)
```

**Run:**
```bash
nim c -r export.nim    # Generate clock.nim
nim c clock.nim        # Compile to executable
./clock                # Run!
```

### Export Modes Comparison

| Feature | Standalone | tStorie-Integrated |
|---------|-----------|-------------------|
| **Dependencies** | Minimal | Full tStorie runtime |
| **Event Loop** | Basic `while running` | Professional with FPS control |
| **Terminal** | None | Full terminal management |
| **Best For** | Learning, simple scripts | Production apps |
| **Size** | Smaller | Larger |
| **Setup** | Simple | Automatic init/cleanup |

### Advanced: Export with Custom Options

```nim
import lib/storie_md
import lib/nim_export
import lib/tstorie_export_metadata
import nimini

proc exportWithOptions(mdFile: string, optimized: bool = false) =
  initRuntime()
  initStdlib()
  registerTStorieExportMetadata()
  
  let doc = parseMarkdownDocument(readFile(mdFile))
  
  let (code, stats) = if optimized:
    exportToTStorieNimOptimized(doc, mdFile)
  else:
    (exportToTStorieNim(doc, mdFile), OptimizationStats())
  
  let outFile = mdFile.replace(".md", ".nim")
  writeFile(outFile, code)
  
  echo "Exported to: ", outFile
  if optimized:
    echo "  Imports optimized: ", stats.importsOptimized
    echo "  Variables removed: ", stats.unusedVarsRemoved

# Use it
exportWithOptions("myapp.md", optimized = true)
```

### What's Next: CLI Tool

To make this more user-friendly, we should create a CLI tool:

**Implementation Plan:**

1. Create `tools/tstorie_export.nim`:
```nim
import std/[parseopt, os, strutils]
import ../lib/[storie_md, nim_export, tstorie_export_metadata]
import ../nimini

proc showHelp() =
  echo """
Usage: tstorie-export [options] <input.md>

Options:
  -o, --output <file>     Output file (default: input.nim)
  --optimize              Apply optimizations
  --mode:MODE             Export mode: standalone or integrated (default)
  -c, --compile           Compile after export
  -r, --run               Compile and run after export
  --dry-run              Show output without writing
  -h, --help             Show this help
"""

proc main() =
  # Parse args, export, optionally compile/run
  discard

when isMainModule:
  main()
```

2. Build it:
```bash
nim c -o:bin/tstorie-export tools/tstorie_export.nim
```

3. Use it:
```bash
tstorie-export myapp.md
tstorie-export myapp.md --optimize --compile
```

### Summary

**Current Method**: Create a small Nim script that imports the export modules and calls the export functions.

**Recommended Next Step**: Build a CLI tool (`tstorie-export`) to make it one command.

**Future Enhancement**: Integrate export into the tStorie runtime itself (export while running).
