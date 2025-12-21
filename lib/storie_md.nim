## Storie Markdown Parser
##
## Platform-agnostic markdown parser for extracting Nim code blocks with lifecycle hooks.
## This module has no file I/O or platform-specific dependencies - it only processes string content.

import strutils, tables
import storie_types
export storie_types  # Re-export types so users get them automatically

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

proc generateSectionId*(title: string): string =
  ## Generate a URL-safe section ID from a title
  result = ""
  for c in title.toLowerAscii():
    if c in {'a'..'z', '0'..'9'}:
      result.add(c)
    elif c == ' ' or c == '-' or c == '_':
      if result.len > 0 and result[^1] != '_':
        result.add('_')
  # Remove trailing underscores
  while result.len > 0 and result[^1] == '_':
    result.setLen(result.len - 1)
  if result.len == 0:
    result = "section"

proc parseHeadingMetadata*(headingLine: string): tuple[title: string, metadata: Table[string, string]] =
  ## Parse a heading line that may contain JSON metadata
  ## Format: # title {"key": "value", "another": true}
  ## Returns tuple of (cleaned title, metadata table)
  result.title = headingLine
  result.metadata = initTable[string, string]()
  
  # Look for JSON object at end of heading
  let jsonStart = headingLine.find('{')
  if jsonStart < 0:
    return
  
  let jsonEnd = headingLine.rfind('}')
  if jsonEnd < 0 or jsonEnd <= jsonStart:
    return
  
  # Extract title (everything before JSON)
  result.title = headingLine[0..<jsonStart].strip()
  
  # Parse simple JSON object (basic key-value pairs)
  let jsonStr = headingLine[jsonStart..jsonEnd]
  var i = 1  # Skip opening brace
  
  while i < jsonStr.len - 1:  # Skip closing brace
    # Skip whitespace and commas
    while i < jsonStr.len and jsonStr[i] in {' ', '\t', '\n', ','}:
      inc i
    
    if i >= jsonStr.len - 1:
      break
    
    # Parse key (expecting "key")
    if jsonStr[i] != '"':
      break
    inc i
    var key = ""
    while i < jsonStr.len and jsonStr[i] != '"':
      key.add(jsonStr[i])
      inc i
    inc i  # Skip closing quote
    
    # Skip whitespace and colon
    while i < jsonStr.len and jsonStr[i] in {' ', '\t', '\n', ':'}:
      inc i
    
    # Parse value (can be string, number, boolean)
    var value = ""
    if jsonStr[i] == '"':
      # String value
      inc i
      while i < jsonStr.len and jsonStr[i] != '"':
        value.add(jsonStr[i])
        inc i
      inc i  # Skip closing quote
    else:
      # Number or boolean
      while i < jsonStr.len and jsonStr[i] notin {',', '}', ' ', '\t', '\n'}:
        value.add(jsonStr[i])
        inc i
    
    if key.len > 0:
      result.metadata[key] = value

proc parseMarkdownInline*(text: string): seq[MarkdownElement] =
  ## Parse inline markdown formatting (bold, italic, links)
  ## Returns a sequence of MarkdownElements with formatting applied
  result = @[]
  var i = 0
  var currentText = ""
  var isBold = false
  var isItalic = false
  
  while i < text.len:
    # Check for links: [text](url) or [text](#anchor)
    if text[i] == '[':
      # Flush current
      if currentText.len > 0:
        result.add(MarkdownElement(
          text: currentText,
          bold: isBold,
          italic: isItalic,
          isLink: false,
          linkUrl: ""
        ))
        currentText = ""
      
      var linkText = ""
      var linkUrl = ""
      var j = i + 1
      
      # Extract link text
      while j < text.len and text[j] != ']':
        linkText.add(text[j])
        inc j
      
      if j < text.len and j + 1 < text.len and text[j] == ']' and text[j + 1] == '(':
        # Extract URL
        j += 2
        while j < text.len and text[j] != ')':
          linkUrl.add(text[j])
          inc j
        
        if j < text.len and text[j] == ')':
          result.add(MarkdownElement(
            text: linkText,
            bold: isBold,
            italic: isItalic,
            isLink: true,
            linkUrl: linkUrl
          ))
          i = j + 1
          continue
      
    # Check for bold: **text**
    if i + 1 < text.len and text[i] == '*' and text[i + 1] == '*':
      # Flush current
      if currentText.len > 0:
        result.add(MarkdownElement(
          text: currentText,
          bold: isBold,
          italic: isItalic,
          isLink: false,
          linkUrl: ""
        ))
        currentText = ""
      
      isBold = not isBold
      i += 2
      continue
    
    # Check for italic: *text* (but not if it's part of **)
    if text[i] == '*' and not (i + 1 < text.len and text[i + 1] == '*') and not (i > 0 and text[i - 1] == '*'):
      # Flush current
      if currentText.len > 0:
        result.add(MarkdownElement(
          text: currentText,
          bold: isBold,
          italic: isItalic,
          isLink: false,
          linkUrl: ""
        ))
        currentText = ""
      
      isItalic = not isItalic
      i += 1
      continue
    
    # Regular character
    currentText.add(text[i])
    inc i
  
  # Final flush
  if currentText.len > 0:
    result.add(MarkdownElement(
      text: currentText,
      bold: isBold,
      italic: isItalic,
      isLink: false,
      linkUrl: ""
    ))
  
  # If no formatting was found, return single element
  if result.len == 0:
    result.add(MarkdownElement(
      text: text,
      bold: false,
      italic: false,
      isLink: false,
      linkUrl: ""
    ))


proc parseMarkdownDocument*(content: string): MarkdownDocument =
  ## Parse a complete Markdown document including front matter, sections, and code blocks.
  ## Front matter is optional YAML-style metadata at the start of the document.
  ## 
  ## The document is organized into sections based on headings. Each section contains
  ## its heading and all content blocks until the next heading.
  ## 
  ## Example:
  ##   ---
  ##   targetFPS: 30
  ##   title: My App
  ##   ---
  ##   
  ##   # Introduction
  ##   Welcome to my app!
  ##   
  ##   ```nim on:render
  ##   bgWriteText(0, 0, "Hello")
  ##   ```
  ##   
  ##   # Next Section
  ##   More content here.
  result.frontMatter = parseFrontMatter(content)
  result.codeBlocks = @[]
  result.sections = @[]
  
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
  
  var currentSection: Section
  var hasCurrentSection = false
  var sectionCounter = 0
  var textBuffer: seq[string] = @[]
  
  # Parse document line by line
  while i < lines.len:
    let line = lines[i]
    let trimmed = line.strip()
    
    # Check for headings (# Title, ## Title, etc.)
    if trimmed.startsWith("#"):
      # Flush text buffer
      if textBuffer.len > 0:
        let text = textBuffer.join("\n")
        if text.strip().len > 0:
          let elements = parseMarkdownInline(text)
          let contentBlock = ContentBlock(
            kind: TextBlock,
            text: text,
            elements: elements
          )
          if hasCurrentSection:
            currentSection.blocks.add(contentBlock)
          else:
            # Create default intro section
            inc sectionCounter
            let sectionId = "section_" & $sectionCounter
            currentSection = Section(
              id: sectionId,
              title: "",
              level: 1,
              blocks: @[],
              metadata: initTable[string, string]()
            )
            currentSection.blocks.add(ContentBlock(
              kind: HeadingBlock,
              level: 1,
              title: ""
            ))
            currentSection.blocks.add(contentBlock)
            hasCurrentSection = true
        textBuffer = @[]
      
      # Finish current section
      if hasCurrentSection:
        result.sections.add(currentSection)
        hasCurrentSection = false
      
      # Start new section
      var level = 0
      var titleStart = 0
      while titleStart < trimmed.len and trimmed[titleStart] == '#':
        inc level
        inc titleStart
      if level <= 6:  # Valid heading levels
        let headingText = trimmed[titleStart..^1].strip()
        let (title, metadata) = parseHeadingMetadata(headingText)
        # Start new section
        inc sectionCounter
        let sectionId = if title.len > 0: generateSectionId(title) else: "section_" & $sectionCounter
        currentSection = Section(
          id: sectionId,
          title: title,
          level: level,
          blocks: @[],
          metadata: metadata
        )
        # Add heading block
        currentSection.blocks.add(ContentBlock(
          kind: HeadingBlock,
          level: level,
          title: title
        ))
        hasCurrentSection = true
        inc i
        continue
    
    # Look for code block start: ```nim or ``` nim
    if trimmed.startsWith("```") or trimmed.startsWith("``` "):
      # Flush text buffer
      if textBuffer.len > 0:
        let text = textBuffer.join("\n")
        if text.strip().len > 0:
          let elements = parseMarkdownInline(text)
          let contentBlock = ContentBlock(
            kind: TextBlock,
            text: text,
            elements: elements
          )
          if hasCurrentSection:
            currentSection.blocks.add(contentBlock)
          else:
            # Create default intro section
            inc sectionCounter
            let sectionId = "section_" & $sectionCounter
            currentSection = Section(
              id: sectionId,
              title: "",
              level: 1,
              blocks: @[],
              metadata: initTable[string, string]()
            )
            currentSection.blocks.add(ContentBlock(
              kind: HeadingBlock,
              level: 1,
              title: ""
            ))
            currentSection.blocks.add(contentBlock)
            hasCurrentSection = true
        textBuffer = @[]
      
      var headerParts = trimmed[3..^1].strip().split()
      if headerParts.len > 0 and headerParts[0] == "nim":
        var lifecycle = ""
        var language = "nim"
        
        # Check for on:* attribute (e.g., on:render, on:update, on:enter, on:exit)
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
        
        # Create the code block
        let codeBlock = CodeBlock(
          code: codeLines.join("\n"),
          lifecycle: lifecycle,
          language: language
        )
        
        # Add to flat list for backward compatibility
        result.codeBlocks.add(codeBlock)
        
        # Add to current section
        if hasCurrentSection:
          currentSection.blocks.add(ContentBlock(
            kind: CodeBlock_Content,
            codeBlock: codeBlock
          ))
        else:
          # Create default section if needed
          inc sectionCounter
          let sectionId = "section_" & $sectionCounter
          currentSection = Section(
            id: sectionId,
            title: "",
            level: 1,
            blocks: @[],
            metadata: initTable[string, string]()
          )
          currentSection.blocks.add(ContentBlock(
            kind: HeadingBlock,
            level: 1,
            title: ""
          ))
          currentSection.blocks.add(ContentBlock(
            kind: CodeBlock_Content,
            codeBlock: codeBlock
          ))
          hasCurrentSection = true
      else:
        # Non-Nim code block, skip it
        inc i
        while i < lines.len:
          if lines[i].strip().startsWith("```"):
            break
          inc i
    else:
      # Regular text line - add to buffer
      textBuffer.add(line)
    
    inc i
  
  # Flush any remaining text
  if textBuffer.len > 0:
    let text = textBuffer.join("\n")
    if text.strip().len > 0:
      let elements = parseMarkdownInline(text)
      let contentBlock = ContentBlock(
        kind: TextBlock,
        text: text,
        elements: elements
      )
      if hasCurrentSection:
        currentSection.blocks.add(contentBlock)
      else:
        # Create default intro section
        inc sectionCounter
        let sectionId = "section_" & $sectionCounter
        currentSection = Section(
          id: sectionId,
          title: "",
          level: 1,
          blocks: @[],
          metadata: initTable[string, string]()
        )
        currentSection.blocks.add(ContentBlock(
          kind: HeadingBlock,
          level: 1,
          title: ""
        ))
        currentSection.blocks.add(contentBlock)
        hasCurrentSection = true
    textBuffer = @[]
  
  # Finish the last section
  if hasCurrentSection:
    result.sections.add(currentSection)
  
  # If no sections were created (no headings), create a single default section
  if result.sections.len == 0 and result.codeBlocks.len > 0:
    var defaultSection = Section(
      id: "main",
      title: "",
      level: 1,
      blocks: @[],
      metadata: initTable[string, string]()
    )
    for cb in result.codeBlocks:
      defaultSection.blocks.add(ContentBlock(
        kind: CodeBlock_Content,
        codeBlock: cb
      ))
    result.sections.add(defaultSection)


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
