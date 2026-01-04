#!/usr/bin/env nim
## Symbol checker for tstorie scripts
## 
## Checks if all called functions and referenced variables are available
## in the tstorie/nimini API or defined in on:init blocks
##
## Usage:
##   nim r check_symbols.nim <markdown_file.md>

import strutils, os, tables, sets
import nimini/tokenizer
import nimini/ast  # For token kind enums

type
  SymbolUsage = object
    name: string
    line: int
    context: string  # "function" or "variable"

proc extractCodeBlocks(mdFile: string): seq[tuple[blockType: string, code: string, startLine: int]] =
  ## Extract code blocks from markdown
  result = @[]
  
  let content = readFile(mdFile)
  let lines = content.split('\n')
  var lineNum = 0
  
  for line in lines:
    inc lineNum
    let stripped = line.strip()
    if stripped.startsWith("```nim on:"):
      let blockType = stripped[10..^1].strip()
      var codeLines: seq[string] = @[]
      let startLine = lineNum
      
      while lineNum < lines.len:
        inc lineNum
        if lines[lineNum - 1].strip().startsWith("```"):
          break
        codeLines.add(lines[lineNum - 1])
      
      result.add((blockType, codeLines.join("\n"), startLine))

proc extractFunctionCalls(code: string): HashSet[string] =
  ## Extract all function call names from code
  result = initHashSet[string]()
  
  try:
    let tokens = tokenizeDsl(code)
    
    var i = 0
    while i < tokens.len:
      let tok = tokens[i]
      
      # Look for identifier followed by (
      if tok.kind == tkIdent and i + 1 < tokens.len and tokens[i + 1].kind == tkLParen:
        result.incl(tok.lexeme)
      
      inc i
  except:
    discard  # Ignore tokenization errors

proc extractVariables(code: string): tuple[defined: HashSet[string], used: HashSet[string]] =
  ## Extract variable definitions and usages
  var defined = initHashSet[string]()
  var used = initHashSet[string]()
  
  try:
    let tokens = tokenizeDsl(code)
    
    var i = 0
    while i < tokens.len:
      let tok = tokens[i]
      
      # var/let/const definitions (keywords are identifiers in this tokenizer)
      if tok.kind == tkIdent and tok.lexeme in ["var", "let", "const"] and i + 1 < tokens.len:
        if tokens[i + 1].kind == tkIdent:
          defined.incl(tokens[i + 1].lexeme)
      
      # proc definitions
      elif tok.kind == tkIdent and tok.lexeme == "proc" and i + 1 < tokens.len:
        if tokens[i + 1].kind == tkIdent:
          defined.incl(tokens[i + 1].lexeme)
      
      # Identifier usage (rough heuristic)
      elif tok.kind == tkIdent:
        # Skip if it's a definition context or keyword
        if i > 0 and tokens[i - 1].kind == tkIdent and tokens[i - 1].lexeme in ["var", "let", "const", "proc"]:
          discard  # This is a definition
        elif tok.lexeme in ["var", "let", "const", "proc", "if", "elif", "else", "while", "for", "return", "and", "or", "not", "in", "is", "mod", "div"]:
          discard  # This is a keyword
        else:
          used.incl(tok.lexeme)
      
      inc i
  except:
    discard
  
  return (defined, used)

# Known tstorie/nimini API functions
const KNOWN_FUNCTIONS = [
  # Drawing
  "clear", "write", "writeText", "fillRect", "drawBox",
  "drawBoxSimple", "drawBoxDouble", "drawBoxRounded",  # Note: drawBoxSingle is NOT registered!
  "drawLabel", "drawButton", "drawTextBox", "drawSlider", 
  "drawCheckBox", "drawProgressBar",
  
  # Style
  "getStyle", "rgb", "defaultStyle",
  
  # Utility
  "str", "int", "float", "bool", "len", "add", "mod", "abs", "min", "max",
  "sin", "cos", "tan", "sqrt", "pow", "floor", "ceil", "round",
  
  # String
  "toLower", "toUpper", "strip", "split", "join", "contains", "startsWith",
  "endsWith", "replace", "find",
  
  # Array/Seq  
  "push", "pop", "insert", "delete",
  
  # Random
  "random", "randomInt", "randomFloat", "randomChoice", "shuffle",
  
  # Audio
  "playTone", "stopAudio", "setVolume",
  
  # Canvas
  "canvasInit", "canvasMoveTo", "canvasLineTo", "canvasClear",
  
  # Figlet
  "figlet", "figletHeight",
  
  # ASCII Art
  "loadImage", "renderImage",
  
  # Dungeon
  "generateDungeon", "getDungeonTile",
  
  # Procgen
  "noise2D", "noise3D", "fbm2D", "fbm3D",
  
  # Events (available in scripts)
  "event"
].toHashSet()

# Known variables injected by tstorie runtime
const KNOWN_VARIABLES = [
  "termWidth", "termHeight", "fps", "frameCount", "deltaTime",
  "event"  # Available in on:input
].toHashSet()

proc main() =
  if paramCount() < 1:
    echo "Usage: nim r check_symbols.nim <markdown_file.md>"
    echo ""
    echo "Checks for undefined functions and variables in tstorie scripts."
    quit(1)
  
  let mdFile = paramStr(1)
  
  if not fileExists(mdFile):
    echo "Error: File not found: ", mdFile
    quit(1)
  
  echo "Symbol Check: ", mdFile
  echo ""
  
  let blocks = extractCodeBlocks(mdFile)
  
  if blocks.len == 0:
    echo "No code blocks found."
    quit(0)
  
  # Track variables defined in on:init
  var initVariables = initHashSet[string]()
  
  # First pass: collect init variables
  for blk in blocks:
    if blk.blockType == "init":
      let (defined, _) = extractVariables(blk.code)
      for v in defined:
        initVariables.incl(v)
  
  echo "Found ", blocks.len, " code block(s)"
  echo "Found ", initVariables.len, " variables defined in on:init"
  echo ""
  
  var hasErrors = false
  
  for blk in blocks:
    echo "Checking on:", blk.blockType, "..."
    
    # Check function calls
    let funcCalls = extractFunctionCalls(blk.code)
    var undefinedFuncs: seq[string] = @[]
    
    for f in funcCalls:
      if f notin KNOWN_FUNCTIONS:
        # Check if it's defined in init as a proc
        if blk.blockType != "init" and f notin initVariables:
          undefinedFuncs.add(f)
    
    if undefinedFuncs.len > 0:
      hasErrors = true
      echo "  ✗ Undefined functions:"
      for f in undefinedFuncs:
        echo "    - ", f
        echo "      Hint: Check if this function is registered in lib/nimini_bridge.nim"
    
    # Check variables
    let (defined, used) = extractVariables(blk.code)
    var undefinedVars: seq[string] = @[]
    
    for v in used:
      # Skip if it's in known variables, defined in this block, or defined in init
      if v notin KNOWN_VARIABLES and v notin defined:
        if blk.blockType == "init" or v notin initVariables:
          # Additional check: might be a known function
          if v notin KNOWN_FUNCTIONS and v notin initVariables:
            undefinedVars.add(v)
    
    if undefinedVars.len > 0:
      hasErrors = true
      echo "  ✗ Possibly undefined variables:"
      for v in undefinedVars:
        echo "    - ", v
        echo "      Hint: Check if defined in on:init or check spelling"
    
    if undefinedFuncs.len == 0 and undefinedVars.len == 0:
      echo "  ✓ All symbols look good"
    
    echo ""
  
  if hasErrors:
    echo "Symbol check found issues!"
    echo ""
    echo "Note: This is a static check and may have false positives."
    echo "Variables from complex expressions or closures might be missed."
    quit(1)
  else:
    echo "All symbols appear to be defined!"
    quit(0)

when isMainModule:
  main()
