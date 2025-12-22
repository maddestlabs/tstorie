## Test TUI system basic functionality
## This test verifies that the TUI module compiles and basic operations work

import ../lib/storie_types
import tables

# Constants for key codes
const
  INPUT_UP* = 1000
  INPUT_DOWN* = 1001
  INPUT_LEFT* = 1002
  INPUT_RIGHT* = 1003
  INPUT_HOME* = 1004
  INPUT_END* = 1005

# Mock the types that tui.nim needs from tstorie.nim
type
  Color* = object
    r*, g*, b*: uint8
  
  Style* = object
    fg*, bg*: Color
    bold*, underline*, italic*, dim*: bool
  
  TermBuffer* = object
    width*, height*: int
    cells: seq[string]
  
  Layer* = ref object
    id*: string
    z*: int
    visible*: bool
    buffer*: TermBuffer
  
  InputAction* = enum
    Press, Release, Repeat
  
  MouseButton* = enum
    MouseLeft, MouseMiddle, MouseRight
  
  InputEventKind* = enum
    KeyEvent, MouseEvent, MouseMoveEvent, TextEvent
  
  InputEvent* = object
    case kind*: InputEventKind
    of KeyEvent:
      keyCode*: int
      keyMods*: set[uint8]
      keyAction*: InputAction
    of MouseEvent:
      mouseButton*: MouseButton
      mouseX*, mouseY*: int
      mouseAction*: InputAction
    of MouseMoveEvent:
      moveX*, moveY*: int
      moveMods*: set[uint8]
    of TextEvent:
      text*: string

# Helper procs for TermBuffer
proc write*(tb: var TermBuffer, x, y: int, ch: string, style: Style) =
  discard

proc writeText*(tb: var TermBuffer, x, y: int, text: string, style: Style) =
  discard

# Now include the TUI module
include ../lib/tui

# Helper to create a test stylesheet
proc createTestStyleSheet(): StyleSheet =
  result = initTable[string, StyleConfig]()
  result["label"] = StyleConfig(
    fg: (200'u8, 200'u8, 200'u8),
    bg: (20'u8, 20'u8, 20'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  result["button.normal"] = StyleConfig(
    fg: (255'u8, 255'u8, 255'u8),
    bg: (50'u8, 50'u8, 150'u8),
    bold: false,
    italic: false,
    underline: false,
    dim: false
  )
  result["button.focused"] = StyleConfig(
    fg: (255'u8, 255'u8, 100'u8),
    bg: (80'u8, 80'u8, 200'u8),
    bold: true,
    italic: false,
    underline: false,
    dim: false
  )

# Test 1: Create widget manager
echo "Test 1: Creating widget manager..."
let styleSheet = createTestStyleSheet()
var wm = newWidgetManager(styleSheet)
assert wm.widgets.len == 0
assert wm.focusedWidget.isNil
echo "  ✓ Widget manager created successfully"

# Test 2: Create and add a label
echo "Test 2: Creating label widget..."
var label = newLabel("test_label", 5, 5, 20, 1, "Hello TUI")
assert label.id == "test_label"
assert label.text == "Hello TUI"
assert label.x == 5
assert label.y == 5
wm.addWidget(label)
assert wm.widgets.len == 1
echo "  ✓ Label widget created and added"

# Test 3: Create and add buttons
echo "Test 3: Creating button widgets..."
var btn1 = newButton("btn1", 5, 10, 10, 3, "Button 1")
btn1.tabIndex = 0
assert btn1.id == "btn1"
assert btn1.label == "Button 1"
assert btn1.focusable == true
wm.addWidget(btn1)

var btn2 = newButton("btn2", 20, 10, 10, 3, "Button 2")
btn2.tabIndex = 1
wm.addWidget(btn2)

assert wm.widgets.len == 3
echo "  ✓ Button widgets created and added"

# Test 4: Test tab order
echo "Test 4: Testing tab order..."
wm.rebuildTabOrder()
assert wm.tabOrder.len == 2  # Only buttons are focusable
assert wm.tabOrder[0] == "btn1"
assert wm.tabOrder[1] == "btn2"
echo "  ✓ Tab order built correctly"

# Test 5: Test focus management
echo "Test 5: Testing focus management..."
wm.focusNext()
assert not wm.focusedWidget.isNil
assert wm.focusedWidget.id == "btn1"
assert wm.focusedWidget.state == wsFocused
echo "  ✓ Focus next works"

wm.focusNext()
assert wm.focusedWidget.id == "btn2"
echo "  ✓ Focus cycling works"

wm.focusPrev()
assert wm.focusedWidget.id == "btn1"
echo "  ✓ Focus previous works"

# Test 6: Test widget lookup
echo "Test 6: Testing widget lookup..."
let foundWidget = wm.getWidget("btn1")
assert not foundWidget.isNil
assert foundWidget.id == "btn1"
echo "  ✓ Widget lookup works"

# Test 7: Test style resolution
echo "Test 7: Testing style resolution..."
let labelStyle = label.resolveStyle()
assert labelStyle.fg.r == 200
assert labelStyle.fg.g == 200
echo "  ✓ Style resolution works"

let btn1NormalStyle = btn1.resolveStyle()
assert btn1NormalStyle.fg.r == 255

btn1.state = wsFocused
let btn1FocusedStyle = btn1.resolveStyle()
assert btn1FocusedStyle.bold == true
echo "  ✓ State-based style resolution works"

# Test 8: Test widget removal
echo "Test 8: Testing widget removal..."
wm.removeWidget("btn2")
assert wm.widgets.len == 2
assert wm.getWidget("btn2").isNil
echo "  ✓ Widget removal works"

# Test 9: Test hit detection
echo "Test 9: Testing hit detection..."
assert btn1.contains(7, 11)  # Inside button at (5,10) size (10,3)
assert not btn1.contains(1, 1)  # Outside button
echo "  ✓ Hit detection works"

# Test 10: Test widget state changes
echo "Test 10: Testing widget state changes..."
btn1.setEnabled(false)
assert btn1.state == wsDisabled
assert not btn1.enabled

btn1.setEnabled(true)
assert btn1.enabled
assert btn1.state == wsNormal
echo "  ✓ Widget state changes work"

# ======== PHASE 3 TESTS ========

# Test 11: Create and test checkbox
echo "Test 11: Testing checkbox widget..."
var checkbox = newCheckBox("check1", 5, 15, "Accept terms", false)
assert checkbox.id == "check1"
assert checkbox.checked == false
assert checkbox.label == "Accept terms"
assert not checkbox.radio
wm.addWidget(checkbox)

checkbox.toggle()
assert checkbox.checked == true
echo "  ✓ Checkbox toggle works"

checkbox.setChecked(false)
assert checkbox.checked == false
echo "  ✓ Checkbox set state works"

# Test 12: Create and test radio buttons
echo "Test 12: Testing radio button groups..."
var radio1 = newRadioButton("radio1", 5, 17, "Option 1", "group1")
var radio2 = newRadioButton("radio2", 5, 18, "Option 2", "group1")
var radio3 = newRadioButton("radio3", 5, 19, "Option 3", "group1")

assert radio1.radio == true
assert radio1.group == "group1"

wm.addWidget(radio1)
wm.addWidget(radio2)
wm.addWidget(radio3)

# Select first radio
radio1.setChecked(true)
wm.uncheckRadioGroup("group1", "radio1")
assert radio1.checked == true
assert radio2.checked == false
assert radio3.checked == false
echo "  ✓ Radio button group exclusion works"

# Toggle to second radio
radio2.toggle()
wm.uncheckRadioGroup("group1", "radio2")
assert radio1.checked == false
assert radio2.checked == true
assert radio3.checked == false
echo "  ✓ Radio button group switching works"

# Test 13: Create and test horizontal slider
echo "Test 13: Testing horizontal slider..."
var hSlider = newSlider("slider_h", 5, 22, 20, 0.0, 100.0)
assert hSlider.id == "slider_h"
assert hSlider.minValue == 0.0
assert hSlider.maxValue == 100.0
assert hSlider.value == 0.0
assert hSlider.orientation == Horizontal
wm.addWidget(hSlider)

hSlider.setValue(50.0)
assert hSlider.value == 50.0
echo "  ✓ Slider value setting works"

hSlider.setValue(150.0)  # Over max
assert hSlider.value == 100.0  # Should clamp
echo "  ✓ Slider value clamping works"

hSlider.setValue(-10.0)  # Under min
assert hSlider.value == 0.0  # Should clamp
echo "  ✓ Slider min value clamping works"

# Test 14: Test slider with steps
echo "Test 14: Testing slider with steps..."
var steppedSlider = newSlider("slider_step", 5, 24, 20, 0.0, 100.0)
steppedSlider.step = 10.0
wm.addWidget(steppedSlider)

steppedSlider.setValue(23.0)  # Should snap to 20
assert steppedSlider.value == 20.0
echo "  ✓ Slider step snapping works"

steppedSlider.setValue(27.0)  # Should snap to 30
assert steppedSlider.value == 30.0
echo "  ✓ Slider step snapping (up) works"

# Test 15: Test vertical slider
echo "Test 15: Testing vertical slider..."
var vSlider = newVerticalSlider("slider_v", 30, 10, 10, 0.0, 100.0)
assert vSlider.orientation == Vertical
assert vSlider.width == 1
assert vSlider.height == 10
wm.addWidget(vSlider)

vSlider.setValue(75.0)
assert vSlider.value == 75.0
echo "  ✓ Vertical slider works"

# Test 16: Test checkbox callback
echo "Test 16: Testing checkbox onChange callback..."
var callbackFired = false
var checkboxCb = newCheckBox("check_cb", 5, 26, "Callback test")
checkboxCb.onChange = proc(w: Widget) =
  callbackFired = true
wm.addWidget(checkboxCb)

checkboxCb.toggle()
assert callbackFired == true
assert checkboxCb.checked == true
echo "  ✓ Checkbox onChange callback works"

# Test 17: Test slider callback
echo "Test 17: Testing slider onChange callback..."
var sliderCallbackValue: float = 0.0
var sliderCb = newSlider("slider_cb", 5, 28, 15, 0.0, 50.0)
sliderCb.onChange = proc(w: Widget) =
  sliderCallbackValue = Slider(w).value
wm.addWidget(sliderCb)

sliderCb.setValue(25.0)
assert sliderCallbackValue == 25.0
echo "  ✓ Slider onChange callback works"

# Test 18: Test checkbox hit detection
echo "Test 18: Testing checkbox hit detection..."
var hitBox = newCheckBox("hit_check", 10, 30, "Hit test")
wm.addWidget(hitBox)
assert hitBox.contains(11, 30)  # Inside checkbox
assert not hitBox.contains(1, 1)  # Outside
echo "  ✓ Checkbox hit detection works"

echo ""
echo "All tests passed! ✓"
echo ""
echo "TUI system is working correctly."
