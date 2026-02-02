## TUI Graphics Backend - Auto-rendering widgets for SDL3/WebGPU
##
## This module provides immediate-mode UI widgets that automatically render
## to pixel-based graphics backends (SDL3, WebGPU). Uses smart caching.
##
## TODO: Implement pixel-based rendering when graphics backend is active
##
## Usage:
##   import lib/tui_graphics
##   
##   if ui.button("btn1", "Click Me!", 100, 50, 200, 40):
##     handleClick()  # Button is drawn as textured sprite

import tables
import tui_helpers  # Core UIContext and logic
import ../nimini/auto_bindings

# Re-export core types
export UIContext, initUI

# ==============================================================================
# Graphics Backend Widgets (SDL3/WebGPU)
# ==============================================================================

# NOTE: These are stubs. Actual implementation would use SDL3/WebGPU rendering
# For now, they just do the UI logic without rendering

proc button*(ui: UIContext, id, label: string, x, y, w, h: int): bool {.autoExpose: "ui".} =
  ## Auto-rendering button for graphics backend (TODO: implement rendering)
  
  if ui.isNil:
    return false
  
  # TODO: Render textured button sprite with proper scaling
  # renderButtonSprite(x, y, w, h, ui.isHovered(id), ui.isActive(id))
  # renderTextCentered(x, y, w, h, label)
  
  # UI logic (same as terminal)
  let hovered = ui.mouseX >= x and ui.mouseX < x+w and ui.mouseY >= y and ui.mouseY < y+h
  
  if hovered:
    ui.hotId = id
  
  result = hovered and ui.mousePressed and ui.activeId == id

# TODO: Add other widget implementations (textBox, slider, checkbox, etc.)
# These should render using graphics primitives instead of terminal characters
