## Export Command for tStorie CLI
##
## Handles the 'tstorie export' subcommand to export markdown documents
## to native Nim programs.

import os, strutils, parseopt, tables
import ../lib/storie_md
import ../lib/nim_export
import ../lib/tstorie_export_metadata
import ../nimini

type
  ExportMode* = enum
    Standalone,    ## Standalone executable with no tStorie dependencies
    Integrated     ## Integrated with tStorie runtime libraries

  ExportOptions* = object
    inputFile*: string
    outputFile*: string
    mode*: ExportMode
    optimize*: bool
    compile*: bool
    run*: bool
    dryRun*: bool
    verbose*: bool

proc showExportHelp() =
  echo "tstorie export - Export tStorie markdown to native Nim"
  echo ""
  echo "Usage:"
  echo "  tstorie export [OPTIONS] <file.md>"
  echo ""
  echo "Options:"
  echo "  -h, --help            Show this help message"
  echo "  -o, --output <file>   Output file (default: input.nim)"
  echo "  --mode <mode>         Export mode: standalone or integrated (default: standalone)"
  echo "  --optimize            Enable optimization passes"
  echo "  -c, --compile         Compile the exported Nim code"
  echo "  -r, --run             Compile and run the exported program"
  echo "  --dry-run             Show what would be exported without writing"
  echo "  -v, --verbose         Show detailed export information"
  echo ""
  echo "Export Modes:"
  echo "  standalone            Creates a self-contained Nim program"
  echo "                        - Minimal dependencies"
  echo "                        - Direct terminal output"
  echo "                        - Best for simple programs"
  echo ""
  echo "  integrated            Creates a program using tStorie runtime"
  echo "                        - Full tStorie API access"
  echo "                        - Advanced rendering and lifecycle"
  echo "                        - Better for complex interactive programs"
  echo ""
  echo "Examples:"
  echo "  tstorie export myapp.md"
  echo "    Export to myapp.nim (standalone mode)"
  echo ""
  echo "  tstorie export myapp.md -c"
  echo "    Export and compile"
  echo ""
  echo "  tstorie export myapp.md -r"
  echo "    Export, compile, and run"
  echo ""
  echo "  tstorie export myapp.md --mode integrated --optimize"
  echo "    Export with tStorie runtime and optimizations"
  echo ""
  echo "  tstorie export myapp.md -o output.nim --dry-run"
  echo "    Preview export without writing file"
  echo ""

proc parseExportArgs(): ExportOptions =
  ## Parse command-line arguments for export command
  result = ExportOptions(
    mode: Standalone,
    optimize: false,
    compile: false,
    run: false,
    dryRun: false,
    verbose: false
  )
  
  # Skip the "export" argument itself
  var args: seq[string] = @[]
  for i in 2..paramCount():  # Start from 2 to skip "tstorie" and "export"
    args.add(paramStr(i))
  
  var p = initOptParser(args)
  for kind, key, val in p.getopt():
    case kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case key
      of "h", "help":
        showExportHelp()
        quit(0)
      of "o", "output":
        result.outputFile = val
        if result.outputFile == "":
          echo "Error: --output requires a filename"
          quit(1)
      of "mode":
        case val.toLower
        of "standalone":
          result.mode = Standalone
        of "integrated":
          result.mode = Integrated
        else:
          echo "Error: Invalid mode '", val, "'. Use 'standalone' or 'integrated'"
          quit(1)
      of "optimize":
        result.optimize = true
      of "c", "compile":
        result.compile = true
      of "r", "run":
        result.run = true
        result.compile = true  # Running implies compiling
      of "dry-run":
        result.dryRun = true
      of "v", "verbose":
        result.verbose = true
      else:
        echo "Error: Unknown option '--", key, "'"
        echo "Use 'tstorie export --help' for usage information"
        quit(1)
    of cmdArgument:
      if result.inputFile.len == 0:
        result.inputFile = key
      else:
        echo "Error: Multiple input files specified"
        echo "Use 'tstorie export --help' for usage information"
        quit(1)
  
  # Validation
  if result.inputFile.len == 0:
    echo "Error: No input file specified"
    echo "Use 'tstorie export --help' for usage information"
    quit(1)
  
  if not fileExists(result.inputFile):
    echo "Error: Input file not found: ", result.inputFile
    quit(1)
  
  # Set default output file if not specified
  if result.outputFile.len == 0:
    let baseName = result.inputFile.extractFilename().changeFileExt("")
    # For integrated mode, place in current directory for easy compilation
    result.outputFile = baseName & ".nim"

proc runExport*() =
  ## Main entry point for export command
  let opts = parseExportArgs()
  
  if opts.verbose:
    echo "tStorie Export Tool"
    echo "-------------------"
    echo "Input file:  ", opts.inputFile
    echo "Output file: ", opts.outputFile
    echo "Mode:        ", opts.mode
    echo "Optimize:    ", opts.optimize
    echo "Compile:     ", opts.compile
    echo "Run:         ", opts.run
    echo "Dry run:     ", opts.dryRun
    echo ""
  
  # Initialize the Nimini runtime and register metadata
  initRuntime()
  registerTStorieExportMetadata()
  
  if opts.verbose:
    echo "✓ Runtime initialized"
    echo "✓ Metadata registered (", gFunctionMetadata.len, " functions)"
  
  # Parse the markdown file
  let mdContent = readFile(opts.inputFile)
  let doc = parseMarkdownDocument(mdContent)
  
  if opts.verbose:
    echo "✓ Parsed markdown document"
    echo "  Code blocks found: ", doc.codeBlocks.len
    echo "  Sections found: ", doc.sections.len
  
  # Generate Nim code
  let nimCode = 
    if opts.mode == Standalone:
      if opts.optimize:
        let (code, stats) = exportToNimOptimized(doc, opts.inputFile)
        code
      else:
        exportToNim(doc)
    else:  # Integrated mode
      if opts.optimize:
        let (code, stats) = exportToTStorieNimOptimized(doc, opts.inputFile)
        code
      else:
        exportToTStorieNim(doc)
  
  if opts.verbose:
    echo "✓ Generated Nim code (", nimCode.split('\n').len, " lines)"
    echo ""
  
  # Handle dry run mode
  if opts.dryRun:
    echo "=== DRY RUN: Generated Code ==="
    echo nimCode
    echo "=== END DRY RUN ==="
    echo ""
    echo "Would write to: ", opts.outputFile
    if opts.compile:
      echo "Would compile with: nim c ", opts.outputFile
    if opts.run:
      echo "Would run: ./", opts.outputFile.changeFileExt("")
    return
  
  # Write the output file
  writeFile(opts.outputFile, nimCode)
  echo "✓ Exported to: ", opts.outputFile
  
  # Show compilation guidance
  if opts.mode == Integrated or nimCode.contains("import lib/"):
    echo ""
    echo "Note: To compile this program:"
    echo "  1. Copy it to the tStorie root directory, OR"
    echo "  2. Compile from tStorie root: nim c ", opts.outputFile
    echo ""
  
  # Optionally compile
  if opts.compile:
    echo ""
    echo "Compiling..."
    let compileCmd = "nim c -d:release " & opts.outputFile
    if opts.verbose:
      echo "  Command: ", compileCmd
    
    let exitCode = execShellCmd(compileCmd)
    if exitCode != 0:
      echo "✗ Compilation failed (exit code: ", exitCode, ")"
      quit(1)
    
    echo "✓ Compiled successfully"
    
    # Optionally run
    if opts.run:
      echo ""
      echo "Running..."
      let exeFile = opts.outputFile.changeFileExt("")
      let runCmd = "./" & exeFile
      if opts.verbose:
        echo "  Command: ", runCmd
      
      let runExitCode = execShellCmd(runCmd)
      if runExitCode != 0:
        echo "✗ Program exited with code: ", runExitCode
        quit(runExitCode)
  
  echo ""
  echo "Done!"
