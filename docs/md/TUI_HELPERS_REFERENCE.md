# TUI Helpers Reference Guide

Complete reference for all TUI helper functions available in TStorie.

## Table of Contents

1. [Box Drawing](#box-drawing)
2. [Text Helpers](#text-helpers)
3. [Hit Testing](#hit-testing)
4. [Basic Widgets](#basic-widgets)
5. [Advanced Widgets](#advanced-widgets)
6. [Input Handling](#input-handling)
7. [Layout Helpers](#layout-helpers)

---

## Box Drawing

### `drawBoxSingle(layer, x, y, w, h, style)`
Draw a box with single-line Unicode borders (┌─┐│└┘).

### `drawBoxDouble(layer, x, y, w, h, style)`
Draw a box with double-line Unicode borders (╔═╗║╚╝).

### `drawBoxRounded(layer, x, y, w, h, style)`
Draw a box with rounded corners (╭─╮│╰╯).

### `drawBoxSimple(layer, x, y, w, h, style)`
Draw a box with ASCII characters (+-+||+-+) for compatibility.

### `fillBox(layer, x, y, w, h, ch, style)`
Fill a rectangular area with a character.

---

## Text Helpers

### `centerTextX(text, boxX, boxWidth) -> int`
Calculate X position to center text horizontally in a box.

### `centerTextY(boxY, boxHeight) -> int`
Calculate Y position to center text vertically in a box.

### `drawCenteredText(layer, x, y, w, h, text, style)`
Draw text centered both horizontally and vertically in a box.

### `drawLabel(layer, x, y, text, style)`
Draw a simple text label at a position.

### `truncateText(text, maxWidth) -> string`
Truncate text to fit maxWidth, adding "..." if needed.

---

## Hit Testing

### `pointInRect(px, py, rx, ry, rw, rh) -> bool`
Check if a point is inside a rectangle.

### `findClickedWidget(mouseX, mouseY, widgetX[], widgetY[], widgetW[], widgetH[]) -> int`
Find which widget was clicked from arrays of widget bounds. Returns index or -1.

---

## Basic Widgets

### `drawButton(layer, x, y, w, h, label, isFocused, isPressed, borderStyle)`
Draw a button widget.
- `borderStyle`: "single", "double", "rounded", or "simple"
- `isPressed`: Fill button when true

### `drawCheckBox(layer, x, y, label, isChecked, isFocused)`
Draw a checkbox with label: `[X] Label` or `[ ] Label`

### `drawSlider(layer, x, y, w, value, minVal, maxVal, isFocused)`
Draw a horizontal slider with handle (─────█───).

### `drawTextBox(layer, x, y, w, h, content, cursorPos, isFocused, borderStyle)`
Draw a single-line text input box with cursor.

### `drawPanel(layer, x, y, w, h, title, borderStyle)`
Draw a titled panel/frame with border.

### `drawProgressBar(layer, x, y, w, progress, showPercent)`
Draw a progress bar (0.0 to 1.0) with optional percentage display.

### `drawSeparator(layer, x, y, w, style, ch)`
Draw a horizontal separator line.

---

## Advanced Widgets

### Radio Buttons

#### `drawRadioButton(layer, x, y, label, isSelected, isFocused)`
Draw a single radio button: `(•) Selected` or `( ) Unselected`

#### `drawRadioGroup(layer, x, y, options[], selected, focusIndex)`
Draw a vertical group of radio buttons.
- `options`: Array of option labels
- `selected`: Index of selected option
- `focusIndex`: Index of focused option (-1 for none)

### Dropdown/Select

#### `drawDropdown(layer, x, y, w, options[], selected, isOpen, isFocused)`
Draw a dropdown/select widget.
- When closed: Shows selected option with ▼ arrow
- When open: Shows list of options

### List/Menu

#### `drawList(layer, x, y, w, h, items[], selected, scrollOffset, isFocused)`
Draw a scrollable list with selection highlighting.
- Automatically shows scrollbar when needed
- `scrollOffset`: First visible item index
- `selected`: Currently selected item

### Text Area

#### `drawTextArea(layer, x, y, w, h, lines[], cursorLine, cursorCol, scrollY, isFocused)`
Draw a multi-line text area with cursor and scrolling.
- `lines`: Array of text lines
- `cursorLine`, `cursorCol`: Cursor position
- `scrollY`: First visible line
- Shows line:col indicator

### Tooltip

#### `drawTooltip(layer, x, y, text)`
Draw a floating tooltip/help text box.

### Tab Container

#### `drawTabBar(layer, x, y, w, tabs[], activeTab)`
Draw a tab bar with multiple tabs.
- `tabs`: Array of tab labels
- `activeTab`: Index of active tab

#### `drawTabContent(layer, x, y, w, h, borderStyle)`
Draw the content area below tabs with connecting borders.

### Enhanced Text Box

#### `drawTextBoxWithScroll(layer, x, y, w, h, content, cursorPos, scrollOffset, isFocused, borderStyle) -> int`
Draw a text input box with automatic horizontal scrolling.
- Returns new scroll offset
- Shows ◀ and ▶ indicators when scrolled

---

## Input Handling

### `handleTextInput(text, cursorPos, content) -> [newCursorPos, newContent, handled]`
Handle text input for text fields.
- Returns array: `[int, string, bool]`

**Usage:**
```nim
let result = handleTextInput(event.text, cursor, content)
cursor = result[0].i
content = result[1].s
handled = result[2].b
```

### `handleBackspace(cursorPos, content) -> [newCursorPos, newContent, handled]`
Handle backspace key for text fields.
- Returns array: `[int, string, bool]`

**Usage:**
```nim
let result = handleBackspace(cursor, content)
cursor = result[0].i
content = result[1].s
handled = result[2].b
```

### `handleArrowKeys(keyCode, value, minVal, maxVal, step) -> [newValue, handled]`
Handle arrow keys for sliders/numeric inputs.
- `keyCode`: 37=Left, 38=Up, 39=Right, 40=Down
- Returns array: `[float, bool]`

**Usage:**
```nim
let result = handleArrowKeys(keyCode, value, 0.0, 100.0, 5.0)
value = result[0].f
handled = result[1].b
```

---

## Layout Helpers

### `layoutVertical(startY, spacing, count) -> int[]`
Calculate Y positions for vertical widget layout.

**Usage:**
```nim
let positions = layoutVertical(10, 5, 3)  # Y positions: [10, 15, 20]
```

### `layoutHorizontal(startX, spacing, count) -> int[]`
Calculate X positions for horizontal widget layout.

**Usage:**
```nim
let positions = layoutHorizontal(5, 10, 4)  # X positions: [5, 15, 25, 35]
```

### `layoutGrid(startX, startY, cols, rows, cellWidth, cellHeight, spacingX, spacingY) -> [(x,y)]`
Calculate positions for grid layout.

**Usage:**
```nim
let grid = layoutGrid(5, 5, 3, 2, 20, 10, 5, 5)
# Returns array of {x, y} maps
```

### `layoutCentered(containerX, containerY, containerW, containerH, itemW, itemH) -> {x, y}`
Center an item within a container.

**Usage:**
```nim
let pos = layoutCentered(0, 0, 80, 24, 40, 10)
let centerX = pos.x
let centerY = pos.y
```

### `layoutForm(startX, startY, labelWidth, fieldWidth, fieldHeight, spacing, fieldCount) -> [{labelX, labelY, fieldX, fieldY}]`
Calculate positions for form fields (label + input pairs).

**Usage:**
```nim
let formPos = layoutForm(5, 10, 15, 30, 3, 2, 3)
# Returns array of maps with labelX, labelY, fieldX, fieldY
let namePos = formPos[0]
drawLabel(0, namePos.labelX, namePos.labelY, "Name:", style)
drawTextBox(0, namePos.fieldX, namePos.fieldY, 30, 3, ...)
```

---

## Style Names

All widgets use theme-aware styles. Common style names:

- `"default"` - Default text
- `"border"` - Box borders
- `"info"` - Information/highlights
- `"warning"` - Warnings/alerts
- `"button"` - Button fill
- `"highlight"` - Focus highlight

Get styles with: `getStyle("styleName")`

---

## Best Practices

1. **Layer Management**: Use layer 0 for UI, higher layers for overlays
2. **Focus Indication**: Always indicate which widget has focus
3. **Keyboard Navigation**: Support Tab, Arrow keys, Space, Enter
4. **Mouse Support**: Implement click handling for interactive widgets
5. **Responsive Layout**: Use layout helpers to adapt to terminal size
6. **Theme Integration**: Use `getStyle()` instead of hardcoded colors
7. **Input Validation**: Check bounds when handling user input
8. **Scroll Management**: Keep selected items visible when scrolling

---

## Example: Complete Form

```nim
# Initialize state
var name = ""
var nameCursor = 0
var nameScroll = 0
var email = ""
var emailCursor = 0
var emailScroll = 0
var focusIndex = 0
var newsletter = false

# Layout
let formPos = layoutForm(10, 5, 10, 30, 3, 2, 2)

# Render
drawLabel(0, formPos[0].labelX, formPos[0].labelY, "Name:", getStyle("info"))
nameScroll = drawTextBoxWithScroll(0, formPos[0].fieldX, formPos[0].fieldY, 
                                   30, 3, name, nameCursor, nameScroll, 
                                   focusIndex == 0, "single")

drawLabel(0, formPos[1].labelX, formPos[1].labelY, "Email:", getStyle("info"))
emailScroll = drawTextBoxWithScroll(0, formPos[1].fieldX, formPos[1].fieldY,
                                    30, 3, email, emailCursor, emailScroll,
                                    focusIndex == 1, "single")

drawCheckBox(0, 10, 15, "Subscribe to newsletter", newsletter, focusIndex == 2)

# Input handling
if event.type == "text":
  if focusIndex == 0:
    let result = handleTextInput(event.text, nameCursor, name)
    nameCursor = result[0].i
    name = result[1].s
  elif focusIndex == 1:
    let result = handleTextInput(event.text, emailCursor, email)
    emailCursor = result[0].i
    email = result[1].s
```

---

## See Also

- [tui_helpers.md](../demos/tui_helpers.md) - Basic widgets demo
- [tui2.md](../demos/tui2.md) - Simplified TUI using helpers
- [tui3_advanced.md](../demos/tui3_advanced.md) - Advanced widgets showcase
