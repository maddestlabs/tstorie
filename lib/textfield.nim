## TextField Widget
##
## A basic single-line text input widget with cursor navigation,
## insert/delete operations, and rendering support.
## Built on top of editor_base primitives.

import editor_base

type
  TextField* = ref object
    text*: string           ## The current text content
    cursor*: int            ## Cursor position (0-based, can equal text.len)
    x*, y*: int            ## Position on screen
    width*: int            ## Display width
    style*: Style          ## Default text style
    cursorStyle*: Style    ## Style for cursor position
    focused*: bool         ## Whether the field has focus
    offset*: int           ## Horizontal scroll offset for long text

proc newTextField*(x, y, width: int): TextField =
  ## Create a new textfield at the given position and width
  result = TextField()
  result.text = ""
  result.cursor = 0
  result.x = x
  result.y = y
  result.width = width
  result.focused = false
  result.offset = 0
  result.style = defaultStyle()
  result.cursorStyle = defaultStyle()
  result.cursorStyle.bg = rgb(100, 100, 100)  ## Gray background for cursor

# ================================================================
# TEXT OPERATIONS
# ================================================================

proc insert*(tf: TextField, ch: string) =
  ## Insert a character at the cursor position
  if tf.cursor <= tf.text.len:
    tf.text.insert(ch, tf.cursor)
    tf.cursor += ch.len

proc deleteChar*(tf: TextField) =
  ## Delete character at cursor (Delete key behavior)
  if tf.cursor < tf.text.len:
    tf.text = tf.text[0 ..< tf.cursor] & tf.text[tf.cursor + 1 .. ^1]

proc backspace*(tf: TextField) =
  ## Delete character before cursor (Backspace key behavior)
  if tf.cursor > 0:
    tf.cursor -= 1
    tf.text = tf.text[0 ..< tf.cursor] & tf.text[tf.cursor + 1 .. ^1]

proc clear*(tf: TextField) =
  ## Clear all text
  tf.text = ""
  tf.cursor = 0
  tf.offset = 0

proc setText*(tf: TextField, text: string) =
  ## Set the text content
  tf.text = text
  tf.cursor = min(tf.cursor, tf.text.len)
  tf.offset = 0

# ================================================================
# CURSOR NAVIGATION
# ================================================================

proc moveCursorLeft*(tf: TextField) =
  ## Move cursor one position left
  if tf.cursor > 0:
    tf.cursor -= 1

proc moveCursorRight*(tf: TextField) =
  ## Move cursor one position right
  if tf.cursor < tf.text.len:
    tf.cursor += 1

proc moveCursorHome*(tf: TextField) =
  ## Move cursor to start of text
  tf.cursor = 0

proc moveCursorEnd*(tf: TextField) =
  ## Move cursor to end of text
  tf.cursor = tf.text.len

# ================================================================
# SCROLLING
# ================================================================

proc updateScroll*(tf: TextField) =
  ## Update horizontal scroll offset to keep cursor visible
  let cursorPos = tf.cursor - tf.offset
  
  # Scroll right if cursor is past the visible area
  if cursorPos >= tf.width:
    tf.offset = tf.cursor - tf.width + 1
  
  # Scroll left if cursor is before the visible area
  if cursorPos < 0:
    tf.offset = tf.cursor

  # Ensure offset doesn't go negative
  if tf.offset < 0:
    tf.offset = 0

# ================================================================
# INPUT HANDLING
# ================================================================

proc handleInput*(tf: TextField, event: InputEvent): bool =
  ## Handle input events. Returns true if the event was handled.
  if not tf.focused:
    return false
  
  case event.kind
  of evKey:
    case event.key
    of "left", "Left":
      tf.moveCursorLeft()
      tf.updateScroll()
      return true
    of "right", "Right":
      tf.moveCursorRight()
      tf.updateScroll()
      return true
    of "home", "Home":
      tf.moveCursorHome()
      tf.updateScroll()
      return true
    of "end", "End":
      tf.moveCursorEnd()
      tf.updateScroll()
      return true
    of "backspace", "Backspace":
      tf.backspace()
      tf.updateScroll()
      return true
    of "delete", "Delete":
      tf.deleteChar()
      tf.updateScroll()
      return true
    else:
      # If it's a printable character (length 1), insert it
      if event.key.len == 1:
        tf.insert(event.key)
        tf.updateScroll()
        return true
  else:
    discard
  
  return false

# ================================================================
# RENDERING
# ================================================================

proc render*(tf: TextField, buf: var Buffer) =
  ## Render the textfield to a buffer
  # Calculate visible portion of text
  let visibleStart = tf.offset
  let visibleEnd = min(tf.offset + tf.width, tf.text.len)
  
  # Clear the field area first
  for i in 0 ..< tf.width:
    buf.write(tf.x + i, tf.y, " ", tf.style)
  
  # Render visible text
  var screenX = tf.x
  for i in visibleStart ..< visibleEnd:
    let isCursor = (i == tf.cursor and tf.focused)
    let style = if isCursor: tf.cursorStyle else: tf.style
    buf.write(screenX, tf.y, $tf.text[i], style)
    screenX += 1
  
  # Render cursor if it's at the end or on an empty field
  if tf.focused and tf.cursor == tf.text.len:
    let cursorScreenX = tf.x + (tf.cursor - tf.offset)
    if cursorScreenX >= tf.x and cursorScreenX < tf.x + tf.width:
      buf.write(cursorScreenX, tf.y, " ", tf.cursorStyle)

proc renderToLayer*(tf: TextField, layer: Layer) =
  ## Convenience method to render directly to a layer
  tf.render(layer.buffer)
