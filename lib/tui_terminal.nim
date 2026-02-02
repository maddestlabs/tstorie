## TUI Terminal Backend - Auto-rendering widgets with smart caching using direct buffer writes

import tables, strutils
import tui_helpers, ../src/types, ../src/layers, storie_types, ../nimini/auto_bindings

export UIContext, initUI

when not declared(Layer):
  type Layer* = ref object
when not declared(AppState):
  type AppState* = ref object

var gDefaultLayerRef*: ptr Layer = nil
var gAppStateRef*: ptr AppState = nil

proc getOrCreateWidgetState*(ui: UIContext, id: string): var UIWidgetState =
  if id notin ui.widgets:
    ui.widgets[id] = UIWidgetState(renderDirty: true)
  return ui.widgets[id]

proc checkRenderDirty*(state: var UIWidgetState, label: string, x, y, w, h: int, 
                       styleName: string = ""): bool =
  if state.renderDirty: return true
  if state.lastLabel != label or state.lastX != x or state.lastY != y or 
     state.lastW != w or state.lastH != h or
     (styleName.len > 0 and state.lastStyleName != styleName):
    state.renderDirty = true
    return true
  return false

proc markRenderClean*(state: var UIWidgetState, label: string, x, y, w, h: int, styleName: string = "") =
  state.lastLabel = label
  state.lastX = x; state.lastY = y; state.lastW = w; state.lastH = h
  state.lastStyleName = styleName
  state.renderDirty = false

proc getLayerBuffer(layerIdx: int): ptr TermBuffer =
  if gDefaultLayerRef.isNil: return nil
  # Always use default layer for layer 0
  if layerIdx == 0:
    return addr gDefaultLayerRef[].buffer
  # For other layers, try appstate
  if not gAppStateRef.isNil and layerIdx > 0 and layerIdx < gAppStateRef[].layers.len:
    return addr gAppStateRef[].layers[layerIdx].buffer
  # Invalid layer index
  return nil

proc drawBoxBorder(buffer: ptr TermBuffer, x, y, w, h: int, style: Style) =
  if buffer.isNil or w < 2 or h < 2: return
  buffer[].writeCellText(x, y, "┌" & "─".repeat(w-2) & "┐", style)
  for row in 1..<(h-1):
    buffer[].writeCellText(x, y + row, "│", style)
    buffer[].writeCellText(x + w - 1, y + row, "│", style)
  buffer[].writeCellText(x, y + h - 1, "└" & "─".repeat(w-2) & "┘", style)

proc drawCenteredTextDirect(buffer: ptr TermBuffer, x, y, w, h: int, text: string, style: Style) =
  if buffer.isNil: return
  let centerY = y + (h div 2)
  let centerX = x + ((w - text.len) div 2)
  if centerX >= x and centerX + text.len <= x + w:
    buffer[].writeCellText(centerX, centerY, text, style)

proc button*(ui: UIContext, id, label: string, x, y, w, h: int, 
             layer: int = 0, styleName: string = "button"): bool {.autoExpose: "ui".} =
  if ui.isNil: return false
  var state = ui.getOrCreateWidgetState(id)
  if checkRenderDirty(state, label, x, y, w, h, styleName):
    let buffer = getLayerBuffer(layer)
    if not buffer.isNil:
      let style = tuiGetStyle(styleName)
      drawBoxBorder(buffer, x, y, w, h, style)
      drawCenteredTextDirect(buffer, x, y, w, h, label, style)
    markRenderClean(state, label, x, y, w, h, styleName)
  let hovered = ui.mouseX >= x and ui.mouseX < x+w and ui.mouseY >= y and ui.mouseY < y+h
  if hovered: ui.hotId = id
  result = hovered and ui.mousePressed and ui.activeId == id

proc label*(ui: UIContext, id, text: string, x, y: int,
            layer: int = 0, styleName: string = "body") {.autoExpose: "ui".} =
  if ui.isNil: return
  var state = ui.getOrCreateWidgetState(id)
  if state.lastLabel != text:
    let buffer = getLayerBuffer(layer)
    if not buffer.isNil:
      buffer[].writeCellText(x, y, text, tuiGetStyle(styleName))
    state.lastLabel = text

proc isHovered*(ui: UIContext, id: string): bool {.autoExpose: "ui".} =
  if ui.isNil: return false
  return ui.hotId == id

proc isActive*(ui: UIContext, id: string): bool {.autoExpose: "ui".} =
  if ui.isNil: return false
  return ui.activeId == id

proc registerTUITerminalBindings*(defaultLayer: ptr Layer, appState: ptr AppState) =
  gDefaultLayerRef = defaultLayer
  gAppStateRef = appState
