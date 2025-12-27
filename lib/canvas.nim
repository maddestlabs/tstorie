## Canvas Navigation System for TStorie
## Provides spatial layout, smooth camera panning, and interactive navigation
## Compatible with Nimini code blocks
##
## Note: This module expects storie_md and layout to be available from the importing context.

import std/[tables, strutils, sequtils, math, sets, sugar, algorithm]

# Forward declare global for nimini environment (set during rendering)
var gNiminiEnv {.global.}: pointer = nil

# ================================================================
# CONFIGURATION CONSTANTS
# ================================================================

const
  SECTION_WIDTH = 60
  SECTION_HEIGHT = 20
  SECTION_PADDING = 10
  MAX_SECTIONS_PER_ROW = 3
  PAN_SPEED = 5.0
  SMOOTH_SPEED = 8.0

# ================================================================
# STYLE CONVERSION HELPERS
# ================================================================

proc toStyle*(config: StyleConfig): Style =
  ## Convert StyleConfig to Style
  Style(
    fg: rgb(config.fg.r, config.fg.g, config.fg.b),
    bg: rgb(config.bg.r, config.bg.g, config.bg.b),
    bold: config.bold,
    italic: config.italic,
    underline: config.underline,
    dim: config.dim
  )

proc getDefaultStyleConfig*(): StyleConfig =
  ## Get default style configuration
  StyleConfig(
    fg: (255'u8, 255'u8, 255'u8),
    bg: (0'u8, 0'u8, 0'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

# ================================================================
# TYPE DEFINITIONS
# ================================================================

type
  Camera* = object
    x*, y*: float
    targetX*, targetY*: float
  
  Link* = object
    text*: string
    target*: string
    screenX*, screenY*: int
    width*: int
    index*: int
  
  SectionLayout* = object
    section*: Section
    x*, y*: int
    width*, height*: int
    index*: int
  
  # Callback type for executing code blocks (lifecycle hooks)
  ExecuteCodeBlockCallback* = proc(codeBlock: CodeBlock, lifecycle: string): bool
  
  CanvasState* = ref object
    camera*: Camera
    sections*: seq[SectionLayout]
    currentSectionIdx*: int
    links*: seq[Link]
    focusedLinkIdx*: int
    visitedSections*: HashSet[string]
    hiddenSections*: HashSet[string]
    removedSections*: HashSet[string]
    mouseEnabled*: bool
    presentationMode*: bool
    lastRenderTime*: float
    lastViewportWidth*: int
    lastViewportHeight*: int
    executeCallback*: ExecuteCodeBlockCallback  # Callback to execute lifecycle hooks
    contentBuffers*: Table[string, seq[string]]  # Per-section buffers for dynamically generated content

# Global canvas state
var canvasState*: CanvasState

# Global viewport dimensions
var
  gViewportWidth: int
  gViewportHeight: int

# ================================================================
# SECTION STATE MANAGEMENT
# ================================================================

# Forward declarations
proc centerOnSection*(sectionIdx: int, viewportWidth, viewportHeight: int)

proc isVisited*(sectionTitle: string): bool =
  ## Check if a section has been visited
  if canvasState.isNil:
    return false
  return sectionTitle in canvasState.visitedSections

proc markVisited*(sectionTitle: string) =
  ## Mark a section as visited and unhide it
  if canvasState.isNil:
    return
  canvasState.visitedSections.incl(sectionTitle)
  canvasState.hiddenSections.excl(sectionTitle)

proc isHidden*(sectionTitle: string): bool =
  ## Check if a section is hidden
  if canvasState.isNil:
    return false
  return sectionTitle in canvasState.hiddenSections

proc hideSection*(sectionTitle: string) =
  ## Hide a section
  if canvasState.isNil:
    return
  canvasState.hiddenSections.incl(sectionTitle)

proc isRemoved*(sectionTitle: string): bool =
  ## Check if a section has been removed
  if canvasState.isNil:
    return false
  return sectionTitle in canvasState.removedSections

proc removeSection*(sectionTitle: string) =
  ## Remove a section from display
  if canvasState.isNil:
    return
  canvasState.removedSections.incl(sectionTitle)

proc restoreSection*(sectionTitle: string) =
  ## Restore a removed section
  if canvasState.isNil:
    return
  canvasState.removedSections.excl(sectionTitle)

# ================================================================
# SECTION LOOKUP AND NAVIGATION
# ================================================================

proc findSectionByReference*(reference: string): SectionLayout =
  ## Find a section by ID or title (case-insensitive partial match)
  if canvasState.isNil:
    return SectionLayout()
  
  var refStr = reference
  # Remove leading # if present
  if refStr.len > 0 and refStr[0] == '#':
    refStr = refStr[1..^1]
  
  let lowerRef = refStr.toLowerAscii()
  
  # Try exact title match first (most common)
  for layout in canvasState.sections:
    if layout.section.title == refStr:
      return layout
  
  # Try exact ID match
  for layout in canvasState.sections:
    if layout.section.id == refStr:
      return layout
  
  # Try case-insensitive title match
  for layout in canvasState.sections:
    if layout.section.title.toLowerAscii() == lowerRef:
      return layout
  
  # Try partial title match
  for layout in canvasState.sections:
    if lowerRef in layout.section.title.toLowerAscii():
      return layout
  
  return SectionLayout()

proc executeLifecycleHooks(section: Section, lifecycle: string) =
  ## Execute lifecycle hooks (on:enter, on:exit) for a section
  if canvasState.isNil or canvasState.executeCallback.isNil:
    return
  
  # Find and execute all code blocks with the specified lifecycle
  for contentBlock in section.blocks:
    if contentBlock.kind == CodeBlock_Content:
      let codeBlock = contentBlock.codeBlock
      if codeBlock.lifecycle == lifecycle:
        # Execute via callback (will be set by main application)
        discard canvasState.executeCallback(codeBlock, lifecycle)

proc navigateToSection*(sectionIdx: int) =
  ## Navigate to a section by index
  if canvasState.isNil or sectionIdx < 0 or sectionIdx >= canvasState.sections.len:
    return
  
  let previousIdx = canvasState.currentSectionIdx
  
  # Execute on:exit hooks for the previous section
  if previousIdx >= 0 and previousIdx < canvasState.sections.len and previousIdx != sectionIdx:
    let previousSection = canvasState.sections[previousIdx].section
    executeLifecycleHooks(previousSection, "exit")
    
    # Check if leaving a section that should be removed after visit
    if previousSection.metadata.hasKey("removeAfterVisit"):
      let removeValue = previousSection.metadata["removeAfterVisit"].toLowerAscii()
      if removeValue == "true" or removeValue == "1":
        removeSection(previousSection.title)
  
  canvasState.currentSectionIdx = sectionIdx
  canvasState.focusedLinkIdx = 0
  
  # Note: Content buffers are per-section, so no need to clear on navigation
  
  # Execute on:enter hooks for the new section
  if sectionIdx >= 0 and sectionIdx < canvasState.sections.len:
    let newSection = canvasState.sections[sectionIdx].section
    executeLifecycleHooks(newSection, "enter")
  
  # Center camera on new section with smooth easing (if viewport is initialized)
  if gViewportWidth > 0 and gViewportHeight > 0:
    centerOnSection(sectionIdx, gViewportWidth, gViewportHeight)

# ================================================================
# LINK PARSING AND FILTERING
# ================================================================

proc parseLinks*(text: string): seq[tuple[text: string, target: string]] =
  ## Parse markdown links from text: [text](target)
  result = @[]
  var pos = 0
  
  while pos < text.len:
    let linkStart = text.find("[", pos)
    if linkStart < 0:
      break
    
    let linkTextEnd = text.find("]", linkStart + 1)
    if linkTextEnd < 0:
      break
    
    if linkTextEnd + 1 < text.len and text[linkTextEnd + 1] == '(':
      let targetEnd = text.find(")", linkTextEnd + 2)
      if targetEnd >= 0:
        let linkText = text[linkStart + 1 ..< linkTextEnd]
        let target = text[linkTextEnd + 2 ..< targetEnd]
        result.add((text: linkText, target: target))
        pos = targetEnd + 1
      else:
        break
    else:
      pos = linkTextEnd + 1

proc filterRemovedSectionLinks*(content: string): string =
  ## Filter out list items that contain only links to removed sections
  var lines: seq[string] = @[]
  
  for line in content.splitLines():
    let trimmed = line.strip()
    
    # Check for list item pattern: bullet + content
    var bullet = ""
    var restOfLine = ""
    
    if trimmed.len > 0 and trimmed[0] in ['*', '+', '-']:
      if trimmed.len > 1 and trimmed[1] == ' ':
        bullet = $trimmed[0]
        restOfLine = trimmed[2..^1].strip()
      else:
        lines.add(line)
        continue
    else:
      lines.add(line)
      continue
    
    # Check if the rest is purely a link
    let parsedLinks = parseLinks(restOfLine)
    if parsedLinks.len == 1:
      # Check if entire restOfLine is just this one link
      let expectedLink = "[" & parsedLinks[0].text & "](" & parsedLinks[0].target & ")"
      if restOfLine == expectedLink:
        # This is a list item with ONLY a link
        let targetSection = findSectionByReference(parsedLinks[0].target)
        if targetSection.section.id != "" and isRemoved(targetSection.section.title):
          # Skip this line (don't add to output)
          continue
    
    # Keep this line
    lines.add(line)
  
  return lines.join("\n")

# ================================================================
# CAMERA MANAGEMENT
# ================================================================

proc updateCamera*(deltaTime: float, viewportWidth, viewportHeight: int) =
  ## Smooth camera movement toward target
  if canvasState.isNil:
    return
  
  let rawT = min(1.0, deltaTime * SMOOTH_SPEED)
  let t = rawT * (2.0 - rawT)  # Ease-out quadratic for smoother motion
  canvasState.camera.x += (canvasState.camera.targetX - canvasState.camera.x) * t
  canvasState.camera.y += (canvasState.camera.targetY - canvasState.camera.y) * t
  
  # Snap when close enough
  if abs(canvasState.camera.targetX - canvasState.camera.x) < 0.5:
    canvasState.camera.x = canvasState.camera.targetX
  if abs(canvasState.camera.targetY - canvasState.camera.y) < 0.5:
    canvasState.camera.y = canvasState.camera.targetY

proc centerOnSection*(sectionIdx: int, viewportWidth, viewportHeight: int) =
  ## Center camera on a specific section
  if canvasState.isNil or sectionIdx < 0 or sectionIdx >= canvasState.sections.len:
    return
  
  let section = canvasState.sections[sectionIdx]
  
  # Center horizontally on section's center
  canvasState.camera.targetX = float(section.x + section.width div 2 - viewportWidth div 2)
  
  # Center vertically on the section's center
  let sectionCenter = section.y + section.height div 2
  canvasState.camera.targetY = float(sectionCenter - viewportHeight div 2)

# ================================================================
# LAYOUT CALCULATION
# ================================================================

proc calculateSectionPositions*(sections: seq[Section]): seq[SectionLayout] =
  ## Calculate spatial positions for all sections
  result = @[]
  var currentX = 0
  var currentY = 0
  var maxHeightInRow = 0
  var sectionsInRow = 0
  
  for i, section in sections:
    var layout = SectionLayout(
      section: section,
      width: SECTION_WIDTH,
      height: SECTION_HEIGHT,
      index: i
    )
    
    # Check for custom x,y in metadata
    if section.metadata.hasKey("x") and section.metadata.hasKey("y"):
      try:
        layout.x = parseInt(section.metadata["x"])
        layout.y = parseInt(section.metadata["y"])
      except:
        # Use grid layout
        layout.x = currentX
        layout.y = currentY
        sectionsInRow += 1
    else:
      # Grid layout
      layout.x = currentX
      layout.y = currentY
      sectionsInRow += 1
    
    maxHeightInRow = max(maxHeightInRow, SECTION_HEIGHT)
    
    if sectionsInRow >= MAX_SECTIONS_PER_ROW:
      currentX = 0
      currentY += maxHeightInRow + SECTION_PADDING
      maxHeightInRow = 0
      sectionsInRow = 0
    else:
      currentX += SECTION_WIDTH + SECTION_PADDING
    
    result.add(layout)

# ================================================================
# SECTION HIERARCHY HELPERS (for presentation mode)
# ================================================================

proc getSectionLevel*(section: Section): int =
  ## Get the heading level (1 for #, 2 for ##, etc.)
  ## Returns 1 if not determinable
  let title = section.title
  var level = 1
  var pos = 0
  while pos < title.len and title[pos] == '#':
    inc level
    inc pos
  return level

proc getNextSectionAtLevel*(currentIdx: int, level: int, forward: bool = true): int =
  ## Find next/previous section at specified heading level
  ## Returns -1 if no section found at that level
  if canvasState.isNil or currentIdx < 0:
    return -1
  
  let step = if forward: 1 else: -1
  var idx = currentIdx + step
  
  while idx >= 0 and idx < canvasState.sections.len:
    if getSectionLevel(canvasState.sections[idx].section) == level:
      return idx
    idx += step
  
  return -1  # Not found

# ================================================================
# TEXT RENDERING UTILITIES
# ================================================================

proc wrapText*(text: string, maxWidth: int): seq[string] =
  ## Wrap text to fit within maxWidth
  result = @[]
  let words = text.split(' ')
  var currentLine = ""
  
  for word in words:
    if currentLine.len + word.len + 1 <= maxWidth:
      if currentLine.len > 0:
        currentLine.add(" ")
      currentLine.add(word)
    else:
      if currentLine.len > 0:
        result.add(currentLine)
      currentLine = word
  
  if currentLine.len > 0:
    result.add(currentLine)

proc formatHeading*(text: string): string =
  ## Format a heading by removing markdown syntax and title-casing
  var cleaned = text
  # Remove leading # characters and whitespace
  while cleaned.len > 0 and cleaned[0] == '#':
    cleaned = cleaned[1..^1]
  cleaned = cleaned.strip()
  cleaned = cleaned.replace("_", " ")
  
  # Title case each word
  var words: seq[string] = @[]
  for word in cleaned.split(' '):
    if word.len > 0:
      words.add(word[0].toUpperAscii() & word[1..^1].toLowerAscii())
  result = words.join(" ")

proc stripMarkdownFormatting*(text: string): string =
  ## Remove markdown bold (**) and italic (*) markers
  result = text
  result = result.replace("**", "")
  result = result.replace("*", "")

# ================================================================
# INITIALIZATION
# ================================================================

proc initCanvas*(sections: seq[Section], currentIdx: int = 0, presentationMode: bool = false) =
  ## Initialize the canvas system (idempotent - only initializes if not already done)
  ## Set presentationMode=true for slide-style navigation where all sections are visible
  if not canvasState.isNil:
    return  # Already initialized
  
  canvasState = CanvasState(
    camera: Camera(x: 0.0, y: 0.0, targetX: 0.0, targetY: 0.0),
    sections: calculateSectionPositions(sections),
    currentSectionIdx: currentIdx,
    links: @[],
    focusedLinkIdx: 0,
    visitedSections: initHashSet[string](),
    hiddenSections: initHashSet[string](),
    removedSections: initHashSet[string](),
    mouseEnabled: false,
    presentationMode: presentationMode,
    lastRenderTime: 0.0,
    lastViewportWidth: 0,
    lastViewportHeight: 0,
    contentBuffers: initTable[string, seq[string]]()
  )
  
  # Initialize section visibility from metadata
  for layout in canvasState.sections:
    if layout.section.metadata.hasKey("hidden"):
      if layout.section.metadata["hidden"].toLowerAscii() in ["true", "yes", "1"]:
        hideSection(layout.section.title)
  
  # In presentation mode, make all sections visible by default
  if presentationMode:
    for layout in canvasState.sections:
      markVisited(layout.section.title)
  
  # Mark starting section as visited
  if currentIdx >= 0 and currentIdx < sections.len:
    markVisited(sections[currentIdx].title)
    # Note: Initial camera centering happens during first render when viewport is known

proc enableMouse*() =
  ## Enable mouse input for the canvas
  if not canvasState.isNil:
    canvasState.mouseEnabled = true

proc disableMouse*() =
  ## Disable mouse input for the canvas
  if not canvasState.isNil:
    canvasState.mouseEnabled = false

proc setExecuteCallback*(callback: ExecuteCodeBlockCallback) =
  ## Set the callback function for executing lifecycle hooks
  ## This should be called after canvas initialization to enable on:enter and on:exit hooks
  if not canvasState.isNil:
    canvasState.executeCallback = callback

# ================================================================
# PUBLIC API EXPORTS
# ================================================================

# Re-export key functions
export isVisited, markVisited, isHidden, hideSection
export isRemoved, removeSection, restoreSection
export findSectionByReference, navigateToSection
export parseLinks, filterRemovedSectionLinks
export updateCamera, centerOnSection
export getSectionLevel, getNextSectionAtLevel
export wrapText, formatHeading, stripMarkdownFormatting
export initCanvas, enableMouse, disableMouse
export Camera, Link, SectionLayout, CanvasState
export canvasState

# ================================================================
# RENDERING
# ================================================================

# Helper to convert ANSI color codes to Color objects  
proc ansiToColor(code: int): Color =
  ## Convert ANSI color code to RGB Color
  case code
  of 30, 0: return black()      # Black
  of 31: return red()           # Red
  of 32: return green()         # Green
  of 33: return yellow()        # Yellow
  of 34: return blue()          # Blue
  of 35: return magenta()       # Magenta
  of 36: return cyan()          # Cyan
  of 37: return white()         # White/Gray
  else: return gray(128)        # Default gray

proc setViewport*(width, height: int) =
  ## Set viewport dimensions
  gViewportWidth = width
  gViewportHeight = height

proc renderInlineMarkdown(text: string, x, y: int, maxWidth: int, 
                         buffer: var TermBuffer, baseStyle: Style): int =
  ## Render text with inline markdown formatting (bold **, italic *)
  ## Returns number of characters rendered
  
  # Process text with markdown formatting
  var expandedText = text
  var currentX = x
  var pos = 0  # Position in text
  var isBold = baseStyle.bold
  var isItalic = baseStyle.italic
  
  while pos < expandedText.len and currentX < x + maxWidth:
    # Check for inline code (backticks) - content inside should be rendered literally
    if expandedText[pos] == '`':
      # Find closing backtick
      let codeStart = pos + 1
      var codeEnd = codeStart
      while codeEnd < expandedText.len and expandedText[codeEnd] != '`':
        codeEnd += 1
      
      if codeEnd < expandedText.len:
        # Found matching backtick - check if it's a variable reference
        let codeContent = expandedText[codeStart ..< codeEnd]
        
        # Check for `? varName` syntax - expand from nimini environment
        if codeContent.len > 1 and codeContent[0] == '?' and codeContent[1] == ' ':
          let varName = codeContent[2..^1].strip()
          var value = ""
          var found = false
          
          # Try to get value from nimini environment (if available)
          when compiles(getVar):
            if not gNiminiEnv.isNil:
              try:
                let env = cast[ref Env](gNiminiEnv)
                let nimVal = getVar(env, varName)
                case nimVal.kind
                of vkString: 
                  value = nimVal.s
                  found = true
                of vkInt: 
                  value = $nimVal.i
                  found = true
                of vkFloat: 
                  value = $nimVal.f
                  found = true
                of vkBool: 
                  value = $nimVal.b
                  found = true
                else: 
                  discard
              except:
                discard
          
          # Render the value or the original text if not found
          let textToRender = if found: value else: codeContent
          for ch in textToRender:
            if currentX >= x + maxWidth:
              break
            var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: false, 
                             underline: baseStyle.underline, italic: false, dim: baseStyle.dim)
            buffer.writeText(currentX, y, $ch, style)
            currentX += 1
          pos = codeEnd + 1
        else:
          # Not a variable reference - render the content literally
          for ch in codeContent:
            if currentX >= x + maxWidth:
              break
            var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: false, 
                             underline: baseStyle.underline, italic: false, dim: baseStyle.dim)
            buffer.writeText(currentX, y, $ch, style)
            currentX += 1
          pos = codeEnd + 1  # Skip past closing backtick
      else:
        # No matching backtick, render the backtick itself
        var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: isBold, 
                         underline: baseStyle.underline, italic: isItalic, dim: baseStyle.dim)
        buffer.writeText(currentX, y, "`", style)
        currentX += 1
        pos += 1
    # Check for **bold**
    elif pos + 1 < expandedText.len and expandedText[pos..pos+1] == "**":
      isBold = not isBold
      pos += 2
    # Check for *italic*
    elif expandedText[pos] == '*':
      isItalic = not isItalic
      pos += 1
    else:
      # Properly handle UTF-8 multi-byte characters
      let b = expandedText[pos].ord
      var charLen = 1
      var ch = ""
      
      if (b and 0x80) == 0:
        ch = $expandedText[pos]
      elif (b and 0xE0) == 0xC0 and pos + 1 < expandedText.len:
        ch = expandedText[pos..pos+1]
        charLen = 2
      elif (b and 0xF0) == 0xE0 and pos + 2 < expandedText.len:
        ch = expandedText[pos..pos+2]
        charLen = 3
      elif (b and 0xF8) == 0xF0 and pos + 3 < expandedText.len:
        ch = expandedText[pos..pos+3]
        charLen = 4
      else:
        ch = "?"
      
      var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: isBold, 
                       underline: baseStyle.underline, italic: isItalic, dim: baseStyle.dim)
      buffer.writeText(currentX, y, ch, style)
      currentX += 1
      pos += charLen
  
  return currentX - x

proc renderTextWithLinks(text: string, x, y: int, maxWidth: int,
                        buffer: var TermBuffer, isCurrent: bool, 
                        startLinkIdx: int,
                        styleSheet: StyleSheet = initTable[string, StyleConfig](),
                        bodyStyle: Style): seq[Link] =
  ## Render text with clickable links
  ## Returns list of rendered links
  result = @[]
  
  # Get link styles from stylesheet or use defaults
  let linkStyle = if styleSheet.hasKey("link"):
                    toStyle(styleSheet["link"])
                  else:
                    Style(fg: ansiToColor(34), bg: black(), bold: false, underline: true, italic: false, dim: false)
  
  let linkFocusedStyle = if styleSheet.hasKey("link_focused"):
                           toStyle(styleSheet["link_focused"])
                         else:
                           Style(fg: ansiToColor(33), bg: black(), bold: true, underline: true, italic: false, dim: false)
  
  var currentX = x
  var pos = 0
  var globalLinkIdx = startLinkIdx
  
  while pos < text.len:
    # Check if we're inside a backtick (inline code) - if so, skip it
    if text[pos] == '`':
      # Find closing backtick
      let codeStart = pos
      var codeEnd = pos + 1
      while codeEnd < text.len and text[codeEnd] != '`':
        codeEnd += 1
      
      if codeEnd < text.len:
        # Found closing backtick - render entire backticked content as literal text
        let codeContent = text[codeStart .. codeEnd]  # Include both backticks
        let charsRendered = renderInlineMarkdown(codeContent, currentX, y,
                                                maxWidth - (currentX - x),
                                                buffer, bodyStyle)
        currentX += charsRendered
        pos = codeEnd + 1
        continue
    
    # Find next link using simple string search
    let linkStart = text.find("[", pos)
    
    if linkStart >= 0 and linkStart < text.len:
      
      # Render text before link
      if linkStart > pos:
        let beforeLink = text[pos..<linkStart]
        let charsRendered = renderInlineMarkdown(beforeLink, currentX, y, 
                                                maxWidth - (currentX - x), 
                                                buffer, bodyStyle)
        currentX += charsRendered
      
      # Extract link text and target
      var linkText = ""
      var target = ""
      var i = linkStart + 1  # Skip '['
      while i < text.len and text[i] != ']':
        linkText.add(text[i])
        i += 1
      i += 2  # Skip ']('
      while i < text.len and text[i] != ')':
        target.add(text[i])
        i += 1
      
      # Check if target section is removed
      let targetSection = findSectionByReference(target)
      let shouldRenderLink = targetSection.section.id == "" or 
                            not isRemoved(targetSection.section.title)
      
      if shouldRenderLink and isCurrent:
        # Render as active link
        let isFocused = (globalLinkIdx == canvasState.focusedLinkIdx)
        let styleToUse = if isFocused: linkFocusedStyle else: linkStyle
        
        result.add(Link(
          text: linkText,
          target: target,
          screenX: currentX,
          screenY: y,
          width: linkText.len,
          index: globalLinkIdx
        ))
        
        # Render link text
        for ch in linkText:
          if currentX < x + maxWidth:
            buffer.writeText(currentX, y, $ch, styleToUse)
            currentX += 1
        
        globalLinkIdx += 1
      else:
        # Render as plain text (dimmed)
        var dimStyle = bodyStyle
        dimStyle.dim = true
        let charsRendered = renderInlineMarkdown(linkText, currentX, y,
                                                maxWidth - (currentX - x),
                                                buffer, dimStyle)
        currentX += charsRendered
      
      pos = i + 1
    else:
      # No more links, render remaining text
      let remaining = text[pos..^1]
      if remaining.len > 0:
        discard renderInlineMarkdown(remaining, currentX, y,
                                    maxWidth - (currentX - x),
                                    buffer, bodyStyle)
      break

proc getSectionRawContent(section: Section): string =
  ## Extract raw text content from a section's blocks
  ## Code blocks with on:render or on:enter lifecycle are replaced with content buffer markers
  var lines: seq[string] = @[]
  
  for blk in section.blocks:
    case blk.kind
    of TextBlock:
      lines.add(blk.text)
    of HeadingBlock:
      # Include all headings
      lines.add("#".repeat(blk.level) & " " & blk.title)
    of CodeBlock_Content:
      # Insert marker for code blocks that generate content (on:render or on:enter)
      if blk.codeBlock.lifecycle in ["render", "enter"]:
        lines.add("{{CONTENT_BUFFER}}")
      # Skip other code blocks in content rendering
  
  return lines.join("\n")

proc hasLinksOutsideBackticks(text: string): bool =
  ## Check if text contains link syntax [...](...)  that is NOT inside backticks
  var pos = 0
  while pos < text.len:
    # Skip over backtick sections
    if text[pos] == '`':
      # Find closing backtick
      pos += 1
      while pos < text.len and text[pos] != '`':
        pos += 1
      if pos < text.len:
        pos += 1  # Skip closing backtick
      continue
    
    # Check for link pattern outside backticks
    if text[pos] == '[':
      # Look for complete link pattern
      var j = pos + 1
      while j < text.len and text[j] != ']':
        j += 1
      if j + 1 < text.len and text[j] == ']' and text[j + 1] == '(':
        return true  # Found link outside backticks
    
    pos += 1
  
  return false

proc renderSection(layout: SectionLayout, screenX, screenY: int,
                  buffer: var TermBuffer, isCurrent: bool,
                  styleSheet: StyleSheet = initTable[string, StyleConfig]()): seq[Link] =
  ## Render a single section to the buffer
  ## Returns list of links found in the section
  result = @[]
  
  # Skip removed sections
  if isRemoved(layout.section.title):
    return
  
  # Get styles from stylesheet or use defaults
  let headingStyle = if styleSheet.hasKey("heading"):
                       toStyle(styleSheet["heading"])
                     else:
                       Style(fg: ansiToColor(33), bg: black(), bold: true, underline: false, italic: false, dim: false)
  
  let bodyStyle = if styleSheet.hasKey("body"):
                    toStyle(styleSheet["body"])
                  else:
                    Style(fg: ansiToColor(37), bg: black(), bold: false, underline: false, italic: false, dim: false)
  
  let placeholderStyle = if styleSheet.hasKey("placeholder"):
                           toStyle(styleSheet["placeholder"])
                         else:
                           Style(fg: ansiToColor(30), bg: black(), bold: true, underline: false, italic: false, dim: false)
  
  # If hidden and not current, show placeholder
  if isHidden(layout.section.title) and not isCurrent:
    let placeholder = "???"
    let centerX = screenX + (layout.width - placeholder.len) div 2
    let centerY = screenY + layout.height div 2
    buffer.writeText(centerX, centerY, placeholder, placeholderStyle)
    return
  
  # Get raw content and preprocess to filter removed section links
  let rawContent = getSectionRawContent(layout.section)
  let processedContent = filterRemovedSectionLinks(rawContent)
  
  var contentY = screenY
  let contentX = screenX
  let maxContentWidth = layout.width
  var currentLinkIdx = 0  # Track link index across all lines
  
  # Render each line
  for line in processedContent.splitLines():
    if contentY >= screenY + layout.height:
      break
    
    # Check for content buffer marker
    if line.strip() == "{{CONTENT_BUFFER}}":
      # Render content buffer if this section has content
      if not canvasState.isNil and canvasState.contentBuffers.hasKey(layout.section.title):
        let sectionBuffer = canvasState.contentBuffers[layout.section.title]
        for bufferLine in sectionBuffer:
          if contentY >= screenY + layout.height:
            break
          
          # Process each buffer line the same way as regular content
          if bufferLine.startsWith("#"):
            # Heading
            let formatted = formatHeading(bufferLine)
            let displayText = if formatted.len > maxContentWidth: 
                                formatted[0..<maxContentWidth] 
                              else: 
                                formatted
            buffer.writeText(contentX, contentY, displayText, headingStyle)
          elif hasLinksOutsideBackticks(bufferLine):
            # Line with links
            let links = renderTextWithLinks(bufferLine, contentX, contentY, maxContentWidth,
                                           buffer, isCurrent, currentLinkIdx, styleSheet, bodyStyle)
            result.add(links)
            currentLinkIdx += links.len
          elif "**" in bufferLine or "*" in bufferLine:
            # Line with markdown formatting
            let wrapped = wrapText(bufferLine, maxContentWidth)
            for wLine in wrapped:
              if contentY >= screenY + layout.height:
                break
              discard renderInlineMarkdown(wLine, contentX, contentY, maxContentWidth,
                                          buffer, bodyStyle)
              contentY += 1
            contentY -= 1
          else:
            # Plain text
            let wrapped = wrapText(bufferLine, maxContentWidth)
            for wLine in wrapped:
              if contentY >= screenY + layout.height:
                break
              buffer.writeText(contentX, contentY, wLine, bodyStyle)
              contentY += 1
            contentY -= 1
          
          contentY += 1
      # Continue to next line (don't render the marker itself)
      continue
    
    # Check line type
    if line.startsWith("#"):
      # Heading
      let formatted = formatHeading(line)
      let displayText = if formatted.len > maxContentWidth: 
                          formatted[0..<maxContentWidth] 
                        else: 
                          formatted
      buffer.writeText(contentX, contentY, displayText, headingStyle)
    elif hasLinksOutsideBackticks(line):
      # Line with links (but not inside backticks)
      let links = renderTextWithLinks(line, contentX, contentY, maxContentWidth,
                                     buffer, isCurrent, currentLinkIdx, styleSheet, bodyStyle)
      result.add(links)
      currentLinkIdx += links.len  # Update index for next line with links
    elif "**" in line or "*" in line:
      # Line with markdown formatting - wrap it first
      let wrapped = wrapText(line, maxContentWidth)
      for wLine in wrapped:
        if contentY >= screenY + layout.height:
          break
        discard renderInlineMarkdown(wLine, contentX, contentY, maxContentWidth,
                                    buffer, bodyStyle)
        contentY += 1
      contentY -= 1  # Adjust for the increment below
    else:
      # Plain text - wrap it
      let wrapped = wrapText(line, maxContentWidth)
      for wLine in wrapped:
        if contentY >= screenY + layout.height:
          break
        buffer.writeText(contentX, contentY, wLine, bodyStyle)
        contentY += 1
      contentY -= 1  # Adjust for the increment below
    
    contentY += 1

proc canvasRender*(buffer: var TermBuffer, viewportWidth, viewportHeight: int,
                  styleSheet: StyleSheet = initTable[string, StyleConfig]()) =
  ## Main canvas rendering function
  if canvasState.isNil:
    return
  
  # Get background color from stylesheet, defaulting to black if not set
  let bgColor = if styleSheet.hasKey("body"):
                  styleSheet["body"].bg
                else:
                  (0'u8, 0'u8, 0'u8)
  
  # Clear the entire buffer to ensure clean rendering during animations
  buffer.clear(bgColor)
  
  # Copy parameters to local variables to avoid any potential shadowing issues
  let vw = viewportWidth
  let vh = viewportHeight
  
  setViewport(vw, vh)
  
  # Check if viewport size has changed
  let viewportChanged = (canvasState.lastViewportWidth != vw or 
                        canvasState.lastViewportHeight != vh)
  
  # Center camera on current section on first render or viewport resize
  if (canvasState.camera.targetX == 0.0 and canvasState.camera.targetY == 0.0) or viewportChanged:
    centerOnSection(canvasState.currentSectionIdx, vw, vh)
    # Snap camera immediately on first render (no animation for initial position)
    if canvasState.lastViewportWidth == 0:
      canvasState.camera.x = canvasState.camera.targetX
      canvasState.camera.y = canvasState.camera.targetY
    # Store current viewport size
    canvasState.lastViewportWidth = vw
    canvasState.lastViewportHeight = vh
  
  # Update current section as visited
  if canvasState.currentSectionIdx >= 0 and 
     canvasState.currentSectionIdx < canvasState.sections.len:
    let currentSection = canvasState.sections[canvasState.currentSectionIdx]
    markVisited(currentSection.section.title)
  
  # Clear links for current frame
  canvasState.links = @[]
  
  # Get camera position
  let cameraX = int(canvasState.camera.x)
  let cameraY = int(canvasState.camera.y)
  
  var renderedCount = 0
  var removedCount = 0
  # Render all visible sections
  for i, layout in canvasState.sections:
    if isRemoved(layout.section.title):
      removedCount += 1
      continue
    
    let screenX = layout.x - cameraX
    let screenY = layout.y - cameraY
    
    # TODO: Fix culling logic - temporarily disabled
    # Cull offscreen sections  
    #if screenX + layout.width < 0 or screenX >= vw or
    #   screenY + layout.height < 0 or not (screenY < vh):
    #  culledCount += 1
    #  continue
    
    renderedCount += 1
    let isCurrent = (layout.index == canvasState.currentSectionIdx)
    let links = renderSection(layout, screenX, screenY, buffer, isCurrent, styleSheet)
    
    if isCurrent:
      canvasState.links = links

proc canvasUpdate*(deltaTime: float) =
  ## Update canvas animations
  if canvasState.isNil:
    return
  
  updateCamera(deltaTime, gViewportWidth, gViewportHeight)

proc canvasHandleKey*(keyCode: int, mods: set[uint8]): bool =
  ## Handle keyboard input
  ## Returns true if event was consumed
  if canvasState.isNil:
    return false
  
  # Arrow keys and Tab for link navigation
  const INPUT_UP = 1000
  const INPUT_DOWN = 1001
  const INPUT_LEFT = 1002
  const INPUT_RIGHT = 1003
  const INPUT_TAB = 9
  const INPUT_ENTER = 13
  
  # PRESENTATION MODE: Arrow keys navigate sections by heading level
  if canvasState.presentationMode:
    case keyCode
    of INPUT_LEFT:
      # Navigate to previous main heading (level 1)
      let prevIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, 1, false)
      if prevIdx >= 0:
        navigateToSection(prevIdx)
        return true
    
    of INPUT_RIGHT:
      # Navigate to next main heading (level 1)
      let nextIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, 1, true)
      if nextIdx >= 0:
        navigateToSection(nextIdx)
        return true
    
    of INPUT_UP:
      # Navigate to previous sub-heading (level 2+)
      # Try level 2 first, then 3, etc.
      for level in 2..6:
        let prevIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, level, false)
        if prevIdx >= 0:
          navigateToSection(prevIdx)
          return true
      return false
    
    of INPUT_DOWN:
      # Navigate to next sub-heading (level 2+)
      for level in 2..6:
        let nextIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, level, true)
        if nextIdx >= 0:
          navigateToSection(nextIdx)
          return true
      return false
    
    else:
      return false
  
  # DEFAULT MODE: Arrow keys and Tab navigate links (interactive fiction)
  else:
    case keyCode
    of INPUT_TAB, INPUT_RIGHT, INPUT_DOWN:
      # Cycle to next link
      if canvasState.links.len > 0:
        canvasState.focusedLinkIdx = (canvasState.focusedLinkIdx + 1) mod canvasState.links.len
        return true
    
    of INPUT_LEFT, INPUT_UP:
      # Cycle to previous link
      if canvasState.links.len > 0:
        canvasState.focusedLinkIdx = (canvasState.focusedLinkIdx - 1 + canvasState.links.len) mod canvasState.links.len
        return true
    
    of INPUT_ENTER:
      # Follow focused link
      if canvasState.links.len > 0 and canvasState.focusedLinkIdx < canvasState.links.len:
        let link = canvasState.links[canvasState.focusedLinkIdx]
        let targetSection = findSectionByReference(link.target)
        if targetSection.section.id != "":
          navigateToSection(targetSection.index)
          return true
    
    of ord('1')..ord('9'):
      # Quick jump to link by number
      let linkNum = keyCode - ord('1')
      if linkNum < canvasState.links.len:
        let link = canvasState.links[linkNum]
        let targetSection = findSectionByReference(link.target)
        if targetSection.section.id != "":
          navigateToSection(targetSection.index)
          return true
    
    else:
      discard
  
  return false

proc canvasHandleMouse*(mouseX, mouseY: int, button: int, isDown: bool): bool =
  ## Handle mouse input
  ## Returns true if event was consumed
  if canvasState.isNil:
    return false
  
  # Only handle left mouse button clicks (mouse down events)
  if button != 0 or not isDown:
    return false
  
  # PRESENTATION MODE: Screen-region navigation
  if canvasState.presentationMode:
    # Divide screen into left and right halves
    let halfWidth = gViewportWidth div 2
    
    if mouseX < halfWidth:
      # Left side clicked - go to previous main heading
      let prevIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, 1, false)
      if prevIdx >= 0:
        navigateToSection(prevIdx)
        return true
    else:
      # Right side clicked - go to next main heading
      let nextIdx = getNextSectionAtLevel(canvasState.currentSectionIdx, 1, true)
      if nextIdx >= 0:
        navigateToSection(nextIdx)
        return true
    
    return false
  
  # DEFAULT MODE: Click on links to navigate
  else:
    # Check if mouse click is on any visible link
    for link in canvasState.links:
      if mouseX >= link.screenX and mouseX < link.screenX + link.width and
         mouseY == link.screenY:
        # Mouse clicked on this link - follow it
        let targetSection = findSectionByReference(link.target)
        if targetSection.section.id != "":
          navigateToSection(targetSection.index)
          return true
  
  return false

proc getSectionCount*(): int =
  ## Get the number of sections in the canvas
  if canvasState.isNil:
    return 0
  return canvasState.sections.len

# ================================================================
# NIMINI BINDINGS
# ================================================================

# Global references needed by nimini wrappers (set by registerCanvasBindings)
var gCanvasBuffer: ptr TermBuffer
var gCanvasAppState: ptr AppState
var gCanvasStyleSheet: ptr StyleSheet

# Helper to convert Value to int (handles both int and float values)
# This may be duplicated in including contexts but that's okay for private helpers
proc canvasValueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

# Note: nimini_initCanvas is defined in index.nim since it needs access to storieCtx

proc nimini_contentWrite*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Write a line to the content buffer for the current section. Args: text (string)
  ## Content buffer is rendered as part of the current section only
  if args.len > 0 and args[0].kind == vkString:
    if not canvasState.isNil and canvasState.currentSectionIdx >= 0 and 
       canvasState.currentSectionIdx < canvasState.sections.len:
      let sectionTitle = canvasState.sections[canvasState.currentSectionIdx].section.title
      if not canvasState.contentBuffers.hasKey(sectionTitle):
        canvasState.contentBuffers[sectionTitle] = @[]
      canvasState.contentBuffers[sectionTitle].add(args[0].s)
  return valNil()

proc nimini_contentClear*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear the content buffer for the current section
  if not canvasState.isNil and canvasState.currentSectionIdx >= 0 and 
     canvasState.currentSectionIdx < canvasState.sections.len:
    let sectionTitle = canvasState.sections[canvasState.currentSectionIdx].section.title
    canvasState.contentBuffers[sectionTitle] = @[]
  return valNil()

proc nimini_hideSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Hide a section by reference. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  hideSection(args[0].s)
  return valNil()

proc nimini_removeSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Remove a section from display. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  removeSection(args[0].s)
  return valNil()
# Test function for TUI
proc nimini_tuiTestInCanvas(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Test if canvas location works for TUI functions
  return valString("TUI test from canvas.nim works!")
proc nimini_restoreSection*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Restore a removed section. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  restoreSection(args[0].s)
  return valNil()

proc nimini_isVisited*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Check if a section has been visited. Args: sectionRef (string)
  if args.len == 0:
    return valBool(false)
  return valBool(isVisited(args[0].s))

proc nimini_markVisited*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Manually mark a section as visited. Args: sectionRef (string)
  if args.len == 0:
    return valNil()
  markVisited(args[0].s)
  return valNil()

proc nimini_canvasRender*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render the canvas system. No args needed (uses global buffers)
  if not gCanvasAppState.isNil and not gCanvasBuffer.isNil:
    gNiminiEnv = cast[pointer](env)  # Store env for variable expansion during rendering
    let styleSheet = if not gCanvasStyleSheet.isNil: gCanvasStyleSheet[]
                     else: initTable[string, StyleConfig]()
    canvasRender(gCanvasBuffer[], gCanvasAppState.termWidth, gCanvasAppState.termHeight, styleSheet)
  return valNil()

proc nimini_canvasUpdate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update canvas animations. Args: deltaTime (float)
  let deltaTime = if args.len > 0:
    (if args[0].kind == vkFloat: args[0].f else: float(args[0].i))
  else:
    0.016 # Default ~60fps
  canvasUpdate(deltaTime)
  return valNil()

proc nimini_canvasHandleKey*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle keyboard input for canvas. Args: keyCode (int), mods (int, optional)
  ## Returns: bool (true if handled)
  if args.len == 0:
    return valBool(false)
  let keyCode = canvasValueToInt(args[0])
  let mods = if args.len > 1: canvasValueToInt(args[1]) else: 0
  # Convert int to set[uint8] - simplified for common cases
  var modSet: set[uint8] = {}
  if (mods and 1) != 0: modSet.incl(0'u8)  # Shift
  if (mods and 2) != 0: modSet.incl(1'u8)  # Ctrl
  if (mods and 4) != 0: modSet.incl(2'u8)  # Alt
  return valBool(canvasHandleKey(keyCode, modSet))

proc nimini_canvasHandleMouse*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse input for canvas. Args: x (int), y (int), button (int), isDown (bool)
  ## Returns: bool (true if handled)
  if args.len < 4:
    return valBool(false)
  let x = canvasValueToInt(args[0])
  let y = canvasValueToInt(args[1])
  let button = canvasValueToInt(args[2])
  let isDown = if args[3].kind == vkBool: args[3].b else: (canvasValueToInt(args[3]) != 0)
  return valBool(canvasHandleMouse(x, y, button, isDown))

proc registerCanvasBindings*(buffer: ptr TermBuffer, appState: ptr AppState, 
                            styleSheet: ptr StyleSheet) =
  ## Register canvas bindings with the nimini runtime
  ## Call this during initialization after creating the nimini context
  gCanvasBuffer = buffer
  gCanvasAppState = appState
  gCanvasStyleSheet = styleSheet
  
  # Export all nimini wrapper functions
  exportNiminiProcs(
    nimini_hideSection, nimini_removeSection, nimini_restoreSection,
    nimini_isVisited, nimini_markVisited, nimini_canvasRender, 
    nimini_canvasUpdate, nimini_canvasHandleKey, nimini_canvasHandleMouse
  )
  
  # Register content buffer functions with simple names
  registerNative("contentWrite", nimini_contentWrite)
  registerNative("contentClear", nimini_contentClear)

# Export rendering functions
export canvasRender, canvasUpdate, canvasHandleKey, canvasHandleMouse, getSectionCount
export registerCanvasBindings, setExecuteCallback, ExecuteCodeBlockCallback
