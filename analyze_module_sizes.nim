## Binary Size Analysis Tool for tstorie
## Compiles with different module configurations to measure contributions

import os, osproc, strutils, strformat, tables, algorithm

type
  ModuleTest = object
    name: string
    pattern: string  # What to comment out
    defineFlag: string  # Alternative: use compile flag
    notes: string
    canDisable: bool  # Whether it can be disabled without breaking build

const
  buildFlags = "-d:release --opt:size -d:strip -d:useMalloc --passC:-flto --passL:-flto --passL:-s"
  sourceFile = "tstorie.nim"

var results: seq[(string, int, float, string)] = @[]

proc getFileSize(path: string): int =
  try:
    return getFileInfo(path).size.int
  except:
    return 0

proc compileWithoutModule(moduleName, pattern, defineFlag: string): int =
  ## Compile tstorie without a specific module and return size
  ## Returns -1 if compilation fails
  let tmpDir = "size_test_tmp"
  let tmpBin = tmpDir / "tstorie_test"
  
  createDir(tmpDir)
  defer: removeDir(tmpDir)
  
  var cmd = "nim c " & buildFlags
  
  if defineFlag != "":
    # Use compile-time flag
    cmd &= " " & defineFlag
    cmd &= " -o:" & tmpBin & " " & sourceFile
  else:
    # Comment out import in source
    let tmpSource = tmpDir / "tstorie_test.nim"
    let originalContent = readFile(sourceFile)
    let modifiedContent = originalContent.replace(pattern, "# " & pattern & "  # DISABLED FOR ANALYSIS")
    writeFile(tmpSource, modifiedContent)
    cmd &= " -o:" & tmpBin & " " & tmpSource
  
  # Suppress output
  cmd &= " 2>&1 > /dev/null"
  
  let exitCode = execCmd(cmd)
  if exitCode != 0:
    return -1
  
  return getFileSize(tmpBin)

proc analyzeModules() =
  echo "======================================"
  echo "TStorie Binary Size Analysis"
  echo "======================================"
  echo ""
  
  # Get baseline
  echo "Building baseline (full binary)..."
  let buildCmd = "nim c " & buildFlags & " -o:tstorie " & sourceFile & " 2>&1 | tail -1"
  discard execCmd(buildCmd)
  let baselineSize = getFileSize("tstorie")
  
  echo &"Baseline size: {baselineSize.formatSize} ({baselineSize} bytes)"
  echo ""
  
  # Define modules to test
  let modules = [
    ModuleTest(name: "figlet_bindings", pattern: "import lib/figlet_bindings", 
               notes: "FIGlet API for nimini", canDisable: true),
    ModuleTest(name: "figlet", pattern: "import lib/figlet",
               notes: "FIGlet rendering engine", canDisable: false),
    ModuleTest(name: "ascii_art_bindings", pattern: "import lib/ascii_art_bindings",
               notes: "ASCII art API", canDisable: true),
    ModuleTest(name: "ansi_art_bindings", pattern: "import lib/ansi_art_bindings",
               notes: "ANSI art parser API", canDisable: true),
    ModuleTest(name: "dungeon_bindings", pattern: "import lib/dungeon_bindings",
               notes: "Dungeon generator API", canDisable: true),
    ModuleTest(name: "particles_bindings", pattern: "import lib/particles_bindings",
               notes: "Particle system API", canDisable: true),
    ModuleTest(name: "tui_helpers_bindings", pattern: "import lib/tui_helpers_bindings",
               notes: "TUI helpers API", canDisable: true),
    ModuleTest(name: "text_editor_bindings", pattern: "import lib/text_editor_bindings",
               notes: "Text editor API", canDisable: true),
    ModuleTest(name: "animation", pattern: "import lib/animation",
               notes: "Animation/easing helpers", canDisable: true),
    ModuleTest(name: "canvas", pattern: "import lib/canvas",
               notes: "Canvas navigation", canDisable: false),
    ModuleTest(name: "gist_loading", pattern: "", defineFlag: "-d:noGistLoading",
               notes: "HTTP client for gist loading", canDisable: true),
  ]
  
  echo "Testing module contributions..."
  echo ""
  
  for module in modules:
    stdout.write &"  Testing {module.name}... "
    stdout.flushFile()
    
    let newSize = compileWithoutModule(module.name, module.pattern, module.defineFlag)
    
    if newSize < 0:
      echo "✗ Build failed (has dependencies)"
      results.add((module.name, 0, 0.0, module.notes & " [has dependencies]"))
    else:
      let diff = baselineSize - newSize
      let percent = (diff.float / baselineSize.float) * 100.0
      
      if diff > 1024:  # Only report if > 1KB
        echo &"✓ Saves {diff.formatSize} ({percent:.2f}%)"
        results.add((module.name, diff, percent, module.notes))
      else:
        echo "✓ ~0 KB"
        results.add((module.name, 0, 0.0, module.notes))
  
  echo ""
  echo "======================================"
  echo "Results Summary"
  echo "======================================"
  echo ""
  echo &"Baseline: {baselineSize.formatSize}"
  echo ""
  
  # Sort by size contribution (descending)
  results.sort(proc (a, b: auto): int = cmp(b[1], a[1]))
  
  echo "| Module | Size Contribution | % of Binary | Notes |"
  echo "|--------|------------------|-------------|-------|"
  
  for (name, size, pct, notes) in results:
    if size > 0:
      echo &"| {name:<25} | {size.formatSize:>10} | {pct:>6.2f}% | {notes} |"
    else:
      echo &"| {name:<25} | ~0 KB | 0.00% | {notes} |"
  
  # Save to file
  let outFile = open("binary_size_results.md", fmWrite)
  outFile.writeLine("# TStorie Binary Size Analysis")
  outFile.writeLine("")
  outFile.writeLine(&"**Baseline**: {baselineSize.formatSize} ({baselineSize} bytes)")
  outFile.writeLine("")
  outFile.writeLine("## Module Contributions")
  outFile.writeLine("")
  outFile.writeLine("| Module | Size Contribution | % of Binary | Notes |")
  outFile.writeLine("|--------|------------------|-------------|-------|")
  
  for (name, size, pct, notes) in results:
    if size > 0:
      outFile.writeLine(&"| {name} | {size.formatSize} | {pct:.2f}% | {notes} |")
    else:
      outFile.writeLine(&"| {name} | ~0 KB | 0.00% | {notes} |")
  
  outFile.close()
  echo ""
  echo "Results saved to: binary_size_results.md"

when isMainModule:
  analyzeModules()
