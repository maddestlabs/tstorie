## Storie Markdown Parser
##
## Platform-agnostic markdown parser for extracting Nim code blocks with lifecycle hooks.
## This module has no file I/O or platform-specific dependencies - it only processes string content.

import strutils, tables

type
  CodeBlock* = object
    code*: string
    lifecycle*: string  ## Lifecycle hook: "render", "update", "init", "input", "shutdown"
    language*: string
  
  FrontMatter* = Table[string, string]
  
  MarkdownDocument* = object
    frontMatter*: FrontMatter
    codeBlocks*: seq[CodeBlock]

proc parseFrontMatter*(content: string): FrontMatter =
  ## Parse YAML-style front matter from the beginning of markdown content.
  ## Front matter is enclosed between --- delimiters at the start of the file.
  ## Returns a table of key-value pairs.
  result = initTable[string, string]()
  
  let lines = content.splitLines()
  if lines.len < 3:
    return
  
  # Check if document starts with front matter delimiter
  if not lines[0].strip().startsWith("---"):
    return
  
  # Parse key-value pairs until closing delimiter
  var i = 1
  while i < lines.len:
    let line = lines[i].strip()
    
    # Check for closing delimiter
    if line.startsWith("---"):
      break
    
    # Skip empty lines and comments
    if line.len == 0 or line.startsWith("#"):
      inc i
      continue
    
    # Parse key: value format
    let colonPos = line.find(':')
    if colonPos > 0:
      let key = line[0..<colonPos].strip()
      let value = line[colonPos+1..^1].strip()
      result[key] = value
    
    inc i

proc parseMarkdownDocument*(content: string): MarkdownDocument =
  ## Parse a complete Markdown document including front matter and code blocks.
  ## Front matter is optional YAML-style metadata at the start of the document.
  ## 
  ## Example:
  ##   ---
  ##   targetFPS: 30
  ##   title: My App
  ##   ---
  ##   
  ##   ```nim on:render
  ##   bgWriteText(0, 0, "Hello")
  ##   ```
  result.frontMatter = parseFrontMatter(content)
  result.codeBlocks = @[]
  
  var lines = content.splitLines()
  var i = 0
  
  # Skip front matter section if present
  if lines.len > 0 and lines[0].strip().startsWith("---"):
    inc i
    while i < lines.len:
      if lines[i].strip().startsWith("---"):
        inc i
        break
      inc i
  
  # Parse code blocks
  while i < lines.len:
    let line = lines[i].strip()
    
    # Look for code block start: ```nim or ``` nim
    if line.startsWith("```") or line.startsWith("``` "):
      var headerParts = line[3..^1].strip().split()
      if headerParts.len > 0 and headerParts[0] == "nim":
        var lifecycle = ""
        var language = "nim"
        
        # Check for on:* attribute (e.g., on:render, on:update)
        for part in headerParts:
          if part.startsWith("on:"):
            lifecycle = part[3..^1]
            break
        
        # Extract code block content
        var codeLines: seq[string] = @[]
        inc i
        while i < lines.len:
          if lines[i].strip().startsWith("```"):
            break
          codeLines.add(lines[i])
          inc i
        
        # Add the code block
        let codeBlock = CodeBlock(
          code: codeLines.join("\n"),
          lifecycle: lifecycle,
          language: language
        )
        result.codeBlocks.add(codeBlock)
    
    inc i

proc parseMarkdown*(content: string): seq[CodeBlock] =
  ## Parse Markdown content and extract Nim code blocks with lifecycle hooks.
  ## 
  ## Code blocks are identified by ```nim markers, and can have optional lifecycle
  ## annotations like: ```nim on:render or ```nim on:update
  ## 
  ## This function is platform-agnostic - it only processes the string content.
  ## The caller is responsible for loading the content from files, network, etc.
  ## 
  ## For front matter support, use parseMarkdownDocument instead.
  let doc = parseMarkdownDocument(content)
  return doc.codeBlocks
