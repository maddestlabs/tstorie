## Simplified Event API for Exports
## Provides the same simple event interface that nimini exposes to scripts
## This allows exported code to use the same event handling API as the runtime

import types

type
  SimpleEvent* = object
    `type`*: string  # Use backticks to allow 'type' as field name
    x*, y*: int
    button*: string
    action*: string
    keyCode*: int    # Matches nimini runtime API
    mods*: seq[string]  # Matches nimini runtime API - array of modifier strings
    text*: string
    # Canvas-relative coordinates (for mouse events, -1 if outside canvas)
    contentX*, contentY*: int
    bufferX*, bufferY*: int
    # Resize event dimensions
    width*, height*: int

proc toSimpleEvent*(evt: InputEvent): SimpleEvent =
  ## Convert native InputEvent to simplified event object
  ## This matches the API provided by encodeInputEvent() in the nimini runtime
  case evt.kind
  of KeyEvent:
    result.`type` = "key"
    result.keyCode = evt.keyCode
    result.action = case evt.keyAction
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat"
    result.mods = @[]
    if ModShift in evt.keyMods: result.mods.add("shift")
    if ModAlt in evt.keyMods: result.mods.add("alt")
    if ModCtrl in evt.keyMods: result.mods.add("ctrl")
    if ModSuper in evt.keyMods: result.mods.add("super")
  of MouseEvent:
    result.`type` = "mouse"
    result.x = evt.mouseX
    result.y = evt.mouseY
    result.button = case evt.button
      of Left: "left"
      of Middle: "middle"
      of Right: "right"
      of ScrollUp: "scroll_up"
      of ScrollDown: "scroll_down"
      else: "unknown"
    result.action = case evt.action
      of Press: "press"
      of Release: "release"
      else: ""
    # Canvas coordinates would need canvas state access - set to -1 for now
    result.contentX = -1
    result.contentY = -1
    result.bufferX = -1
    result.bufferY = -1
    result.mods = @[]
    if ModShift in evt.mods: result.mods.add("shift")
    if ModAlt in evt.mods: result.mods.add("alt")
    if ModCtrl in evt.mods: result.mods.add("ctrl")
    if ModSuper in evt.mods: result.mods.add("super")
  of MouseMoveEvent:
    result.`type` = "mouse_move"
    result.x = evt.moveX
    result.y = evt.moveY
    result.mods = @[]
    if ModShift in evt.moveMods: result.mods.add("shift")
    if ModAlt in evt.moveMods: result.mods.add("alt")
    if ModCtrl in evt.moveMods: result.mods.add("ctrl")
    if ModSuper in evt.moveMods: result.mods.add("super")
  of TextEvent:
    result.`type` = "text"
    result.text = evt.text
  of ResizeEvent:
    result.`type` = "resize"
    result.x = evt.newWidth
    result.y = evt.newHeight
    result.width = evt.newWidth
    result.height = evt.newHeight
