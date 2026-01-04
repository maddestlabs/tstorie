#!/usr/bin/env nim
## Debug tool for tstorie markdown scripts
## 
## This tool helps troubleshoot nimini scripts embedded in markdown:
## 1. Extracts code blocks with line number mapping
## 2. Validates syntax
## 3. Provides clear error messages with both script and markdown line numbers
##
## Usage:
##   nim r debug_script.nim <markdown_file.md> [block_type]
##   
##   Examples:
##     nim r debug_script.nim docs/demos/tui2.md
##     nim r debug_script.nim docs/demos/tui2.md render
##     nim r debug_script.nim docs/demos/tui2.md --validate

import strutils, os, tables
import lib/storie_md
import nimini

type
  CodeBlockInfo = object
    blockType: string  ## "init", "render", "input"
    code: string
    startLine: int     ## Line in markdown where code block starts
    endLine: int       ## Line in markdown where code block ends
    lineMap: seq[int]  ## Maps script line number to markdown line number

proc extractCodeBlocks(mdFile: string): seq[CodeBlockInfo] =
  ## Extract all code blocks from markdown file with line mapping
  result = @[]
  
  let content = readFile(mdFile)
  let lines = content.split('\n')
  
  var i = 0
  while i < lines.len:
    let line = lines[i].strip()
    
    # Look for code block start: ```nim on:init, on:render, on:input
    if line.startsWith("```nim on:"):
      let blockType = line[10..^1].strip()
      var codeLines: seq[string] = @[]
      var lineMap: seq[int] = @[]
      let startLine = i + 1
      
      inc i
      # Collect code until closing ```
      while i < lines.len:
        if lines[i].strip().startsWith("```"):
          break
        codeLines.add(lines[i])
        lineMap.add(i + 1)  # +1 for 1-based line numbers
        inc i
      
      result.add(CodeBlockInfo(
        blockType: blockType,
        code: codeLines.join("\n"),
        startLine: startLine,
        endLine: i,
        lineMap: lineMap
      ))
    
    inc i

proc formatLineMapping(blockInfo: CodeBlockInfo): string =
  ## Create a visual line mapping for debugging
  result = "Code Block: on:" & blockInfo.blockType & "\n"
  result.add("Markdown lines: " & $blockInfo.startLine & " - " & $blockInfo.endLine & "\n")
  result.add("\nLine Mapping:\n")
  result.add("Script Line | MD Line | Code\n")
  result.add("------------|---------|" & "-".repeat(50) & "\n")
  
  let codeLines = blockInfo.code.split('\n')
  for i, codeLine in codeLines:
    let scriptLine = i + 1
    let mdLine = if i < blockInfo.lineMap.len: blockInfo.lineMap[i] else: 0
    let preview = if codeLine.len > 50: codeLine[0..49] & "..." else: codeLine
    result.add(align($scriptLine, 11) & " | " & align($mdLine, 7) & " | " & preview & "\n")

proc validateCodeBlock(blockInfo: CodeBlockInfo): tuple[success: bool, error: string, scriptLine: int] =
  ## Validate a code block and return error info if any
  try:
    # Tokenize and parse
    let tokens = tokenizeDsl(blockInfo.code)
    let program = parseDsl(tokens)
    return (true, "", 0)
  except NiminiError as e:
    # Extract line number from error
    let scriptLine = e.line
    let mdLine = if scriptLine > 0 and scriptLine <= blockInfo.lineMap.len:
      blockInfo.lineMap[scriptLine - 1]
    else:
      0
    
    let errorMsg = e.msg & "\n" &
                   "  Script line: " & $scriptLine & "\n" &
                   "  Markdown line: " & $mdLine
    return (false, errorMsg, scriptLine)
  except Exception as e:
    return (false, e.msg, 0)

proc showCodeContext(blockInfo: CodeBlockInfo, errorLine: int, contextLines: int = 3) =
  ## Show code around the error with line numbers
  let codeLines = blockInfo.code.split('\n')
  
  echo "\nCode Context (around error):"
  echo "Script Line | MD Line | Code"
  echo "------------|---------|" & "-".repeat(60)
  
  let startIdx = max(0, errorLine - contextLines - 1)
  let endIdx = min(codeLines.len - 1, errorLine + contextLines - 1)
  
  for i in startIdx..endIdx:
    let scriptLine = i + 1
    let mdLine = if i < blockInfo.lineMap.len: blockInfo.lineMap[i] else: 0
    let marker = if scriptLine == errorLine: " >>> " else: "     "
    
    echo marker & align($scriptLine, 6) & " | " & align($mdLine, 7) & " | " & codeLines[i]

proc main() =
  if paramCount() < 1:
    echo "Usage: nim r debug_script.nim <markdown_file.md> [block_type|--validate]"
    echo ""
    echo "Options:"
    echo "  <markdown_file.md>  Path to the markdown file to debug"
    echo "  [block_type]        Optional: 'init', 'render', or 'input' to show specific block"
    echo "  --validate          Validate all code blocks"
    echo "  --lines             Show line mappings for all blocks"
    echo ""
    echo "Examples:"
    echo "  nim r debug_script.nim docs/demos/tui2.md"
    echo "  nim r debug_script.nim docs/demos/tui2.md render"
    echo "  nim r debug_script.nim docs/demos/tui2.md --validate"
    quit(1)
  
  let mdFile = paramStr(1)
  
  if not fileExists(mdFile):
    echo "Error: File not found: ", mdFile
    quit(1)
  
  echo "Analyzing: ", mdFile
  echo ""
  
  let blocks = extractCodeBlocks(mdFile)
  
  if blocks.len == 0:
    echo "No code blocks found in file."
    quit(0)
  
  echo "Found ", blocks.len, " code block(s):"
  for blk in blocks:
    echo "  - on:", blk.blockType, " (", blk.code.split('\n').len, " lines, MD lines ", blk.startLine, "-", blk.endLine, ")"
  echo ""
  
  # Handle different modes
  if paramCount() >= 2:
    let option = paramStr(2)
    
    if option == "--validate":
      echo "=== VALIDATING ALL BLOCKS ==="
      echo ""
      var hasErrors = false
      
      for blk in blocks:
        echo "Validating on:", blk.blockType, "..."
        let (success, error, errorLine) = validateCodeBlock(blk)
        
        if success:
          echo "  ✓ OK"
        else:
          echo "  ✗ ERROR"
          echo ""
          echo error
          echo ""
          showCodeContext(blk, errorLine)
          echo ""
          hasErrors = true
      
      if hasErrors:
        quit(1)
      else:
        echo "All blocks validated successfully!"
        quit(0)
    
    elif option == "--lines":
      echo "=== LINE MAPPINGS ==="
      echo ""
      for blk in blocks:
        echo formatLineMapping(blk)
        echo ""
      quit(0)
    
    else:
      # Show specific block
      let blockType = option
      var found = false
      
      for blk in blocks:
        if blk.blockType == blockType:
          found = true
          echo "=== CODE BLOCK: on:", blockType, " ==="
          echo ""
          echo formatLineMapping(blk)
          echo ""
          echo "Full Code:"
          echo "-".repeat(70)
          echo blk.code
          echo "-".repeat(70)
          echo ""
          
          # Validate it
          echo "Validating..."
          let (success, error, errorLine) = validateCodeBlock(blk)
          
          if success:
            echo "✓ Syntax is valid!"
          else:
            echo "✗ Syntax error:"
            echo error
            echo ""
            showCodeContext(blk, errorLine)
      
      if not found:
        echo "Block type '", blockType, "' not found."
        var blockNames: seq[string] = @[]
        for blk in blocks:
          blockNames.add("on:" & blk.blockType)
        echo "Available blocks: ", blockNames.join(", ")
        quit(1)
  
  else:
    # Default: validate all and show summary
    echo "=== QUICK VALIDATION ==="
    echo ""
    
    var hasErrors = false
    for blk in blocks:
      let (success, error, errorLine) = validateCodeBlock(blk)
      
      if success:
        echo "✓ on:", blk.blockType, " - OK"
      else:
        echo "✗ on:", blk.blockType, " - ERROR at script line ", errorLine, " (MD line ", 
             (if errorLine > 0 and errorLine <= blk.lineMap.len: $blk.lineMap[errorLine-1] else: "?"), ")"
        hasErrors = true
    
    if hasErrors:
      echo ""
      echo "Run with --validate to see detailed errors"
      quit(1)
    else:
      echo ""
      echo "All blocks are valid!"
      quit(0)

when isMainModule:
  main()
