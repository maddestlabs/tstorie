#!/usr/bin/env nim
## Runtime validation tool for tstorie scripts
## 
## This tool actually executes code blocks to catch runtime errors
## that syntax validation alone can't catch (undefined variables, missing functions, etc.)
##
## Usage:
##   nim r debugger_runtime.nim <markdown_file.md> [block_type]

import strutils, os, tables
import lib/storie_md
import lib/storie_types
import lib/nimini_bridge
import nimini
import src/types
import src/appstate

proc extractCodeBlocks(mdFile: string): tuple[doc: MarkdownDocument, blocks: seq[tuple[blockType: string, code: string, startLine: int]]] =
  ## Parse markdown and extract code blocks with their types
  let content = readFile(mdFile)
  let doc = parseMarkdown(content)
  
  var blocks: seq[tuple[blockType: string, code: string, startLine: int]] = @[]
  
  # Track line numbers while parsing
  let lines = content.split('\n')
  var lineNum = 0
  
  for line in lines:
    inc lineNum
    let stripped = line.strip()
    if stripped.startsWith("```nim on:"):
      let blockType = stripped[10..^1].strip()
      var codeLines: seq[string] = @[]
      let startLine = lineNum
      
      # Collect code
      while lineNum < lines.len:
        inc lineNum
        if lines[lineNum - 1].strip().startsWith("```"):
          break
        codeLines.add(lines[lineNum - 1])
      
      blocks.add((blockType, codeLines.join("\n"), startLine))
  
  return (doc, blocks)

proc testExecuteBlock(doc: MarkdownDocument, blockType: string, code: string, env: ref Env): tuple[success: bool, error: string] =
  ## Try to execute a code block and catch runtime errors
  try:
    # Compile
    let tokens = tokenizeDsl(code)
    let program = parseDsl(tokens)
    
    # Create mock state variables
    var scriptCode = ""
    scriptCode.add("var termWidth = 80\n")
    scriptCode.add("var termHeight = 24\n")
    scriptCode.add("var fps = 60.0\n")
    scriptCode.add("var frameCount = 0\n")
    scriptCode.add("var deltaTime = 0.016\n")
    
    if blockType == "input":
      # Add mock event for input blocks
      scriptCode.add("# Mock event for validation\n")
    
    scriptCode.add("\n")
    scriptCode.add(code)
    
    let fullTokens = tokenizeDsl(scriptCode)
    let fullProgram = parseDsl(fullTokens)
    
    # Try to execute
    execProgram(fullProgram, env)
    
    return (true, "")
    
  except NiminiError as e:
    return (false, "Runtime Error: " & e.msg)
  except Exception as e:
    return (false, "Runtime Error: " & e.msg)

proc main() =
  if paramCount() < 1:
    echo "Usage: nim r debugger_runtime.nim <markdown_file.md> [block_type]"
    echo ""
    echo "This tool validates code blocks by actually executing them"
    echo "to catch runtime errors like undefined variables/functions."
    echo ""
    echo "Examples:"
    echo "  nim r debugger_runtime.nim docs/demos/tui2.md"
    echo "  nim r debugger_runtime.nim docs/demos/tui2.md render"
    quit(1)
  
  let mdFile = paramStr(1)
  
  if not fileExists(mdFile):
    echo "Error: File not found: ", mdFile
    quit(1)
  
  echo "Runtime Validation: ", mdFile
  echo ""
  
  # Parse document
  let (doc, blocks) = extractCodeBlocks(mdFile)
  
  if blocks.len == 0:
    echo "No code blocks found."
    quit(0)
  
  echo "Found ", blocks.len, " code block(s)"
  echo ""
  
  # Create nimini environment with tstorie API
  var env = newEnv()
  registerTStorieAPI(env, nil)  # Register all tstorie functions
  
  # Filter blocks if specific type requested
  var blocksToTest = blocks
  if paramCount() >= 2:
    let filterType = paramStr(2)
    blocksToTest = @[]
    for blk in blocks:
      if blk.blockType == filterType:
        blocksToTest.add(blk)
    
    if blocksToTest.len == 0:
      echo "No blocks of type '", filterType, "' found."
      quit(1)
  
  # Test execution
  var hasErrors = false
  var initEnv = newEnv()
  registerTStorieAPI(initEnv, nil)
  
  for blk in blocksToTest:
    echo "Testing on:", blk.blockType, "..."
    
    # Init blocks should run first and share state
    let testEnv = if blk.blockType == "init":
      initEnv
    else:
      newEnv(initEnv)  # Child scope with init variables
    
    # Re-register API for each block
    if blk.blockType != "init":
      registerTStorieAPI(testEnv, nil)
    
    let (success, error) = testExecuteBlock(doc, blk.blockType, blk.code, testEnv)
    
    if success:
      echo "  ✓ Executed successfully"
    else:
      echo "  ✗ Runtime Error"
      echo ""
      echo "  ", error
      echo ""
      
      # Try to extract what's missing
      if "Undefined variable" in error:
        let parts = error.split('\'')
        if parts.len >= 2:
          let varName = parts[1]
          echo "  Hint: Variable '", varName, "' is not defined."
          echo "        - Check if it's defined in on:init"
          echo "        - Check spelling and case"
          echo "        - Verify it's in scope"
      elif "not callable" in error:
        echo "  Hint: This might be an undefined function."
        echo "        - Check if the function is registered in nimini_bridge.nim"
        echo "        - Verify the function name spelling"
      
      echo ""
      hasErrors = true
  
  if hasErrors:
    echo "Runtime validation found errors!"
    quit(1)
  else:
    echo "All blocks executed successfully!"
    quit(0)

when isMainModule:
  main()
