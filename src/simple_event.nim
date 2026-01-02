## Simplified Event API for Exports
## Provides the same simple event interface that nimini exposes to scripts
## This allows exported code to use the same event handling API as the runtime

import types
import strutils

type
  SimpleEvent* = object
    `type`*: string  # Use backticks to allow 'type' as field name
    x*, y*: int
    button*: string
    action*: string
    key*: int
    mods*: string

proc toSimpleEvent*(evt: InputEvent): SimpleEvent =
  ## Convert native InputEvent to simplified event object
  ## This matches the API provided by encodeInputEvent() in the nimini runtime
  case evt.kind
  of KeyEvent:
    result.`type` = "key"
    result.key = evt.keyCode
    result.action = case evt.keyAction
      of Press: "press"
      of Release: "release"
      of Repeat: "repeat"
    var modStrs: seq[string]
    if ModShift in evt.keyMods: modStrs.add("shift")
    if ModAlt in evt.keyMods: modStrs.add("alt")
    if ModCtrl in evt.keyMods: modStrs.add("ctrl")
    if ModSuper in evt.keyMods: modStrs.add("super")
    result.mods = modStrs.join(",")
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
  of MouseMoveEvent:
    result.`type` = "mouse_move"
    result.x = evt.moveX
    result.y = evt.moveY
  of TextEvent:
    result.`type` = "text"
  of ResizeEvent:
    result.`type` = "resize"
    result.x = evt.newWidth
    result.y = evt.newHeight
