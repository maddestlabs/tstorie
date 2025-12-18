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

# Global canvas state
var canvasState*: CanvasState

# ================================================================
# SECTION STATE MANAGEMENT
# ================================================================

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
  
  let t = min(1.0, deltaTime * SMOOTH_SPEED)
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
  ## Initialize the canvas system
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
    lastRenderTime: 0.0
  )
  
  # Initialize section visibility from metadata
  for layout in canvasState.sections:
    if layout.section.metadata.hasKey("hidden"):
      if layout.section.metadata["hidden"].toLowerAscii() in ["true", "yes", "1"]:
        hideSection(layout.section.title)
  
  # Mark starting section as visited
  if currentIdx >= 0 and currentIdx < sections.len:
    markVisited(sections[currentIdx].title)

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
