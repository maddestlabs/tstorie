## Storie Markdown Parser
##
## Platform-agnostic markdown parser for extracting Nim code blocks with lifecycle hooks.
## This module has no file I/O or platform-specific dependencies - it only processes string content.

import strutils, tables
import storie_types, storie_themes
export storie_types, storie_themes  # Re-export types so users get them automatically

# Global table to store embedded figlet fonts from markdown
var gEmbeddedFigletFonts* = initTable[string, string]()

proc parseColor*(colorStr: string): tuple[r, g, b: uint8] =
  ## Parse a color string in various formats:
  ## - "255,0,0" or "255, 0, 0" (RGB values)
  ## - "#FF0000" (hex color)
  ## Returns tuple of RGB values
  let trimmed = colorStr.strip()
  
  if trimmed.startsWith("#"):
    # Hex color: #RRGGBB
    if trimmed.len == 7:
      let r = parseHexInt(trimmed[1..2])
      let g = parseHexInt(trimmed[3..4])
      let b = parseHexInt(trimmed[5..6])
      return (r.uint8, g.uint8, b.uint8)
  elif ',' in trimmed:
    # Comma-separated RGB: "255, 0, 0"
    let parts = trimmed.split(',')
    if parts.len == 3:
      let r = parseInt(parts[0].strip())
      let g = parseInt(parts[1].strip())
      let b = parseInt(parts[2].strip())
      return (r.uint8, g.uint8, b.uint8)
  
  # Default to black if parsing fails
  return (0'u8, 0'u8, 0'u8)

proc parseBool*(boolStr: string): bool =
  ## Parse a boolean string value
  let lower = boolStr.strip().toLowerAscii()
  return lower == "true" or lower == "yes" or lower == "1"

proc parseStyleSheet*(frontMatter: FrontMatter): StyleSheet =
  ## Parse style configurations from front matter
  ## Supports:
  ##   1. Theme-based: theme: "catppuccin"
  ##   2. Individual styles: styles.heading.fg: "#FF0000"
  ## Theme is applied first, then individual overrides
  result = initTable[string, StyleConfig]()
  
  # Check if a theme is specified and get theme colors for defaults
  var themeColors: ThemeColors
  if frontMatter.hasKey("theme"):
    let themeName = frontMatter["theme"]
    themeColors = getTheme(themeName)
    result = applyTheme(themeColors, themeName)
  else:
    # Use default theme (Futurism) for colors even if no theme specified
    themeColors = getTheme("futurism")
  
  var styleData = initTable[string, Table[string, string]]()
  
  # Collect all style.* keys and group by style name
  for key, value in frontMatter:
    if key.startsWith("styles."):
      let rest = key[7..^1]  # Remove "styles." prefix
      let dotPos = rest.find('.')
      
      if dotPos > 0:
        let styleName = rest[0..<dotPos]
        let property = rest[dotPos+1..^1]
        
        if not styleData.hasKey(styleName):
          styleData[styleName] = initTable[string, string]()
        
        styleData[styleName][property] = value
  
  # Convert collected data into StyleConfig objects (overriding theme if set)
  for styleName, properties in styleData:
    # Start with existing style if theme was applied, otherwise use theme defaults
    var style = if result.hasKey(styleName):
      result[styleName]
    else:
      StyleConfig(
        fg: themeColors.fgPrimary,      # Use theme's foreground
        bg: themeColors.bgPrimary,      # Use theme's background
        bold: false,
        italic: false,
        underline: false,
        dim: false
      )
    
    # Apply property overrides
    for prop, val in properties:
      case prop
      of "fg", "foreground":
        style.fg = parseColor(val)
      of "bg", "background":
        style.bg = parseColor(val)
      of "bold":
        style.bold = parseBool(val)
      of "italic":
        style.italic = parseBool(val)
      of "underline":
        style.underline = parseBool(val)
      of "dim":
        style.dim = parseBool(val)
      else:
        discard  # Unknown property, ignore
    
    result[styleName] = style

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
      var value = line[colonPos+1..^1].strip()
      
      # Remove surrounding quotes if present
      if value.len >= 2 and value[0] == '"' and value[^1] == '"':
        value = value[1..^2]
      
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
    # Check for inline code: `text` - content inside should NOT be parsed as markdown
    if text[i] == '`':
      # Flush current text
      if currentText.len > 0:
        result.add(MarkdownElement(
          text: currentText,
          bold: isBold,
          italic: isItalic,
          isLink: false,
          linkUrl: ""
        ))
        currentText = ""
      
      # Find closing backtick
      var codeText = ""
      var j = i + 1
      while j < text.len and text[j] != '`':
        codeText.add(text[j])
        inc j
      
      if j < text.len and text[j] == '`':
        # Found closing backtick - add code content as literal text (no formatting)
        result.add(MarkdownElement(
          text: codeText,
          bold: false,  # Force no formatting for inline code
          italic: false,
          isLink: false,
          linkUrl: ""
        ))
        i = j + 1
        continue
      else:
        # No closing backtick found, treat opening backtick as regular character
        currentText.add('`')
        i += 1
        continue
    
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
  result.styleSheet = parseStyleSheet(result.frontMatter)
  result.codeBlocks = @[]
  result.sections = @[]
  result.embeddedContent = @[]
  
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
      
      # Check for embedded content blocks: figlet:NAME, data:NAME, custom:NAME
      if headerParts.len > 0:
        let header = headerParts[0]
        
        # Check for figlet:NAME blocks
        if header.startsWith("figlet:"):
          let fontName = header[7..^1]  # Extract name after "figlet:"
          # Extract figlet font content
          var fontLines: seq[string] = @[]
          inc i
          while i < lines.len:
            if lines[i].strip().startsWith("```"):
              break
            fontLines.add(lines[i])
            inc i
          # Store in global table for runtime use
          let fontContent = fontLines.join("\n")
          gEmbeddedFigletFonts[fontName] = fontContent
          # Also store in document for export
          result.embeddedContent.add(EmbeddedContent(
            name: fontName,
            kind: FigletFont,
            content: fontContent
          ))
          inc i
          continue
        
        # Check for data:NAME blocks
        elif header.startsWith("data:"):
          let dataName = header[5..^1]  # Extract name after "data:"
          # Extract data content
          var dataLines: seq[string] = @[]
          inc i
          while i < lines.len:
            if lines[i].strip().startsWith("```"):
              break
            dataLines.add(lines[i])
            inc i
          let dataContent = dataLines.join("\n")
          result.embeddedContent.add(EmbeddedContent(
            name: dataName,
            kind: DataFile,
            content: dataContent
          ))
          inc i
          continue
        
        # Check for custom:NAME blocks
        elif header.startsWith("custom:"):
          let customName = header[7..^1]  # Extract name after "custom:"
          # Extract custom content
          var customLines: seq[string] = @[]
          inc i
          while i < lines.len:
            if lines[i].strip().startsWith("```"):
              break
            customLines.add(lines[i])
            inc i
          let customContent = customLines.join("\n")
          result.embeddedContent.add(EmbeddedContent(
            name: customName,
            kind: Custom,
            content: customContent
          ))
          inc i
          continue
      
      # If we get here, it's a regular code block (nim on:*, etc.)
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
        # Non-Nim code block - parse it as a data block (e.g., lvl, json, txt, etc.)
        var language = if headerParts.len > 0: headerParts[0] else: ""
        
        # Extract code block content
        var codeLines: seq[string] = @[]
        inc i
        while i < lines.len:
          if lines[i].strip().startsWith("```"):
            break
          codeLines.add(lines[i])
          inc i
        
        # Create the code block (no lifecycle for non-Nim blocks)
        let codeBlock = CodeBlock(
          code: codeLines.join("\n"),
          lifecycle: "",  # Data blocks don't have lifecycle
          language: language
        )
        
        # Add to flat list
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
