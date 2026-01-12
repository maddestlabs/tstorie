---
title: "Advanced TUI Widgets Demo"
minWidth: 80
minHeight: 40
theme: "neotopia"
---

# Advanced TUI Widgets Showcase

This demo showcases the new advanced TUI widgets: radio buttons, dropdowns, lists, tabs, and more!

```nim on:init
# ===================================================================
# State Management
# ===================================================================
# Radio button group
var radioOptions = @["Small", "Medium", "Large"]
var radioSelected = 1
var radioFocusIndex = -1

# Dropdown
var dropdownOptions = @["Option 1", "Option 2", "Option 3", "Option 4"]
var dropdownSelected = 0
var dropdownOpen = false
var dropdownFocused = false

# List widget
var listItems = @["Item A", "Item B", "Item C", "Item D", "Item E", "Item F", "Item G", "Item H", "Item I", "Item J"]
var listSelected = 0
var listScrollOffset = 0
var listFocused = false

# Tab container
var tabs = @["Settings", "Profile", "Help"]
var activeTab = 0

# Text area
var textLines = @["Line 1: Hello!", "Line 2: This is a", "Line 3: multi-line", "Line 4: text area!"]
var textCursorLine = 0
var textCursorCol = 0
var textScrollY = 0
var textAreaFocused = false

# Form with enhanced text box
var formName = ""
var formNameCursor = 0
var formNameScroll = 0
var formEmail = ""
var formEmailCursor = 0
var formEmailScroll = 0
var formFocusIndex = 0

# Focus areas: 0=radio, 1=dropdown, 2=list, 3=form, 4=textarea
var focusArea = 0
var message = "Tab to cycle focus | Arrow keys to navigate | Space/Enter to select"

# Helper function for string slicing (since substr is not available)
proc sliceStr(s: string, startIdx: int, endIdx: int): string =
  if startIdx < 0 or startIdx >= len(s):
    return ""
  let actualEnd = min(endIdx + 1, len(s))
  if startIdx >= actualEnd:
    return ""
  var result = ""
  var i = startIdx
  while i < actualEnd:
    result = result & chr(ord(s[i]))
    i = i + 1
  return result
```

```nim on:render
# ===================================================================
# Render
# ===================================================================
clear()

let w = getWidth()
let h = getHeight()

# Title
drawLabel(0, 5, 2, "Advanced TUI Widgets - Tab to cycle focus areas", getStyle("info"))
drawLabel(0, 5, h - 2, message, getStyle("warning"))

# Left column - Radio buttons
drawPanel(0, 5, 4, 25, 8, "Size Selection", "single")
var dy = 0
while dy < len(radioOptions):
  let isSelected = dy == radioSelected
  let isFocused = focusArea == 0 and dy == radioFocusIndex
  drawRadioButton(0, 7, 6 + dy, radioOptions[dy], isSelected, isFocused)
  dy = dy + 1

# Dropdown
drawPanel(0, 5, 13, 25, 9, "Dropdown Menu", "single")
drawDropdown(0, 7, 15, 21, dropdownOptions, dropdownSelected, dropdownOpen, focusArea == 1)

# Right column - List
drawPanel(0, 35, 4, 30, 12, "Scrollable List", "single")
drawList(0, 37, 6, 26, 9, listItems, listSelected, listScrollOffset, focusArea == 2)

# Tab container
drawTabBar(0, 35, 17, 40, tabs, activeTab)
drawTabContent(0, 35, 19, 40, 8, "single")

# Tab content varies by active tab
if activeTab == 0:
  drawLabel(0, 37, 21, "Settings Panel", getStyle("info"))
  drawLabel(0, 37, 22, "Configure your preferences here", getStyle("default"))
elif activeTab == 1:
  drawLabel(0, 37, 21, "Profile Panel", getStyle("info"))
  drawLabel(0, 37, 22, "View and edit your profile", getStyle("default"))
else:
  drawLabel(0, 37, 21, "Help Panel", getStyle("info"))
  drawLabel(0, 37, 22, "Get assistance and documentation", getStyle("default"))

# Bottom - Form with enhanced text boxes
drawPanel(0, 5, 23, 65, 12, "Contact Form", "single")

# Use form layout helper
let formLayouts = layoutForm(7, 25, 10, 30, 3, 1, 2)
let nameLayout = formLayouts[0]
let emailLayout = formLayouts[1]

# Name field
drawLabel(0, nameLayout.labelX, nameLayout.labelY, "Name:", getStyle("info"))
formNameScroll = drawTextBoxWithScroll(0, nameLayout.fieldX, nameLayout.fieldY, 30, 3, 
                                       formName, formNameCursor, formNameScroll, 
                                       focusArea == 3 and formFocusIndex == 0, "single")

# Email field
drawLabel(0, emailLayout.labelX, emailLayout.labelY, "Email:", getStyle("info"))
formEmailScroll = drawTextBoxWithScroll(0, emailLayout.fieldX, emailLayout.fieldY, 30, 3,
                                        formEmail, formEmailCursor, formEmailScroll,
                                        focusArea == 3 and formFocusIndex == 1, "single")

# Text area in bottom right
drawPanel(0, 5, 36, 40, 8, "Multi-line Text", "single")
drawTextArea(0, 7, 38, 36, 5, textLines, textCursorLine, textCursorCol, textScrollY, focusArea == 4)
```

```nim on:input
# ===================================================================
# Key Input Handling
# ===================================================================
if event.type == "key":
  let keyCode = event.keyCode
  let isShift = contains(event.mods, "shift")
  
  # Tab - cycle focus areas (support Shift+Tab for reverse)
  if keyCode == 9:
    if isShift:
      focusArea = (focusArea - 1 + 5) mod 5
    else:
      focusArea = (focusArea + 1) mod 5
    
    # Reset sub-focus when changing areas
    radioFocusIndex = if focusArea == 0: 0 else: -1
    message = "Focus area: " & str(focusArea) & (if isShift: " (Shift+Tab)" else: " (Tab)")
    return true
  
  # Handle input based on focus area
  if focusArea == 0:  # Radio buttons
    if keyCode == 10000 or keyCode == 10001:  # Up/Down arrows
      if keyCode == 10000:  # Up
        radioFocusIndex = (radioFocusIndex - 1 + len(radioOptions)) mod len(radioOptions)
      elif keyCode == 10001:  # Down
        radioFocusIndex = (radioFocusIndex + 1) mod len(radioOptions)
      return true
    
    if keyCode == 32 or keyCode == 13:  # Space or Enter
      if radioFocusIndex >= 0:
        radioSelected = radioFocusIndex
        message = "Selected: " & radioOptions[radioSelected]
      return true
  
  elif focusArea == 1:  # Dropdown
    if keyCode == 32 or keyCode == 13:  # Space or Enter
      dropdownOpen = not dropdownOpen
      message = if dropdownOpen: "Dropdown opened" else: "Dropdown closed"
      return true
    
    if dropdownOpen and (keyCode == 10000 or keyCode == 10001):  # Up/Down
      if keyCode == 10000:  # Up
        dropdownSelected = (dropdownSelected - 1 + len(dropdownOptions)) mod len(dropdownOptions)
      elif keyCode == 10001:  # Down
        dropdownSelected = (dropdownSelected + 1) mod len(dropdownOptions)
      message = "Selected: " & dropdownOptions[dropdownSelected]
      return true
  
  elif focusArea == 2:  # List
    if keyCode == 10000 or keyCode == 10001:  # Up/Down arrows
      if keyCode == 10000:  # Up
        if listSelected > 0:
          listSelected = listSelected - 1
          # Auto-scroll when selection moves out of view
          if listSelected < listScrollOffset:
            listScrollOffset = listSelected
          message = "Selected: " & listItems[listSelected]
      elif keyCode == 10001:  # Down
        if listSelected < len(listItems) - 1:
          listSelected = listSelected + 1
          # Auto-scroll when selection moves out of view
          if listSelected >= listScrollOffset + 9:
            listScrollOffset = listSelected - 8
          message = "Selected: " & listItems[listSelected]
      return true
    
    # Page Up/Down for faster scrolling
    if keyCode == 33:  # Page Up
      listSelected = max(0, listSelected - 5)
      listScrollOffset = max(0, listScrollOffset - 5)
      message = "Selected: " & listItems[listSelected]
      return true
    elif keyCode == 34:  # Page Down
      listSelected = min(len(listItems) - 1, listSelected + 5)
      if listSelected >= listScrollOffset + 9:
        listScrollOffset = min(len(listItems) - 9, listScrollOffset + 5)
      message = "Selected: " & listItems[listSelected]
      return true
  
  elif focusArea == 3:  # Form
    # Arrow keys to switch between fields
    if keyCode == 10000 or keyCode == 10001:  # Up/Down
      if keyCode == 10000:  # Up
        formFocusIndex = (formFocusIndex - 1 + 2) mod 2
      elif keyCode == 10001:  # Down
        formFocusIndex = (formFocusIndex + 1) mod 2
      return true
    
    # Backspace
    if keyCode == 127 or keyCode == 8:
      if formFocusIndex == 0:
        let result = handleBackspace(formNameCursor, formName)
        formNameCursor = result[0]
        formName = result[1]
      else:
        let result = handleBackspace(formEmailCursor, formEmail)
        formEmailCursor = result[0]
        formEmail = result[1]
      return true
  
  elif focusArea == 4:  # Text area
    # Arrow key navigation
    if keyCode == 10000:  # Up
      if textCursorLine > 0:
        textCursorLine = textCursorLine - 1
        # Clamp cursor column to new line length
        if textCursorCol > len(textLines[textCursorLine]):
          textCursorCol = len(textLines[textCursorLine])
      return true
    elif keyCode == 10001:  # Down
      if textCursorLine < len(textLines) - 1:
        textCursorLine = textCursorLine + 1
        # Clamp cursor column to new line length
        if textCursorCol > len(textLines[textCursorLine]):
          textCursorCol = len(textLines[textCursorLine])
      return true
    elif keyCode == 10002:  # Left
      if textCursorCol > 0:
        textCursorCol = textCursorCol - 1
      elif textCursorLine > 0:
        textCursorLine = textCursorLine - 1
        textCursorCol = len(textLines[textCursorLine])
      return true
    elif keyCode == 10003:  # Right
      if textCursorCol < len(textLines[textCursorLine]):
        textCursorCol = textCursorCol + 1
      elif textCursorLine < len(textLines) - 1:
        textCursorLine = textCursorLine + 1
        textCursorCol = 0
      return true
    
    # Backspace
    if keyCode == 127 or keyCode == 8:
      if textCursorCol > 0:
        # Delete character before cursor
        let line = textLines[textCursorLine]
        textLines[textCursorLine] = sliceStr(line, 0, textCursorCol - 2) & sliceStr(line, textCursorCol, len(line) - 1)
        textCursorCol = textCursorCol - 1
      elif textCursorLine > 0:
        # Merge with previous line
        let currentLine = textLines[textCursorLine]
        textCursorCol = len(textLines[textCursorLine - 1])
        textLines[textCursorLine - 1] = textLines[textCursorLine - 1] & currentLine
        # Remove current line
        var newLines = @[""]
        var i = 0
        while i < len(textLines):
          if i != textCursorLine:
            push(newLines, textLines[i])
          i = i + 1
        textLines = newLines
        textCursorLine = textCursorLine - 1
      return true
    
    # Enter - insert new line
    if keyCode == 13:
      let currentLine = textLines[textCursorLine]
      let beforeCursor = sliceStr(currentLine, 0, textCursorCol - 1)
      let afterCursor = sliceStr(currentLine, textCursorCol, len(currentLine) - 1)
      textLines[textCursorLine] = beforeCursor
      # Insert new line after current
      var newLines = @[""]
      var i = 0
      while i <= len(textLines):
        if i <= textCursorLine:
          push(newLines, textLines[i])
        elif i == textCursorLine + 1:
          push(newLines, afterCursor)
        elif i < len(textLines):
          push(newLines, textLines[i])
        i = i + 1
      textLines = newLines
      textCursorLine = textCursorLine + 1
      textCursorCol = 0
      return true
  
  return false

# ===================================================================
# Text Input Handling
# ===================================================================
elif event.type == "text":
  if focusArea == 3:  # Form
    if formFocusIndex == 0:
      let result = handleTextInput(event.text, formNameCursor, formName)
      formNameCursor = result[0]
      formName = result[1]
    else:
      let result = handleTextInput(event.text, formEmailCursor, formEmail)
      formEmailCursor = result[0]
      formEmail = result[1]
    return true
  
  elif focusArea == 4:  # Text area
    # Insert text at cursor position
    let currentLine = textLines[textCursorLine]
    let beforeCursor = sliceStr(currentLine, 0, textCursorCol - 1)
    let afterCursor = sliceStr(currentLine, textCursorCol, len(currentLine) - 1)
    textLines[textCursorLine] = beforeCursor & event.text & afterCursor
    textCursorCol = textCursorCol + len(event.text)
    return true
  
  return false

# ===================================================================
# Mouse Input Handling
# ===================================================================
elif event.type == "mouse":
  let mx = event.x
  let my = event.y
  let action = event.action
  
  if action == "press":
    # Check which area was clicked
    # Radio buttons
    if mx >= 5 and mx < 30 and my >= 4 and my < 12:
      focusArea = 0
      let radioY = my - 6
      if radioY >= 0 and radioY < len(radioOptions):
        radioFocusIndex = radioY
        radioSelected = radioY
        message = "Selected: " & radioOptions[radioSelected]
      return true
    
    # Dropdown
    if mx >= 5 and mx < 30 and my >= 13 and my < 22:
      focusArea = 1
      dropdownFocused = true
      if my == 15:  # Clicked on dropdown header
        dropdownOpen = not dropdownOpen
        message = if dropdownOpen: "Dropdown opened" else: "Dropdown closed"
      elif dropdownOpen and my >= 16 and my < 16 + len(dropdownOptions):
        let optionIndex = my - 16
        if optionIndex >= 0 and optionIndex < len(dropdownOptions):
          dropdownSelected = optionIndex
          dropdownOpen = false
          message = "Selected: " & dropdownOptions[dropdownSelected]
      return true
    
    # List (clickable items)
    if mx >= 35 and mx < 65 and my >= 4 and my < 16:
      focusArea = 2
      let itemY = my - 6
      if itemY >= 0 and itemY < 9:
        let itemIndex = listScrollOffset + itemY
        if itemIndex < len(listItems):
          listSelected = itemIndex
          message = "Selected: " & listItems[listSelected]
      return true
  
  # Handle mouse wheel for list scrolling
  if action == "wheel":
    if mx >= 35 and mx < 65 and my >= 4 and my < 16:
      focusArea = 2
      # event.wheelDelta: positive = scroll up, negative = scroll down
      if event.wheelDelta > 0:
        # Scroll up
        if listScrollOffset > 0:
          listScrollOffset = listScrollOffset - 1
          if listSelected > listScrollOffset + 8:
            listSelected = listScrollOffset + 8
          message = "Scrolled up: " & listItems[listSelected]
      else:
        # Scroll down
        if listScrollOffset < len(listItems) - 9:
          listScrollOffset = listScrollOffset + 1
          if listSelected < listScrollOffset:
            listSelected = listScrollOffset
          message = "Scrolled down: " & listItems[listSelected]
      return true
    
  # Tabs
  if action == "press":
    if mx >= 35 and mx < 75 and my >= 17 and my < 19:
      # Simple tab hit detection
      let relX = mx - 36
      if relX < 10:
        activeTab = 0
      elif relX < 20:
        activeTab = 1
      else:
        activeTab = 2
      message = "Active tab: " & tabs[activeTab]
      return true
    
    # Form clicks
    if mx >= 5 and mx < 70 and my >= 23 and my < 35:
      focusArea = 3
      if my >= 25 and my < 28:
        formFocusIndex = 0
      elif my >= 29 and my < 32:
        formFocusIndex = 1
      message = "Form field focused"
      return true
    
    # Text area clicks
    if mx >= 5 and mx < 45 and my >= 36 and my < 44:
      focusArea = 4
      # Could calculate cursor position from click coordinates here
      message = "Text area focused"
      return true
  
  return false

return false
```

## Features Demonstrated

### New Widgets:
- **Radio Buttons** - Single selection from multiple options
- **Dropdown Menu** - Expandable selection widget
- **Scrollable List** - Long list with keyboard navigation
- **Tab Container** - Multi-panel interface
- **Enhanced Text Box** - Horizontal scrolling for long text
- **Text Area** - Multi-line text editing
- **Form Layout** - Automatic field positioning

### New Helper Functions:
- `drawRadioButton()` / `drawRadioGroup()` - Radio button widgets
- `drawDropdown()` - Dropdown/select widget
- `drawList()` - Scrollable list with selection
- `drawTabBar()` / `drawTabContent()` - Tabbed interface
- `drawTextArea()` - Multi-line text editor
- `drawTextBoxWithScroll()` - Auto-scrolling text input
- `layoutForm()` - Automatic form layout
- `handleTextInput()` / `handleBackspace()` - Input helpers

All widgets are theme-aware and integrate seamlessly with the existing TUI system!
