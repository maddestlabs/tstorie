#!/usr/bin/env nim
## Binding Metadata Generator
##
## Automatically generates:
## 1. Metadata registrations for tstorie_export_metadata.nim
## 2. Export wrapper functions for nim_export.nim
## 3. Optionally integrates them directly into source files
##
## Usage:
##   nim r tools/generate_binding_metadata.nim lib/particles_bindings.nim
##   nim r tools/generate_binding_metadata.nim --integrate lib/particles_bindings.nim
##
## This tool detects nimini binding patterns and generates the corresponding
## metadata and wrappers needed for the export system.

import std/[strutils, sequtils, parseopt, os, re, tables, algorithm]

type
  ParamInfo = object
    name: string
    paramType: string  # "string", "int", "float", "bool"
    optional: bool
    defaultValue: string

  FunctionInfo = object
    name: string
    docComment: string
    params: seq[ParamInfo]
    returnType: string  # "nil", "int", "bool", etc.
    registryAccess: string  # e.g., "gParticleSystems"
    module: string  # e.g., "particles"

proc extractDocComment(lines: seq[string], startIdx: int): string =
  ## Extract doc comment lines before the function
  var docLines: seq[string] = @[]
  var i = startIdx - 1
  while i >= 0 and lines[i].strip().startsWith("##"):
    let line = lines[i].strip()[2..^1].strip()
    if line.len > 0:
      docLines.add(line)
    dec i
  
  # Reverse to get correct order
  docLines.reverse()
  result = docLines.join(" ")

proc parseArgSpec(docComment: string): seq[ParamInfo] =
  ## Parse "Args: name (type), param (type, optional, default=value)" from doc
  result = @[]
  
  # Find the Args: line
  let argsMatch = docComment.find(re"Args:\s*(.+?)(?:Returns:|$)")
  if argsMatch == -1:
    return
  
  let argsText = docComment[argsMatch..^1]
  let colonIdx = argsText.find(":")
  if colonIdx == -1:
    return
  
  var argsLine = argsText[colonIdx + 1..^1]
  
  # Stop at "Returns:" if present
  let returnsIdx = argsLine.find("Returns:")
  if returnsIdx != -1:
    argsLine = argsLine[0..<returnsIdx]
  
  # Split by comma (but need to handle nested parens)
  var current = ""
  var parenDepth = 0
  
  for ch in argsLine:
    if ch == '(':
      inc parenDepth
    elif ch == ')':
      dec parenDepth
    elif ch == ',' and parenDepth == 0:
      if current.strip().len > 0:
        # Parse this parameter
        let parts = current.strip().split("(", maxsplit=1)
        if parts.len == 2:
          let paramName = parts[0].strip()
          let rest = parts[1].strip().strip(chars={')'})
          
          # Parse type and optional/default info
          var paramType = ""
          var optional = false
          var defaultVal = ""
          
          let typeParts = rest.split(",")
          if typeParts.len > 0:
            paramType = typeParts[0].strip()
          
          for part in typeParts[1..^1]:
            let p = part.strip()
            if p == "optional":
              optional = true
            elif p.startsWith("default="):
              optional = true
              defaultVal = p[8..^1].strip()
          
          result.add(ParamInfo(
            name: paramName,
            paramType: paramType,
            optional: optional,
            defaultValue: defaultVal
          ))
      current = ""
    else:
      current.add(ch)
  
  # Handle last parameter
  if current.strip().len > 0:
    let parts = current.strip().split("(", maxsplit=1)
    if parts.len == 2:
      let paramName = parts[0].strip()
      let rest = parts[1].strip().strip(chars={')'})
      
      var paramType = ""
      var optional = false
      var defaultVal = ""
      
      let typeParts = rest.split(",")
      if typeParts.len > 0:
        paramType = typeParts[0].strip()
      
      for part in typeParts[1..^1]:
        let p = part.strip()
        if p == "optional":
          optional = true
        elif p.startsWith("default="):
          optional = true
          defaultVal = p[8..^1].strip()
      
      result.add(ParamInfo(
        name: paramName,
        paramType: paramType,
        optional: optional,
        defaultValue: defaultVal
      ))

proc detectReturnType(procBody: string): string =
  ## Detect return type from return statements
  if "return valNil()" in procBody or "valNil()" in procBody:
    return "nil"
  elif "return valInt(" in procBody or "valInt(" in procBody:
    return "int"
  elif "return valBool(" in procBody or "valBool(" in procBody:
    return "bool"
  elif "return valFloat(" in procBody or "valFloat(" in procBody:
    return "float"
  elif "return valString(" in procBody or "valString(" in procBody:
    return "string"
  else:
    return "nil"

proc detectRegistryAccess(procBody: string): string =
  ## Detect the global registry variable name (e.g., gParticleSystems)
  let match = procBody.find(re"(g[A-Z][a-zA-Z]+)\[")
  if match != -1:
    let endIdx = procBody.find("[", match)
    if endIdx != -1:
      return procBody[match..<endIdx]
  return ""

proc extractFieldAssignments(procBody: string): seq[(string, string)] =
  ## Extract field assignments like: ps.gravity = args[1].f
  ## Returns: @[("gravity", "float"), ("windForce", "tuple"), ...]
  result = @[]
  
  for line in procBody.splitLines():
    # Look for .field = pattern
    if "." in line and "=" in line:
      let parts = line.split('=')
      if parts.len >= 2:
        let leftSide = parts[0].strip()
        let rightSide = parts[1].strip()
        
        if "." in leftSide:
          let fieldParts = leftSide.split('.')
          if fieldParts.len >= 2:
            let fieldName = fieldParts[^1].strip()
            
            # Infer type from args access
            var fieldType = ""
            if ".f" in rightSide or "float(" in rightSide:
              fieldType = "float"
            elif ".i" in rightSide or "int(" in rightSide:
              fieldType = "int"
            elif ".b" in rightSide or "bool(" in rightSide:
              fieldType = "bool"
            elif ".s" in rightSide:
              fieldType = "string"
            elif "(" in rightSide and "," in rightSide:
              fieldType = "tuple"
            
            if fieldType.len > 0:
              result.add((fieldName, fieldType))

proc extractMethodCalls(procBody: string): seq[(string, seq[string])] =
  ## Extract method calls like: ps.emit(count) or ps.update(dt)
  ## Returns: @[("emit", @["int"]), ("update", @["float"]), ...]
  result = @[]
  
  for line in procBody.splitLines():
    if "." in line and "(" in line:
      # Try to match pattern: something.methodName(args)
      if line.contains(re"\.(\w+)\("):
        # Simple extraction - could be improved
        discard

proc parseBindingFile(filePath: string): seq[FunctionInfo] =
  ## Parse a *_bindings.nim file and extract function information
  result = @[]
  
  let content = readFile(filePath)
  let lines = content.splitLines()
  
  # Detect module name from imports (e.g., "import particles" -> "particles")
  var moduleName = ""
  for line in lines:
    if line.strip().startsWith("import ") and not line.contains("std/") and 
       not line.contains("../"):
      let parts = line.strip().split()
      if parts.len >= 2:
        moduleName = parts[1]
        break
  
  var i = 0
  while i < lines.len:
    let line = lines[i].strip()
    
    # Look for proc definitions with {.nimini.} pragma
    if line.startsWith("proc ") and "{.nimini.}" in line:
      # Extract function name
      let procMatch = line.find(re"proc\s+([a-zA-Z0-9_]+)\*")
      if procMatch == -1:
        inc i
        continue
      
      let nameStart = procMatch + 5  # "proc "
      var nameEnd = nameStart
      while nameEnd < line.len and line[nameEnd] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
        inc nameEnd
      
      let funcName = line[nameStart..<nameEnd]
      
      # Extract doc comment
      let docComment = extractDocComment(lines, i)
      
      # Extract procedure body to analyze
      var procBody = ""
      var j = i
      var braceDepth = 0
      var started = false
      
      while j < lines.len:
        let bodyLine = lines[j]
        for ch in bodyLine:
          if ch == '=':
            started = true
          if started:
            procBody.add(ch)
            if ch == '(':
              inc braceDepth
            elif ch == ')':
              dec braceDepth
        
        if started and braceDepth == 0 and procBody.contains("return"):
          break
        inc j
      
      # Parse parameters from doc comment
      let params = parseArgSpec(docComment)
      let returnType = detectReturnType(procBody)
      let registryVar = detectRegistryAccess(procBody)
      
      result.add(FunctionInfo(
        name: funcName,
        docComment: docComment,
        params: params,
        returnType: returnType,
        registryAccess: registryVar,
        module: moduleName
      ))
    
    inc i

proc generateMetadataRegistration(functions: seq[FunctionInfo]): string =
  ## Generate metadata registration code for tstorie_export_metadata.nim
  result = "  # " & (if functions.len > 0: functions[0].module else: "Module") & " functions\n"
  
  for fn in functions:
    let desc = if fn.docComment.len > 0:
      fn.docComment.split("Args:")[0].strip()
    else:
      fn.name
    
    result &= "  gFunctionMetadata[\"" & fn.name & "\"] = FunctionMetadata(\n"
    if fn.module.len > 0:
      result &= "    storieLibs: @[\"" & fn.module & "\"],\n"
    result &= "    description: \"" & desc & "\")\n"
    result &= "\n"

proc generateExportWrapper(fn: FunctionInfo, registryVar: string, moduleName: string): string =
  ## Generate export wrapper function for nim_export.nim
  result = "    result &= \"proc " & fn.name & "("
  
  # Generate parameter list
  var paramList: seq[string] = @[]
  for param in fn.params:
    var pType = param.paramType
    # Map nimini types to Nim types
    if pType == "string": pType = "string"
    elif pType == "int": pType = "int"  
    elif pType == "float": pType = "float"
    elif pType == "bool": pType = "bool"
    
    if param.optional and param.defaultValue.len > 0:
      paramList.add(param.name & ": " & pType & " = " & param.defaultValue)
    else:
      paramList.add(param.name & ": " & pType)
  
  result &= paramList.join(", ")
  
  # Return type
  if fn.returnType != "nil":
    result &= "): " & fn.returnType & " =\\n\"\n"
  else:
    result &= ") =\\n\"\n"
  
  # Generate function body
  let registryName = registryVar.replace("g", "").replace("Systems", "System").replace("s", "")
  result &= "    result &= \"  if " & registryVar & ".hasKey(" & fn.params[0].name & "):\\n\"\n"
  
  # Generate the implementation based on function type
  if fn.name.contains("Set"):
    # Setter function - assign to fields
    result &= "    result &= \"    let ps = " & registryVar & "[" & fn.params[0].name & "]\\n\"\n"
    
    # Generate field assignments based on parameters
    if fn.params.len >= 2:
      for i in 1..<fn.params.len:
        let param = fn.params[i]
        let fieldName = fn.name.replace("particleSet", "").replace("Set", "")
        let lowerField = fieldName[0].toLowerAscii() & fieldName[1..^1]
        
        if param.paramType == "string" and lowerField.contains("Char"):
          # Special case: string to seq[string] conversion
          result &= "    result &= \"    var charSeq: seq[string] = @[]\\n\"\n"
          result &= "    result &= \"    for ch in " & param.name & ": charSeq.add($ch)\\n\"\n"
          result &= "    result &= \"    ps." & lowerField & " = charSeq\\n\"\n"
        elif fn.params.len == 3 and (param.paramType == "float" or param.paramType == "int"):
          # Tuple assignment (x, y)
          if i == 1:
            result &= "    result &= \"    ps." & lowerField & " = (" & fn.params[1].name & ", " & fn.params[2].name & ")\\n\"\n"
        elif fn.params.len > 3 and param.paramType in ["int", "float"]:
          # Multiple params - check if it's min/max pattern
          if i == 1 and fn.params.len >= 3:
            let fieldMin = lowerField & "Min"
            let fieldMax = lowerField & "Max"
            if fn.params.len == 3:
              result &= "    result &= \"    ps." & fieldMin & " = " & fn.params[1].name & "\\n\"\n"
              result &= "    result &= \"    ps." & fieldMax & " = " & fn.params[2].name & "\\n\"\n"
        else:
          # Simple field assignment
          result &= "    result &= \"    ps." & lowerField & " = " & param.name & "\\n\"\n"
  elif fn.name == "particleInit":
    result &= "    result &= \"    " & registryVar & "[" & fn.params[0].name & "] = initParticleSystem(" & fn.params[1].name & ")\\n\"\n"
  elif fn.name == "particleEmit":
    result &= "    result &= \"    " & registryVar & "[" & fn.params[0].name & "].emit(" & fn.params[1].name & ")\\n\"\n"
  elif fn.name == "particleUpdate":
    result &= "    result &= \"    " & registryVar & "[" & fn.params[0].name & "].update(" & fn.params[1].name & ", gState.termWidth, gState.termHeight)\\n\"\n"
  elif fn.name == "particleRender":
    result &= "    result &= \"    let targetLayer = if " & fn.params[1].name & " == 0: gDefaultLayer else: gState.layers[" & fn.params[1].name & "]\\n\"\n"
    result &= "    result &= \"    if not targetLayer.isNil:\\n\"\n"
    result &= "    result &= \"      " & registryVar & "[" & fn.params[0].name & "].render(targetLayer.buffer)\\n\"\n"
  elif fn.name == "particleCheckHit":
    result &= "    result &= \"    result = " & registryVar & "[" & fn.params[0].name & "].checkHit(" & fn.params[1].name & ", " & fn.params[2].name & ")\\n\"\n"
  else:
    # Generic method call
    result &= "    result &= \"    " & registryVar & "[" & fn.params[0].name & "]." & fn.name.replace("particle", "") & "("  
    if fn.params.len > 1:
      let args = fn.params[1..^1].mapIt(it.name).join(", ")
      result &= args
    result &= ")\\n\"\n"
  
  # Handle return value
  if fn.returnType == "bool":
    result &= "    result &= \"  else:\\n\"\n"
    result &= "    result &= \"    return false\\n\"\n"
  
  result &= "    result &= \"\\n\"\n"
  
  # Add implementation based on the function
  result &= "    # TODO: Implement based on binding logic\n"
  result &= "    discard\n"

proc main() =
  var inputFile = ""
  var outputFormat = "metadata"  # or "wrappers" or "both"
  var integrate = false
  
  var p = initOptParser()
  for kind, key, val in p.getopt():
    case kind
    of cmdArgument:
      if inputFile.len == 0:
        inputFile = key
    of cmdLongOption, cmdShortOption:
      case key
      of "format", "f":
        outputFormat = val
      of "integrate", "i":
        integrate = true
      of "help", "h":
        echo "Usage: generate_binding_metadata [options] <binding_file.nim>"
        echo "Options:"
        echo "  -f, --format=TYPE    Output format: metadata, wrappers, both (default: metadata)"
        echo "  -i, --integrate      Automatically integrate into source files"
        echo "  -h, --help           Show this help"
        quit(0)
    of cmdEnd: break
  
  if inputFile.len == 0:
    echo "Error: No input file specified"
    echo "Usage: generate_binding_metadata <binding_file.nim>"
    quit(1)
  
  if not fileExists(inputFile):
    echo "Error: File not found: ", inputFile
    quit(1)
  
  echo "Parsing: ", inputFile
  let functions = parseBindingFile(inputFile)
  echo "Found ", functions.len, " functions"
  
  if functions.len == 0:
    echo "Warning: No functions found"
    quit(0)
  
  let moduleName = functions[0].module
  let registryVar = functions[0].registryAccess
  
  # Generate metadata
  let metadataCode = generateMetadataRegistration(functions)
  
  # Generate wrappers
  var wrappersCode = ""
  if outputFormat in ["wrappers", "both"]:
    wrappersCode = "  # " & moduleName & " system wrappers\n"
    wrappersCode &= "  if \"" & moduleName & "\" in ctx.imports.storieLibImports:\n"
    
    for fn in functions:
      wrappersCode &= generateExportWrapper(fn, registryVar, moduleName)
    
    wrappersCode &= "\n"
  
  if integrate:
    echo "\n=== INTEGRATING CODE ==="
    
    # 1. Add metadata to tstorie_export_metadata.nim
    let metadataFile = "lib/tstorie_export_metadata.nim"
    if fileExists(metadataFile):
      echo "Adding metadata to: ", metadataFile
      var content = readFile(metadataFile)
      
      # Find the end of registerTStorieExportMetadata function
      let marker = "proc registerTStorieExportMetadata*"
      if marker in content:
        # Find a good insertion point (before the end of the proc)
        # Look for the last gFunctionMetadata line
        let lines = content.splitLines()
        var insertIdx = -1
        
        for i in countdown(lines.high, 0):
          if "gFunctionMetadata[" in lines[i]:
            insertIdx = i + 1
            break
        
        if insertIdx > 0:
          # Insert the metadata
          var newLines = lines[0..<insertIdx]
          newLines.add("")
          newLines.add(metadataCode.strip().splitLines())
          newLines.add(lines[insertIdx..^1])
          
          writeFile(metadataFile, newLines.join("\n"))
          echo "  ✓ Metadata added successfully"
        else:
          echo "  ✗ Could not find insertion point in ", metadataFile
      else:
        echo "  ✗ Could not find registerTStorieExportMetadata in ", metadataFile
    else:
      echo "  ✗ File not found: ", metadataFile
    
    # 2. Add wrappers to nim_export.nim  
    if wrappersCode.len > 0:
      let exportFile = "lib/nim_export.nim"
      if fileExists(exportFile):
        echo "Adding wrappers to: ", exportFile
        var content = readFile(exportFile)
        
        # Find the particle wrapper section (or create it)
        let marker = "# Particle system wrappers"
        if marker in content:
          echo "  ! Particle wrappers already exist, skipping..."
        else:
          # Find where to insert (after str functions, before global variables)
          let insertMarker = "  # Global variables"
          if insertMarker in content:
            content = content.replace(insertMarker, "\n" & wrappersCode & insertMarker)
            writeFile(exportFile, content)
            echo "  ✓ Wrappers added successfully"
          else:
            echo "  ✗ Could not find insertion point in ", exportFile
      else:
        echo "  ✗ File not found: ", exportFile
    
    echo "\n=== INTEGRATION COMPLETE ==="
    echo "Run: nim c tstorie.nim"
    echo "Then: ./tstorie export docs/demos/depths.md"
  
  else:
    # Just output the code
    if outputFormat in ["metadata", "both"]:
      echo "\n# =========================================="
      echo "# METADATA REGISTRATION CODE"
      echo "# =========================================="
      echo "# Add this to lib/tstorie_export_metadata.nim"
      echo "# Inside registerTStorieExportMetadata() function:"
      echo metadataCode
    
    if outputFormat in ["wrappers", "both"]:
      echo "\n# =========================================="
      echo "# EXPORT WRAPPER CODE"
      echo "# =========================================="
      echo "# Add this to lib/nim_export.nim"
      echo "# In the generateNimProgram and generateTStorieIntegratedProgram functions:"
      echo wrappersCode

when isMainModule:
  main()
