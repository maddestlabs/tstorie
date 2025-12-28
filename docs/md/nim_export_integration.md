## Example: Integrating Nim Export into tStorie CLI

Here's how you could add an export command to tStorie:

```nim
# In tstorie.nim or a new module

import lib/storie_md
import lib/nim_export

proc cmdExport(inputFile: string, outputFile: string = "") =
  ## Export a tStorie markdown file to compilable Nim code
  echo "Exporting ", inputFile, " to native Nim..."
  
  # Determine output filename
  let outFile = if outputFile.len > 0:
    outputFile
  else:
    inputFile.changeFileExt("nim")
  
  # Read and parse markdown
  let content = readFile(inputFile)
  let doc = parseMarkdownDocument(content)
  
  # Analyze and report
  echo "\nAnalyzing code blocks..."
  echo "  Found ", doc.codeBlocks.len, " code blocks"
  
  let imports = analyzeCodeBlocks(doc.codeBlocks)
  if imports.stdLibImports.len > 0:
    echo "  Standard library: ", imports.stdLibImports.toSeq.join(", ")
  if imports.storieLibImports.len > 0:
    echo "  tStorie libraries: ", imports.storieLibImports.toSeq.join(", ")
  
  # Generate and save
  echo "\nGenerating Nim code..."
  exportToNimFile(doc, outFile, inputFile.extractFilename)
  
  echo "✓ Exported to ", outFile
  echo "\nTo compile:"
  echo "  nim c -d:release ", outFile

# Add to command-line parsing:

proc main() =
  var p = initOptParser()
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "export":
        # Usage: tstorie --export input.md [output.nim]
        p.next()
        if p.kind != cmdArgument:
          echo "Error: --export requires input file"
          quit(1)
        let inputFile = p.key
        var outputFile = ""
        p.next()
        if p.kind == cmdArgument:
          outputFile = p.key
        cmdExport(inputFile, outputFile)
        quit(0)
      # ... other options
    of cmdArgument:
      # ... existing argument handling

when isMainModule:
  main()
```

## Example Usage

```bash
# Export a markdown file to Nim
./tstorie --export docs/demos/clock.md

# Specify output filename
./tstorie --export docs/demos/clock.md clock_native.nim

# Then compile the exported code
nim c -d:release clock_native.nim

# Run it
./clock_native
```

## Interactive Editor Integration

For the editor mode, you could add an export command:

```nim
# In editor handling code

proc handleEditorCommand(cmd: string) =
  case cmd
  of "export", "e":
    echo "Export to Nim..."
    let doc = parseMarkdownDocument(currentEditorContent)
    let outFile = "exported_" & $epochTime().int & ".nim"
    exportToNimFile(doc, outFile, "editor.md")
    echo "Exported to ", outFile
  # ... other commands
```

Users could then type `:export` or `:e` in editor mode to export their current work.

## Batch Export Tool

Create a standalone tool for batch exports:

```nim
# batch_export.nim

import os, strutils, lib/storie_md, lib/nim_export

proc exportDirectory(dir: string, outputDir: string = "exported") =
  ## Export all .md files in a directory
  createDir(outputDir)
  
  for file in walkFiles(dir / "*.md"):
    echo "Processing ", file
    try:
      let content = readFile(file)
      let doc = parseMarkdownDocument(content)
      
      let basename = file.extractFilename.changeFileExt("")
      let outFile = outputDir / basename & ".nim"
      
      exportToNimFile(doc, outFile, file.extractFilename)
      echo "  → ", outFile
    except:
      echo "  ✗ Error: ", getCurrentExceptionMsg()

when isMainModule:
  if paramCount() < 1:
    echo "Usage: batch_export <directory> [output_dir]"
    quit(1)
  
  let inDir = paramStr(1)
  let outDir = if paramCount() >= 2: paramStr(2) else: "exported"
  
  exportDirectory(inDir, outDir)
```

Usage:
```bash
nim c batch_export.nim
./batch_export docs/demos/ exported_demos/
```

## Web Interface Integration

For the web version, add an export button:

```javascript
// In the web UI

function exportToNim() {
  // Get current markdown content
  const markdown = editor.getValue();
  
  // Call the WASM-compiled export function
  const nimCode = Module.ccall('exportMarkdownToNim',
    'string',
    ['string', 'string'],
    [markdown, 'export.md']
  );
  
  // Download the generated code
  downloadFile('exported.nim', nimCode);
}

function downloadFile(filename, content) {
  const blob = new Blob([content], { type: 'text/plain' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
```

Add export button to UI:
```html
<button onclick="exportToNim()" class="export-btn">
  Export to Nim
</button>
```

## Gist Integration

Export gists to compilable Nim:

```nim
import lib/gist_api, lib/storie_md, lib/nim_export

proc exportGist(gistId: string, token: string = "") =
  echo "Fetching gist ", gistId
  let gist = loadGist(gistId, token)
  
  let mdFile = gist.getFirstMarkdownFile()
  let doc = parseMarkdownDocument(mdFile.content)
  
  let outFile = gist.description & ".nim"
  exportToNimFile(doc, outFile, mdFile.filename)
  
  echo "Exported ", outFile

# Usage:
# exportGist("863a4175989370857ccd67cb5492ac11")
```

## Build Automation

Create a nimble task for exporting demos:

```nim
# In tstorie.nimble

task exportDemos, "Export all demo files to native Nim":
  echo "Exporting demo files..."
  exec "nim c -r batch_export.nim docs/demos/ exported_demos/"
  echo "Compiling exported demos..."
  for file in listFiles("exported_demos"):
    if file.endsWith(".nim"):
      exec "nim c -d:release " & file
```

Then run:
```bash
nimble exportDemos
```

## Development Workflow

Recommended workflow for users:

1. **Prototype in tStorie**
   ```bash
   tstorie --content demo:mygame
   # Edit and iterate quickly
   ```

2. **Export when satisfied**
   ```bash
   tstorie --export mygame.md mygame.nim
   ```

3. **Profile and optimize**
   ```bash
   nim c -d:release --profiler:on mygame.nim
   ./mygame
   ```

4. **Iterate on exported code** (advanced users)
   - Hand-optimize hot loops
   - Add proper type annotations
   - Integrate with other Nim libraries

## Future: CI/CD Integration

GitHub Actions workflow for auto-exporting:

```yaml
# .github/workflows/export.yml

name: Export tStorie to Nim

on:
  push:
    paths:
      - 'stories/**/*.md'

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Nim
        uses: jiro4989/setup-nim-action@v1
      
      - name: Export stories
        run: |
          nim c batch_export.nim
          ./batch_export stories/ exported/
      
      - name: Compile exported files
        run: |
          for file in exported/*.nim; do
            nim c -d:release "$file"
          done
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v2
        with:
          name: compiled-binaries
          path: exported/*
```

This automatically exports and compiles all stories when markdown files change!
