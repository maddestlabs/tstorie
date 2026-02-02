## TUI Module - Retained mode UI system for tStorie
## Provides buttons, labels, checkboxes, and sliders with group management
## Usage: init*() → updateTUI() in on:update → drawTUI() in on:render

import tables, strutils
import ../src/types
import ../src/input/types  # Import key constants (KEY_RETURN, KEY_SPACE, etc.)
import storie_types
import ../backends/terminal/termbuffer

const
  MAX_WIDGETS = 32  # Increased from 16 to 32 for more complex UIs
  MAX_GROUPS = 8    # Support 8 UI groups

type
  WidgetType* = enum
    wtButton
    wtLabel
    wtCheckbox
    wtSlider

  Widget* = object
    id*: int
    x*, y*, w*, h*: int
    group*: int
    active*: bool
    visible*: bool
    hovered*: bool
    focused*: bool  # Keyboard focus state
    case kind*: WidgetType
    of wtButton:
      buttonLabel*: string
      clicked*: bool
    of wtLabel:
      labelText*: string
      labelAlign*: string  # "left", "center", "right"
    of wtCheckbox:
      checkLabel*: string
      checked*: bool
      toggled*: bool  # Just toggled this frame
    of wtSlider:
      sliderLabel*: string
      minVal*, maxVal*, currentVal*: int
      dragging*: bool

var 
  gWidgets: array[MAX_WIDGETS, Widget]
  gGroupVisible: array[MAX_GROUPS, bool]
  gLastMousePressed = false  # Track press state changes
  gFocusedWidget = -1  # Currently focused widget for keyboard navigation
  gStorieStyleSheet*: ptr StyleSheet = nil  # Reference to global stylesheet for themed styles

proc getThemedStyle(styleName: string): Style =
  ## Get a Style from the global stylesheet by name, with fallback
  if not gStorieStyleSheet.isNil and gStorieStyleSheet[].hasKey(styleName):
    let sc = gStorieStyleSheet[][styleName]
    return Style(
      fg: Color(r: sc.fg.r, g: sc.fg.g, b: sc.fg.b),
      bg: Color(r: sc.bg.r, g: sc.bg.g, b: sc.bg.b),
      bold: sc.bold,
      underline: sc.underline,
      italic: sc.italic,
      dim: sc.dim
    )
  # Fallback to default style
  return Style(
    fg: Color(r: 224'u8, g: 224'u8, b: 224'u8),
    bg: Color(r: 0'u8, g: 17'u8, b: 17'u8),
    bold: false,
    underline: false,
    italic: false,
    dim: false
  )

# Initialize group visibility (all visible by default)
proc initTUI*() {.exportc.} =
  ## Initialize the TUI system - call once at startup
  for i in 0..<MAX_GROUPS:
    gGroupVisible[i] = true
  for i in 0..<MAX_WIDGETS:
    gWidgets[i].active = false
  gFocusedWidget = -1

# Keyboard navigation helpers
proc findNextFocusableWidget(startIdx: int, forward: bool = true): int =
  ## Find next/previous focusable widget in visible groups
  ## Returns -1 if none found
  let step = if forward: 1 else: -1
  var idx = startIdx
  
  # Search through all widgets
  for _ in 0..<MAX_WIDGETS:
    idx = (idx + step + MAX_WIDGETS) mod MAX_WIDGETS
    
    # Skip inactive, invisible widgets, and labels
    if not gWidgets[idx].active or not gWidgets[idx].visible:
      continue
    if not gGroupVisible[gWidgets[idx].group]:
      continue
    if gWidgets[idx].kind == wtLabel:  # Labels aren't focusable
      continue
    
    return idx
  
  return -1  # No focusable widget found

proc handleTUIKey*(keyCode: KeyCode, action: string, modifiers: set[uint8] = {}) {.exportc.} =
  ## Handle keyboard input for TUI navigation and interaction
  ## Call from on:input when event.type == "key"
  ## keyCode: the key code (e.g., KEY_TAB, KEY_RETURN, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT)
  ## action: "press", "release", or "repeat"
  ## modifiers: optional modifier keys (ModShift, ModAlt, ModCtrl, ModSuper)
  
  # Only handle key press and repeat events (ignore release)
  if action != "press" and action != "repeat":
    return
  
  # Tab navigation (with SHIFT+TAB for reverse)
  if keyCode == KEY_TAB:
    let hasShift = ModShift in modifiers
    
    # SHIFT+TAB: Cycle backward
    if hasShift:
      let prevIdx = if gFocusedWidget == -1:
        findNextFocusableWidget(0, forward = false)  # Start from end
      else:
        findNextFocusableWidget(gFocusedWidget, forward = false)
      
      if prevIdx != -1:
        if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
          gWidgets[gFocusedWidget].focused = false
        gFocusedWidget = prevIdx
        gWidgets[gFocusedWidget].focused = true
    # TAB: Cycle forward
    else:
      let nextIdx = if gFocusedWidget == -1:
        findNextFocusableWidget(0)  # Start from beginning
      else:
        findNextFocusableWidget(gFocusedWidget)
      
      if nextIdx != -1:
        if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
          gWidgets[gFocusedWidget].focused = false
        gFocusedWidget = nextIdx
        gWidgets[gFocusedWidget].focused = true
  
  # Activate
  elif keyCode == KEY_RETURN or keyCode == KEY_SPACE:
    # Activate focused widget
    if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
      case gWidgets[gFocusedWidget].kind:
        of wtButton:
          gWidgets[gFocusedWidget].clicked = true
        of wtCheckbox:
          gWidgets[gFocusedWidget].checked = not gWidgets[gFocusedWidget].checked
          gWidgets[gFocusedWidget].toggled = true
        else:
          discard
  
  # Arrow Left
  elif keyCode == KEY_LEFT:
    # Decrease slider value or navigate backward
    if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
      if gWidgets[gFocusedWidget].kind == wtSlider:
        let current = gWidgets[gFocusedWidget].currentVal
        let step = max(1, (gWidgets[gFocusedWidget].maxVal - gWidgets[gFocusedWidget].minVal) div 20)
        gWidgets[gFocusedWidget].currentVal = max(gWidgets[gFocusedWidget].minVal, current - step)
      else:
        # Navigate backward
        let prevIdx = findNextFocusableWidget(gFocusedWidget, forward = false)
        if prevIdx != -1 and prevIdx != gFocusedWidget:
          gWidgets[gFocusedWidget].focused = false
          gFocusedWidget = prevIdx
          gWidgets[gFocusedWidget].focused = true
  
  # Arrow Right
  elif keyCode == KEY_RIGHT:
    # Increase slider value or navigate forward
    if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
      if gWidgets[gFocusedWidget].kind == wtSlider:
        let current = gWidgets[gFocusedWidget].currentVal
        let step = max(1, (gWidgets[gFocusedWidget].maxVal - gWidgets[gFocusedWidget].minVal) div 20)
        gWidgets[gFocusedWidget].currentVal = min(gWidgets[gFocusedWidget].maxVal, current + step)
      else:
        # Navigate forward
        let nextIdx = findNextFocusableWidget(gFocusedWidget)
        if nextIdx != -1 and nextIdx != gFocusedWidget:
          gWidgets[gFocusedWidget].focused = false
          gFocusedWidget = nextIdx
          gWidgets[gFocusedWidget].focused = true
  
  # Arrow Up
  elif keyCode == KEY_UP:
    # Navigate to previous widget
    if gFocusedWidget >= 0:
      let prevIdx = findNextFocusableWidget(gFocusedWidget, forward = false)
      if prevIdx != -1 and prevIdx != gFocusedWidget:
        gWidgets[gFocusedWidget].focused = false
        gFocusedWidget = prevIdx
        gWidgets[gFocusedWidget].focused = true
    else:
      # No focus yet, start from beginning
      let firstIdx = findNextFocusableWidget(0)
      if firstIdx != -1:
        gFocusedWidget = firstIdx
        gWidgets[gFocusedWidget].focused = true
  
  # Arrow Down
  elif keyCode == KEY_DOWN:
    # Navigate to next widget
    if gFocusedWidget >= 0:
      let nextIdx = findNextFocusableWidget(gFocusedWidget)
      if nextIdx != -1 and nextIdx != gFocusedWidget:
        gWidgets[gFocusedWidget].focused = false
        gFocusedWidget = nextIdx
        gWidgets[gFocusedWidget].focused = true
    else:
      # No focus yet, start from beginning
      let firstIdx = findNextFocusableWidget(0)
      if firstIdx != -1:
        gFocusedWidget = firstIdx
        gWidgets[gFocusedWidget].focused = true

# Group management
proc setGroupVisible*(group: int, visible: bool) {.exportc.} =
  ## Set visibility for a UI group
  if group < 0 or group >= MAX_GROUPS:
    return
  gGroupVisible[group] = visible

proc isGroupVisible*(group: int): bool {.exportc.} =
  ## Check if a group is visible
  if group < 0 or group >= MAX_GROUPS:
    return false
  return gGroupVisible[group]

# Widget initialization
proc initButton*(id: int, x, y, w, h: int, label: string, group: int = 0) {.exportc.} =
  ## Initialize a button widget
  if id < 0 or id >= MAX_WIDGETS:
    return
  gWidgets[id] = Widget(
    id: id,
    kind: wtButton,
    x: x, y: y, w: w, h: h,
    group: group,
    active: true,
    visible: true,
    hovered: false,
    buttonLabel: label,
    clicked: false
  )

proc initLabel*(id: int, x, y, w, h: int, text: string, align: string = "left", group: int = 0) {.exportc.} =
  ## Initialize a label widget
  if id < 0 or id >= MAX_WIDGETS:
    return
  gWidgets[id] = Widget(
    id: id,
    kind: wtLabel,
    x: x, y: y, w: w, h: h,
    group: group,
    active: true,
    visible: true,
    hovered: false,
    labelText: text,
    labelAlign: align
  )

proc initCheckbox*(id: int, x, y, w, h: int, label: string, checked: bool = false, group: int = 0) {.exportc.} =
  ## Initialize a checkbox widget
  if id < 0 or id >= MAX_WIDGETS:
    return
  gWidgets[id] = Widget(
    id: id,
    kind: wtCheckbox,
    x: x, y: y, w: w, h: h,
    group: group,
    active: true,
    visible: true,
    hovered: false,
    checkLabel: label,
    checked: checked,
    toggled: false
  )

proc initSlider*(id: int, x, y, w, h: int, label: string, minVal, maxVal, initialVal: int, group: int = 0) {.exportc.} =
  ## Initialize a slider widget
  if id < 0 or id >= MAX_WIDGETS:
    return
  gWidgets[id] = Widget(
    id: id,
    kind: wtSlider,
    x: x, y: y, w: w, h: h,
    group: group,
    active: true,
    visible: true,
    hovered: false,
    sliderLabel: label,
    minVal: minVal,
    maxVal: maxVal,
    currentVal: clamp(initialVal, minVal, maxVal),
    dragging: false
  )

# Update logic
proc updateTUI*(mouseX, mouseY: int, mousePressed: bool) {.exportc.} =
  ## Update all widget states based on mouse input
  let mouseJustPressed = mousePressed and not gLastMousePressed
  gLastMousePressed = mousePressed
  
  for i in 0..<MAX_WIDGETS:
    if not gWidgets[i].active or not gWidgets[i].visible:
      continue
    if not gGroupVisible[gWidgets[i].group]:
      continue
    
    # Check hover state
    gWidgets[i].hovered = mouseX >= gWidgets[i].x and 
                          mouseX < gWidgets[i].x + gWidgets[i].w and
                          mouseY >= gWidgets[i].y and 
                          mouseY < gWidgets[i].y + gWidgets[i].h
    
    # Widget-specific updates
    case gWidgets[i].kind:
      of wtButton:
        gWidgets[i].clicked = gWidgets[i].hovered and mouseJustPressed
      
      of wtCheckbox:
        gWidgets[i].toggled = gWidgets[i].hovered and mouseJustPressed
        if gWidgets[i].toggled:
          gWidgets[i].checked = not gWidgets[i].checked
      
      of wtSlider:
        if gWidgets[i].hovered and mouseJustPressed:
          gWidgets[i].dragging = true
        if not mousePressed:
          gWidgets[i].dragging = false
        
        # Update slider value while dragging
        if gWidgets[i].dragging:
          let sliderWidth = gWidgets[i].w - 4  # Account for borders and label
          let relX = mouseX - gWidgets[i].x - 2
          let range = gWidgets[i].maxVal - gWidgets[i].minVal
          let normalizedPos = clamp(relX.float / sliderWidth.float, 0.0, 1.0)
          gWidgets[i].currentVal = gWidgets[i].minVal + int(normalizedPos * range.float)
      
      of wtLabel:
        discard  # Labels don't have interactive state

# Drawing
proc drawButton(buffer: ptr TermBuffer, w: Widget, style: Style) =
  let x = w.x
  let y = w.y
  let width = w.w
  let height = w.h
  
  # Choose style based on state: clicked > focused > hovered > normal
  var btnStyle = style
  if w.clicked:
    btnStyle = getThemedStyle("warning")  # Warning/emphasis style when clicked
  elif w.focused:
    btnStyle = getThemedStyle("link_focused")  # Focused style for keyboard navigation
  elif w.hovered:
    btnStyle = getThemedStyle("button")   # Button style when hovered (stands out)
  else:
    btnStyle = getThemedStyle("default")  # Default style for normal state (blends in)
  
  # Draw box border with filled background
  # Use double-line border for focused state
  if w.focused:
    buffer[].writeCellText(x, y, "╔" & "═".repeat(width-2) & "╗", btnStyle)
    for row in 1..<(height-1):
      buffer[].writeCellText(x, y + row, "║" & " ".repeat(width-2) & "║", btnStyle)
    buffer[].writeCellText(x, y + height - 1, "╚" & "═".repeat(width-2) & "╝", btnStyle)
  else:
    buffer[].writeCellText(x, y, "┌" & "─".repeat(width-2) & "┐", btnStyle)
    for row in 1..<(height-1):
      buffer[].writeCellText(x, y + row, "│" & " ".repeat(width-2) & "│", btnStyle)
    buffer[].writeCellText(x, y + height - 1, "└" & "─".repeat(width-2) & "┘", btnStyle)
  
  # Draw centered label
  let centerY = y + (height div 2)
  let centerX = x + ((width - w.buttonLabel.len) div 2)
  if centerX >= x and centerX + w.buttonLabel.len <= x + width:
    buffer[].writeCellText(centerX, centerY, w.buttonLabel, btnStyle)

proc drawLabel(buffer: ptr TermBuffer, w: Widget, style: Style) =
  let x = w.x
  let y = w.y + (w.h div 2)  # Vertical center
  
  # Use themed 'heading' style for labels (prominent text)
  let labelStyle = getThemedStyle("heading")
  
  var drawX = x
  case w.labelAlign:
    of "center":
      drawX = x + ((w.w - w.labelText.len) div 2)
    of "right":
      drawX = x + w.w - w.labelText.len
    else:  # "left"
      drawX = x
  
  if drawX >= x and drawX + w.labelText.len <= x + w.w:
    buffer[].writeCellText(drawX, y, w.labelText, labelStyle)

proc drawCheckbox(buffer: ptr TermBuffer, w: Widget, style: Style) =
  let x = w.x
  let y = w.y
  
  # Choose style based on state: focused > hovered > normal
  var boxStyle: Style
  if w.focused:
    boxStyle = getThemedStyle("link_focused")
  elif w.hovered:
    boxStyle = getThemedStyle("button")
  else:
    boxStyle = getThemedStyle("default")
  
  let labelStyle = getThemedStyle("body")
  
  # Draw checkbox symbol (use different brackets for focus)
  var symbol: string
  if w.focused:
    symbol = if w.checked: "《X》" else: "《 》"
  else:
    symbol = if w.checked: "[X]" else: "[ ]"
  
  buffer[].writeCellText(x, y, symbol, boxStyle)
  
  # Draw label
  buffer[].writeCellText(x + 4, y, w.checkLabel, labelStyle)

proc drawSlider(buffer: ptr TermBuffer, w: Widget, style: Style) =
  let x = w.x
  let y = w.y
  
  # Use themed styles for different parts
  let labelStyle = if w.focused: getThemedStyle("link_focused") else: getThemedStyle("info")
  let trackStyle = if w.focused: getThemedStyle("link_focused") else: getThemedStyle("border")
  let handleStyle = if w.dragging: getThemedStyle("accent3") 
                    elif w.focused: getThemedStyle("warning")
                    else: getThemedStyle("accent1")
  let valueStyle = getThemedStyle("default")
  
  # Draw label
  buffer[].writeCellText(x, y, w.sliderLabel, labelStyle)
  
  # Draw slider track (use different brackets for focus)
  let trackY = y + 1
  let trackWidth = w.w - 2
  if w.focused:
    buffer[].writeCellText(x, trackY, "《" & "═".repeat(trackWidth) & "》", trackStyle)
  else:
    buffer[].writeCellText(x, trackY, "[" & "-".repeat(trackWidth) & "]", trackStyle)
  
  # Draw slider handle
  let range = w.maxVal - w.minVal
  let normalizedPos = if range > 0: (w.currentVal - w.minVal).float / range.float else: 0.0
  let handleX = x + 1 + int(normalizedPos * trackWidth.float)
  buffer[].writeCellText(handleX, trackY, "█", handleStyle)
  
  # Draw value
  let valueStr = $w.currentVal
  buffer[].writeCellText(x, trackY + 1, valueStr, valueStyle)

proc drawTUI*(buffer: ptr TermBuffer, style: Style) {.exportc.} =
  ## Draw all visible widgets from active groups
  if buffer.isNil: 
    return
  
  # Draw in group order (0 first, then 1, etc.)
  for groupId in 0..<MAX_GROUPS:
    if not gGroupVisible[groupId]:
      continue
    
    for i in 0..<MAX_WIDGETS:
      if not gWidgets[i].active or not gWidgets[i].visible:
        continue
      if gWidgets[i].group != groupId:
        continue
      
      case gWidgets[i].kind:
        of wtButton:
          drawButton(buffer, gWidgets[i], style)
        of wtLabel:
          drawLabel(buffer, gWidgets[i], style)
        of wtCheckbox:
          drawCheckbox(buffer, gWidgets[i], style)
        of wtSlider:
          drawSlider(buffer, gWidgets[i], style)

# State queries
proc wasClicked*(id: int): bool {.exportc.} =
  ## Check if button was clicked this frame
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return false
  if gWidgets[id].kind != wtButton:
    return false
  return gWidgets[id].clicked

proc isHovered*(id: int): bool {.exportc.} =
  ## Check if widget is currently hovered
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return false
  return gWidgets[id].hovered

proc wasToggled*(id: int): bool {.exportc.} =
  ## Check if checkbox was toggled this frame
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return false
  if gWidgets[id].kind != wtCheckbox:
    return false
  return gWidgets[id].toggled

proc isChecked*(id: int): bool {.exportc.} =
  ## Get checkbox checked state
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return false
  if gWidgets[id].kind != wtCheckbox:
    return false
  return gWidgets[id].checked

proc getSliderValue*(id: int): int {.exportc.} =
  ## Get current slider value
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return 0
  if gWidgets[id].kind != wtSlider:
    return 0
  return gWidgets[id].currentVal

proc setSliderValue*(id: int, value: int) {.exportc.} =
  ## Set slider value programmatically
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return
  if gWidgets[id].kind != wtSlider:
    return
  gWidgets[id].currentVal = clamp(value, gWidgets[id].minVal, gWidgets[id].maxVal)

# Widget visibility control
proc setWidgetVisible*(id: int, visible: bool) {.exportc.} =
  ## Set individual widget visibility
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return
  gWidgets[id].visible = visible

proc isWidgetVisible*(id: int): bool {.exportc.} =
  ## Check if widget is visible
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return false
  return gWidgets[id].visible

# Text updates
proc setButtonLabel*(id: int, label: string) {.exportc.} =
  ## Update button label
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return
  if gWidgets[id].kind != wtButton:
    return
  gWidgets[id].buttonLabel = label

proc setLabelText*(id: int, text: string) {.exportc.} =
  ## Update label text
  if id < 0 or id >= MAX_WIDGETS or not gWidgets[id].active:
    return
  if gWidgets[id].kind != wtLabel:
    return
  gWidgets[id].labelText = text

# Keyboard focus management
proc getFocusedWidget*(): int {.exportc.} =
  ## Get the ID of the currently focused widget (-1 if none)
  return gFocusedWidget

proc setFocusedWidget*(id: int) {.exportc.} =
  ## Set keyboard focus to a specific widget
  ## Pass -1 to clear focus
  if id < -1 or id >= MAX_WIDGETS:
    return
  
  # Clear previous focus
  if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
    gWidgets[gFocusedWidget].focused = false
  
  # Set new focus
  if id >= 0 and gWidgets[id].active and gWidgets[id].kind != wtLabel:
    gFocusedWidget = id
    gWidgets[id].focused = true
  else:
    gFocusedWidget = -1

proc clearFocus*() {.exportc.} =
  ## Clear keyboard focus from all widgets
  if gFocusedWidget >= 0 and gFocusedWidget < MAX_WIDGETS:
    gWidgets[gFocusedWidget].focused = false
  gFocusedWidget = -1
