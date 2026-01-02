## TUI (Terminal User Interface) Module
## 
## Provides interactive UI widgets with state management, styling, and event handling.
## This module is designed to work with tstorie's existing systems:
## - Style system (Color, Style, StyleSheet from storie_types)
## - Layout module (text alignment and measurement)
## - Animation module (smooth transitions)
## - Events module (input handling)
##
## Phase 1: Foundation - Widget base types, manager, and style resolution
##
## NOTE: This module is included (not imported) by tstorie.nim, so it has access
## to all tstorie types and constants including INPUT_* constants

import tables
import algorithm  # For sort
import math  # For round, min, max
import storie_types  # For StyleSheet, StyleConfig
import layout  # For HAlign, VAlign
import ../src/types  # For Style, Color, Layer, InputEvent, etc.
from ../src/layers import write, writeText  # For buffer operations

# INPUT constants - used throughout tstorie
const
  INPUT_ESCAPE* = 27
  INPUT_BACKSPACE* = 127
  INPUT_SPACE* = 32
  INPUT_TAB* = 9
  INPUT_ENTER* = 13
  INPUT_DELETE* = 46
  INPUT_UP* = 1000
  INPUT_DOWN* = 1001
  INPUT_LEFT* = 1002
  INPUT_RIGHT* = 1003
  INPUT_HOME* = 1004
  INPUT_END* = 1005
  INPUT_PAGE_UP* = 1006
  INPUT_PAGE_DOWN* = 1007
  INPUT_F1* = 1008
  INPUT_F2* = 1009
  INPUT_F3* = 1010
  INPUT_F4* = 1011
  INPUT_F5* = 1012
  INPUT_F6* = 1013
  INPUT_F7* = 1014
  INPUT_F8* = 1015
  INPUT_F9* = 1016
  INPUT_F10* = 1017
  INPUT_F11* = 1018
  INPUT_F12* = 1019

# ================================================================
# WIDGET STATE MANAGEMENT
# ================================================================

type
  WidgetState* = enum
    ## Visual/interaction state of a widget
    wsNormal      ## Default state
    wsFocused     ## Widget has keyboard focus
    wsHovered     ## Mouse is over the widget
    wsDisabled    ## Widget is disabled (grayed out)
    wsActive      ## Widget is being actively manipulated (pressed, dragged)

  Widget* = ref object of RootObj
    ## Base widget type - all UI components inherit from this
    id*: string                ## Unique identifier for this widget
    x*, y*: int               ## Position (top-left corner)
    width*, height*: int      ## Size
    visible*: bool            ## Whether widget is rendered
    enabled*: bool            ## Whether widget accepts input
    state*: WidgetState       ## Current visual/interaction state
    focusable*: bool          ## Whether widget can receive keyboard focus
    tabIndex*: int            ## Order in tab navigation (-1 = not in tab order)
    
    # Style system integration
    styleSheet*: StyleSheet   ## Reference to document stylesheet
    normalStyle*: string      ## Style name for normal state (e.g., "button.normal")
    focusedStyle*: string     ## Style name for focused state
    hoverStyle*: string       ## Style name for hover state
    disabledStyle*: string    ## Style name for disabled state
    activeStyle*: string      ## Style name for active state
    
    # Style overrides (takes precedence over named styles)
    styleOverride*: Style     ## Direct style override (optional)
    useOverride*: bool        ## Whether to use styleOverride
    
    # Event callbacks
    onFocus*: proc(w: Widget) {.nimcall.}         ## Called when widget gains focus
    onBlur*: proc(w: Widget) {.nimcall.}          ## Called when widget loses focus
    onChange*: proc(w: Widget) {.nimcall.}        ## Called when widget value changes
    onClick*: proc(w: Widget) {.nimcall.}         ## Called when widget is clicked
    onKeyPress*: proc(w: Widget, key: int, mods: set[uint8]): bool {.nimcall.}  ## Custom key handler
    
    # Internal state
    userData*: pointer        ## User data pointer for custom widget data

# ================================================================
# WIDGET BASE METHODS
# ================================================================

method update*(w: Widget, dt: float) {.base.} =
  ## Update widget state (animations, etc.)
  ## Override in derived widgets for custom behavior
  discard

method render*(w: Widget, layer: Layer) {.base.} =
  ## Render widget to a layer
  ## Override in derived widgets for custom rendering
  discard

method handleInput*(w: Widget, event: InputEvent): bool {.base.} =
  ## Handle input event
  ## Returns true if event was consumed
  ## Override in derived widgets for custom input handling
  return false

method contains*(w: Widget, px, py: int): bool {.base.} =
  ## Check if point (px, py) is inside widget bounds
  ## Override for widgets with non-rectangular hit areas
  result = px >= w.x and px < w.x + w.width and
           py >= w.y and py < w.y + w.height

# ================================================================
# STYLE RESOLUTION SYSTEM
# ================================================================

proc resolveStyle*(w: Widget): Style =
  ## Resolve the current style for a widget based on its state
  ## Priority: styleOverride > state-specific style > normal style > default
  
  # If override is set, use it directly
  if w.useOverride:
    return w.styleOverride
  
  # TEMPORARY: Skip stylesheet lookup to avoid memory corruption issues
  # TODO: Fix styleSheet handling for multi-widget scenarios
  
  # Return default style
  return Style(
    fg: Color(r: 255, g: 255, b: 255),
    bg: Color(r: 0, g: 0, b: 0),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )

proc setStyleOverride*(w: Widget, style: Style) =
  ## Set a direct style override (bypasses stylesheet lookup)
  w.styleOverride = style
  w.useOverride = true

proc clearStyleOverride*(w: Widget) =
  ## Clear style override and return to stylesheet-based styling
  w.useOverride = false

# ================================================================
# WIDGET MANAGER
# ================================================================

type
  WidgetManager* = ref object
    ## Manages a collection of widgets, handles focus and tab order
    widgets*: seq[Widget]           ## All managed widgets
    focusedWidget*: Widget          ## Currently focused widget (nil if none)
    hoveredWidget*: Widget          ## Currently hovered widget (nil if none)
    activeWidget*: Widget           ## Currently active widget (being dragged/pressed)
    tabOrder*: seq[string]          ## Explicit tab order (widget IDs)
    autoTabOrder*: bool             ## Automatically build tab order from tabIndex
    styleSheet*: StyleSheet         ## Shared stylesheet for all widgets
    lastMouseX*, lastMouseY*: int   ## Last known mouse position

proc newWidgetManager*(styleSheet: StyleSheet): WidgetManager =
  ## Create a new widget manager
  result = WidgetManager()
  result.widgets = @[]
  result.focusedWidget = nil
  result.hoveredWidget = nil
  result.activeWidget = nil
  result.tabOrder = @[]
  result.autoTabOrder = true
  result.lastMouseX = 0
  result.lastMouseY = 0
  result.styleSheet = styleSheet

proc newWidgetManager*(): WidgetManager =
  ## Create a new widget manager with empty stylesheet
  result = newWidgetManager(initTable[string, StyleConfig]())

proc addWidget*(wm: WidgetManager, widget: Widget) =
  ## Add a widget to the manager
  if widget.isNil:
    return
  
  # Don't set stylesheet - causes memory corruption with multiple widgets
  # widget.styleSheet = wm.styleSheet
  
  # Add to widgets list
  wm.widgets.add(widget)
  
  # If widget is focusable and in tab order, add to tab order list
  if widget.focusable and widget.tabIndex >= 0:
    if wm.autoTabOrder:
      # Will be rebuilt in rebuildTabOrder
      discard
    else:
      wm.tabOrder.add(widget.id)

proc removeWidget*(wm: WidgetManager, widgetId: string) =
  ## Remove a widget by ID
  var idx = -1
  for i, w in wm.widgets:
    if w.id == widgetId:
      idx = i
      break
  
  if idx >= 0:
    let widget = wm.widgets[idx]
    
    # Clear references
    if wm.focusedWidget == widget:
      wm.focusedWidget = nil
    if wm.hoveredWidget == widget:
      wm.hoveredWidget = nil
    if wm.activeWidget == widget:
      wm.activeWidget = nil
    
    # Remove from lists
    wm.widgets.delete(idx)
    
    # Remove from tab order
    let tabIdx = wm.tabOrder.find(widgetId)
    if tabIdx >= 0:
      wm.tabOrder.delete(tabIdx)

proc getWidget*(wm: WidgetManager, id: string): Widget =
  ## Get widget by ID
  for widget in wm.widgets:
    if widget.id == id:
      return widget
  return nil

proc rebuildTabOrder*(wm: WidgetManager) =
  ## Rebuild tab order based on widget tabIndex values
  if not wm.autoTabOrder:
    return
  
  wm.tabOrder = @[]
  
  # Collect focusable widgets with valid tab indices
  var indexedWidgets: seq[tuple[index: int, id: string]] = @[]
  for widget in wm.widgets:
    if widget.focusable and widget.tabIndex >= 0:
      indexedWidgets.add((widget.tabIndex, widget.id))
  
  # Sort by tab index using algorithm.sort
  indexedWidgets.sort(proc (a, b: tuple[index: int, id: string]): int =
    result = cmp(a.index, b.index)
  )
  
  # Build tab order list
  for item in indexedWidgets:
    wm.tabOrder.add(item.id)

proc focusWidget*(wm: WidgetManager, widget: Widget) =
  ## Set focus to a specific widget
  if widget.isNil or not widget.enabled or not widget.focusable:
    return
  
  # Blur current focused widget
  if not wm.focusedWidget.isNil:
    if wm.focusedWidget.state == wsFocused:
      wm.focusedWidget.state = wsNormal
    if not wm.focusedWidget.onBlur.isNil:
      wm.focusedWidget.onBlur(wm.focusedWidget)
  
  # Focus new widget
  wm.focusedWidget = widget
  widget.state = wsFocused
  
  if not widget.onFocus.isNil:
    widget.onFocus(widget)

proc focusWidgetById*(wm: WidgetManager, id: string) =
  ## Set focus to a widget by ID
  let widget = wm.getWidget(id)
  if not widget.isNil:
    wm.focusWidget(widget)

proc focusNext*(wm: WidgetManager) =
  ## Focus next widget in tab order (Tab key)
  if wm.tabOrder.len == 0:
    wm.rebuildTabOrder()
  
  if wm.tabOrder.len == 0:
    return
  
  # Find current focused widget in tab order
  var currentIdx = -1
  if not wm.focusedWidget.isNil:
    for i, id in wm.tabOrder:
      if id == wm.focusedWidget.id:
        currentIdx = i
        break
  
  # Move to next widget (wrap around)
  let nextIdx = (currentIdx + 1) mod wm.tabOrder.len
  wm.focusWidgetById(wm.tabOrder[nextIdx])

proc focusPrev*(wm: WidgetManager) =
  ## Focus previous widget in tab order (Shift+Tab)
  if wm.tabOrder.len == 0:
    wm.rebuildTabOrder()
  
  if wm.tabOrder.len == 0:
    return
  
  # Find current focused widget in tab order
  var currentIdx = -1
  if not wm.focusedWidget.isNil:
    for i, id in wm.tabOrder:
      if id == wm.focusedWidget.id:
        currentIdx = i
        break
  
  # Move to previous widget (wrap around)
  let prevIdx = if currentIdx <= 0: wm.tabOrder.len - 1 else: currentIdx - 1
  wm.focusWidgetById(wm.tabOrder[prevIdx])

proc clearFocus*(wm: WidgetManager) =
  ## Remove focus from all widgets
  if not wm.focusedWidget.isNil:
    if wm.focusedWidget.state == wsFocused:
      wm.focusedWidget.state = wsNormal
    if not wm.focusedWidget.onBlur.isNil:
      wm.focusedWidget.onBlur(wm.focusedWidget)
    wm.focusedWidget = nil

proc updateHover*(wm: WidgetManager, mouseX, mouseY: int) =
  ## Update hover state based on mouse position
  wm.lastMouseX = mouseX
  wm.lastMouseY = mouseY
  
  var newHovered: Widget = nil
  
  # Find topmost widget under mouse (reverse order for z-order)
  for i in countdown(wm.widgets.len - 1, 0):
    let widget = wm.widgets[i]
    if widget.visible and widget.enabled and widget.contains(mouseX, mouseY):
      newHovered = widget
      break
  
  # Update hover states
  if wm.hoveredWidget != newHovered:
    # Remove hover from old widget
    if not wm.hoveredWidget.isNil:
      if wm.hoveredWidget.state == wsHovered:
        wm.hoveredWidget.state = wsNormal
    
    # Add hover to new widget (unless it's focused)
    wm.hoveredWidget = newHovered
    if not newHovered.isNil and newHovered.state != wsFocused:
      newHovered.state = wsHovered

proc update*(wm: WidgetManager, dt: float) =
  ## Update all widgets
  for widget in wm.widgets:
    if widget.visible:
      widget.update(dt)

proc render*(wm: WidgetManager, layer: Layer) =
  ## Render all visible widgets to a layer
  for widget in wm.widgets:
    if widget.visible:
      widget.render(layer)

proc handleInput*(wm: WidgetManager, event: InputEvent): bool =
  ## Handle input event
  ## Returns true if event was consumed by a widget
  
  # First, let the active widget handle input (if dragging, etc.)
  if not wm.activeWidget.isNil:
    if wm.activeWidget.handleInput(event):
      return true
  
  # Then, let the focused widget handle input
  if not wm.focusedWidget.isNil:
    if wm.focusedWidget.handleInput(event):
      return true
  
  # Finally, check other widgets (for mouse events, etc.)
  # Iterate in reverse order for proper z-order handling
  for i in countdown(wm.widgets.len - 1, 0):
    let widget = wm.widgets[i]
    if widget.visible and widget.enabled:
      if widget != wm.focusedWidget and widget != wm.activeWidget:
        if widget.handleInput(event):
          # If a widget handled a mouse click and is focusable, focus it
          if event.kind == MouseEvent and event.action == Press and widget.focusable:
            wm.focusWidget(widget)
          return true
  
  return false

# ================================================================
# LABEL WIDGET (Phase 2)
# ================================================================

type
  Label* = ref object of Widget
    ## Non-interactive text display widget
    text*: string                ## Text to display
    hAlign*: HAlign             ## Horizontal alignment (from layout module)
    vAlign*: VAlign             ## Vertical alignment (from layout module)
    wordWrap*: bool             ## Enable word wrapping
    padding*: int               ## Internal padding

proc newLabel*(id: string, x, y, w, h: int, text: string = ""): Label =
  ## Create a new label widget
  result = Label()
  result.id = id
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = false
  result.tabIndex = -1
  result.normalStyle = "label"
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  result.text = text
  result.hAlign = AlignLeft
  result.vAlign = AlignTop
  result.wordWrap = false
  result.padding = 0

method render*(label: Label, layer: Layer) =
  ## Render label to layer
  if not label.visible:
    return
  
  let style = label.resolveStyle()
  
  # Fill background
  for dy in 0 ..< label.height:
    for dx in 0 ..< label.width:
      layer.buffer.cells[(label.y + dy) * layer.buffer.width + (label.x + dx)] = Cell(ch: " ", style: style)
  
  if label.text.len == 0:
    return
  
  # Calculate text dimensions and position
  let availWidth = label.width - (label.padding * 2)
  let availHeight = label.height - (label.padding * 2)
  
  if availWidth <= 0 or availHeight <= 0:
    return
  
  # Simple text rendering (no wrapping for now)
  let textLen = label.text.len
  var renderX = label.x + label.padding
  var renderY = label.y + label.padding
  
  # Apply horizontal alignment
  case label.hAlign
  of AlignCenter:
    renderX = label.x + (label.width - textLen) div 2
  of AlignRight:
    renderX = label.x + label.width - textLen - label.padding
  of AlignLeft, AlignJustify:  # Justify treated as left for single-line text
    renderX = label.x + label.padding
  
  # Apply vertical alignment
  case label.vAlign
  of AlignMiddle:
    renderY = label.y + label.height div 2
  of AlignBottom:
    renderY = label.y + label.height - 1 - label.padding
  of AlignTop:
    renderY = label.y + label.padding
  
  # Clamp to widget bounds
  renderX = max(label.x, min(renderX, label.x + label.width - 1))
  renderY = max(label.y, min(renderY, label.y + label.height - 1))
  
  # Render text (truncate if too long)
  let maxLen = min(textLen, label.width - (renderX - label.x))
  if maxLen > 0:
    layer.buffer.writeText(renderX, renderY, label.text[0 ..< maxLen], style)

proc setText*(label: Label, text: string) =
  ## Update label text
  label.text = text

# ================================================================
# BUTTON WIDGET (Phase 2)
# ================================================================

type
  Button* = ref object of Widget
    ## Interactive button widget
    label*: string              ## Button text
    hAlign*: HAlign             ## Text horizontal alignment
    vAlign*: VAlign             ## Text vertical alignment
    padding*: int               ## Internal padding
    drawBorder*: bool           ## Whether to draw a border
    borderStyle*: string        ## Named style for border (optional)

proc newButton*(id: string, x, y, w, h: int, label: string = "Button"): Button =
  ## Create a new button widget
  result = Button()
  result.id = id
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = true
  result.tabIndex = 0
  result.normalStyle = "button.normal"
  result.focusedStyle = "button.focused"
  result.hoverStyle = "button.hover"
  result.disabledStyle = "button.disabled"
  result.activeStyle = "button.active"
  result.useOverride = false
  # Don't initialize styleSheet here - will be set by addWidget
  result.label = label
  result.hAlign = AlignCenter
  result.vAlign = AlignMiddle
  result.padding = 1
  result.drawBorder = true
  result.borderStyle = ""

method render*(btn: Button, layer: Layer) =
  ## Render button to layer
  if not btn.visible:
    return
  
  # Safety check: ensure button fits in buffer
  if btn.x < 0 or btn.y < 0:
    return
  if btn.x + btn.width > layer.buffer.width or btn.y + btn.height > layer.buffer.height:
    return
  
  let style = btn.resolveStyle()
  
  # Fill background
  for dy in 0 ..< btn.height:
    for dx in 0 ..< btn.width:
      let idx = (btn.y + dy) * layer.buffer.width + (btn.x + dx)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: " ", style: style)
  
  # Draw border if enabled
  if btn.drawBorder and btn.width >= 2 and btn.height >= 2:
    # Top border
    for dx in 0 ..< btn.width:
      let idx = (btn.y) * layer.buffer.width + (btn.x + dx)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "─", style: style)
    
    # Bottom border
    for dx in 0 ..< btn.width:
      let idx = (btn.y + btn.height - 1) * layer.buffer.width + (btn.x + dx)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "─", style: style)
    
    # Left border
    for dy in 0 ..< btn.height:
      let idx = (btn.y + dy) * layer.buffer.width + (btn.x)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "│", style: style)
    
    # Right border
    for dy in 0 ..< btn.height:
      let idx = (btn.y + dy) * layer.buffer.width + (btn.x + btn.width - 1)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "│", style: style)
    
    # Corners
    block:
      let idx = (btn.y) * layer.buffer.width + (btn.x)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "┌", style: style)
    block:
      let idx = (btn.y) * layer.buffer.width + (btn.x + btn.width - 1)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "┐", style: style)
    block:
      let idx = (btn.y + btn.height - 1) * layer.buffer.width + (btn.x)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "└", style: style)
    block:
      let idx = (btn.y + btn.height - 1) * layer.buffer.width + (btn.x + btn.width - 1)
      if idx >= 0 and idx < layer.buffer.cells.len:
        layer.buffer.cells[idx] = Cell(ch: "┘", style: style)
  
  # Render label text
  if btn.label.len > 0:
    let textLen = btn.label.len
    var renderX = btn.x + btn.padding
    var renderY = btn.y + btn.padding
    
    # Apply horizontal alignment
    case btn.hAlign
    of AlignCenter:
      renderX = btn.x + (btn.width - textLen) div 2
    of AlignRight:
      renderX = btn.x + btn.width - textLen - btn.padding
    of AlignLeft, AlignJustify:  # Justify treated as left for buttons
      renderX = btn.x + btn.padding
    
    # Apply vertical alignment
    case btn.vAlign
    of AlignMiddle:
      renderY = btn.y + btn.height div 2
    of AlignBottom:
      renderY = btn.y + btn.height - 1 - btn.padding
    of AlignTop:
      renderY = btn.y + btn.padding
    
    # Clamp to widget bounds
    renderX = max(btn.x, min(renderX, btn.x + btn.width - 1))
    renderY = max(btn.y, min(renderY, btn.y + btn.height - 1))
    
    # Render text (truncate if too long)
    let maxLen = min(textLen, btn.width - (renderX - btn.x))
    if maxLen > 0:
      layer.buffer.writeText(renderX, renderY, btn.label[0 ..< maxLen], style)

method handleInput*(btn: Button, event: InputEvent): bool =
  ## Handle input events for button
  if not btn.enabled or not btn.visible:
    return false
  
  # Handle mouse clicks
  case event.kind
  of MouseEvent:
    if event.button == Left:
      case event.action
      of Press:
        if btn.contains(event.mouseX, event.mouseY):
          btn.state = wsActive
          return true
      of Release:
        if btn.state == wsActive:
          let inBounds = btn.contains(event.mouseX, event.mouseY)
          btn.state = if inBounds: wsHovered else: wsNormal
          # Trigger onClick if released within button bounds
          if inBounds and not btn.onClick.isNil:
            btn.onClick(btn)
          return true
      else:
        discard
  
  # Handle keyboard activation (Space or Enter when focused)
  of KeyEvent:
    if btn.state == wsFocused and event.keyAction == Press:
      if event.keyCode == ord(' ') or event.keyCode == ord('\r') or event.keyCode == ord('\n'):
        # Trigger click
        if not btn.onClick.isNil:
          btn.onClick(btn)
        return true
  
  else:
    discard
  
  return false

proc setLabel*(btn: Button, label: string) =
  ## Update button label text
  btn.label = label

# ================================================================
# CHECKBOX WIDGET (Phase 3)
# ================================================================

type
  CheckBox* = ref object of Widget
    ## Boolean toggle widget (checkbox or radio button)
    checked*: bool              ## Current checked state
    label*: string              ## Label text next to checkbox
    group*: string              ## Radio button group (empty for checkbox)
    radio*: bool                ## True for radio button, false for checkbox
    
    # Visual customization
    checkedChar*: string        ## Character when checked (e.g., "✓", "●", "█")
    uncheckedChar*: string      ## Character when unchecked (e.g., "☐", "○", "▯")
    boxWidth*: int              ## Width of the check box itself
    spacing*: int               ## Space between box and label

# Forward declarations
proc toggle*(cb: CheckBox)
proc setChecked*(cb: CheckBox, checked: bool)

proc newCheckBox*(id: string, x, y: int, label: string = "", checked: bool = false): CheckBox =
  ## Create a new checkbox widget
  result = CheckBox()
  result.id = id
  result.x = x
  result.y = y
  result.width = 3 + label.len  # [X] + label
  result.height = 1
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = true
  result.tabIndex = 0
  result.normalStyle = "checkbox.normal"
  result.focusedStyle = "checkbox.focused"
  result.hoverStyle = "checkbox.hover"
  result.disabledStyle = "checkbox.disabled"
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  result.checked = checked
  result.label = label
  result.group = ""
  result.radio = false
  result.checkedChar = "✓"
  result.uncheckedChar = " "
  result.boxWidth = 3
  result.spacing = 1

proc newRadioButton*(id: string, x, y: int, label: string = "", group: string = "default"): CheckBox =
  ## Create a new radio button widget (checkbox in radio mode)
  result = newCheckBox(id, x, y, label, false)
  result.radio = true
  result.group = group
  result.checkedChar = "●"
  result.uncheckedChar = "○"
  result.normalStyle = "radio.normal"
  result.focusedStyle = "radio.focused"
  result.hoverStyle = "radio.hover"

method render*(cb: CheckBox, layer: Layer) =
  ## Render checkbox/radio button to layer
  if not cb.visible:
    return
  
  let style = cb.resolveStyle()
  
  # Render box with check/uncheck indicator
  let indicator = if cb.checked: cb.checkedChar else: cb.uncheckedChar
  let boxText = "[" & indicator & "]"
  
  # Render box
  layer.buffer.writeText(cb.x, cb.y, boxText, style)
  
  # Render label if present
  if cb.label.len > 0:
    let labelX = cb.x + cb.boxWidth + cb.spacing
    layer.buffer.writeText(labelX, cb.y, cb.label, style)

method handleInput*(cb: CheckBox, event: InputEvent): bool =
  ## Handle input events for checkbox/radio button
  if not cb.enabled or not cb.visible:
    return false
  
  # Handle mouse clicks
  case event.kind
  of MouseEvent:
    if event.button == Left and event.action == Press:
      if cb.contains(event.mouseX, event.mouseY):
        cb.toggle()
        return true
  
  # Handle keyboard activation (Space when focused)
  of KeyEvent:
    if cb.state == wsFocused and event.keyAction == Press:
      if event.keyCode == ord(' '):
        cb.toggle()
        return true
  
  else:
    discard
  
  return false

proc toggle*(cb: CheckBox) =
  ## Toggle checkbox state
  if cb.radio and cb.checked:
    # Radio buttons can't be unchecked by clicking again
    return
  
  cb.checked = not cb.checked
  
  # Trigger onChange callback
  if not cb.onChange.isNil:
    cb.onChange(cb)

proc setChecked*(cb: CheckBox, checked: bool) =
  ## Set checkbox state programmatically
  if cb.checked != checked:
    cb.checked = checked
    if not cb.onChange.isNil:
      cb.onChange(cb)

proc uncheckRadioGroup*(wm: WidgetManager, group: string, exceptId: string = "") =
  ## Uncheck all radio buttons in a group except the specified one
  for widget in wm.widgets:
    if widget of CheckBox:
      let cb = CheckBox(widget)
      if cb.radio and cb.group == group and cb.id != exceptId:
        cb.checked = false

# ================================================================
# SLIDER WIDGET (Phase 3)
# ================================================================

type
  Orientation* = enum
    Horizontal, Vertical
  
  Slider* = ref object of Widget
    ## Numeric value slider widget
    value*: float               ## Current value
    minValue*, maxValue*: float ## Value range
    step*: float                ## Step increment (0 for continuous)
    showValue*: bool            ## Display numeric value
    orientation*: Orientation   ## Horizontal or vertical slider
    
    # Visual customization
    trackChar*: string          ## Character for empty track
    fillChar*: string           ## Character for filled track
    handleChar*: string         ## Character for slider handle
    
    # Internal state
    dragging*: bool             ## Currently being dragged
    dragStartX*, dragStartY*: int  ## Drag start position

# Forward declarations
proc updateValueFromPosition*(slider: Slider, mouseX, mouseY: int)
proc setValue*(slider: Slider, value: float)

proc newSlider*(id: string, x, y, length: int, minVal: float = 0.0, maxVal: float = 100.0): Slider =
  ## Create a new horizontal slider widget
  result = Slider()
  result.id = id
  result.x = x
  result.y = y
  result.width = length
  result.height = 1
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = true
  result.tabIndex = 0
  result.normalStyle = "slider.normal"
  result.focusedStyle = "slider.focused"
  result.hoverStyle = "slider.hover"
  result.activeStyle = "slider.active"
  result.disabledStyle = "slider.disabled"
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  result.value = minVal
  result.minValue = minVal
  result.maxValue = maxVal
  result.step = 0.0  # Continuous by default
  result.showValue = true
  result.orientation = Horizontal
  result.trackChar = "─"
  result.fillChar = "━"
  result.handleChar = "●"
  result.dragging = false

proc newVerticalSlider*(id: string, x, y, length: int, minVal: float = 0.0, maxVal: float = 100.0): Slider =
  ## Create a new vertical slider widget
  result = newSlider(id, x, y, length, minVal, maxVal)
  result.width = 1
  result.height = length
  result.orientation = Vertical
  result.trackChar = "│"
  result.fillChar = "┃"

method render*(slider: Slider, layer: Layer) =
  ## Render slider to layer
  if not slider.visible:
    return
  
  let style = slider.resolveStyle()
  
  # Calculate handle position based on value
  let range = slider.maxValue - slider.minValue
  let normalized = if range > 0.0: (slider.value - slider.minValue) / range else: 0.0
  
  if slider.orientation == Horizontal:
    let trackLength = slider.width
    let handlePos = int(normalized * float(trackLength - 1))
    
    # Render track
    for i in 0 ..< trackLength:
      let ch = if i < handlePos: slider.fillChar
               elif i == handlePos: slider.handleChar
               else: slider.trackChar
      layer.buffer.cells[(slider.y) * layer.buffer.width + (slider.x + i)] = Cell(ch: ch, style: style)
    
    # Render value if enabled
    if slider.showValue:
      let valueStr = $int(slider.value)
      let valueX = slider.x + trackLength + 2
      layer.buffer.writeText(valueX, slider.y, valueStr, style)
  
  else:  # Vertical
    let trackLength = slider.height
    let handlePos = trackLength - 1 - int(normalized * float(trackLength - 1))
    
    # Render track (top to bottom)
    for i in 0 ..< trackLength:
      let ch = if i > handlePos: slider.fillChar
               elif i == handlePos: slider.handleChar
               else: slider.trackChar
      layer.buffer.cells[(slider.y + i) * layer.buffer.width + (slider.x)] = Cell(ch: ch, style: style)
    
    # Render value if enabled
    if slider.showValue:
      let valueStr = $int(slider.value)
      let valueY = slider.y + trackLength + 1
      layer.buffer.writeText(slider.x, valueY, valueStr, style)

method handleInput*(slider: Slider, event: InputEvent): bool =
  ## Handle input events for slider
  if not slider.enabled or not slider.visible:
    return false
  
  case event.kind
  of MouseEvent:
    case event.action
    of Press:
      if event.button == Left:
        if slider.contains(event.mouseX, event.mouseY):
          slider.dragging = true
          slider.state = wsActive
          slider.dragStartX = event.mouseX
          slider.dragStartY = event.mouseY
          slider.updateValueFromPosition(event.mouseX, event.mouseY)
          return true
    
    of Release:
      if slider.dragging:
        slider.dragging = false
        slider.state = if slider.contains(event.mouseX, event.mouseY): wsHovered else: wsNormal
        return true
    
    else:
      discard
  
  of MouseMoveEvent:
    # Handle dragging on mouse move
    if slider.dragging:
      slider.updateValueFromPosition(event.moveX, event.moveY)
      return true
  
  of KeyEvent:
    if slider.state == wsFocused and event.keyAction == Press:
      var handled = false
      let stepSize = if slider.step > 0.0: slider.step else: (slider.maxValue - slider.minValue) / 20.0
      
      case event.keyCode
      of INPUT_LEFT, INPUT_DOWN:
        slider.setValue(slider.value - stepSize)
        handled = true
      of INPUT_RIGHT, INPUT_UP:
        slider.setValue(slider.value + stepSize)
        handled = true
      of INPUT_HOME:
        slider.setValue(slider.minValue)
        handled = true
      of INPUT_END:
        slider.setValue(slider.maxValue)
        handled = true
      else:
        discard
      
      if handled:
        return true
  
  else:
    discard
  
  return false

proc updateValueFromPosition*(slider: Slider, mouseX, mouseY: int) =
  ## Update slider value based on mouse position
  var newValue: float
  
  if slider.orientation == Horizontal:
    let relX = mouseX - slider.x
    let normalized = float(relX) / float(slider.width - 1)
    newValue = slider.minValue + normalized * (slider.maxValue - slider.minValue)
  else:  # Vertical
    let relY = mouseY - slider.y
    let normalized = 1.0 - (float(relY) / float(slider.height - 1))
    newValue = slider.minValue + normalized * (slider.maxValue - slider.minValue)
  
  slider.setValue(newValue)

proc setValue*(slider: Slider, value: float) =
  ## Set slider value with clamping and step snapping
  var newValue = value
  
  # Clamp to range
  newValue = max(slider.minValue, min(slider.maxValue, newValue))
  
  # Apply step if specified
  if slider.step > 0.0:
    let steps = round((newValue - slider.minValue) / slider.step)
    newValue = slider.minValue + steps * slider.step
  
  # Update if changed
  if newValue != slider.value:
    slider.value = newValue
    if not slider.onChange.isNil:
      slider.onChange(slider)

# ================================================================
# UTILITY FUNCTIONS
# ================================================================

proc newWidget*(id: string, x, y, w, h: int): Widget =
  ## Create a new base widget
  result = Widget()
  result.id = id
  result.x = x
  result.y = y
  result.width = w
  result.height = h
  result.visible = true
  result.enabled = true
  result.state = wsNormal
  result.focusable = false
  result.tabIndex = -1
  result.normalStyle = ""
  result.focusedStyle = ""
  result.hoverStyle = ""
  result.disabledStyle = ""
  result.activeStyle = ""
  result.useOverride = false
  result.styleSheet = initTable[string, StyleConfig]()
  result.userData = nil

proc setEnabled*(w: Widget, enabled: bool) =
  ## Enable or disable a widget
  w.enabled = enabled
  if enabled:
    if w.state == wsDisabled:
      w.state = wsNormal
  else:
    w.state = wsDisabled

proc setVisible*(w: Widget, visible: bool) =
  ## Show or hide a widget
  w.visible = visible

proc setBounds*(w: Widget, x, y, width, height: int) =
  ## Set widget position and size
  w.x = x
  w.y = y
  w.width = width
  w.height = height

proc setPosition*(w: Widget, x, y: int) =
  ## Set widget position
  w.x = x
  w.y = y

proc setSize*(w: Widget, width, height: int) =
  ## Set widget size
  w.width = width
  w.height = height
