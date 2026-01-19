## Magic - Compress and decompress tstorie code snippets
##
## Usage:
##   tstorie magic pack <input.md>         # Compress markdown to base64
##   tstorie magic unpack <compressed>     # Decompress base64 to markdown
##   tstorie magic pack <input.md> -o <output.txt>  # Save to file
##   tstorie magic validate <preset.md>     # Check preset for parameter safety

import std/[strutils, base64, os, tables, re]
import zippy  # Pure Nim - works on native AND WASM
import ../lib/magic

proc compressString*(input: string): string =
  ## Compress a string using zippy and encode as base64
  ## Uses dfZlib (zlib format, RFC 1950) - compatible with JS CompressionStream('deflate')
  let compressed = compress(input, dataFormat = dfZlib)
  result = encode(compressed)

proc decompressString*(input: string): string =
  ## Decode base64 and decompress using zippy
  ## Uses dfZlib (zlib format, RFC 1950) - compatible with JS DecompressionStream('deflate')
  let decoded = decode(input)
  result = uncompress(decoded, dataFormat = dfZlib)

proc packMarkdown*(filePath: string): string =
  ## Read a markdown file and return compressed base64 string
  if not fileExists(filePath):
    raise newException(IOError, "File not found: " & filePath)
  
  let content = readFile(filePath)
  result = compressString(content)

proc unpackToMarkdown*(compressed: string): string =
  ## Decompress a base64 string back to markdown
  result = decompressString(compressed)

proc validatePreset*(filePath: string): tuple[ok: bool, warnings: seq[string], declared: seq[string], found: seq[string]] =
  ## Validate a preset file for parameter safety
  ## Returns (ok, warnings, declaredParams, foundPlaceholders)
  result.ok = true
  result.warnings = @[]
  result.declared = @[]
  result.found = @[]
  
  if not fileExists(filePath):
    result.ok = false
    result.warnings.add("File not found: " & filePath)
    return
  
  let content = readFile(filePath)
  
  # Extract declared parameters from <!-- SUGAR_PARAMS: name, count --> 
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("<!--") and trimmed.contains("SUGAR_PARAMS:"):
      let startPos = trimmed.find("SUGAR_PARAMS:") + 13
      let endPos = trimmed.find("-->", startPos)
      if endPos > startPos:
        let paramList = trimmed[startPos..<endPos].strip()
        for param in paramList.split(','):
          let cleaned = param.strip()
          if cleaned.len > 0:
            result.declared.add(cleaned)
      break
  
  # Find all parameter placeholders (support multiple syntaxes)
  let patterns = [
    (re"{{(\w+)}}", "{{PARAM}}"),  # Mustache style
    (re"@(\w+)@", "@PARAM@"),       # @ markers
    (re"\$(\w+)\$", "$PARAM$"),     # $ markers
    (re"<!--(\w+)-->", "<!--PARAM-->")  # HTML comment style
  ]
  
  var syntaxUsed = ""
  for (pattern, syntax) in patterns:
    for match in content.findAll(pattern):
      # Extract parameter name from match
      var param = ""
      case syntax:
      of "{{PARAM}}":
        param = match[2..^3]  # Strip {{ and }}
      of "@PARAM@":
        param = match[1..^2]  # Strip @ and @
      of "$PARAM$":
        param = match[1..^2]  # Strip $ and $
      of "<!--PARAM-->":
        param = match[4..^4]  # Strip <!-- and -->
      else:
        continue
      
      if param notin result.found:
        result.found.add(param)
      if syntaxUsed.len == 0:
        syntaxUsed = syntax
      elif syntaxUsed != syntax:
        result.warnings.add("Warning: Multiple placeholder syntaxes detected (" & syntaxUsed & " and " & syntax & ")")
  
  # Check for unsafe single-brace syntax {param} (but not part of double-brace)
  var unsafeBraces: seq[string] = @[]
  # Match {word} but not when preceded or followed by another brace
  let singleBracePattern = re"(?<!{){(\w+)}(?!})"
  for match in content.findAll(singleBracePattern):
    let param = match[1..^2]  # Strip { and }
    if param notin unsafeBraces:
      unsafeBraces.add(param)
  
  if unsafeBraces.len > 0:
    result.warnings.add("Warning: Found unsafe single-brace placeholders {" & unsafeBraces.join(", ") & "}")
    result.warnings.add("  Recommendation: Use {{PARAM}} or @PARAM@ syntax instead")
  
  # Validate declared vs found
  if result.declared.len > 0:
    # Check for undeclared parameters
    for param in result.found:
      if param notin result.declared:
        result.warnings.add("Warning: Parameter '" & param & "' used but not declared in SUGAR_PARAMS")
    
    # Check for unused declarations
    for param in result.declared:
      if param notin result.found:
        result.warnings.add("Warning: Parameter '" & param & "' declared but never used")
  elif result.found.len > 0:
    result.warnings.add("Recommendation: Add <!-- SUGAR_PARAMS: " & result.found.join(", ") & " --> to explicitly declare parameters")


when isMainModule:
  import std/parseopt
  
  proc printUsage() =
    echo """
Magic - Compress and decompress tstorie code snippets

Usage:
  tstorie magic pack <input.md>                  Compress markdown to base64
  tstorie magic pack <input.md> -o <output.txt>  Save compressed output to file
  tstorie magic unpack <compressed-string>       Decompress to markdown
  tstorie magic unpack <input.txt> -o <output.md>  Decompress file to file
  tstorie magic validate <preset.md>             Check preset for parameter safety
  tstorie magic help                              Show this help

Examples:
  # Compress a particle system preset
  tstorie magic pack presets/particles-bugs.md
  
  # Validate parameter usage
  tstorie magic validate presets/particles-bugs.md
  
  # Save compressed output to file
  tstorie sugar pack presets/particles-bugs.md -o bugs.sugar
  
  # Decompress and view
  tstorie sugar unpack "eJyNVE1v2zAM..."
  
  # Decompress file to file
  tstorie sugar unpack bugs.sugar -o output.md
"""
  
  var command = ""
  var inputFile = ""
  var outputFile = ""
  
  # Simple argument parsing
  if paramCount() == 0:
    printUsage()
    quit(0)
  
  command = paramStr(1).toLowerAscii()
  
  if command == "help" or command == "-h" or command == "--help":
    printUsage()
    quit(0)
  
  if command notin ["pack", "unpack", "validate"]:
    echo "Error: Unknown command '" & command & "'"
    echo "Use 'tstorie magic help' for usage information"
    quit(1)
  
  if paramCount() < 2:
    echo "Error: Missing input parameter"
    printUsage()
    quit(1)
  
  inputFile = paramStr(2)
  
  # Check for -o output flag
  var i = 3
  while i <= paramCount():
    let arg = paramStr(i)
    if arg == "-o" and i + 1 <= paramCount():
      outputFile = paramStr(i + 1)
      inc i, 2
    else:
      inc i
  
  try:
    case command
    of "validate":
      let (ok, warnings, declared, found) = validatePreset(inputFile)
      
      echo "\n📋 Validating preset: " & inputFile
      echo "─" .repeat(50)
      
      if declared.len > 0:
        echo "\n✓ Declared parameters: " & declared.join(", ")
      
      if found.len > 0:
        echo "✓ Found placeholders: " & found.join(", ")
      
      if warnings.len > 0:
        echo "\n⚠️  Issues found:"
        for w in warnings:
          echo "  " & w
      else:
        echo "\n✓ No issues found!"
        
      if not ok:
        quit(1)
    
    of "pack":
      let compressed = packMarkdown(inputFile)
      
      if outputFile.len > 0:
        writeFile(outputFile, compressed)
        echo "✓ Compressed and saved to: " & outputFile
        echo "  Original size: " & $readFile(inputFile).len & " bytes"
        echo "  Compressed size: " & $compressed.len & " bytes"
        let ratio = (1.0 - (compressed.len.float / readFile(inputFile).len.float)) * 100.0
        echo "  Compression ratio: " & formatFloat(ratio, ffDecimal, 1) & "%"
      else:
        echo compressed
    
    of "unpack":
      var compressed: string
      
      # Check if input is a file or raw string
      if fileExists(inputFile):
        compressed = readFile(inputFile).strip()
      else:
        # It's a raw compressed string
        compressed = inputFile.strip()
      
      let decompressed = unpackToMarkdown(compressed)
      
      if outputFile.len > 0:
        writeFile(outputFile, decompressed)
        echo "✓ Decompressed and saved to: " & outputFile
        echo "  Decompressed size: " & $decompressed.len & " bytes"
      else:
        echo decompressed
    
    else:
      discard
  
  except Exception as e:
    echo "Error: " & e.msg
    quit(1)
