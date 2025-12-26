## Simple test for TextField widget

import ../lib/editor_base
import ../lib/textfield

proc testTextField() =
  echo "Testing TextField widget..."
  
  # Create a textfield
  var field = newTextField(0, 0, 20)
  field.focused = true
  
  # Test 1: Insert characters
  field.insert("H")
  field.insert("e")
  field.insert("l")
  field.insert("l")
  field.insert("o")
  assert field.text == "Hello"
  assert field.cursor == 5
  echo "✓ Insert characters"
  
  # Test 2: Move cursor left
  field.moveCursorLeft()
  assert field.cursor == 4
  field.moveCursorLeft()
  assert field.cursor == 3
  echo "✓ Move cursor left"
  
  # Test 3: Insert in middle
  field.insert("X")
  assert field.text == "HelXlo"
  assert field.cursor == 4
  echo "✓ Insert in middle"
  
  # Test 4: Delete character
  field.deleteChar()
  assert field.text == "HelXo"
  assert field.cursor == 4
  echo "✓ Delete character"
  
  # Test 5: Backspace
  field.backspace()
  assert field.text == "Helo"
  assert field.cursor == 3
  echo "✓ Backspace"
  
  # Test 6: Move to home
  field.moveCursorHome()
  assert field.cursor == 0
  echo "✓ Move cursor home"
  
  # Test 7: Move to end
  field.moveCursorEnd()
  assert field.cursor == 4
  echo "✓ Move cursor end"
  
  # Test 8: Clear text
  field.clear()
  assert field.text == ""
  assert field.cursor == 0
  echo "✓ Clear text"
  
  # Test 9: Set text
  field.setText("World")
  assert field.text == "World"
  echo "✓ Set text"
  
  # Test 10: Input event handling
  let keyEvent = InputEvent(
    kind: evKey,
    key: "!",
    keyCode: 33,
    action: "press"
  )
  field.moveCursorEnd()
  let handled = field.handleInput(keyEvent)
  assert handled == true
  assert field.text == "World!"
  echo "✓ Handle input event"
  
  # Test 11: Render to buffer
  var buffer = newBuffer(30, 5)
  field.render(buffer)
  echo "✓ Render to buffer"
  
  # Test 12: Scrolling with long text
  field.clear()
  field.width = 10
  for i in 1..20:
    field.insert("X")
  field.updateScroll()
  assert field.offset > 0  # Should have scrolled
  echo "✓ Horizontal scrolling"
  
  echo "\nAll tests passed! ✓"

when isMainModule:
  testTextField()
