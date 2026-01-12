## Convert old-style nimini bindings to registerNative() pattern
##
## Usage:
##   nim r tools/convert_to_register_native.nim lib/particles_bindings.nim
##   nim r tools/convert_to_register_native.nim --dry-run lib/particles_bindings.nim
##   nim r tools/convert_to_register_native.nim --all  # Convert all binding files

import std/[strutils, sequtils, tables, os, parseopt, algorithm, re]

type
  ParamInfo = object
    name: string
    paramType: string
    optional: bool
    defaultValue: string
  
  FunctionInfo = object
    name: string
    docComment: string
    params: seq[ParamInfo]
    returnType: string
    body: string
    registryAccess: string
    module: string
    lineStart: int
    lineEnd: int

proc extractDocComment(lines: seq[string], startIdx: int): string =
  ## Extract doc comment lines before the function
  var docLines: seq[string] = @[]
  var i = startIdx - 1
  while i >= 0 and lines[i].strip().startsWith("##"):
    let line = lines[i].strip()[2..^1].strip()
    if line.len > 0:
      docLines.add(line)
    dec i
  
  docLines.reverse()
  result = docLines.join(" ")

proc detectModule(content: string): string =
  ## Detect module name from imports (e.g., "import particles" -> "particles")
  for line in content.splitLines():
    let trimmed = line.strip()
    # Skip non-import lines, nimini imports, and relative imports
    if not trimmed.startsWith("import "):
      continue
    if "nimini" in trimmed or "../" in trimmed:
      continue
    
    let parts = trimmed.split()
    if parts.len >= 2:
      var moduleName = parts[1]
      
      # Skip grouped imports like std/[tables, math]
      if '[' in moduleName or ']' in moduleName:
        continue
      
      # Get just the module name without path
      moduleName = moduleName.split('/')[^1]
      
      # Skip standard library and internal imports
      if moduleName in ["tables", "strutils", "sequtils", "storie_types", "primitives", 
                        "math", "types", "layers", "graph", "os", "algorithm", "re"]:
        continue
      
      return moduleName
  
  return ""

proc detectRegistryVar(procBody: string): string =
  ## Detect global registry variable (e.g., gParticleSystems)
  let match = procBody.find(re"(g[A-Z][a-zA-Z]+)\[")
  if match != -1:
    let endIdx = procBody.find("[", match)
    if endIdx != -1:
      return procBody[match..<endIdx]
  return ""

proc parseBindingFile(filePath: string): seq[FunctionInfo] =
  ## Parse a *_bindings.nim file and extract function information
  result = @[]
  
  let content = readFile(filePath)
  let lines = content.splitLines()
  
  let moduleName = detectModule(content)
  
  var i = 0
  while i < lines.len:
    let line = lines[i]
    
    # Look for proc definitions with {.nimini.} pragma
    if line.strip().startsWith("proc ") and "{.nimini.}" in line:
      var fn: FunctionInfo
      fn.lineStart = i
      fn.module = moduleName
      
      # Extract function name
      let procMatch = line.find("proc ")
      if procMatch != -1:
        let nameStart = procMatch + 5
        var nameEnd = line.find("*", nameStart)
        if nameEnd == -1:
          nameEnd = line.find("(", nameStart)
        fn.name = line[nameStart..<nameEnd].strip()
      
      # Extract doc comment from previous lines
      fn.docComment = extractDocComment(lines, i)
      
      # Extract function body - everything until the next proc at column 0
      var bodyLines: seq[string] = @[]
      inc i
      
      while i < lines.len:
        let bodyLine = lines[i]
        
        # Stop if we hit another proc at column 0
        if bodyLine.strip().len > 0 and bodyLine[0] != ' ' and bodyLine[0] != '\t':
          if bodyLine.startsWith("proc "):
            dec i
            break
        
        bodyLines.add(bodyLine)
        inc i
      
      fn.lineEnd = i
      fn.body = bodyLines.join("\n")
      
      # Detect registry access pattern
      fn.registryAccess = detectRegistryVar(fn.body)
      
      result.add(fn)
    
    inc i

proc generateMetadataString(fn: FunctionInfo): string =
  ## Generate metadata string for registerNative()
  var parts: seq[string] = @[]
  
  # Description (first line of doc comment)
  if fn.docComment.len > 0:
    let desc = fn.docComment.split("Args:")[0].strip()
    parts.add(desc)
  else:
    parts.add(fn.name)
  
  # TODO: Parse Args from doc comment
  # For now, we'll leave it out since it requires more parsing
  
  # Libs
  if fn.module.len > 0:
    parts.add("Libs: " & fn.module)
  
  result = parts.join("\n")

proc generateRegisterNativeCall(fn: FunctionInfo): string =
  ## Generate the registerNative() call with inline body
  result = "registerNative(\"" & fn.name & "\", \"\"\"\n"
  result &= "  " & generateMetadataString(fn).replace("\n", "\n  ") & "\n"
  result &= "\"\"\"):\n"
  
  # Add the function body (remove first indent level)
  var bodyLines = fn.body.splitLines()
  for line in bodyLines:
    if line.strip().len > 0:
      # Remove common leading whitespace
      if line.len >= 2 and line[0..1] == "  ":
        result &= line[2..^1] & "\n"
      else:
        result &= line & "\n"
    else:
      result &= "\n"

proc convertFile(filePath: string, dryRun: bool = false): bool =
  ## Convert a binding file to use registerNative()
  echo "Processing: ", filePath
  
  let functions = parseBindingFile(filePath)
  
  if functions.len == 0:
    echo "  No functions found or already converted"
    return false
  
  echo "  Found ", functions.len, " functions to convert"
  
  if dryRun:
    echo "\n# Preview of conversions:"
    echo "# ========================\n"
    for i, fn in functions:
      if i >= 3:
        echo "  ... and ", functions.len - 3, " more functions"
        break
      echo generateRegisterNativeCall(fn)
      echo ""
    return false
  
  # Read original file
  let content = readFile(filePath)
  let lines = content.splitLines()
  
  # Build new file content
  var newLines: seq[string] = @[]
  var lastProcessedLine = -1
  
  for fn in functions:
    # Add lines before this function
    for i in (lastProcessedLine + 1)..<fn.lineStart:
      newLines.add(lines[i])
    
    # Add the registerNative call
    let converted = generateRegisterNativeCall(fn)
    newLines.add(converted.strip())
    newLines.add("")
    
    lastProcessedLine = fn.lineEnd - 1
  
  # Add remaining lines
  for i in (lastProcessedLine + 1)..<lines.len:
    newLines.add(lines[i])
  
  # Write back to file
  let backup = filePath & ".backup"
  copyFile(filePath, backup)
  echo "  Created backup: ", backup
  
  writeFile(filePath, newLines.join("\n"))
  echo "  ✓ Converted ", filePath
  
  return true

proc main() =
  var inputFiles: seq[string] = @[]
  var dryRun = false
  var convertAll = false
  
  # Parse command line
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "dry-run", "n": dryRun = true
      of "all", "a": convertAll = true
      of "help", "h":
        echo "Usage:"
        echo "  convert_to_register_native [options] <file.nim>"
        echo ""
        echo "Options:"
        echo "  --dry-run, -n    Show preview without modifying files"
        echo "  --all, -a        Convert all *_bindings.nim files"
        echo "  --help, -h       Show this help"
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      inputFiles.add(p.key)
  
  if convertAll:
    # Find all binding files
    for file in walkFiles("lib/*_bindings.nim"):
      if not convertFile(file, dryRun):
        echo "  Skipped (no conversion needed)"
      echo ""
  elif inputFiles.len > 0:
    for file in inputFiles:
      if not fileExists(file):
        echo "Error: File not found: ", file
        quit(1)
      if not convertFile(file, dryRun):
        echo "  Skipped (no conversion needed)"
  else:
    echo "Error: No input files specified"
    echo "Use --help for usage information"
    quit(1)
  
  if not dryRun:
    echo "\nDone! Backup files created with .backup extension"
    echo "Review the changes and remove backups if satisfied."

when isMainModule:
  main()
