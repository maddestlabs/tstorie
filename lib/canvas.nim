## Canvas Navigation System for TStorie
## Provides spatial layout, smooth camera panning, and interactive navigation
## Compatible with Nimini code blocks
##
## Usage:
##   include lib/canvas  (current - shares namespace with tstorie.nim)
##   import lib/canvas   (future - proper module, call initCanvasModule)

# Import core types and functions when used as a module
when not declared(TermBuffer):
  # Imported as a module - need all dependencies
  import ../src/types
  import ../src/charwidth
  import ../src/layers  # For writeText, clear, etc.
else:
  # Included in tstorie.nim - charwidth imported via src/charwidth
  when not declared(getCharDisplayWidth):
    import src/charwidth

import std/[tables, strutils, sequtils, math, sets, sugar, algorithm]
import section_manager, ansi_parser

# Import nimini for binding registration
when not declared(exportNiminiProcs):
  import ../nimini

# Forward declare global for nimini environment (set during rendering)
var gNiminiEnv {.global.}: pointer = nil

# Global storage for parsed ANSI buffers (keyed by section ID + block index)
var gAnsiBuffers {.global.} = initTable[string, TermBuffer]()

# ================================================================
# IMPORT COMPATIBILITY: Use globals directly when included
# ================================================================
# When included: gAppState, storieCtx, gSectionMgr are in scope
# When imported: must call initCanvasModule() to set them up

# Helper to get current section index from section manager (source of truth)
proc getCurrentSectionIdx*(): int =
  ## Get current section index (works for both include and import)
  when declared(gSectionMgr):
    # Included mode - use global directly
    if not gSectionMgr.isNil:
      return gSectionMgr[].currentIndex
  return 0

# ================================================================
# CONFIGURATION CONSTANTS
# ================================================================

const
  SECTION_HEIGHT = 20
  SECTION_PADDING = 10
  MAX_SECTIONS_PER_ROW = 3
  PAN_SPEED = 5.0
  SMOOTH_SPEED = 8.0

# Section width can be overridden based on front matter minWidth
var gSectionWidth* = 60  # Default section width

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

# Global default style - can be overridden by setDefaultStyle()
var gDefaultStyleConfig* = StyleConfig(
  fg: (255'u8, 255'u8, 255'u8),
  bg: (0'u8, 0'u8, 0'u8),
  bold: false,
  italic: false,
  underline: false,
  dim: false
)

proc getDefaultStyleConfig*(): StyleConfig =
  ## Get default style configuration
  return gDefaultStyleConfig

proc setDefaultStyleConfig*(config: StyleConfig) =
  ## Set the global default style configuration
  gDefaultStyleConfig = config
  # Also update the types.nim global default Style
  setGlobalDefaultStyle(Style(
    fg: Color(r: config.fg.r, g: config.fg.g, b: config.fg.b),
    bg: Color(r: config.bg.r, g: config.bg.g, b: config.bg.b),
    bold: config.bold,
    italic: config.italic,
    underline: config.underline,
    dim: config.dim
  ))

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
  
  ContentBounds* = object
    ## Content area bounds for coordinate conversion
    x*, y*: int        # Top-left position of content area in terminal grid
    width*, height*: int  # Size of content area
  
  SectionLayout* = object
    section*: Section
    x*, y*: int
    width*, height*: int
    index*: int
    navigable*: bool  # Whether this section can be navigated to
    actualVisualWidth*: int  # Actual visual width of rendered content (accounting for double-width chars)
    actualVisualHeight*: int  # Actual height of rendered content in lines
    zIndex*: int  # Z-index for layer rendering (0 = default layer)
    layerName*: string  # Named layer to render to (empty = default)
  
  # Callback type for executing code blocks (lifecycle hooks)
  ExecuteCodeBlockCallback* = proc(codeBlock: CodeBlock, lifecycle: string): bool
  
  CanvasState* = ref object
    camera*: Camera
    sections*: seq[SectionLayout]
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
    frontMatter*: FrontMatter  # Document front matter for global settings like hideHeadings
    currentContentBounds*: ContentBounds  # Current section's content rendering bounds (for mouse coords)
    currentContentBufferBounds*: ContentBounds  # Content buffer area bounds (for games/dynamic content)
    # References needed by nimini wrappers (set by registerCanvasBindings)
    buffer*: ptr TermBuffer
    appState*: ptr AppState
    styleSheet*: ptr StyleSheet

# Global canvas state
var canvasState*: CanvasState

# Global viewport dimensions
var
  gViewportWidth: int
  gViewportHeight: int

# ================================================================
# MODULE INITIALIZATION (for import mode)
# ================================================================

proc initCanvasModule*(appState: ptr AppState, 
                      sectionMgr: ptr SectionManager,
                      styleSheet: ptr StyleSheet) =
  ## Initialize canvas when used as an imported module
  ## Call this after creating AppState and SectionManager
  ## Not needed when canvas is included in tstorie.nim
  ##
  ## Example:
  ##   import lib/canvas
  ##   var state = newAppState(80, 24)
  ##   var mgr = newSectionManager(sections)
  ##   initCanvasModule(addr state, addr mgr, addr stylesheet)
  when not declared(gAppState):
    # Store references in canvasState when imported (not included)
    if not canvasState.isNil:
      canvasState.appState = appState
      canvasState.styleSheet = styleSheet
    # Note: Section manager is accessed via global gSectionMgr when included
    # When imported, would need additional handling (future work)

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
  ## Supports both hyphen and underscore variants for backward compatibility
  if canvasState.isNil:
    return SectionLayout()
  
  var refStr = reference
  # Remove leading # if present
  if refStr.len > 0 and refStr[0] == '#':
    refStr = refStr[1..^1]
  
  let lowerRef = refStr.toLowerAscii()
  # Normalize reference for flexible matching (support both - and _)
  let normalizedRef = lowerRef.replace("_", "-")
  
  # Try exact title match first (most common)
  for layout in canvasState.sections:
    if layout.section.title == refStr:
      return layout
  
  # Try exact ID match (both original and normalized)
  for layout in canvasState.sections:
    if layout.section.id == refStr:
      return layout
    let normalizedId = layout.section.id.replace("_", "-")
    if normalizedId == normalizedRef:
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

type
  SectionMetrics* = object
    ## Screen-relative coordinates and dimensions of a section
    x*: int         # Screen X coordinate (after camera transform)
    y*: int         # Screen Y coordinate (after camera transform)
    width*: int     # Visual width of the section content
    height*: int    # Visual height of the section content
    worldX*: int    # World X coordinate (before camera transform)
    worldY*: int    # World Y coordinate (before camera transform)

proc getSectionMetrics*(): SectionMetrics =
  ## Get the screen coordinates and dimensions of the current section
  ## Returns metrics with x, y being relative to the terminal screen
  ## and width, height being the actual rendered content dimensions
  ## Returns zero values if no section is active
  if canvasState.isNil:
    return SectionMetrics()
  
  let currentIdx = getCurrentSectionIdx()
  if currentIdx < 0 or currentIdx >= canvasState.sections.len:
    return SectionMetrics()
  
  let layout = canvasState.sections[currentIdx]
  
  # Get camera position for screen coordinate conversion
  let cameraX = int(canvasState.camera.x + 0.5)
  let cameraY = int(canvasState.camera.y + 0.5)
  
  # Calculate screen-relative coordinates
  let screenX = layout.x - cameraX
  let screenY = layout.y - cameraY
  
  # Use actual visual dimensions if available, otherwise use layout dimensions
  let width = if layout.actualVisualWidth > 0: layout.actualVisualWidth else: layout.width
  let height = if layout.actualVisualHeight > 0: layout.actualVisualHeight else: layout.height
  
  return SectionMetrics(
    x: screenX,
    y: screenY,
    width: width,
    height: height,
    worldX: layout.x,
    worldY: layout.y
  )

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
  
  let previousIdx = getCurrentSectionIdx()
  
  # Execute on:exit hooks for the previous section
  if previousIdx >= 0 and previousIdx < canvasState.sections.len and previousIdx != sectionIdx:
    let previousSection = canvasState.sections[previousIdx].section
    executeLifecycleHooks(previousSection, "exit")
    
    # Check if leaving a section that should be removed after visit
    if previousSection.metadata.hasKey("removeAfterVisit"):
      let removeValue = previousSection.metadata["removeAfterVisit"].toLowerAscii()
      if removeValue == "true" or removeValue == "1":
        removeSection(previousSection.title)
  
  # Update section manager (source of truth)
  if not gSectionMgr.isNil and sectionIdx >= 0 and sectionIdx < gSectionMgr[].sections.len:
    gSectionMgr[].currentIndex = sectionIdx
  
  canvasState.focusedLinkIdx = 0
  
  # Note: Content buffers are per-section, so no need to clear on navigation
  
  # Execute on:enter hooks for the new section
  if sectionIdx >= 0 and sectionIdx < canvasState.sections.len:
    let newSection = canvasState.sections[sectionIdx].section
    executeLifecycleHooks(newSection, "enter")
  
  # Center camera on new section with smooth easing (if viewport is initialized)
  # This is called AFTER on:enter hooks so content buffers are populated
  # For first visit, render will adjust if actual dimensions differ significantly
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
  
  # Use actual rendered dimensions if available (for accurate centering),
  # otherwise fall back to allocated section dimensions
  let effectiveWidth = if section.actualVisualWidth > 0: 
                         section.actualVisualWidth 
                       else: 
                         section.width
  
  let effectiveHeight = if section.actualVisualHeight > 0:
                          section.actualVisualHeight
                        else:
                          section.height
  
  # Center horizontally on actual content center (content is left-aligned at section.x)
  let contentCenterX = float(section.x) + float(effectiveWidth) / 2.0
  canvasState.camera.targetX = contentCenterX - float(viewportWidth) / 2.0
  
  # Center vertically on actual content center (content starts at section.y)
  let contentCenterY = float(section.y) + float(effectiveHeight) / 2.0
  canvasState.camera.targetY = contentCenterY - float(viewportHeight) / 2.0

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
    # Read width from metadata, default to gSectionWidth
    var sectionWidth = gSectionWidth
    if section.metadata.hasKey("width"):
      try:
        sectionWidth = parseInt(section.metadata["width"])
      except:
        discard
    
    # Read height from metadata, default to SECTION_HEIGHT
    var sectionHeight = SECTION_HEIGHT
    if section.metadata.hasKey("height"):
      try:
        sectionHeight = parseInt(section.metadata["height"])
      except:
        discard
    
    # Read navigable from metadata, default to true
    var isNavigable = true
    if section.metadata.hasKey("navigable"):
      let navValue = section.metadata["navigable"].toLowerAscii()
      isNavigable = navValue notin ["false", "no", "0"]
    
    # Read z-index from metadata for layer rendering
    var zIndex = 0
    var layerName = ""
    if section.metadata.hasKey("z"):
      try:
        zIndex = parseInt(section.metadata["z"])
        layerName = "z" & section.metadata["z"]  # e.g., "z-3" for z:-3
      except:
        discard
    
    var layout = SectionLayout(
      section: section,
      width: sectionWidth,
      height: sectionHeight,
      index: i,
      navigable: isNavigable,
      zIndex: zIndex,
      layerName: layerName
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
    
    maxHeightInRow = max(maxHeightInRow, sectionHeight)
    
    if sectionsInRow >= MAX_SECTIONS_PER_ROW:
      currentX = 0
      currentY += maxHeightInRow + SECTION_PADDING
      maxHeightInRow = 0
      sectionsInRow = 0
    else:
      currentX += sectionWidth + SECTION_PADDING
    
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
  ## Automatically skips Section 0 if it has no title (lifecycle hooks only)
  ## Also skips non-navigable sections
  if canvasState.isNil or currentIdx < 0:
    return -1
  
  let step = if forward: 1 else: -1
  var idx = currentIdx + step
  
  while idx >= 0 and idx < canvasState.sections.len:
    # Skip Section 0 if it has no title (it's just lifecycle hooks/init code)
    if idx == 0 and canvasState.sections[0].section.title.len == 0:
      idx += step
      continue
    
    # Skip non-navigable sections
    if not canvasState.sections[idx].navigable:
      idx += step
      continue
    
    if getSectionLevel(canvasState.sections[idx].section) == level:
      return idx
    idx += step
  
  return -1  # Not found

# ================================================================
# TEXT RENDERING UTILITIES
# ================================================================

proc getVisualWidth*(text: string): int =
  ## Calculate the visual display width of a string (accounting for double-width chars)
  result = 0
  var i = 0
  while i < text.len:
    let b = text[i].ord
    var charLen = 1
    var ch = ""
    
    if (b and 0x80) == 0:
      ch = $text[i]
    elif (b and 0xE0) == 0xC0 and i + 1 < text.len:
      ch = text[i..i+1]
      charLen = 2
    elif (b and 0xF0) == 0xE0 and i + 2 < text.len:
      ch = text[i..i+2]
      charLen = 3
    elif (b and 0xF8) == 0xF0 and i + 3 < text.len:
      ch = text[i..i+3]
      charLen = 4
    else:
      ch = "?"
    
    result += getCharDisplayWidth(ch)
    i += charLen

proc truncateToVisualWidth*(text: string, maxVisualWidth: int): string =
  ## Truncate a string to fit within maxVisualWidth display columns
  result = ""
  var visualWidth = 0
  var i = 0
  
  while i < text.len and visualWidth < maxVisualWidth:
    let b = text[i].ord
    var charLen = 1
    var ch = ""
    
    if (b and 0x80) == 0:
      ch = $text[i]
    elif (b and 0xE0) == 0xC0 and i + 1 < text.len:
      ch = text[i..i+1]
      charLen = 2
    elif (b and 0xF0) == 0xE0 and i + 2 < text.len:
      ch = text[i..i+2]
      charLen = 3
    elif (b and 0xF8) == 0xF0 and i + 3 < text.len:
      ch = text[i..i+3]
      charLen = 4
    else:
      ch = "?"
    
    let charWidth = getCharDisplayWidth(ch)
    if visualWidth + charWidth <= maxVisualWidth:
      result.add(ch)
      visualWidth += charWidth
    else:
      break
    
    i += charLen

proc wrapText*(text: string, maxWidth: int): seq[string] =
  ## Wrap text to fit within maxWidth (accounting for double-width characters)
  result = @[]
  let words = text.split(' ')
  var currentLine = ""
  
  for word in words:
    let currentWidth = getVisualWidth(currentLine)
    let wordWidth = getVisualWidth(word)
    let spaceWidth = if currentLine.len > 0: 1 else: 0
    
    if currentWidth + wordWidth + spaceWidth <= maxWidth:
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
  # Replace both underscores and hyphens with spaces for display
  cleaned = cleaned.replace("_", " ")
  cleaned = cleaned.replace("-", " ")
  
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

proc initCanvas*(sections: seq[Section], currentIdx: int = 0, presentationMode: bool = false, frontMatter: FrontMatter = initTable[string, string]()) =
  ## Initialize the canvas system (idempotent - only initializes if not already done)
  ## Set presentationMode=true for slide-style navigation where all sections are visible
  ## frontMatter: Document front matter containing global settings like hideHeadings
  
  # Preserve existing references if canvasState already exists
  var existingBuffer: ptr TermBuffer = nil
  var existingAppState: ptr AppState = nil
  var existingStyleSheet: ptr StyleSheet = nil
  
  if not canvasState.isNil:
    # Already initialized - preserve references and skip reinitialization
    existingBuffer = canvasState.buffer
    existingAppState = canvasState.appState
    existingStyleSheet = canvasState.styleSheet
  
  # Set section width from minWidth if provided
  if frontMatter.hasKey("minWidth"):
    try:
      let minWidth = parseInt(frontMatter["minWidth"])
      if minWidth > gSectionWidth:
        gSectionWidth = minWidth
    except:
      discard
  
  canvasState = CanvasState(
    camera: Camera(x: 0.0, y: 0.0, targetX: 0.0, targetY: 0.0),
    sections: calculateSectionPositions(sections),
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
    contentBuffers: initTable[string, seq[string]](),
    frontMatter: frontMatter,
    currentContentBounds: ContentBounds(),
    currentContentBufferBounds: ContentBounds(),
    buffer: existingBuffer,
    appState: existingAppState,
    styleSheet: existingStyleSheet
  )
  
  # Initialize section visibility from metadata
  # Check if all sections should be hidden by default (from front matter)
  let hideSectionsDefault = frontMatter.hasKey("hideSections") and 
                            frontMatter["hideSections"].toLowerAscii() in ["true", "yes", "1"]
  
  for layout in canvasState.sections:
    # Determine if this section should be hidden
    var shouldHide = hideSectionsDefault  # Start with document default
    
    # Check for explicit section-level override
    if layout.section.metadata.hasKey("hidden"):
      let hiddenValue = layout.section.metadata["hidden"].toLowerAscii()
      shouldHide = hiddenValue in ["true", "yes", "1"]
    
    if shouldHide:
      hideSection(layout.section.title)
  
  # In presentation mode, make all sections visible by default
  if presentationMode:
    for layout in canvasState.sections:
      markVisited(layout.section.title)
  
  # Mark starting section as visited (always visible)
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
export getSectionMetrics
export Camera, Link, SectionLayout, SectionMetrics, CanvasState
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
            let chStr = $ch
            buffer.writeText(currentX, y, chStr, style)
            currentX += getCharDisplayWidth(chStr)
          pos = codeEnd + 1
        else:
          # Not a variable reference - render the content literally
          for ch in codeContent:
            if currentX >= x + maxWidth:
              break
            var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: false, 
                             underline: baseStyle.underline, italic: false, dim: baseStyle.dim)
            let chStr = $ch
            buffer.writeText(currentX, y, chStr, style)
            currentX += getCharDisplayWidth(chStr)
          pos = codeEnd + 1  # Skip past closing backtick
      else:
        # No matching backtick, render the backtick itself
        var style = Style(fg: baseStyle.fg, bg: baseStyle.bg, bold: isBold, 
                         underline: baseStyle.underline, italic: isItalic, dim: baseStyle.dim)
        buffer.writeText(currentX, y, "`", style)
        currentX += 1  # Backtick is always single-width
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
      currentX += getCharDisplayWidth(ch)
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
  # For canvas mode (internal navigation links), underline is false by default
  # This is different from traditional web links since canvas is more like a game UI
  let linkStyle = if styleSheet.hasKey("link"):
                    toStyle(styleSheet["link"])
                  else:
                    Style(fg: ansiToColor(34), bg: bodyStyle.bg, bold: false, underline: false, italic: false, dim: false)
  
  let linkFocusedStyle = if styleSheet.hasKey("link_focused"):
                           toStyle(styleSheet["link_focused"])
                         else:
                           Style(fg: ansiToColor(33), bg: bodyStyle.bg, bold: true, underline: false, italic: false, dim: false)
  
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
          width: getVisualWidth(linkText),
          index: globalLinkIdx
        ))
        
        # Render link text
        for ch in linkText:
          if currentX < x + maxWidth:
            let chStr = $ch
            buffer.writeText(currentX, y, chStr, styleToUse)
            currentX += getCharDisplayWidth(chStr)
        
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
  ## Respects front matter "hideHeadings" setting and section-level "showHeading" metadata
  ## Logic: hideHeadings sets default, showHeading overrides per section
  var lines: seq[string] = @[]
  var contentBufferInserted = false  # Track if we've already inserted the buffer marker
  
  # Determine if headings should be shown by default (from front matter)
  let hideHeadingsDefault = if not canvasState.isNil and canvasState.frontMatter.hasKey("hideHeadings"):
                              canvasState.frontMatter["hideHeadings"].toLowerAscii() in ["true", "yes", "1"]
                            else:
                              false
  
  # Check section-level override, or use document default
  let showHeading = if section.metadata.hasKey("showHeading"):
                      # Section explicitly sets showHeading - use that value
                      section.metadata["showHeading"].toLowerAscii() in ["true", "yes", "1"]
                    else:
                      # No section override - use inverse of hideHeadings default
                      not hideHeadingsDefault
  
  for blk in section.blocks:
    case blk.kind
    of TextBlock:
      lines.add(blk.text)
    of HeadingBlock:
      # Include heading only if showHeading is true
      if showHeading:
        lines.add("#".repeat(blk.level) & " " & blk.title)
    of CodeBlock_Content:
      # Insert marker for code blocks that generate or receive content:
      # - on:render/on:enter blocks actively generate content via contentWrite()
      # - Data blocks (lvl, json, etc.) mark where global on:render can place content
      # Only insert ONE marker per section since content buffer is per-section
      if not contentBufferInserted and (blk.codeBlock.lifecycle in ["render", "enter"] or 
         (blk.codeBlock.lifecycle == "" and blk.codeBlock.language != "")):
        lines.add("{{CONTENT_BUFFER}}")
        contentBufferInserted = true
      # Skip other code blocks in content rendering
    of PreformattedBlock:
      # Add preformatted text directly (renders as-is without backticks)
      lines.add(blk.content)
    of AnsiBlock:
      # Parse ANSI content to a styled buffer (only once, cached)
      let bufferKey = blk.ansiBufferKey
      
      # Only parse if not already cached
      if not gAnsiBuffers.hasKey(bufferKey):
        # Convert bracket notation to actual ANSI escape sequences first
        let convertedContent = convertBracketNotationToAnsi(blk.ansiContent)
        let ansiBuffer = parseAnsiToBuffer(convertedContent)
        gAnsiBuffers[bufferKey] = ansiBuffer
      
      # Add a marker line so we know where to render the ANSI buffer
      # This marker will be recognized during rendering
      lines.add("{{ANSI:" & bufferKey & "}}")
  
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
                  styleSheet: StyleSheet = initTable[string, StyleConfig]()): tuple[links: seq[Link], visualWidth: int, visualHeight: int] =
  ## Render a single section to the buffer
  ## Returns links found in the section, maximum visual width, and total height of rendered content
  result.links = @[]
  result.visualWidth = 0
  result.visualHeight = 0
  
  # Skip removed sections
  if isRemoved(layout.section.title):
    return
  
  # Get styles from stylesheet or use defaults
  # Get default background from body style in stylesheet if available
  let defaultBg = if styleSheet.hasKey("body"): 
                    styleSheet["body"].bg
                  else:
                    (0'u8, 0'u8, 0'u8)
  
  let headingStyle = if styleSheet.hasKey("heading"):
                       toStyle(styleSheet["heading"])
                     else:
                       Style(fg: ansiToColor(33), bg: rgb(defaultBg.r, defaultBg.g, defaultBg.b), bold: true, underline: false, italic: false, dim: false)
  
  let bodyStyle = if styleSheet.hasKey("body"):
                    toStyle(styleSheet["body"])
                  else:
                    Style(fg: ansiToColor(37), bg: rgb(defaultBg.r, defaultBg.g, defaultBg.b), bold: false, underline: false, italic: false, dim: false)
  
  let placeholderStyle = if styleSheet.hasKey("placeholder"):
                           toStyle(styleSheet["placeholder"])
                         else:
                           Style(fg: ansiToColor(30), bg: rgb(defaultBg.r, defaultBg.g, defaultBg.b), bold: true, underline: false, italic: false, dim: false)
  
  # Track actual rendered dimensions for proper centering
  var maxVisualWidth = 0
  let startContentY = screenY
  
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
        let bufferStartY = contentY  # Track where buffer rendering begins
        let sectionBuffer = canvasState.contentBuffers[layout.section.title]
        
        # Track the maximum cell width used (accounting for double-width chars)
        var maxCellWidth = 0
        
        # Store buffer bounds for current section (if this is the current section, will be updated below)
        if isCurrent:
          canvasState.currentContentBufferBounds = ContentBounds(
            x: contentX,
            y: bufferStartY,
            width: maxContentWidth,
            height: 0  # Will be calculated as we render
          )
        
        for bufferLine in sectionBuffer:
          if contentY >= screenY + layout.height:
            break
          
          if bufferLine.startsWith("#"):
            # Heading
            let formatted = formatHeading(bufferLine)
            let displayText = if getVisualWidth(formatted) > maxContentWidth: 
                                truncateToVisualWidth(formatted, maxContentWidth) 
                              else: 
                                formatted
            # Track visual width of rendered heading (equals cell width for double-width chars)
            let renderedWidth = getVisualWidth(displayText)
            if renderedWidth > maxVisualWidth:
              maxVisualWidth = renderedWidth
            if renderedWidth > maxCellWidth:
              maxCellWidth = renderedWidth
            buffer.writeText(contentX, contentY, displayText, headingStyle)
          elif hasLinksOutsideBackticks(bufferLine):
            # Line with links
            let links = renderTextWithLinks(bufferLine, contentX, contentY, maxContentWidth,
                                           buffer, isCurrent, currentLinkIdx, styleSheet, bodyStyle)
            result.links.add(links)
            currentLinkIdx += links.len
            # Track width - estimate based on longest link text
            var maxLinkTextWidth = 0
            for link in links:
              let linkTextWidth = getVisualWidth(link.text)
              if linkTextWidth > maxLinkTextWidth:
                maxLinkTextWidth = linkTextWidth
            if maxLinkTextWidth > maxVisualWidth:
              maxVisualWidth = maxLinkTextWidth
            if maxLinkTextWidth > maxCellWidth:
              maxCellWidth = maxLinkTextWidth
          elif "**" in bufferLine or "*" in bufferLine:
            # Line with markdown formatting
            let wrapped = wrapText(bufferLine, maxContentWidth)
            for wLine in wrapped:
              if contentY >= screenY + layout.height:
                break
              discard renderInlineMarkdown(wLine, contentX, contentY, maxContentWidth,
                                          buffer, bodyStyle)
              # Track width without markdown markers (equals cell width for double-width chars)
              let textWithoutMarkdown = wLine.replace("**", "").replace("*", "")
              let lineWidth = getVisualWidth(textWithoutMarkdown)
              if lineWidth > maxVisualWidth:
                maxVisualWidth = lineWidth
              if lineWidth > maxCellWidth:
                maxCellWidth = lineWidth
              contentY += 1
            contentY -= 1
          else:
            # Plain text
            let wrapped = wrapText(bufferLine, maxContentWidth)
            for wLine in wrapped:
              if contentY >= screenY + layout.height:
                break
              buffer.writeText(contentX, contentY, wLine, bodyStyle)
              # Track visual width of wrapped line (equals cell width for double-width chars)
              let lineWidth = getVisualWidth(wLine)
              if lineWidth > maxVisualWidth:
                maxVisualWidth = lineWidth
              if lineWidth > maxCellWidth:
                maxCellWidth = lineWidth
              contentY += 1
            contentY -= 1
          
          contentY += 1
        
        # Update buffer dimensions now that we've finished rendering it
        if isCurrent:
          canvasState.currentContentBufferBounds.height = contentY - bufferStartY
          # Set width to actual cell width used (accounts for double-width chars like emoji)
          canvasState.currentContentBufferBounds.width = maxCellWidth
      
      # Continue to next line (don't render the marker itself)
      continue
    
    # Check line type
    if line.startsWith("#"):
      # Heading
      let formatted = formatHeading(line)
      let displayText = if getVisualWidth(formatted) > maxContentWidth: 
                          truncateToVisualWidth(formatted, maxContentWidth) 
                        else: 
                          formatted
      # Track visual width of actual rendered text
      let renderedWidth = getVisualWidth(displayText)
      if renderedWidth > maxVisualWidth:
        maxVisualWidth = renderedWidth
      buffer.writeText(contentX, contentY, displayText, headingStyle)
    elif hasLinksOutsideBackticks(line):
      # Line with links (but not inside backticks)
      let links = renderTextWithLinks(line, contentX, contentY, maxContentWidth,
                                     buffer, isCurrent, currentLinkIdx, styleSheet, bodyStyle)
      result.links.add(links)
      currentLinkIdx += links.len  # Update index for next line with links
      # Track width based on link text content
      var maxLinkTextWidth = 0
      for link in links:
        let linkTextWidth = getVisualWidth(link.text)
        if linkTextWidth > maxLinkTextWidth:
          maxLinkTextWidth = linkTextWidth
      if maxLinkTextWidth > maxVisualWidth:
        maxVisualWidth = maxLinkTextWidth
    elif line.startsWith("{{ANSI:") and line.endsWith("}}"):
      # ANSI block marker - render the styled buffer
      let bufferKey = line[7..^3]  # Extract key from {{ANSI:key}}
      if gAnsiBuffers.hasKey(bufferKey):
        let ansiBuffer = gAnsiBuffers[bufferKey]
        # Render each line of the ANSI buffer with its styled cells
        for y in 0 ..< ansiBuffer.height:
          if contentY >= screenY + layout.height:
            break
          # Only render if contentY is within buffer bounds
          if contentY >= 0 and contentY < buffer.height:
            var lineWidth = 0
            var maxNonSpaceX = 0  # Track actual content width
            for x in 0 ..< ansiBuffer.width:
              let idx = y * ansiBuffer.width + x
              if idx < ansiBuffer.cells.len:
                let cell = ansiBuffer.cells[idx]
                # Only render non-empty cells (skip spaces with default background)
                # This prevents overwriting buffer cells with black backgrounds
                if cell.ch != " " or cell.style.bg.r != 0 or cell.style.bg.g != 0 or cell.style.bg.b != 0:
                  # Render each cell with its style, with proper bounds checking
                  if contentX + x >= 0 and contentX + x < buffer.width:
                    let bufIdx = contentY * buffer.width + (contentX + x)
                    if bufIdx >= 0 and bufIdx < buffer.cells.len:
                      buffer.cells[bufIdx] = cell
                      lineWidth = x + 1
                      if cell.ch != " ":
                        maxNonSpaceX = x + 1
            # Use actual visual width (excluding trailing spaces)
            if maxNonSpaceX > maxVisualWidth:
              maxVisualWidth = maxNonSpaceX
          contentY += 1
        contentY -= 1  # Adjust for the increment below
    elif "**" in line or "*" in line:
      # Line with markdown formatting - wrap it first
      let wrapped = wrapText(line, maxContentWidth)
      for wLine in wrapped:
        if contentY >= screenY + layout.height:
          break
        discard renderInlineMarkdown(wLine, contentX, contentY, maxContentWidth,
                                    buffer, bodyStyle)
        # Track width of rendered text (without markdown markers)
        let textWithoutMarkdown = wLine.replace("**", "").replace("*", "")
        let lineWidth = getVisualWidth(textWithoutMarkdown)
        if lineWidth > maxVisualWidth:
          maxVisualWidth = lineWidth
        contentY += 1
      contentY -= 1  # Adjust for the increment below
    else:
      # Plain text - wrap it
      let wrapped = wrapText(line, maxContentWidth)
      for wLine in wrapped:
        if contentY >= screenY + layout.height:
          break
        buffer.writeText(contentX, contentY, wLine, bodyStyle)
        # Track visual width of wrapped line
        let lineWidth = getVisualWidth(wLine)
        if lineWidth > maxVisualWidth:
          maxVisualWidth = lineWidth
        contentY += 1
      contentY -= 1  # Adjust for the increment below
    
    contentY += 1
  
  # Update result with actual rendered dimensions
  result.visualWidth = maxVisualWidth
  result.visualHeight = contentY - startContentY

proc canvasRender*(buffer: var TermBuffer, viewportWidth, viewportHeight: int,
                  styleSheet: StyleSheet = initTable[string, StyleConfig]()) =
  ## Main canvas rendering function
  if canvasState.isNil:
    return
  
  # Clear the buffer with transparency to allow lower layers to show through
  # This enables multi-layer rendering (e.g., particles underneath canvas content)
  buffer.clearTransparent()
  
  # Copy parameters to local variables to avoid any potential shadowing issues
  let vw = viewportWidth
  let vh = viewportHeight
  
  setViewport(vw, vh)
  
  # Check if viewport size has changed
  let viewportChanged = (canvasState.lastViewportWidth != vw or 
                        canvasState.lastViewportHeight != vh)
  
  # Center camera on current section on first render or viewport resize
  # This happens BEFORE rendering so we use estimated dimensions
  let needsRecenter = (canvasState.camera.targetX == 0.0 and canvasState.camera.targetY == 0.0) or viewportChanged
  if needsRecenter:
    centerOnSection(getCurrentSectionIdx(), vw, vh)
    # Snap camera immediately on first render (no animation for initial position)
    if canvasState.lastViewportWidth == 0:
      canvasState.camera.x = canvasState.camera.targetX
      canvasState.camera.y = canvasState.camera.targetY
    # Store current viewport size
    canvasState.lastViewportWidth = vw
    canvasState.lastViewportHeight = vh
  
  # Update current section as visited
  let currentIdx = getCurrentSectionIdx()
  if currentIdx >= 0 and currentIdx < canvasState.sections.len:
    let currentSection = canvasState.sections[currentIdx]
    markVisited(currentSection.section.title)
  
  # Clear links for current frame
  canvasState.links = @[]
  
  # Get camera position - use rounding for precise centering
  let cameraX = int(canvasState.camera.x + 0.5)
  let cameraY = int(canvasState.camera.y + 0.5)
  
  var renderedCount = 0
  var removedCount = 0
  # Track if we need to recenter after rendering (for first visit with dynamic content)
  let currentSectionIdx = getCurrentSectionIdx()
  var shouldRecenterAfterRender = false
  
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
    let isCurrent = (layout.index == getCurrentSectionIdx())
    
    # Determine which buffer to render to based on z-index
    var targetBuffer = addr buffer
    if layout.layerName != "" and not canvasState.appState.isNil:
      # Section has z-index - render to its own layer
      var targetLayer = getLayer(canvasState.appState[], layout.layerName)
      if targetLayer.isNil:
        # Layer doesn't exist - create it
        targetLayer = addLayer(canvasState.appState[], layout.layerName, layout.zIndex)
      if not targetLayer.isNil:
        targetBuffer = addr targetLayer.buffer
    
    let (links, visualWidth, visualHeight) = renderSection(layout, screenX, screenY, targetBuffer[], isCurrent, styleSheet)
    
    # Update the actual dimensions in the section layout
    let previousWidth = canvasState.sections[i].actualVisualWidth
    let previousHeight = canvasState.sections[i].actualVisualHeight
    canvasState.sections[i].actualVisualWidth = visualWidth
    canvasState.sections[i].actualVisualHeight = visualHeight
    
    # If this is the current section and dimensions changed significantly, re-center
    # This handles cases where on:render/on:enter adds content via contentWrite()
    if isCurrent:
      canvasState.links = links
      # Store content bounds for mouse coordinate conversion
      canvasState.currentContentBounds = ContentBounds(
        x: screenX,
        y: screenY,
        width: layout.width,
        height: visualHeight  # Use actual rendered height
      )
      
      # Check if dimensions changed significantly (first render: previousWidth/Height are 0)
      # Re-center if width or height increased by more than a small threshold
      let widthChanged = (previousWidth == 0 and visualWidth > 0) or 
                        abs(visualWidth - previousWidth) > 2
      let heightChanged = (previousHeight == 0 and visualHeight > 0) or 
                         abs(visualHeight - previousHeight) > 2
      
      if widthChanged or heightChanged:
        # Re-center on the current section with updated dimensions
        centerOnSection(layout.index, vw, vh)

proc canvasUpdate*(deltaTime: float) =
  ## Update canvas animations
  if canvasState.isNil:
    return
  
  updateCamera(deltaTime, gViewportWidth, gViewportHeight)
  
  # Check if mousefocus is enabled (default: true, can be disabled with frontmatter: mousefocus: "false")
  let mouseFocusEnabled = not (canvasState.frontMatter.hasKey("mousefocus") and 
                               canvasState.frontMatter["mousefocus"].toLowerAscii() in ["false", "no", "0"])
  
  # Update hover focus for links when mousefocus is enabled and not in presentation mode
  if mouseFocusEnabled and not canvasState.presentationMode and not canvasState.appState.isNil:
    # Get current mouse position from app state (updated by mouse move events)
    let mouseX = canvasState.appState.lastMouseX
    let mouseY = canvasState.appState.lastMouseY
    
    # Check if mouse is hovering over any link
    for i, link in canvasState.links:
      if mouseX >= link.screenX and mouseX < link.screenX + link.width and
         mouseY == link.screenY:
        # Mouse is hovering over this link - focus it
        if canvasState.focusedLinkIdx != i:
          canvasState.focusedLinkIdx = i
        break

proc canvasHandleKey*(keyCode: int, mods: set[uint8]): bool =
  ## Handle keyboard input
  ## Returns true if event was consumed
  if canvasState.isNil:
    return false
  
  # Arrow keys and Tab for link navigation
  const INPUT_UP = 10000
  const INPUT_DOWN = 10001
  const INPUT_LEFT = 10002
  const INPUT_RIGHT = 10003
  const INPUT_TAB = 9
  const INPUT_ENTER = 13
  
  # PRESENTATION MODE: Arrow keys navigate sections by heading level
  if canvasState.presentationMode:
    let currentIdx = getCurrentSectionIdx()
    case keyCode
    of INPUT_LEFT:
      # Navigate to previous main heading (level 1)
      let prevIdx = getNextSectionAtLevel(currentIdx, 1, false)
      if prevIdx >= 0:
        navigateToSection(prevIdx)
        return true
    
    of INPUT_RIGHT:
      # Navigate to next main heading (level 1)
      let nextIdx = getNextSectionAtLevel(currentIdx, 1, true)
      if nextIdx >= 0:
        navigateToSection(nextIdx)
        return true
    
    of INPUT_UP:
      # Navigate to previous sub-heading (level 2+)
      # Try level 2 first, then 3, etc.
      for level in 2..6:
        let prevIdx = getNextSectionAtLevel(currentIdx, level, false)
        if prevIdx >= 0:
          navigateToSection(prevIdx)
          return true
      return false
    
    of INPUT_DOWN:
      # Navigate to next sub-heading (level 2+)
      for level in 2..6:
        let nextIdx = getNextSectionAtLevel(currentIdx, level, true)
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
        if targetSection.section.id != "" and targetSection.navigable:
          navigateToSection(targetSection.index)
          return true
    
    of ord('1')..ord('9'):
      # Quick jump to link by number
      let linkNum = keyCode - ord('1')
      if linkNum < canvasState.links.len:
        let link = canvasState.links[linkNum]
        let targetSection = findSectionByReference(link.target)
        if targetSection.section.id != "" and targetSection.navigable:
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
  
  # Only handle left mouse button clicks (mouse release events)
  if button != 0 or isDown:
    return false
  
  # PRESENTATION MODE: Screen-region navigation
  if canvasState.presentationMode:
    let currentIdx = getCurrentSectionIdx()
    # Divide screen into left and right halves
    let halfWidth = gViewportWidth div 2
    
    if mouseX < halfWidth:
      # Left side clicked - go to previous main heading
      let prevIdx = getNextSectionAtLevel(currentIdx, 1, false)
      if prevIdx >= 0:
        navigateToSection(prevIdx)
        return true
    else:
      # Right side clicked - go to next main heading
      let nextIdx = getNextSectionAtLevel(currentIdx, 1, true)
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
        if targetSection.section.id != "" and targetSection.navigable:
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

# Helper to convert Value to int (handles both int and float values)
# This may be duplicated in including contexts but that's okay for private helpers
proc canvasValueToInt(v: Value): int =
  case v.kind
  of vkInt: return v.i
  of vkFloat: return int(v.f)
  else: return 0

# Note: initCanvas is defined in index.nim since it needs access to storieCtx

proc nimini_contentWrite*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Write a line to the content buffer for the current section. Args: text (string)
  ## Content buffer is rendered as part of the current section only
  if args.len > 0 and args[0].kind == vkString:
    let currentIdx = getCurrentSectionIdx()
    if not canvasState.isNil and currentIdx >= 0 and currentIdx < canvasState.sections.len:
      let sectionTitle = canvasState.sections[currentIdx].section.title
      if not canvasState.contentBuffers.hasKey(sectionTitle):
        canvasState.contentBuffers[sectionTitle] = @[]
      canvasState.contentBuffers[sectionTitle].add(args[0].s)
  return valNil()

proc nimini_contentClear*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Clear the content buffer for the current section
  let currentIdx = getCurrentSectionIdx()
  if not canvasState.isNil and currentIdx >= 0 and currentIdx < canvasState.sections.len:
    let sectionTitle = canvasState.sections[currentIdx].section.title
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

proc canvasRender*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Render the canvas system. No args needed (uses canvasState references)
  if not canvasState.isNil and not canvasState.appState.isNil and not canvasState.buffer.isNil:
    gNiminiEnv = cast[pointer](env)  # Store env for variable expansion during rendering
    let styleSheet = if not canvasState.styleSheet.isNil: canvasState.styleSheet[]
                     else: initTable[string, StyleConfig]()
    canvasRender(canvasState.buffer[], canvasState.appState.termWidth, canvasState.appState.termHeight, styleSheet)
  return valNil()

proc canvasUpdate*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Update canvas animations. Args: deltaTime (float)
  let deltaTime = if args.len > 0:
    (if args[0].kind == vkFloat: args[0].f else: float(args[0].i))
  else:
    0.016 # Default ~60fps
  canvasUpdate(deltaTime)
  return valNil()

proc canvasHandleKey*(env: ref Env; args: seq[Value]): Value {.nimini.} =
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

proc canvasHandleMouse*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Handle mouse input for canvas. Args: x (int), y (int), button (int), isDown (bool)
  ## Returns: bool (true if handled)
  if args.len < 4:
    return valBool(false)
  let x = canvasValueToInt(args[0])
  let y = canvasValueToInt(args[1])
  let button = canvasValueToInt(args[2])
  let isDown = if args[3].kind == vkBool: args[3].b else: (canvasValueToInt(args[3]) != 0)
  return valBool(canvasHandleMouse(x, y, button, isDown))

proc nimini_getSectionMetrics*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current section's screen coordinates and dimensions
  ## Returns table: { x: int, y: int, width: int, height: int, worldX: int, worldY: int }
  ## Returns nil if canvas is not initialized or no current section
  if canvasState.isNil:
    return valNil()
  
  let metrics = getSectionMetrics()
  
  # Return nil if no metrics available (all zeros)
  if metrics.x == 0 and metrics.y == 0 and metrics.width == 0 and metrics.height == 0:
    return valNil()
  
  result = valMap()
  result.map["x"] = valInt(metrics.x)
  result.map["y"] = valInt(metrics.y)
  result.map["width"] = valInt(metrics.width)
  result.map["height"] = valInt(metrics.height)
  result.map["worldX"] = valInt(metrics.worldX)
  result.map["worldY"] = valInt(metrics.worldY)

proc getContentBounds*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Get current section's content rendering bounds for mouse coordinate conversion
  ## Returns table: { x: int, y: int, width: int, height: int }
  ## Returns nil if canvas is not initialized
  if canvasState.isNil:
    return valNil()
  
  result = valMap()
  result.map["x"] = valInt(canvasState.currentContentBounds.x)
  result.map["y"] = valInt(canvasState.currentContentBounds.y)
  result.map["width"] = valInt(canvasState.currentContentBounds.width)
  result.map["height"] = valInt(canvasState.currentContentBounds.height)

proc screenToContent*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Convert screen coordinates to content-relative coordinates
  ## Args: screenX (int), screenY (int)
  ## Returns table: { x: int, y: int } or nil if outside content area or canvas not initialized
  if args.len < 2 or canvasState.isNil:
    return valNil()
  
  let screenX = canvasValueToInt(args[0])
  let screenY = canvasValueToInt(args[1])
  let bounds = canvasState.currentContentBounds
  
  let contentX = screenX - bounds.x
  let contentY = screenY - bounds.y
  
  # Check if within content area
  if contentX < 0 or contentY < 0 or 
     contentX >= bounds.width or contentY >= bounds.height:
    return valNil()
  
  result = valMap()
  result.map["x"] = valInt(contentX)
  result.map["y"] = valInt(contentY)

proc eventToGrid*(env: ref Env; args: seq[Value]): Value {.nimini.} =
  ## Convert mouse event to grid coordinates (for games)
  ## Args: event (table), cellWidth (int), cellHeight (int, optional, default=1)
  ## Returns table: { x: int, y: int, valid: bool }
  ## Uses bufferX/bufferY from event if available, otherwise returns invalid
  if args.len < 2:
    # Return invalid result
    result = valMap()
    result.map["x"] = valInt(-1)
    result.map["y"] = valInt(-1)
    result.map["valid"] = valBool(false)
    return result
  
  # Get event table
  let eventVal = args[0]
  if eventVal.kind != vkMap:
    result = valMap()
    result.map["x"] = valInt(-1)
    result.map["y"] = valInt(-1)
    result.map["valid"] = valBool(false)
    return result
  
  # Get cell dimensions
  let cellWidth = canvasValueToInt(args[1])
  let cellHeight = if args.len >= 3: canvasValueToInt(args[2]) else: 1
  
  # Extract bufferX and bufferY from event
  var bufferX = -1
  var bufferY = -1
  
  if eventVal.map.hasKey("bufferX"):
    bufferX = canvasValueToInt(eventVal.map["bufferX"])
  if eventVal.map.hasKey("bufferY"):
    bufferY = canvasValueToInt(eventVal.map["bufferY"])
  
  # Check if coordinates are valid
  if bufferX < 0 or bufferY < 0:
    result = valMap()
    result.map["x"] = valInt(-1)
    result.map["y"] = valInt(-1)
    result.map["valid"] = valBool(false)
    return result
  
  # Convert to grid coordinates
  let gridX = bufferX div cellWidth
  let gridY = bufferY div cellHeight
  
  result = valMap()
  result.map["x"] = valInt(gridX)
  result.map["y"] = valInt(gridY)
  result.map["valid"] = valBool(true)

proc registerCanvasBindings*(buffer: ptr TermBuffer, appState: ptr AppState, 
                            styleSheet: ptr StyleSheet) =
  ## Register canvas bindings with the nimini runtime
  ## Call this during initialization after creating the nimini context
  ## 
  ## This function works for both include and import modes
  
  # Create minimal canvasState if it doesn't exist yet
  # This ensures we can store references even before initCanvas is called
  if canvasState.isNil:
    canvasState = CanvasState(
      camera: Camera(x: 0.0, y: 0.0, targetX: 0.0, targetY: 0.0),
      sections: @[],
      links: @[],
      focusedLinkIdx: 0,
      visitedSections: initHashSet[string](),
      hiddenSections: initHashSet[string](),
      removedSections: initHashSet[string](),
      mouseEnabled: false,
      presentationMode: false,
      lastRenderTime: 0.0,
      lastViewportWidth: 0,
      lastViewportHeight: 0,
      contentBuffers: initTable[string, seq[string]](),
      frontMatter: initTable[string, string](),
      currentContentBounds: ContentBounds(),
      currentContentBufferBounds: ContentBounds(),
      buffer: nil,
      appState: nil,
      styleSheet: nil
    )
  
  # Store references for nimini wrappers
  canvasState.buffer = buffer
  canvasState.appState = appState
  canvasState.styleSheet = styleSheet
  
  # Export all nimini wrapper functions
  exportNiminiProcs(
    nimini_hideSection, nimini_removeSection, nimini_restoreSection,
    nimini_isVisited, nimini_markVisited, canvasRender, 
    canvasUpdate, canvasHandleKey, canvasHandleMouse,
    getContentBounds, screenToContent, eventToGrid
  )
  
  # Register content buffer functions with simple names
  registerNative("contentWrite", nimini_contentWrite)
  registerNative("contentClear", nimini_contentClear)
  registerNative("getSectionMetrics", nimini_getSectionMetrics)

# Export rendering functions
export canvasRender, canvasUpdate, canvasHandleKey, canvasHandleMouse, getSectionCount
export registerCanvasBindings, setExecuteCallback, ExecuteCodeBlockCallback
export initCanvasModule  # For import mode initialization
