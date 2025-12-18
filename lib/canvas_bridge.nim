## Canvas Nimini Bridge - Canvas functions for Nimini scripts
## Provides rendering, interaction, and navigation for interactive fiction

import std/[tables, strutils, times, math]
import ../lib/canvas
import ../lib/storie_md
import ../lib/layout

# ================================================================
# RENDERING STATE
# ================================================================

# Note: We don't store buffer reference with type because TermBuffer
# is defined in tstorie.nim and not accessible to this imported module.
# Instead, buffer is passed as parameter to all render functions.

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

var
  gViewportWidth: int
  gViewportHeight: int
  gViewportChanged: bool = false
  gGetAllSections: proc(): seq[Section]
  gGetCurrentSection: proc(): Section
  gGotoSection: proc(idx: int): bool
  gSetMultiSectionMode: proc(enabled: bool)
  gEnableMouse: proc()
  gDisableMouse: proc()

# ================================================================
# VIEWPORT MANAGEMENT
# ================================================================

proc setViewport*(width, height: int) =
  ## Set viewport dimensions
  if gViewportWidth != width or gViewportHeight != height:
    gViewportWidth = width
    gViewportHeight = height
    gViewportChanged = true

proc resetViewportChanged*() =
  gViewportChanged = false

# ================================================================
# LINK RENDERING
# ================================================================

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
                        buffer: var TermBuffer, isCurrent: bool): seq[Link] =
  ## Render text with clickable links
  ## Returns list of rendered links
  result = @[]
  var currentX = x
  var pos = 0
  var globalLinkIdx = 1
  
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
                                     buffer, isCurrent)
      result.add(links)
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

# ================================================================
# GLOBAL RENDER HANDLER
# ================================================================

proc canvasRender*(buffer: var TermBuffer, viewportWidth, viewportHeight: int) =
  ## Main canvas rendering function
  if canvasState.isNil:
    return
  
  setViewport(viewportWidth, viewportHeight)
  
  buffer.clear()
  
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
  
  # Render all visible sections
  for layout in canvasState.sections:
    if isRemoved(layout.section.title):
      continue
    
    let screenX = layout.x - cameraX
    let screenY = layout.y - cameraY
    
    # Cull offscreen sections
    if screenX + layout.width < 0 or screenX >= viewportWidth or
       screenY + layout.height < 0 or screenY >= viewportHeight:
      continue
    
    let isCurrent = (layout.index == canvasState.currentSectionIdx)
    let links = renderSection(layout, screenX, screenY, buffer, isCurrent)
    
    if isCurrent:
      canvasState.links = links
  
  # Render status bar
  let statusY = viewportHeight - 1
  if statusY >= 0 and canvasState.currentSectionIdx >= 0 and
     canvasState.currentSectionIdx < canvasState.sections.len:
    let currentSection = canvasState.sections[canvasState.currentSectionIdx]
    let linkInfo = if canvasState.links.len > 0:
                     " | Arrows/Tab: cycle links (" & $canvasState.links.len & ") | Enter: follow"
                   else:
                     ""
    var status = " " & currentSection.section.title & linkInfo & " | 1-9: jump | Q: quit "
    if status.len > viewportWidth:
      status = status[0..<viewportWidth]
    
    var style = Style(fg: ansiToColor(30), bg: black(), bold: false, underline: false, italic: false)
    buffer.write(0, statusY, status, style)
  
  resetViewportChanged()

# ================================================================
# GLOBAL UPDATE HANDLER
# ================================================================

proc canvasUpdate*(deltaTime: float) =
  ## Update camera animation
  if canvasState.isNil:
    return
  
  updateCamera(deltaTime, gViewportWidth, gViewportHeight)
  
  # Handle pending section removals
  var currentSection = if canvasState.currentSectionIdx >= 0 and 
                         canvasState.currentSectionIdx < canvasState.sections.len:
                        canvasState.sections[canvasState.currentSectionIdx]
                       else:
                        SectionLayout()
  
  for layout in canvasState.sections:
    if layout.section.metadata.hasKey("removeAfterVisit"):
      if layout.section.metadata["removeAfterVisit"].toLowerAscii() in ["true", "yes", "1"]:
        if layout.index != canvasState.currentSectionIdx:
          if isVisited(layout.section.title):
            removeSection(layout.section.title)

# ================================================================
# INPUT HANDLERS
# ================================================================

proc navigateToLink(link: Link) =
  ## Navigate to the target of a link
  let targetLayout = findSectionByReference(link.target)
  if targetLayout.section.id != "":
    # Navigate using the global goto function
    if not gGotoSection.isNil:
      discard gGotoSection(targetLayout.index)
    
    canvasState.currentSectionIdx = targetLayout.index
    centerOnSection(canvasState.currentSectionIdx, gViewportWidth, gViewportHeight)
    canvasState.focusedLinkIdx = 0
    
    # Mark as visited
    markVisited(targetLayout.section.title)

proc canvasHandleKey*(keyCode: int, mods: set[uint8]): bool =
  ## Handle keyboard input
  ## Returns true if event was consumed
  if canvasState.isNil:
    return false
  
  # Enter - follow focused link
  if keyCode == 13:  # Enter
    if canvasState.focusedLinkIdx > 0 and 
       canvasState.focusedLinkIdx <= canvasState.links.len:
      navigateToLink(canvasState.links[canvasState.focusedLinkIdx - 1])
      return true
  
  # Tab - cycle through links
  elif keyCode == 9:  # Tab
    if canvasState.links.len > 0:
      canvasState.focusedLinkIdx = (canvasState.focusedLinkIdx mod canvasState.links.len) + 1
      return true
  
  # Arrow keys - navigate links
  elif keyCode == 1001:  # Down
    if canvasState.links.len > 0:
      canvasState.focusedLinkIdx = (canvasState.focusedLinkIdx mod canvasState.links.len) + 1
      return true
  
  elif keyCode == 1000:  # Up
    if canvasState.links.len > 0:
      canvasState.focusedLinkIdx -= 1
      if canvasState.focusedLinkIdx < 1:
        canvasState.focusedLinkIdx = canvasState.links.len
      return true
  
  # Number keys - jump to section
  elif keyCode >= 49 and keyCode <= 57:  # '1' to '9'
    let sectionIdx = keyCode - 49
    if sectionIdx < canvasState.sections.len:
      if not gGotoSection.isNil:
        discard gGotoSection(sectionIdx)
      canvasState.currentSectionIdx = sectionIdx
      centerOnSection(sectionIdx, gViewportWidth, gViewportHeight)
      canvasState.focusedLinkIdx = 0
      return true
  
  # Q - quit (let caller handle)
  elif keyCode == 113 or keyCode == 81:  # 'q' or 'Q'
    return false
  
  return false

proc canvasHandleMouse*(mouseX, mouseY: int, button: int, isDown: bool): bool =
  ## Handle mouse input
  ## Returns true if event was consumed
  if canvasState.isNil or not canvasState.mouseEnabled:
    return false
  
  if isDown:
    # Check if clicking on a link
    for link in canvasState.links:
      if mouseX >= link.screenX and mouseX < link.screenX + link.width and
         mouseY == link.screenY:
        navigateToLink(link)
        return true
  else:
    # Mouse move - update focused link
    var oldFocus = canvasState.focusedLinkIdx
    canvasState.focusedLinkIdx = 0
    
    for link in canvasState.links:
      if mouseX >= link.screenX and mouseX < link.screenX + link.width and
         mouseY == link.screenY:
        canvasState.focusedLinkIdx = link.index
        break
  
  return false

# ================================================================
# INITIALIZATION
# ================================================================

proc setGlobalCallbacks*(getAllSections: proc(): seq[Section],
                        getCurrentSection: proc(): Section,
                        gotoSection: proc(idx: int): bool,
                        setMultiSectionMode: proc(enabled: bool),
                        enableMouse: proc(),
                        disableMouse: proc()) =
  ## Set global callback functions
  gGetAllSections = getAllSections
  gGetCurrentSection = getCurrentSection
  gGotoSection = gotoSection
  gSetMultiSectionMode = setMultiSectionMode
  gEnableMouse = enableMouse
  gDisableMouse = disableMouse

proc initCanvasSystem*(buffer: var TermBuffer, viewportWidth, viewportHeight: int,
                      getAllSections: proc(): seq[Section],
                      getCurrentSection: proc(): Section) =
  ## Initialize canvas with current document sections
  setViewport(viewportWidth, viewportHeight)
  
  let sections = getAllSections()
  let current = getCurrentSection()
  var currentIdx = 0
  
  for i, section in sections:
    if section.id == current.id:
      currentIdx = i
      break
  
  initCanvas(sections, currentIdx)
  centerOnSection(currentIdx, viewportWidth, viewportHeight)
  
  # Snap camera immediately
  canvasState.camera.x = canvasState.camera.targetX
  canvasState.camera.y = canvasState.camera.targetY

# ================================================================
# EXPORTS
# ================================================================

export canvasRender, canvasUpdate, canvasHandleKey, canvasHandleMouse
export setGlobalCallbacks, initCanvasSystem
export setViewport, resetViewportChanged
