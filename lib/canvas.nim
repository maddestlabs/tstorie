## Canvas Navigation System for TStorie
## Provides spatial layout, smooth camera panning, and interactive navigation
## Compatible with Nimini code blocks

import std/[tables, strutils, sequtils, math, sets, sugar, algorithm]
import ../lib/storie_md
import ../lib/layout

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
    lastRenderTime*: float
    lastViewportWidth*: int
    lastViewportHeight*: int

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

proc navigateToSection*(sectionIdx: int) =
  ## Navigate to a section by index
  if canvasState.isNil or sectionIdx < 0 or sectionIdx >= canvasState.sections.len:
    return
  
  canvasState.currentSectionIdx = sectionIdx
  canvasState.focusedLinkIdx = 0
  
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
  canvasState.camera.targetX = float(section.x + section.width div 2 - viewportWidth div 2)
  canvasState.camera.targetY = float(section.y + section.height div 2 - viewportHeight div 2)

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

proc initCanvas*(sections: seq[Section], currentIdx: int = 0) =
  ## Initialize the canvas system (idempotent - only initializes if not already done)
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
    lastRenderTime: 0.0,
    lastViewportWidth: 0,
    lastViewportHeight: 0
  )
  
  # Initialize section visibility from metadata
  for layout in canvasState.sections:
    if layout.section.metadata.hasKey("hidden"):
      if layout.section.metadata["hidden"].toLowerAscii() in ["true", "yes", "1"]:
        hideSection(layout.section.title)
  
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

# ================================================================
# PUBLIC API EXPORTS
# ================================================================

# Re-export key functions
export isVisited, markVisited, isHidden, hideSection
export isRemoved, removeSection, restoreSection
export findSectionByReference, navigateToSection
export parseLinks, filterRemovedSectionLinks
export updateCamera, centerOnSection
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
                         buffer: var TermBuffer, baseColor: int, baseBold: bool): int =
  ## Render text with inline markdown formatting (bold **, italic *)
  ## Returns number of characters rendered
  var currentX = x
  var pos = 0
  var isBold = baseBold
  var isItalic = false
  
  while pos < text.len and currentX < x + maxWidth:
    # Check for **bold**
    if pos + 1 < text.len and text[pos..pos+1] == "**":
      isBold = not isBold
      pos += 2
    # Check for *italic*
    elif text[pos] == '*':
      isItalic = not isItalic
      pos += 1
    else:
      let ch = $text[pos]
      var style = Style(fg: ansiToColor(baseColor), bg: black(), bold: isBold, 
                       underline: false, italic: isItalic)
      buffer.write(currentX, y, ch, style)
      currentX += 1
      pos += 1
  
  return currentX - x

proc renderTextWithLinks(text: string, x, y: int, maxWidth: int,
                        buffer: var TermBuffer, isCurrent: bool, 
                        startLinkIdx: int): seq[Link] =
  ## Render text with clickable links
  ## Returns list of rendered links
  result = @[]
  var currentX = x
  var pos = 0
  var globalLinkIdx = startLinkIdx
  
  while pos < text.len:
    # Find next link using simple string search
    let linkStart = text.find("[", pos)
    
    if linkStart >= 0 and linkStart < text.len:
      
      # Render text before link
      if linkStart > pos:
        let beforeLink = text[pos..<linkStart]
        let charsRendered = renderInlineMarkdown(beforeLink, currentX, y, 
                                                maxWidth - (currentX - x), 
                                                buffer, 37, false)
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
        let linkColor = if isFocused: 33 else: 34  # Yellow or blue
        let linkBold = isFocused
        
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
            var style = Style(fg: ansiToColor(linkColor), bg: black(), bold: linkBold,
                            underline: true, italic: false)
            buffer.write(currentX, y, $ch, style)
            currentX += 1
        
        globalLinkIdx += 1
      else:
        # Render as plain text (dimmed)
        let charsRendered = renderInlineMarkdown(linkText, currentX, y,
                                                maxWidth - (currentX - x),
                                                buffer, 30, false)
        currentX += charsRendered
      
      pos = i + 1
    else:
      # No more links, render remaining text
      let remaining = text[pos..^1]
      if remaining.len > 0:
        discard renderInlineMarkdown(remaining, currentX, y,
                                    maxWidth - (currentX - x),
                                    buffer, 37, false)
      break

proc getSectionRawContent(section: Section): string =
  ## Extract raw text content from a section's blocks
  var lines: seq[string] = @[]
  
  for blk in section.blocks:
    case blk.kind
    of TextBlock:
      lines.add(blk.text)
    of HeadingBlock:
      lines.add("#".repeat(blk.level) & " " & blk.title)
    of CodeBlock_Content:
      # Skip code blocks in content rendering
      discard
  
  return lines.join("\n")

proc renderSection(layout: SectionLayout, screenX, screenY: int,
                  buffer: var TermBuffer, isCurrent: bool): seq[Link] =
  ## Render a single section to the buffer
  ## Returns list of links found in the section
  result = @[]
  
  # Skip removed sections
  if isRemoved(layout.section.title):
    return
  
  # If hidden and not current, show placeholder
  if isHidden(layout.section.title) and not isCurrent:
    let placeholder = "???"
    let centerX = screenX + (layout.width - placeholder.len) div 2
    let centerY = screenY + layout.height div 2
    var style = Style(fg: ansiToColor(30), bg: black(), bold: true, underline: false, italic: false)
    buffer.write(centerX, centerY, placeholder, style)
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
    
    # Check line type
    if line.startsWith("#"):
      # Heading
      let formatted = formatHeading(line)
      let displayText = if formatted.len > maxContentWidth: 
                          formatted[0..<maxContentWidth] 
                        else: 
                          formatted
      var style = Style(fg: ansiToColor(33), bg: black(), bold: true, underline: false, italic: false)
      buffer.write(contentX, contentY, displayText, style)
    elif line.contains("[") and line.contains("]("):
      # Line with links
      let links = renderTextWithLinks(line, contentX, contentY, maxContentWidth,
                                     buffer, isCurrent, currentLinkIdx)
      result.add(links)
      currentLinkIdx += links.len  # Update index for next line with links
    elif "**" in line or "*" in line:
      # Line with markdown formatting
      discard renderInlineMarkdown(line, contentX, contentY, maxContentWidth,
                                  buffer, 37, false)
    else:
      # Plain text - wrap it
      let wrapped = wrapText(line, maxContentWidth)
      for wLine in wrapped:
        if contentY >= screenY + layout.height:
          break
        var style = Style(fg: ansiToColor(37), bg: black(), bold: false, underline: false, italic: false)
        buffer.write(contentX, contentY, wLine, style)
        contentY += 1
      contentY -= 1  # Adjust for the increment below
    
    contentY += 1

proc canvasRender*(buffer: var TermBuffer, viewportWidth, viewportHeight: int) =
  ## Main canvas rendering function
  if canvasState.isNil:
    return
  
  # Clear the entire buffer to ensure clean rendering during animations
  buffer.clear()
  
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
    let links = renderSection(layout, screenX, screenY, buffer, isCurrent)
    
    if isCurrent:
      canvasState.links = links
  
  # Render status bar
  let statusY = vh - 1
  if statusY >= 0 and canvasState.currentSectionIdx >= 0 and
     canvasState.currentSectionIdx < canvasState.sections.len:
    let currentSection = canvasState.sections[canvasState.currentSectionIdx]
    let linkInfo = if canvasState.links.len > 0:
                     " | Arrows/Tab: cycle links (" & $canvasState.links.len & ") | Enter: follow"
                   else:
                     ""
    var status = " " & currentSection.section.title & linkInfo & " | 1-9: jump | Q: quit "
    if status.len > vw:
      status = status[0..<vw]
    
    var style = Style(fg: ansiToColor(30), bg: black(), bold: false, underline: false, italic: false, dim: false)
    buffer.write(0, statusY, status, style)

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

# Export rendering functions
export canvasRender, canvasUpdate, canvasHandleKey, canvasHandleMouse, getSectionCount
